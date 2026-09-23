// Explorer home page: stats, projected blocks from the mempool, the chain
// of confirmed blocks and recently seen transactions. Every click leads
// further in from here.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Column {
    id: root

    property var feed: null
    // Is anyone looking at the home page? Only then is the projected block
    // tracked; it costs 7.8 kB/s while running.
    property bool live: true
    property string colorMode: "fee"
    property string currency: "eur"
    // Which sections the home page shows. Empty means all.
    property var parts: []
    property var panelIds: []

    function zeigt(id) {
        var f = root.parts;
        if (!f || !f.length || typeof f.indexOf !== "function")
            return true;
        return f.indexOf(id) >= 0;
    }
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    property string lang: "de"
    property string btcZeichen: "\u20BF"

    signal blockPicked(string hash)
    signal txPicked(string txid)
    signal projectedPicked(int rank, var data)
    signal colorModeRequested(string mode)
    signal historyPicked()

    spacing: uiFont * 1.4

    // Thousands separator per language: German uses a period, English a comma.
    // This matters: "1.234" means either one thousand two hundred thirty-four
    // or one point two three four depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    // ------------------------------------------------------- Stats
    Flow {
        width: parent.width
        visible: root.zeigt("stats")
        spacing: root.uiFont * 1.8

        Repeater {
            model: [
                { "k": Tr.t("blockHeight", root.lang), "v": root.feed ? root.grp(root.feed.tipHeight) : "–" },
                { "k": Tr.t("explorer.inMempool", root.lang), "v": root.feed ? root.grp(root.feed.mempoolCount) : "–" },
                { "k": Tr.t("fee", root.lang), "v": root.feed && root.feed.feeFastest
                    ? Tr.fixed(root.feed.feeFastest, 1, root.lang) + " sat/vB" : "–" },
                { "k": Tr.t("hashrate", root.lang), "v": (root.feed && root.feed.hashrate.current)
                    ? Math.round(root.feed.hashrate.current / 1e18) + " EH/s" : "–" },
                { "k": Tr.t("difficulty", root.lang), "v": (root.feed && root.feed.difficulty.change !== undefined)
                    ? (root.feed.difficulty.change >= 0 ? "+" : "")
                      + Tr.fixed(root.feed.difficulty.change, 2, root.lang) + " %" : "–" },
                { "k": Tr.t("price", root.lang), "v": root.feed
                    ? Tr.price1(Money.rate(root.feed.price, root.currency),
                                Money.symbol(Money.actual(root.feed.price, root.currency)),
                                root.lang) : "–" }
            ]

            Column {
                id: stat

                required property var modelData

                spacing: root.uiFont * 0.1

                Text {
                    text: stat.modelData.k
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }

                Text {
                    text: stat.modelData.v
                    color: root.textColor
                    font.pixelSize: root.uiFont * 1.25
                }
            }
        }
    }

    // Projected and confirmed blocks in one strip
    BlockChain {
        width: parent.width
        visible: root.zeigt("chain")
        feed: root.feed
        lang: root.lang
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onBlockPicked: function (hash) {
            root.blockPicked(hash);
        }
        onProjectedPicked: function (rank, data) {
            root.projectedPicked(rank, data);
        }
    }

    // Further back than the strip reaches
    Text {
        id: historieLink

        visible: root.zeigt("chain")
        text: Tr.t("explorer.browseAll", root.lang)
        color: historieMaus.containsMouse ? root.accentColor : root.dimColor
        font.pixelSize: root.uiFont * 0.85

        MouseArea {
            id: historieMaus

            anchors.fill: parent
            anchors.margins: -root.uiFont * 0.3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.historyPicked()
        }
    }

    // ------------------------- the next block, tracked live
    ProjectedBlock {
        width: parent.width
        btcZeichen: root.btcZeichen
        visible: root.zeigt("next")
        feed: root.feed
        live: root.live && root.zeigt("next")
        colorMode: root.colorMode
        lang: root.lang
        onColorModeRequested: function (m) {
            root.colorModeRequested(m);
        }
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onTxPicked: function (txid) {
            root.txPicked(txid);
        }
    }

    // ------------------------------------------------------- Panels
    MainPanels {
        width: parent.width
        visible: root.zeigt("panels")
        panels: root.panelIds
        lang: root.lang
        feed: root.feed
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onTxPicked: function (txid) {
            root.txPicked(txid);
        }
    }

    // -------------------------------------- recently seen transactions
    Column {
        width: parent.width
        spacing: root.uiFont * 0.25
        visible: root.zeigt("recent") && root.feed
                 && (root.feed.snap.recent || []).length > 0

        Text {
            text: Tr.t("explorer.recent", root.lang)
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.85
        }

        Repeater {
            model: {
                var r = (root.feed && root.feed.snap.recent) || [];
                return r.slice(-12).reverse();
            }

            Rectangle {
                id: trow

                required property var modelData

                width: parent.width
                height: root.uiFont * 2
                radius: 4
                color: tarea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: root.uiFont * 0.6
                    spacing: root.uiFont

                    Text {
                        width: root.uiFont * 14
                        elide: Text.ElideMiddle
                        text: trow.modelData.t || ""
                        color: root.textColor
                        font.pixelSize: root.uiFont * 0.85
                        font.family: Fonts.mono()
                    }

                    Text {
                        width: root.uiFont * 6
                        text: trow.modelData.r !== undefined
                            ? Tr.fixed(trow.modelData.r, 2, root.lang) + " sat/vB" : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }

                    Text {
                        // `a` is the amount in sat, `v` the virtual size
                        text: trow.modelData.a !== undefined
                            ? root.btcZeichen + " " + Tr.fixed(trow.modelData.a / 1e8, 8, root.lang) : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }
                }

                MouseArea {
                    id: tarea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: trow.modelData.t ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (trow.modelData.t)
                            root.txPicked(String(trow.modelData.t));
                    }
                }
            }
        }
    }
}
