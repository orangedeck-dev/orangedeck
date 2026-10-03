// The pool: third page of the miner tab, between device and network.
//
// Reads the open statistics of a pool with the public-pool interface
// (public-pool.io, pool.solomining.de and the many self-hosted ones). Two
// parts, the second only if the user entered an address:
//
//   Pool       /api/pool, /api/info, /api/info/chart: size, miners, blocks,
//              which devices mine there. Needs nothing from the user.
//   Yours      /api/client/<address>, /api/client/<address>/chart: the
//              devices mining to that payout address, as the pool sees them.
//
// The second part is the way to see a miner that the app cannot reach on
// the network: a guest Wi-Fi with client isolation, a phone on mobile data.
// The miner talks to the pool anyway, and the pool shows what it gets.
//
// The address is only sent to the pool entered here, which knows it from
// the miner already. It is not written anywhere else and never logged.
//
// Fetched here with XMLHttpRequest, like `DirectMiner`, so it works the same
// in the app, the DMS plugin and on Android, with or without the service.
// Only while the page is visible.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "strings.js" as Tr
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    function rollen(wie) {
        return Roll.rollen(flick, wie);
    }

    property string lang: "de"
    property bool live: true
    property bool finger: false
    property real topInset: 0
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"

    // As entered in the settings: "pool.solomining.de", "https://public-pool.io:40557"
    property string url: ""
    // The devices under the payout address, fetched once for this page and
    // the device page (PoolKlient.qml). Null or not ready without an address.
    property var klient: null
    // The own devices from the device page, for "your share" without an address.
    property var miners: []
    property real netDiff: 0

    // https:// added, trailing slash and "/api" removed.
    readonly property string basis: {
        var u = String(root.url || "").trim();
        if (!u)
            return "";
        if (u.indexOf("://") < 0)
            u = "https://" + u;
        u = u.replace(/\/+$/, "").replace(/\/api$/i, "");
        return u;
    }
    readonly property string adresse: root.klient && root.klient.bereit ? root.klient.adresse : ""
    // On a narrow screen the worker rows drop the best share column.
    readonly property bool schmal: root.width < root.scaleUnit * 22
    // Host without port, to match the stratum host of the own devices: the API
    // often runs on another port than stratum (public-pool.io: 40557 and 21496).
    readonly property string wirt: {
        var m = /^[a-z]+:\/\/([^\/:]+)/i.exec(root.basis);
        return m ? m[1].toLowerCase() : "";
    }

    // ------------------------------------------------------------ Fetching
    property var pool: null          // /api/pool
    property var info: null          // /api/info
    property var poolChart: []       // /api/info/chart
    readonly property var client: root.klient && root.adresse ? root.klient.client : null
    readonly property var clientChart: root.klient && root.adresse ? root.klient.chart : []
    property string fehler: ""
    property bool geladen: false
    property int __runde: 0

    function holen(pfad, fertig) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status !== 200) {
                fertig(null, x.status ? "HTTP " + x.status : Tr.t("pool.unreachable", root.lang));
                return;
            }
            try {
                fertig(JSON.parse(x.responseText), "");
            } catch (e) {
                fertig(null, Tr.t("pool.noPublicPool", root.lang));
            }
        };
        x.open("GET", root.basis + pfad);
        x.timeout = 10000;
        x.send();
    }

    function abrufen() {
        if (!root.live || !root.basis)
            return;
        var runde = ++root.__runde;
        var gilt = function () {
            return runde === root.__runde;
        };
        root.holen("/api/pool", function (d, err) {
            if (!gilt())
                return;
            root.pool = d;
        });
        root.holen("/api/info", function (d, err) {
            if (!gilt())
                return;
            root.geladen = true;
            root.fehler = d ? "" : err;
            if (d)
                root.info = d;
        });
        // With an address the chart shows its hashrate (PoolKlient), without
        // one the pool's.
        if (!root.adresse) {
            root.holen("/api/info/chart", function (d, err) {
                if (gilt())
                    root.poolChart = Array.isArray(d) ? d : [];
            });
        }
    }

    onBasisChanged: {
        root.pool = null;
        root.info = null;
        root.poolChart = [];
        root.geladen = false;
        root.abrufen();
    }
    onAdresseChanged: root.abrufen()
    onLiveChanged: if (root.live) root.abrufen()
    Component.onCompleted: root.abrufen()

    // public-pool writes its statistics every ten minutes, the worker list on
    // every share. A minute is plenty.
    Timer {
        interval: 60000
        repeat: true
        running: root.live && root.basis !== ""
        onTriggered: root.abrufen()
    }

    property real jetzt: Date.now() / 1000
    Timer {
        interval: 30000
        repeat: true
        running: root.live
        triggeredOnStart: true
        onTriggered: root.jetzt = Date.now() / 1000
    }

    // ------------------------------------------------------------- Values
    function zahl(v) {
        var n = parseFloat(v);
        return isFinite(n) ? n : 0;
    }

    // Pool hashrate in H/s: /api/pool if the pool has it, otherwise the sum of
    // the device types in /api/info.
    readonly property real poolHash: {
        if (root.pool && root.pool.totalHashRate)
            return root.zahl(root.pool.totalHashRate);
        var s = 0, ua = (root.info && root.info.userAgents) || [];
        for (var i = 0; i < ua.length; i++)
            s += root.zahl(ua[i].totalHashRate);
        return s;
    }
    readonly property int poolMiner: {
        if (root.pool && root.pool.totalMiners)
            return root.pool.totalMiners;
        var s = 0, ua = (root.info && root.info.userAgents) || [];
        for (var i = 0; i < ua.length; i++)
            s += parseInt(ua[i].count, 10) || 0;
        return s;
    }
    readonly property int poolBloecke: {
        if (root.pool && Array.isArray(root.pool.blocksFound))
            return root.pool.blocksFound.length;
        return ((root.info && root.info.blockData) || []).length;
    }

    // Device types, by miners or by hashrate, largest first, the rest combined.
    // Each gets its color, the same in bars and ring, as on solomining.de.
    property string typAnsicht: "balken"     // "balken" | "ring"
    property string typMass: "hash"          // "hash" | "miner"
    readonly property var typFarben: [root.accentColor, "#3b82f6", "#22c55e", "#a855f7", "#f5c16c"]
    readonly property color restFarbe: "#94a3b8"
    readonly property var typen: {
        var ua = ((root.info && root.info.userAgents) || []).map(function (x) {
            return { "name": x.userAgent || "?", "n": parseInt(x.count, 10) || 0,
                     "h": root.zahl(x.totalHashRate) };
        });
        var nachMiner = root.typMass === "miner";
        ua.sort(function (a, b) {
            return nachMiner ? b.n - a.n : b.h - a.h;
        });
        var out = [], rest = { "n": 0, "h": 0 };
        // The pool's own catch-all names go into "others" with the rest.
        var sammel = ["other", "others", "unknown", "?", ""];
        var eigene = ua.filter(function (x) {
            return sammel.indexOf(String(x.name).toLowerCase()) < 0;
        });
        for (var j = 0; j < ua.length; j++) {
            if (eigene.indexOf(ua[j]) < 0) {
                rest.n += ua[j].n;
                rest.h += ua[j].h;
            }
        }
        ua = eigene;
        for (var i = 0; i < ua.length; i++) {
            if (i < root.typFarben.length) {
                ua[i].farbe = root.typFarben[i];
                out.push(ua[i]);
            } else {
                rest.n += ua[i].n;
                rest.h += ua[i].h;
            }
        }
        if (rest.n > 0 || rest.h > 0)
            out.push({ "name": Tr.t("net.others", root.lang), "n": rest.n, "h": rest.h,
                       "farbe": root.restFarbe });
        var summe = 0;
        for (var k = 0; k < out.length; k++)
            summe += nachMiner ? out[k].n : out[k].h;
        for (k = 0; k < out.length; k++)
            out[k].anteil = summe > 0 ? (nachMiner ? out[k].n : out[k].h) / summe : 0;
        return out;
    }
    readonly property real typSumme: {
        var s = 0;
        for (var i = 0; i < root.typen.length; i++)
            s += root.typMass === "miner" ? root.typen[i].n : root.typen[i].h;
        return s;
    }
    function typWert(t) {
        return root.typMass === "miner" ? Tr.group(t.n, root.lang) : Tr.big(t.h, root.lang, "H/s");
    }

    // Own devices on the network that mine on this pool.
    readonly property var lokal: {
        var h = 0, n = 0;
        for (var i = 0; i < root.miners.length; i++) {
            var m = root.miners[i];
            if (!m.online || !m.pool)
                continue;
            if (String(m.pool).split(":")[0].toLowerCase() !== root.wirt)
                continue;
            h += m.hashRate || 0;
            n++;
        }
        return { "h": h, "n": n };
    }

    readonly property var arbeiter: root.klient && root.adresse ? root.klient.arbeiter : []
    readonly property real eigenHash: {
        var s = 0;
        for (var i = 0; i < root.arbeiter.length; i++)
            if (root.arbeiter[i].aktiv)
                s += root.arbeiter[i].h;
        return s;
    }
    readonly property real eigenBest: root.client ? root.zahl(root.client.bestDifficulty) : 0

    // The chart series as `MinerChart` expects it: seconds and GH/s, oldest first.
    function reihe(liste) {
        var p = (liste || []).map(function (x) {
            return { "t": Date.parse(x.label) / 1000, "v": root.zahl(x.data) / 1e9 };
        }).filter(function (x) {
            return isFinite(x.t);
        });
        p.sort(function (a, b) {
            return a.t - b.t;
        });
        return {
            "t": p.map(function (x) { return x.t; }),
            "hr": p.map(function (x) { return Math.round(x.v * 10) / 10; }),
            "hrNow": [], "temp": []
        };
    }
    readonly property var kurve: root.reihe(root.adresse ? root.clientChart : root.poolChart)

    function vor(sek) {
        if (!isFinite(sek))
            return "–";
        if (sek < 60)
            return Tr.t("net.justNow", root.lang);
        var m = Math.floor(sek / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        var dauer = d > 0 ? Tr.t("duration.dayHour", root.lang, d, h % 24)
                  : h > 0 ? Tr.t("duration.hourMin", root.lang, h, m % 60)
                  : Tr.t("duration.min", root.lang, m);
        return Tr.t("net.ago", root.lang, dauer);
    }
    function anteil(teil, ganz) {
        if (!(ganz > 0) || !(teil > 0))
            return "–";
        var p = 100 * teil / ganz;
        return Tr.fixed(p, p >= 1 ? 1 : (p >= 0.01 ? 3 : 5), root.lang) + " %";
    }

    // Two small pill buttons, one of them chosen.
    component Wahl: Row {
        id: wahlRoot

        property var eintraege: []
        property string wert: ""
        signal gewaehlt(string k)

        spacing: root.scaleUnit * 0.15

        Repeater {
            model: wahlRoot.eintraege

            Rectangle {
                id: knopf

                required property var modelData

                readonly property bool an: knopf.modelData.k === wahlRoot.wert

                width: knopfText.implicitWidth + root.scaleUnit * 0.7
                height: Math.max(root.finger ? 32 : 0, knopfText.implicitHeight + root.scaleUnit * 0.25)
                radius: height / 2
                color: knopf.an ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                border.width: 1
                border.color: knopf.an ? root.accentColor : Qt.rgba(1, 1, 1, 0.14)

                Text {
                    id: knopfText

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: knopf.an ? root.textColor : root.dimColor
                    font.pixelSize: root.scaleUnit * 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: root.finger ? -6 : 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wahlRoot.gewaehlt(knopf.modelData.k)
                }
            }
        }
    }

    // Label on a bar: dark where the bar is, light beyond `grenze`.
    component ZweiTon: Item {
        id: zt

        property real grenze: 0
        property string links: ""
        property string rechts: ""
        readonly property color hell: root.textColor
        readonly property color dunkel: "#14111a"

        // Each layer shows only its stretch: dark from 0 to the bar's end,
        // light from there on. The texts inside sit at the same place in both.
        Repeater {
            model: [{ "c": zt.dunkel, "von": 0, "bis": zt.grenze },
                    { "c": zt.hell, "von": zt.grenze, "bis": zt.width }]

            Item {
                id: lage

                required property var modelData

                x: Math.max(0, Math.min(zt.width, lage.modelData.von))
                width: Math.max(0, Math.min(zt.width, lage.modelData.bis) - x)
                height: zt.height
                clip: true

                Item {
                    x: -lage.x
                    width: zt.width
                    height: zt.height

                    Text {
                        x: root.scaleUnit * 0.3
                        anchors.verticalCenter: parent.verticalCenter
                        text: zt.links
                        color: lage.modelData.c
                        font.pixelSize: root.scaleUnit * 0.5
                    }

                    Text {
                        x: zt.width - width - root.scaleUnit * 0.3
                        anchors.verticalCenter: parent.verticalCenter
                        text: zt.rechts
                        color: lage.modelData.c
                        font.pixelSize: root.scaleUnit * 0.5
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- Layout
    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin: root.topInset
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500

        Rectangle {
            parent: flick
            anchors.right: parent.right
            width: Math.max(2, root.scaleUnit * 0.16)
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: flick.contentHeight > flick.height + 1
            y: flick.contentY + flick.height * (flick.contentY / flick.contentHeight)
            height: flick.height * (flick.height / flick.contentHeight)
            z: 30
        }

        Column {
            id: body

            width: flick.width * 0.9
            x: (flick.width - width) / 2
            y: Math.max(root.scaleUnit * 0.3, (flick.height - implicitHeight) / 2)
            spacing: root.scaleUnit * 0.6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.wirt
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.72
            }

            // Not reachable, or not a public-pool.
            Text {
                width: parent.width
                visible: root.geladen && root.fehler !== "" && !root.info
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Tr.t("pool.unreachable", root.lang) + " (" + root.fehler + ")"
                color: root.badColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            // ------------------------------------------------ Yours
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.adresse !== "" && root.client !== null

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("pool.yours", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.eigenHash > 0 ? Tr.big(root.eigenHash, root.lang, "H/s") : "–"
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 2.2
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.eigenHash > 0
                    text: Tr.t("pool.shareOfPool", root.lang, root.anteil(root.eigenHash, root.poolHash))
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.eigenBest > 0 && root.netDiff > 0
                    topPadding: root.scaleUnit * 0.3
                    text: Tr.t("miner.bestShare", root.lang) + ": "
                          + Tr.t("miner.ofNet", root.lang, Tr.big(root.eigenBest, root.lang),
                                 Tr.big(root.netDiff, root.lang))
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    width: parent.width
                    visible: root.arbeiter.length === 0
                    topPadding: root.scaleUnit * 0.3
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Tr.t("pool.noWorkers", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }
            }

            // The chart: own hashrate at the pool with an address, the pool's without.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: (root.kurve.hr || []).length > 1

                Text {
                    text: Tr.t(root.adresse ? "pool.ownChart" : "pool.poolChart", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                MinerChart {
                    width: parent.width
                    height: root.scaleUnit * 4.2
                    hist: root.kurve
                    lang: root.lang
                    lineColor: root.accentColor
                    dimColor: root.dimColor
                    labelSize: root.scaleUnit * 0.5
                }
            }

            // The devices under the address.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.1
                visible: root.arbeiter.length > 0

                Repeater {
                    model: root.arbeiter

                    Row {
                        id: wz

                        required property var modelData

                        width: parent.width
                        height: root.finger ? Math.max(40, implicitHeight) : implicitHeight
                        spacing: root.scaleUnit * 0.5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * 0.32
                            height: width
                            radius: width / 2
                            color: wz.modelData.aktiv ? root.goodColor : root.badColor
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * (root.schmal ? 5.5 : 7)
                            elide: Text.ElideRight
                            text: wz.modelData.name
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * 4
                            text: wz.modelData.aktiv ? Tr.big(wz.modelData.h, root.lang, "H/s")
                                                     : Tr.t("miner.off", root.lang)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.schmal
                            width: root.scaleUnit * 3
                            text: Tr.big(wz.modelData.best, root.lang)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.vor(wz.modelData.alter)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }
                    }
                }
            }

            // ------------------------------------------------ Pool
            Grid {
                id: raster

                readonly property int spalten: body.width > root.scaleUnit * 16 ? 3 : 2
                readonly property real zelle: (body.width - (spalten - 1) * columnSpacing) / spalten

                visible: root.info !== null
                width: body.width
                columns: spalten
                columnSpacing: root.scaleUnit * 0.5
                rowSpacing: root.scaleUnit * 0.55

                Repeater {
                    model: [
                        { "k": Tr.t("pool.hashrate", root.lang), "v": Tr.big(root.poolHash, root.lang, "H/s") },
                        { "k": Tr.t("pool.miners", root.lang), "v": Tr.group(root.poolMiner, root.lang) },
                        { "k": Tr.t("pool.blocks", root.lang), "v": String(root.poolBloecke) }
                    ]

                    Column {
                        id: zelle

                        required property var modelData

                        width: raster.zelle
                        spacing: root.scaleUnit * 0.08

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: zelle.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: zelle.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.85
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // Own devices on the network that mine here, without an address.
            Text {
                width: parent.width
                visible: root.adresse === "" && root.lokal.n > 0 && root.poolHash > 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Tr.t("pool.localShare", root.lang, root.lokal.n,
                           root.anteil(root.lokal.h, root.poolHash))
                color: root.textColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            // Which devices mine here: bars or ring, by miners or by hashrate.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.25
                visible: root.typen.length > 0

                Item {
                    width: parent.width
                    height: Math.max(typTitel.height, wahlAnsicht.height)

                    Text {
                        id: typTitel

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.t("pool.devicesInPool", root.lang)
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.55
                    }

                    Row {
                        id: wahlAnsicht

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.scaleUnit * 0.5

                        Wahl {
                            eintraege: [{ "k": "hash", "l": Tr.t("pool.byHash", root.lang) },
                                        { "k": "miner", "l": Tr.t("pool.byMiners", root.lang) }]
                            wert: root.typMass
                            onGewaehlt: function (k) {
                                root.typMass = k;
                            }
                        }

                        Wahl {
                            eintraege: [{ "k": "balken", "l": Tr.t("pool.viewBars", root.lang) },
                                        { "k": "ring", "l": Tr.t("pool.viewRing", root.lang) }]
                            wert: root.typAnsicht
                            onGewaehlt: function (k) {
                                root.typAnsicht = k;
                            }
                        }
                    }
                }

                // Bars. The label is drawn twice: dark as far as the bar reaches,
                // light beyond. One color for both was unreadable wherever the bar
                // ended inside a word (Galaxy, 03.10.2026).
                Repeater {
                    model: root.typAnsicht === "balken" ? root.typen : []

                    Item {
                        id: typ

                        required property var modelData

                        width: parent.width
                        height: root.scaleUnit * 1.05

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        Rectangle {
                            id: balken

                            width: parent.width * Math.max(0.005, Math.min(1, typ.modelData.anteil))
                            height: parent.height
                            radius: 3
                            color: typ.modelData.farbe
                        }

                        ZweiTon {
                            anchors.fill: parent
                            grenze: balken.width
                            links: typ.modelData.name + " · " + root.typWert(typ.modelData)
                            rechts: Tr.fixed(100 * typ.modelData.anteil,
                                             typ.modelData.anteil >= 0.01 ? 1 : 3, root.lang) + " %"
                        }
                    }
                }

                // Ring with the total in the middle and a legend below.
                Item {
                    visible: root.typAnsicht === "ring"
                    width: parent.width
                    height: ring.height

                    Canvas {
                        id: ring

                        readonly property var teile: root.typen

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, root.scaleUnit * 9)
                        height: width
                        onTeileChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onVisibleChanged: if (visible) requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var t = ring.teile, summe = 0, i;
                            for (i = 0; i < t.length; i++)
                                summe += t[i].anteil;
                            if (!(summe > 0))
                                return;
                            var aussen = width / 2 - 2, innen = aussen * 0.62;
                            var r = (aussen + innen) / 2, start = -Math.PI / 2;
                            ctx.lineWidth = aussen - innen;
                            for (i = 0; i < t.length; i++) {
                                var ende = start + t[i].anteil / summe * Math.PI * 2;
                                ctx.beginPath();
                                ctx.arc(width / 2, height / 2, r, start, ende);
                                ctx.strokeStyle = t[i].farbe;
                                ctx.stroke();
                                start = ende;
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: ring
                        spacing: root.scaleUnit * 0.05

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.typMass === "miner" ? Tr.group(root.typSumme, root.lang)
                                                           : Tr.big(root.typSumme, root.lang, "H/s")
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.85
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Tr.t(root.typMass === "miner" ? "pool.miners" : "pool.hashrate", root.lang)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.5
                        }
                    }
                }

                Repeater {
                    model: root.typAnsicht === "ring" ? root.typen : []

                    Row {
                        id: leg

                        required property var modelData

                        width: parent.width
                        spacing: root.scaleUnit * 0.4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * 0.45
                            height: width
                            radius: 2
                            color: leg.modelData.farbe
                        }

                        Text {
                            width: leg.width - root.scaleUnit * 0.85 - legWert.width - root.scaleUnit * 0.4
                            elide: Text.ElideRight
                            text: leg.modelData.name
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            id: legWert

                            text: root.typWert(leg.modelData) + " · "
                                  + Tr.fixed(100 * leg.modelData.anteil,
                                             leg.modelData.anteil >= 0.01 ? 1 : 3, root.lang) + " %"
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }
                    }
                }
            }

            // Without an address: what it would bring.
            Text {
                width: parent.width
                visible: root.adresse === ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Tr.t("pool.hintAddress", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.5
            }
        }
    }
}
