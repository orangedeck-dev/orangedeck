// Font families in one place.
//
// "monospace" and "sans-serif" are fontconfig names: on Linux fontconfig
// resolves them to the user's default fonts, on Windows and macOS they do
// not exist. There Qt falls back to some font, possibly a proportional one
// where monospace is needed, and then hashes and amounts no longer line up.
//
// `font.families` would be the obvious way, but QML does not have it: the
// `font` value type only knows `family` (checked with Qt 6.11.2, the
// assignment fails with "Cannot assign to non-existent property"). So this
// picks one family instead of listing several.
//
// On Linux the generic name stays and the user's default font is used.
// Only on Windows and macOS the first installed font from the list is
// picked.
.pragma library

var _kandidaten = {
    "mono": ["Menlo", "SF Mono", "Consolas", "Cascadia Mono", "Roboto Mono",
             "DejaVu Sans Mono", "Liberation Mono", "Courier New"],
    "sans": ["Helvetica Neue", "Segoe UI", "Roboto", "Noto Sans",
             "DejaVu Sans", "Liberation Sans", "Arial"],
    "serif": ["Times New Roman", "Georgia", "DejaVu Serif", "Liberation Serif"]
};

var _generisch = { "mono": "monospace", "sans": "sans-serif", "serif": "serif" };

// Computed once, then cached: `Qt.fontFamilies()` reads the whole font
// database, which does not belong in a binding that is re-evaluated for
// every line.
var _gemerkt = {};

function _waehle(art) {
    if (_gemerkt[art] !== undefined)
        return _gemerkt[art];
    var name = _generisch[art];
    var os = (typeof Qt !== "undefined" && Qt.platform) ? Qt.platform.os : "";
    if (os === "windows" || os === "osx") {
        var da = Qt.fontFamilies();
        var liste = _kandidaten[art];
        for (var i = 0; i < liste.length; i++) {
            if (da.indexOf(liste[i]) >= 0) {
                name = liste[i];
                break;
            }
        }
    }
    _gemerkt[art] = name;
    return name;
}

function mono() {
    return _waehle("mono");
}

function sans() {
    return _waehle("sans");
}

function serif() {
    return _waehle("serif");
}

// For `ctx.font` on a Canvas, which uses CSS shorthand. A name with spaces
// needs quotes there, a generic family must not have them: quoted it
// would be looked up as a font name instead of a generic family, and Qt
// would not find it.
function _css(name) {
    return name.indexOf(" ") >= 0 ? '"' + name + '"' : name;
}

function monoCss() {
    return _css(_waehle("mono"));
}

function sansCss() {
    return _css(_waehle("sans"));
}
