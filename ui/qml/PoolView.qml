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
    // Payout address, optional.
    property string address: ""
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
    // Without the worker name: the stratum user is "address.worker", and
    // people paste it as AxeOS shows it ("bc1q….bitaxe"). An address never
    // contains a dot, so everything from the first one on goes.
    readonly property string adresse: String(root.address || "").trim().split(".")[0]
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
    property var client: null        // /api/client/<address>
    property var clientChart: []     // /api/client/<address>/chart
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
        if (root.adresse) {
            var a = encodeURIComponent(root.adresse);
            root.holen("/api/client/" + a, function (d, err) {
                if (gilt())
                    root.client = d;
            });
            root.holen("/api/client/" + a + "/chart", function (d, err) {
                if (gilt())
                    root.clientChart = Array.isArray(d) ? d : [];
            });
        } else {
            root.client = null;
            root.clientChart = [];
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

    // Device types, largest share of the hashrate first, the rest combined.
    readonly property var typen: {
        var ua = ((root.info && root.info.userAgents) || []).slice();
        ua.sort(function (a, b) {
            return root.zahl(b.totalHashRate) - root.zahl(a.totalHashRate);
        });
        var out = [], rest = 0, restN = 0;
        for (var i = 0; i < ua.length; i++) {
            if (i < 5)
                out.push({ "name": ua[i].userAgent || "?", "n": parseInt(ua[i].count, 10) || 0,
                           "h": root.zahl(ua[i].totalHashRate) });
            else {
                rest += root.zahl(ua[i].totalHashRate);
                restN += parseInt(ua[i].count, 10) || 0;
            }
        }
        if (rest > 0)
            out.push({ "name": Tr.t("net.others", root.lang), "n": restN, "h": rest });
        return out;
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

    // The devices under the address, as the pool lists them. A worker the pool
    // has not heard from for ten minutes counts as gone, and so does one it saw
    // a moment ago but credits with no hashrate.
    readonly property var arbeiter: {
        var w = (root.client && root.client.workers) || [];
        var out = [];
        for (var i = 0; i < w.length; i++) {
            var zuletzt = Date.parse(w[i].lastSeen) / 1000;
            var alter = isFinite(zuletzt) ? root.jetzt - zuletzt : Infinity;
            out.push({ "name": w[i].name || "–", "h": root.zahl(w[i].hashRate),
                       "best": root.zahl(w[i].bestDifficulty), "alter": alter,
                       "aktiv": alter < 600 && root.zahl(w[i].hashRate) > 0 });
        }
        out.sort(function (a, b) {
            return b.h - a.h;
        });
        return out;
    }
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

            // Which devices mine here, by share of the hashrate.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.typen.length > 0

                Text {
                    text: Tr.t("pool.deviceTypes", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Repeater {
                    model: root.typen

                    Item {
                        id: typ

                        required property var modelData

                        width: parent.width
                        height: root.scaleUnit * 0.95

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        Rectangle {
                            width: parent.width * Math.max(0.005, Math.min(1, typ.modelData.h / Math.max(1, root.poolHash)))
                            height: parent.height
                            radius: 3
                            color: root.accentColor
                            opacity: 0.55
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: root.scaleUnit * 0.3
                            anchors.verticalCenter: parent.verticalCenter
                            text: typ.modelData.name + " · " + Tr.group(typ.modelData.n, root.lang)
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.5
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: root.scaleUnit * 0.3
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.anteil(typ.modelData.h, root.poolHash)
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.5
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
