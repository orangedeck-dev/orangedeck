// Detects the transaction type from its structure.
//
// Bitcoin has no transaction types. What this returns is an interpretation
// based on inputs and outputs. It is useful but never certain: a wallet can
// produce any pattern for other reasons. So the UI calls it a type, not a
// certainty.
.pragma library

// Colors fit the rest of the UI: warm tones for everyday payments, cool
// ones for reshuffling, a separate tone for data storage.
// Color per type. The label lives in strings.js under "type.<key>";
// it is translated, the color is not.
var TYPES = {
    "payment":       { "color": "#f7931a" },
    "consolidation": { "color": "#3fb3a3" },
    "batch":         { "color": "#4a86d8" },
    "coinjoin":      { "color": "#c065c9" },
    "data":          { "color": "#8a7f9c" },
    "coinbase":      { "color": "#d8b84a" },
    "sweep":         { "color": "#6f7fd0" },
    "inscription":   { "color": "#e0578f" }
};

// --- Interpretation of the mempool.space `flags` ------------------------
//
// The tile view has no inputs and outputs, only the short form. It does
// carry a bit field that mempool.space computes itself. The bit positions
// are taken from `frontend/src/app/shared/filters.utils.ts`
// (TransactionFlags) and were checked against real data: a transaction
// with bit 24 set did have an OP_RETURN output, one without did not.
var FLAG = {
    "rbf": 0, "no_rbf": 1, "v1": 2, "v2": 3, "v3": 4, "nonstandard": 5,
    "p2pk": 8, "p2ms": 9, "p2pkh": 10, "p2sh": 11, "p2wpkh": 12, "p2wsh": 13, "p2tr": 14,
    "cpfp_parent": 16, "cpfp_child": 17, "replacement": 18, "acceleration": 19,
    "op_return": 24, "fake_pubkey": 25, "inscription": 26, "fake_scripthash": 27, "annex": 28,
    "coinjoin": 32, "consolidation": 33, "batch_payout": 34
};

// Careful: `>>` works on 32 bits in JavaScript, the flags go up to 2^44.
// So divide by powers of two instead of shifting.
function hasFlag(flags, name) {
    var b = FLAG[name];
    if (b === undefined || !flags)
        return false;
    return Math.floor(flags / Math.pow(2, b)) % 2 === 1;
}

// Order of the types in the tile view. The daemon stores exactly this
// digit per tile, so both lists must stay in sync.
var KINDS = ["payment", "consolidation", "batch", "coinjoin",
             "data", "inscription", "coinbase", "sweep"];

function kindAt(i) {
    return KINDS[i] || "payment";
}

// Determine the type from the bit field. The order is the priority:
// rarer and more telling types win.
function fromFlags(flags, isCoinbase) {
    if (isCoinbase)
        return "coinbase";
    if (hasFlag(flags, "coinjoin"))
        return "coinjoin";
    if (hasFlag(flags, "inscription"))
        return "inscription";
    if (hasFlag(flags, "op_return"))
        return "data";
    if (hasFlag(flags, "consolidation"))
        return "consolidation";
    if (hasFlag(flags, "batch_payout"))
        return "batch";
    return "payment";
}

function classify(tx) {
    if (!tx)
        return null;
    var vin = tx.vin || [], vout = tx.vout || [];
    var nIn = vin.length, nOut = vout.length;

    if (nIn && vin[0] && vin[0].is_coinbase)
        return "coinbase";

    // Data storage first: it is unambiguous
    for (var i = 0; i < nOut; i++) {
        if (vout[i] && vout[i].scriptpubkey_type === "op_return")
            return "data";
    }

    // Count equal-sized outputs, the mark of a CoinJoin
    var counts = {}, best = 0;
    for (i = 0; i < nOut; i++) {
        var v = vout[i] ? vout[i].value : 0;
        counts[v] = (counts[v] || 0) + 1;
        if (counts[v] > best)
            best = counts[v];
    }
    if (nIn >= 5 && nOut >= 5 && best >= 3)
        return "coinjoin";

    if (nIn >= 5 && nOut <= 2)
        return "consolidation";
    if (nIn <= 2 && nOut >= 5)
        return "batch";
    // Consolidation only from two inputs: a payment without change (1 to 1)
    // is not a consolidation, and it is common.
    if (nOut === 1 && nIn >= 2)
        return "sweep";
    return "payment";
}

function info(kind) {
    return TYPES[kind] || TYPES["payment"];
}

// Translated label. The key in strings.js is "type.<kind>".
function labelKey(kind) {
    return "type." + (TYPES[kind] ? kind : "payment");
}
