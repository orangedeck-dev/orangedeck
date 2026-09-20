// Eigene Miner. Zeigt, was die Geraete melden, und stellt die erreichte
// Schwierigkeit der des Netzes gegenueber -- das ist die Zahl, um die es beim
// Solomining eigentlich geht.
//
// Bewusst **nicht** auf ein Geraet festgelegt: der Daemon spricht AxeOS
// (Bitaxe, NerdAxe und die uebrigen ESP-Miner-Abkoemmlinge) und die
// cgminer-Schnittstelle (Antminer, Avalon, Whatsminer und Nachbauten) und
// liefert beides normalisiert, Hashrate in H/s. Mehrere Geraete zugleich sind
// vorgesehen.
//
// **Zwei Seiten seit dem 11.09.2026: "Geraet" und "Netz".** Die zweite zeigt
// Hashrate, Schwierigkeit, Blockzeit und Pools des ganzen Netzes
// (`NetworkView`). Damit hat der Reiter auch ohne eigenen Miner einen Inhalt
// -- vorher blieb er auf dem Telefon ohne eingetragene Adresse ganz weg. Ist
// kein Geraet eingetragen, gibt es nur das Netz und keinen Umschalter.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Tastatur: Bild auf/ab, Pos1, Ende -- im Netzwerk-Bereich rollt dessen
    // Flaeche, am Geraet die eigene (roll.js; aus Main.qml ueber FeedTabs)
    function rollen(wie) {
        return root.paneNow === "net" ? netz.rollen(wie) : Roll.rollen(flick, wie);
    }

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    // Bedienung mit dem Finger: groessere Knoepfe am Netz-Graphen
    property bool finger: false
    // Sieht niemand hin, holt die Netz-Seite nichts
    property bool live: true

    // Welche Seite oben liegt: "device", "net", oder leer fuer "von selbst" --
    // das Geraet, wenn eines eingetragen ist. Der Wirt haelt die Wahl.
    property string pane: ""
    property string netSpan: "1y"
    signal paneRequested(string p)
    signal netSpanRequested(string s)

    // Welche Seiten es ueberhaupt gibt -- aus den Einstellungen, leer heisst
    // beide. Ohne "Geraet" zeigt der Reiter nur das Netz, auch wenn ein
    // Miner eingetragen ist; ohne eingetragenen Miner gibt es ohnehin nur das
    // Netz. Ist das Netz abgewaehlt und kein Geraet da, bleibt es trotzdem:
    // eine leere Seite hilft niemandem.
    property var panes: []
    function erlaubt(p) {
        var v = root.panes;
        if (!v || !v.length || typeof v.indexOf !== "function")
            return true;
        return v.indexOf(p) >= 0;
    }
    readonly property bool mitGeraet: root.configured && root.erlaubt("device")
    readonly property bool mitNetz: root.erlaubt("net") || !root.mitGeraet
    readonly property bool zweiSeiten: root.mitGeraet && root.mitNetz
    readonly property string paneNow: !root.mitGeraet ? "net"
                                    : !root.mitNetz ? "device"
                                    : (root.pane === "net" ? "net" : "device")
    // Die Solo-Chance beim Geraet, abschaltbar wie Kurve und Bestenliste
    property bool showSolo: true
    // Was die Netz-Seite zeigt: "stats", "chart", "pools", leer heisst alles
    property var netParts: []

    readonly property var miners: feed ? feed.miners : []
    readonly property var total: feed ? feed.minerTotal : ({})
    readonly property bool configured: feed ? feed.minerConfigured : false
    readonly property bool anyOnline: feed ? feed.minerOnline : false
    readonly property real netDiff: (feed && feed.hashrate.difficulty) || 0
    readonly property real netHash: (feed && feed.hashrate.current) || 0
    readonly property real bestShare: (netDiff > 0 && total.bestDiff)
        ? total.bestDiff / netDiff : 0

    // **Die Solo-Chance.** Eigene Hashrate durch die des Netzes ist der Anteil
    // an jedem Block; bei 144 Bloecken am Tag ergibt das die Chance pro Tag
    // und ihren Kehrwert, die mittlere Wartezeit. Beides sind Erwartungswerte
    // eines Zufalls ohne Gedaechtnis -- nach tausend Jahren ist die Chance
    // fuer den naechsten Tag dieselbe.
    readonly property real soloAnteil: (root.netHash > 0 && root.total.hashRate > 0)
        ? root.total.hashRate / root.netHash : 0
    readonly property real soloTag: root.soloAnteil * 144

    // "16.600 Jahre", "64 Tage", "5 Std 20 Min"
    function warte(tage) {
        if (!(tage > 0) || !isFinite(tage))
            return "–";
        if (tage >= 730) {
            var jahre = tage / 365.25;
            return Tr.t("duration.years", root.lang,
                        jahre >= 1e6 ? Tr.big(jahre, root.lang) : Tr.group(jahre, root.lang));
        }
        if (tage >= 2)
            return Tr.t("duration.days", root.lang, Tr.group(tage, root.lang));
        return root.span(tage * 86400);
    }
    // Bei genau einem Geraet ist Platz fuer die Einzelheiten
    readonly property var one: (miners.length === 1 && miners[0].online) ? miners[0] : null
    readonly property var oneHist: (one && feed) ? (feed.minerHistory[one.id] || ({})) : ({})
    // Seit der Inhalt rollbar ist, muss nichts mehr wegen Platzmangel
    // wegbleiben. Die Schwellen halten nur noch das ganz kleine
    // Desktop-Widget frei, wo Kurve und Liste sinnlos waeren.
    // Hat der Wirt schon eine Knopfleiste (im Dashboard die von DMS), stellt
    // er die Knoepfe selbst und schaltet unsere ab. Sie sitzen dann in der
    // obersten Zeile, wo nichts sie ueberdecken kann.
    property bool showActions: true
    // Fuer den Wirt: Legende auf- und zuklappen
    function toggleInfo() {
        info.open = !info.open;
    }
    // Weboberflaeche des Geraets oeffnen. Gilt fuer jeden Miner, der eine hat.
    //
    // **Mit Schema.** Die Kennung ist die Adresse, wie sie eingetragen wurde
    // -- am Telefon oft ohne "http://". `DirectMiner` setzt es fuer die
    // Abfragen selbst davor (`basis()`), hier fehlte es: Qt las die blanke
    // Adresse als Pfad relativ zur QML-Datei, und Android meldete
    // "No Activity found to handle Intent { dat=qrc:/... }". Der Pfeil tat
    // am Galaxy A55 nichts (11.09.2026).
    readonly property string webUrl: {
        if (!(root.one && root.one.type === "axeos"))
            return "";
        var u = String(root.one.id).trim();
        return u.indexOf("://") < 0 ? "http://" + u : u;
    }
    function openWeb() {
        if (webUrl)
            Qt.openUrlExternally(webUrl);
    }
    readonly property bool roomForChart: height > 200
    // Ueber wie viele Minuten die Rechenwerke gemittelt sind: eine Messung je
    // fuenf Sekunden, im Daemon wie in `DirectMiner`
    readonly property real domainMin: root.one && root.one.domainSamples
        ? root.one.domainSamples * 5 / 60 : 0

    // Welche Kennzahlen ueberhaupt gezeigt werden. Leere Liste heisst alle --
    // die Auswahl kommt aus den Einstellungen, hier steht nur der Filter.
    property var metricKeys: []
    property bool showChart: true
    property bool showDomains: true
    property bool showBoard: true
    property string lang: "de"

    readonly property var metrics: {
        var m = root.one;
        if (!m)
            return [];
        var alle = [
            { "id": "temp", "k": Tr.t("miner.temp", root.lang), "v": (m.temp !== undefined && m.temp !== null)
                ? Math.round(m.temp) + " °C" : "–" },
            { "id": "power", "k": Tr.t("miner.power", root.lang), "v": m.power
                ? Tr.fixed(m.power, 1, root.lang) + " W" : "–" },
            { "id": "fan", "k": Tr.t("miner.fan", root.lang), "v": m.fanRpm ? Tr.t("miner.rpm", root.lang, m.fanRpm) : "–" },
            { "id": "error", "k": Tr.t("miner.errorRate", root.lang), "v": (m.errorPct !== undefined && m.errorPct !== null)
                ? Tr.fixed(m.errorPct, 1, root.lang) + " %" : "–" },
            { "id": "shares", "k": Tr.t("miner.shares", root.lang), "v": m.shares !== undefined
                ? (m.rejected ? Tr.t("miner.rejected", root.lang, m.shares, m.rejected)
                              : String(m.shares)) : "–" },
            { "id": "uptime", "k": Tr.t("miner.uptime", root.lang), "v": root.span(m.uptime) }
        ];
        var mk = root.metricKeys;
        if (!mk || !mk.length || typeof mk.indexOf !== "function")
            return alle;
        return alle.filter(function (x) {
            return mk.indexOf(x.id) >= 0;
        });
    }

    // Ab sechs Kennzahlen auf Zeilen zu je drei verteilen, darunter eine Zeile.
    readonly property var metricRows: {
        var m = root.metrics;
        if (m.length < 6)
            return m.length ? [m] : [];
        var out = [];
        for (var i = 0; i < m.length; i += 3)
            out.push(m.slice(i, i + 3));
        return out;
    }
    readonly property bool roomForBoard: height > 240

    function big(n, unit) {
        if (!n)
            return "–";
        var u = ["", "k", "M", "G", "T", "P", "E"], i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return Tr.fixed(n, n >= 100 ? 0 : 2, root.lang)
             + " " + u[i] + (unit || "");
    }

    function span(sec) {
        if (!sec)
            return "–";
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600),
            m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
    }

    // Zu den Einstellungen geht es in der Weboberflaeche des Geraets -- die
    // bleiben dort, hier wird nur angezeigt. Nur ein Zeichen, keine
    // Beschriftung: so passt der Knopf fuer jeden Miner.
    // Alle Erklaerungen an einem Ort, statt sie in die Flaeche zu streuen
    InfoPopup {
        id: info

        anchors.fill: parent
        buttonMargin: 0
        showButton: root.showActions
        fontSize: root.scaleUnit * 0.72
        textColor: root.textColor
        dimColor: root.dimColor
        lang: root.lang
        title: Tr.t("miner.whatIsThis", root.lang)
        // Die Erklaerungen der Seite, die gerade oben liegt
        entries: root.paneNow === "net" ? [
            {
                "color": root.accentColor,
                "k": Tr.t("hashrate", root.lang),
                "v": Tr.t("net.hashHelp", root.lang)
            },
            {
                "color": netz.diffColor,
                "thin": true,
                "k": Tr.t("difficulty", root.lang),
                "v": Tr.t("net.diffHelp", root.lang)
            },
            {
                "k": Tr.t("pool", root.lang),
                "v": Tr.t("net.poolsHelp", root.lang)
            }
        ] : [
            {
                "color": root.accentColor,
                "thin": true,
                "k": Tr.t("miner.hashNow", root.lang),
                "v": Tr.t("miner.hashNowHelp", root.lang)
            },
            {
                "color": root.accentColor,
                "k": Tr.t("miner.hashAvg", root.lang),
                "v": Tr.t("miner.hashAvgHelp", root.lang)
            },
            {
                "color": root.textColor,
                "k": Tr.t("miner.temp", root.lang),
                "v": Tr.t("miner.tempHelp", root.lang)
            },
            {
                "k": Tr.t("miner.oneToN", root.lang),
                "v": Tr.t("miner.oneToNHelp", root.lang)
            },
            {
                "k": Tr.t("miner.solo", root.lang),
                "v": Tr.t("miner.soloHelp", root.lang)
            },
            {
                "k": Tr.t("miner.domains", root.lang),
                "v": Tr.t("miner.domainsHelp", root.lang)
            },
            {
                "k": Tr.t("miner.errorRate", root.lang),
                "v": Tr.t("miner.errorHelp", root.lang)
            }
        ]
        z: 40
    }

    Rectangle {
        id: openBtn

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: info.buttonWidth + root.scaleUnit * 0.4
        visible: root.showActions && root.webUrl !== "" && root.paneNow === "device"
        width: info.buttonWidth
        height: width
        radius: height / 2
        color: openArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 20

        // **Gezeichnet, nicht als Zeichen.** "↗" (U+2197) hat eine
        // Emoji-Darstellung, und Samsung nimmt sie: am Galaxy A55 stand ein
        // blaues Kaestchen mit weissem Pfeil neben dem schlichten "i"
        // (11.09.2026). Strich in Farbe und Staerke des "i" daneben.
        Canvas {
            id: pfeil

            anchors.centerIn: parent
            width: parent.width * 0.42
            height: width
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width, s = Math.max(1.5, w * 0.16), r = s / 2;
                ctx.strokeStyle = root.textColor;
                ctx.lineWidth = s;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(r, w - r);
                ctx.lineTo(w - r, r);
                ctx.moveTo(w * 0.38, r);
                ctx.lineTo(w - r, r);
                ctx.lineTo(w - r, w * 0.62);
                ctx.stroke();
            }
        }

        MouseArea {
            id: openArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWeb()
        }
    }

    // ------------------------------------------------------ Geraet | Netz
    // Nur, wenn es zwei Seiten gibt. Er liegt fest oben, beide Seiten rollen
    // darunter.
    readonly property real kopfHoehe: root.zweiSeiten ? umschalter.height + root.scaleUnit * 0.5 : 0

    TileGoggles {
        id: umschalter

        visible: root.zweiSeiten
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: umschalter.schalterBreite
        modes: [
            { "k": "device", "l": Tr.t("miner.paneDevice", root.lang) },
            { "k": "net", "l": Tr.t("miner.paneNet", root.lang) }
        ]
        mode: root.paneNow
        labelKey: ""
        counts: []
        total: 0
        lang: root.lang
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.finger ? Math.max(15, root.scaleUnit * 0.62) : root.scaleUnit * 0.62
        minTap: root.finger ? 40 : 0
        z: 20
        onPicked: function (m) {
            root.paneRequested(m);
        }
    }

    // ------------------------------------------------------------- Netz
    // Ohne eingetragenes Geraet steht darunter, wie eines dazukommt: auf dem
    // Telefon in den Einstellungen, am Rechner ueber die Suche des Dienstes.
    NetworkView {
        id: netz

        anchors.fill: parent
        visible: root.paneNow === "net"
        live: root.live && root.visible && root.paneNow === "net"
        // Ohne Umschalter beginnt die Seite oben -- dort sitzt der i-Knopf
        // und braucht seine Zeile.
        topInset: root.zweiSeiten ? root.kopfHoehe
                                  : (root.showActions ? info.buttonWidth + root.scaleUnit * 0.3 : 0)
        feed: root.feed
        lang: root.lang
        span: root.netSpan
        parts: root.netParts
        finger: root.finger
        // **Am Finger nicht unter 20.** `scaleUnit` folgt der Breite; hochkant
        // am Telefon sind das rund 16 Punkte, und die Beschriftungen der
        // Kennzahlen und Pools standen in knapp neun. Am Rechner bleibt es,
        // wie es war.
        scaleUnit: root.finger ? Math.max(20, root.scaleUnit) : root.scaleUnit
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        footer: root.configured ? ""
              : (root.feed && root.feed.direkt)
                ? Tr.t("net.addMiner", root.lang, Tr.t("tab.settings", root.lang),
                       Tr.t("tab.miner", root.lang))
                : Tr.t("miner.none", root.lang) + ". " + Tr.t("miner.discover", root.lang)
        footerCommand: (!root.configured && !(root.feed && root.feed.direkt))
            ? "orangedeck --discover-miners --write\nsystemctl --user restart orangedeck" : ""
        onSpanRequested: function (sp) {
            root.netSpanRequested(sp);
        }
    }

    // ------------------------------------------- eingetragen, aber alle aus
    Column {
        anchors.centerIn: parent
        spacing: root.scaleUnit * 0.35
        visible: root.configured && !root.anyOnline && root.paneNow === "device"

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t(root.miners.length === 1 ? "miner.notReachable"
                                               : "miner.unreachable", root.lang)
            color: root.badColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("miner.offNote", root.lang)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }
    }

    // ------------------------------------------------------------- im Betrieb
    // Der Inhalt kann hoeher werden als die Flaeche -- im Dashboard-Tab
    // (410 px) reicht es nicht fuer Kurve, Rechenwerke und Bestenliste
    // zugleich. Deshalb rollbar: passt alles, bleibt es mittig stehen; passt
    // es nicht, laesst es sich schieben.
    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin: root.kopfHoehe
        clip: true
        visible: root.anyOnline && root.paneNow === "device"
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500

        // Schmaler Balken rechts, nur solange es etwas zu rollen gibt
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
                // Mittig, solange Platz ist -- sonst oben anfangen. Am
                // 11.09.2026 kurz oben festgesetzt; mit nur der Geraeteseite
                // hing der Inhalt dann am oberen Rand und die untere Haelfte
                // blieb leer. Zurueck, auf Wunsch des Anwenders.
                y: Math.max(root.scaleUnit * 0.3, (flick.height - implicitHeight) / 2)
                spacing: root.scaleUnit * 0.45

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.total.online > 1
                    ? Tr.t("miner.devices", root.lang, root.total.online)
                    : (root.miners[0] ? root.miners[0].name : Tr.t("miner.title", root.lang))
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.72
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.big(root.total.hashRate, "H/s")
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 2.6
                font.bold: true
            }

            // Die Momentanrate schwankt um rund zehn Prozent -- oben steht deshalb
            // der geglaettete Zehnminutenwert, hier der Vergleich mit dem, was das
            // Geraet bei seiner Taktung erwarten laesst.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.expected
                text: root.one && root.one.expected
                    ? Tr.t("miner.smoothed", root.lang, root.big(root.one.expected, "H/s"))
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            // Der Grund, warum man das ueberhaupt macht
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.blockFound > 0
                width: blockText.width + root.scaleUnit
                height: blockText.height + root.scaleUnit * 0.4
                radius: height / 2
                color: root.goodColor

                Text {
                    id: blockText

                    anchors.centerIn: parent
                    text: root.one && root.one.blockFound > 0
                        ? (root.one.blockFound === 1
                            ? Tr.t("miner.oneBlockFound", root.lang)
                            : Tr.t("miner.blocksFound", root.lang, root.one.blockFound))
                        : ""
                    color: "#0b0b12"
                    font.pixelSize: root.scaleUnit * 0.62
                    font.bold: true
                }
            }

            // Die eigentliche Zahl beim Solomining
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.bestShare", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.total.bestDiff
                        ? Tr.t("miner.ofNet", root.lang, root.big(root.total.bestDiff),
                               root.big(root.netDiff))
                        : "–"
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.bestShare > 0
                    // Winzige Anteile -- "1 zu N" liest sich besser als eine
                    // Prozentzahl mit acht Nullen.
                    text: root.bestShare >= 1
                        ? Tr.t("miner.enoughForBlock", root.lang)
                        : Tr.t("miner.oneInN", root.lang, root.big(1 / root.bestShare))
                    color: root.bestShare >= 1 ? root.goodColor : root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            // Die Chance, dass einer der naechsten Bloecke der eigene ist.
            // Unter einem Block am Tag als "1 zu N pro Tag" mit der mittleren
            // Wartezeit darunter; darueber reicht die Wartezeit allein.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.showSolo && root.soloTag > 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.solo", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.soloTag >= 1
                        ? Tr.t("miner.soloEvery", root.lang, root.warte(1 / root.soloTag))
                        : Tr.t("miner.soloDay", root.lang, root.big(1 / root.soloTag))
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.soloTag > 0 && root.soloTag < 1
                    text: Tr.t("miner.soloEvery", root.lang, root.warte(1 / root.soloTag))
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // --------------------------------------- Einzelheiten, ein Geraet
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2
                visible: root.one !== null

                // Die Kennzahlen. Ab sechs Stueck werden sie auf Zeilen zu je
                // drei verteilt -- in einer Reihe liefen sie im Dashboard ueber
                // den Rand hinaus und die aeusseren beiden wurden abgeschnitten.
                // Bis fuenf bleibt es bei einer Zeile.
                Column {
                    width: parent.width
                    spacing: root.scaleUnit * 0.45

                    Repeater {
                        model: root.metricRows

                        Row {
                            id: zeile

                            required property var modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.scaleUnit * 1.1

                            Repeater {
                                model: zeile.modelData

                                Column {
                                    id: cell

                                    required property var modelData

                                    spacing: root.scaleUnit * 0.1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.k
                                        color: root.dimColor
                                        font.pixelSize: root.scaleUnit * 0.55
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.v
                                        color: root.textColor
                                        font.pixelSize: root.scaleUnit * 0.8
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Nur der Wirt des Pools -- der Benutzername enthaelt beim
                    // Solomining die Auszahlungsadresse und wird nirgends angezeigt.
                    text: root.one
                        ? [root.one.model, root.one.version, root.one.pool].filter(function (x) {
                              return !!x;
                          }).join(" · ")
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }
            }

            // ------------------------------------------------------- Verlauf
            MinerChart {
                width: parent.width
                height: root.scaleUnit * 4.2
                visible: root.showChart && root.one !== null && root.roomForChart
                         && (root.oneHist.hr || []).length > 1
                hist: root.oneHist
                lang: root.lang
                lineColor: root.accentColor
                dimColor: root.dimColor
                labelSize: root.scaleUnit * 0.5
            }

            // **Wo der lange Verlauf herkaeme.** Zeichnet das Geraet nicht
            // selbst auf, reicht der Graph nur so weit zurueck, wie die
            // Anwendung offen ist. Der Schalter liegt in AxeOS, nicht hier:
            // die Anwendung stellt am Miner nichts um, ohne dass man es sieht.
            // `statsFrequency` meldet nur `DirectMiner`; beim Daemon fehlt es,
            // und dort bleibt der Satz weg.
            Text {
                width: parent.width
                visible: root.showChart && root.one !== null && root.roomForChart
                         && root.one.statsFrequency === 0
                text: Tr.t("miner.statsHint", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.45
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            // ------------------------------------------ Rechenwerke einzeln
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.one !== null && (root.one.domains || []).length > 0
                         && root.roomForChart && root.showDomains

                Text {
                    // Der Chip ist intern in Hash-Domaenen geteilt (beim BM1370
                    // vier). Die Einzelmessungen rauschen um ueber zehn Prozent --
                    // gezeigt wird deshalb der geglaettete Wert, sonst sieht
                    // Rauschen wie ein Defekt aus.
                    // Die Minuten in der Schreibweise der Sprache: bis zum
                    // 11.09.2026 stand dort "0.3 Min" mit Punkt, weil die
                    // Zahl roh eingesetzt wurde. Ab einer Minute ganz.
                    text: root.one && root.one.domainSamples
                        ? Tr.t("miner.domainsAvg", root.lang, root.domainMin >= 1
                               ? Math.round(root.domainMin)
                               : Tr.fixed(root.domainMin, 1, root.lang))
                        : Tr.t("miner.domains", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Row {
                    width: parent.width
                    spacing: root.scaleUnit * 0.25

                    Repeater {
                        model: root.one ? (root.one.domainsAvg || root.one.domains) : []

                        Rectangle {
                            id: dom

                            required property var modelData
                            required property int index

                            readonly property var vals: root.one.domainsAvg || root.one.domains || []

                            width: (root.width * 0.9 - root.scaleUnit * 0.75) / Math.max(1, dom.vals.length)
                            height: root.scaleUnit * 0.95
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Rectangle {
                                // Anteil am staerksten Rechenwerk -- so sieht man
                                // sofort, wenn eines abfaellt.
                                width: parent.width * Math.max(0.05, Math.min(1,
                                    dom.modelData / Math.max.apply(null, dom.vals)))
                                height: parent.height
                                radius: parent.radius
                                color: root.accentColor
                                opacity: 0.75
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(dom.modelData) + " GH/s"
                                color: root.textColor
                                font.pixelSize: root.scaleUnit * 0.5
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------- Bestenliste
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.12
                visible: root.showBoard && root.one !== null && root.roomForBoard
                         && (root.one.scoreboard || []).length > 0

                Text {
                    text: Tr.t("miner.bestList", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Repeater {
                    model: root.one ? (root.one.scoreboard || []).slice(0, 5) : []

                    Row {
                        id: sbRow

                        required property var modelData
                        required property int index

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Text {
                            width: root.scaleUnit * 1.2
                            text: (sbRow.index + 1) + "."
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: root.big(sbRow.modelData.diff)
                            color: sbRow.index === 0 ? root.accentColor : root.textColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: root.netDiff > 0
                                ? Tr.t("miner.oneTo", root.lang,
                                       root.big(root.netDiff / sbRow.modelData.diff))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: sbRow.modelData.time
                                ? Qt.formatDate(new Date(sbRow.modelData.time * 1000), Tr.datum(root.lang))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }
                    }
                }
            }

            // ------------------------------------------------ Geraete einzeln
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2

                visible: root.one === null

                Repeater {
                    model: root.miners

                    Row {
                        id: line

                        required property var modelData

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * 0.32
                            height: width
                            radius: width / 2
                            color: line.modelData.online ? root.goodColor : root.badColor
                        }

                        Text {
                            width: root.scaleUnit * 7
                            elide: Text.ElideRight
                            text: line.modelData.name || line.modelData.id
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: line.modelData.online ? root.big(line.modelData.hashRate, "H/s") : Tr.t("miner.off", root.lang)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            visible: line.modelData.online && line.modelData.temp !== undefined
                                     && line.modelData.temp !== null
                            width: root.scaleUnit * 2.4
                            text: line.modelData.temp !== undefined && line.modelData.temp !== null
                                ? Math.round(line.modelData.temp) + " °C" : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            visible: line.modelData.online
                            text: root.span(line.modelData.uptime)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }
                    }
                }
            }
        }
    }
}
