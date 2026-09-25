// Uebernommen aus ui/qml/mondrian.js durch tools/website.py.
// Nicht hier bearbeiten -- die Quelle liegt in der Anwendung.
// Packing of the transaction squares, modeled on bitfeed
// (client/src/models/TxMondrianPoolScene.js, MIT, mononaut).
//
// The layout is the same: the grid is "width" units wide and grows upwards,
// and each transaction goes to the first free spot from the bottom left
// where its r x r square fits. That produces the typical picture: large
// squares scattered between densely packed small ones.
//
// The bookkeeping underneath is different. The original keeps a list of
// free "slots" {x, y, r}. That is fast, but removing a tile does not give
// back its whole area: under constant reshuffling the density drops from
// 96 % to 90 % and the holes keep growing. Bitfeed hardly ever removes
// tiles, this view reshuffles all the time. So this uses an exact
// occupancy map instead: a cell is either taken or free.


function MondrianLayout(width) {
    this.width = width;
    this.rows = [];          // one array per row, 1 = taken
    this.rowFree = [];       // number of free cells per row
    this.lowestFree = 0;     // search starts at this row
    // The bottom row drops out of view when the pile gets too high. So that
    // the tiles above keep their coordinates, rowOffset counts how many rows
    // have already dropped out. All y values are absolute; rows[] is accessed
    // via y - rowOffset.
    this.rowOffset = 0;
}

MondrianLayout.prototype.idx = function (y) {
    return y - this.rowOffset;
};

MondrianLayout.prototype.ensureRows = function (upTo) {
    var need = this.idx(upTo);
    while (this.rows.length <= need) {
        var row = new Array(this.width);
        for (var i = 0; i < this.width; i++)
            row[i] = 0;
        this.rows.push(row);
        this.rowFree.push(this.width);
    }
};

MondrianLayout.prototype.fits = function (x, y, r) {
    if (x + r > this.width)
        return false;
    for (var yy = this.idx(y); yy < this.idx(y) + r; yy++) {
        if (yy < 0)
            return false;                // already dropped out
        if (yy >= this.rows.length)
            continue;                    // rows not created yet are free
        var row = this.rows[yy];
        for (var xx = x; xx < x + r; xx++) {
            if (row[xx])
                return false;
        }
    }
    return true;
};

MondrianLayout.prototype.mark = function (x, y, r, value) {
    this.ensureRows(y + r);
    for (var yy = this.idx(y); yy < this.idx(y) + r; yy++) {
        if (yy < 0 || yy >= this.rows.length)
            continue;
        var row = this.rows[yy];
        for (var xx = x; xx < x + r; xx++) {
            if (row[xx] !== value) {
                row[xx] = value;
                this.rowFree[yy] += value ? -1 : 1;
            }
        }
    }
};

// Places a square of edge length "size" at the first fitting spot from
// the bottom left and returns {x, y, r}.
MondrianLayout.prototype.place = function (size) {
    var y = Math.max(this.lowestFree, this.rowOffset);
    for (;;) {
        this.ensureRows(y + size);
        if (this.rowFree[this.idx(y)] >= size) {
            var row = this.rows[this.idx(y)];
            for (var x = 0; x + size <= this.width; x++) {
                if (row[x])
                    continue;
                if (this.fits(x, y, size)) {
                    this.mark(x, y, size, 1);
                    while (this.idx(this.lowestFree) < this.rows.length && this.rowFree[this.idx(this.lowestFree)] === 0)
                        this.lowestFree++;
                    return { x: x, y: y, r: size };
                }
            }
        }
        y++;
    }
};

MondrianLayout.prototype.remove = function (square) {
    this.mark(square.x, square.y, square.r, 0);
    if (square.y < this.lowestFree)
        this.lowestFree = square.y;
};

