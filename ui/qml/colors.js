// Color model from bitfeed (client/src/utils/color.js + models/BitcoinTx.js,
// MIT, mononaut). Colors there are given in HCL and converted to sRGB via
// d3-color: hcl(h * 360, 78.225, l * 150). This is rebuilt here so the
// tones match exactly.

.pragma library

var ORANGE = { h: 0.181, l: 0.472 };
var BLUE = { h: 0.5, l: 0.55 };
var TEAL = { h: 0.475, l: 0.55 };
var PURPLE = { h: 0.95, l: 0.35 };

// bluegreen from color.js; bitfeed uses it to highlight the transaction
// under the pointer (BitcoinTx.hoverOn)
var BLUEGREEN = { h: 0.45, l: 0.4 };

var CHROMA = 78.225;
var AGE_MS = 60000;          // after 60 s a transaction counts as "old"

// --- Lab/LCh -> sRGB, as in d3-color (white point D50) --------------------
var Xn = 0.96422, Yn = 1, Zn = 0.82521;
var t0 = 4 / 29, t1 = 6 / 29, t2 = 3 * t1 * t1, t3 = t1 * t1 * t1;

function lab2xyz(t) {
    return t > t1 ? t * t * t : t2 * (t - t0);
}

function lrgb2rgb(x) {
    var v = x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
    return Math.max(0, Math.min(255, Math.round(255 * v)));
}

function hex2(n) {
    var s = n.toString(16);
    return s.length < 2 ? "0" + s : s;
}

function hclToCss(h01, l01) {
    var hRad = (h01 * 360) * Math.PI / 180;
    var L = l01 * 150;
    var a = Math.cos(hRad) * CHROMA;
    var b = Math.sin(hRad) * CHROMA;

    var y = (L + 16) / 116;
    var x = y + a / 500;
    var z = y - b / 200;
    x = Xn * lab2xyz(x);
    y = Yn * lab2xyz(y);
    z = Zn * lab2xyz(z);

    var r = lrgb2rgb(3.1338561 * x - 1.6168667 * y - 0.4906146 * z);
    var g = lrgb2rgb(-0.9787684 * x + 1.9161415 * y + 0.0334540 * z);
    var bl = lrgb2rgb(0.0719453 * x - 0.2289914 * y + 1.4052427 * z);
    return "#" + hex2(r) + hex2(g) + hex2(bl);
}

function mix(from, to, min, max, value) {
    var dx = Math.max(0, Math.min(1, (value - min) / (max - min)));
    return {
        h: from.h + dx * (to.h - from.h),
        l: from.l + dx * (to.l - from.l)
    };
}

// --- precomputed palettes (HCL conversion is too expensive per frame) ----
var AGE_STEPS = 48;
var agePalette = null;
var feePalette = null;

function ageColors() {
    if (!agePalette) {
        agePalette = [];
        for (var i = 0; i < AGE_STEPS; i++) {
            var c = mix(ORANGE, BLUE, 0, AGE_STEPS - 1, i);
            agePalette.push(hclToCss(c.h, c.l));
        }
    }
    return agePalette;
}

function ageColor(ageMs) {
    var p = ageColors();
    var i = Math.max(0, Math.min(AGE_STEPS - 1, Math.floor(ageMs / AGE_MS * (AGE_STEPS - 1))));
    return p[i];
}

// Fee color: teal -> purple over log2(sat/vB) from 1 to log2(128).
// Coinbase and zero-fee transactions are orange.
function feeColorForRate(rate) {
    if (rate === null || rate === undefined || rate <= 0)
        return hclToCss(ORANGE.h, ORANGE.l);
    var c = mix(TEAL, PURPLE, 1, Math.log(128) / Math.LN2, Math.log(rate) / Math.LN2);
    return hclToCss(c.h, c.l);
}

// Representative rate per fee bucket from block.json
var BUCKET_RATES = [0.3, 0.7, 1.5, 2.5, 4, 6.5, 11, 22, 55, 150];

// Bucket boundaries. Must match FEE_BUCKETS in daemon/orangedeck,
// otherwise the same block is colored differently depending on the data
// source. Ten buckets, nine boundaries; BUCKET_RATES above gives a
// representative rate for each one's color.
var FEE_EDGES = [0.5, 1, 2, 3, 5, 8, 15, 30, 80];

function feeBucket(rate) {
    var r = rate || 0;
    for (var i = 0; i < FEE_EDGES.length; i++) {
        if (r < FEE_EDGES[i])
            return i;
    }
    return FEE_EDGES.length;
}

function feeColors() {
    if (!feePalette) {
        feePalette = [];
        for (var i = 0; i < BUCKET_RATES.length; i++)
            feePalette.push(feeColorForRate(BUCKET_RATES[i]));
    }
    return feePalette;
}

function bucketColor(bucket) {
    var p = feeColors();
    return p[Math.max(0, Math.min(p.length - 1, bucket))];
}

function blockAgeColor() {
    return hclToCss(ORANGE.h, ORANGE.l);
}

// ice() from TxBlockScene.js: when a block is found the tiles are pulled
// to lightness 1, the white the mined transactions flash in.
var ICE = null;
var ICE_MID = null;

function iceColor(h01) {
    var h = Math.abs(h01 - 0.58) < 0.1 ? (h01 < 0.58 ? 0.48 : 0.68) : h01;
    var l = h01 < 0.76 ? 1 : 0.7;
    return hclToCss(h, l);
}

function iceWhite() {
    if (!ICE)
        ICE = iceColor(ORANGE.h);
    return ICE;
}

// Transition white -> block color, as when the block is assembled
var ICE_RAMP = null;

function iceRamp() {
    if (!ICE_RAMP) {
        ICE_RAMP = [];
        var to = hclToCss(ORANGE.h, ORANGE.l);
        var tr = parseInt(to.substr(1, 2), 16);
        var tg = parseInt(to.substr(3, 2), 16);
        var tb = parseInt(to.substr(5, 2), 16);
        for (var i = 0; i < 20; i++) {
            var f = i / 19;
            ICE_RAMP.push("#" + hex2(Math.round(255 + (tr - 255) * f))
                + hex2(Math.round(255 + (tg - 255) * f))
                + hex2(Math.round(255 + (tb - 255) * f)));
        }
    }
    return ICE_RAMP;
}

function hoverColor() {
    return hclToCss(BLUEGREEN.h, BLUEGREEN.l);
}

function iceMid() {
    if (!ICE_MID)
        ICE_MID = hclToCss(ORANGE.h, 0.78);
    return ICE_MID;
}

// Mix two colors, t = 0 gives a, t = 1 gives b. Deliberately in sRGB: this
// is not a gradient between distant tones (HCL would be right for that,
// see DOKUMENTATION) but a fade to white.
function blendHex(a, b, t) {
    var f = Math.max(0, Math.min(1, t));
    var ar = parseInt(a.substr(1, 2), 16), ag = parseInt(a.substr(3, 2), 16), ab = parseInt(a.substr(5, 2), 16);
    var br = parseInt(b.substr(1, 2), 16), bg = parseInt(b.substr(3, 2), 16), bb = parseInt(b.substr(5, 2), 16);
    return "#" + hex2(Math.round(ar + (br - ar) * f))
        + hex2(Math.round(ag + (bg - ag) * f))
        + hex2(Math.round(ab + (bb - ab) * f));
}
