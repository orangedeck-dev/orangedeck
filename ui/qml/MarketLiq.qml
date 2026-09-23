// Liquidations and positioning, the second sub-tab of the market view.
//
// Two questions the price alone does not answer:
//
//   How are others positioned? The share of accounts that are long, per
//   exchange. Real numbers from the exchanges, not an estimate.
//
//   Where were positions forced out? One bar per price level, built from
//   the forced liquidations the service has observed itself.
//
// Deliberately no Coinglass-style heatmap. That picture is computed, not
// measured: it extrapolates from open interest and assumed leverage where
// liquidations would sit. Only the exchange knows the real liquidation
// prices of open positions, and nobody publishes them. So this view shows
// only what actually happened. Less picture, but every number can be backed up.
//
// Only `import QtQuick`, so this also runs on Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"
    property string zeichen: "$"
    // [[priceMid, longValue, shortValue], ...] in dollars per price level
    property var hist: []
    // [{id, name, long}]: share of accounts that are long
    property var ratio: []
    // Start of listening, 0 = never
    property int seit: 0
    // {id, name, online, since} per source; `since` only exists in the direct feed
    property var liqQuellen: []
    // Bybit shown separately if it started later. In the direct feed `seit`
    // is the start of the OKX backfill, about a day back; Bybit has no
    // backfill and only counts from the moment it connects. The service
    // listens to both for the same time and sends no `since`.
    readonly property int bybitSeit: {
        for (var i = 0; i < root.liqQuellen.length; i++) {
            var q = root.liqQuellen[i];
            if (q.id === "bybit-liq" && q.since > 0)
                return q.since;
        }
        return 0;
    }

    function seitText() {
        var f = Tr.datum(root.lang) + " HH:mm";
        var s = Qt.formatDateTime(new Date(root.seit * 1000), f);
        if (root.bybitSeit > root.seit + 600)
            s += " (OKX), " + Qt.formatDateTime(new Date(root.bybitSeit * 1000), f) + " (Bybit)";
        return s;
    }
    property real preis: 0
    property var quellen: []

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12

    readonly property color upColor: "#5cb946"
    readonly property color downColor: "#d33f3f"

    // Totals over the whole window, the line people read first
    readonly property real summeLong: {
        var s = 0;
        for (var i = 0; i < root.hist.length; i++)
            s += root.hist[i][1];
        return s;
    }
    readonly property real summeShort: {
        var s = 0;
        for (var i = 0; i < root.hist.length; i++)
            s += root.hist[i][2];
        return s;
    }
    readonly property real groessteStufe: {
        var m = 0;
        for (var i = 0; i < root.hist.length; i++)
            m = Math.max(m, root.hist[i][1] + root.hist[i][2]);
        return m;
    }
    // The service also sends empty levels, otherwise there would be no price
    // axis. So "nothing observed" is not detected by the list length but by
    // every level being zero.
    readonly property bool hatDaten: root.groessteStufe > 0

    // Short money format: 298,826 becomes "299 k", 1,240,000 becomes "1.2 M".
    // Next to twenty bars a full number has no room, and the order of
    // magnitude is what matters anyway.
    function geld(v) {
        if (v >= 1e9)
            return Tr.fixed(v / 1e9, 1, root.lang) + " G";
        if (v >= 1e6)
            return Tr.fixed(v / 1e6, 1, root.lang) + " M";
        if (v >= 1000)
            return Math.round(v / 1000) + " k";
        return Math.round(v) + "";
    }

    // ------------------------------------------------------ positioning
    Column {
        id: oben

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.baseFont * 0.35

        Text {
            text: Tr.t("market.longShort", root.lang)
            color: root.textColor
            font.pixelSize: root.baseFont
            font.bold: true
        }

        // Share of accounts, not of capital. Without this line 53 % reads
        // like an imbalance, but it only means that every second account is
        // long, not that half the money is there.
        Text {
            text: Tr.t("market.accountShare", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            visible: root.ratio.length > 0
        }

        Repeater {
            model: root.ratio

            Row {
                id: zeile

                required property var modelData

                spacing: root.baseFont * 0.6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont * 4.5
                    text: zeile.modelData.name
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 1
                    elide: Text.ElideRight
                }

                // The bar: green is the long share, red the rest. The middle
                // is marked, without a reference line "53 %" says nothing.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont * 14
                    height: Math.max(6, root.baseFont * 0.75)
                    radius: 2
                    color: root.downColor

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0, Math.min(1, zeile.modelData.long))
                        radius: 2
                        color: root.upColor
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.fixed(zeile.modelData.long * 100, 1, root.lang) + " %"
                    color: zeile.modelData.long >= 0.5 ? root.upColor : root.downColor
                    font.pixelSize: root.baseFont - 1
                    font.family: Fonts.mono()
                }
            }
        }

        Text {
            visible: root.ratio.length === 0
            text: Tr.t("market.noRatio", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Item {
            width: 1
            height: root.baseFont * 0.6
        }

        // ------------------------------------------------- liquidations
        Text {
            text: Tr.t("market.liqTitle", root.lang)
            color: root.textColor
            font.pixelSize: root.baseFont
            font.bold: true
        }

        Text {
            text: root.seit > 0
                  ? Tr.t("market.liqSince", root.lang, root.seitText())
                  : Tr.t("market.liqNever", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            width: parent.width
            wrapMode: Text.WordWrap
        }

        // Flow, not Row: on a phone both totals do not fit side by side,
        // and "Shorts liquidated" ran off the right edge.
        Flow {
            width: parent.width
            spacing: root.baseFont * 1.2
            visible: root.hatDaten

            Text {
                text: "▼ " + Tr.t("market.longsLiq", root.lang) + "  "
                      + root.zeichen + " " + root.geld(root.summeLong)
                color: root.downColor
                font.pixelSize: root.baseFont - 1
                font.family: Fonts.mono()
            }

            Text {
                text: "▲ " + Tr.t("market.shortsLiq", root.lang) + "  "
                      + root.zeichen + " " + root.geld(root.summeShort)
                color: root.upColor
                font.pixelSize: root.baseFont - 1
                font.family: Fonts.mono()
            }
        }
    }

    // -------------------------------------------------------- histogram
    // Price goes up, amount goes right. Horizontal bars, because the question
    // is "at what level", not "when" (the CVD answers that).
    Item {
        id: bild

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: oben.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: root.baseFont * 0.7

        readonly property real achse: root.baseFont * 4.2
        readonly property real feld: Math.max(10, width - achse - root.baseFont * 3)

        Text {
            anchors.centerIn: parent
            visible: !root.hatDaten
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("market.liqEmpty", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        // How many axis labels fit without overlapping. Every third one
        // readable beats all of them unreadable.
        readonly property real zeilenhoehe: Math.max(2, height / Math.max(1, root.hist.length))
        readonly property int jedeWievielte:
            Math.max(1, Math.ceil((root.baseFont + 2) / zeilenhoehe))

        Repeater {
            // Highest price level on top. The service sends them
            // ascending, so they are drawn reversed.
            model: root.hatDaten ? root.hist.slice().reverse() : []

            Item {
                id: stufe

                required property var modelData
                required property int index

                readonly property real wert: stufe.modelData[1] + stufe.modelData[2]
                readonly property bool amKurs: root.preis > 0
                    && Math.abs(stufe.modelData[0] - root.preis)
                       <= (root.hist.length > 1
                           ? Math.abs(root.hist[1][0] - root.hist[0][0]) / 2 : 0)

                width: bild.width
                height: bild.zeilenhoehe
                y: stufe.index * height

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: bild.achse
                    // The level at the current price is always labelled, however
                    // tight it gets, since it is the reference for everything else.
                    visible: stufe.amKurs || stufe.index % bild.jedeWievielte === 0
                    text: Tr.group(stufe.modelData[0], root.lang)
                    color: stufe.amKurs ? root.accentColor : root.dimColor
                    font.pixelSize: Math.max(7, root.baseFont - 3)
                    font.family: Fonts.mono()
                    horizontalAlignment: Text.AlignRight
                }

                // Red: liquidated longs. Green: liquidated shorts. Both start
                // on the left, end to end, so the total length is the
                // level's amount.
                Rectangle {
                    id: balkenLong

                    x: bild.achse + root.baseFont * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    // An empty level draws nothing but keeps its slot,
                    // the axis depends on it.
                    height: Math.max(1, parent.height - 2)
                    width: root.groessteStufe > 0
                           ? bild.feld * stufe.modelData[1] / root.groessteStufe : 0
                    color: root.downColor
                }

                Rectangle {
                    x: balkenLong.x + balkenLong.width
                    anchors.verticalCenter: parent.verticalCenter
                    height: balkenLong.height
                    width: root.groessteStufe > 0
                           ? bild.feld * stufe.modelData[2] / root.groessteStufe : 0
                    color: root.upColor
                }

                Text {
                    x: balkenLong.x + bild.feld + root.baseFont * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.geld(stufe.wert)
                    color: root.dimColor
                    font.pixelSize: Math.max(7, root.baseFont - 3)
                    font.family: Fonts.mono()
                    visible: stufe.wert > 0 && stufe.height >= root.baseFont - 2
                }
            }
        }

        // The current price as a line. Without it "where" means nothing,
        // the question is always "where relative to now".
        Rectangle {
            visible: root.hatDaten && root.hist.length > 1 && root.preis > 0
            // Only across the bar area. At full width it ran through the
            // amounts on the right and struck them out.
            x: bild.achse + root.baseFont * 0.5
            width: bild.feld
            height: 1
            color: root.accentColor
            opacity: 0.7
            y: {
                if (root.hist.length < 2)
                    return 0;
                var hoch = root.hist[root.hist.length - 1][0];
                var tief = root.hist[0][0];
                if (hoch <= tief)
                    return 0;
                var t = (hoch - root.preis) / (hoch - tief);
                return Math.max(0, Math.min(1, t)) * bild.height;
            }
        }
    }
}
