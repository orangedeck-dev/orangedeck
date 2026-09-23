// Currencies in one place.
//
// mempool.space sends seven exchange rates in the same message, so offering
// all of them costs nothing. Which one is shown is a setting; this file only
// holds symbols, names and the rate lookup.
.pragma library

var CURRENCIES = [
    { "k": "eur", "l": "Euro", "z": "€" },
    { "k": "usd", "l": "Dollar", "z": "$" },
    { "k": "gbp", "l": "Pfund", "z": "£" },
    { "k": "chf", "l": "Franken", "z": "CHF" },
    { "k": "cad", "l": "kan. Dollar", "z": "CA$" },
    { "k": "aud", "l": "aust. Dollar", "z": "A$" },
    { "k": "jpy", "l": "Yen", "z": "¥" }
];

function symbol(cur) {
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (CURRENCIES[i].k === cur)
            return CURRENCIES[i].z;
    }
    return "€";
}

function label(cur) {
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (CURRENCIES[i].k === cur)
            return CURRENCIES[i].l;
    }
    return cur;
}

// Rate in the chosen currency. If it is missing, fall back through the list
// in order: another currency is better than a dash.
function rate(price, cur) {
    if (!price)
        return 0;
    if (price[cur])
        return price[cur];
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (price[CURRENCIES[i].k])
            return price[CURRENCIES[i].k];
    }
    return 0;
}

// The currency actually used, for the label.
function actual(price, cur) {
    if (!price)
        return cur;
    if (price[cur])
        return cur;
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (price[CURRENCIES[i].k])
            return CURRENCIES[i].k;
    }
    return cur;
}

// No number formatting here. `strings.js` formats numbers, because the
// notation depends on the language, not the currency. Importing it from here
// does not work: a `.pragma library` script cannot import another script,
// and loading fails silently ("Script ... unavailable"). So this file only
// returns rate and symbol, and the caller formats.
