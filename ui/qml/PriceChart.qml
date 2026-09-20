// Der Kursverlauf: eine Linie mit Zeitraumwahl und Ablesen am Zeiger.
//
// Die Daten kommen ausgeduennt herein -- hoechstens 360 Punkte, egal ob der
// Zeitraum ein Tag oder sechzehn Jahre ist. Ausgeduennt wird im Dienst
// (`price_series`) oder im Direktbezug (`DirectFeed.__preisReihe`), nie hier:
// eine Kurve von 800 Punkten Breite hat von 33.299 Punkten nichts, und das
// `JSON.parse` der Vollform kostete gemessen 6 % CPU.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    property string lang: "de"
    property string currency: "eur"
    // 24h | 7d | 30d | 90d | 1y | max -- der Wirt haelt ihn, damit er ueber
    // Sitzungen bleibt
    property string span: "30d"
    // Sieht niemand hin, wird auch nichts geholt
    property bool live: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12
    // Mindesthoehe der Tippflaeche der Zeitraum-Knoepfe, 0 = wie gezeichnet
    property real minTap: 0

    signal spanRequested(string s)

    readonly property var spans: [
        { "k": "24h", "l": Tr.t("price.24h", root.lang) },
        { "k": "7d", "l": Tr.t("price.7d", root.lang) },
        { "k": "30d", "l": Tr.t("price.30d", root.lang) },
        { "k": "90d", "l": Tr.t("price.90d", root.lang) },
        { "k": "1y", "l": Tr.t("price.1y", root.lang) },
        { "k": "max", "l": Tr.t("price.max", root.lang) }
    ]

    property var punkte: []
    property bool laden: false
    property string fehler: ""
    property bool umgerechnet: false

    readonly property string zeichen: Money.symbol(root.currency)
    readonly property real minWert: {
        var m = Infinity;
        for (var i = 0; i < root.punkte.length; i++)
            m = Math.min(m, root.punkte[i][1]);
        return m === Infinity ? 0 : m;
    }
    readonly property real maxWert: {
        var m = -Infinity;
        for (var i = 0; i < root.punkte.length; i++)
            m = Math.max(m, root.punkte[i][1]);
        return m === -Infinity ? 0 : m;
    }
    // Veraenderung ueber den Zeitraum, in Prozent
    readonly property real wandel: {
        if (root.punkte.length < 2)
            return 0;
        var a = root.punkte[0][1], b = root.punkte[root.punkte.length - 1][1];
        return a ? (b - a) / a * 100 : 0;
    }

    // **Nur die letzte Anfrage zaehlt.** Beim Start fragt der Graph mit der
    // Vorgabe "30d", bevor die Einstellungen geladen sind, und gleich danach
    // mit dem gespeicherten Zeitraum. Im Direktbezug laedt jede der beiden
    // den ganzen Datensatz (1,5 MB), und welche zuletzt ankommt, gewann: am
    // 10.09.2026 stand auf dem Telefon "90 T" gewaehlt ueber dreissig Tagen.
    property int __anfrage: 0

    function holen() {
        if (!root.feed || !root.live)
            return;
        root.laden = true;
        var nr = ++root.__anfrage;
        root.feed.prices(root.span, root.currency, function (d, err) {
            if (nr !== root.__anfrage)
                return;
            root.laden = false;
            if (err || !d) {
                root.fehler = err || "nicht erreichbar";
                return;
            }
            root.fehler = "";
            root.umgerechnet = d.converted === true;
            root.punkte = d.points || [];
            leinwand.requestPaint();
        });
    }

    onSpanChanged: root.holen()
    onCurrencyChanged: root.holen()
    onLiveChanged: if (root.live) root.holen()
    Component.onCompleted: root.holen()

    // Der obere Rand wandert; unten aendert sich nichts mehr. Fuenf Minuten
    // reichen -- der Dienst holt selbst nur stuendlich nach.
    Timer {
        interval: 300000
        repeat: true
        running: root.live && root.visible
        onTriggered: root.holen()
    }

    // ------------------------------------------------------- Zeitraumwahl
    // **Passen Kopf und Knoepfe nicht nebeneinander, kommen die Knoepfe in
    // eine eigene Zeile darunter.** Seit sie am Telefon fuer den Finger
    // groesser sind (10.09.2026), lagen sie hochkant ueber dem Kurs: "24 Std"
    // stand quer auf "77.219 $".
    readonly property bool gestapelt: kopf.width + wahl.schalterBreite + root.baseFont > root.width

    TileGoggles {
        id: wahl

        anchors.right: parent.right
        anchors.top: root.gestapelt ? kopf.bottom : parent.top
        anchors.topMargin: root.gestapelt ? root.baseFont * 0.5 : 0
        width: Math.min(parent.width, root.baseFont * 22)
        alignRight: true
        modes: root.spans
        mode: root.span
        // Die Zeitraeume brauchen keine Beschriftung -- "24 Std" sagt genug
        labelKey: ""
        counts: []
        total: 0
        lang: root.lang
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.baseFont
        minTap: root.minTap
        onPicked: function (m) {
            root.spanRequested(m);
        }
    }

    // ------------------------------------------------------------ Kopfzeile
    //
    // **Flach wird nebeneinander.** Gestapelt kostet der Kopf zwei Zeilen, und
    // die fehlen der Kurve: im Dashboard-Tab blieben ihr davon noch vierzig
    // Punkte, Hoechst- und Tiefstwert lagen uebereinander.
    readonly property bool flach: root.height < 200

    Grid {
        id: kopf

        anchors.left: parent.left
        anchors.top: parent.top
        columns: root.flach ? 2 : 1
        rowSpacing: 1
        columnSpacing: root.baseFont * 0.6
        verticalItemAlignment: Grid.AlignVCenter

        Text {
            text: root.punkte.length
                  ? Tr.price1(root.punkte[root.punkte.length - 1][1], root.zeichen, root.lang)
                  : "–"
            color: root.textColor
            font.pixelSize: root.baseFont * (root.flach ? 1.2 : 1.5)
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.punkte.length > 1
            // Zwei Nachkommastellen an einer fuenfstelligen Prozentzahl sind
            // Rauschen -- ueber hundert Prozent werden sie weggelassen.
            text: (root.wandel >= 0 ? "+" : "−")
                  + Tr.fixed(Math.abs(root.wandel),
                             Math.abs(root.wandel) >= 100 ? 0 : 2, root.lang) + " %"
            color: root.wandel >= 0 ? "#5cb946" : "#d33f3f"
            font.pixelSize: root.baseFont - 1
        }
    }

    // --------------------------------------------------------------- Kurve
    Canvas {
        id: leinwand

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Kopfzeile links und Zeitraumwahl rechts stehen nebeneinander und
        // sind verschieden hoch. Ohne das Maximum schob sich der Hoechstwert
        // der Kurve unter die Prozentangabe.
        anchors.topMargin: (root.gestapelt ? kopf.height + root.baseFont * 0.5 + wahl.height
                                           : Math.max(kopf.height, wahl.height))
                           + root.baseFont * 0.6
        antialiasing: true

        // Breit genug fuer die laengste Beschriftung, gemessen statt geraten:
        // "69.660 €" ist bei grosser Schrift dreimal so breit wie eine feste
        // Zahl von Zeichen vermuten laesst, und die Kurve lief darunter durch.
        readonly property real padL: mass.implicitWidth + 6
        readonly property real padR: 2
        readonly property real padT: root.baseFont * 0.8
        readonly property real padB: root.baseFont * 1.6

        function xBei(i) {
            var n = root.punkte.length;
            if (n < 2)
                return padL;
            return padL + (width - padL - padR) * i / (n - 1);
        }

        function yBei(v) {
            var lo = root.minWert, hi = root.maxWert;
            if (hi <= lo)
                return height / 2;
            return padT + (height - padT - padB) * (1 - (v - lo) / (hi - lo));
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var n = root.punkte.length;
            if (n < 2)
                return;

            // **Feine Linien auf runden Betraegen, zur Orientierung.**
            // Gewuenscht am 10.09.2026: "alle 5000 $ eine feine Linie". Die
            // Schrittweite ist gerechnet, nicht fest -- fest 5000 gaebe im
            // Tagesverlauf keine einzige Linie und bei "Max" zwei Dutzend.
            // Genommen wird die kleinste runde Weite (1, 2, 2,5 oder 5 mal
            // einer Zehnerpotenz) fuer hoechstens rund fuenf Linien; bei
            // 62.553 bis 81.476 $ sind das genau 5000. Blasser als die
            // Grundlinien, damit die Kurve nicht in einem Gitter untergeht.
            var schritt = root.rasterSchritt(root.minWert, root.maxWert);
            if (schritt > 0) {
                ctx.strokeStyle = Qt.rgba(root.dimColor.r, root.dimColor.g,
                                          root.dimColor.b, 0.14);
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (var v = Math.ceil(root.minWert / schritt) * schritt;
                     v < root.maxWert; v += schritt) {
                    var ry = Math.round(yBei(v)) + 0.5;
                    // Nicht auf die Grundlinien oben und unten legen
                    if (ry - padT < 4 || height - padB - ry < 4)
                        continue;
                    ctx.moveTo(padL, ry);
                    ctx.lineTo(width - padR, ry);
                }
                ctx.stroke();

                // Beschriftet, links wie Hoechst- und Tiefstwert, aber
                // leichter als diese: sie sind Orientierung, keine Aussage.
                // Liegt eine zu nah an den Grenzwerten, bleibt sie ohne
                // Zahl -- zwei Beschriftungen uebereinander liest niemand.
                ctx.fillStyle = Qt.rgba(root.dimColor.r, root.dimColor.g,
                                        root.dimColor.b, 0.5);
                ctx.font = (root.baseFont - 3) + "px " + Fonts.sansCss();
                ctx.textAlign = "left";
                for (var w = Math.ceil(root.minWert / schritt) * schritt;
                     w < root.maxWert; w += schritt) {
                    var ly = yBei(w);
                    if (ly - padT < root.baseFont * 1.1 || height - padB - ly < root.baseFont * 1.1)
                        continue;
                    ctx.fillText(Tr.price1(w, root.zeichen, root.lang), 0,
                                 ly + (root.baseFont - 3) * 0.35);
                }
            }

            // Grundlinien oben und unten: Hoechst- und Tiefstwert.
            ctx.strokeStyle = root.lineColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(padL, padT + 0.5);
            ctx.lineTo(width - padR, padT + 0.5);
            ctx.moveTo(padL, height - padB - 0.5);
            ctx.lineTo(width - padR, height - padB - 0.5);
            ctx.stroke();

            // Flaeche unter der Kurve, nach unten auslaufend
            var g = ctx.createLinearGradient(0, padT, 0, height - padB);
            g.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                      root.accentColor.b, 0.28));
            g.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                      root.accentColor.b, 0));
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.moveTo(xBei(0), height - padB);
            for (var i = 0; i < n; i++)
                ctx.lineTo(xBei(i), yBei(root.punkte[i][1]));
            ctx.lineTo(xBei(n - 1), height - padB);
            ctx.closePath();
            ctx.fill();

            ctx.strokeStyle = root.accentColor;
            ctx.lineWidth = 1.6;
            ctx.lineJoin = "round";
            ctx.beginPath();
            for (var k = 0; k < n; k++) {
                if (k === 0)
                    ctx.moveTo(xBei(k), yBei(root.punkte[k][1]));
                else
                    ctx.lineTo(xBei(k), yBei(root.punkte[k][1]));
            }
            ctx.stroke();

            // Hoechst- und Tiefstwert an den linken Rand
            ctx.fillStyle = root.dimColor;
            ctx.font = (root.baseFont - 2) + "px " + Fonts.sansCss();
            ctx.textAlign = "left";
            ctx.fillText(Tr.price1(root.maxWert, root.zeichen, root.lang), 0, padT + root.baseFont * 0.7);
            ctx.fillText(Tr.price1(root.minWert, root.zeichen, root.lang), 0, height - padB - 2);

            // Anfang und Ende der Zeitachse
            ctx.textAlign = "left";
            ctx.fillText(root.datum(root.punkte[0][0]), padL, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.datum(root.punkte[n - 1][0]), width - padR, height - 2);
        }
    }

    // Nur zum Messen: dieselbe Schrift, derselbe Text wie die Beschriftung am
    // linken Rand der Kurve.
    Text {
        id: mass

        visible: false
        text: Tr.price1(root.maxWert || 88888, root.zeichen, root.lang)
        // Dieselbe Schrift wie auf der Leinwand -- siehe MarketView.qml:
        // gemessen mit der Standardschrift, gezeichnet mit `Fonts.sansCss()`,
        // und unter Ubuntu und Fedora ist das nicht dieselbe.
        font.family: Fonts.sans()
        font.pixelSize: root.baseFont - 2
    }

    // Runde Schrittweite fuer die feinen Linien, siehe onPaint
    function rasterSchritt(lo, hi) {
        var spanne = hi - lo;
        if (!(spanne > 0))
            return 0;
        // Hoechstens rund fuenf Linien. Mit vier waren es bei neunzig Tagen
        // (58.348 bis 81.272 $) nur 10.000er-Schritte und eine einzige
        // beschriftete Linie; gewuenscht war "alle 5000 $".
        var roh = spanne / 5;
        var zehner = Math.pow(10, Math.floor(Math.log(roh) / Math.LN10));
        var stufen = [1, 2, 2.5, 5, 10];
        for (var i = 0; i < stufen.length; i++) {
            if (stufen[i] * zehner >= roh)
                return stufen[i] * zehner;
        }
        return 10 * zehner;
    }

    function datum(ts) {
        var d = new Date(ts * 1000);
        // Im Tagesverlauf sagt ein Datum nichts -- dort zaehlt die Uhrzeit
        return Qt.formatDateTime(d, root.span === "24h" ? "HH:mm" : Tr.datum(root.lang));
    }

    // ------------------------------------------------- Ablesen am Zeiger
    property int zeigerIndex: -1

    MouseArea {
        anchors.fill: leinwand
        hoverEnabled: true
        onPositionChanged: function (m) {
            var n = root.punkte.length;
            if (n < 2) {
                root.zeigerIndex = -1;
                return;
            }
            var t = (m.x - leinwand.padL) / Math.max(1, leinwand.width - leinwand.padL - leinwand.padR);
            root.zeigerIndex = Math.max(0, Math.min(n - 1, Math.round(t * (n - 1))));
        }
        onExited: root.zeigerIndex = -1
    }

    Rectangle {
        visible: root.zeigerIndex >= 0
        x: leinwand.x + leinwand.xBei(root.zeigerIndex)
        y: leinwand.y + leinwand.padT
        width: 1
        height: leinwand.height - leinwand.padT - leinwand.padB
        color: root.dimColor
        opacity: 0.6
    }

    Rectangle {
        id: punktMarke

        visible: root.zeigerIndex >= 0
        width: 7
        height: 7
        radius: 4
        color: root.accentColor
        x: leinwand.x + leinwand.xBei(root.zeigerIndex) - 3.5
        y: leinwand.y + leinwand.yBei(root.punkte[root.zeigerIndex] ? root.punkte[root.zeigerIndex][1] : 0) - 3.5
    }

    Column {
        visible: root.zeigerIndex >= 0 && root.punkte[root.zeigerIndex] !== undefined
        x: Math.max(0, Math.min(root.width - width,
                                leinwand.x + leinwand.xBei(root.zeigerIndex) - width / 2))
        y: leinwand.y
        spacing: 0

        Text {
            text: root.punkte[root.zeigerIndex]
                  ? Tr.price1(root.punkte[root.zeigerIndex][1], root.zeichen, root.lang) : ""
            color: root.textColor
            font.pixelSize: root.baseFont
            font.weight: Font.DemiBold
        }

        Text {
            text: root.punkte[root.zeigerIndex]
                  ? Qt.formatDateTime(new Date(root.punkte[root.zeigerIndex][0] * 1000),
                                      root.span === "24h" ? Tr.datumOhneJahr(root.lang) + " HH:mm"
                                                          : Tr.datum(root.lang))
                  : ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }
    }

    // ------------------------------------------------------------ Hinweise
    Text {
        anchors.centerIn: parent
        visible: root.laden && !root.punkte.length
        text: Tr.t("price.loading", root.lang)
        color: root.dimColor
        font.pixelSize: root.baseFont
    }

    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: root.fehler !== "" && !root.punkte.length
        text: Tr.t("price.failed", root.lang, Tr.grund(root.fehler, root.lang))
        color: root.dimColor
        font.pixelSize: root.baseFont - 1
    }

    // Die fuenf Waehrungen ausser EUR und USD stehen nicht im Datensatz --
    // sie entstehen aus dem Dollarwert mit dem **heutigen** Wechselkurs. Ueber
    // Jahre ist das eine Umrechnung, keine Wahrheit; also steht es dabei.
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: root.umgerechnet && root.punkte.length > 0
        text: Tr.t("price.converted", root.lang)
        color: root.dimColor
        font.pixelSize: root.baseFont - 3
        opacity: 0.8
    }
}
