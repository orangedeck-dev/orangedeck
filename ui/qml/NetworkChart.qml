// Das Netz ueber einen Zeitraum: die Hashrate als Flaeche, die Schwierigkeit
// als Treppe darueber -- auf **derselben** Achse.
//
// Die Schwierigkeit D setzt eine Rechenleistung voraus: ein Block braucht im
// Mittel D * 2^32 Versuche und soll alle 600 Sekunden kommen, also
// D * 2^32 / 600 H/s. In diese Einheit umgerechnet liegen beide Groessen auf
// einer Achse, und man sieht, was die Anpassung tut: die Treppe laeuft der
// Flaeche hinterher. mempool.space zeigt zwei Achsen; das laedt dazu ein, zwei
// Kurven zu vergleichen, deren Lage zueinander nur von der Skalierung abhaengt.
//
// Links steht die Hashrate (orange), rechts dieselbe Hoehe als Schwierigkeit
// (hell) -- die Beschriftung traegt die Farbe ihrer Linie, wie in
// `MinerChart`.
//
// Die Daten holt `NetworkView`; hier wird nur gezeichnet und gewaehlt.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property string lang: "de"
    // 30d | 90d | 1y | 3y | max -- der Wirt haelt ihn
    property string span: "1y"
    // [[Zeit, H/s], ...], aufsteigend
    property var reihe: []
    // [[Zeit, Schwierigkeit, Hoehe, Faktor], ...] -- jede Anpassung im Zeitraum
    property var stufen: []
    property bool laden: false
    property string fehler: ""

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color diffColor: "#e8e4f0"
    property color lineColor: "#2a2a38"
    property real baseFont: 12
    property real minTap: 0

    signal spanRequested(string s)

    // H/s je Einheit Schwierigkeit
    readonly property real faktor: 4294967296 / 600

    // Dieselben Knoepfe wie am Kursverlauf, soweit es sie hier gibt. 24
    // Stunden und sieben Tage fehlen: die Reihe hat einen Punkt am Tag.
    readonly property var spans: [
        { "k": "30d", "l": Tr.t("price.30d", root.lang) },
        { "k": "90d", "l": Tr.t("price.90d", root.lang) },
        { "k": "1y", "l": Tr.t("price.1y", root.lang) },
        { "k": "3y", "l": Tr.t("net.3y", root.lang) },
        { "k": "max", "l": Tr.t("price.max", root.lang) }
    ]

    // **Das Mittel ueber sieben Tage ist die Linie, die Tageswerte sind nur
    // Beiwerk.** Die Hashrate eines Tages ist eine Schaetzung aus rund 144
    // Bloecken, und deren Zahl schwankt zufaellig: im ersten Bild vom
    // 11.09.2026 war das Jahr ein Band aus Zacken zwischen 0,85 und
    // 1,31 Tausend EH/s, der Gang darin nicht zu sehen. Gezeichnet wird deshalb
    // wie im Miner-Graphen: der Rohwert duenn und blass, das Mittel kraeftig.
    //
    // Mittig gemittelt, nicht nachlaufend: ein nachlaufendes Mittel kaeme
    // selbst dreieinhalb Tage zu spaet und verfaelschte genau das, was der
    // Graph zeigen soll -- wie die Schwierigkeit der Hashrate folgt. Ist die
    // Reihe ausgeduennt (drei Jahre, alles), liegt schon ein Mittel in jedem
    // Punkt, und das Fenster umfasst nur noch ihn selbst.
    readonly property real fenster: 3.5 * 86400
    readonly property var mittel: {
        var r = root.reihe, out = [];
        var von = 0, bis = 0, summe = 0;
        for (var i = 0; i < r.length; i++) {
            while (bis < r.length && r[bis][0] <= r[i][0] + root.fenster) {
                summe += r[bis][1];
                bis++;
            }
            while (r[von][0] < r[i][0] - root.fenster) {
                summe -= r[von][1];
                von++;
            }
            out.push([r[i][0], summe / (bis - von)]);
        }
        return out;
    }
    // Liegt mehr als ein Tag zwischen zwei Punkten, ist schon gemittelt;
    // dann gibt es keine Tageswerte, die man duenn darunter zeigen koennte.
    readonly property bool mitTageswerten: {
        var r = root.reihe;
        return r.length > 2 && (r[r.length - 1][0] - r[0][0]) / (r.length - 1) < 1.5 * 86400;
    }

    // Die Treppe als Punkte [Zeit, H/s]: am linken Rand der Wert, der dort
    // galt, dann je Anpassung ein Sprung. Der Wert **vor** der ersten
    // Anpassung im Zeitraum steckt in ihrem Faktor -- ohne ihn begaenne die
    // Treppe erst bei der ersten Stufe, bei dreissig Tagen oft erst in der
    // Mitte.
    readonly property var treppe: {
        var r = root.reihe, s = root.stufen;
        if (r.length < 2 || !s.length)
            return [];
        var t0 = r[0][0];
        var anfang = s[0][1] / (s[0][3] || 1);
        var out = [];
        for (var i = 0; i < s.length; i++) {
            if (s[i][0] <= t0)
                anfang = s[i][1];
        }
        out.push([t0, anfang * root.faktor]);
        for (var j = 0; j < s.length; j++) {
            if (s[j][0] > t0)
                out.push([s[j][0], s[j][1] * root.faktor]);
        }
        return out;
    }

    // Die Zeitachse reicht bis zum letzten Wert **beider** Reihen: die
    // Tagesmittel der Hashrate liegen nach dem Ausduennen ein paar Tage vor
    // heute, eine Anpassung von gestern soll trotzdem zu sehen sein.
    readonly property real tAnfang: root.reihe.length ? root.reihe[0][0] : 0
    readonly property real tEnde: {
        var t = root.reihe.length ? root.reihe[root.reihe.length - 1][0] : 0;
        var tr = root.treppe;
        if (tr.length)
            t = Math.max(t, tr[tr.length - 1][0]);
        return t;
    }

    readonly property real minWert: {
        var m = Infinity;
        for (var i = 0; i < root.reihe.length; i++)
            m = Math.min(m, root.reihe[i][1]);
        for (var j = 0; j < root.treppe.length; j++)
            m = Math.min(m, root.treppe[j][1]);
        return m === Infinity ? 0 : m;
    }
    readonly property real maxWert: {
        var m = -Infinity;
        for (var i = 0; i < root.reihe.length; i++)
            m = Math.max(m, root.reihe[i][1]);
        for (var j = 0; j < root.treppe.length; j++)
            m = Math.max(m, root.treppe[j][1]);
        return m === -Infinity ? 0 : m;
    }

    // **Ueber die ganze Geschichte logarithmisch.** Von 7 kH/s im Januar 2009
    // bis 900 EH/s heute sind siebzehn Zehnerpotenzen; linear waeren die
    // ersten elf Jahre ein Strich auf der Grundlinie. Ab drei Zehnerpotenzen
    // Spanne wird umgeschaltet -- in drei Jahren sind es keine zwei.
    readonly property bool logAchse: root.minWert > 0 && root.maxWert / root.minWert > 1000

    // Veraenderung ueber den Zeitraum. Ueber alles waere es eine Zahl mit
    // achtzehn Stellen, dort bleibt sie weg.
    // Aus dem Mittel: zwei einzelne Tage an den Raendern waeren Zufall.
    readonly property real wandel: {
        var r = root.mittel;
        if (r.length < 2 || root.logAchse)
            return 0;
        var a = r[0][1], b = r[r.length - 1][1];
        return a ? (b - a) / a * 100 : 0;
    }

    onReiheChanged: leinwand.requestPaint()
    onStufenChanged: leinwand.requestPaint()

    // ------------------------------------------------------- Zeitraumwahl
    // Wie am Kursverlauf: passen Kopf und Knoepfe nicht nebeneinander, kommen
    // die Knoepfe in eine eigene Zeile darunter.
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
    // Welche Linie was ist, in ihrer Farbe -- eine Legende in einer Zeile.
    Row {
        id: kopf

        anchors.left: parent.left
        anchors.top: parent.top
        spacing: root.baseFont * 0.5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Tr.t("hashrate", root.lang)
            color: root.accentColor
            font.pixelSize: root.baseFont
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.reihe.length > 1 && !root.logAchse
            text: (root.wandel >= 0 ? "+" : "−")
                  + Tr.fixed(Math.abs(root.wandel),
                             Math.abs(root.wandel) >= 100 ? 0 : 1, root.lang) + " %"
            color: root.wandel >= 0 ? "#5cb946" : "#d33f3f"
            font.pixelSize: root.baseFont - 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.treppe.length > 0
            text: "· " + Tr.t("difficulty", root.lang)
            color: root.diffColor
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
        anchors.topMargin: (root.gestapelt ? kopf.height + root.baseFont * 0.5 + wahl.height
                                           : Math.max(kopf.height, wahl.height))
                           + root.baseFont * 0.6
        antialiasing: true

        // Links die Hashrate, rechts die Schwierigkeit -- beide gemessen,
        // nicht geraten (siehe PriceChart).
        readonly property real padL: massL.implicitWidth + 6
        readonly property real padR: massR.implicitWidth + 6
        readonly property real padT: root.baseFont * 0.8
        readonly property real padB: root.baseFont * 1.6

        function xBei(t) {
            var spanne = root.tEnde - root.tAnfang;
            if (spanne <= 0)
                return padL;
            return padL + (width - padL - padR) * (t - root.tAnfang) / spanne;
        }

        function anteil(v) {
            var lo = root.minWert, hi = root.maxWert;
            if (root.logAchse) {
                if (v <= 0)
                    return 0;
                return (Math.log(v) - Math.log(lo)) / (Math.log(hi) - Math.log(lo));
            }
            return hi > lo ? (v - lo) / (hi - lo) : 0.5;
        }

        function yBei(v) {
            return padT + (height - padT - padB) * (1 - anteil(v));
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var r = root.reihe, n = r.length;
            if (n < 2)
                return;
            var unten = height - padB;

            // Feine Linien: linear auf runden Betraegen (wie am Kursverlauf),
            // logarithmisch auf jeder Tausenderstufe -- genau dort wechselt
            // der Vorsatz, 1 PH/s, 1 EH/s.
            var linien = root.logAchse ? root.stufenLog(root.minWert, root.maxWert)
                                       : root.stufenLinear(root.minWert, root.maxWert);
            ctx.strokeStyle = Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.14);
            ctx.lineWidth = 1;
            ctx.beginPath();
            var beschriftet = [];
            for (var g = 0; g < linien.length; g++) {
                var ry = Math.round(yBei(linien[g])) + 0.5;
                if (ry - padT < 4 || unten - ry < 4)
                    continue;
                ctx.moveTo(padL, ry);
                ctx.lineTo(width - padR, ry);
                // Zu nah an Hoechst- oder Tiefstwert bleibt die Linie ohne
                // Zahl: am Telefon standen "1.306" und "1.200 EH/s" sonst
                // ineinander.
                if (ry - padT >= root.baseFont * 1.5 && unten - ry >= root.baseFont * 1.5)
                    beschriftet.push([linien[g], ry]);
            }
            ctx.stroke();
            ctx.fillStyle = Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.5);
            ctx.font = (root.baseFont - 3) + "px " + Fonts.sansCss();
            ctx.textAlign = "left";
            for (var b = 0; b < beschriftet.length; b++)
                ctx.fillText(root.achsText(beschriftet[b][0]), 0,
                             beschriftet[b][1] + (root.baseFont - 3) * 0.35);

            // Grundlinien oben und unten
            ctx.strokeStyle = root.lineColor;
            ctx.beginPath();
            ctx.moveTo(padL, padT + 0.5);
            ctx.lineTo(width - padR, padT + 0.5);
            ctx.moveTo(padL, unten - 0.5);
            ctx.lineTo(width - padR, unten - 0.5);
            ctx.stroke();

            // Die Tageswerte duenn und blass -- nur, wo es welche gibt
            if (root.mitTageswerten) {
                ctx.strokeStyle = Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0.3);
                ctx.lineWidth = 1;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (var q = 0; q < n; q++) {
                    if (q === 0)
                        ctx.moveTo(xBei(r[q][0]), yBei(r[q][1]));
                    else
                        ctx.lineTo(xBei(r[q][0]), yBei(r[q][1]));
                }
                ctx.stroke();
            }

            // Ab hier das Mittel: Flaeche darunter, nach unten auslaufend
            r = root.mittel;
            n = r.length;
            var verlauf = ctx.createLinearGradient(0, padT, 0, unten);
            verlauf.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                            root.accentColor.b, 0.28));
            verlauf.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                            root.accentColor.b, 0));
            ctx.fillStyle = verlauf;
            ctx.beginPath();
            ctx.moveTo(xBei(r[0][0]), unten);
            for (var i = 0; i < n; i++)
                ctx.lineTo(xBei(r[i][0]), yBei(r[i][1]));
            ctx.lineTo(xBei(r[n - 1][0]), unten);
            ctx.closePath();
            ctx.fill();

            ctx.strokeStyle = root.accentColor;
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.beginPath();
            for (var k = 0; k < n; k++) {
                if (k === 0)
                    ctx.moveTo(xBei(r[k][0]), yBei(r[k][1]));
                else
                    ctx.lineTo(xBei(r[k][0]), yBei(r[k][1]));
            }
            ctx.stroke();

            // Die Treppe: waagerecht bis zur naechsten Anpassung, dann
            // senkrecht auf den neuen Wert, bis an den rechten Rand.
            var tr = root.treppe;
            if (tr.length) {
                ctx.strokeStyle = Qt.rgba(root.diffColor.r, root.diffColor.g,
                                          root.diffColor.b, 0.8);
                ctx.lineWidth = 1.3;
                ctx.lineJoin = "miter";
                ctx.beginPath();
                ctx.moveTo(xBei(tr[0][0]), yBei(tr[0][1]));
                for (var s = 1; s < tr.length; s++) {
                    ctx.lineTo(xBei(tr[s][0]), yBei(tr[s - 1][1]));
                    ctx.lineTo(xBei(tr[s][0]), yBei(tr[s][1]));
                }
                ctx.lineTo(width - padR, yBei(tr[tr.length - 1][1]));
                ctx.stroke();
            }

            // Hoechst- und Tiefstwert: links als Hashrate, rechts als
            // Schwierigkeit -- dieselbe Hoehe, zwei Lesarten.
            ctx.font = (root.baseFont - 2) + "px " + Fonts.sansCss();
            ctx.fillStyle = root.accentColor;
            ctx.textAlign = "left";
            ctx.fillText(Tr.big(root.maxWert, root.lang, "H/s"), 0, padT + root.baseFont * 0.7);
            ctx.fillText(Tr.big(root.minWert, root.lang, "H/s"), 0, unten - 2);
            if (tr.length) {
                ctx.fillStyle = root.diffColor;
                ctx.textAlign = "right";
                ctx.fillText(Tr.big(root.maxWert / root.faktor, root.lang), width,
                             padT + root.baseFont * 0.7);
                ctx.fillText(Tr.big(root.minWert / root.faktor, root.lang), width, unten - 2);
            }

            // Anfang und Ende der Zeitachse
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "left";
            ctx.fillText(root.datum(root.tAnfang), padL, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.datum(root.tEnde), width - padR, height - 2);
        }
    }

    // Nur zum Messen: die breitesten Beschriftungen links und rechts
    Text {
        id: massL

        visible: false
        text: Tr.big(root.maxWert || 888e18, root.lang, "H/s")
        // Dieselbe Schrift wie auf der Leinwand, siehe MarketView.qml.
        font.family: Fonts.sans()
        font.pixelSize: root.baseFont - 2
    }

    Text {
        id: massR

        visible: false
        text: Tr.big((root.maxWert || 888e18) / root.faktor, root.lang)
        font.family: Fonts.sans()
        font.pixelSize: root.baseFont - 2
    }

    // Runde Schrittweite, hoechstens rund fuenf Linien (wie am Kursverlauf)
    function stufenLinear(lo, hi) {
        var spanne = hi - lo;
        if (!(spanne > 0))
            return [];
        var roh = spanne / 5;
        var zehner = Math.pow(10, Math.floor(Math.log(roh) / Math.LN10));
        var schritt = 10 * zehner;
        var wahl = [1, 2, 2.5, 5, 10];
        for (var i = 0; i < wahl.length; i++) {
            if (wahl[i] * zehner >= roh) {
                schritt = wahl[i] * zehner;
                break;
            }
        }
        var out = [];
        for (var v = Math.ceil(lo / schritt) * schritt; v < hi; v += schritt)
            out.push(v);
        return out;
    }

    // Jede Tausenderstufe; sind es mehr als sechs, nur jede zweite
    function stufenLog(lo, hi) {
        var out = [];
        for (var e = Math.ceil(Math.log(lo) / Math.LN10 / 3) * 3;
             Math.pow(10, e) < hi; e += 3)
            out.push(Math.pow(10, e));
        if (out.length > 6)
            out = out.filter(function (x, i) {
                return i % 2 === 0;
            });
        return out;
    }

    // Die feinen Linien liegen logarithmisch genau auf 1 kH/s, 1 MH/s, ...:
    // dort "1 EH/s" statt "1,00 EH/s".
    function achsText(v) {
        if (root.logAchse) {
            var u = ["", "k", "M", "G", "T", "P", "E"];
            var i = Math.round(Math.log(v) / Math.LN10 / 3);
            if (i >= 0 && i < u.length)
                return "1 " + u[i] + "H/s";
        }
        return Tr.big(v, root.lang, "H/s");
    }

    function datum(ts) {
        return ts ? Qt.formatDateTime(new Date(ts * 1000), Tr.datum(root.lang)) : "";
    }

    // Die Schwierigkeit, die zu einem Zeitpunkt galt
    function schwierigkeitBei(t) {
        var tr = root.treppe;
        var wert = tr.length ? tr[0][1] : 0;
        for (var i = 0; i < tr.length; i++) {
            if (tr[i][0] <= t)
                wert = tr[i][1];
        }
        return wert / root.faktor;
    }

    // ------------------------------------------------- Ablesen am Zeiger
    // Mit der Maus und mit dem Finger: am Telefon gibt es kein Schweben,
    // dort zeigt das Antippen und Ziehen den Wert.
    property int zeigerIndex: -1

    MouseArea {
        anchors.fill: leinwand
        hoverEnabled: true
        function waehle(mx) {
            var r = root.reihe;
            if (r.length < 2) {
                root.zeigerIndex = -1;
                return;
            }
            var spanne = root.tEnde - root.tAnfang;
            var t = root.tAnfang + spanne * (mx - leinwand.padL)
                    / Math.max(1, leinwand.width - leinwand.padL - leinwand.padR);
            var best = 0;
            for (var i = 1; i < r.length; i++) {
                if (Math.abs(r[i][0] - t) < Math.abs(r[best][0] - t))
                    best = i;
            }
            root.zeigerIndex = best;
        }
        onPositionChanged: function (m) {
            waehle(m.x);
        }
        onPressed: function (m) {
            waehle(m.x);
        }
        onExited: root.zeigerIndex = -1
        onReleased: if (!containsMouse) root.zeigerIndex = -1
    }

    // Der Punkt sitzt auf der kraeftigen Linie, also auf dem Mittel
    readonly property var zeigerPunkt: (root.zeigerIndex >= 0 && root.zeigerIndex < root.mittel.length)
        ? root.mittel[root.zeigerIndex] : null

    Rectangle {
        visible: root.zeigerPunkt !== null
        x: leinwand.x + (root.zeigerPunkt ? leinwand.xBei(root.zeigerPunkt[0]) : 0)
        y: leinwand.y + leinwand.padT
        width: 1
        height: leinwand.height - leinwand.padT - leinwand.padB
        color: root.dimColor
        opacity: 0.6
    }

    Rectangle {
        visible: root.zeigerPunkt !== null
        width: 7
        height: 7
        radius: 4
        color: root.accentColor
        x: leinwand.x + (root.zeigerPunkt ? leinwand.xBei(root.zeigerPunkt[0]) : 0) - 3.5
        y: leinwand.y + (root.zeigerPunkt ? leinwand.yBei(root.zeigerPunkt[1]) : 0) - 3.5
    }

    Column {
        visible: root.zeigerPunkt !== null
        x: Math.max(0, Math.min(root.width - width,
                                leinwand.x + (root.zeigerPunkt ? leinwand.xBei(root.zeigerPunkt[0]) : 0)
                                - width / 2))
        y: leinwand.y
        spacing: 0

        Text {
            text: root.zeigerPunkt ? Tr.big(root.zeigerPunkt[1], root.lang, "H/s") : ""
            color: root.accentColor
            font.pixelSize: root.baseFont
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.treppe.length > 0
            text: root.zeigerPunkt
                  ? Tr.t("difficulty", root.lang) + " "
                    + Tr.big(root.schwierigkeitBei(root.zeigerPunkt[0]), root.lang)
                  : ""
            color: root.diffColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: root.zeigerPunkt ? root.datum(root.zeigerPunkt[0]) : ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }
    }

    // ------------------------------------------------------------ Hinweise
    Text {
        anchors.centerIn: parent
        visible: root.laden && root.reihe.length < 2
        text: Tr.t("net.loading", root.lang)
        color: root.dimColor
        font.pixelSize: root.baseFont
    }

    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !root.laden && root.fehler !== "" && root.reihe.length < 2
        text: Tr.t("net.failed", root.lang, Tr.grund(root.fehler, root.lang))
        color: root.dimColor
        font.pixelSize: root.baseFont - 1
    }
}
