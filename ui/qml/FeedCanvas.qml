// Bitfeed view: the found block in the middle, the mempool as a pile at the
// bottom, new transactions fall in from the top.
//
// Packing, sizes and colors follow the original (bitfeed, MIT, mononaut):
//   side length = ceil(log10(output value in sat)) - 5, clamped to 1..5
//   layout      = Mondrian slot layout, see mondrian.js
//   color       = by age (orange -> blue in 60 s) or by fee rate
//   gap         = fixed pixel value, so it is the same size everywhere
import QtQuick
import "mondrian.js" as Mondrian
import "colors.js" as Palette
import "txtype.js" as TxType
import "strings.js" as Tr

Item {
    id: root

    // Falling tiles start above the area (`fromY` is negative). Without
    // clipping QML keeps drawing them outside. In a window of its own the window
    // clips, but in the dashboard popup they would rain over the whole screen.
    clip: true

    property var feed: null
    property bool paused: false
    // Outline color for transactions of a watched wallet
    property color ownColor: "#ffffff"
    property bool showBlock: true
    property real density: 1.0
    property string colorMode: "age"        // "age" | "fee"
    property string sizeMode: "value"       // "value" | "vbytes"
    property int fullMempool: 120000        // a full pile corresponds to this many TX
    property color gridColor: "#2a2a38"
    property color rulerColor: "#7d8a8a"
    property int labelFont: 11
    property bool showRuler: true
    property string lang: "de"

    // --- Grid and layout, formulas from bitfeed --------------------------
    // TxPoolScene.resize: heightLimit = height/4 (height/4.5 in narrow windows).
    // In bitfeed that is a cap for the pile. Used as the only rule, the pile
    // would always get exactly a quarter, no matter whether the block above has
    // a quarter or three times its own size available.
    //
    // In portrait that falls apart: at 440x950 the pile would get 189 pixels and
    // the block 661, of which it needs 317. The block floats in empty space and
    // the live part of the picture is squeezed.
    //
    // So it is computed the other way round: the band at the top is as tall as
    // the block needs, and the rest belongs to the pile, but only up to a third
    // of the height. Without that upper limit the pile takes over a large window
    // (1900x1500 would give it 802 instead of 500 pixels).
    //
    // bitfeed's fraction is the lower limit (the pile keeps its rows in a flat
    // bar), a third of the height the upper limit. In between, what the block
    // leaves over decides.
    //
    //     1900x1500   500 px pile
    //      440x900    300 px pile
    readonly property real blockWish: Math.min(width * 0.72, height / 2.5)
    // 0.86 is the same factor `blockSide` below uses to compute back from
    // `poolTop`. Applied forward here so both mean the same thing.
    readonly property real blockBand: showBlock ? blockWish / 0.86 : 0
    readonly property real poolLimit: height / (width <= 620 ? 4.5 : 4)
    readonly property real poolH: showBlock
        ? Math.max(poolLimit, Math.min(height - blockBand, height / 3))
        : height
    readonly property real poolTop: Math.max(0, height - poolH)
    // In the original the tile size follows the window width (max(4,
    // width/250)), so tiles grow when the window is enlarged. Here it is fixed:
    // 4 px tile, 1 px gap, which is what bitfeed shows at about a thousand
    // pixels width. A wider window fits more columns, the tiles stay the same.
    // The "tile size" setting makes them larger or smaller.
    //
    // Whole device pixels, not whole logical points. Integer logical sizes only
    // avoid the checkerboard pattern at a device pixel ratio of 1 or 2. At
    // 2.8125 (450 dpi phones) a whole logical number is fractional again: a
    // 1 point gap becomes 2.8125 device pixels. Exactly one device pixel of the
    // gap is then dark and the rest is spread as partial coverage over the
    // neighbors, differently for every gap. Gaps look alternately thin and thick
    // and the edges soft: the same checkerboard, one coordinate level lower.
    //
    // So everything is computed in device pixels and divided back at the end.
    readonly property real dpr: Screen.devicePixelRatio > 0
                                ? Screen.devicePixelRatio : 1

    function schnapp(v) {
        return Math.round(v * root.dpr) / root.dpr;
    }

    function schnappAb(v) {
        return Math.floor(v * root.dpr) / root.dpr;
    }

    readonly property int fugeDev: Math.max(1, Math.round(
        Math.min(3, Math.max(1, density)) * dpr))
    readonly property int seiteDev: Math.max(2, Math.round(
        Math.min(10, Math.max(2, 4 * density)) * dpr))
    readonly property int zelleDev: seiteDev + fugeDev * 2
    readonly property real unitWidth: seiteDev / dpr
    readonly property real unitPad: fugeDev / dpr
    readonly property real gridSize: zelleDev / dpr
    readonly property int gridW: Math.max(8, Math.floor(width / gridSize) - 1)
    readonly property int gridRows: Math.max(3, Math.floor(poolH / gridSize))
    readonly property real gridLeft: root.schnapp((width - gridW * gridSize) / 2)
    // TxController.resize: blockAreaSize = min(width*0.75, height/2.5)
    readonly property real blockSide: Math.min(width * 0.72, height / 2.5, poolTop * 0.86)
    readonly property real blockCenterY: poolTop * 0.5
    // Top edge of the pile, where the dashed line sits as in the original
    // (mempoolScreenHeight). It moves with the fill level.
    readonly property real pileTopY: height - pileRows * gridSize + scrollPx

    // --- State -----------------------------------------------------------
    property var layout: null
    property var poolTx: []                 // {sq, t0, rate, fly, fromY}
    // Separate list of the tiles still falling. Otherwise the whole pile would
    // have to be scanned thirty times a second to find those few.
    property var flying: []
    property real scrollPx: 0           // smooth settling after clearing a row
    property var cellIndex: ({})            // grid cell -> tile, for the tooltip
    property var hoveredTx: null
    property var hoverRect: null            // outline of the tile under the pointer
    property real hoverX: 0
    property real hoverY: 0
    property real blockPulse: 0
    // On touch the info stays until the user taps somewhere else. This is the
    // id of the transaction whose info is currently pinned; a second tap on the
    // same tile opens it in the explorer. See the PointHandler below.
    property string pinnedTxid: ""
    readonly property bool touchUi: Qt.platform.os === "android" || Qt.platform.os === "ios"

    // A tile was tapped. The host decides what to do with it (in the window:
    // open it in the explorer).
    signal txActivated(string txid)

    // --- View: zoom and pan ----------------------------------------------
    // Tiles are 4 px, so without magnification a single transaction is hard to
    // hit. Zoom is purely a view matter: grid and packing stay unchanged, only
    // the drawing is translated and scaled. That is why it lives in
    // ctx.setTransform in the canvases and as a transform on the rectangle
    // layers. Both then redraw sharply instead of scaling a finished image.
    property real zoom: 1
    property real viewX: 0
    property real viewY: 0
    readonly property real minZoom: 1
    readonly property real maxZoom: 24
    readonly property bool zoomed: zoom > 1.0001
    // Was the last frame zoomed? When zooming out, the whole canvas has to be
    // cleared once.
    property bool __warZoom: false
    // Geometry of the last frame. Used by `clearTop` in `onPaint`.
    property real __letzteBreite: -1
    property real __letzteHoehe: -1
    property real __letzteLinie: -1
    // Count per transaction type in the displayed block, indexed like TxType.KINDS
    property var blockTypeCounts: []

    // The color mode determines every color in the picture, so both canvases
    // must repaint. Otherwise the block keeps its old color until the next one
    // is found.
    onColorModeChanged: {
        poolCanvas.requestPaint();
        blockCanvas.requestPaint();
        flyLayer.refresh();
    }

    // Color of a block tile. Three modes:
    //
    //   age   the block is complete and all tiles have the same age, so one
    //         color for the whole block, as in the original
    //   fee   by fee rate
    //   type  by inferred transaction type (mempool goggles)
    function blockTileColor(s) {
        if (root.colorMode === "type")
            return TxType.info(TxType.kindAt(s.k || 0)).color;
        if (root.colorMode === "fee")
            return Palette.bucketColor(s.b);
        return Palette.blockAgeColor();
    }

    function viewApply(ctx) {
        ctx.setTransform(zoom, 0, 0, zoom, viewX, viewY);
    }

    // Shift a scene value so that after scaling it lands on a whole screen
    // pixel.
    //
    // Rounding has to happen in screen space. Rounding in scene coordinates
    // only matches at scale 1: the pile would draw at `round(y)` while the
    // animation layer uses the unrounded value, and `y` is fractional because
    // of the settling `scrollPx`. A tile that just landed would jump by up to
    // half a grid step when moving from one layer to the other, and the gap
    // next to it would be visibly uneven. Both layers use this function.
    //
    // It rounds to whole device pixels, not whole logical points. At a ratio of
    // 2.8125 a logical point sits in the middle of a device pixel, and rounding
    // to it would undo the grid that `zelleDev` and `fugeDev` laid out: gaps
    // meant to be six device pixels wide came out as 4 to 7, and tiles one
    // pixel wider than computed ate into the gap.
    //
    // `zoom` is part of it: rounding happens in screen space and is converted
    // back to scene coordinates, so the result also sits on whole pixels when
    // zoomed.
    function snap(v) {
        var s = zoom * root.dpr;
        return Math.round(v * s) / s;
    }

    function toSceneX(px) {
        return (px - viewX) / zoom;
    }

    function toSceneY(py) {
        return (py - viewY) / zoom;
    }

    // Never past the edge: at zoom 1 the view sits exactly on the picture again.
    function clampView() {
        if (zoom <= minZoom + 0.0001) {
            zoom = minZoom;
            viewX = 0;
            viewY = 0;
            return;
        }
        viewX = Math.round(Math.min(0, Math.max(width - width * zoom, viewX)));
        viewY = Math.round(Math.min(0, Math.max(height - height * zoom, viewY)));
    }

    // Zoom around a fixed point: whatever is under the pointer stays under the
    // pointer. The scale is an integer and the offset sits on whole pixels.
    // The pile is a pixel grid of 4 px tiles. A fractional scale makes every
    // edge fractional, and since drawing is done without antialiasing each edge
    // snaps on its own: squares turn into rectangles and a checkerboard pattern
    // appears. With integers every tile stays exactly square and every gap the
    // same width, at any magnification.
    function setZoomAt(px, py, z) {
        var z1 = Math.max(minZoom, Math.min(maxZoom, Math.round(z)));
        if (z1 === zoom)
            return;
        var sx = toSceneX(px);
        var sy = toSceneY(py);
        zoom = z1;
        viewX = Math.round(px - sx * z1);
        viewY = Math.round(py - sy * z1);
        clampView();
        repaintView();
    }

    // One wheel step = one level. A factor would be pointless here, since the
    // result is rounded to integers anyway.
    function zoomStep(px, py, dir) {
        setZoomAt(px, py, zoom + dir);
    }

    function panBy(dx, dy) {
        if (!zoomed)
            return;
        viewX = Math.round(viewX + dx);
        viewY = Math.round(viewY + dy);
        clampView();
        repaintView();
    }

    function resetView() {
        zoom = minZoom;
        viewX = 0;
        viewY = 0;
        repaintView();
    }

    function repaintView() {
        poolCanvas.requestPaint();
        blockCanvas.requestPaint();
        if (blockPhase !== "idle")
            blockAnim.requestPaint();
        flyLayer.refresh();
    }

    onWidthChanged: clampView()
    onHeightChanged: clampView()
    property var mining: []             // tiles on their way into the block
    property string blockPhase: "idle"  // idle | ice | fly
    // Timer for the block animation. Named to avoid BLOCKCLOCK, a registered
    // trademark of Coinkite; the name should not appear anywhere in the project,
    // not even where nobody sees it.
    property real blockTakt: 0
    property bool blockRevealed: true
    property real blockFade: 0
    property real levelClock: 0
    property int placed: 0
    property bool poolDirty: false
    property int pileRows: 0
    property int occupied: 0            // occupied grid units, sum of r*r
    property var queue: []              // pending arrivals
    property real queueAcc: 0
    // Upper limit of the queue. Reasoning at `onTransactionsArrived`.
    property int queueMax: 240

    signal blockLayoutChanged

    // Gap between the block tiles, a quarter of the grid step as in the
    // original, but rounded to whole pixels. Together with the rounded edges
    // (see blockRect) the gaps are exactly the same width everywhere. On
    // fractional pixel values a gap sometimes gets one pixel more and sometimes
    // one less, which creates a checkerboard pattern.
    // Padding around each block tile; the gap between two neighbors is twice as
    // wide. The original computes `unitPadding = gridSize / 4`, so there the tile
    // is exactly half as wide as the grid cell. With small grid steps the block
    // then looks very sparse: at g = 7 that is a 3 px tile on a 4 px gap, while
    // the pile next to it shows a 4 px tile on a 2 px gap.
    //
    // So the divisor here is larger. 8 gives a 1 px padding at g = 7, so a 5 px
    // tile on a 2 px gap: the same density as the pile, and the block reads as
    // a solid area instead of a dot grid. A deliberate departure from the
    // original, adjustable via blockPadDivisor.
    property int blockPadDivisor: 8

    // From which cell size tile and gap fit into whole numbers.
    //
    // The gap is at least one device pixel (see `blockPad` for why). With an
    // eight pixel cell that is an eighth, with three pixels it is two thirds:
    // the tile is then narrower than the gap and the block turns into a dot
    // grid. Computed for a width of 105 grid cells at dpr 1:
    //
    //     block side  cell   gap   tile
    //       250 px    2 px   1 px  1 px    dot grid
    //       300 px    2 px   1 px  1 px    dot grid
    //       350 px    3 px   1 px  1 px    gap wider than the tile
    //       420 px    4 px   1 px  2 px    fine
    //       840 px    8 px   1 px  6 px    what a large window shows
    //
    // Below four device pixels there is no integer split that works for both.
    // There the values stay fractional and are antialiased: soft instead of
    // hard. A soft, even texture is more honest than a hard grid that suggests
    // a structure that is not there.
    //
    // The threshold lives only here, in device pixels. `grobRaster()` is the
    // one place that checks it.
    readonly property int zelleGanzAb: 4

    function grobRaster(g) {
        return g * root.dpr < root.zelleGanzAb;
    }

    function blockPad(g) {
        // Below `zelleGanzAb` device pixels per cell there are no whole numbers
        // that give both tile and gap, so use the original's ratio (g/4) as a
        // fraction, together with antialiasing.
        if (root.grobRaster(g))
            return g / 4;
        // The minimum padding is one device pixel, not one logical point. On a
        // 450 dpi screen a logical point is 2.8 device pixels, and with a six
        // device pixel cell that leaves no tile at all: tiles one or two pixels
        // wide, narrower than the gaps between them (5 to 6 px). That is the
        // opposite of what `blockPadDivisor` intends (tile 5 on gap 2, a solid
        // area instead of a dot grid).
        return Math.max(1 / root.dpr, root.schnapp(
            g / Math.max(1, blockPadDivisor)));
    }

    // Grid step of the block, in whole device pixels. blockRect rounds both
    // edges separately; with a fractional step `x1 - x0` would come out as
    // floor(g*r) or ceil(g*r) depending on the fraction, turning a square into
    // e.g. a 3x4 rectangle, which is what causes the checkerboard pattern.
    // The block ends up to `rowsUsed` pixels smaller than the available space.
    // That is invisible, and in exchange every tile is exactly square and every
    // gap the same width.
    function blockUnit(rows) {
        var g = blockSide / Math.max(1, rows);
        // Integer only from `zelleGanzAb` device pixels per cell up. Below that
        // floor(g) would be very small or 1: the tile fills the whole cell, the gap
        // is zero and the block becomes a solid area. That happens in the dashboard
        // tab, where the block is small (at 105 grid cells width floor(g) = 1 lasts
        // up to about 210 px block side). With a fractional step the rounded edges
        // alternate between 1 and 2 px and give a texture again.
        //
        // There is no checkerboard risk there: at that size all tiles are 1 px
        // anyway.
        //
        // Integer in device pixels, not logical points. The reason is at `dpr`
        // above.
        return root.grobRaster(g) ? g : root.schnappAb(g);
    }

    function txSize(valueSats, vbytes) {
        if (sizeMode === "vbytes")
            return Math.min(5, Math.max(1, Math.ceil(Math.sqrt((vbytes || 1) / 256))));
        return Mondrian.txSize(valueSats, 5);
    }

    function resetPool() {
        queue = [];
        queueAcc = 0;
        layout = new Mondrian.MondrianLayout(gridW);
        poolTx = [];
        flying = [];
        scrollPx = 0;
        cellIndex = ({});
        hoveredTx = null;
        placed = 0;
        occupied = 0;
    }

    function addTx(value, rate, vsize, ageMs, tx) {
        return addSized(txSize(value, vsize), rate, ageMs, tx);
    }

    function addSized(size, rate, ageMs, tx) {
        if (!layout)
            return null;
        var sq = layout.place(size);
        var side = sq.r * gridSize - unitPad * 2;
        var entry = {
            "sq": sq,
            "t0": Date.now() - (ageMs || 0),
            "rate": rate,
            "fly": ageMs ? 1 : 0,
            "fromY": -side - Math.random() * height * 0.5,
            "vy": 0,
            "tx": tx || null
        };
        poolTx.push(entry);
        if (entry.fly < 1)
            flying.push(entry);
        occupied += sq.r * sq.r;
        placed++;
        for (var cx = 0; cx < sq.r; cx++) {
            for (var cy = 0; cy < sq.r; cy++)
                cellIndex[(sq.x + cx) + ":" + (sq.y + cy)] = entry;
        }
        return entry;
    }

    function removeTx(entry) {
        var i = poolTx.indexOf(entry);
        if (i < 0)
            return;
        poolTx.splice(i, 1);
        var fi = flying.indexOf(entry);
        if (fi >= 0)
            flying.splice(fi, 1);
        occupied -= entry.sq.r * entry.sq.r;
        for (var cx = 0; cx < entry.sq.r; cx++) {
            for (var cy = 0; cy < entry.sq.r; cy++)
                delete cellIndex[(entry.sq.x + cx) + ":" + (entry.sq.y + cy)];
        }
        if (hoveredTx && hoveredTx === entry.tx)
            hoveredTx = null;
        layout.remove(entry.sq);
    }

    function targetX(sq) {
        return gridLeft + sq.x * gridSize + unitPad;
    }

    // Between two tiles there is a gap of a few pixels. When the pointer is on
    // it, the last info should stay instead of flickering; when it moves away,
    // the info has to disappear.
    //
    // Clearing only on leaving the whole area (`onExited`) is not enough: the
    // dashboard has large empty regions inside the area where nothing is ever
    // left, and the tooltip would stay forever. So the measure is the distance
    // to the last tile hit, with one grid cell of tolerance.
    // What lies under a point of the area: {tx, rect} or null, in the pile or in
    // the block field above it. Mouse and touch ask the same function.
    function hitAt(px, py) {
        var sx = toSceneX(px);
        var sy = toSceneY(py);
        var e = txAt(sx, sy);
        if (e && e.tx) {
            var sd = Math.max(1, e.sq.r * gridSize - unitPad * 2);
            return {
                "tx": e.tx,
                "rect": {
                    "x": targetX(e.sq),
                    "y": targetY(e.sq),
                    "w": sd,
                    "h": sd
                }
            };
        }
        if (sy < pileTopY) {
            var bt = blockCanvas.blockTxAt(sx, sy);
            if (bt)
                return { "tx": bt, "rect": blockCanvas.hoverRectAt(sx, sy) };
        }
        return null;
    }

    // A touch tap: pin, open or dismiss. Called by the PointHandler, which
    // detects the tap itself (see there).
    function fingerTap(px, py) {
        var h = hitAt(px, py);
        var t = h && h.tx && h.tx.t ? String(h.tx.t) : "";
        var vorher = pinnedTxid;
        if (t !== "" && t === vorher) {
            hoveredTx = null;
            hoverRect = null;
            pinnedTxid = "";
            txActivated(t);
        } else if (h) {
            hoverX = px;
            hoverY = py;
            hoveredTx = h.tx;
            hoverRect = h.rect;
            pinnedTxid = t;
        } else {
            hoveredTx = null;
            hoverRect = null;
            pinnedTxid = "";
        }
    }

    function clearHoverIfAway(sx, sy) {
        var r = hoverRect;
        if (!r)
            return;
        var tol = Math.max(4, gridSize);
        var rh = (r.h !== undefined) ? r.h : r.w;
        if (sx < r.x - tol || sx > r.x + r.w + tol
                || sy < r.y - tol || sy > r.y + rh + tol) {
            hoveredTx = null;
            hoverRect = null;
        }
    }

    // The pixel position moves with the conveyor belt: rowOffset counts the rows
    // that have already dropped out at the bottom, scrollPx lets the pile settle
    // smoothly afterwards instead of jumping.
    function targetY(sq) {
        return height - (sq.y - layout.rowOffset + sq.r) * gridSize + unitPad + scrollPx;
    }

    // The pile works like a conveyor belt, as in the original: new transactions
    // land at the top, the oldest row drops out of the picture at the bottom.
    // That leaves no holes in the interior; over 40 000 tiles the density stays
    // at 100 %. Removing from the middle of the pile would riddle it with holes
    // (down to 17 %).
    // Returns false if it cannot clear right now.
    function shedBottomRow() {
        var base = layout.rowOffset;
        var i;

        // Do not clear while something in the bottom row is still flying.
        // `mondrian.js` puts new tiles into the lowest free row. If this loop took
        // the row away while a tile was still in the air, `sq.y < rowOffset`,
        // `targetY` would be below the bottom edge, and the tile would fly there,
        // accelerating out of the picture as if it were leaving the mempool.
        //
        // Waiting one tick costs nothing: the flight takes under a second, and the
        // pile may stand one row too high for that long.
        for (i = 0; i < poolTx.length; i++) {
            if (poolTx[i].sq.y === base && poolTx[i].fly < 1)
                return false;
        }

        // Nothing is removed here. Removing a tile as soon as its bottom row is
        // cleared depends on the row, which is the wrong measure: a tile with
        // `r = 1` would vanish in the same frame in which it is still fully visible.
        //
        // Whether something may go depends on whether any of it is still visible.
        // `raeumeUnsichtbare()` below checks that frame by frame, the same way for
        // every size.
        layout.dropBottomRow();
        scrollPx = -gridSize;       // the pile visibly settles
        return true;
    }

    // The pile is not filled artificially. Every tile in it is a real
    // transaction that fell in from the top. The cost: after startup it takes
    // about a quarter of an hour until the pile is full, because the public API
    // only delivers newly arriving transactions (about five per second), not the
    // mempool's current contents. Placeholders would appear without falling and
    // have no data for the tooltip.
    // Gone only once it is no longer visible.
    //
    // `targetY` gives the tile's top edge. If that is at or below the bottom
    // edge, no pixel of it is in the picture anymore; before that the pile
    // canvas cuts it off and it visibly runs out. This works the same for a 1x1
    // as for a 5x5; nothing depends on the row number.
    function raeumeUnsichtbare() {
        var weg = null;
        for (var i = 0; i < poolTx.length; i++) {
            // Anything still flying is not cleared: it is in the air, not at its place,
            // and would otherwise vanish in the middle of the picture.
            if (poolTx[i].fly >= 1 && targetY(poolTx[i].sq) >= height) {
                if (!weg)
                    weg = [];
                weg.push(poolTx[i]);
            }
        }
        if (!weg)
            return;
        // Through `removeTx`, so `flying`, `cellIndex`, `hoveredTx`, `occupied` and
        // the layout are all updated together.
        for (var j = 0; j < weg.length; j++)
            removeTx(weg[j]);
    }

    function maintainPool(dt) {
        levelClock += dt;
        if (levelClock < 0.15 || !layout || gridW < 2)
            return false;
        levelClock = 0;

        raeumeUnsichtbare();

        // What grows past the top edge drops out at the bottom
        var changed = false;
        var rounds = 0;
        while (layout.height() > gridRows && rounds++ < 3) {
            if (!shedBottomRow())
                break;              // a tile is still in the air
            changed = true;
        }
        return changed;
    }


    // Which tile is under the mouse pointer? Looked up through the grid cell so
    // it does not have to scan thousands of tiles.
    // px/py are already scene coordinates (see toSceneX/toSceneY).
    function txAt(px, py) {
        if (!layout || gridSize < 1)
            return null;
        if (py < pileTopY - gridSize)
            return null;
        var gx = Math.floor((px - gridLeft) / gridSize);
        var gy = layout.rowOffset + Math.floor((height + scrollPx - py) / gridSize);
        var e = cellIndex[gx + ":" + gy];
        return (e && e.fly >= 1) ? e : null;
    }

    // Block found, as in bitfeed (TxController.addBlock + TxBlockScene.prepareTx):
    //
    // 1. The mined transactions disappear from the pile and light up white
    //    (ice(): the same color with lightness 1 -> #ffffff).
    // 2. They pulse briefly, staggered in time. The block field stays empty.
    // 3. After three seconds all transactions of the block fly to their place.
    //    Those no longer in the picture (the mempool is larger than the visible
    //    pile) rise from below the bottom edge; in the original that is
    //    `prepareTxOnScreen` for transactions not drawn yet.
    // 4. The block is assembled in white and only then fades to orange.
    function startBlockAnimation() {
        blockRevealed = false;
        blockPhase = "ice";
        blockTakt = 0;
        blockPulse = 1;
        mining = [];

        // A block holds roughly five percent of the mempool, and about that many
        // tiles light up. The rest of the block rises from below the bottom edge
        // later.
        var take = Math.min(Math.round(poolTx.length * 0.12), 700);
        for (var i = 0; i < take && poolTx.length > 0; i++) {
            var e = poolTx[Math.floor(Math.random() * poolTx.length)];
            if (!e)
                continue;
            var side = Math.max(1, e.sq.r * gridSize - unitPad * 2);
            mining.push({
                "x0": targetX(e.sq),
                "y0": targetY(e.sq),
                "x": targetX(e.sq),
                "y": targetY(e.sq),
                "s0": side,
                "s": side,
                "ts": side,
                "tx": 0,
                "ty": 0,
                "white": 0,
                "delay": 0.2 + Math.random() * 1.5,
                "flyDelay": Math.random() * 0.9,
                "fromBelow": false
            });
            removeTx(e);
        }
    }

    function assignBlockTargets() {
        var list = blockCanvas.squares;
        if (!list || list.length === 0)
            return false;

        // How many tiles the block has. Very large blocks are thinned out so the
        // animation stays smooth.
        var maxTiles = 6000;
        var step = Math.max(1, Math.ceil(list.length / maxTiles));
        var targets = [];
        for (var i = 0; i < list.length; i += step)
            targets.push(blockCanvas.rectFor(list[i].sq));

        // existing tiles from the pile first
        var n = Math.min(mining.length, targets.length);
        for (var k = 0; k < n; k++) {
            var m = mining[k];
            var t = targets[k];
            m.tx = t.x;
            m.ty = t.y;
            m.ts = t.s;
            m.x0 = m.x;
            m.y0 = m.y;
            m.s0 = m.s;
        }
        if (mining.length > targets.length)
            mining = mining.slice(0, targets.length);

        // the rest rises from below the bottom edge
        for (var j = n; j < targets.length; j++) {
            var q = targets[j];
            mining.push({
                "x0": q.x + (Math.random() - 0.5) * width * 0.25,
                "y0": height + 10 + Math.random() * height * 0.7,
                "x": q.x,
                "y": height + 10,
                "s0": q.s,
                "s": q.s,
                "ts": q.s,
                "tx": q.x,
                "ty": q.y,
                "white": 1,
                "delay": 0,
                "flyDelay": Math.random() * 0.9,
                "fromBelow": true
            });
        }
        return true;
    }

    function finishBlockAnimation() {
        blockPhase = "idle";
        mining = [];
        blockRevealed = true;
        blockAnim.requestPaint();
        blockCanvas.requestPaint();
    }

    function stepBlockAnimation(dt) {
        if (blockPhase === "idle")
            return false;
        blockTakt += dt;
        var i, m, u;

        if (blockPhase === "ice") {
            for (i = 0; i < mining.length; i++) {
                m = mining[i];
                u = blockTakt - m.delay;
                if (u <= 0)
                    continue;
                m.white = Math.min(1, u / 0.35);
                var p = u < 0.75 ? Math.sin(u / 0.75 * Math.PI) : 0;
                m.s = m.s0 * (1 + 0.25 * p);
            }
            var ready = blockCanvas.forHeight === (feed ? feed.tipHeight : 0) && blockCanvas.squares.length > 0;
            if (blockTakt > 3 && ready && assignBlockTargets()) {
                blockPhase = "fly";
                blockTakt = 0;
            } else if (blockTakt > 20) {
                finishBlockAnimation();
            }
            return true;
        }

        if (blockPhase === "fly") {
            var pending = false;
            for (i = 0; i < mining.length; i++) {
                m = mining[i];
                u = (blockTakt - m.flyDelay) / 1.2;
                if (u < 1)
                    pending = true;
                u = u < 0 ? 0 : (u > 1 ? 1 : u);
                var ease = u * u * (3 - 2 * u);
                m.x = m.x0 + (m.tx - m.x0) * ease;
                m.y = m.y0 + (m.ty - m.y0) * ease;
                m.s = m.s0 + (m.ts - m.s0) * ease;
                m.white = 1;                 // assembled in white
            }
            if (!pending) {
                blockPhase = "settle";
                blockTakt = 0;
            }
            return true;
        }

        // settle: the finished block fades from white to orange
        blockFade = Math.min(1, blockTakt / 0.9);
        if (blockTakt > 1.15)
            finishBlockAnimation();
        return true;
    }

    // Color of a pile tile. There is no type here: the WebSocket `transactions`
    // messages carry no `flags`, and querying each one is out of the question
    // at five new transactions per second. In "type" mode the pile therefore
    // falls back to the fee color, and the legend says so.
    function colorFor(entry) {
        if (colorMode === "age")
            return Palette.ageColor(Date.now() - entry.t0);
        return Palette.feeColorForRate(entry.rate);
    }

    // mempool.space delivers new transactions as a batch every second. If they
    // all started falling at once there would be bursts instead of rain, so they
    // are released spread over the interval.
    function drainQueue(dt) {
        if (queue.length === 0) {
            queueAcc = 0;
            return;
        }
        queueAcc += (queue.length / 0.85) * dt;
        while (queueAcc >= 1 && queue.length > 0) {
            queueAcc -= 1;
            var t = queue.shift();
            addTx(t.a, t.r, t.v, 0, t);
        }
    }

    // Returns true if the pile changed and needs to be repainted
    function step(dt) {
        drainQueue(dt);
        var g = height * 1.1;
        var settled = false;
        var stillFlying = [];
        for (var i = 0; i < flying.length; i++) {
            var e = flying[i];
            e.vy += g * dt;
            var ty = targetY(e.sq);
            var span = ty - e.fromY;
            // The transition counts, not the state: 'pending' may only be set in the
            // one frame in which the tile lands. If it were set on every 'fly >= 1',
            // step() (30/s) would immediately overwrite what poolCanvas.onPaint (5/s)
            // reset. The tile would never leave 'flying', the list would grow to the
            // whole pile, and from 'capacity' on new tiles would fall invisibly.
            var wasFlying = e.fly < 1;
            e.fly = span > 0 ? Math.min(1, e.fly + (e.vy * dt) / span) : 1;
            if (e.fly >= 1 && wasFlying) {
                e.pending = true;
                settled = true;
            }
            // The tile leaves this list only once the pile has been repainted
            // (poolCanvas resets pending). Otherwise it would be visible nowhere for one
            // or two frames and blink out.
            if (e.fly < 1 || e.pending)
                stillFlying.push(e);
        }
        if (stillFlying.length !== flying.length)
            flying = stillFlying;

        if (blockPulse > 0)
            blockPulse = Math.max(0, blockPulse - dt / 1.8);

        if (layout) {
            var rows = layout.height();
            if (rows !== pileRows)
                pileRows = rows;
        }

        var scrolled = false;
        if (scrollPx < 0) {
            scrollPx = Math.min(0, scrollPx + gridSize * dt / 0.3);
            scrolled = true;
        }

        // The bottom row is not collected separately. It stays in `poolTx` until
        // the end and `poolCanvas` draws it past the edge, where it is clipped.
        // Anything fully below the edge is invisible anyway, and anything above it
        // still belongs to the pile.

        var animating = stepBlockAnimation(dt);
        return maintainPool(dt) || settled || scrolled || animating;
    }

    onGridWChanged: resetPool()
    onGridRowsChanged: resetPool()
    Component.onCompleted: resetPool()

    Connections {
        target: root.feed
        enabled: root.feed !== null

        function onTransactionsArrived(txs) {
            if (root.paused || !root.layout)
                return;
            // Do not collect what nobody sees. The tick only runs while the area is
            // visible (`Timer.running` below), but arrivals keep coming. After half an
            // hour on another tab thousands would be queued, and `drainQueue` releases
            // them at `queue.length / 0.85` per second, so practically all at once:
            // switching back would drop the whole half hour in one flood.
            //
            // The rain shows what is arriving right now. What arrived while another tab
            // was open is old news, and the pile itself is still there anyway.
            if (!root.visible)
                return;
            for (var i = 0; i < txs.length; i++) {
                var t = txs[i];
                root.queue.push(t);
            }
            // And a limit while visible too. A machine that stalls, or a burst from
            // mempool.space, causes the same flood. Two seconds of backlog at five
            // arrivals per second is plenty; anything beyond that could not be seen as
            // individual tiles anyway.
            if (root.queue.length > root.queueMax)
                root.queue.splice(0, root.queue.length - root.queueMax);
        }

        function onBlockMined(tip) {
            root.startBlockAnimation();
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.visible && !root.paused && root.width > 0
        onTriggered: {
            if (root.step(0.033))
                root.poolDirty = true;
            flyLayer.refresh();
                if (root.blockPhase !== "idle")
                blockAnim.requestPaint();
        }
    }

    // The pile is the expensive layer. It is repainted at most five times a
    // second; in between the animation layer keeps drawing.
    Timer {
        interval: 200
        repeat: true
        running: root.visible && !root.paused
        onTriggered: {
            if (root.poolDirty) {
                root.poolDirty = false;
                poolCanvas.requestPaint();
            }
        }
    }

    // The age color changes slowly, so repainting once a second is enough
    // instead of thirty times a second.
    Timer {
        interval: 1200
        repeat: true
        running: root.visible && !root.paused && root.colorMode === "age"
        onTriggered: poolCanvas.requestPaint()
    }


    // ------------------------------------------------------------ Block field
    // Separate canvas: the block only changes every ten minutes and does not
    // need to be repainted thirty times a second.
    Canvas {
        id: blockCanvas

        anchors.fill: parent
        // Above the rain, not below it. Otherwise falling mempool tiles
        // (`flyKachel`) would be drawn across the middle of the block.
        z: 20
        // Antialias only where cells are smaller than `zelleGanzAb` device pixels;
        // otherwise the tile graphic stays deliberately hard.
        antialiasing: rowsUsed > 0 && root.grobRaster(root.blockUnit(rowsUsed))
        visible: root.showBlock

        property var squares: []
        property var cellIdx: ({})      // grid cell -> tile index, for the tooltip
        property int gridUnits: 1
        property int rowsUsed: 1
        property int forHeight: 0

        function rebuild() {
            var b = root.feed ? root.feed.block : null;
            if (!b || !b.tiles || b.tiles.length < 2) {
                squares = [];
                requestPaint();
                return;
            }

            var tiles = b.tiles;
            var n = Math.floor(tiles.length / 2);
            // One digit per tile: the inferred transaction type. Older block data does
            // not have the field, then everything counts as a payment.
            var types = b.types || "";
            var sizes = [], buckets = [], kinds = [], weight = 0;
            for (var i = 0; i < n; i++) {
                var r = parseInt(tiles.charAt(i * 2), 10) || 1;
                sizes.push(r);
                buckets.push(parseInt(tiles.charAt(i * 2 + 1), 10) || 0);
                kinds.push(i < types.length ? (parseInt(types.charAt(i), 10) || 0) : 0);
                weight += r * r;
            }

            var gw = Math.max(4, Math.ceil(Math.sqrt(weight)));
            var lay = new Mondrian.MondrianLayout(gw);
            var out = [];
            for (var k = 0; k < n; k++)
                out.push({ "sq": lay.place(sizes[k]), "b": buckets[k], "k": kinds[k] });

            var idx = {};
            for (var c = 0; c < out.length; c++) {
                var q = out[c].sq;
                for (var qx = 0; qx < q.r; qx++) {
                    for (var qy = 0; qy < q.r; qy++)
                        idx[(q.x + qx) + ":" + (q.y + qy)] = c;
                }
            }
            cellIdx = idx;

            squares = out;
            gridUnits = gw;
            rowsUsed = Math.max(gw, lay.height());
            forHeight = b.height;
            // How often each type occurs, used by the legend
            var z = [0, 0, 0, 0, 0, 0, 0, 0];
            for (var t = 0; t < kinds.length; t++)
                z[kinds[t]]++;
            root.blockTypeCounts = z;
            requestPaint();
        }

        // Outline of the block tile under the pointer
        function hoverRectAt(px, py) {
            if (squares.length === 0)
                return null;
            var g = root.blockUnit(rowsUsed);
            var pad = root.blockPad(g);
            var bx = root.schnapp((root.width - gridUnits * g) / 2);
            var by = root.schnapp(root.blockCenterY - (rowsUsed * g) / 2);
            var cx = Math.floor((px - bx) / g);
            var cy = Math.floor((py - by) / g);
            var i = cellIdx[cx + ":" + cy];
            if (i === undefined || !squares[i])
                return null;
            return blockRect(squares[i].sq, g, bx, by, pad);
        }

        // Round edges to whole pixels so all gaps are the same width
        function blockRect(q, g, bx, by, pad) {
            // Below `zelleGanzAb` device pixels per cell, do not round. Rounded there,
            // only 1 px cells and 1 px tiles remain: tiles touch and merge into blobs.
            // Unrounded and antialiased they form a texture instead, which is also what
            // the original does, since it draws with fractional sizes in WebGL anyway.
            if (root.grobRaster(g)) {
                var side = Math.max(0.35, q.r * g - pad * 2);
                return {
                    "x": bx + q.x * g + pad,
                    "y": by + q.y * g + pad,
                    "w": side,
                    "h": side
                };
            }
            var x0 = root.schnapp(bx + q.x * g);
            var x1 = root.schnapp(bx + (q.x + q.r) * g);
            var y0 = root.schnapp(by + q.y * g);
            var y1 = root.schnapp(by + (q.y + q.r) * g);
            return {
                "x": x0 + pad,
                "y": y0 + pad,
                "w": Math.max(1 / root.dpr, x1 - x0 - pad * 2),
                "h": Math.max(1 / root.dpr, y1 - y0 - pad * 2)
            };
        }

        // Which transaction of the block is under the pointer?
        function blockTxAt(px, py) {
            if (squares.length === 0 || !root.blockRevealed)
                return null;
            var g = root.blockUnit(rowsUsed);
            var bx = root.schnapp((root.width - gridUnits * g) / 2);
            var by = root.schnapp(root.blockCenterY - (rowsUsed * g) / 2);
            var cx = Math.floor((px - bx) / g);
            var cy = Math.floor((py - by) / g);
            if (cx < 0 || cy < 0 || cx >= gridUnits || cy >= rowsUsed)
                return null;
            var i = cellIdx[cx + ":" + cy];
            if (i === undefined)
                return null;
            var list = (root.feed && root.feed.block) ? root.feed.block.txs : null;
            var t = list ? list[i] : null;
            if (!t)
                return null;
            return {
                "t": t[0],
                "v": t[1],
                "f": t[2],
                "a": t[3],
                "r": t[4],
                "inBlock": true
            };
        }

        // Screen rectangle of a block tile, used as flight target when a block is found
        function rectFor(q) {
            var g = root.blockUnit(rowsUsed);
            var side = g * rowsUsed;
            var pad = root.blockPad(g);
            var bx = root.schnapp((root.width - gridUnits * g) / 2);
            var by = root.schnapp(root.blockCenterY - (rowsUsed * g) / 2);
            var r = blockRect(q, g, bx, by, pad);
            return {
                "x": r.x,
                "y": r.y,
                "s": r.w
            };
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            root.viewApply(ctx);
            // While the mined transactions are on their way the block field is empty;
            // the block only appears when they arrive.
            if (!root.blockRevealed || squares.length === 0 || root.poolTop < 24)
                return;

            var g = root.blockUnit(rowsUsed);
            var side = g * rowsUsed;
            var pad = root.blockPad(g);
            var bx = root.schnapp((root.width - gridUnits * g) / 2);
            // In the block the grid axis runs downwards (row 0 at the top), so the large
            // transactions placed first end up at the top.
            var by = root.schnapp(root.blockCenterY - (rowsUsed * g) / 2);

            var byColor = {};
            for (var i = 0; i < squares.length; i++) {
                var s = squares[i];
                var c = root.blockTileColor(s);
                if (!byColor[c])
                    byColor[c] = [];
                byColor[c].push(s.sq);
            }

            for (var col in byColor) {
                ctx.fillStyle = col;
                var list = byColor[col];
                for (var j = 0; j < list.length; j++) {
                    var r = blockRect(list[j], g, bx, by, pad);
                    ctx.fillRect(r.x, r.y, r.w, r.h);
                }
            }
        }

        Connections {
            target: root.feed
            enabled: root.feed !== null
            function onBlockChanged() {
                blockCanvas.rebuild();
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: rebuild()

        // The block depends on the top edge of the pile. `blockSide` computes
        // `min(width*0.72, height/2.5, poolTop*0.86)`, and `poolTop` moves with the
        // fill level, so a change of `poolTop` must trigger a repaint too.
        //
        // At startup the pile is empty, `poolTop` is small and `blockSide` almost
        // zero, so the block is not drawn at all. Without this repaint it would
        // only appear after switching tabs, when the canvas is recreated.
        //
        // This is cheap: once the pile has some height, width and height clamp the
        // value and `blockSide` stops changing by itself. The repaints only happen
        // in the first seconds.
        Connections {
            target: root
            function onBlockSideChanged() {
                blockCanvas.requestPaint();
            }
        }

        Connections {
            target: root
            function onBlockRevealedChanged() {
                blockCanvas.requestPaint();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onPositionChanged: mouse => {
            // The tooltip is positioned in window coordinates, hit testing in the scene.
            root.hoverX = mouse.x;
            root.hoverY = mouse.y;
            var h = root.hitAt(mouse.x, mouse.y);
            if (h) {
                root.hoveredTx = h.tx;
                root.hoverRect = h.rect;
            } else {
                root.clearHoverIfAway(root.toSceneX(mouse.x), root.toSceneY(mouse.y));
            }
        }

        // Mouse only. On touch `onExited` does arrive after release, but after the
        // PointHandler below, and it would clear the info that was just pinned. On
        // touch the PointHandler alone decides.
        onExited: {
            if (root.touchUi)
                return;
            root.hoveredTx = null;
            root.hoverRect = null;
        }

        // On touch there is no "exit". The tooltip follows `onPositionChanged` and
        // is cleared by `onExited`, which on Android may not arrive on release: the
        // pointer does not leave, it stops existing. (Sometimes it does arrive,
        // later; nothing relies on it either way, see `onExited`.) The tooltip
        // would stay up. `acceptedButtons` is `NoButton` here, so there is no
        // `onReleased` either. What only has an exit with a pointer has none on
        // touch, so this handler provides it.
        //
        // It also detects the tap itself. A TapHandler receives nothing on touch
        // here (neither `tapped` nor `singleTapped`), so a tap and the double tap
        // to reset would do nothing. Instead: short and without significant
        // movement is a tap, two of them in quick succession at the same spot a
        // double tap. All in one handler, in a fixed order.
        PointHandler {
            id: finger

            enabled: root.touchUi
            property point startPos
            property point lastPos
            property real startAt: 0
            property real lastTapAt: 0
            property point lastTapPos

            onPointChanged: if (active) lastPos = point.position
            onActiveChanged: {
                if (active) {
                    startPos = point.position;
                    lastPos = point.position;
                    startAt = Date.now();
                    return;
                }
                var weit = Qt.styleHints.startDragDistance;
                var dx = lastPos.x - startPos.x, dy = lastPos.y - startPos.y;
                var tipp = Date.now() - startAt < 500 && dx * dx + dy * dy <= weit * weit;
                if (!tipp) {
                    // Dragged or held long: release the info.
                    root.hoveredTx = null;
                    root.hoverRect = null;
                    root.pinnedTxid = "";
                    return;
                }
                var jetzt = Date.now();
                var ddx = lastPos.x - lastTapPos.x, ddy = lastPos.y - lastTapPos.y;
                if (jetzt - lastTapAt < Qt.styleHints.mouseDoubleClickInterval
                        && ddx * ddx + ddy * ddy <= 4 * weit * weit) {
                    lastTapAt = 0;
                    root.hoveredTx = null;
                    root.hoverRect = null;
                    root.pinnedTxid = "";
                    root.resetView();
                    return;
                }
                lastTapAt = jetzt;
                lastTapPos = lastPos;
                root.fingerTap(lastPos.x, lastPos.y);
            }
        }

        // The same for the mouse. A TapHandler receives no mouse clicks here either:
        // hovering shows the tooltip, but a click would never open the explorer.
        // Here, press and release without significant movement is a click and opens
        // the tile under the pointer; two clicks in quick succession at the same
        // spot reset the view. Dragging (panning while zoomed) triggers nothing.
        PointHandler {
            id: maus

            enabled: !root.touchUi
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            acceptedButtons: Qt.LeftButton
            property point startPos
            property point lastPos
            property real lastClickAt: 0
            property point lastClickPos

            onPointChanged: if (active) lastPos = point.position
            onActiveChanged: {
                if (active) {
                    startPos = point.position;
                    lastPos = point.position;
                    return;
                }
                var weit = Qt.styleHints.startDragDistance;
                var dx = lastPos.x - startPos.x, dy = lastPos.y - startPos.y;
                if (dx * dx + dy * dy > weit * weit)
                    return;
                var jetzt = Date.now();
                var ddx = lastPos.x - lastClickPos.x, ddy = lastPos.y - lastClickPos.y;
                if (jetzt - lastClickAt < Qt.styleHints.mouseDoubleClickInterval
                        && ddx * ddx + ddy * ddy <= 4 * weit * weit) {
                    lastClickAt = 0;
                    klickOeffnen.stop();
                    root.resetView();
                    return;
                }
                lastClickAt = jetzt;
                lastClickPos = lastPos;
                var h = root.hitAt(lastPos.x, lastPos.y);
                klickOeffnen.txid = h && h.tx && h.tx.t ? String(h.tx.t) : "";
                if (klickOeffnen.txid !== "")
                    klickOeffnen.restart();
            }
        }

        // A single click waits to see whether a second one follows. When zoomed in,
        // almost the whole area is tiles; if the first click of a double click
        // already opened the explorer, there would be no way out of the zoom. So
        // open only after the double click interval, and only if no second click
        // came in between.
        Timer {
            id: klickOeffnen

            property string txid: ""
            interval: Qt.styleHints.mouseDoubleClickInterval
            onTriggered: if (txid !== "") root.txActivated(txid)
        }
    }

    // ----------------------------------------------- Zoom and pan
    // Three ways to the same view: wheel, pinch (touchpad and screen) and drag.
    // The MouseArea above accepts no buttons (`acceptedButtons: Qt.NoButton`),
    // so the two do not get in each other's way.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (event.angleDelta.y === 0)
                return;
            root.zoomStep(event.x, event.y, event.angleDelta.y > 0 ? 1 : -1);
            event.accepted = true;
        }
    }

    PinchHandler {
        id: pinchView

        target: null
        property real startZoom: 1

        onActiveChanged: {
            if (active)
                startZoom = root.zoom;
        }
        onActiveScaleChanged: {
            if (active)
                root.setZoomAt(centroid.position.x, centroid.position.y,
                               startZoom * activeScale);
        }
    }

    DragHandler {
        id: panView

        target: null
        // Without magnification there is nothing to pan, so dragging stays off and
        // does not feel like a stuck window.
        enabled: root.zoomed
        property real lastX: 0
        property real lastY: 0

        onActiveChanged: {
            lastX = centroid.position.x;
            lastY = centroid.position.y;
        }
        onCentroidChanged: {
            if (!active)
                return;
            root.panBy(centroid.position.x - lastX, centroid.position.y - lastY);
            lastX = centroid.position.x;
            lastY = centroid.position.y;
        }
    }

    // Click, tap and double tap are handled by the two PointHandlers in the
    // MouseArea above. There is deliberately no TapHandler here: it receives
    // neither mouse nor touch, and if it ever did fire somewhere, a click would
    // be handled twice.

    // When a block is found up to three thousand tiles fly at once. That is too
    // much for the rectangle layer, so a separate canvas draws only during the
    // animation.
    Canvas {
        id: blockAnim

        anchors.fill: parent
        z: 20                       // same as blockCanvas, see there
        antialiasing: false
        visible: root.blockPhase !== "idle"

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            root.viewApply(ctx);
            if (root.blockPhase === "idle" || !root.mining || root.mining.length === 0)
                return;

            var ice = Palette.iceWhite();
            var mid = Palette.iceMid();
            var ramp = Palette.iceRamp();
            var i, m;

            if (root.blockPhase === "settle") {
                var idx = Math.max(0, Math.min(ramp.length - 1, Math.floor(root.blockFade * (ramp.length - 1))));
                ctx.fillStyle = ramp[idx];
                for (i = 0; i < root.mining.length; i++) {
                    m = root.mining[i];
                    ctx.fillRect(m.x, m.y, m.s, m.s);
                }
                return;
            }

            if (root.blockPhase === "fly") {
                ctx.fillStyle = ice;
                for (i = 0; i < root.mining.length; i++) {
                    m = root.mining[i];
                    ctx.fillRect(m.x, m.y, m.s, m.s);
                }
                return;
            }

            // ice: the tiles light up one after another
            for (i = 0; i < root.mining.length; i++) {
                m = root.mining[i];
                ctx.fillStyle = m.white > 0.66 ? ice : (m.white > 0.25 ? mid : Palette.blockAgeColor());
                ctx.fillRect(m.x, m.y, m.s, m.s);
            }
        }
    }

    // The transaction under the pointer is highlighted so it is clear what the
    // info belongs to; in the original that is `hoverOn()` with the color
    // bluegreen.
    // `transform` acts in an item's own coordinate system: the scale covers
    // width and height, but not x and y, which describe the position in the
    // parent. Set directly on hoverMark, the outline would land at the unscaled
    // position, next to the tile when zoomed. flyLayer does not have this
    // problem because it fills its parent and sits at (0,0) anyway.
    //
    // The fix is a container that sits at (0,0) like flyLayer and carries the
    // view transform; everything inside it then works in scene coordinates.
    Item {
        id: sceneLayer

        anchors.fill: parent
        transform: [
            Scale { xScale: root.zoom; yScale: root.zoom },
            Translate { x: root.viewX; y: root.viewY }
        ]
        z: 60

    Rectangle {
        id: hoverMark

        visible: opacity > 0.01
        color: Palette.hoverColor()
        opacity: root.hoverRect ? 1 : 0
        x: root.hoverRect ? root.hoverRect.x : 0
        y: root.hoverRect ? root.hoverRect.y : 0
        width: root.hoverRect ? root.hoverRect.w : 0
        height: root.hoverRect ? (root.hoverRect.h !== undefined ? root.hoverRect.h : root.hoverRect.w) : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }

    }

    // ----------------------------------------------------- Pile and falling
    Canvas {
        id: poolCanvas

        anchors.fill: parent
        antialiasing: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            // Clear only the pile area instead of the whole canvas; in fullscreen that
            // is four million pixels less per frame.
            // When zoomed the pile can be anywhere, so clear the whole area. Also do
            // that once when leaving zoom, otherwise whatever was last drawn at the top
            // stays, and the dashed line shows up twice (once in place, once as a
            // leftover).
            // The dashed line does not sit at `poolTop`. It is drawn at `pileTopY`,
            // which is something else:
            //
            //   poolTop  = height - poolH                 the allotted band
            //   pileTopY = height - pileRows*gridSize
            //              + scrollPx                     the actual fill level
            //
            // `scrollPx` is negative while the pile moves (`-gridSize`, then animated
            // to 0). The line then moves up to `gridSize + 4` points above `poolTop`,
            // out of the region that would be cleared from `poolTop - 8`. It would stay
            // there, and the next fill level would put another line below it.
            //
            // So clearing starts at the highest point where something was drawn in this
            // or the previous frame. That costs a few rows more and otherwise keeps the
            // saving: the block above stays untouched.
            var linie = root.pileTopY - root.gridSize - 4;
            var vorher = root.__letzteLinie < 0 ? linie : root.__letzteLinie;
            root.__letzteLinie = linie;
            var gewachsen = root.width !== root.__letzteBreite
                         || root.height !== root.__letzteHoehe;
            root.__letzteBreite = root.width;
            root.__letzteHoehe = root.height;
            var clearTop = (root.zoomed || root.__warZoom || gewachsen)
                ? 0
                : Math.max(0, Math.min(root.poolTop, linie, vorher) - 8);
            root.__warZoom = root.zoomed;
            ctx.clearRect(0, clearTop, root.width, root.height - clearTop);
            root.viewApply(ctx);
            // While loading and unloading (e.g. the dashboard tab) painting can happen
            // before the state is ready
            if (!root.layout || !root.poolTx)
                return;

            var now = Date.now();
            var ageOn = root.colorMode === "age";
            var pal = Palette.ageColors();
            var steps = pal.length;

            // Batch by color, which saves thousands of state changes
            var groups = {};
            // Transactions of a watched wallet. The daemon sets the field `m`; here it
            // only checks whether it is present.
            var eigene = [];
            var i, e, key;
            for (i = 0; i < root.poolTx.length; i++) {
                e = root.poolTx[i];
                if (e.fly < 1)
                    continue;
                e.pending = false;
                if (e.tx && e.tx.m)
                    eigene.push(e);
                if (ageOn) {
                    var idx = Math.floor((now - e.t0) / 60000 * (steps - 1));
                    key = idx < 0 ? 0 : (idx >= steps ? steps - 1 : idx);
                } else {
                    key = Palette.feeColorForRate(e.rate);
                }
                if (!groups[key])
                    groups[key] = [];
                groups[key].push(e);
            }

            for (var g in groups) {
                ctx.fillStyle = ageOn ? pal[parseInt(g, 10)] : g;
                var list = groups[g];
                for (var j = 0; j < list.length; j++) {
                    var t = list[j];
                    var side = t.sq.r * root.gridSize - root.unitPad * 2;
                    if (side < 1)
                        side = 1;
                    // On whole pixels: targetY contains the animated scrollPx and is
                    // fractional. Without rounding the bottom edge snaps differently from the
                    // top edge, and the tile ends up one pixel taller or shorter than wide.
                    ctx.fillRect(root.snap(root.targetX(t.sq)),
                                 root.snap(root.targetY(t.sq)), side, side);
                }
            }

            // Own transactions get a light outline. Deliberately only an outline and no
            // color of their own: the fill should keep showing fee or age. At four
            // pixels side length a two pixel core remains, which is enough to find them.
            if (eigene.length) {
                ctx.strokeStyle = String(root.ownColor);
                // One device pixel wide, not one logical point; otherwise on a dense
                // screen the outline is almost three pixels thick and covers the tile core.
                ctx.lineWidth = 1 / root.dpr;
                for (i = 0; i < eigene.length; i++) {
                    var m = eigene[i];
                    var ms = m.sq.r * root.gridSize - root.unitPad * 2;
                    if (ms < 1)
                        ms = 1;
                    // On half pixels: a 1 px line would otherwise sit half on each neighboring
                    // pixel and turn gray. Half device pixels, for the same reason as `snap`.
                    var hp = 0.5 / (root.zoom * root.dpr);
                    ctx.strokeRect(root.snap(root.targetX(m.sq)) + hp,
                                   root.snap(root.targetY(m.sq)) + hp,
                                   ms - hp * 2, ms - hp * 2);
                }
            }

            // Separator line at the top of the mempool area. Dashed by hand, which is
            // more reliable than setLineDash.
            //
            // It is not zoomed: it is a label of the view, not a tile. Its caption
            // ("Mempool: … unconfirmed") lives in `FeedPanel` and does not grow either;
            // a line growing next to it looked wrong. So back to screen coordinates and
            // the height converted.
            if (root.showRuler && root.pileRows > 0) {
                ctx.setTransform(1, 0, 0, 1, 0, 0);
                ctx.fillStyle = String(root.rulerColor);
                ctx.globalAlpha = 0.75;
                var y0 = Math.round(root.pileTopY * root.zoom + root.viewY) - 4;
                if (y0 > 0 && y0 < root.height) {
                    for (var dx = 0; dx < root.width; dx += 11)
                        ctx.fillRect(dx, y0, 6, 1);
                }
                ctx.globalAlpha = 1;
            }
        }
    }

    Text {
        id: poolLabel

        anchors.left: parent.left
        y: Math.round(root.pileTopY) - height - 7
        visible: root.showRuler && root.pileRows > 0 && root.height > 150
        color: root.rulerColor
        font.pixelSize: root.labelFont
        text: {
            var n = root.feed ? root.feed.mempoolCount : 0;
            if (!n)
                return Tr.t("mempool", root.lang);
            return Tr.t("feed.mempoolLine", root.lang, Tr.group(n, root.lang));
        }
    }

    // Falling and absorbed transactions as real rectangles instead of on a
    // canvas: there are only a few dozen, and it saves clearing the full canvas
    // thirty times a second.
    Item {
        id: flyLayer

        anchors.fill: parent
        // Rectangles are vector shapes, they stay sharp when scaled.
        transform: [
            Scale { xScale: root.zoom; yScale: root.zoom },
            Translate { x: root.viewX; y: root.viewY }
        ]

        readonly property int capacity: 320


        function refresh() {
            if (!root.flying)
                return;
            var n = 0;
            var i, item;

            for (i = 0; i < root.flying.length && n < capacity; i++) {
                var t = root.flying[i];
                item = flyRepeater.itemAt(n++);
                if (!item)
                    break;
                var side = Math.max(1, t.sq.r * root.gridSize - root.unitPad * 2);
                var ty = root.targetY(t.sq);
                item.x = root.snap(root.targetX(t.sq));
                item.y = root.snap(t.fromY + (ty - t.fromY) * t.fly);
                item.width = side;
                item.height = side;
                item.color = root.colorFor(t);
                item.opacity = 1;
                item.visible = true;
            }

            for (i = n; i < capacity; i++) {
                item = flyRepeater.itemAt(i);
                if (!item)
                    break;
                if (!item.visible)
                    break;
                item.visible = false;
            }

        }

        Repeater {
            id: flyRepeater

            model: flyLayer.capacity

            Rectangle {
                visible: false
                antialiasing: false
            }
        }
    }

    // Pulse when a block is found
    Rectangle {
        visible: root.blockPulse > 0 && root.showBlock
        color: "transparent"
        border.color: "#f7941d"
        border.width: 2 + 8 * root.blockPulse
        opacity: root.blockPulse * 0.5
        width: root.blockSide + 32 * (1 - root.blockPulse)
        height: width
        x: (root.width - width) / 2
        y: root.blockCenterY - height / 2
    }
}
