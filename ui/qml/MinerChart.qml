// History of one miner: hashrate and temperature stacked, as in the AxeOS
// web UI. Two axes, because the two values are unrelated.
//
// The data is recorded by the daemon or `DirectMiner`. If the device
// records history itself (AxeOS with `statsFrequency`), it comes from
// there, and the points are one minute apart instead of five seconds.
//
// The time axis follows the timestamps, not the number of points. Device
// history in minute steps followed by recent data in five-second steps,
// spread evenly, would stretch the last few minutes over half the width.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property string lang: "de"

    property var hist: ({})
    property color lineColor: "#f7931a"
    property color tempColor: "#e8e4f0"
    property color gridColor: Qt.rgba(1, 1, 1, 0.07)
    property color dimColor: "#9a94a6"
    property real labelSize: 9
    // Switch to TH/s above this. Deliberately a bit above 1000 so the unit
    // does not flip back and forth when the value hovers around the mark.
    property real teraFrom: 1025

    // History is stored in GH/s.
    function fmtRate(gh, withUnit) {
        if (gh >= root.teraFrom)
            return Tr.fixed(gh / 1000, 2, root.lang) + (withUnit ? " TH/s" : "");
        return Tr.fixed(gh, 0, root.lang) + (withUnit ? " GH/s" : "");
    }

    readonly property var hr: (hist && hist.hr) || []
    readonly property var hrNow: (hist && hist.hrNow) || []
    readonly property var temp: (hist && hist.temp) || []
    readonly property var zeit: (hist && hist.t) || []

    onHrChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var s = root.hr;
            if (s.length < 2)
                return;

            var padL = 4, padR = 4, padT = 6, padB = 14;
            var w = width - padL - padR, h = height - padT - padB;
            if (w <= 0 || h <= 0)
                return;

            // Horizontal position by time when every point has one; otherwise
            // (history without timestamps) by index.
            var zt = root.zeit;
            var nachZeit = zt.length === s.length && zt[zt.length - 1] > zt[0];
            function xAt(i, n) {
                if (nachZeit)
                    return padL + w * (zt[i] - zt[0]) / (zt[zt.length - 1] - zt[0]);
                return padL + w * i / Math.max(1, n - 1);
            }

            // Horizontal grid lines
            ctx.strokeStyle = root.gridColor;
            ctx.lineWidth = 1;
            for (var g = 0; g <= 3; g++) {
                var gy = Math.round(padT + h * g / 3) + 0.5;
                ctx.beginPath();
                ctx.moveTo(padL, gy);
                ctx.lineTo(padL + w, gy);
                ctx.stroke();
            }

            // Both hashrates share one axis, otherwise comparing them is meaningless.
            function rangeOf(lists) {
                var lo = null, hi = null;
                for (var a = 0; a < lists.length; a++) {
                    var v = lists[a];
                    for (var b = 0; b < v.length; b++) {
                        if (v[b] === null || v[b] === undefined)
                            continue;
                        lo = (lo === null) ? v[b] : Math.min(lo, v[b]);
                        hi = (hi === null) ? v[b] : Math.max(hi, v[b]);
                    }
                }
                if (lo === null)
                    return null;
                var span = Math.max(hi - lo, Math.abs(hi) * 0.02, 0.1);
                return [lo - span * 0.15, hi + span * 0.15];
            }

            function drawIn(vals, range, color, width2, alpha) {
                if (!range)
                    return;
                var lo = range[0], hi = range[1];
                ctx.beginPath();
                var started = false;
                for (var i = 0; i < vals.length; i++) {
                    if (vals[i] === null || vals[i] === undefined)
                        continue;
                    var x = xAt(i, vals.length);
                    var y = padT + h - h * (vals[i] - lo) / (hi - lo);
                    started ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
                    started = true;
                }
                ctx.strokeStyle = color;
                ctx.globalAlpha = alpha === undefined ? 1 : alpha;
                ctx.lineWidth = width2;
                ctx.stroke();
                ctx.globalAlpha = 1;
            }

            function draw(vals, color, width2) {
                var pts = [];
                for (var i = 0; i < vals.length; i++) {
                    if (vals[i] !== null && vals[i] !== undefined)
                        pts.push([i, vals[i]]);
                }
                if (pts.length < 2)
                    return null;
                var lo = pts[0][1], hi = pts[0][1];
                for (var j = 1; j < pts.length; j++) {
                    lo = Math.min(lo, pts[j][1]);
                    hi = Math.max(hi, pts[j][1]);
                }
                // Some headroom so the curve does not stick to the edge
                var span = Math.max(hi - lo, Math.abs(hi) * 0.02, 0.1);
                lo -= span * 0.15;
                hi += span * 0.15;
                ctx.beginPath();
                for (var k = 0; k < pts.length; k++) {
                    var x = xAt(pts[k][0], vals.length);
                    var y = padT + h - h * (pts[k][1] - lo) / (hi - lo);
                    k === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.strokeStyle = color;
                ctx.lineWidth = width2;
                ctx.stroke();
                return [lo, hi];
            }

            var tRange = draw(root.temp, root.tempColor, 1.2);

            // Instantaneous value only. The ten-minute value (`hr`, from
            // `hashRate_10m`) is what the device web UI shows, but in operation it is
            // almost always flat: it is smoothed, and a running miner runs steadily.
            // A line that does not move says nothing and takes the axis away from the
            // other one, and the same value is shown as a number next to it anyway.
            //
            // With a fallback though: `hrNow` comes from `hashRate` and is only set
            // on the AxeOS path. A miner on the cgminer interface does not report it
            // (see the cgminer MH/s handling in `daemon/orangedeck`), so `hrNow` is
            // null throughout and its chart would stay empty. So: the instantaneous
            // value if there is one, otherwise the smoothed one.
            var hatNow = false;
            for (var q = 0; q < root.hrNow.length; q++) {
                if (root.hrNow[q] !== null && root.hrNow[q] !== undefined) {
                    hatNow = true;
                    break;
                }
            }
            //
            // And only over short spans. Device history reaches back twelve hours,
            // and there it is the other way round: 720 instantaneous values are a
            // band of noise that hides the daily trend, while the ten-minute value
            // shows exactly that trend. The threshold is one hour: below it the
            // smoothed value is flat, above it the instantaneous value is a band.
            var sekSpanne = nachZeit ? zt[zt.length - 1] - zt[0] : s.length * 5;
            var kurve = hatNow && sekSpanne < 3600 ? root.hrNow : s;
            var hRange = rangeOf([kurve]);
            drawIn(kurve, hRange, root.lineColor, 2.0, 1.0);

            // Labels in the color of their curve, otherwise you cannot tell which
            // axis belongs to which line.
            ctx.font = root.labelSize + "px " + Fonts.sansCss();
            if (hRange) {
                ctx.fillStyle = root.lineColor;
                ctx.textAlign = "left";
                ctx.fillText(root.fmtRate(hRange[1], true), padL, padT + root.labelSize);
                ctx.fillText(root.fmtRate(hRange[0], false), padL, padT + h);
            }
            if (tRange) {
                ctx.fillStyle = root.tempColor;
                ctx.textAlign = "right";
                ctx.fillText(tRange[1].toFixed(0) + " °C", padL + w, padT + root.labelSize);
                ctx.fillText(tRange[0].toFixed(0), padL + w, padT + h);
            }
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "center";
            var sek = sekSpanne;
            var spanne = sek >= 3600
                ? Tr.t("duration.hourMin", root.lang, Math.floor(sek / 3600),
                       Math.round(sek % 3600 / 60))
                : Tr.t("duration.min", root.lang, Math.round(sek / 60));
            ctx.fillText(spanne, padL + w / 2, height - 2);
        }
    }
}
