// Clock view: large, calm, no controls. Meant for a wall-mounted tablet
// or full-screen mode on the desktop.
//
// Modeled on the unreleased `display-mode` branch of upstream bitfeed:
// a switch that locks the UI into a reduced view without controls.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "roll.js" as Roll

// The Repeater below refers to `root`. Without this pragma qmllint warns
// that ids from the enclosing component are not bound inside nested
// components; with it they are bound explicitly.
pragma ComponentBehavior: Bound

Item {
    id: root

    // Keyboard: Page Up/Down, Home, End (roll.js, forwarded from Main.qml via FeedTabs)
    function rollen(wie) {
        return Roll.rollen(flick, wie);
    }

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    // Which stats to show. An empty list means all of them, so a stat added
    // later shows up instead of silently missing.
    property var fields: []
    property string currency: "eur"
    property bool showBars: true
    property bool showSpark: true
    // Price chart below the stats. The host keeps the time span so it
    // survives across sessions.
    property bool showPrice: true
    property string priceSpan: "30d"
    // Touch mode: larger buttons on the price chart. Set by the host
    // (Main.qml on the phone), not by the view itself.
    property bool finger: false

    signal priceSpanRequested(string s)

    property bool showTime: false
    property string lang: "de"
    // What is shown large in the center. Several entries rotate, so on a wall
    // tablet the same area shows height, price and Moscow time in turn.
    property var bigFields: ["height"]
    property int bigRotate: 0        // seconds, 0 = no rotation
    property int bigIndex: 0

    readonly property var bigList: (bigFields && bigFields.length) ? bigFields : ["height"]
    readonly property string bigNow: bigList[bigIndex % bigList.length]

    // Label and value of the big display. Kept in one place so the order
    // below stays consistent.
    function bigLabel(id) {
        if (id === "price")
            return Tr.t("price", root.lang);
        if (id === "moscow")
            return Tr.t("clock.moscow", root.lang);
        if (id === "fee")
            return Tr.t("fee", root.lang);
        if (id === "hashrate")
            return Tr.t("hashrate", root.lang);
        if (id === "mempool")
            return Tr.t("mempool", root.lang);
        if (id === "time")
            return Tr.t("set.clockTime", root.lang);
        return Tr.t("blockHeight", root.lang);
    }

    function bigValue(id) {
        if (id === "price")
            return root.kurs ? root.grp(root.kurs) + " " + root.waehrung : "–";
        if (id === "moscow")
            return root.kurs ? root.grp(1e8 / root.kurs) : "–";
        if (id === "fee")
            return root.comma(root.fees.fastest);
        if (id === "hashrate")
            return root.hr.current ? root.comma(root.hr.current / 1e18, 0) + " EH/s" : "–";
        if (id === "mempool")
            return root.feed ? root.grp(root.feed.mempoolCount) : "–";
        if (id === "time")
            return Qt.formatDateTime(root.jetzt, "HH:mm");
        return root.grp(root.feed ? root.feed.tipHeight : 0);
    }

    // Needed when the time is the big display, otherwise it would freeze
    property date jetzt: new Date()

    Timer {
        interval: 10000
        repeat: true
        running: root.visible && (root.showTime || root.bigNow === "time")
        triggeredOnStart: true
        onTriggered: root.jetzt = new Date()
    }

    // Rotation timer. Runs only when there is something to rotate and the view
    // is visible; a hidden timer only costs power.
    Timer {
        interval: Math.max(2, root.bigRotate) * 1000
        repeat: true
        running: root.visible && root.bigRotate > 0 && root.bigList.length > 1
        onTriggered: root.bigIndex = (root.bigIndex + 1) % root.bigList.length
    }

    readonly property real kurs: Money.rate(price, currency)
    readonly property string waehrung: Money.symbol(Money.actual(price, currency))

    // Accept anything that is not a field array: empty, undefined or an
    // invalid stored value all mean "show everything".
    function zeigt(id) {
        var f = root.fields;
        if (!f || !f.length || typeof f.indexOf !== "function")
            return true;
        return f.indexOf(id) >= 0;
    }

    readonly property var tip: feed ? feed.tip : ({})
    readonly property var fees: (feed && feed.snap.fees) || ({})
    readonly property var price: feed ? feed.price : ({})
    readonly property var diff: feed ? feed.difficulty : ({})
    readonly property var hr: feed ? feed.hashrate : ({})

    // Halving every 210,000 blocks
    readonly property int halvingHeight: {
        var h = feed ? feed.tipHeight : 0;
        return h > 0 ? (Math.floor(h / 210000) + 1) * 210000 : 0;
    }
    readonly property int halvingLeft: halvingHeight > 0 ? halvingHeight - feed.tipHeight : 0

    // Thousands separator per language: German uses a period, English a comma.
    // This matters: "1.234" means either one thousand two hundred thirty-four
    // or one point two three four depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function comma(v, digits) {
        if (v === undefined || v === null)
            return "–";
        return Tr.fixed(v, digits === undefined ? 1 : digits, root.lang);
    }

    // "3 days 4 h left", no seconds, they only flicker
    function span(ms) {
        if (!ms || ms < 0)
            return "–";
        var min = Math.floor(ms / 60000);
        var d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60), m = min % 60;
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
    }

    // The whole page scrolls as one. Clock and price chart sit one below the
    // other in the same Flickable. The chart takes its height from the width,
    // not the height, so it is not squashed in landscape. If both fit, they are
    // centered as a group and in portrait the chart may grow into the free
    // space. If not, the clock fills the first screen and the chart sits below
    // it: on the wall you see the clock, and whoever wants the price scrolls.
    readonly property real rand: root.scaleUnit * 0.4
    readonly property real luecke: root.scaleUnit * 0.8
    readonly property real kurveHoehe: {
        if (!kurve.visible)
            return 0;
        var basis = Math.max(120, Math.min(root.width * 0.42, 380));
        var frei = root.height - body.implicitHeight - root.luecke - 2 * root.rand;
        return Math.max(basis, Math.min(root.width * 0.75, frei));
    }
    readonly property bool passtAlles: body.implicitHeight + root.luecke + root.kurveHoehe
                                       + 2 * root.rand <= root.height
    readonly property real bodyY: root.passtAlles
        ? (root.height - body.implicitHeight - root.luecke - root.kurveHoehe) / 2
        : Math.max(root.rand, (root.height - body.implicitHeight) / 2)
    // If it does not fit, the chart starts below the first screen instead of
    // being cut off at the bottom edge.
    readonly property real kurveY: root.passtAlles
        ? root.bodyY + body.implicitHeight + root.luecke
        : Math.max(root.bodyY + body.implicitHeight + root.luecke, root.height)

    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: kurve.visible
            ? root.kurveY + root.kurveHoehe + root.rand
            : Math.max(root.height, root.bodyY + body.implicitHeight + root.rand)
        boundsBehavior: Flickable.StopAtBounds

    Column {
        id: body

        width: parent.width * 0.86
        x: (flick.width - width) / 2
        // The chart is not part of this column but placed below it. Inside the
        // column it was one item of seven and always got clipped first.
        // bodyY and kurveY position both.
        y: root.bodyY
        spacing: root.scaleUnit * (kurve.visible ? 0.35 : 0.5)

        // -------------------------------------------------------- Time
        // On a wall tablet the view doubles as a clock. The timer runs only while
        // the time is shown, and a minute display needs no per-second tick.
        Text {
            id: uhr

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showTime && root.bigNow !== "time"
            color: root.textColor
            font.pixelSize: root.scaleUnit * 2.2
            font.letterSpacing: root.scaleUnit * 0.04

            text: Qt.formatDateTime(root.jetzt, "HH:mm")
        }

        // ------------------------------------------------ Big display
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.bigLabel(root.bigNow)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.8
            font.letterSpacing: root.scaleUnit * 0.08
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.bigValue(root.bigNow)
            color: root.accentColor
            // Room for the price chart comes from here. The column otherwise fills
            // the area exactly, and with the chart added it would overflow and need
            // scrolling, which is wrong for a wall clock. The big value gives up a
            // quarter of its height and is still the largest number on screen.
            font.pixelSize: root.scaleUnit * (kurve.visible ? 2.3 : 3.4)
            font.bold: true
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.6
        }

        // ------------------------------------------------------ Stats
        Row {
            id: kennzahlen

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.scaleUnit * 1.6
            // The row can get wider than the area: it is only centered, and its width
            // is the sum of its children. With 1400 px and five stats the outer values
            // were cut off. If it does not fit, the whole row is scaled down; at 0.95
            // nobody notices, and it beats a clipped number.
            scale: implicitWidth > parent.width && implicitWidth > 0
                   ? parent.width / implicitWidth : 1
            transformOrigin: Item.Center

            Repeater {
                model: {
                    var alle = [
                        {
                            "id": "fee",
                            "k": Tr.t("fee", root.lang),
                            "v": root.comma(root.fees.fastest) + " sat/vB"
                        },
                        {
                            "id": "price",
                            "k": Tr.t("price", root.lang),
                            "v": root.kurs ? root.grp(root.kurs) + " " + root.waehrung : "–"
                        },
                        {
                            // Satoshis per unit of the currency. The number rises when the price
                            // falls: it measures money in bitcoin instead of bitcoin in money,
                            // which is the point of it.
                            "id": "moscow",
                            "k": Tr.t("clock.moscow", root.lang),
                            "v": root.kurs ? root.grp(1e8 / root.kurs) + " sat" : "–"
                        },
                        {
                            "id": "mempool",
                            "k": Tr.t("mempool", root.lang),
                            "v": root.feed ? root.grp(root.feed.mempoolCount) : "–"
                        },
                        {
                            "id": "hashrate",
                            "k": Tr.t("hashrate", root.lang),
                            "v": root.hr.current ? root.comma(root.hr.current / 1e18, 0) + " EH/s" : "–"
                        }
                    ];
                    return alle.filter(function (x) {
                        // Skip whatever is already shown large above; the same number twice
                        // reads like a bug.
                        return root.zeigt(x.id) && x.id !== root.bigNow;
                    });
                }

                Column {
                    // With `pragma ComponentBehavior: Bound` modelData has to be
                    // requested explicitly.
                    required property var modelData

                    spacing: root.scaleUnit * 0.12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.k
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.62
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.v
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 1.0
                    }
                }
            }
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.6
        }

        // ------------------------------------ Difficulty and halving
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.25
            visible: root.showBars

            Row {
                width: parent.width

                Text {
                    text: Tr.t("clock.diffLine", root.lang,
                               root.diff.change !== undefined
                                   ? (root.diff.change >= 0 ? "+" : "")
                                     + root.comma(root.diff.change, 2) + " %" : "")
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Item {
                    width: parent.width - 2 * root.scaleUnit * 8
                    height: 1
                }

                Text {
                    text: root.diff.remainingBlocks !== undefined
                        ? Tr.t("clock.remaining", root.lang,
                               root.grp(root.diff.remainingBlocks),
                               root.span(root.diff.remainingTime))
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            Rectangle {
                width: parent.width
                height: Math.max(3, root.scaleUnit * 0.16)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.diff.progress || 0) / 100))
                    height: parent.height
                    radius: height / 2
                    color: root.accentColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 600
                        }
                    }
                }
            }

            Text {
                text: root.halvingLeft > 0
                    ? Tr.t("clock.halving", root.lang, root.grp(root.halvingHeight),
                           root.grp(root.halvingLeft),
                           root.span(root.halvingLeft * 600000))
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }
        }

        // -------------------------------------------- Hashrate chart
        Canvas {
            id: spark

            width: parent.width
            height: root.scaleUnit * 1.8
            // Only one chart in this view. With the price chart shown, the hashrate
            // chart steps back: two stacked lines are noise in a clock, and there is
            // not enough room for both. Hashrate is also in the miner tab, price is
            // nowhere else. Turn off the price chart to get hashrate here.
            visible: root.showSpark && !kurve.visible
                     && (root.hr.series || []).length > 1

            Connections {
                target: root
                function onHrChanged() {
                    spark.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var s = root.hr.series || [];
                if (s.length < 2)
                    return;
                var lo = Math.min.apply(null, s), hi = Math.max.apply(null, s);
                if (hi <= lo)
                    return;
                var pad = 2;
                ctx.beginPath();
                for (var i = 0; i < s.length; i++) {
                    var x = pad + (width - 2 * pad) * i / (s.length - 1);
                    var y = height - pad - (height - 2 * pad) * (s[i] - lo) / (hi - lo);
                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.strokeStyle = root.accentColor;
                ctx.lineWidth = Math.max(1.5, root.scaleUnit * 0.09);
                ctx.stroke();
            }
        }
        }

        // ----------------------------------------------- Price chart
        // Needs height to be readable. In flat areas (bar popout, small desktop
        // widget) it is hidden instead of collapsing into a line.
        //
        // The threshold is in pixels, not in `scaleUnit`. scaleUnit itself grows
        // with the height (`height / 16`), so `height >= scaleUnit * 22` would mean
        // `height >= 1.375 * height` and never be true.
    PriceChart {
        id: kurve

        x: root.width * 0.07
        y: root.kurveY
        width: root.width * 0.86
        height: root.kurveHoehe
        // The page scrolls instead of taking space away; the chart is hidden only
        // in really flat areas (bar popout, narrow desktop widget) where scrolling
        // would not help either.
        visible: root.showPrice && root.height >= 250
        live: root.visible
        feed: root.feed
        lang: root.lang
        currency: root.currency
        span: root.priceSpan
        // Smaller than the stats above: a chart label is secondary. But not below
        // 13 px on the phone, otherwise the span buttons are too small to hit
        // with a finger.
        baseFont: root.finger ? Math.max(13, root.scaleUnit * 0.5) : root.scaleUnit * 0.5
        minTap: root.finger ? 40 : 0
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.35)
        onSpanRequested: function (sp) {
            root.priceSpanRequested(sp);
        }
    }
    }

    // Say so when there is no connection instead of showing stale data
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.scaleUnit * 0.6
        visible: root.feed && !root.feed.online
        text: Tr.t("offline", root.lang)
        color: "#d9534f"
        font.pixelSize: root.scaleUnit * 0.62
    }
}
