// The projected block, live: the tile graphic of what would fit into the
// next block right now, and what changes in it.
//
// Two sources, both through the daemon:
//
//   the figures  from the state (`feed.projected`). They arrive over the
//                WebSocket, so they need no request of their own and update
//                at the pace of the state.
//   the tiles    from `/lookup/projectedtiles/<rank>`. Only this request makes
//                the daemon subscribe to `track-mempool-block`; once requests
//                stop, it unsubscribes by itself after twenty seconds. So it
//                only asks while someone is looking, because the stream costs
//                7.8 kB/s.
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Column {
    id: root

    property var feed: null
    property int rank: 0
    // Is anyone looking? Without this the polling keeps running while hidden,
    // which cost the dashboard tab 7.4 % CPU.
    property bool live: true
    property int refreshMs: 2000
    property bool showHeader: true
    property real tileHeight: 0
    // Tile color: "fee" or "type" (mempool goggles). Held by the parent so the
    // choice survives paging through the explorer.
    property string colorMode: "fee"

    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    property string lang: "de"
    property string btcZeichen: "\u20BF"

    signal txPicked(string txid)
    signal colorModeRequested(string mode)

    // The figures come from the state and change continuously.
    readonly property var info: (feed && feed.projected && feed.projected.length > rank)
        ? feed.projected[rank] : null
    // The last projected block is a catch-all: it holds the whole rest of the
    // mempool, often several block sizes.
    readonly property bool sammelposten: info && info.blockVSize > 1.05e6

    property var tiles: null
    // The revision the next request refers to. The daemon then sends only the
    // changes since then.
    property int seq: 0
    property string error: ""
    property bool busy: false
    property bool unveraendert: false
    property bool __pending: false

    spacing: uiFont * 0.5

    // Thousands separator in the notation of the language: German uses a dot,
    // English a comma. This is not cosmetic, "1.234" means either one thousand
    // two hundred thirty-four or one point two, depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function refresh() {
        if (!root.feed || root.__pending || !root.live)
            return;
        root.__pending = true;
        if (root.tiles === null)
            root.busy = true;
        var r = root.rank;
        // Full snapshot the first time, deltas after that.
        var frage = String(r) + ((root.tiles && root.seq > 0) ? "-" + root.seq : "");
        root.feed.lookup("projectedtiles", frage, function (d, err) {
            root.__pending = false;
            root.busy = false;
            if (r !== root.rank)
                return;
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.seq = d.seq || 0;
            if (d.full || !root.tiles) {
                root.unveraendert = false;
                root.tiles = d;
                return;
            }
            // Nothing changed, so skip recomputing and repainting.
            if (!(d.txs && d.txs.length) && !(d.removed && d.removed.length)) {
                root.unveraendert = true;
                return;
            }
            root.unveraendert = false;
            // If applying the delta fails (e.g. no packing exists yet), fetch the full
            // snapshot next time.
            if (!tileView.applyDelta(d))
                root.seq = 0;
        });
    }

    onRankChanged: {
        root.tiles = null;
        root.seq = 0;
        root.error = "";
        refresh();
    }

    onLiveChanged: {
        if (root.live)
            refresh();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: root.refreshMs
        repeat: true
        running: root.live && root.feed !== null
        onTriggered: root.refresh()
    }

    // ----------------------------------------------------------- Header
    Item {
        width: parent.width
        height: root.showHeader ? headRow.height : 0
        visible: root.showHeader

        Row {
            id: headRow

            spacing: root.uiFont * 0.5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.rank === 0 ? Tr.t("nextBlock", root.lang)
                                      : Tr.t("proj.nth", root.lang, root.rank + 1)
                color: root.textColor
                font.pixelSize: root.uiFont * 1.05
            }

            // The dot shows the feed is live. Deliberately without a pulse: an endless
            // animation keeps rendering at sixty frames per second, which measured 5 %
            // CPU for a six pixel dot.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.uiFont * 0.45
                height: width
                radius: width / 2
                color: root.tiles ? "#2f9e63" : root.dimColor
                opacity: root.tiles ? 1 : 0.4
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.info
                    ? Tr.t("proj.summary", root.lang, root.grp(root.info.nTx),Tr.fixed(
                           root.info.medianFee, 1, root.lang))
                    : ""
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.85
            }
        }
    }

    Text {
        width: parent.width
        visible: root.sammelposten && root.info !== null
        text: root.info
            ? Tr.t("proj.overflow", root.lang, Math.round(root.info.blockVSize / 1e6))
            : ""
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.8
    }

    // What changed since the last request
    Text {
        width: parent.width
        text: {
            if (root.error.length)
                return Tr.grund(root.error, root.lang);
            if (root.busy)
                return Tr.t("proj.fetching", root.lang);
            if (!root.tiles)
                return "";
            if (root.unveraendert || (tileView.addedCount === 0 && tileView.removedCount === 0))
                return Tr.t("proj.unchanged", root.lang);
            var s = [];
            if (tileView.addedCount > 0)
                s.push(Tr.t("proj.changed", root.lang, tileView.addedCount));
            if (tileView.removedCount > 0)
                s.push(Tr.t("proj.dropped", root.lang, tileView.removedCount));
            return s.join("  ·  ");
        }
        color: root.error.length ? "#e06c6c" : root.dimColor
        font.pixelSize: root.uiFont * 0.8
    }

    TileGoggles {
        width: parent.width
        visible: root.tiles !== null
        mode: root.colorMode
        lang: root.lang
        counts: tileView.typeCounts
        total: tileView.squares.length
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onPicked: function (m) {
            root.colorModeRequested(m);
        }
    }

    BlockTiles {
        id: tileView

        btcZeichen: root.btcZeichen
        width: parent.width
        height: root.tileHeight > 0 ? root.tileHeight : Math.min(parent.width, root.uiFont * 34)
        visible: root.tiles !== null
        live: true
        colorMode: root.colorMode
        block: root.tiles
        dimColor: root.dimColor
        labelSize: root.uiFont * 0.85
        onTxPicked: function (txid) {
            root.txPicked(txid);
        }
    }
}
