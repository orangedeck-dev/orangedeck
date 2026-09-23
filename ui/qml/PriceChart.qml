// Price history: a single line with a span picker and a readout under the pointer.
//
// The data arrives already thinned to at most 360 points, whether the span is
// one day or sixteen years. Thinning happens in the service (`price_series`)
// or in the direct feed (`DirectFeed.__preisReihe`), never here: a curve
// 800 px wide gains nothing from 33,299 points, and running `JSON.parse` on
// the full series cost about 6 % CPU.
//
// Only `import QtQuick`, so this also runs on Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    property string lang: "de"
    property string currency: "eur"
    // 24h | 7d | 30d | 90d | 1y | max. The host owns it so it survives
    // across sessions.
    property string span: "30d"
    // Nothing is fetched while nobody is looking
    property bool live: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12
    // Minimum tap height of the span buttons, 0 = as drawn
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
    // Change over the span, in percent
    readonly property real wandel: {
        if (root.punkte.length < 2)
            return 0;
        var a = root.punkte[0][1], b = root.punkte[root.punkte.length - 1][1];
        return a ? (b - a) / a * 100 : 0;
    }

    // Only the latest request counts. On startup the chart asks with the
    // default "30d" before settings are loaded, and right after that with the
    // saved span. In the direct feed each request loads the whole data set
    // (1.5 MB), and whichever arrived last would win, so the picker could
    // show "90d" over a thirty-day curve.
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

    // Only the recent end changes; older data is fixed. Five minutes is
    // plenty, the service itself only refreshes hourly.
    Timer {
        interval: 300000
        repeat: true
        running: root.live && root.visible
        onTriggered: root.holen()
    }

    // ------------------------------------------------------- span picker
    // If the header and the buttons do not fit side by side, the buttons move
    // to their own row below. With finger-sized buttons on a phone they
    // otherwise overlapped the price.
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
        // The spans need no label, "24h" says enough
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

    // ------------------------------------------------------------ header
    //
    // When the chart is short, price and change sit side by side. Stacked,
    // the header takes two rows away from the curve, and in the dashboard
    // tab the max and min labels ended up on top of each other.
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
            // Two decimals on a five-digit percentage are noise, so they
            // are dropped above one hundred percent.
            text: (root.wandel >= 0 ? "+" : "−")
                  + Tr.fixed(Math.abs(root.wandel),
                             Math.abs(root.wandel) >= 100 ? 0 : 2, root.lang) + " %"
            color: root.wandel >= 0 ? "#5cb946" : "#d33f3f"
            font.pixelSize: root.baseFont - 1
        }
    }

    // --------------------------------------------------------------- curve
    Canvas {
        id: leinwand

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Header on the left and span picker on the right sit side by side
        // at different heights. Without the max, the curve's top value slid
        // under the percentage.
        anchors.topMargin: (root.gestapelt ? kopf.height + root.baseFont * 0.5 + wahl.height
                                           : Math.max(kopf.height, wahl.height))
                           + root.baseFont * 0.6
        antialiasing: true

        // Wide enough for the longest label, measured rather than guessed:
        // with a large font "69.660 €" is far wider than a fixed character
        // count suggests, and the curve ran underneath it.
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

            // Faint lines at round amounts, for orientation. The step is
            // computed, not fixed: a fixed 5000 would give no line at all
            // for one day and two dozen for "max". It takes the smallest
            // round step (1, 2, 2.5 or 5 times a power of ten) that gives at
            // most about five lines; for 62,553 to 81,476 $ that is 5000.
            // Fainter than the base lines so the curve does not drown in a grid.
            var schritt = root.rasterSchritt(root.minWert, root.maxWert);
            if (schritt > 0) {
                ctx.strokeStyle = Qt.rgba(root.dimColor.r, root.dimColor.g,
                                          root.dimColor.b, 0.14);
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (var v = Math.ceil(root.minWert / schritt) * schritt;
                     v < root.maxWert; v += schritt) {
                    var ry = Math.round(yBei(v)) + 0.5;
                    // Skip lines that would sit on the top or bottom base line
                    if (ry - padT < 4 || height - padB - ry < 4)
                        continue;
                    ctx.moveTo(padL, ry);
                    ctx.lineTo(width - padR, ry);
                }
                ctx.stroke();

                // Labelled on the left like max and min, but lighter, since
                // they are orientation, not data. A line too close to the
                // max or min gets no number, two overlapping labels are
                // unreadable.
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

            // Base lines at top and bottom: max and min.
            ctx.strokeStyle = root.lineColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(padL, padT + 0.5);
            ctx.lineTo(width - padR, padT + 0.5);
            ctx.moveTo(padL, height - padB - 0.5);
            ctx.lineTo(width - padR, height - padB - 0.5);
            ctx.stroke();

            // Filled area under the curve, fading downwards
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

            // Max and min on the left edge
            ctx.fillStyle = root.dimColor;
            ctx.font = (root.baseFont - 2) + "px " + Fonts.sansCss();
            ctx.textAlign = "left";
            ctx.fillText(Tr.price1(root.maxWert, root.zeichen, root.lang), 0, padT + root.baseFont * 0.7);
            ctx.fillText(Tr.price1(root.minWert, root.zeichen, root.lang), 0, height - padB - 2);

            // Start and end of the time axis
            ctx.textAlign = "left";
            ctx.fillText(root.datum(root.punkte[0][0]), padL, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.datum(root.punkte[n - 1][0]), width - padR, height - 2);
        }
    }

    // Measurement only: same font and text as the labels on the left edge
    // of the curve.
    Text {
        id: mass

        visible: false
        text: Tr.price1(root.maxWert || 88888, root.zeichen, root.lang)
        // Same font as on the canvas, see MarketView.qml: measuring with the
        // default font and drawing with `Fonts.sansCss()` gives different
        // widths on Ubuntu and Fedora.
        font.family: Fonts.sans()
        font.pixelSize: root.baseFont - 2
    }

    // Round step for the faint lines, see onPaint
    function rasterSchritt(lo, hi) {
        var spanne = hi - lo;
        if (!(spanne > 0))
            return 0;
        // At most about five lines. With four, ninety days
        // (58,348 to 81,272 $) gave 10,000 steps and only one labelled line.
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
        // For a single day the date says nothing, the time does
        return Qt.formatDateTime(d, root.span === "24h" ? "HH:mm" : Tr.datum(root.lang));
    }

    // ------------------------------------------------- pointer readout
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

    // ------------------------------------------------------------ notices
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

    // The five currencies other than EUR and USD are not in the data set.
    // They are derived from the dollar value at today's exchange rate. Over
    // years that is a conversion, not the real price, so the chart says so.
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
