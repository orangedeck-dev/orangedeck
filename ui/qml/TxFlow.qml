// Flow of a transaction: inputs on the left, outputs on the right, each
// band's height proportional to its amount.
//
// Layout follows mempool.space
// (frontend/src/app/components/tx-bowtie-graph/tx-bowtie-graph.component.ts).
// Three things are taken from it:
//
//   * No tapering. A band keeps its height from left to right. The narrower
//     middle comes only from closing the gaps: at the edges the bands are
//     spaced apart, in the trunk they touch.
//   * The fee is an output like any other, just in its own color. The
//     original does `voutWithFee.unshift({ type: 'fee', value: tx.fee })`, so
//     it comes first. That makes the sums match: total left equals total right.
//   * A minimum thickness so small amounts stay visible. The original uses
//     `minWeight = 2` with `Math.max(minWeight - 1, weight) + 1`.
//
// All inputs merge into one trunk on purpose: Bitcoin does not say which
// input pays which output, so individual links would be made up.
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"
    // As elsewhere: `₿` only where the font has the glyph (see FeedTabs).
    property string btcZeichen: "\u20BF"

    property var vin: []
    property var vout: []
    property real fee: 0
    property color inColor: "#5b8dd9"
    property color outColor: "#f7931a"
    property color feeColor: "#8a7f9c"
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property real labelSize: 10
    // How many bands are drawn individually; the rest are merged into one.
    // The original draws up to `lineLimit = 250` strands. Its `maxStrands = 24`
    // only says how many should fit fully on screen; as a hard cap it drops
    // visible inputs. The limit is also tied to the height so every band keeps
    // its minimum thickness plus a small gap.
    property int maxBands: 250
    readonly property int bandLimit: Math.max(4, Math.min(maxBands,
                                     Math.floor(innerH / Math.max(1.6, minBand + 0.6))))
    // Thin enough to leave air between strands when there are many inputs:
    // 250 strands at 1.3 px leave 0.7 px of gap, at 0.8 px it is 1.2 px.
    property real minBand: Math.max(0.8, labelSize * 0.1)
    // Height of the trunk in the middle. Bands do not taper: the trunk is
    // narrower than the edges only because the gaps between bands disappear
    // there.
    //
    // A fixed pixel value, not a ratio. In mempool.space (tx-bowtie-graph):
    //
    //   combinedWeight = min(maxCombinedWeight /* 100 */, floor((txWidth - 2*midWidth)/6))
    //   innerTop       = height/2 - combinedWeight/2
    //   spacing        = max(4, (height - visibleWeight) / gaps)
    //
    // At their default 1200 x 600 all bands together take 100 of 600 pixels,
    // one sixth of the height, and the gaps take the rest. The trunk keeps its
    // thickness regardless of the band count while the gaps at the edges open
    // up, which gives the wide curve with many inputs and the full band with a
    // single one. A ratio would keep the gap to band proportion constant. The
    // value here is a bit larger because this area is much flatter.
    //
    // With a single band there is no gap and therefore no waist.
    property real trunkPx: labelSize * 5
    readonly property real trunkH: Math.max(minBand, Math.min(innerH * 0.62, trunkPx))
    // How strongly the bands swing. 0.5 gives a plain sine shape; higher
    // values start flatter and run steeper through the middle.
    property real swing: 0.78
    property real edgeGap: Math.max(2, labelSize * 0.3)
    // Gap between the arrow and the right edge, so it does not stick to it.
    property real edgeMargin: Math.max(4, Math.min(width * 0.012, labelSize))

    // A short straight piece before each input and after each output that
    // fades out towards the edge. It shows that the chain continues: another
    // transaction comes before and after this one. mempool.space draws the same
    // short bars left and right of the flow.
    property real stubLen: Math.max(10, Math.min(width * 0.075, 90))
    // No gap between this stub and the band: as in the original, both form one
    // continuous band and only the notch separates them, at both ends.

    // Same angle at both ends: both use atan((h/2) / (h * headRatio)), so a
    // thick band does not end up with two different slopes.
    function tipFor(thickness) {
        return root.headFor(thickness);
    }

    // Notch depth relative to band thickness, derived from the original. There
    // the arrow is an SVG marker with `viewBox="-5 -5 10 10"`,
    // `markerWidth="1.5"`, `markerHeight="1"` and `markerUnits="strokeWidth"`,
    // so it grows with the band. With the default aspect ratio handling the
    // smaller scale wins, 1/10 of the band thickness per unit: the notch is ten
    // units high (the full thickness) and five deep, half the thickness, which
    // is 45 degrees.
    property real headRatio: 0.55

    function headFor(thickness) {
        // The cap keeps the notch inside the straight connector piece. The
        // thickest band is `trunkH`, at most `labelSize * 5`, the connector is
        // `labelSize * 2`: 0.55 * 5 / 2 = 1.375. With 1.4 the cap normally does
        // not kick in, so the angle stays at 45 degrees and the notch reaches at
        // most into the flat start of the curve.
        return Math.max(2, Math.min(connector * 1.4, thickness * root.headRatio));
    }
    // Space above and below so the flow does not touch the edges.
    property real padY: Math.max(6, height * 0.11)
    // Straight connector at both ends before the curve starts
    property real connector: Math.max(6, Math.min(width * 0.05, labelSize * 2))
    readonly property real innerH: Math.max(8, height - 2 * padY)
    // Do not mix in RGB. Blue (H 216°) and orange (H 33°) are 177° apart,
    // almost opposite, and their RGB midpoint drops to 28 % saturation and
    // looks grey.
    //
    // Mixing around the hue circle keeps the saturation. Going up passes
    // magenta (H 305°), going down passes green (H 125°). Magenta suits the
    // orange and matches the original, which runs from violet to blue.
    property bool hueUp: true

    function mixHue(a, b, t) {
        var ha = a.hsvHue < 0 ? 0 : a.hsvHue * 360;
        var hb = b.hsvHue < 0 ? 0 : b.hsvHue * 360;
        var d = root.hueUp ? ((hb - ha) + 360) % 360 : -(((ha - hb) + 360) % 360);
        var h = ((ha + d * t) % 360 + 360) % 360;
        var sa = a.hsvSaturation, sb = b.hsvSaturation;
        var va = a.hsvValue, vb = b.hsvValue;
        return Qt.hsva(h / 360, sa + (sb - sa) * t, va + (vb - va) * t, 1);
    }

    // Color at position t (0 = far left, 1 = far right)
    function flowColor(t) {
        return mixHue(root.inColor, root.outColor, Math.max(0, Math.min(1, t)));
    }

    readonly property color midColor: flowColor(0.5)

    property var hovered: null
    // Pointer position. The tooltip sits next to the pointer instead of at the
    // bottom, so it is read where the user is looking (as in the original).
    property real zeigerX: 0
    property real zeigerY: 0
    // The transaction itself. In the trunk both sides belong to it, so the
    // tooltip shows it above the other details.
    property string txid: ""

    signal activated(string side, int index)

    // The fee counts as an output so both sides have the same height.
    //
    // A function, not a binding. `rebuild()` runs from `onVoutChanged`, and the
    // order in which a change reaches bindings and signal handlers is not
    // defined. If the handler ran first it read a stale, empty list, and the
    // output side stayed blank with the flow ending in the middle.
    function voutMitGebuehr() {
        var l = [];
        if (fee > 0)
            l.push({ "__fee": true, "value": fee });
        var v = vout || [];
        for (var i = 0; i < v.length; i++)
            l.push(v[i]);
        return l;
    }

    // Also a function, for the same reason as `voutMitGebuehr()`: `rebuild()`
    // runs from `onVinChanged` and must not read a binding that may be stale.
    function summeEin() {
        var s = 0, v = vin || [];
        for (var i = 0; i < v.length; i++)
            s += (v[i].prevout && v[i].prevout.value) || 0;
        return s;
    }

    property var bandsIn: []
    property var bandsOut: []

    onVinChanged: rebuild()
    onVoutChanged: rebuild()
    onFeeChanged: rebuild()
    onWidthChanged: rebuild()
    onHeightChanged: rebuild()
    Component.onCompleted: rebuild()

    // Each band keeps its thickness; only the gaps differ between edge and
    // trunk. `edgeY` is the position at the edge (with gaps), `midY` the
    // position in the trunk (without).
    //
    // Position and stroke width are two separate things:
    //
    //   weight     the real share of the amount. All weights add up to exactly
    //              `trunkH` and determine the position in the trunk.
    //   thickness  what is drawn, at least `minBand`. A band thinner than the
    //              minimum overlaps its neighbours in the trunk, which keeps the
    //              trunk narrow even with 250 strands running into it.
    //
    // Treating both as one would stretch the trunk to the sum of the minimum
    // thicknesses: 300 px instead of 40 for 250 bands at 1.2 px. The original:
    //
    //   thickness = min(combinedWeight + 0.5, max(minWeight - 1, w) + 1)
    //   innerY    = min(innerBottom - thickness/2,
    //                   max(innerTop + thickness/2, lastInner + weight/2))
    //
    // Position comes from `weight`, drawn width from `thickness`.
    function build(list, valueOf, total) {
        var n = Math.min(list.length, root.bandLimit);
        var out = [];
        var i;

        function add(v, more, idx) {
            out.push({ "i": idx, "v": v, "more": more || 0, "fee": false });
        }

        for (i = 0; i < n; i++)
            add(valueOf(list[i]) || 0, 0, i);
        if (list.length > n) {
            var rest = 0;
            for (i = n; i < list.length; i++)
                rest += valueOf(list[i]) || 0;
            add(rest, list.length - n, -1);
        }

        // Can be empty when one side is already set and the other is not yet (the
        // properties arrive one after another). The code below reads `out[0]`.
        if (!out.length)
            return out;

        var t = total > 0 ? total : 1;
        var sumThick = 0;
        for (i = 0; i < out.length; i++) {
            out[i].weight = (out[i].v / t) * root.trunkH;
            out[i].thick = Math.max(root.minBand, out[i].weight);
            sumThick += out[i].thick;
        }
        // If the thicknesses do not fit side by side at the edge, scale them all
        // down evenly so the fan does not run off the bottom.
        if (sumThick > root.innerH) {
            var f = root.innerH / sumThick;
            for (i = 0; i < out.length; i++)
                out[i].thick *= f;
            sumThick = root.innerH;
        }

        // --- Position in the trunk: by weight, centered ------------------------
        //
        // A band is drawn with the same thickness everywhere, at the edge and in
        // the trunk. The drawn height of the trunk is therefore not the sum of the
        // weights: the first and the last band stick out by half of what the
        // minimum thickness adds beyond their weight.
        //
        // That overhang differs between the two sides (maybe a thick input on top
        // on the left, the tiny fee on the right), which makes one side visibly
        // thicker at the seam. So the space for the weights is reduced by both
        // overhangs; the drawn trunk then measures exactly `trunkH` on both sides
        // and the seam lines up.
        var ueOben = Math.max(0, (out[0].thick - out[0].weight) / 2);
        var letzt = out[out.length - 1];
        var ueUnten = Math.max(0, (letzt.thick - letzt.weight) / 2);
        var k = root.trunkH > 0
            ? Math.max(0.2, (root.trunkH - ueOben - ueUnten) / root.trunkH) : 1;
        var trunkTop = root.padY + (root.innerH - root.trunkH) / 2 + ueOben;
        var acc = 0;
        for (i = 0; i < out.length; i++) {
            var anteil = out[i].weight * k;
            out[i].hMid = out[i].thick;
            out[i].midY = trunkTop + acc + anteil / 2 - out[i].thick / 2;
            acc += anteil;
        }

        // --- Position at the edge: by thickness, with gaps ---------------------
        var nGaps = Math.max(0, out.length - 1);
        var gap = nGaps > 0 ? Math.max(0, (root.innerH - sumThick) / nGaps) : 0;
        var ey = nGaps > 0 ? root.padY : root.padY + (root.innerH - sumThick) / 2;
        for (i = 0; i < out.length; i++) {
            out[i].hEdge = out[i].thick;
            out[i].edgeY = ey;
            ey += out[i].thick + gap;
        }
        return out;
    }

    function rebuild() {
        var gesamt = root.summeEin();
        if (width <= 0 || height <= 0 || gesamt <= 0) {
            bandsIn = [];
            bandsOut = [];
            canvas.requestPaint();
            return;
        }
        // Both sides use the same total (the fee counts as an output), so they
        // produce the same trunk and meet exactly in the middle.
        bandsIn = build(vin || [], function (e) {
            return (e.prevout && e.prevout.value) || 0;
        }, gesamt);
        var bo = build(root.voutMitGebuehr(), function (e) {
            return e.value || 0;
        }, gesamt);
        if (fee > 0 && bo.length)
            bo[0].fee = true;
        bandsOut = bo;
        canvas.requestPaint();
    }

    Canvas {
        id: canvas

        anchors.fill: parent

        // S-curve that starts and ends horizontally: flat at both ends, the swing
        // in between.
        function curve(ctx, x0, y0, x1, y1) {
            var d = (x1 - x0) * root.swing;
            ctx.bezierCurveTo(x0 + d, y0, x1 - d, y1, x1, y1);
        }

        // A chevron notch across the band, pointing right. Cut out
        // (`destination-out`) instead of painted, so it works on any band color or
        // gradient. The bands are far apart at this point, so nothing else is hit.
        function notch(ctx, x, cy, len, thickness) {
            if (len < 1.5 || thickness < 2)
                return;
            var alt = ctx.globalCompositeOperation;
            ctx.globalCompositeOperation = "destination-out";
            // In the original the notch is the gap between the block at the band
            // start and the band itself, so it grows with the thickness: about 8 %
            // of the band. A fixed cap of 2.5 px would leave only a hairline on a
            // thick band.
            var lw = Math.max(1, Math.min(10, thickness * 0.08));
            ctx.lineWidth = lw;
            ctx.lineJoin = "miter";
            ctx.strokeStyle = "#000000";
            // Extend past the band edge. A stroke ends square to its own direction,
            // which is diagonal here, so stopping exactly at the edge leaves a small
            // wedge of band color at the top and bottom. Both legs run past the edge
            // by their own width; nothing else is drawn there.
            var h = thickness / 2;
            var diag = Math.sqrt(len * len + h * h);
            var ux = (len / diag) * lw;
            var uy = (h / diag) * lw;
            ctx.beginPath();
            ctx.moveTo(x - ux, cy - h - uy);
            ctx.lineTo(x + len, cy);
            ctx.lineTo(x - ux, cy + h + uy);
            ctx.stroke();
            ctx.globalCompositeOperation = alt;
            ctx.lineJoin = "round";
        }

        // The short piece at the edge: full on one side, fading out on the other.
        // `nachAussenRechts` says which way it fades.
        //
        // `farbeBei` returns the color the band would have at that point, so the
        // gradient continues through the stub. A single fixed color leaves a hue
        // jump of more than ten degrees at the seam, because the band gradient
        // runs around the hue circle. The fade uses only alpha.
        function stub(ctx, x, len, cy, thickness, farbeBei, nachAussenRechts, lit) {
            if (len < 1 || thickness < 0.5)
                return;
            var g = ctx.createLinearGradient(x, 0, x + len, 0);
            for (var st = 0; st <= 4; st++) {
                var t = st / 4;
                var c = farbeBei(t);
                if (lit)
                    c = Qt.lighter(c, 1.35);
                g.addColorStop(t, Qt.rgba(c.r, c.g, c.b,
                                          nachAussenRechts ? 1 - t : t));
            }
            ctx.strokeStyle = g;
            ctx.lineWidth = thickness;
            ctx.beginPath();
            ctx.moveTo(x, cy);
            ctx.lineTo(x + len, cy);
            ctx.stroke();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.bandsIn.length)
                return;

            var w = width;
            // Left: stub, then the band with the notch.
            var xIn = root.stubLen;
            var xL = xIn + root.connector;
            var xC = w * 0.5;
            var xEnd = w - root.edgeMargin - root.stubLen;
            var xR = xEnd - root.connector;
            // The two sides meet in the middle with a little overlap so no seam
            // shows.
            var seam = 0.75;
            var i, b, lit, g, k, cEdge, cMid;

            // Drawn as strokes, not filled areas. Filling between two curves with the
            // same vertical distance makes a band thinner on steep parts: at a slope
            // of 60 degrees only half is left. A stroke has the same width everywhere.
            // The original does the same ("stroke-width: combinedWeight").
            ctx.lineCap = "butt";
            ctx.lineJoin = "round";

            for (i = 0; i < root.bandsIn.length; i++) {
                b = root.bandsIn[i];
                lit = root.hovered && root.hovered.side === "in" && root.hovered.index === b.i;
                g = ctx.createLinearGradient(0, 0, xC, 0);
                for (k = 0; k <= 4; k++) {
                    var ck = root.flowColor(k / 8);
                    var cl = lit ? Qt.lighter(ck, 1.35) : ck;
                    g.addColorStop(k / 4, Qt.rgba(cl.r, cl.g, cl.b, 1));
                }
                cEdge = b.edgeY + b.hEdge / 2;
                cMid = b.midY + b.hMid / 2;
                var head = root.headFor(b.hEdge);
                ctx.strokeStyle = g;
                ctx.lineWidth = b.hEdge;
                ctx.beginPath();
                // The band runs all the way to the edge. Starting it behind the notch
                // would leave a gap on both sides between the slanted notch edge and the
                // square end of the stroke.
                ctx.moveTo(xIn, cEdge);
                ctx.lineTo(xL, cEdge);
                canvas.curve(ctx, xL, cEdge, xC + seam, cMid);
                ctx.stroke();
                // The band gradient is `createLinearGradient(0, xC)` with
                // `flowColor(k/8)`, so at x the color is `flowColor(x / (2*xC))`.
                // This function continues exactly that into the stub.
                canvas.stub(ctx, 0, xIn + 0.5, cEdge, b.hEdge, function (t) {
                    return root.flowColor((t * xIn) / (2 * xC));
                }, false, lit);
                // The arrow is a notch cut out of the band, not an attached triangle,
                // so there is no seam and the direction stays readable.
                canvas.notch(ctx, xIn, cEdge, head, b.hEdge);
            }

            for (i = 0; i < root.bandsOut.length; i++) {
                b = root.bandsOut[i];
                lit = root.hovered && root.hovered.side === "out" && root.hovered.index === b.i;
                var col = b.fee ? root.feeColor : root.outColor;
                g = ctx.createLinearGradient(xC, 0, w, 0);
                if (b.fee) {
                    g.addColorStop(0, Qt.rgba(root.midColor.r, root.midColor.g, root.midColor.b, 1));
                    g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 1));
                } else {
                    for (k = 0; k <= 4; k++) {
                        var cq = root.flowColor(0.5 + k / 8);
                        var cr = lit ? Qt.lighter(cq, 1.35) : cq;
                        g.addColorStop(k / 4, Qt.rgba(cr.r, cr.g, cr.b, 1));
                    }
                }
                cEdge = b.edgeY + b.hEdge / 2;
                cMid = b.midY + b.hMid / 2;

                // No arrow tip. The band runs square into the block at the edge,
                // which follows directly and is separated only by the notch, as on
                // the left side.
                ctx.strokeStyle = g;
                ctx.lineWidth = b.hEdge;
                ctx.beginPath();
                ctx.moveTo(xC - seam, cMid);
                canvas.curve(ctx, xC - seam, cMid, xR, cEdge);
                ctx.lineTo(xEnd, cEdge);
                ctx.stroke();

                // Block first, then the notch: the notch cuts out what is already
                // drawn, so it has to come last or the block fills it again.
                canvas.stub(ctx, xEnd - 0.5, root.stubLen + 0.5, cEdge, b.hEdge,
                            b.fee ? function () {
                                return root.feeColor;
                            } : function (t) {
                                // Counterpart to the input side: the band gradient
                                // runs from xC to w over flowColor(0.5..1).
                                return root.flowColor(0.5 + 0.5 * (xEnd - xC + t * root.stubLen)
                                                            / (w - xC));
                            }, true, lit);
                // The notch sits on the seam: legs at the band's edge, tip in the
                // block. Same as on the input side.
                canvas.notch(ctx, xEnd, cEdge, root.tipFor(b.hEdge), b.hEdge);
            }

            if (root.fee > 0 && root.bandsOut.length) {
                var fb = root.bandsOut[0];
                ctx.font = root.labelSize + "px " + Fonts.sansCss();
                ctx.fillStyle = root.dimColor;
                ctx.textAlign = "right";
                var ty = fb.edgeY - root.labelSize * 0.45;
                if (ty < root.labelSize)
                    ty = fb.edgeY + fb.hEdge + root.labelSize;
                ctx.fillText(Tr.t("flow.fee", root.lang, root.fee), w - root.edgeMargin, ty);
            }
        }
    }

    function bandAt(px, py) {
        var side = px < width * 0.5 ? "in" : "out";
        var list = side === "in" ? bandsIn : bandsOut;
        var edge = side === "in" ? px < width * 0.25 : px > width * 0.75;
        for (var i = 0; i < list.length; i++) {
            var b = list[i];
            var y0 = edge ? b.edgeY : b.midY;
            var y1 = y0 + (edge ? b.hEdge : b.hMid);
            if (py >= y0 && py <= y1)
                return { "side": b.fee ? "fee" : side, "index": b.i,
                         "value": b.v, "more": b.more, "edge": edge };
        }
        return null;
    }

    // Address for a band. It belongs to the band at the edge and in the
    // trunk alike; in the trunk the transaction id is shown above it.
    function addrFor(hv) {
        if (!hv || hv.index < 0)
            return "";
        var e;
        if (hv.side === "in") {
            e = (root.vin || [])[hv.index];
            return (e && e.prevout && e.prevout.scriptpubkey_address) || "";
        }
        if (hv.side === "out") {
            e = root.voutMitGebuehr()[hv.index];
            return (e && e.scriptpubkey_address) || "";
        }
        return "";
    }

    function titleFor(hv) {
        if (!hv)
            return "";
        if (hv.side === "fee")
            return Tr.t("flow.fee", root.lang, root.fee);
        if (hv.more)
            return Tr.t("flow.more", root.lang, hv.more);
        var n = hv.index + (hv.side === "out" && root.fee > 0 ? 0 : 1);
        return Tr.t(hv.side === "in" ? "flow.in" : "flow.out", root.lang, n);
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onPositionChanged: mouse => {
            root.zeigerX = mouse.x;
            root.zeigerY = mouse.y;
            var b = root.bandAt(mouse.x, mouse.y);
            if (JSON.stringify(b) !== JSON.stringify(root.hovered)) {
                root.hovered = b;
                canvas.requestPaint();
            }
        }
        onExited: {
            root.hovered = null;
            canvas.requestPaint();
        }
        onClicked: {
            if (!root.hovered || root.hovered.side === "fee" || root.hovered.index < 0)
                return;
            // The fee comes first in the list, so real output indices are
            // shifted by one.
            var idx = root.hovered.index;
            if (root.hovered.side === "out" && root.fee > 0)
                idx -= 1;
            if (idx >= 0)
                root.activated(root.hovered.side, idx);
        }
    }

    // Tooltip at the pointer. Same order as the original: transaction (trunk
    // only), which input or output, the amount, and the address.
    Rectangle {
        id: tip

        readonly property bool imStrang: root.hovered !== null && !root.hovered.edge
        readonly property string adresse: root.addrFor(root.hovered)

        visible: root.hovered !== null
        width: tipInhalt.width + root.labelSize * 1.6
        height: tipInhalt.height + root.labelSize * 1.1
        radius: root.labelSize * 0.4
        color: Qt.rgba(0.05, 0.05, 0.08, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 10
        // Below right of the pointer if it fits, otherwise flipped to the other
        // side so it stays inside the area.
        x: Math.max(0, Math.min(root.width - width, root.zeigerX + root.labelSize))
        y: Math.max(0, Math.min(root.height - height, root.zeigerY + root.labelSize * 0.8))

        Column {
            id: tipInhalt

            anchors.centerIn: parent
            spacing: root.labelSize * 0.25

            Text {
                visible: tip.imStrang && root.txid !== ""
                width: Math.min(root.width * 0.6, implicitWidth)
                elide: Text.ElideMiddle
                text: Tr.t("flow.tx", root.lang) + "  " + root.txid
                color: root.dimColor
                font.pixelSize: root.labelSize * 0.92
                font.family: Fonts.mono()
            }

            Text {
                text: root.titleFor(root.hovered)
                color: root.textColor
                font.pixelSize: root.labelSize
            }

            Text {
                text: root.btcZeichen + " " + Tr.fixed((root.hovered ? root.hovered.value : 0) / 1e8,
                                           8, root.lang)
                color: root.textColor
                font.pixelSize: root.labelSize
            }

            Text {
                visible: tip.adresse !== ""
                width: Math.min(root.width * 0.6, implicitWidth)
                elide: Text.ElideMiddle
                text: tip.adresse
                color: root.dimColor
                font.pixelSize: root.labelSize * 0.92
                font.family: Fonts.mono()
            }
        }
    }
}
