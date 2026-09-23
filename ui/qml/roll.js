// Keyboard scrolling: Page Up/Down, Home, End.
//
// Mining, Explorer, Clock and Settings are taller than a small window.
// Without this, the lower part of those pages is out of reach on a machine
// without a mouse wheel.
.pragma library

// `wie`: "ab" (down), "auf" (up), "anfang" (top), "ende" (bottom).
// A page step is 90 % of the height, so one line of the previous view stays
// visible and the reader keeps their place.
function rollen(f, wie) {
    if (!f)
        return false;
    var min = f.originY - f.topMargin;
    var max = Math.max(min, f.originY + f.contentHeight + f.bottomMargin - f.height);
    var y = f.contentY;
    if (wie === "anfang")
        y = min;
    else if (wie === "ende")
        y = max;
    else
        y += (wie === "ab" ? 1 : -1) * f.height * 0.9;
    y = Math.max(min, Math.min(max, y));
    if (y === f.contentY)
        return false;
    f.cancelFlick();
    f.contentY = y;
    return true;
}
