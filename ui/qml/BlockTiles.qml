// Tile graphic of a block: the same look as in the feed, but for any block
// from the explorer.
//
// Packing and colors come from the same building blocks (`mondrian.js`,
// `colors.js`), so both views really look the same, not just similar.
//
// Two modes:
//
//   `live: false`  a confirmed block. It no longer changes, the packing is
//                  computed once.
//   `live: true`   a projected block. It changes constantly, and it must not
//                  be repacked: between two requests 99.7 % of the tiles
//                  would move and the picture would just flicker. Instead
//                  known tiles stay in place, removed ones free their area and
//                  new ones fill the gaps. The packing stays dense this way
//                  (0.7 % -> 3.0 % free cells, almost all at the top edge);
//                  that is what the exact occupancy map in `mondrian.js` is
//                  for. Whatever the new tiles do not fill is closed by
//                  gravity afterwards (`MondrianLayout.gravity`, as on
//                  mempool.space); without it holes would remain.
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick
import "mondrian.js" as Mondrian
import "colors.js" as Palette
import "txtype.js" as TxType
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    // Prepared tile data from /lookup/blocktiles/<hash> or
    // /lookup/projectedtiles/<rank>
    property var block: null
    property bool live: false
    // fee:  fee rate, teal to violet (the original's colors)
    // type: transaction type from the `flags` bit field (Mempool Goggles)
    property string colorMode: "fee"
    property color dimColor: "#9a94a6"
    property real labelSize: 11
    property string lang: "de"
    // `₿` only where the font has it (see FeedTabs.btcZeichen)
    property string btcZeichen: "\u20BF"

    // Per tile: { sq: {x,y,r}, b: fee class, k: type, d: tooltip data }
    property var squares: []
    property int gridUnits: 0
    property int rowsUsed: 0
    property var cellIdx: ({})
    property bool __idxDirty: true
    property var hovered: null

    // What changed in the last update. The view above prints it, and the new
    // tiles flash white briefly.
    property int addedCount: 0
    property int removedCount: 0
    // Count per transaction type, indexed like TxType.KINDS; feeds the legend.
    property var typeCounts: []
    property var freshIdx: []
    property real flashPhase: 0
    // Bounding box of the new tiles. Without it every fade frame clears and
    // redraws the whole canvas, which costs about 4 % CPU.
    property var flashBox: null

    // Continuously maintained state of live mode.
    property var __lay: null
    property var __byId: ({})

    signal txPicked(string txid)

    readonly property real side: Math.min(width, height)

    // Whole device pixels, not whole logical points. An integer grid step
    // removes the checkerboard pattern (see DOKUMENTATION), but only on screens
    // with a device pixel ratio of 1 or 2. At 2.8125 (450 dpi) a whole logical
    // number is fractional again.
    //
    // Brightness per device pixel across a gap, measured on a phone:
    //
    //     158 11 11 11 11 11 40      five dark pixels
    //     154 11 11 11 11 11 44      five
    //     148 11 11 11 11 49         four
    //
    // Meant to be equal, drawn unequal. Less visible than in the feed because the
    // gaps are wider here, but the same cause. `FeedCanvas` computes in device
    // pixels for the same reason.
    readonly property real dpr: Screen.devicePixelRatio > 0
                                ? Screen.devicePixelRatio : 1

    function schnapp(v) {
        return Math.round(v * root.dpr) / root.dpr;
    }

    function unit(rows) {
        var g = side / Math.max(1, rows);
        return g * root.dpr < 2 ? g : Math.floor(g * root.dpr) / root.dpr;
    }

    function pad(g) {
        if (g * root.dpr < 2)
            return g / 4;
        // The minimum margin is one device pixel, not one logical point. Reasoning
        // and measurement are in `FeedCanvas` at `blockPad`. In short: one logical
        // point is 2.8 device pixels here, and small cells would leave no tile.
        return Math.max(1 / root.dpr, root.schnapp(g / 8));
    }

    onBlockChanged: rebuild()
    onColorModeChanged: repaintAll()
    onWidthChanged: repaintAll()
    onHeightChanged: repaintAll()
    onLiveChanged: {
        // When the mode changes, bookkeeping starts over.
        root.__lay = null;
        root.__byId = ({});
        rebuild();
    }

    function repaintAll() {
        canvas.requestPaint();
        flashCanvas.requestPaint();
    }

    // Extract the per-tile data: an id, the edge length, the fee class and the
    // tooltip line. The id is the txid; live mode depends on it, since only the
    // id tells whether a tile is already known.
    function records(b) {
        var tiles = b.tiles;
        var n = Math.floor(tiles.length / 2);
        var txs = b.txs || [];
        // One digit per tile, same order. Older responses without this field count
        // as "payment".
        var types = b.types || "";
        var out = [];
        for (var i = 0; i < n; i++) {
            var d = txs[i];
            out.push({
                "id": (d && d[0]) ? String(d[0]) : ("#" + i),
                "r": parseInt(tiles.charAt(i * 2), 10) || 1,
                "b": parseInt(tiles.charAt(i * 2 + 1), 10) || 0,
                "k": i < types.length ? (parseInt(types.charAt(i), 10) || 0) : 0,
                "d": d || null
            });
        }
        return out;
    }

    // How often each type occurs. One pass over the tiles per update; the legend
    // is built from it.
    function countTypes() {
        var c = [0, 0, 0, 0, 0, 0, 0, 0];
        for (var i = 0; i < root.squares.length; i++)
            c[root.squares[i].k || 0]++;
        root.typeCounts = c;
    }

    // Color of a tile: the one place where the coloring mode is decided. Both
    // canvases ask here.
    function tileColor(s) {
        if (root.colorMode === "type")
            return TxType.info(TxType.kindAt(s.k)).color;
        return Palette.bucketColor(s.b);
    }

    function gridFor(recs) {
        var w = 0;
        for (var i = 0; i < recs.length; i++)
            w += recs[i].r * recs[i].r;
        return Math.max(4, Math.ceil(Math.sqrt(w)));
    }

    // Rebuild the cell -> tile map. It serves tooltip and click, so it is only
    // built once the mouse is actually over the graphic. On every update that
    // would be seven thousand entries nobody reads.
    function reindex() {
        root.__idxDirty = false;
        var idx = {};
        for (var i = 0; i < root.squares.length; i++) {
            var sq = root.squares[i].sq;
            for (var cx = 0; cx < sq.r; cx++) {
                for (var cy = 0; cy < sq.r; cy++)
                    idx[(sq.x + cx) + ":" + (sq.y + cy)] = i;
            }
        }
        root.cellIdx = idx;
    }

    function clear() {
        root.squares = [];
        root.typeCounts = [];
        root.cellIdx = ({});
        root.__idxDirty = true;
        root.freshIdx = [];
        root.__lay = null;
        root.__byId = ({});
        root.hovered = null;
        repaintAll();
    }

    function rebuild() {
        var b = root.block;
        if (!b || !b.tiles || b.tiles.length < 2) {
            clear();
            return;
        }
        var recs = root.records(b);
        if (!root.live) {
            root.fullBuild(recs);
            return;
        }

        // Is tracking worth it at all? After a block is found the projected block is
        // completely different, and repacking is the right thing.
        var known = 0;
        for (var i = 0; i < recs.length; i++) {
            if (root.__byId[recs[i].id])
                known++;
        }
        var gw = root.gridFor(recs);
        var passt = root.__lay !== null && recs.length > 0
            && known / recs.length > 0.25
            && Math.abs(gw - root.gridUnits) <= root.gridUnits * 0.15;
        if (!passt) {
            root.fullBuild(recs);
            return;
        }
        root.update(recs);
    }

    function fullBuild(recs) {
        var gw = root.gridFor(recs);
        var lay = new Mondrian.MondrianLayout(gw);
        var out = [], byId = {};
        for (var i = 0; i < recs.length; i++) {
            var e = { "sq": lay.place(recs[i].r), "b": recs[i].b,
                      "k": recs[i].k, "d": recs[i].d };
            out.push(e);
            byId[recs[i].id] = e;
        }
        root.squares = out;
        root.countTypes();
        root.gridUnits = gw;
        root.rowsUsed = Math.max(gw, lay.height());
        root.__lay = lay;
        root.__byId = byId;
        root.addedCount = 0;
        root.removedCount = 0;
        root.freshIdx = [];
        root.flashPhase = 0;
        root.__idxDirty = true;
        repaintAll();
    }

    // Close gaps in two stages. After each update apply gravity (as on
    // mempool.space): little movement, cuts the holes to a third. If they still
    // exceed one percent of the area, repack stably: about one tile in ten
    // moves, and the block is dense afterwards. Measurements and reasoning are
    // in `mondrian.js`.
    function lueckenSchliessen(lay, eintraege) {
        lay.gravity(eintraege);
        if (lay.enclosedHoles() <= lay.width * lay.width * 0.01)
            return lay;
        var neu = Mondrian.repackStable(lay.width, eintraege);
        root.__lay = neu;
        return neu;
    }

    // Update instead of repacking: first all removals so their area becomes
    // free, then the additions in the order they were delivered (by fee rate,
    // descending).
    function update(recs) {
        var lay = root.__lay;
        var alt = root.__byId, neu = {}, i, e;
        var vorhanden = {};
        for (i = 0; i < recs.length; i++)
            vorhanden[recs[i].id] = recs[i];

        var raus = 0;
        for (var id in alt) {
            if (!vorhanden[id]) {
                lay.remove(alt[id].sq);
                raus++;
            }
        }

        var out = [], fresh = [], dazu = 0;
        for (i = 0; i < recs.length; i++) {
            var r = recs[i];
            e = alt[r.id];
            if (e) {
                // Known: keep the position but update fee class and data, since a
                // transaction's rate can change.
                e.b = r.b;
                e.k = r.k;
                e.d = r.d;
            } else {
                e = { "sq": lay.place(r.r), "b": r.b, "k": r.k, "d": r.d };
                fresh.push(out.length);
                dazu++;
            }
            neu[r.id] = e;
            out.push(e);
        }
        lay = root.lueckenSchliessen(lay, out);

        root.squares = out;
        root.__byId = neu;
        root.countTypes();
        root.rowsUsed = Math.max(root.gridUnits, lay.height());
        root.addedCount = dazu;
        root.removedCount = raus;
        root.freshIdx = fresh;
        root.__idxDirty = true;
        canvas.requestPaint();

        root.computeFlashBox();
        // Only flash when someone is looking.
        if (fresh.length > 0 && root.visible) {
            root.flashPhase = 1;
            flashTimer.restart();
        } else {
            root.flashPhase = 0;
        }
        root.markFlash();
    }

    // Apply only the delta. The daemon keeps a change log and on request sends
    // only what was added and removed since the last version: 5 to 90 kB instead
    // of 634 kB per request. Without it, parsing the JSON alone cost 6 % CPU.
    function applyDelta(d) {
        if (!root.live || root.__lay === null || !root.squares.length) {
            return false;
        }
        var lay = root.__lay, byId = root.__byId, i;

        var raus = 0, rem = d.removed || [];
        for (i = 0; i < rem.length; i++) {
            var alt = byId[rem[i]];
            if (alt) {
                lay.remove(alt.sq);
                delete byId[rem[i]];
                raus++;
            }
        }

        var recs = (d.tiles && d.tiles.length >= 2) ? root.records(d) : [];
        var frisch = {}, dazu = 0;
        for (i = 0; i < recs.length; i++) {
            var r = recs[i];
            var e = byId[r.id];
            if (e) {
                // Already present: only fee class and type are updated, the position stays.
                // That is the whole point.
                e.b = r.b;
                e.k = r.k;
                e.d = r.d;
            } else {
                byId[r.id] = { "sq": lay.place(r.r), "b": r.b, "k": r.k, "d": r.d };
                frisch[r.id] = true;
                dazu++;
            }
        }

        // Rebuild the tile list. Order does not matter for the picture, every tile
        // carries its own position.
        var out = [], fresh = [];
        for (var id in byId) {
            if (frisch[id])
                fresh.push(out.length);
            out.push(byId[id]);
        }
        // Only now, with removals and additions applied: gaps that no new tile
        // filled are closed from behind.
        lay = root.lueckenSchliessen(lay, out);

        root.squares = out;
        root.__byId = byId;
        root.countTypes();
        root.rowsUsed = Math.max(root.gridUnits, lay.height());
        root.addedCount = dazu;
        root.removedCount = raus;
        root.freshIdx = fresh;
        root.__idxDirty = true;
        canvas.requestPaint();

        root.computeFlashBox();
        if (fresh.length > 0 && root.visible) {
            root.flashPhase = 1;
            flashTimer.restart();
        } else {
            root.flashPhase = 0;
        }
        root.markFlash();
        return true;
    }

    // The fade runs on a timer, not a NumberAnimation. An animation ticks at the
    // display refresh rate and every frame costs here (5 % CPU just for a
    // pulsing six-pixel dot). Five steps over 750 ms look like a smooth fade and
    // cost a twelfth of that.
    Timer {
        id: flashTimer

        interval: 150
        repeat: true
        running: false
        onTriggered: {
            root.flashPhase -= 0.2;
            if (root.flashPhase <= 0.01 || !root.visible) {
                root.flashPhase = 0;
                stop();
            }
            root.markFlash();
        }
    }

    // Only repaint the bounding box of the new tiles.
    function markFlash() {
        if (root.flashBox)
            flashCanvas.markDirty(Qt.rect(root.flashBox.x, root.flashBox.y,
                                          root.flashBox.w, root.flashBox.h));
        else
            flashCanvas.requestPaint();
    }

    // Bounding box of all new tiles in canvas coordinates.
    function computeFlashBox() {
        if (!root.freshIdx.length) {
            root.flashBox = null;
            return;
        }
        var g = root.gridStep, p = root.pad(g);
        var bx = root.originX, by = root.originY;
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (var i = 0; i < root.freshIdx.length; i++) {
            var s = root.squares[root.freshIdx[i]];
            if (!s)
                continue;
            var t = root.rectFor(s.sq, g, bx, by, p);
            if (t.x < x0) x0 = t.x;
            if (t.y < y0) y0 = t.y;
            if (t.x + t.w > x1) x1 = t.x + t.w;
            if (t.y + t.h > y1) y1 = t.y + t.h;
        }
        root.flashBox = x1 < x0 ? null
            : { "x": Math.floor(x0) - 1, "y": Math.floor(y0) - 1,
                "w": Math.ceil(x1 - x0) + 2, "h": Math.ceil(y1 - y0) + 2 };
    }

    function rectFor(q, g, bx, by, p) {
        if (g * root.dpr < 2) {
            var sd = Math.max(0.35, q.r * g - p * 2);
            return { "x": bx + q.x * g + p, "y": by + q.y * g + p, "w": sd, "h": sd };
        }
        var x0 = root.schnapp(bx + q.x * g), x1 = root.schnapp(bx + (q.x + q.r) * g);
        var y0 = root.schnapp(by + q.y * g), y1 = root.schnapp(by + (q.y + q.r) * g);
        return { "x": x0 + p, "y": y0 + p,
                 "w": Math.max(1 / root.dpr, x1 - x0 - p * 2),
                 "h": Math.max(1 / root.dpr, y1 - y0 - p * 2) };
    }

    readonly property real gridStep: unit(rowsUsed)
    readonly property real originX: root.schnapp((side - gridUnits * gridStep) / 2)
    readonly property real originY: root.schnapp((side - rowsUsed * gridStep) / 2)

    Canvas {
        id: canvas

        anchors.centerIn: parent
        width: root.side
        height: root.side
        antialiasing: root.rowsUsed > 0 && root.gridStep < 2

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.squares.length)
                return;
            var g = root.gridStep;
            var p = root.pad(g);
            var bx = root.originX;
            var by = root.originY;

            // Group by color, which saves thousands of state changes.
            var groups = {}, i, s, c;
            for (i = 0; i < root.squares.length; i++) {
                s = root.squares[i];
                c = root.tileColor(s);
                if (!groups[c])
                    groups[c] = [];
                groups[c].push(s);
            }
            for (var col in groups) {
                ctx.fillStyle = col;
                var list = groups[col];
                for (i = 0; i < list.length; i++) {
                    var t = root.rectFor(list[i].sq, g, bx, by, p);
                    ctx.fillRect(t.x, t.y, t.w, t.h);
                }
            }

            // Highlight the tile under the pointer.
            if (root.hovered !== null && root.squares[root.hovered]) {
                var h = root.rectFor(root.squares[root.hovered].sq, g, bx, by, p);
                ctx.fillStyle = Palette.hoverColor();
                ctx.fillRect(h.x, h.y, h.w, h.h);
            }
        }
    }

    // New tiles live on their own canvas, the same split as in the feed (pile
    // below, falling tiles above). That way the flash costs a few rectangles
    // instead of the whole block.
    Canvas {
        id: flashCanvas

        anchors.fill: canvas
        antialiasing: canvas.antialiasing
        visible: root.flashPhase > 0

        onPaint: {
            var ctx = getContext("2d");
            var box = root.flashBox;
            if (box)
                ctx.clearRect(box.x, box.y, box.w, box.h);
            else
                ctx.reset();
            if (root.flashPhase <= 0 || !root.freshIdx.length)
                return;
            var g = root.gridStep;
            var p = root.pad(g);
            var bx = root.originX;
            var by = root.originY;
            var weiss = Palette.iceWhite();
            for (var i = 0; i < root.freshIdx.length; i++) {
                var s = root.squares[root.freshIdx[i]];
                if (!s)
                    continue;
                var t = root.rectFor(s.sq, g, bx, by, p);
                ctx.fillStyle = Palette.blendHex(root.tileColor(s), weiss, root.flashPhase);
                ctx.fillRect(t.x, t.y, t.w, t.h);
            }
        }
    }

    function at(px, py) {
        if (!root.squares.length)
            return null;
        if (root.__idxDirty)
            root.reindex();
        var g = root.gridStep;
        var cx = Math.floor((px - root.originX) / g), cy = Math.floor((py - root.originY) / g);
        var i = root.cellIdx[cx + ":" + cy];
        return i === undefined ? null : i;
    }

    MouseArea {
        anchors.fill: canvas
        hoverEnabled: true

        onPositionChanged: mouse => {
            var i = root.at(mouse.x, mouse.y);
            if (i !== root.hovered) {
                root.hovered = i;
                canvas.requestPaint();
            }
        }
        onExited: {
            root.hovered = null;
            canvas.requestPaint();
        }
        onClicked: {
            var d = root.hovered !== null && root.squares[root.hovered]
                ? root.squares[root.hovered].d : null;
            if (d && d[0])
                root.txPicked(String(d[0]));
        }
    }

    // Details of the tile under the pointer.
    Rectangle {
        visible: root.hovered !== null && tipCol.height > 0
        width: tipCol.width + root.labelSize * 1.6
        height: tipCol.height + root.labelSize * 1.2
        radius: root.labelSize * 0.4
        color: Qt.rgba(0.05, 0.05, 0.08, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        x: Math.max(0, Math.min(root.width - width, root.width / 2 - width / 2))
        y: root.height - height - root.labelSize * 0.4
        z: 20

        Column {
            id: tipCol

            anchors.centerIn: parent
            spacing: 1

            readonly property var d: (root.hovered !== null && root.squares[root.hovered])
                ? root.squares[root.hovered].d : null

            Text {
                visible: tipCol.d !== null && tipCol.d !== undefined
                text: tipCol.d ? String(tipCol.d[0]).substring(0, 20) + "…" : ""
                color: "#f2eef8"
                font.pixelSize: root.labelSize
                font.family: Fonts.mono()
            }

            Text {
                visible: tipCol.d !== null && tipCol.d !== undefined
                text: tipCol.d
                    ? Tr.ersetzen(Tr.t("tile.tooltip", root.lang, tipCol.d[1], tipCol.d[4],
                                       Tr.fixed((tipCol.d[3] / 1e8), 8, root.lang)),
                                  root.btcZeichen, "")
                    : ""
                color: root.dimColor
                font.pixelSize: root.labelSize * 0.92
            }
        }
    }
}
