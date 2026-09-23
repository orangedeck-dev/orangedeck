// The network over a time span: hashrate as an area, difficulty as a step
// line above it, both on the same axis.
//
// Difficulty D implies a hashrate: a block needs D * 2^32 attempts on
// average and should arrive every 600 seconds, so D * 2^32 / 600 H/s.
// Converted to that unit both values share one axis, and you can see what
// the adjustment does: the steps trail the area. mempool.space uses two
// axes, which invites comparing two curves whose relative position depends
// only on the scaling.
//
// The left axis shows hashrate (orange), the right axis the same height as
// difficulty (light). Each label uses the color of its line, as in
// `MinerChart`.
//
// `NetworkView` fetches the data; this file only draws and handles the span.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property string lang: "de"
    // 30d | 90d | 1y | 3y | max, kept by the host
    property string span: "1y"
    // [[time, H/s], ...], ascending
    property var reihe: []
    // [[time, difficulty, height, factor], ...], every adjustment in the span
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

    // H/s per unit of difficulty
    readonly property real faktor: 4294967296 / 600

    // Same buttons as on the price chart where they apply. 24 hours and
    // seven days are missing because the series has one point per day.
    readonly property var spans: [
        { "k": "30d", "l": Tr.t("price.30d", root.lang) },
        { "k": "90d", "l": Tr.t("price.90d", root.lang) },
        { "k": "1y", "l": Tr.t("price.1y", root.lang) },
        { "k": "3y", "l": Tr.t("net.3y", root.lang) },
        { "k": "max", "l": Tr.t("price.max", root.lang) }
    ]

    // The seven-day average is the main line, daily values are secondary.
    // A day's hashrate is an estimate from about 144 blocks, and that count
    // varies randomly, so over a year the raw values form a jagged band that
    // hides the trend. Drawn like the miner chart: raw values thin and faint,
    // the average bold.
    //
    // Centered average, not trailing: a trailing average would itself lag by
    // three and a half days and distort exactly what the chart should show,
    // how difficulty follows hashrate. If the series is already thinned out
    // (three years, max), each point is already an average and the window
    // covers only that point.
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
    // More than a day between two points means the data is already averaged,
    // so there are no daily values to draw underneath.
    readonly property bool mitTageswerten: {
        var r = root.reihe;
        return r.length > 2 && (r[r.length - 1][0] - r[0][0]) / (r.length - 1) < 1.5 * 86400;
    }

    // The step line as points [time, H/s]: at the left edge the value that
    // was valid there, then one jump per adjustment. The value before the
    // first adjustment in the span comes from its factor; without it the line
    // would start at the first step, which for thirty days is often midway.
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

    // The time axis runs to the last value of both series: after thinning,
    // the daily hashrate averages end a few days before today, but an
    // adjustment from yesterday should still be visible.
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

    // Logarithmic over the full history. From 7 kH/s in January 2009 to
    // 900 EH/s today is seventeen orders of magnitude; on a linear scale the
    // first eleven years would be a line on the baseline. Switches at a span
    // of three orders of magnitude; three years is less than two.
    readonly property bool logAchse: root.minWert > 0 && root.maxWert / root.minWert > 1000

    // Change over the span. For "max" it would be an eighteen-digit number,
    // so it is left out there.
    // Taken from the average: two single days at the edges would be noise.
    readonly property real wandel: {
        var r = root.mittel;
        if (r.length < 2 || root.logAchse)
            return 0;
        var a = r[0][1], b = r[r.length - 1][1];
        return a ? (b - a) / a * 100 : 0;
    }

    onReiheChanged: leinwand.requestPaint()
    onStufenChanged: leinwand.requestPaint()

    // ------------------------------------------------------- Span selection
    // As on the price chart: if header and buttons do not fit side by side,
    // the buttons move to their own row below.
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

    // ------------------------------------------------------------ Header
    // Which line is which, in its color: a one-line legend.
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

    // --------------------------------------------------------------- Chart
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

        // Hashrate on the left, difficulty on the right, both measured rather
        // than estimated (see PriceChart).
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

            // Grid lines: linear on round values (as on the price chart), logarithmic
            // on every factor of 1000, which is where the prefix changes (1 PH/s, 1 EH/s).
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
                // Too close to the max or min value the line gets no number, otherwise
                // labels like "1,306" and "1,200 EH/s" overlap on the phone.
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

            // Baselines at top and bottom
            ctx.strokeStyle = root.lineColor;
            ctx.beginPath();
            ctx.moveTo(padL, padT + 0.5);
            ctx.lineTo(width - padR, padT + 0.5);
            ctx.moveTo(padL, unten - 0.5);
            ctx.lineTo(width - padR, unten - 0.5);
            ctx.stroke();

            // Daily values thin and faint, only where there are any
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

            // From here on the average: area below it, fading out downwards
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

            // Step line: horizontal until the next adjustment, then vertical to the
            // new value, up to the right edge.
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

            // Max and min: left as hashrate, right as difficulty. Same height, two
            // readings.
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

            // Start and end of the time axis
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "left";
            ctx.fillText(root.datum(root.tAnfang), padL, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.datum(root.tEnde), width - padR, height - 2);
        }
    }

    // Measuring only: the widest labels on the left and right
    Text {
        id: massL

        visible: false
        text: Tr.big(root.maxWert || 888e18, root.lang, "H/s")
        // Same font as on the canvas, see MarketView.qml.
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

    // Round step size, at most about five lines (as on the price chart)
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

    // Every factor of 1000; if there are more than six, only every other one
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

    // On a log scale the grid lines sit exactly on 1 kH/s, 1 MH/s, ...,
    // so show "1 EH/s" instead of "1.00 EH/s".
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

    // The difficulty that was valid at a given time
    function schwierigkeitBei(t) {
        var tr = root.treppe;
        var wert = tr.length ? tr[0][1] : 0;
        for (var i = 0; i < tr.length; i++) {
            if (tr[i][0] <= t)
                wert = tr[i][1];
        }
        return wert / root.faktor;
    }

    // ------------------------------------------------- Pointer readout
    // Works with mouse and finger: phones have no hover, so tapping and
    // dragging shows the value there.
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

    // The dot sits on the bold line, i.e. on the average
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

    // ------------------------------------------------------------ Notices
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
