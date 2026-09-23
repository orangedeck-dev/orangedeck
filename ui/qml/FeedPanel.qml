// Frame around the view: header, block details, graphic, legend, footer.
// Plain QtQuick. Colors are set from outside so the same component runs in
// the DMS plugin and in the standalone window.
import QtQuick
import "colors.js" as Palette
import "money.js" as Money
import "strings.js" as Tr
import "txtype.js" as TxType
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    property bool paused: false
    property real density: 1.0
    property bool headerVisible: true
    property bool infoVisible: true
    property bool legendVisible: true
    // `frostedInfo` (below): background behind the text details. Without it
    // they get lost when zoomed in over large bright tile areas.
    // Tile tapped, passed through from FeedCanvas
    signal txActivated(string txid)
    // The host keeps the color mode and remembers it across sessions
    signal colorModeRequested(string mode)
    property bool frostedInfo: true
    property bool frostedBlur: true
    // The dashed line above the mempool pile
    property bool rulerVisible: true
    property bool footerVisible: true
    // The tile graphic of the latest block in the middle
    property bool blockVisible: true
    property string colorMode: "age"
    // Which currency is shown; the daemon provides seven
    property string currency: "eur"
    property string sizeMode: "value"

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#c9a227"
    property color lineColor: "#2a2a38"
    // Tint of the frosted boxes (header, info, legend, goggles). Dark by
    // default; the DMS hosts pass a theme surface color so they turn light in
    // light mode.
    property color frostedTint: "#0b0b12"
    property int baseFont: 12
    property string lang: "de"
    property string btcZeichen: "\u20BF"
    property string pfeilLang: "\u27F6"

    readonly property bool showHeader: headerVisible && height >= 108
    readonly property bool showFooter: footerVisible && height >= 168
    readonly property bool showInfo: infoVisible && width >= 480 && height >= 300
    // On flat surfaces (dashboard tab) only the essentials, otherwise the
    // column runs into the pile
    readonly property bool infoCompact: height < 520
    // The legend together with the color switch fits from a height of 330;
    // the dashboard tab is 410 high.
    //
    // It is also shown only if it fits next to the block. The block grows with
    // the height (`blockSide`), so in a narrow, tall window (480 x 900) the
    // legend would cover half of it. The check uses the margin next to the
    // unzoomed block; `legend.width` is known even while the legend is hidden,
    // so there is no binding loop. The 16 are the eight points its box extends
    // outwards plus some air.
    readonly property bool legendePasst:
        (canvasView.width - canvasView.blockSide) / 2 >= legend.width + 16
    readonly property bool showLegend: legendVisible && width >= 420 && height >= 330
                                       && legendePasst

    // The color switch does not depend on the room for the legend. The legend
    // is a panel that needs space, the switch is a control. On the desktop `c`
    // cycles the color mode, so the switch may disappear below 420 points.
    // Without a keyboard it is the only way to change the mode, so on phones it
    // always stays. `Qt.platform.os` is checked directly, as in `fonts.js`;
    // passing a property through three levels would be too much plumbing for
    // this one question.
    readonly property bool showGoggles: legendVisible
        && (showLegend || Qt.platform.os === "android" || Qt.platform.os === "ios")
    // Same top margin on the left and the right. If each side computes its own
    // (with a minimum on one side only), the legend can sit up to thirty pixels
    // lower than the block details between 460 and 520 px of height, and the
    // gap below the header box looks uneven.
    //
    // The minimum applies to both sides: `FrostedPanel` extends eight pixels
    // outwards, and without it the boxes touch on flat surfaces.
    readonly property int sideTopMargin: Math.max(
        Math.round(root.baseFont * 1.6),
        Math.round(canvasView.height * (root.infoCompact ? 0.04 : 0.10)))
    readonly property var tip: feed ? feed.tip : ({})
    readonly property var nextBlock: feed ? feed.nextBlock : ({})
    readonly property var block: feed ? feed.block : ({})

    // Thousands and decimal separators depend on the language: German uses a
    // dot, English a comma, Polish and Czech a narrow space.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function dec(n, digits) {
        return Tr.fixed(n, digits, root.lang);
    }

    function fee(v) {
        if (!v)
            return "–";
        return (v < 10 ? dec(v, 2) : grp(v)) + " sat/vB";
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.round(Date.now() / 1000 - ts));
        if (s < 60)
            return Tr.t("ago.sec", root.lang, s);
        return Tr.t("ago.min", root.lang, Math.floor(s / 60));
    }

    function stamp(ts) {
        if (!ts)
            return "";
        var d = new Date(ts * 1000);
        return Qt.formatDateTime(d, Tr.datum(root.lang) + "  HH:mm");
    }

    function fiat(sats) {
        var pr = root.feed ? root.feed.price : null;
        return Tr.fiat(sats, Money.rate(pr, root.currency),
                       Money.symbol(Money.actual(pr, root.currency)), root.lang);
    }

    // Trigger the block animation by hand (key b in the standalone window), for
    // testing without waiting ten minutes for the next block
    function triggerBlockAnimation() {
        canvasView.startBlockAnimation();
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: agoLabel.text = root.ago(root.tip.time)
    }

    // ------------------------------------------------------------ Header
    // ------------------------------------------------ Background of the details
    FrostedPanel {
        content: header
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && header.visible
        z: 4
    }

    FrostedPanel {
        content: info
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && info.visible
        z: 4
    }

    FrostedPanel {
        content: legend
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && legend.visible
        z: 4
    }

    // The color switch needs the same background as the legend. It sits below
    // the legend, right where the pile grows upwards when the mempool is full,
    // and without a background its buttons are unreadable over the tiles.
    FrostedPanel {
        content: goggles
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        visible: root.frostedInfo && goggles.visible
        z: 4
    }

    Item {
        id: header

        z: 5

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showHeader ? Math.round(root.baseFont * 2.4) : 0
        visible: root.showHeader

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                spacing: 6

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.feed && root.feed.online ? "#5cb946" : "#d33f3f"
                }

                Text {
                    text: Tr.t("block", root.lang) + " " + root.grp(root.tip.height)
                    color: root.textColor
                    font.pixelSize: root.baseFont + 2
                    font.weight: Font.DemiBold
                }
            }

            Text {
                id: agoLabel

                text: root.ago(root.tip.time)
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }
        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                anchors.right: parent.right
                text: Tr.t("feed.inMempool", root.lang,
                           root.grp(root.feed ? root.feed.mempoolCount : 0))
                color: root.textColor
                font.pixelSize: root.baseFont
            }

            Text {
                anchors.right: parent.right
                text: root.fee(root.feed ? root.feed.feeFastest : 0)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }
        }
    }

    FeedCanvas {
        id: canvasView
        
        onTxActivated: function (txid) { root.txActivated(txid); }

        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.showHeader ? 4 : 0

        feed: root.feed
        paused: root.paused
        density: root.density
        colorMode: root.colorMode
        lang: root.lang
        sizeMode: root.sizeMode
        showBlock: root.blockVisible && height > 130
        showRuler: root.rulerVisible
        gridColor: root.lineColor
        rulerColor: root.dimColor
        labelFont: root.baseFont - 1
    }

    // -------------------------------------------------- Block details
    Column {
        id: info

        z: 5

        anchors.left: canvasView.left
        anchors.top: canvasView.top
        anchors.topMargin: root.sideTopMargin
        width: Math.min(160, root.width * 0.22)
        spacing: 2
        visible: root.showInfo && root.block.height !== undefined

        Text {
            text: Tr.t("lastBlock", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            text: root.grp(root.block.height)
            color: root.textColor
            font.pixelSize: root.baseFont + 6
            font.weight: Font.DemiBold
        }

        Text {
            text: root.stamp(root.block.time)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            bottomPadding: 6
        }

        // Label for the number below. It is the sum of all outputs of this
        // block, not the mempool and not "what changed hands": change sent back
        // to the sender counts too, so it is regularly higher than what actually
        // moved.
        Text {
            visible: !root.infoCompact
            text: Tr.t("feed.movedValue", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: root.btcZeichen + " " + root.dec((root.block.totalValue || 0) / 1e8, 4)
            color: root.textColor
            font.pixelSize: root.baseFont
        }

        Text {
            visible: !root.infoCompact
            text: root.fiat(root.block.totalValue)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            bottomPadding: 6
        }

        Text {
            visible: !root.infoCompact
            text: Tr.t("feed.bytes", root.lang, root.grp(root.block.size))
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            text: Tr.t("txlist.count", root.lang, root.grp(root.block.nTx))
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
            bottomPadding: 6
        }

        Text {
            visible: !root.infoCompact
            text: Tr.t("feed.avgFee", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: (root.infoCompact ? "Ø " : "") + root.dec(root.block.avgFeeRate, 2) + " sat/vByte"
            color: root.textColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            visible: !root.infoCompact
            text: root.block.pool || ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            topPadding: 6
        }
    }

    // ------------------------------------------------------------- Legend
    Column {
        id: legend

        z: 5

        anchors.right: canvasView.right
        anchors.top: canvasView.top
        anchors.topMargin: root.sideTopMargin
        spacing: 4
        visible: root.showLegend

        Text {
            anchors.right: parent.right
            text: Tr.t(root.sizeMode === "vbytes" ? "feed.sizeVbytes" : "feed.sizeValue", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Repeater {
            // The legend numbers use the same formatting as every other
            // number. As plain text, the English UI showed "< 1.024"
            // (one thousand twenty-four or one point zero?) and "< 0,01"
            // next to English formats everywhere else.
            model: root.sizeMode === "vbytes"
                ? [256, 1024, 2304, 4096, 6400].map(function (n) {
                    return "< " + Tr.group(n, root.lang);
                })
                : [0.01, 0.1, 1, 10, 100].map(function (n) {
                    return "< " + root.btcZeichen + " "
                         + Tr.fixed(n, n < 1 ? (n < 0.1 ? 2 : 1) : 0, root.lang);
                })

            Row {
                spacing: 6
                anchors.right: parent.right

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                    font.family: Fonts.mono()
                }

                Item {
                    width: 22
                    height: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3 + index * 4
                        height: width
                        color: Palette.blockAgeColor()
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            text: Tr.t(root.colorMode === "type" ? "feed.typeScale"
                : (root.colorMode === "fee" ? "feed.feeScale" : "feed.ageScale"), root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            topPadding: 4
        }

        // Color table of the transaction types. Only those present in the block.
        Repeater {
            model: {
                if (root.colorMode !== "type")
                    return [];
                var z = canvasView.blockTypeCounts || [];
                var out = [];
                for (var i = 0; i < z.length; i++) {
                    if (z[i] > 0)
                        out.push({ "i": i, "n": z[i] });
                }
                out.sort(function (a, b) {
                    return b.n - a.n;
                });
                return out;
            }

            Row {
                id: artZeile

                required property var modelData

                readonly property var meta: TxType.info(TxType.kindAt(artZeile.modelData.i))

                anchors.right: parent.right
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t(TxType.labelKey(TxType.kindAt(artZeile.modelData.i)), root.lang)
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont - 3
                    height: width
                    radius: 2
                    color: artZeile.meta.color
                }
            }
        }

        Text {
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            visible: root.colorMode === "type"
            text: Tr.t("feed.noTypeMempool", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            topPadding: 2
        }

        Row {
            anchors.right: parent.right
            spacing: 4
            visible: root.colorMode !== "type"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorMode === "fee" ? "2" : "0"
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }

            Rectangle {
                width: 90
                height: 8
                anchors.verticalCenter: parent.verticalCenter

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(2) : Palette.ageColor(0)
                    }

                    GradientStop {
                        position: 0.5
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(16) : Palette.ageColor(30000)
                    }

                    GradientStop {
                        position: 1
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(128) : Palette.ageColor(60000)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorMode === "fee" ? "128+" : "60+"
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }
        }
    }

    // Switch for the tile color. Same buttons as in the explorer, here with
    // three modes: age, fee, type.
    TileGoggles {
        id: goggles

        z: 6
        // Below the legend at the right edge. Bottom left it would sit in the
        // pile and be unreadable over the tiles.
        anchors.right: legend.right
        // Below the legend, but not lower than the pile reaches.
        //
        // The gap to the legend is computed: the switch has its own background,
        // so the gap lies between two boxes that each extend eight pixels
        // outwards (`FrostedPanel.pad`). Less than that makes the boxes overlap,
        // and two translucent surfaces on top of each other give a dark seam.
        //
        // The lower clamp is the second part: in the "type" mode the legend has
        // seven more rows, and on a flat surface it would push the switch out of
        // the drawing area into the footer, where its box covers the price. So
        // it ends at the bottom of the pile at the latest.
        //
        // Without a legend it sits right under the header, i.e. under the row
        // with block height and sat/vB. An invisible item keeps its height in
        // QML, so anchoring below the hidden legend would leave it below a panel
        // nobody sees, seven rows down in the "type" mode.
        //
        // Positions derived from content move with it. That is fine for a label
        // but not for a control, which belongs at a place where it can be found
        // again, here the top edge. For that reason it is not placed below the
        // block (with zoom the block can be anywhere) and not at `sideTopMargin`
        // (ten percent of the height, meant for the legend; on a phone that puts
        // the box back onto the tiles).
        //
        // Below the header the same gap as below the legend applies: both boxes
        // extend 8 points outwards, so a smaller offset makes them overlap.
        y: Math.min(root.showLegend
                    ? legend.y + legend.height + 8 + 8 + 2
                    : (root.showHeader ? header.y + header.height + 8 + 8 + 2
                                       : canvasView.y + 2),
                    canvasView.y + canvasView.height - goggles.height)
        // Exactly as wide as the button row so the background behind it
        // encloses it instead of sitting next to it. A guessed width
        // (`baseFont * 14`) was too tight for the German labels.
        width: goggles.schalterBreite
        alignRight: true
        visible: root.showGoggles
        mode: root.colorMode
        lang: root.lang
        modes: [
            { "k": "age", "l": Tr.t("color.age", root.lang) },
            { "k": "fee", "l": Tr.t("color.fee", root.lang) },
            { "k": "type", "l": Tr.t("color.type", root.lang) }
        ]
        // The color table is already in the legend on the right; showing it
        // twice would only be noise. Only the switch itself stays here.
        counts: []
        total: 0
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.baseFont
        onPicked: function (m) {
            root.colorModeRequested(m);
        }
    }

    // ------------------------------------------------------------ Footer
    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showFooter ? Math.round(root.baseFont * 1.9) : 0
        visible: root.showFooter

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: root.lineColor
            opacity: 0.6
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: Tr.t("feed.nextBlockLine", root.lang,
                           root.grp(root.nextBlock.nTx),
                           root.fee(root.nextBlock.medianFee).replace(" sat/vB", ""))
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.feed
                ? root.btcZeichen + " " + Tr.price1(Money.rate(root.feed.price, root.currency),
                                   Money.symbol(Money.actual(root.feed.price, root.currency)),
                                   root.lang)
                : ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }
    }

    // ---------------------------------------------------------- Tooltip
    // Shows the transaction details on hover, as on bitfeed.live. Inputs and
    // outputs are not part of the data stream and are loaded one by one on
    // demand.
    property var inOutCache: ({})
    property string inOutKey: ""
    property string inOutText: ""

    function loadInOut(txid) {
        if (!txid)
            return;
        if (root.inOutCache[txid] !== undefined) {
            root.inOutText = root.inOutCache[txid];
            root.inOutKey = txid;
            return;
        }
        root.inOutKey = txid;
        root.inOutText = "";
        var req = new XMLHttpRequest();
        req.open("GET", "https://mempool.space/api/tx/" + txid);
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            var out = "";
            if (req.status === 200) {
                try {
                    var d = JSON.parse(req.responseText);
                    var ni = (d.vin || []).length, no = (d.vout || []).length;
                    out = Tr.ersetzen(
                        Tr.t("tip.inOut", root.lang, ni,
                             Tr.t(ni === 1 ? "in.one" : "in.many", root.lang), no,
                             Tr.t(no === 1 ? "out.one" : "out.many", root.lang)),
                        root.btcZeichen, root.pfeilLang);
                } catch (e) {}
            }
            root.inOutCache[txid] = out;
            if (root.inOutKey === txid)
                root.inOutText = out;
        };
        req.send();
    }

    Timer {
        id: inOutDelay

        interval: 350
        onTriggered: {
            var t = canvasView.hoveredTx;
            if (t && t.t)
                root.loadInOut(t.t);
        }
    }

    Connections {
        target: canvasView

        function onHoveredTxChanged() {
            var t = canvasView.hoveredTx;
            if (!t || !t.t) {
                inOutDelay.stop();
                root.inOutText = "";
                root.inOutKey = "";
                return;
            }
            if (root.inOutCache[t.t] !== undefined) {
                root.inOutKey = t.t;
                root.inOutText = root.inOutCache[t.t];
            } else {
                root.inOutText = "";
                inOutDelay.restart();
            }
        }
    }

    FrostedPanel {
        content: tip
        backdropSource: canvasView
        blurred: root.frostedBlur
        tint: root.frostedTint
        pad: 0
        visible: root.frostedInfo && tip.visible
        z: 199
    }

    Rectangle {
        id: tip

        readonly property var tx: canvasView.hoveredTx

        // The rate has to match the two rows above it. `r` from the state is
        // the effective rate from mempool.space, which includes ancestors
        // (CPFP) and sigops. Next to size and fee that gives a different
        // number (1000 sat / 219.25 vB = 4.56, but 4.54 shown). The explorer
        // also computes fee per vbyte (`fee / (weight/4)`), so the tooltip
        // would contradict it for the same transaction.
        //
        // So this shows the rate that can be checked against the numbers
        // shown; the effective rate is added as its own row when it differs.
        // The tile color stays with the effective rate, since that is what a
        // miner selects by.
        readonly property real eigenRate: tip.tx && tip.tx.v > 0
            ? tip.tx.f / tip.tx.v : (tip.tx ? (tip.tx.r || 0) : 0)
        // A difference only counts if it is visible: one percent, but at least
        // 0.01 sat/vB; anything smaller disappears when rounding to two
        // decimals anyway.
        readonly property bool rateWeichtAb: tip.tx && (tip.tx.r || 0) > 0
            && Math.abs(tip.tx.r - tip.eigenRate)
               > Math.max(0.01, tip.eigenRate * 0.01)

        visible: tx !== null && root.width > 300
        // Size from the content, but via childrenRect instead of the column:
        // if the column were centered in the rectangle, the rectangle's size
        // would depend on the column and vice versa. QML breaks that loop and
        // leaves both at zero.
        width: tipCol.width + 20
        height: tipCol.height + 16
        radius: 6
        // Same dark background as the other details: on the tile field the line
        // color is too light and the text gets lost against it.
        color: Qt.rgba(root.frostedTint.r, root.frostedTint.g, root.frostedTint.b, 0.88)
        border.width: 1
        border.color: Qt.lighter(root.lineColor, 1.4)
        z: 200

        x: Math.max(0, Math.min(root.width - width, canvasView.x + canvasView.hoverX + 14))
        y: Math.max(0, Math.min(root.height - height, canvasView.y + canvasView.hoverY - height - 12))

        Column {
            id: tipCol

            x: 10
            y: 8
            width: childrenRect.width
            height: childrenRect.height
            spacing: 3

            Text {
                text: tip.tx && tip.tx.t
                    ? Tr.t("tip.txid", root.lang, String(tip.tx.t).substring(0, 20) + "…") : ""
                color: root.textColor
                font.pixelSize: root.baseFont - 1
                font.family: Fonts.mono()
            }

            // If the transaction belongs to a watched wallet, that is the most
            // important detail about it, so it goes to the top.
            Text {
                visible: tip.tx && tip.tx.m === 1
                text: Tr.t("feed.ownWallet", root.lang)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                visible: root.inOutText.length > 0
                text: root.inOutText
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.t("tip.size", root.lang, root.dec(tip.tx.v, 2)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.t("tip.rate", root.lang, root.dec(tip.eigenRate, 2)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                visible: tip.rateWeichtAb
                text: tip.tx ? Tr.t("tip.rateEff", root.lang, root.dec(tip.tx.r, 2)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.t("tip.fee", root.lang, root.grp(tip.tx.f)) : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? Tr.ersetzen(Tr.t("tip.total", root.lang, Tr.fixed(
                                    (tip.tx.a / 1e8), 8, root.lang)),
                                    root.btcZeichen, root.pfeilLang)
                               + "  " + root.fiat(tip.tx.a) : ""
                color: root.textColor
                font.pixelSize: root.baseFont - 2
            }
        }
    }

    // On its own background, not bare over the block. Centered, the text
    // sits right on the orange block and is hard to read in its dim color.
    // The pill has the same opacity as the tooltip, and the red is the same
    // as for "no connection" in the clock.
    Rectangle {
        anchors.centerIn: parent
        visible: root.feed !== null && !root.feed.online
        z: 25
        width: keineVerbindung.implicitWidth + root.baseFont * 1.6
        height: keineVerbindung.implicitHeight + root.baseFont * 0.9
        radius: height / 2
        color: Qt.rgba(0.05, 0.05, 0.08, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Text {
            id: keineVerbindung

            anchors.centerIn: parent
            text: Tr.t("feed.noConnection", root.lang)
            color: "#e06c6c"
            font.pixelSize: root.baseFont
        }
    }
}
