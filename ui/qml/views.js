// The app's views, defined in one place.
//
// The order is needed in several places: `FeedTabs.tabViews`,
// `FeedTabs.tabNamen` and the start view setting. Keeping separate copies
// lets them drift apart, e.g. a start view list that does not know about
// views added later. A new view goes into the table below and every place
// picks it up.
//
// Pure functions, no state, like `strings.js` and for the same reason:
// the same files run in the app, in the Quickshell window and in the DMS
// plugin, and a QML singleton needs a `qmldir` that only the CMake module
// generates.
.pragma library

// Default order: what a user sees without rearranging anything.
//
//   id         the number the view is known by everywhere (also `--view N`
//              and the Android shortcuts). Not its position: the market
//              view has id 6 but sits in fifth place. Renumbering would
//              break every stored value and every shortcut.
//   name       key in `strings.js`
//   schalter   setting that can turn the tab off.
//              Empty means it cannot be turned off.
var ANSICHTEN = [
    { "id": 0, "name": "tab.feed",     "schalter": "showFeed"     },
    { "id": 1, "name": "tab.clock",    "schalter": "showClock"    },
    { "id": 2, "name": "tab.miner",    "schalter": "showMiner"    },
    { "id": 3, "name": "tab.explorer", "schalter": "showExplorer" },
    { "id": 6, "name": "tab.market",   "schalter": "showMarket"   },
    // The wallet does not use a tab switch but `walletEnabled`, the switch
    // with the warning in front of it. A second switch next to it would only
    // raise the question which one applies.
    { "id": 4, "name": "tab.wallet",   "schalter": ""             },
    // Settings always stay. Otherwise turning off the last tab would leave
    // no way to reach any switch.
    { "id": 5, "name": "tab.settings", "schalter": ""             }
];

var EINSTELLUNGEN = 5;

function eintrag(id) {
    var n = parseInt(id, 10);
    for (var i = 0; i < ANSICHTEN.length; i++) {
        if (ANSICHTEN[i].id === n)
            return ANSICHTEN[i];
    }
    return null;
}

// Translation key of a view. Unknown ids return "", so the caller shows
// nothing instead of a bare number.
function name(id) {
    var e = eintrag(id);
    return e ? e.name : "";
}

function schalter(id) {
    var e = eintrag(id);
    return e ? e.schalter : "";
}

function alle() {
    var out = [];
    for (var i = 0; i < ANSICHTEN.length; i++)
        out.push(ANSICHTEN[i].id);
    return out;
}

// Map the stored order onto the known set of views.
//
// Lenient in both directions on purpose: unknown entries are dropped (a
// view that no longer exists blocks nothing), missing ones are appended
// (a new view shows up without anyone having to reset their stored order).
//
// From QSettings the entries are strings ("0", "1"), from view.json
// numbers. `parseInt` in `eintrag` accepts both.
function ordnung(gespeichert) {
    var out = [];
    if (gespeichert && gespeichert.length) {
        for (var i = 0; i < gespeichert.length; i++) {
            var e = eintrag(gespeichert[i]);
            if (e && out.indexOf(e.id) < 0)
                out.push(e.id);
        }
    }
    for (var j = 0; j < ANSICHTEN.length; j++) {
        if (out.indexOf(ANSICHTEN[j].id) < 0)
            out.push(ANSICHTEN[j].id);
    }
    return out;
}

// The tabs that are actually shown.
//
//   gespeichert  the user's order (may be empty)
//   moeglich(id) can this view show anything at all? A technical check:
//                the miner sits in the home network, wallet derivation and
//                market candles are computed by the daemon. A tab that
//                can never have content is worse than no tab.
//   an(schluessel) did the user leave it on? The switch is applied on top
//                and cannot force anything.
//   mitEinstellungen  whether settings is a tab (default yes). The
//                standalone app uses a gear button instead, because on the
//                phone the full-screen button covered the last tab.
function reiter(gespeichert, moeglich, an, mitEinstellungen) {
    var einst = mitEinstellungen !== false;
    var ord = ordnung(gespeichert);
    var out = [];
    for (var i = 0; i < ord.length; i++) {
        var e = eintrag(ord[i]);
        if (e.id === EINSTELLUNGEN && !einst)
            continue;
        if (!moeglich(e.id))
            continue;
        if (e.schalter.length && !an(e.schalter))
            continue;
        out.push(e.id);
    }
    // Final guard: settings stay reachable whatever `moeglich` and `an`
    // report, either as a tab or, if the host prefers, through its gear button.
    if (einst && out.indexOf(EINSTELLUNGEN) < 0)
        out.push(EINSTELLUNGEN);
    return out;
}
