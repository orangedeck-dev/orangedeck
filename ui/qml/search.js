// Detects what the user typed.
//
// `label` is a key in strings.js, not display text, so the hint in the
// search field follows the UI language.
//
// Ported from bitfeed (MIT, mononaut):
// upstream/bitfeed/client/src/utils/search.js, function `matchQuery`.
// The patterns are taken over; they cover more cases than one would think
// of by hand, especially the block hash with its eight leading zeros and
// the two forms `txid:n` (output) and `n:txid` (input).
//
// The data path is not taken over: bitfeed queries its own Elixir server,
// here everything goes through the daemon.
.pragma library

function matchQuery(query) {
    if (!query || !query.length)
        return null;

    var q = String(query).trim();
    var lower = q.toLowerCase();

    // A number: block height
    var asInt = parseInt(lower, 10);
    if (!isNaN(asInt) && asInt >= 0 && String(asInt) === lower) {
        return { "kind": "blockheight", "label": "blockHeight", "value": lower, "arg": lower };
    }

    // Block hash: 64 hex chars, eight of them leading zeros
    if (/^0{8}[a-f0-9]{56}$/.test(lower)) {
        return { "kind": "blockhash", "label": "search.kind.blockhash", "value": lower, "arg": lower };
    }

    // Input: n:txid
    if (/^[0-9]+:[a-f0-9]{64}$/.test(lower)) {
        var pi = lower.split(":");
        return { "kind": "input", "label": "search.kind.input", "value": lower,
                 "arg": pi[1], "index": parseInt(pi[0], 10) };
    }

    // Output: txid:n
    if (/^[a-f0-9]{64}:[0-9]+$/.test(lower)) {
        var po = lower.split(":");
        return { "kind": "output", "label": "search.kind.output", "value": lower,
                 "arg": po[0], "index": parseInt(po[1], 10) };
    }

    // Transaction: 64 hex chars without the leading zeros
    if (/^[a-f0-9]{64}$/.test(lower)) {
        return { "kind": "tx", "label": "transaction", "value": lower, "arg": lower };
    }

    // Addresses: case matters, so `q` instead of `lower`
    if (/^(bc1|tb1|bcrt1)[023456789acdefghjklmnpqrstuvwxyz]{6,87}$/i.test(q)) {
        return { "kind": "address", "label": "search.kind.segwit", "value": q, "arg": q };
    }
    if (/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/.test(q)) {
        return { "kind": "address", "label": "address", "value": q, "arg": q };
    }
    if (/^(xpub|ypub|zpub|vpub|upub)[a-km-zA-HJ-NP-Z1-9]{50,}$/.test(q)) {
        return { "kind": "xpub", "label": "search.kind.xpub", "value": q, "arg": q };
    }

    return null;
}

// What the input could be while still typing, for the hint on the right
// of the field. `tr(key, value)` translates; the library itself knows no
// language.
function hintFor(query, tr) {
    if (!query || !query.length)
        return tr("search.placeholder");
    var m = matchQuery(query);
    if (m)
        return tr(m.label);
    var q = String(query).trim();
    if (/^[0-9a-fA-F]+$/.test(q) && q.length < 64)
        return tr("search.moreChars", 64 - q.length);
    return tr("search.invalidHint");
}
