// Reads the state delivered by orangedeck and emits new transactions and
// found blocks as signals.
//
// Only `import QtQuick` on purpose: this file runs unchanged in
// DankMaterialShell, in the standalone Qt app and on Android. The Quickshell
// pieces it would otherwise need are replaced:
//
//   Quickshell.env  ->  not needed, the location is in `endpoint`
//   FileView        ->  XMLHttpRequest against the loopback interface.
//                       Reading file:// is not an option: Qt gates it behind
//                       QML_XHR_ALLOW_FILE_READ=1, and without that variable
//                       the request stays at readyState 1. HTTP has no such
//                       special case, on desktop or on Android.
//   Process         ->  does not belong here. The daemon is started by
//                       OrangeDeckDaemon.qml in the shell and by
//                       orangedeck-window for the standalone window.
import QtQuick

Item {
    id: root

    visible: false

    property bool active: true
    // Defaults to the loopback interface of the local daemon. On a tablet this
    // can point to a machine on the local network instead, as a deliberate
    // setting, not a default.
    property string endpoint: "http://127.0.0.1:21021"
    property int pollMs: 400

    // Where the data comes from:
    //
    //   "daemon"  the local service on 127.0.0.1. Default on the desktop: it
    //             keeps one connection for all windows and widgets, can derive
    //             wallets and poll the miner on the home network.
    //   "direct"  the UI talks to mempool.space itself. Default on the phone:
    //             there is no service there, and a widget that only works while
    //             the home machine is on is no widget.
    //   "auto"    try the service first; if nothing answers within `autoMs`,
    //             go direct. Meant for the DMS plugin: installed from the DMS
    //             plugin directory it is just the folder, with no repo, no unit
    //             and no orangedeck in PATH. With the service present it is used,
    //             wallets included.
    //
    // To the outside there is no difference: both sources go through the same
    // evaluation and all views read the same properties.
    property string mode: "daemon"
    property int autoMs: 4000

    // Decided once per session and then kept. Switching back and forth on every
    // hiccup of the service would make the Wallet tab come and go, and
    // `FeedTabs.reiterPruefen` resets a remembered view to the feed when that
    // happens. If the service starts later, the decision applies on the next
    // shell start.
    property string __autoMode: ""
    readonly property bool __suchtDienst: root.mode === "auto" && root.__autoMode === ""
    readonly property string effMode: root.mode !== "auto" ? root.mode
        : (root.__autoMode || "daemon")
    readonly property bool direkt: root.effMode === "direct"

    // While searching, the regular service poll is running. No separate probe
    // request is needed: the first reply to `/state` answers the question.
    Timer {
        interval: root.autoMs
        repeat: false
        running: root.active && root.__suchtDienst

        onTriggered: {
            if (root.__suchtDienst)
                root.__autoMode = "direct";
        }
    }
    // What direct mode cannot do; the views hide themselves accordingly.
    //
    // The miner is not listed here: on the same Wi-Fi `DirectMiner` polls it
    // itself. What can be missing is the address, not the path. The Miner tab
    // shows the network when there is no device, so it always has content.
    //
    // `__suchtDienst` is part of the Wallet condition: during the search `direkt`
    // is still false, but nobody knows yet whether a service exists. A Wallet tab
    // that disappears after four seconds is worse than one that shows up four
    // seconds later.
    readonly property bool canWallet: !root.direkt && !root.__suchtDienst
    // The market also works in direct mode (`DirectMarket.qml`). Without
    // QtWebSockets that loader fails and the tab stays hidden.
    //
    // Do not wait for `Loader.Ready`. Before the loader is done there would be no
    // Market tab, and `FeedTabs.reiterPruefen` would reset a remembered Market
    // view to the feed on every start.
    readonly property bool canMarket: !root.direkt || markt.status !== Loader.Error

    // Addresses from the settings. Unused in daemon mode, where the service
    // reads `sources.json`.
    property var minerHosts: []

    // Parsed state
    property var snap: ({})
    property var block: ({})          // tile data of the most recently found block
    property int seq: 0
    property real stateTs: 0
    property real blockEventTs: 0
    property bool online: false
    property string source: ""
    property string lastError: ""

    readonly property int mempoolCount: (snap.mempool && snap.mempool.count) || 0
    readonly property int mempoolVsize: (snap.mempool && snap.mempool.vsize) || 0
    readonly property real feeFastest: (snap.fees && snap.fees.fastest) || 0
    readonly property real feeHour: (snap.fees && snap.fees.hour) || 0
    readonly property int vbps: snap.vbps || 0
    readonly property var tip: snap.tip || ({})
    readonly property var nextBlock: snap.nextBlock || ({})
    // The full row of projected blocks as it arrives over the WebSocket. Same
    // field names as `/lookup/mempoolblocks/now`, but without a separate request,
    // so it updates at the pace of the state.
    readonly property var projected: snap.projected || []
    readonly property var price: snap.price || ({})
    readonly property int tipHeight: tip.height || 0
    // Slow metrics and the own miner, fetched by the daemon on the side.
    readonly property var difficulty: snap.difficulty || ({})
    readonly property var hashrate: snap.hashrate || ({})
    // Miner: a list, since there can be more than one device. The daemon
    // delivers all fields normalized, hashrate always in H/s. In direct mode they
    // come from `DirectMiner`, otherwise from the daemon state. The shape is the
    // same, so `MinerView` cannot tell the difference, just like the mempool.
    readonly property var miners: root.direkt
        ? (bergwerk.item ? bergwerk.item.miners : [])
        : (snap.miners || [])
    readonly property var minerTotal: root.direkt
        ? (bergwerk.item ? bergwerk.item.minerTotal : ({}))
        : (snap.minerTotal || ({}))
    // Summary of the watched wallets. The wallet view fetches full details via
    // `/wallets`; they are too large for the state.
    readonly property var wallets: snap.wallets || []
    readonly property bool walletBusy: snap.walletBusy || false
    readonly property bool walletConfigured: wallets.length > 0
    // History per device: recorded by the daemon, or by `DirectMiner` in direct
    // mode.
    readonly property var minerHistory: root.direkt
        ? (bergwerk.item ? bergwerk.item.minerHistory : ({}))
        : (snap.minerHistory || ({}))
    readonly property bool minerConfigured: miners.length > 0
    readonly property bool minerOnline: (minerTotal.online || 0) > 0

    signal transactionsArrived(var txs)
    signal blockMined(var tip)

    // --- Fetching ---
    // One request at a time: with a 400 ms interval and a stalled network path,
    // requests would otherwise pile up.
    property bool __statePending: false
    property bool __blockPending: false
    // Version of the slow fields we already have; the service then omits them.
    // -1 means "none yet".
    property int __slowRev: -1

    function __get(path, pendingKey, onOk, onFail) {
        if (root[pendingKey])
            return;
        root[pendingKey] = true;
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            root[pendingKey] = false;
            if (x.status === 200 && x.responseText)
                onOk(x.responseText);
            else if (onFail)
                onFail();
        };
        try {
            x.open("GET", root.endpoint + path);
            x.send();
        } catch (e) {
            root[pendingKey] = false;
            if (onFail)
                onFail();
        }
    }

    // Arbitrary request against the daemon, returns JSON. Separate from `lookup`,
    // which is for outside paths; this is for the service's own paths
    // (`/wallets`, `/market...`).
    function getJson(path, done) {
        if (root.direkt) {
            // In direct mode the market computes this itself from the same responses.
            if (path.indexOf("/market") === 0 && markt.item) {
                markt.item.getJson(path, done);
                return;
            }
            // `/wallets`: deriving from the xpub is point arithmetic on secp256k1 and
            // stays in the service.
            done(null, "im Direktbezug nicht verfuegbar");
            return;
        }
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status !== 200) {
                done(null, "nicht erreichbar");
                return;
            }
            try {
                done(JSON.parse(x.responseText), null);
            } catch (e) {
                done(null, "Antwort nicht lesbar");
            }
        };
        try {
            x.open("GET", root.endpoint + path);
            x.send();
        } catch (e) {
            done(null, String(e));
        }
    }

    // Price history. `span` is one of 24h, 7d, 30d, 90d, 1y, max.
    //
    // Deliberately not part of the state: the state is fetched two and a half
    // times per second, the history changes about once an hour. It is only
    // fetched when someone is actually looking at the chart.
    function prices(span, cur, done) {
        if (root.direkt) {
            if (direkt.item)
                direkt.item.prices(span, cur, done);
            else
                done(null, "Direktbezug nicht bereit");
            return;
        }
        root.getJson("/prices?span=" + span + "&cur=" + cur, done);
    }

    // Hashrate, difficulty and pools for the Network tab. `span` is one of 30d,
    // 90d, 1y, 3y, max. Not part of the state for the same reason as the price
    // history: it is only fetched when someone looks.
    function network(span, done) {
        if (root.direkt) {
            if (direkt.item)
                direkt.item.network(span, done);
            else
                done(null, "Direktbezug nicht bereit");
            return;
        }
        root.getJson("/network?span=" + span, done);
    }

    // Single lookup for the explorer. Goes through the daemon, not straight out:
    // it knows the data source (mempool.space or an own node) and caches the
    // responses.
    function lookup(kind, arg, done) {
        if (root.direkt) {
            if (direkt.item)
                direkt.item.lookup(kind, String(arg), done);
            else
                done(null, "Direktbezug nicht bereit");
            return;
        }
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status === 200) {
                try {
                    done(JSON.parse(x.responseText), null);
                    return;
                } catch (e) {
                    done(null, "Antwort nicht lesbar");
                    return;
                }
            }
            var msg = "nicht erreichbar";
            try {
                msg = JSON.parse(x.responseText).error || msg;
            } catch (e) {}
            done(null, msg);
        };
        try {
            x.open("GET", root.endpoint + "/lookup/" + kind + "/" + encodeURIComponent(arg));
            x.send();
        } catch (e) {
            done(null, String(e));
        }
    }

    function __parse(txt) {
        if (!txt)
            return;
        var d;
        try {
            d = JSON.parse(txt);
        } catch (e) {
            return;
        }
        root.__apply(d);
    }

    // The core. It does not care where the state comes from: the service
    // delivers it as JSON, direct mode builds it itself; from here on the path
    // is the same.
    function __apply(d) {
        if (!d || typeof d !== "object")
            return;

        // Whatever the service left out stays from the previous state. It trims two
        // things: transactions already known (`?since`) and the slow fields while
        // they have not changed (`?slow`). A full 32 kB every 400 ms cost 20 % CPU;
        // trimmed it is about 2 kB.
        var alt = root.snap;
        if (alt && typeof alt === "object") {
            for (var k in alt) {
                if (d[k] === undefined)
                    d[k] = alt[k];
            }
        }
        if (typeof d.slowRev === "number")
            root.__slowRev = d.slowRev;

        root.snap = d;
        root.stateTs = d.ts || 0;
        root.source = d.source || "";
        root.lastError = d.error || "";
        root.online = (Date.now() / 1000 - root.stateTs) < 12 && root.source !== "offline";
        // The service answered, which settles the `mode: "auto"` question before the
        // timer above runs out.
        if (root.__suchtDienst)
            root.__autoMode = "daemon";

        var fresh = [];
        var rec = d.recent || [];
        for (var i = 0; i < rec.length; i++) {
            if (rec[i].n > root.seq)
                fresh.push(rec[i]);
        }
        var newSeq = d.seq || root.seq;
        // On the very first load, do not rain the whole buffer down at once.
        if (root.seq === 0) {
            fresh = fresh.slice(-12);
        }
        root.seq = newSeq;
        if (fresh.length > 0)
            root.transactionsArrived(fresh);

        var be = d.blockEvent || 0;
        if (be > root.blockEventTs) {
            var first = root.blockEventTs === 0;
            root.blockEventTs = be;
            if (!first)
                root.blockMined(d.tip || {});
        }
    }

    Timer {
        interval: root.pollMs
        repeat: true
        running: root.active && !root.direkt
        triggeredOnStart: true
        onTriggered: root.__get("/state?since=" + root.seq + "&slow=" + root.__slowRev,
                                "__statePending", root.__parse, function () {
            root.online = false;
        })
    }

    // Direct mode lives in its own file because it needs `QtWebSockets`, a
    // package that is not installed everywhere. Loaded through a Loader, a
    // missing module only disables this mode, not the whole app.
    Loader {
        id: direkt

        active: root.direkt
        source: "DirectFeed.qml"
        onStatusChanged: {
            if (direkt.status === Loader.Error) {
                root.lastError = "Direktbezug nicht verfuegbar (QtWebSockets fehlt)";
                root.online = false;
            }
        }
    }

    // The miner on the local network. A separate loader next to `direkt` so an
    // error here does not take the mempool down with it, same reason as above.
    // Only active in direct mode; in daemon mode the service polls it.
    Loader {
        id: bergwerk

        active: root.direkt
        source: "DirectMiner.qml"
        onLoaded: {
            bergwerk.item.hosts = Qt.binding(function () {
                return root.minerHosts || [];
            });
            bergwerk.item.active = Qt.binding(function () {
                return root.active;
            });
        }
    }

    // The market. Separate loader for the same reason as the two above: if it
    // fails, mempool and miner keep running.
    Loader {
        id: markt

        active: root.direkt
        source: "DirectMarket.qml"
        onLoaded: {
            markt.item.active = Qt.binding(function () {
                return root.active;
            });
            markt.item.preise = Qt.binding(function () {
                return root.price;
            });
        }
    }

    Connections {
        target: direkt.item

        function onSnapChanged() {
            root.__apply(direkt.item.snap);
        }

        function onBlockChanged() {
            if (direkt.item.block && direkt.item.block.height)
                root.block = direkt.item.block;
        }
    }

    // The daemon fetches block data in the background after a block is found,
    // so keep retrying until the height matches.
    Timer {
        interval: 3000
        repeat: true
        running: root.active && !root.direkt
        triggeredOnStart: true
        onTriggered: {
            if (root.block.height && root.block.height === root.tipHeight)
                return;
            root.__get("/block", "__blockPending", function (txt) {
                try {
                    var b = JSON.parse(txt);
                    if (b && b.height)
                        root.block = b;
                } catch (e) {}
            });
        }
    }
}