// Gravity: tiles move down into gaps. Modeled on mempool.space
// (`BlockLayout.applyGravity` in
// frontend/src/app/components/block-overview-graph/block-scene.ts): every
// tile with the whole row below it free is taken out and placed again at
// the first fitting spot. Its own spot is free again during that, so it
// never ends up worse than before.
//
// Used while updating a projected block: removed transactions free their
// area, new ones fill gaps from the front, but only where they fit, so
// the rest would stay as holes. In a simulation with 150 rounds of
// reshuffling (`node tools/packung-sim.js`) this cut the enclosed free
// cells from 525 to 139, moving about 25 tiles per round. A stricter
// version (re-place every tile) got to 106 but moved six times as many
// tiles, a much busier picture for little gain. Several passes per round
// did not help: going front to back, one pass already catches the chains.
//
// `entries` are objects with `sq` = {x, y, r}; `sq` is replaced when the
// tile falls. Returns how many tiles fell.
MondrianLayout.prototype.gravity = function (entries) {
    var order = entries.slice().sort(function (a, b) {
        return a.sq.y - b.sq.y || a.sq.x - b.sq.x;
    });
    var moved = 0;
    for (var i = 0; i < order.length; i++) {
        var q = order[i].sq;
        var vorher = this.idx(q.y - 1);
        if (vorher < 0 || vorher >= this.rows.length)
            continue;
        var row = this.rows[vorher], frei = true;
        for (var x = q.x; x < q.x + q.r; x++) {
            if (row[x]) {
                frei = false;
                break;
            }
        }
        if (!frei)
            continue;
        this.remove(q);
        var neu = this.place(q.r);
        order[i].sq = neu;
        if (neu.x !== q.x || neu.y !== q.y)
            moved++;
    }
    return moved;
};

// Free cells with a tile below them in the same column: the holes you can
// see. The ragged edge at the very back is part of any packing and does
// not count.
MondrianLayout.prototype.enclosedHoles = function () {
    var h = this.height(), n = 0;
    for (var x = 0; x < this.width; x++) {
        var letzte = -1, y;
        for (y = 0; y < h; y++) {
            if (this.rows[y][x])
                letzte = y;
        }
        for (y = 0; y < letzte; y++) {
            if (!this.rows[y][x])
                n++;
        }
    }
    return n;
};

// Stable repack: same order, no holes. Gravity alone is not enough.
// Measured on the live feed it cuts the holes to about a third but does
// not prevent them: a hole with a wider tile above it stays open.
// mempool.space accepts that until the next block is found.
//
// So once there are too many holes, the tiles are put into a fresh packing
// in their current order (front to back, row by row). Tiles before the
// first hole stay where they are; the ones behind move up. In the
// simulation (`node tools/packung-sim.js`) 7 to 11 % of the tiles changed
// place, not the 99.7 % of a full repack sorted by fee, which dissolved
// the block into flicker. Returns the new packing; `sq` of the entries is
// replaced.
function repackStable(width, entries) {
    var lay = new MondrianLayout(width);
    var order = entries.slice().sort(function (a, b) {
        return a.sq.y - b.sq.y || a.sq.x - b.sq.x;
    });
    for (var i = 0; i < order.length; i++)
        order[i].sq = lay.place(order[i].sq.r);
    return lay;
}

// Topmost occupied row
// Height of the pile in visible rows
MondrianLayout.prototype.height = function () {
    for (var y = this.rows.length - 1; y >= 0; y--) {
        if (this.rowFree[y] < this.width)
            return y + 1;
    }
    return 0;
};

// Push the bottom row out of view. It must be empty first; its tiles
// visibly fall out at the bottom.
MondrianLayout.prototype.dropBottomRow = function () {
    if (this.rows.length === 0)
        return;
    this.rows.shift();
    this.rowFree.shift();
    this.rowOffset++;
    if (this.lowestFree < this.rowOffset)
        this.lowestFree = this.rowOffset;
};

// Size of a transaction in grid units, same as logTxSize() in the original
function txSize(valueSats, max) {
    var v = Math.max(1, valueSats || 1);
    var scale = Math.ceil(Math.log(v) / Math.LN10) - 5;
    return Math.min(max || 5, Math.max(1, scale));
}
