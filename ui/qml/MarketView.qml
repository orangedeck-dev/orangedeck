// Market view: candles built from trades on several exchanges, volume below.
//
// Inspired by aggr.trade. Only the idea is taken from it, no code: aggr is
// GPL-3.0, this repo is MIT. The exchange APIs belong to nobody.
//
// Aggregation happens in the service: it keeps one-second buckets and merges
// them into the requested interval on each query. At most 400 finished
// candles arrive here, never single trades. A busy market sends hundreds per
// second, which is exactly the scale where CPU time has blown up in this
// program before.
//
// Only `import QtQuick`, so this also runs on Android.
// Bound: the delegates and `EigenFeld` access `root`. Without the pragma,
// ids from the enclosing component are not guaranteed to be visible there
// (qmllint warns about it). The delegates declare `modelData` as `required`
// anyway.
pragma ComponentBehavior: Bound

import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    property string lang: "de"
    property string currency: "usd"
    // Range: 1h | 12h | 24h | 7d | 30d | 1y | all | custom. The host owns it,
    // as well as the chart kind and the custom range.
    property string range: "24h"
    property string kind: "candles"      // candles | line
    // What sits below the price: volume bars or the CVD.
    property string lower: "volume"      // volume | cvd
    // Which sub-tab is open. Liquidations are organised by price, not by
    // time: a horizontal bar at a price level fits no panel that runs left
    // to right. So they get their own area instead of another lane below
    // the price.
    property string sub: "price"         // price | liq | heat
    property int customSecs: 259200      // three days by default
    // Crosshair and running tape, both optional
    property bool crosshair: true
    property bool showTape: true
    property bool live: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property color panelColor: "#16161f"
    property real baseFont: 12

    readonly property string zeichen: Money.symbol(root.currency)
    readonly property color upColor: "#5cb946"
    readonly property color downColor: "#d33f3f"

    signal rangeRequested(string r)
    signal kindRequested(string k)
    signal customSecsRequested(int secs)
    signal lowerRequested(string l)
    signal subRequested(string t)
    // From and to are sent back as a pair. Separately they would be
    // inconsistent in between (a from without a to is no window).
    signal vonBisRequested(int von, int bis)

    readonly property var zeitraeume: [
        { "k": "1h", "l": Tr.t("market.1h", root.lang) },
        { "k": "12h", "l": Tr.t("market.12h", root.lang) },
        { "k": "24h", "l": Tr.t("market.24h", root.lang) },
        { "k": "7d", "l": Tr.t("market.7d", root.lang) },
        { "k": "30d", "l": Tr.t("market.30d", root.lang) },
        { "k": "1y", "l": Tr.t("market.1y", root.lang) },
        { "k": "all", "l": Tr.t("market.all", root.lang) },
        { "k": "custom", "l": Tr.t("market.custom", root.lang) }
    ]

    readonly property var darstellungen: [
        { "k": "candles", "l": Tr.t("market.candles", root.lang) },
        { "k": "line", "l": Tr.t("market.line", root.lang) }
    ]

    readonly property var unterarten: [
        { "k": "volume", "l": Tr.t("market.volume", root.lang) },
        { "k": "cvd", "l": Tr.t("market.cvd", root.lang) }
    ]

    property var kerzen: []
    property var quellen: []
    // Liquidations and positioning, see MarketLiq.qml
    property var liqHist: []
    property var ratio: []
    property int liqSeit: 0
    // Per source {id, name, online, since}; `since` only in the direct feed
    property var liqQuellen: []
    // The heatmap has its own path and is not polled every second: it is
    // computed, not observed, and only changes with open interest, which
    // Binance updates every five minutes.
    property var heat: ({})

    function heatHolen() {
        if (!root.feed || !root.live || root.sub !== "heat")
            return;
        var pfad = "/market/heatmap?range=" + root.range
                 + (root.range === "custom" ? "&secs=" + root.sichtSekunden : "")
                 + "&cur=" + root.currency;
        root.feed.getJson(pfad, function (d, err) {
            if (err || !d) {
                // Retry soon rather than in a minute, otherwise the view
                // stays empty on open when Binance Futures is slow.
                heatNochmal.restart();
                return;
            }
            heatNochmal.stop();
            root.heat = d;
        });
    }

    Timer {
        id: heatNochmal

        interval: 10000
        onTriggered: root.heatHolen()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.live && root.visible && root.sub === "heat"
        triggeredOnStart: true
        onTriggered: root.heatHolen()
    }

    onSubChanged: if (root.sub === "heat") root.heatHolen()
    property int tradeZahl: 0
    // True when the candles are converted from dollars. Over years that is
    // a conversion at today's rate, not the real price.
    property bool umgerechnet: false
    property string fehler: ""
    // The tape: only what came after `bandNr` is fetched and appended.
    property var band: []
    property int bandNr: 0
    // Newest trade on top. Reversed once instead of computed per row.
    readonly property var bandUmgekehrt: root.band.slice().reverse()
    // Which candle is under the pointer, and where the pointer is
    property int zeiger: -1
    property real zeigerY: 0

    // ---------------------------------------------------------------- zoom
    // Draw immediately, fetch later. Querying on every wheel step made the
    // service pick a new interval and maybe fetch from the exchange, and the
    // image came back out of step with the movement, so it stuttered. The
    // view now zooms instantly into the candles it already has and only
    // asks again once the hand stops. Then the matching interval arrives and
    // `zoomSekunden` is cleared.
    property int zoomSekunden: 0
    property bool zoomAusstehend: false

    // ------------------------------------------------- window in time
    // 0 means "up to now". That is the normal case; anything else is a
    // window in the past. Dragging and the slider move it, the length stays.
    property int fensterEnde: 0
    // Explicit from..to window. When set, neither range nor window end apply.
    //
    // The host owns it, like range and chart kind: a typed
    // "01.01.2021..31.03.2021" is intentional and should survive a restart.
    // So it is read-only here: it changes through `vonBisRequested` and comes
    // back from the host. The window end from slider and drag stays
    // transient, after a restart people want to see the present.
    property int vonZeit: 0
    property int bisZeit: 0
    // While dragging: how many pixels the image is shifted
    property real ziehVersatz: 0

    // ------------------------------------------------------- overview
    // The whole history as daily candles, fetched once. Measured reason: a
    // fresh window costs 1.1 to 1.5 seconds because the service asks
    // Binance for it (4 ms when cached). On the slider ten pixels are
    // quickly a hundred days, so while dragging every position would be a
    // new window and the image would stand still.
    //
    // So while dragging, the image is drawn from these ~3,300 candles:
    // coarse, but instant and available anywhere since 2017. The exact
    // window arrives when the hand lets go.
    property var uebersicht: []
    property bool vorschau: false
    // A single day cannot fill a 24-hour window. If the range is too short
    // for a picture, the preview shows the surroundings, better the area
    // than an empty panel. From a two-month window upwards this is not
    // needed, the preview matches what comes afterwards.
    readonly property int vorschauMindest: 60 * 86400

    // Binance listed BTCUSDT on 2017-07-31, there is nothing earlier.
    readonly property int beginn: 1501459200
    readonly property int jetzt: Math.round(Date.now() / 1000)
    readonly property int endeEffektiv: root.fensterEnde > 0 ? root.fensterEnde : root.jetzt
    readonly property bool inVergangenheit: root.fensterEnde > 0 || root.bisZeit > 0

    // The value alone, no side effects. 0 still means "up to now".
    function fensterWert(ende) {
        var min = root.beginn + root.sichtSekunden;
        var max = root.jetzt;
        var e = Math.round(Math.max(min, Math.min(max, ende)));
        return (e >= max - 60) ? 0 : e;
    }

    function fensterSetzen(ende) {
        root.fensterEnde = root.fensterWert(ende);
        root.vonBisLoeschen();
        nachfassen.restart();
    }

    // While the slider is dragged: only remember the position, do not
    // reload. The image comes from the overview meanwhile and follows the
    // hand without delay.
    function fensterSchieben(ende) {
        root.fensterEnde = root.fensterWert(ende);
    }

    // Do not reset it here: the window belongs to the host. If the view
    // cleared it itself, it would hold a different value than the settings,
    // and the next read from there would bring the cleared window back.
    function vonBisLoeschen() {
        if (root.vonZeit || root.bisZeit)
            root.vonBisRequested(0, 0);
    }

    function zurueckZurGegenwart() {
        root.fensterEnde = 0;
        if (root.vonZeit || root.bisZeit) {
            // Comes back through the host; the change then triggers a fetch.
            root.vonBisRequested(0, 0);
            return;
        }
        root.holen();
    }

    readonly property int sichtSekunden: root.zoomSekunden > 0
        ? root.zoomSekunden
        : (root.range === "custom" ? root.customSecs : root.sekundenVon(root.range))

    // The overview slice that matches the dragged target.
    readonly property var vorschauKerzen: {
        var u = root.uebersicht;
        if (!u.length)
            return root.kerzen;
        var ende = root.endeEffektiv;
        var spanne = Math.max(root.sichtSekunden, root.vorschauMindest);
        var von = ende - spanne;
        var aus = [];
        for (var i = 0; i < u.length; i++) {
            if (u[i][0] >= von && u[i][0] <= ende)
                aus.push(u[i]);
        }
        return aus.length >= 3 ? aus : root.kerzen;
    }

    // Always a slice of the fetched candles, the window (end - span, end].
    // `holen()` also requests a reserve next to it: while dragging, real
    // candles move in from it instead of an empty area appearing, and after
    // release the new window is there immediately instead of jumping back to
    // the old state until the response arrives. `ab` is the start of the
    // window in `kerzen`, -1 means no reserve.
    readonly property var sichtInfo: {
        // Dragging the slider: from the overview, without a single request.
        if (root.vorschau)
            return root.gebuendelt(-1, root.vorschauKerzen);
        var k = root.kerzen;
        if (!k.length)
            return root.gebuendelt(-1, k);
        // A typed from..to is exactly what was fetched
        if (root.vonZeit && root.bisZeit && root.zoomSekunden <= 0)
            return root.gebuendelt(0, k);
        var letzte = k[k.length - 1][0];
        var bis = root.fensterEnde > 0 ? Math.min(letzte, root.fensterEnde) : letzte;
        var von = bis - root.sichtSekunden;
        var ab = -1;
        var aus = [];
        for (var i = 0; i < k.length; i++) {
            if (k[i][0] > von && k[i][0] <= bis) {
                if (ab < 0)
                    ab = i;
                aus.push(k[i]);
            }
        }
        // Below three candles nothing is visible, so show everything
        // until the matching interval arrives.
        return aus.length >= 3 ? root.gebuendelt(ab, aus) : root.gebuendelt(0, k);
    }
    readonly property var sicht: root.sichtInfo.liste
    readonly property int sichtAb: root.sichtInfo.ab
    // Where neighbours come from while dragging, bundled like `sicht`
    readonly property var sichtQuelle: root.sichtInfo.quelle

    // Candles that are too narrow get merged, not turned into a line. The
    // service picks the interval from the query length, and with the reserve
    // the present asks for 1.5 times the span and the past up to double. So
    // switching to a line below a width threshold made the chart flip
    // between candles and line while panning. On 310 px, 400 candles are too
    // fine anyway.
    //
    // Every `g` candles become one: open of the first, close of the last,
    // high and low over all, volume summed, until each is at least three
    // pixels wide. Groups end at the right edge of the window so the newest
    // candle keeps updating live, and the reserve is bundled with the same
    // boundaries so nothing jumps while dragging. The line stays unbundled,
    // every point counts there.
    function gebuendelt(ab, liste) {
        var n = liste.length;
        var roh = ab >= 0 ? root.kerzen : liste;
        // Not `feldBreite`: it subtracts `padR`, which measures the highest
        // price of the visible candles, a cycle through `sicht`. The canvas
        // minus an axis margin is accurate enough for "how many fit".
        var platz = Math.max(1, leinwand.width - root.baseFont * 4);
        var g = root.kind === "candles" && n >= 3
                ? Math.max(1, Math.ceil(n * 3 / platz)) : 1;
        if (g <= 1)
            return { "ab": ab, "liste": liste, "quelle": roh };
        if (ab < 0) {
            var nur = root.buendeln(liste, g, n % g);
            return { "ab": -1, "liste": nur, "quelle": nur };
        }
        var ende = ab + n;                  // past the window, in `kerzen`
        var rest = ende % g;
        var alle = root.buendeln(root.kerzen, g, rest);
        var erste = rest > 0 ? rest : g;
        var gruppeEnde = (ende - 1) < erste ? 0 : 1 + Math.floor((ende - 1 - erste) / g);
        var ganze = Math.max(1, Math.floor(n / g));
        var start = Math.max(0, gruppeEnde - ganze + 1);
        return { "ab": start, "liste": alle.slice(start, gruppeEnde + 1), "quelle": alle };
    }

    // Merge every `g` candles into one; the first group takes `rest` (0 means full)
    function buendeln(liste, g, rest) {
        var aus = [];
        var i = 0;
        while (i < liste.length) {
            var groesse = (aus.length === 0 && rest > 0) ? rest : g;
            var bis = Math.min(liste.length, i + groesse);
            var k0 = liste[i];
            var hoch = k0[2], tief = k0[3], kauf = 0, verkauf = 0, getrennt = true;
            for (var j = i; j < bis; j++) {
                var k = liste[j];
                hoch = Math.max(hoch, k[2]);
                tief = Math.min(tief, k[3]);
                kauf += k[5] || 0;
                if (k.length > 6)
                    verkauf += k[6];
                else
                    getrennt = false;
            }
            aus.push(getrennt ? [k0[0], k0[1], hoch, tief, liste[bis - 1][4], kauf, verkauf]
                              : [k0[0], k0[1], hoch, tief, liste[bis - 1][4], kauf]);
            i = bis;
        }
        return aus;
    }

    function zoomen(faktor) {
        root.zoomAuf(root.sichtSekunden * faktor);
    }

    // Absolute span. Pinch zoom computes from the state at touch-down, not
    // step by step, otherwise every rounding error would accumulate.
    function zoomAuf(sekunden) {
        root.zoomSekunden = Math.round(Math.max(300, Math.min(400000000, sekunden)));
        root.zoomAusstehend = true;
        nachfassen.restart();
        leinwand.requestPaint();
    }

    Timer {
        id: nachfassen

        interval: 250
        onTriggered: {
            if (root.zoomAusstehend) {
                root.zoomAusstehend = false;
                if (root.range !== "custom")
                    root.rangeRequested("custom");
                root.customSecsRequested(root.zoomSekunden);
            } else {
                root.holen();
            }
        }
    }

    readonly property real hoch: {
        var m = -Infinity;
        for (var i = 0; i < root.sicht.length; i++)
            m = Math.max(m, root.sicht[i][2]);
        return m === -Infinity ? 0 : m;
    }
    readonly property real tief: {
        var m = Infinity;
        for (var i = 0; i < root.sicht.length; i++)
            m = Math.min(m, root.sicht[i][3]);
        return m === Infinity ? 0 : m;
    }
    // Exchange candles carry one volume, the service's live buckets carry two
    // (buy and sell separately). Both shapes arrive here.
    function volumen(k) {
        return k.length > 6 ? k[5] + k[6] : (k[5] || 0);
    }

    readonly property real maxVol: {
        var m = 0;
        for (var i = 0; i < root.sicht.length; i++)
            m = Math.max(m, root.volumen(root.sicht[i]));
        return m;
    }
    readonly property real letzterPreis: root.sicht.length
                                         ? root.sicht[root.sicht.length - 1][4] : 0

    // ------------------------------------------------------------- CVD
    // Buys minus sells, cumulated. It answers the question a candle leaves
    // open: who moved the price. If the price rises while the CVD falls,
    // nobody is buying, there is just less selling.
    //
    // Cumulated over the visible window, starting at zero. An absolute level
    // would mean nothing: the series starts where the exchange's candles
    // start, and nobody reads a value from 2017. Comparisons are always
    // within the picture.
    readonly property var cvd: {
        var aus = [];
        var summe = 0;
        for (var i = 0; i < root.sicht.length; i++) {
            var k = root.sicht[i];
            summe += (k[5] || 0) - (k[6] || 0);
            aus.push(summe);
        }
        return aus;
    }

    // Zero always stays in view. Without it a falling series in the upper
    // third looks like a surplus.
    readonly property real cvdTief: {
        var m = 0;
        for (var i = 0; i < root.cvd.length; i++)
            m = Math.min(m, root.cvd[i]);
        return m;
    }
    readonly property real cvdHoch: {
        var m = 0;
        for (var i = 0; i < root.cvd.length; i++)
            m = Math.max(m, root.cvd[i]);
        return m;
    }

    // ------------------------------------------------------------ geometry
    // Computed once, used three times: by the canvas, the crosshair and the
    // pointer readout. Inside the paint block the crosshair would have to
    // compute it a second time, and sooner or later differently.
    readonly property real padR: mass.implicitWidth + 10
    readonly property real padB: root.baseFont * 1.4
    // No tape while the chart shows the past. The tape is live; next to
    // candles from half a year ago it would show today's prices, with the
    // header showing one value and the tape another. Two conflicting values
    // are worse than a missing one.
    // Everything tied to the price chart disappears in the liquidation tab:
    // tape, slider, crosshair. They refer to a time axis that is not there.
    readonly property bool bandDa: root.showTape && !root.inVergangenheit
                                   && root.sub === "price"
    readonly property real bandHoehe: root.bandDa
                                      ? Math.min(root.height * 0.28, root.baseFont * 11)
                                      : 0
    // The slider below the time axis. Dropped in very short panels, where
    // the curve itself is already cramped.
    readonly property bool schieberDa: root.height >= 260 && root.sub === "price"

    // ----------------------------------------------------- header space
    // The sub-tabs push the header to the right, and in the popout the
    // controls overlapped: price over trade count over "Binance". The row
    // cannot get narrower, so something has to give, in order of how
    // dispensable it is.
    //
    // The price always stays. Then the exchange dots go, then the trade
    // count, then the two chart toggles. The range picker stays, without it
    // the tab is no longer usable.
    readonly property bool platzQuellen: root.width > root.baseFont * 66
    readonly property bool platzTrades: root.width > root.baseFont * 56
    // On a phone the header does not fit on one row, and the price got cut
    // off between sub-tabs and range picker (the `clip` below prevents
    // overlap, not truncation). If tabs, price and picker do not fit side by
    // side, the price row moves below the tabs.
    // Without room for the toggles the price always wraps; the two short
    // buttons (`kurzwahl`) then sit to the right of the price.
    readonly property bool kopfUmbruch: (root.sub === "price" && !root.platzUmschalter)
                                        || unterreiter.width + root.baseFont * 2.0
                                        + preisText.implicitWidth + wahl.width > root.width
    // Where content below the header starts. Computed in one place because
    // four panels depend on it.
    readonly property real kopfHoehe: root.kopfUmbruch
                                      ? Math.max(unterreiter.height, wahl.height)
                                        + Math.max(kopf.height, kurzwahl.visible ? kurzwahl.height : 0)
                                      : Math.max(kopf.height, wahl.height)
    readonly property bool platzUmschalter: root.width > root.baseFont * 44
    readonly property real schieberHoehe: root.schieberDa ? root.baseFont * 1.7 : 0
    readonly property real feldBreite: Math.max(1, leinwand.width - root.padR)
    readonly property real volHoehe: (leinwand.height - root.padB) * 0.26
    readonly property real preisHoehe: leinwand.height - root.padB - root.volHoehe
                                       - root.baseFont * 0.4
    readonly property real padT: root.baseFont * 0.2
    readonly property real spanne: {
        var d = root.hoch - root.tief;
        return d > 0 ? d : Math.max(1, root.hoch * 0.0002);
    }
    // What is actually in the picture, not what is selected. In the preview
    // that is two months even though the window is set to 24 hours, and the
    // time axis has to follow it, otherwise clock times end up under a
    // two-month picture.
    readonly property real gezeigteSekunden: root.sicht.length > 1
        ? Math.max(1, root.sicht[root.sicht.length - 1][0] - root.sicht[0][0])
        : root.sichtSekunden

    readonly property real kerzeBreite: root.sicht.length
                                        ? root.feldBreite / root.sicht.length : 1

    function yPreis(v) {
        return root.padT + root.preisHoehe * (1 - (v - root.tief) / root.spanne);
    }

    function preisBei(y) {
        return root.tief + root.spanne * (1 - (y - root.padT) / root.preisHoehe);
    }

    function indexBei(x) {
        if (!root.sicht.length)
            return -1;
        var i = Math.floor(x / root.kerzeBreite);
        return Math.max(0, Math.min(root.sicht.length - 1, i));
    }

    // Once per currency. The first fetch costs the service about six
    // seconds (four pages at Binance), after that milliseconds, it caches
    // for half an hour. Until it arrives the slider behaves as without it.
    property string uebersichtFuer: ""

    function uebersichtHolen() {
        if (!root.feed || !root.live)
            return;
        if (root.uebersichtFuer === root.currency)
            return;
        var fuer = root.currency;
        root.uebersichtFuer = fuer;
        root.feed.getJson("/market/overview?cur=" + fuer, function (d, err) {
            if (err || !d || !(d.candles || []).length) {
                // Do not keep it marked, try again next time
                if (root.uebersichtFuer === fuer)
                    root.uebersichtFuer = "";
                return;
            }
            root.uebersicht = d.candles;
        });
    }

    // With reserve. Live, half a window extra on the left; in the past also
    // up to half a window on the right. Sent as `range=custom&secs=` without
    // a moving `to=now`: the request goes out every second, and a value that
    // changes every second would be a new fetch at the exchange each time.
    // For 1h to 30d, 1.5 times the span stays in the same interval as the
    // window itself. No reserve for "all", anything from 200 days up (the
    // interval would get coarser there) and a typed from..to.
    function holen() {
        if (!root.feed || !root.live)
            return;
        var s = root.sichtSekunden;
        var fenster;
        if (root.vonZeit && root.bisZeit) {
            fenster = "range=" + root.range
                    + (root.range === "custom" ? "&secs=" + root.customSecs : "")
                    + "&from=" + root.vonZeit + "&to=" + root.bisZeit;
        } else if (root.range === "all" || s >= 200 * 86400) {
            fenster = "range=" + root.range
                    + (root.range === "custom" ? "&secs=" + root.customSecs : "")
                    + (root.fensterEnde ? "&to=" + root.fensterEnde : "");
        } else if (root.fensterEnde) {
            var rechts = Math.min(Math.round(s * 0.5),
                                  Math.max(0, Math.round(Date.now() / 1000) - root.fensterEnde));
            fenster = "range=custom&secs=" + Math.round(s * 1.5 + rechts)
                    + "&to=" + (root.fensterEnde + rechts);
        } else {
            fenster = "range=custom&secs=" + Math.round(s * 1.5);
        }
        var pfad = "/market?" + fenster
                 + "&tape=" + root.bandNr
                 + "&cur=" + root.currency;
        root.feed.getJson(pfad, function (d, err) {
            if (err || !d) {
                root.fehler = err || "nicht erreichbar";
                return;
            }
            root.fehler = "";
            root.kerzen = d.candles || [];
            // The fetched candles are now exactly the requested slice,
            // cropping further would be redundant. Only during an ongoing
            // gesture does the local zoom stay.
            if (!root.zoomAusstehend)
                root.zoomSekunden = 0;
            root.quellen = d.sources || [];
            root.liqHist = d.liqHist || [];
            root.ratio = d.ratio || [];
            root.liqSeit = d.liqSince || 0;
            root.liqQuellen = d.liqSources || [];
            root.tradeZahl = d.trades || 0;
            root.umgerechnet = d.converted === true;
            // Only append what is new and trim the front. Since `bandNr`
            // the service only sends what was added anyway.
            if ((d.tape || []).length) {
                var neu = root.band.concat(d.tape);
                root.band = neu.slice(-60);
                root.bandNr = d.tapeLast || root.bandNr;
            }
            leinwand.requestPaint();
        });
    }

    onRangeChanged: root.holen()
    onCurrencyChanged: {
        // Tape prices are in the old currency. Left in place they would
        // sit next to the new candles and nobody would notice the mismatch.
        root.band = [];
        root.bandNr = 0;
        // The overview carries prices too: in another currency it is a
        // different series and gets fetched again.
        root.uebersichtFuer = "";
        root.holen();
        root.uebersichtHolen();
    }
    onCustomSecsChanged: if (root.range === "custom") root.holen()
    // From and to come back from the host as two assignments. `nachfassen`
    // merges them into one request, otherwise one with half a window would
    // go out in between.
    onVonZeitChanged: nachfassen.restart()
    onBisZeitChanged: nachfassen.restart()
    onLiveChanged: {
        if (root.live) {
            root.holen();
            root.uebersichtHolen();
        }
    }
    Component.onCompleted: {
        root.holen();
        root.uebersichtHolen();
    }

    // Every request keeps the exchange streams in the service alive; after
    // two minutes without one it disconnects them. Nobody looking means no
    // requests from here either.
    Timer {
        interval: 1000
        repeat: true
        // A window in the past no longer changes, fetching it every second
        // would be pointless. The tape stops too; it shows the present, the
        // chart the past.
        running: root.live && root.visible && !root.inVergangenheit
        onTriggered: root.holen()
    }

    // ------------------------------------------------------------ header
    // The sub-tab switch sits before the price, where tabs belong, and costs
    // no extra row: in the popout 409 px of height is all there is.
    ViewTabs {
        id: unterreiter

        anchors.left: parent.left
        anchors.top: parent.top
        labels: [Tr.t("market.sub.price", root.lang),
                 Tr.t("market.sub.liq", root.lang),
                 Tr.t("market.sub.heat", root.lang)]
        current: root.sub === "liq" ? 1 : (root.sub === "heat" ? 2 : 0)
        fontSize: root.baseFont
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        z: 40
        onPicked: function (i) {
            root.subRequested(i === 1 ? "liq" : (i === 2 ? "heat" : "price"));
        }
    }

    Row {
        id: kopf

        anchors.left: root.kopfUmbruch ? parent.left : unterreiter.right
        anchors.leftMargin: root.kopfUmbruch ? 0 : root.baseFont * 1.4
        // A right anchor with `clip` as the last safeguard: whatever still
        // does not fit gets cut off instead of drawn on top of something.
        // Half a text is ugly, two overlapping texts are unreadable.
        anchors.right: root.kopfUmbruch ? (kurzwahl.visible ? kurzwahl.left : parent.right) : wahl.left
        anchors.rightMargin: root.kopfUmbruch && !kurzwahl.visible ? 0 : root.baseFont * 0.6
        anchors.top: parent.top
        anchors.topMargin: root.kopfUmbruch ? Math.max(unterreiter.height, wahl.height) : 0
        clip: true
        spacing: root.baseFont

        Text {
            id: preisText

            anchors.verticalCenter: parent.verticalCenter
            text: root.letzterPreis
                  ? Tr.price1(root.letzterPreis, root.zeichen, root.lang) : "–"
            color: root.textColor
            font.pixelSize: root.baseFont * 1.5
            font.weight: Font.DemiBold
        }

        // Under the pointer the candle, otherwise how many trades came
        // through. Not bottom right: there it collided with the time axis
        // label ("14:19:5553 Trades").
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.platzTrades && !root.zeigerDa && root.tradeZahl > 0
            text: Tr.t("market.trades", root.lang, Tr.group(root.tradeZahl, root.lang))
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }



        // When the window is in the past, a click goes back to now.
        // Without it, getting back after panning would be tedious.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.inVergangenheit
            width: heimText.implicitWidth + root.baseFont
            height: Math.round(root.baseFont * 1.7)
            radius: height / 2
            color: heimMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.width: 1
            border.color: root.accentColor

            Text {
                id: heimText

                anchors.centerIn: parent
                text: Tr.t("market.now", root.lang)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }

            MouseArea {
                id: heimMaus

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.zurueckZurGegenwart()
            }
        }

        // If the curve is in a currency other than the exchange's, it says
        // so: conversion uses today's rate, even for candles from 2017. Not
        // bottom left: the start of the time axis is there and the note sat
        // right on it.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.umgerechnet && root.sicht.length > 0
            text: Tr.t("price.converted", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            opacity: 0.8
        }

        // Which exchange is stalled. Without this a flat curve does not
        // tell whether the market is calm or the connection is gone.
        Repeater {
            model: root.platzQuellen ? root.quellen : []

            Row {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: parent.modelData.online ? root.upColor : root.downColor
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.name
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                }
            }
        }
    }

    Row {
        id: wahl

        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.baseFont * 0.5
        z: 50

        // Candles or line. Only here: the price chart in the clock cannot
        // show candles, the mempool.space series only has closing prices, no
        // high and low.
        TileGoggles {
            visible: root.sub === "price" && root.platzUmschalter
            anchors.verticalCenter: parent.verticalCenter
            width: root.baseFont * 9.5
            alignRight: true
            labelKey: ""
            modes: root.darstellungen
            mode: root.kind
            counts: []
            total: 0
            lang: root.lang
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            uiFont: root.baseFont
            onPicked: function (m) {
                root.kindRequested(m);
            }
        }

        // What sits below the price. A separate toggle instead of both
        // stacked: bars count up from zero, the CVD has zero in the middle.
        // Two scales in one panel are unreadable.
        TileGoggles {
            visible: root.sub === "price" && root.platzUmschalter
            anchors.verticalCenter: parent.verticalCenter
            width: root.baseFont * 8
            alignRight: true
            labelKey: ""
            modes: root.unterarten
            mode: root.lower
            counts: []
            total: 0
            lang: root.lang
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            uiFont: root.baseFont
            onPicked: function (m) {
                root.lowerRequested(m);
            }
        }

        // Custom range, up here only when there is room. On a phone the row
        // with the field ran left into the sub-tabs, so there it goes into
        // the second row.
        EigenFeld {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.range === "custom" && root.platzUmschalter
        }

        DropDown {
            anchors.verticalCenter: parent.verticalCenter
            // The bounds are the view, not the row. Otherwise the list
            // sticks to its row and draws past it unchecked; in the
            // dashboard tab it ended up beside the panel.
            bounds: root
            flaecheColor: root.panelColor
            model: root.zeitraeume
            current: root.range
            // On a phone, the value instead of "Custom range". The long text
            // made the picker so wide that it covered "Heatmap" in every
            // sub-tab. "3d" says more and needs no new translation.
            anzeige: (root.range === "custom" && !root.platzUmschalter)
                     ? ((root.vonZeit && root.bisZeit)
                        ? Qt.formatDateTime(new Date(root.vonZeit * 1000), Tr.datumOhneJahr(root.lang))
                          + "–" + Qt.formatDateTime(new Date(root.bisZeit * 1000), Tr.datumOhneJahr(root.lang))
                        : root.eigenText(root.customSecs))
                     : ""
            uiFont: root.baseFont
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            lineColor: root.lineColor
            onPicked: function (k) {
                // An explicit window overrides the range: if it stayed,
                // picking here would seem to do nothing.
                root.vonBisLoeschen();
                root.rangeRequested(k);
            }
        }
    }

    // Custom range: a number with a unit, e.g. "72h" or "90d". A calendar
    // with from and to would be a component of its own; typing is enough
    // here. A component because it can sit in two places: up next to the
    // picker, or on a phone in the second row.
    component EigenFeld: Rectangle {
        id: feld

        property real hoechstens: 100000

        width: Math.min(feld.hoechstens, (root.vonZeit && root.bisZeit) ? root.baseFont * 15
                                                                        : root.baseFont * 5)
        height: Math.round(root.baseFont * 2.0)
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: eingabe.activeFocus ? root.accentColor : root.lineColor
        clip: true

        TextInput {
            id: eingabe

            anchors.fill: parent
            anchors.leftMargin: root.baseFont * 0.7
            anchors.rightMargin: root.baseFont * 0.5
            verticalAlignment: TextInput.AlignVCenter
            color: root.textColor
            font.pixelSize: root.baseFont
            selectByMouse: true
            text: (root.vonZeit && root.bisZeit)
                  ? Qt.formatDateTime(new Date(root.vonZeit * 1000), Tr.datum(root.lang))
                    + ".." + Qt.formatDateTime(new Date(root.bisZeit * 1000), Tr.datum(root.lang))
                  : root.eigenText(root.customSecs)
            onAccepted: {
                // Two dots separate an explicit window:
                // "01.01.2021..31.03.2021". Without them it is a length
                // ending now.
                if (text.indexOf("..") >= 0) {
                    var teile = text.split("..");
                    var a = root.datumSekunden(teile[0]);
                    var b = root.datumSekunden(teile[1]);
                    if (a > 0 && b > a) {
                        root.fensterEnde = 0;
                        root.vonBisRequested(a, b);
                    }
                    return;
                }
                var sek = root.eigenSekunden(text);
                if (sek > 0) {
                    root.vonBisLoeschen();
                    root.customSecsRequested(sek);
                }
            }
        }
    }

    // "72h" -> 259200. Units: m minutes, h hours, d days, w weeks,
    // y years. Without a unit, days.
    function eigenSekunden(text) {
        var m = String(text).trim().toLowerCase().match(/^([0-9]+(?:[.,][0-9]+)?)\s*([mhdwy]?)$/);
        if (!m)
            return 0;
        var zahl = parseFloat(m[1].replace(",", "."));
        var faktor = { "m": 60, "h": 3600, "d": 86400, "w": 604800, "y": 31536000 };
        return Math.round(zahl * (faktor[m[2]] || 86400));
    }

    // "31.03.2021" or "2021-03-31" -> seconds. Without a time, start of day
    // in the local time zone.
    function datumSekunden(text) {
        var t = String(text).trim();
        var m = t.match(/^([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})$/);
        if (m)
            return Math.round(new Date(parseInt(m[3], 10), parseInt(m[2], 10) - 1,
                                       parseInt(m[1], 10)).getTime() / 1000);
        m = t.match(/^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$/);
        if (m)
            return Math.round(new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1,
                                       parseInt(m[3], 10)).getTime() / 1000);
        return 0;
    }

    // The field content has to be readable.
    //
    // The unit is picked by magnitude, not divisibility: the largest unit
    // that still leaves a whole number. When zooming no number is even, and
    // divisibility would give something like "12215m", correct but useless;
    // nobody converts that to eight and a half days. 36 hours reads better
    // than 1.5 days.
    //
    // Weeks are never used for output even though the field accepts them:
    // the view's ranges are 1h, 12h, 24h, 7d, 30d and 1y, there are no weeks
    // in that vocabulary, and "26w" next to "30d" would be two units for
    // the same scale. A typed "12w" is accepted and shown as "84d".
    //
    // The first threshold is just below an hour, not on it: otherwise a
    // span of 3599 seconds rounds to "60m" instead of "1h".
    function eigenText(sek) {
        if (sek < 3570)
            return root.rundText(sek / 60) + "m";
        if (sek < 86400 * 2)
            return root.rundText(sek / 3600) + "h";
        if (sek < 31536000)
            return root.rundText(sek / 86400) + "d";
        return root.rundText(sek / 31536000) + "y";
    }

    // Rounded coarsely so it looks clean: integer from ten up, one decimal
    // below that, dropped if it would be zero. Only the display is rounded,
    // the underlying value stays exact.
    function rundText(wert) {
        if (wert >= 10 || Math.abs(wert - Math.round(wert)) < 0.05)
            return Tr.group(Math.round(wert), root.lang);
        return Tr.fixed(wert, 1, root.lang);
    }

    // On a phone, one button per toggle. The two rows at the top need
    // `platzUmschalter`; without these buttons neither candles/line nor
    // volume/CVD could be picked on a phone. Each button shows the current
    // choice and cycles on tap.
    Row {
        id: kurzwahl

        visible: root.sub === "price" && !root.platzUmschalter
        anchors.right: parent.right
        anchors.verticalCenter: kopf.verticalCenter
        spacing: root.baseFont * 0.5
        z: 50

        // The custom range field when there is no room at the top. At most a
        // third of the width, otherwise a typed from..to is 210 px wide and
        // the price gets cut off. The text can be scrolled inside the field.
        //
        // Hidden in the past. There "Now" sits next to the price, and the row
        // is too short for field and button together. "Now" leads back and
        // matters more; the picker at the top shows the range anyway.
        EigenFeld {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.range === "custom" && !root.inVergangenheit
            hoechstens: root.width * 0.34
        }

        Repeater {
            model: [
                { "modes": root.darstellungen, "wert": root.kind, "art": "kind" },
                { "modes": root.unterarten, "wert": root.lower, "art": "lower" }
            ]

            Item {
                id: kurzknopf

                required property var modelData

                readonly property int stelle: {
                    var m = kurzknopf.modelData.modes;
                    for (var i = 0; i < m.length; i++) {
                        if (m[i].k === kurzknopf.modelData.wert)
                            return i;
                    }
                    return 0;
                }

                width: kurzText.implicitWidth + root.baseFont * 1.2
                height: kurzText.implicitHeight + root.baseFont * 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: root.accentColor
                }

                Text {
                    id: kurzText

                    anchors.centerIn: parent
                    text: kurzknopf.modelData.modes[kurzknopf.stelle].l
                    color: root.textColor
                    font.pixelSize: root.baseFont * 0.8
                }

                // Extend the tap area up and down to finger size
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -Math.max(0, (40 - kurzknopf.height) / 2)
                    anchors.bottomMargin: -Math.max(0, (40 - kurzknopf.height) / 2)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var m = kurzknopf.modelData.modes;
                        var naechste = m[(kurzknopf.stelle + 1) % m.length].k;
                        if (kurzknopf.modelData.art === "kind")
                            root.kindRequested(naechste);
                        else
                            root.lowerRequested(naechste);
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- candles
    Canvas {
        id: leinwand

        visible: root.sub === "price"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // The readout row keeps its space even when empty, otherwise the
        // chart jumps by one row height on every hover.
        anchors.topMargin: root.kopfHoehe
                           + root.baseFont * 0.25 + ablesen.implicitHeight
                           + root.baseFont * 0.35
        anchors.bottomMargin: root.bandHoehe + root.schieberHoehe
        antialiasing: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var n = root.sicht.length;
            if (n < 1)
                return;

            var breiteGesamt = root.feldBreite;
            var kerzeBreite = Math.max(1, root.kerzeBreite);
            var koerper = Math.max(1, Math.min(kerzeBreite * 0.7, kerzeBreite - 1));
            var preisHoehe = root.preisHoehe;
            var lo = root.tief, hi = root.hoch;
            var spanne = root.spanne;
            var padB = root.padB, volHoehe = root.volHoehe;

            function yPreis(v) {
                return root.yPreis(v);
            }

            // Horizontal grid lines and the price axis on the right
            ctx.strokeStyle = root.lineColor;
            ctx.fillStyle = root.dimColor;
            ctx.font = (root.baseFont - 2) + "px " + Fonts.sansCss();
            ctx.textAlign = "left";
            ctx.lineWidth = 1;
            for (var g = 0; g <= 4; g++) {
                var wert = lo + spanne * g / 4;
                var y = Math.round(yPreis(wert)) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(breiteGesamt, y);
                ctx.stroke();
                ctx.fillText(Tr.group(wert, root.lang), breiteGesamt + 6, y + 4);
            }

            var i, k, x, farbe, steigt;

            // While dragging only the data moves; neighbouring candles come
            // in from the reserve (see `sichtInfo`). What is missing there
            // has not been fetched yet and stays empty instead of being made
            // up. The `translate` comes after the grid: if price scale, lines
            // and time axis moved along, every swipe on a phone would look
            // like a picture change that does not happen. Clipping is at the
            // scale so candles do not run over their labels.
            ctx.save();
            ctx.beginPath();
            ctx.rect(0, 0, breiteGesamt, height - padB);
            ctx.clip();
            if (root.ziehVersatz !== 0)
                ctx.translate(root.ziehVersatz, 0);

            // ---- line instead of candles ----------------------------------
            // With nine years in one picture a candle is a stroke and the
            // line says more. With one hour it is the other way round.
            //
            // Width decides this, not whether it is a preview. If every
            // preview fell back to the line, dragging the slider would show a
            // line for the whole gesture even with candles selected, and the
            // picture would jump to another chart type on release. That jump
            // says nothing about the data.
            //
            // What really sets the preview apart is resolution: it draws daily
            // candles. Over sixty days that is sixty candles and a normal
            // picture; over nine years it is three thousand, each narrower
            // than a pixel. That is what the threshold measures, and it
            // applies to the settled picture too, since a candle less than
            // two and a half pixels wide shows neither wick nor body.
            //
            // The dimming still marks it as a preview.
            var alsLinie = root.kind === "line" || kerzeBreite < 2.5;
            if (root.vorschau)
                ctx.globalAlpha = 0.55;

            // While dragging, neighbours from the reserve move into view,
            // counted from the window start in `kerzen`. Without an offset
            // it is exactly the window.
            var quelle = root.sichtAb >= 0 ? root.sichtQuelle : root.sicht;
            var basis0 = root.sichtAb >= 0 ? root.sichtAb : 0;
            var extraL = root.ziehVersatz > 0 ? Math.ceil(root.ziehVersatz / kerzeBreite) + 1 : 0;
            var extraR = root.ziehVersatz < 0 ? Math.ceil(-root.ziehVersatz / kerzeBreite) + 1 : 0;
            var jVon = Math.max(0, basis0 - extraL);
            var jBis = Math.min(quelle.length - 1, basis0 + n - 1 + extraR);
            var j;

            if (alsLinie) {
                var g = ctx.createLinearGradient(0, root.padT, 0, root.padT + preisHoehe);
                g.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0.28));
                g.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.moveTo((jVon - basis0) * kerzeBreite + kerzeBreite / 2, root.padT + preisHoehe);
                for (j = jVon; j <= jBis; j++)
                    ctx.lineTo((j - basis0) * kerzeBreite + kerzeBreite / 2, yPreis(quelle[j][4]));
                ctx.lineTo((jBis - basis0) * kerzeBreite + kerzeBreite / 2,
                           root.padT + preisHoehe);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = root.accentColor;
                ctx.lineWidth = 1.6;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (j = jVon; j <= jBis; j++) {
                    var xl = (j - basis0) * kerzeBreite + kerzeBreite / 2;
                    if (j === jVon)
                        ctx.moveTo(xl, yPreis(quelle[j][4]));
                    else
                        ctx.lineTo(xl, yPreis(quelle[j][4]));
                }
                ctx.stroke();
            }

            // ---- candles ---------------------------------------------------
            for (j = jVon; j <= jBis; j++) {
                k = quelle[j];
                i = j - basis0;
                x = i * kerzeBreite + (kerzeBreite - koerper) / 2;
                steigt = k[4] >= k[1];
                farbe = steigt ? root.upColor : root.downColor;

                if (!alsLinie) {
                    var mitte = i * kerzeBreite + kerzeBreite / 2;

                    // Wick
                    ctx.strokeStyle = farbe;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(Math.round(mitte) + 0.5, yPreis(k[2]));
                    ctx.lineTo(Math.round(mitte) + 0.5, yPreis(k[3]));
                    ctx.stroke();

                    // Body, at least one pixel, otherwise a candle without
                    // movement disappears entirely
                    var yO = yPreis(Math.max(k[1], k[4]));
                    var yC = yPreis(Math.min(k[1], k[4]));
                    ctx.fillStyle = farbe;
                    ctx.fillRect(x, yO, koerper, Math.max(1, yC - yO));
                }

                // ---- volume below ---------------------------------------
                if (root.lower === "volume" && root.maxVol > 0) {
                    var basis = height - padB;
                    if (k.length > 6) {
                        // Live buckets: buy and sell stacked
                        // Clamped: the scale applies to the window, a
                        // neighbouring candle from the reserve can be larger
                        var hKauf = Math.min(volHoehe, volHoehe * (k[5] / root.maxVol));
                        var hVerk = Math.min(volHoehe - hKauf, volHoehe * (k[6] / root.maxVol));
                        ctx.fillStyle = root.upColor;
                        ctx.fillRect(x, basis - hKauf, koerper, hKauf);
                        ctx.fillStyle = root.downColor;
                        ctx.fillRect(x, basis - hKauf - hVerk, koerper, hVerk);
                    } else {
                        // Exchange candle: one volume, coloured by direction
                        var hVol = Math.min(volHoehe, volHoehe * (root.volumen(k) / root.maxVol));
                        ctx.fillStyle = farbe;
                        ctx.fillRect(x, basis - hVol, koerper, hVol);
                    }
                }
            }

            // ---- CVD instead of the bars -----------------------------------
            // After the loop: a line is not a sequence of bars, it needs all
            // points at once.
            if (root.lower === "cvd") {
                var cBasis = height - padB;
                var cLo = root.cvdTief, cHi = root.cvdHoch;
                var cSpanne = (cHi - cLo) || 1;

                function yCvd(v) {
                    return cBasis - volHoehe * (v - cLo) / cSpanne;
                }

                // Zero line first, it shows whether buyers or sellers
                // are ahead.
                var yNull = yCvd(0);
                ctx.strokeStyle = root.lineColor;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, Math.round(yNull) + 0.5);
                ctx.lineTo(breiteGesamt, Math.round(yNull) + 0.5);
                ctx.stroke();

                var letzterCvd = root.cvd.length ? root.cvd[root.cvd.length - 1] : 0;
                var cvdFarbe = letzterCvd >= 0 ? root.upColor : root.downColor;

                // Area between line and zero, so the direction is visible
                // at a glance
                ctx.beginPath();
                ctx.moveTo(kerzeBreite / 2, yNull);
                for (i = 0; i < n; i++)
                    ctx.lineTo(i * kerzeBreite + kerzeBreite / 2, yCvd(root.cvd[i]));
                ctx.lineTo((n - 1) * kerzeBreite + kerzeBreite / 2, yNull);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(cvdFarbe.r, cvdFarbe.g, cvdFarbe.b, 0.16);
                ctx.fill();

                ctx.strokeStyle = cvdFarbe;
                ctx.lineWidth = 1.4;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (i = 0; i < n; i++) {
                    var xc = i * kerzeBreite + kerzeBreite / 2;
                    if (i === 0)
                        ctx.moveTo(xc, yCvd(root.cvd[i]));
                    else
                        ctx.lineTo(xc, yCvd(root.cvd[i]));
                }
                ctx.stroke();
            }

            // Offset, clipping and preview dimming end here
            ctx.restore();

            // Time axis: start and end
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "left";
            ctx.fillText(root.uhrzeit(root.sicht[0][0]), 0, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.uhrzeit(root.sicht[n - 1][0]), breiteGesamt, height - 2);
        }
    }

    // For one day a date says nothing, for nine years a clock time says
    // nothing. But once a date is shown it includes the year: "31.10." alone
    // is a guess, not information, for a range that can span years.
    function uhrzeit(ts) {
        var sek = root.gezeigteSekunden;
        if (sek <= 86400 * 2)
            return Qt.formatDateTime(new Date(ts * 1000), "HH:mm");
        if (sek <= 86400 * 400)
            return Qt.formatDateTime(new Date(ts * 1000), Tr.datumKurzesJahr(root.lang));
        return Qt.formatDateTime(new Date(ts * 1000), Tr.monatJahr(root.lang));
    }

    // The readout row has room, so it shows the full date with time.
    function zeitpunkt(ts) {
        return Qt.formatDateTime(new Date(ts * 1000),
                                 root.gezeigteSekunden <= 86400 * 2
                                 ? Tr.datum(root.lang) + "  HH:mm" : Tr.datum(root.lang));
    }

    // The readout has its own row. In the header it grew with every value
    // and slid under the exchange dots and buttons; four labelled numbers
    // are simply wider than the space next to the price.
    Text {
        id: ablesen

        anchors.left: parent.left
        anchors.right: wahl.left
        anchors.rightMargin: root.baseFont
        anchors.top: parent.top
        anchors.topMargin: root.kopfHoehe + root.baseFont * 0.25
        visible: root.zeigerDa || root.vorschau
        elide: Text.ElideRight
        text: {
            // While dragging this shows where you are and that the picture
            // is coarse. The space is reserved anyway.
            if (root.vorschau)
                return Tr.t("market.preview", root.lang) + "    "
                     + root.zeitpunkt(root.endeEffektiv);
            if (!root.zeigerDa)
                return "";
            var k = root.sicht[root.zeiger];
            // If `sicht` changes in the middle of a gesture (pinch, drag),
            // the pointer can point at nothing for one pass, which would
            // otherwise throw a TypeError.
            if (!k)
                return "";
            var zeile = root.zeitpunkt(k[0]) + "    O " + Tr.group(k[1], root.lang)
                      + "   H " + Tr.group(k[2], root.lang)
                      + "   L " + Tr.group(k[3], root.lang)
                      + "   C " + Tr.group(k[4], root.lang);
            // With the CVD below, its value belongs here too, otherwise the
            // line is read without an axis.
            if (root.lower === "cvd" && root.zeiger < root.cvd.length) {
                var v = root.cvd[root.zeiger];
                zeile += "   CVD " + (v >= 0 ? "+" : "\u2212")
                       + Tr.fixed(Math.abs(v), 1, root.lang) + " \u20bf";
            }
            return zeile;
        }
        color: root.textColor
        font.pixelSize: root.baseFont - 2
        font.family: Fonts.mono()
    }

    // ------------------------------------------- zoom, pointer, crosshair
    MouseArea {
        id: zeigerFeld

        visible: root.sub === "price"
        anchors.fill: leinwand
        anchors.rightMargin: root.padR
        hoverEnabled: true
        // Dragging moves the window in time. The view follows immediately
        // (the drawn picture is shifted), fetching happens only when the
        // hand lets go.
        acceptedButtons: Qt.LeftButton
        cursorShape: druck ? Qt.ClosedHandCursor : Qt.ArrowCursor

        property bool druck: false
        property real griffX: 0

        onPressed: function (m) {
            zeigerFeld.druck = true;
            zeigerFeld.griffX = m.x;
        }

        onReleased: {
            if (!zeigerFeld.druck)
                return;
            zeigerFeld.druck = false;
            if (Math.abs(root.ziehVersatz) >= 2) {
                // Dragging to the right means going back into the past.
                var proPunkt = root.sichtSekunden / Math.max(1, root.feldBreite);
                root.fensterSetzen(root.endeEffektiv - root.ziehVersatz * proPunkt);
            }
            root.ziehVersatz = 0;
            leinwand.requestPaint();
        }

        onCanceled: {
            zeigerFeld.druck = false;
            root.ziehVersatz = 0;
            leinwand.requestPaint();
        }

        onPositionChanged: function (m) {
            if (zeigerFeld.druck) {
                root.ziehVersatz = m.x - zeigerFeld.griffX;
                root.zeiger = -1;
                leinwand.requestPaint();
                return;
            }
            root.zeiger = root.indexBei(m.x);
            root.zeigerY = m.y;
        }
        onExited: root.zeiger = -1

        // The wheel drives the custom range. Scrolling in shortens it,
        // scrolling out lengthens it, and because the service picks the
        // interval for the range, there are always about two hundred candles,
        // however deep you go. A fixed range becomes custom on the first
        // turn: anything else would be a toggle contradicting itself while
        // zooming.
        //
        // A `WheelHandler`, not `onWheel` on the MouseArea. That one is set
        // to `acceptedButtons: Qt.NoButton` because it should only be
        // hovered, not clicked, and whether it still receives wheel events
        // then is the kind of guarantee you cannot check without turning a
        // wheel. The handler is built for this.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (rad) {
                // One wheel notch is 120 eighths of a degree; a touchpad
                // reports finer steps. Both go through the same factor so
                // mouse and touchpad feel the same.
                var schritte = rad.angleDelta.y / 120;
                if (!schritte)
                    return;
                root.zoomen(Math.pow(1 / 1.35, schritte));
            }
        }

        // Pinch does the same as the wheel. `WheelHandler` does not take
        // touchscreen input, so without this pinching did nothing on a phone.
        //
        // The point between the fingers stays put, not the right edge.
        // Pinching on a candle in the middle means wanting to see that one
        // larger, not the newest. Computed from the state at touch-down: the
        // time under the centre and its fraction of the width from the left.
        // In the present, zooming in therefore moves into the past; started at
        // the far right it stays live.
        PinchHandler {
            id: kneifen

            target: null

            property int startSekunden: 0
            property int startEnde: 0
            property real anteil: 1

            onActiveChanged: {
                if (!kneifen.active) {
                    // As after dragging: the new window applies, and one
                    // fetch happens after the gesture.
                    if (kneifen.anteil < 1)
                        root.fensterSetzen(root.endeEffektiv);
                    return;
                }
                kneifen.startSekunden = root.sichtSekunden;
                kneifen.startEnde = root.endeEffektiv;
                kneifen.anteil = Math.max(0, Math.min(1, kneifen.centroid.position.x / Math.max(1, root.feldBreite)));
                // The first finger already started as a drag. Without this,
                // releasing would also shift the window.
                zeigerFeld.druck = false;
                root.ziehVersatz = 0;
                root.zeiger = -1;
                leinwand.requestPaint();
            }
            onActiveScaleChanged: {
                if (!kneifen.active || kneifen.activeScale <= 0)
                    return;
                root.zoomAuf(kneifen.startSekunden / kneifen.activeScale);
                if (kneifen.anteil >= 1)
                    return;
                var rechtsVorher = (1 - kneifen.anteil) * kneifen.startSekunden;
                var mitte = kneifen.startEnde - rechtsVorher;
                root.fensterSchieben(mitte + (1 - kneifen.anteil) * root.sichtSekunden);
            }
        }
    }

    // Length of a named range, for the first wheel turn
    function sekundenVon(r) {
        switch (r) {
        case "1h":
            return 3600;
        case "12h":
            return 43200;
        case "24h":
            return 86400;
        case "7d":
            return 604800;
        case "30d":
            return 2592000;
        case "1y":
            return 31536000;
        case "all":
            // Binance starts on 2017-07-31
            return Math.round(Date.now() / 1000) - 1501459200;
        }
        return root.customSecs;
    }

    readonly property bool zeigerDa: root.sub === "price" && root.zeiger >= 0
                                     && root.zeiger < root.sicht.length

    // Vertical line through the candle under the pointer
    Rectangle {
        visible: root.crosshair && root.zeigerDa
        x: leinwand.x + (root.zeiger + 0.5) * root.kerzeBreite
        y: leinwand.y + root.padT
        width: 1
        height: root.preisHoehe
        color: root.dimColor
        opacity: 0.7
    }

    // Horizontal line at pointer height
    Rectangle {
        visible: root.crosshair && root.zeigerDa
        x: leinwand.x
        y: leinwand.y + root.zeigerY
        width: root.feldBreite
        height: 1
        color: root.dimColor
        opacity: 0.7
    }

    // Price at the horizontal line, on the axis to the right
    Rectangle {
        visible: root.crosshair && root.zeigerDa
        x: leinwand.x + root.feldBreite + 2
        y: leinwand.y + root.zeigerY - height / 2
        width: preisMarke.implicitWidth + 8
        height: preisMarke.implicitHeight + 4
        radius: 3
        color: root.accentColor

        Text {
            id: preisMarke

            anchors.centerIn: parent
            text: Tr.group(root.preisBei(root.zeigerY), root.lang)
            color: "#11131f"
            font.pixelSize: root.baseFont - 2
        }
    }

    MarketHeat {
        visible: root.sub === "heat"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Math.max(root.kopfHoehe, unterreiter.height)
                           + root.baseFont * 0.6
        lang: root.lang
        zeichen: root.zeichen
        yAchse: root.heat.yAxis || []
        zellen: root.heat.cells || []
        hoechst: root.heat.max || 0
        schlusskurse: root.heat.closes || []
        hebel: (root.heat.model && root.heat.model.leverage) || []
        beschnitten: root.heat.clamped === true
        maxTage: root.heat.maxDays || 30
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        baseFont: root.baseFont
    }

    MarketLiq {
        visible: root.sub === "liq"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Math.max(root.kopfHoehe, unterreiter.height)
                           + root.baseFont * 0.6
        lang: root.lang
        zeichen: root.zeichen
        hist: root.liqHist
        ratio: root.ratio
        seit: root.liqSeit
        liqQuellen: root.liqQuellen
        preis: root.letzterPreis
        quellen: root.quellen
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        baseFont: root.baseFont
    }

    // Only for measuring the price axis.
    //
    // It has to be the same font that draws. The axis is written on the
    // canvas with `Fonts.sansCss()`; measuring with Qt's default font is not
    // enough, because on Linux fontconfig resolves "sans-serif" to the
    // configured font, which need not be the same. On Ubuntu and Fedora the
    // last digit was cut off ("81.95" instead of "81.951"): the text starts
    // at `breiteGesamt + 6` and `padR` was too small for the wider font.
    // Drawing starts at `+6`, the margin here is `+10`, four pixels of slack
    // so antialiasing rounding cuts nothing off.
    Text {
        id: mass

        visible: false
        text: Tr.group(root.hoch || 88888, root.lang)
        font.family: Fonts.sans()
        font.pixelSize: root.baseFont - 2
    }

    Connections {
        target: root
        function onSichtChanged() {
            leinwand.requestPaint();
        }
    }

    // ------------------------------------------------ time slider
    // The full width is the full history, from the first trading day on
    // Binance until now. The handle is the visible window: it shows both
    // where you are and how much you see. Dragging moves it, a click beside
    // it jumps.
    Item {
        id: schieber

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: root.padR
        anchors.bottom: bandFeld.visible ? bandFeld.top : parent.bottom
        height: root.schieberHoehe
        visible: root.schieberDa

        readonly property real gesamt: Math.max(1, root.jetzt - root.beginn)
        readonly property real anteil: Math.min(1, root.sichtSekunden / gesamt)
        readonly property real griffBreite: Math.max(10, width * anteil)
        readonly property real griffX: {
            var start = root.endeEffektiv - root.sichtSekunden;
            var t = (start - root.beginn) / schieber.gesamt;
            return Math.max(0, Math.min(width - schieber.griffBreite, t * width));
        }

        // Time for a position on the bar
        function zeitBei(x) {
            return root.beginn + schieber.gesamt * Math.max(0, Math.min(1, x / width));
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(3, root.baseFont * 0.35)
            radius: height / 2
            color: root.lineColor
        }

        // This area must come before the handle. In QML the later sibling
        // gets events first; placed after the handle it swallowed every
        // press on it, so the handle could never be dragged and every
        // gesture became a click at the release point, with a jump.
        //
        // `z` and declaration order only rank among siblings, and whoever
        // is on top receives events first.
        MouseArea {
            anchors.fill: parent
            // Clicked beside the handle: jump there, window centre on the
            // clicked spot.
            onClicked: function (m) {
                root.fensterSetzen(schieber.zeitBei(m.x) + root.sichtSekunden / 2);
            }
        }

        Rectangle {
            id: griff

            // Dragging breaks the binding. `drag.target` writes `x`
            // directly, after which the handle no longer follows the window
            // (a click beside it moved the picture but not the handle). So
            // the binding is restored after every gesture.
            function bindungZurueck() {
                griff.x = Qt.binding(function () {
                    return schieber.griffX;
                });
            }

            x: schieber.griffX
            width: schieber.griffBreite
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(7, root.baseFont * 0.8)
            radius: height / 2
            color: griffMaus.pressed || griffMaus.containsMouse
                   ? root.accentColor : root.dimColor

            MouseArea {
                id: griffMaus

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                drag.target: griff
                drag.axis: Drag.XAxis
                drag.minimumX: 0
                drag.maximumX: schieber.width - griff.width
                drag.threshold: 0

                // While dragging, the view draws from the overview. The
                // fetch happens on release: a fresh window costs over a
                // second, and on the slider every hand movement would be one.
                onPressed: root.vorschau = true

                onPositionChanged: {
                    if (!drag.active)
                        return;
                    // The handle stands for the start of the window
                    root.fensterSchieben(schieber.zeitBei(griff.x) + root.sichtSekunden);
                }

                onReleased: {
                    root.vorschau = false;
                    root.fensterSetzen(schieber.zeitBei(griff.x) + root.sichtSekunden);
                    griff.bindungZurueck();
                }

                onCanceled: {
                    root.vorschau = false;
                    griff.bindungZurueck();
                }
            }
        }

    }

    // -------------------------------------------------- running tape
    // Trades as they come in, newest on top. The service only keeps trades
    // over a thousand dollars and sends only new ones per request; this
    // shows the latest, as many as fit.
    ListView {
        id: bandFeld

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.bandHoehe
        visible: root.bandDa
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        // The newest trade is on top. Someone scrolling back should not be
        // yanked to the top by every new trade, so the position is not
        // tracked.
        model: root.bandUmgekehrt

        delegate: Item {
            id: zeile

            required property var modelData

            width: bandFeld.width
            height: Math.round(root.baseFont * 1.35)

            // How much a row stands out depends on its amount. Below ten
            // thousand it stays a stripe at the edge, above it the row is
            // filled, so large trades stand out and small ones stay visible.
            readonly property real wucht: Math.max(0, Math.min(1,
                (zeile.modelData[3] - 1000) / 99000))

            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: root.padR
                color: zeile.modelData[4] ? root.upColor : root.downColor
                opacity: 0.10 + zeile.wucht * 0.5
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(zeile.modelData[1] * 1000), "HH:mm:ss")
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
                font.family: Fonts.mono()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: root.baseFont * 5
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.group(zeile.modelData[2], root.lang)
                color: root.textColor
                font.pixelSize: root.baseFont - 2
                font.family: Fonts.mono()
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.padR + 6
                anchors.verticalCenter: parent.verticalCenter
                text: root.zeichen + " " + Tr.group(zeile.modelData[3], root.lang)
                color: root.textColor
                font.pixelSize: root.baseFont - 2
                font.family: Fonts.mono()
                font.bold: zeile.wucht > 0.4
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.padR + root.baseFont * 7
                anchors.verticalCenter: parent.verticalCenter
                text: zeile.modelData[5]
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }
        }
    }

    // ------------------------------------------------------------ notices
    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !root.sicht.length
        text: root.fehler !== "" ? Tr.t("market.failed", root.lang, root.fehler)
                                 : Tr.t("market.waiting", root.lang)
        color: root.dimColor
        font.pixelSize: root.baseFont
    }


}
