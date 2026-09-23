// Direct feed for the market view: candles, tape, liquidations and heatmap
// without the service.
//
// Why this file exists: going through the service on a phone means "service
// on another device", which needs a computer on the same Wi-Fi and an open
// port, and a VPN on the phone was enough to cut the app off while a shell
// on the same device still got through. On the road it does not work at all.
//
// The responses match the service (`/market`, `/market/overview`,
// `/market/heatmap` in `daemon/orangedeck`). `FeedState` passes `getJson`
// through to here and the views cannot tell the difference, same approach
// as `DirectFeed`.
//
// What differs from the service, and why:
//
//   Liquidations  The service listens around the clock and keeps two days.
//                 Here there is only what arrived since the view was opened,
//                 plus the last day from OKX: `liquidation-orders` is also
//                 available over REST, about 400 entries over roughly 23 hours,
//                 then the list ends. Binance has switched off
//                 `allForceOrders` (404), Bybit offers no way at all.
//   Tape, trades  Only while the view is open, same as in the service.
//   Heatmap       Needs nothing collected: candles and the open interest
//                 history both come over REST.
//
// Separate file for the same reason as `DirectFeed`: `import QtWebSockets`
// is not available everywhere, and as a Loader only the market view fails.
import QtQuick
import QtWebSockets

Item {
    id: root

    visible: false

    property bool active: true
    // Prices from mempool.space as `DirectFeed` collects them: {usd, eur, ...}.
    // The conversion factor comes from these, same as `markt_kurs()` in the service.
    property var preise: ({})

    // Constants, same as in the service
    readonly property int linger: 120          // MARKET_LINGER
    readonly property int tapeMin: 1000        // MARKET_TAPE_MIN, dollars
    readonly property int tapeKeep: 400        // MARKET_TAPE_KEEP
    readonly property int liqSekunden: 172800  // LIQ_SEKUNDEN, two days
    readonly property int liqKeep: 20000       // LIQ_KEEP
    readonly property int oiMaxTage: 30        // OI_MAX_TAGE
    readonly property real okxKontrakt: 0.01   // BTC per BTC-USDT-SWAP contract
    readonly property int timeoutMs: 20000

    readonly property var spans: ({
        "1h": ["1m", 60], "12h": ["5m", 144], "24h": ["15m", 96],
        "7d": ["1h", 168], "30d": ["4h", 180], "1y": ["1d", 365],
        "all": ["1w", 1000]
    })
    readonly property var ladder: [["1m", 60], ["3m", 180], ["5m", 300],
        ["15m", 900], ["30m", 1800], ["1h", 3600], ["2h", 7200], ["4h", 14400],
        ["6h", 21600], ["12h", 43200], ["1d", 86400], ["3d", 259200],
        ["1w", 604800]]
    readonly property var kerzenTtl: ({
        "1m": 20, "5m": 60, "15m": 120, "1h": 300, "4h": 600, "1d": 1800,
        "1w": 3600
    })
    // Heatmap assumptions, made up rather than measured, see `HEBEL_STUFEN`
    // in the service. They are sent along with the response.
    readonly property var hebel: [[5, 0.30], [10, 0.30], [25, 0.20], [50, 0.13], [100, 0.07]]
    readonly property real longAnteil: 0.5
    readonly property var oiRaster: [["5m", 300], ["15m", 900], ["30m", 1800],
        ["1h", 3600], ["2h", 7200], ["4h", 14400], ["6h", 21600],
        ["12h", 43200], ["1d", 86400]]

    // Internal state
    property real __gefragt: 0
    property bool __erwuenscht: false
    readonly property bool laeuft: root.active && root.__erwuenscht

    property var __band: []
    property int __bandNr: 0
    property real __trades: 0

    // [ts, price, amount, isLong, source]
    property var __liq: []
    property bool __liqUnsortiert: false
    property var __liqGesehen: ({})
    property int __liqGesehenZahl: 0
    property real __liqSeit: 0
    property real __bybitSeit: 0    // first connect, Bybit has no backfill
    property real __nachgeholt: 0

    property var __puffer: ({})     // url -> {t, d}
    property int __pufferZahl: 0
    property var __wartend: ({})    // url -> [done, ...]

    property var __ratio: []
    property real __ratioT: 0
    property bool __ratioLaeuft: false

    property var __ueb: ({ "t": 0, "d": [] })
    property var __uebWartend: null

    // Entry point
    function getJson(pfad, done) {
        var a = root.__abfrage(pfad);
        if (a.pfad === "/market")
            root.__markt(a.q, done);
        else if (a.pfad === "/market/overview")
            root.__overview(a.q, done);
        else if (a.pfad === "/market/heatmap")
            root.__heat(a.q, done);
        else
            done(null, "im Direktbezug nicht verfuegbar");
    }

    // Small helpers
    function __r(x, stellen) {
        var f = Math.pow(10, stellen);
        return Math.round(x * f) / f;
    }

    function __jetzt() {
        return Date.now() / 1000;
    }

    function __abfrage(pfad) {
        var i = pfad.indexOf("?");
        var q = {};
        if (i >= 0) {
            var teile = pfad.substring(i + 1).split("&");
            for (var k = 0; k < teile.length; k++) {
                var j = teile[k].indexOf("=");
                if (j > 0)
                    q[teile[k].substring(0, j)] = decodeURIComponent(teile[k].substring(j + 1));
            }
        }
        return { "pfad": i >= 0 ? pfad.substring(0, i) : pfad, "q": q };
    }

    function __ganz(v) {
        var n = parseInt(v, 10);
        return isNaN(n) ? 0 : n;
    }

    function __waehrung(q) {
        var c = String(q.cur || "");
        return /^[A-Za-z]{3}$/.test(c) ? c.toLowerCase() : "usd";
    }

    // [factor, converted], see `markt_kurs()` in the service
    function __kurs(cur) {
        if (cur === "usd")
            return [1.0, false];
        var p = root.preise || {};
        if (p[cur] && p.usd)
            return [p[cur] / p.usd, true];
        return [1.0, false];
    }

    // HTTP
    Component {
        id: fristC

        Timer {
            repeat: false
        }
    }

    // One request, JSON back. If the same URL is already in flight, the
    // second caller attaches to it. The view polls every second, and a slow
    // exchange would otherwise pile up requests.
    function __hol(url, done) {
        var liste = root.__wartend[url];
        if (liste) {
            liste.push(done);
            return;
        }
        root.__wartend[url] = [done];
        var req = new XMLHttpRequest();
        var fertig = false;
        // Own timeout, as in `DirectMiner`: `XMLHttpRequest` in QML has no
        // reliable `timeout`. The timer has to be cleaned up on both paths.
        var frist = fristC.createObject(root, { "interval": root.timeoutMs });
        function ab(obj, err) {
            if (frist) {
                frist.stop();
                frist.destroy();
                frist = null;
            }
            if (fertig)
                return;
            fertig = true;
            var wer = root.__wartend[url] || [];
            delete root.__wartend[url];
            for (var i = 0; i < wer.length; i++)
                wer[i](obj, err);
        }
        frist.triggered.connect(function () {
            req.abort();
            ab(null, "keine Antwort");
        });
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            if (req.status !== 200) {
                ab(null, "HTTP " + req.status);
                return;
            }
            try {
                ab(JSON.parse(req.responseText), null);
            } catch (e) {
                ab(null, "Antwort nicht lesbar");
            }
        };
        frist.start();
        try {
            req.open("GET", url);
            req.send();
        } catch (e2) {
            ab(null, String(e2));
        }
    }

    // Cached and already transformed. If the source fails, the last result
    // is returned, an old price beats an empty chart.
    function __gepuffert(url, ttl, umformen, done) {
        var e = root.__puffer[url];
        if (e && root.__jetzt() - e.t < ttl) {
            done(e.d, null);
            return;
        }
        root.__hol(url, function (roh, err) {
            if (roh !== null && !err) {
                var d = umformen(roh);
                // Past windows get their own URL per step. A rough cap keeps
                // the cache from growing forever.
                if (!root.__puffer[url] && ++root.__pufferZahl > 300) {
                    root.__puffer = {};
                    root.__pufferZahl = 1;
                }
                root.__puffer[url] = { "t": root.__jetzt(), "d": d };
                done(d, null);
            } else if (e) {
                done(e.d, null);
            } else {
                done(null, err);
            }
        });
    }

    // Candles
    // `raster_fuer()` (limit 400) and `raster_heat()` (limit 200) in the service
    function __rasterFuer(sekunden, grenze) {
        for (var i = 0; i < root.ladder.length; i++) {
            var laenge = root.ladder[i][1];
            if (sekunden / laenge <= grenze)
                return [root.ladder[i][0], Math.max(20, Math.min(1000, Math.round(sekunden / laenge)))];
        }
        return ["1w", 1000];
    }

    // [t, o, h, l, c, buy, sell]. Binance field 9 is the taker buy volume,
    // the rest was sold. The CVD depends on this.
    function __kerzenAus(roh) {
        var aus = [];
        for (var i = 0; i < (roh || []).length; i++) {
            var k = roh[i];
            var vol = Number(k[5]);
            var kauf = Number(k[9]);
            var o = Number(k[1]), h = Number(k[2]), l = Number(k[3]), c = Number(k[4]);
            if (isNaN(vol) || isNaN(kauf) || isNaN(o) || isNaN(h) || isNaN(l) || isNaN(c))
                continue;
            aus.push([Math.floor(Number(k[0]) / 1000), root.__r(o, 2), root.__r(h, 2),
                      root.__r(l, 2), root.__r(c, 2), root.__r(kauf, 3),
                      root.__r(Math.max(0, vol - kauf), 3)]);
        }
        return aus;
    }

    function __kerzen(raster, anzahl, von, bis, done) {
        var url = "https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval="
                + raster + "&limit=" + Math.min(1000, anzahl);
        if (von && bis && bis > von)
            url += "&startTime=" + Math.floor(von) * 1000 + "&endTime=" + Math.floor(bis) * 1000;
        else if (bis)
            url += "&endTime=" + Math.floor(bis) * 1000;
        // Past candles are final, an hour of caching does no harm there
        var ttl = (bis && bis < root.__jetzt() - 120) ? 3600 : (root.kerzenTtl[raster] || 60);
        root.__gepuffert(url, ttl, root.__kerzenAus, function (d, err) {
            done(d || [], err);
        });
    }

    // Daily candles since 2017, four pages of 1000, see `uebersicht()`
    function __uebersicht(done) {
        if (root.__ueb.d.length && root.__jetzt() - root.__ueb.t < 1800) {
            done(root.__ueb.d, null);
            return;
        }
        if (root.__uebWartend) {
            root.__uebWartend.push(done);
            return;
        }
        root.__uebWartend = [done];
        var aus = [];
        function ende(err) {
            var wer = root.__uebWartend || [];
            root.__uebWartend = null;
            // If a page fails, the old result stays. A partial history
            // would give a wrong slider.
            if (!err)
                root.__ueb = { "t": root.__jetzt(), "d": aus };
            var d = root.__ueb.d;
            for (var i = 0; i < wer.length; i++)
                wer[i](d, d.length ? null : err);
        }
        function seite(start) {
            if (start >= root.__jetzt() || aus.length >= 6000) {
                ende(null);
                return;
            }
            root.__hol("https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=1d&limit=1000&startTime="
                       + start * 1000, function (roh, err) {
                if (err || !roh) {
                    ende(err || "leer");
                    return;
                }
                if (!roh.length) {
                    ende(null);
                    return;
                }
                aus = aus.concat(root.__kerzenAus(roh));
                // The next page starts one day after the last candle
                var weiter = Math.floor(Number(roh[roh.length - 1][0]) / 1000) + 86400;
                if (weiter <= start)
                    ende(null);
                else
                    seite(weiter);
            });
        }
        seite(1501459200);    // 2017-07-31, first trading day on Binance
    }

    // Long/short ratio
    // Three sources in parallel; done once all three have answered. Until
    // then the last result applies, `/market` does not wait for it.
    function __ratioAuffrischen() {
        if (root.__ratioLaeuft || (root.__ratio.length && root.__jetzt() - root.__ratioT < 300))
            return;
        root.__ratioLaeuft = true;
        var aus = [], offen = 3;
        function geordnet() {
            var rang = { "okx": 0, "bybit": 1, "binance": 2 };
            var k = aus.map(function (x) {
                return { "id": x.id, "name": x.name, "long": root.__r(Math.max(0, Math.min(1, x.long)), 4) };
            });
            k.sort(function (a, b) {
                return rang[a.id] - rang[b.id];
            });
            return k;
        }
        // Partial results while fewer are in. Waiting for all three left the
        // bar empty on open for as long as the slowest exchange took, up to
        // the 20 s timeout if one hung. A later refresh never replaces a
        // full list with a partial one.
        function fertig() {
            if (--offen > 0) {
                if (aus.length > root.__ratio.length)
                    root.__ratio = geordnet();
                return;
            }
            root.__ratioLaeuft = false;
            // If all failed, ask again next time
            if (aus.length) {
                root.__ratio = geordnet();
                root.__ratioT = root.__jetzt();
            }
        }
        root.__hol("https://www.okx.com/api/v5/rubik/stat/contracts/long-short-account-ratio?ccy=BTC&period=5m",
                   function (d) {
            try {
                // OKX returns the long/short ratio, not the shares
                var v = Number(d.data[0][1]);
                if (!isNaN(v))
                    aus.push({ "id": "okx", "name": "OKX", "long": v / (1 + v) });
            } catch (e) {}
            fertig();
        });
        root.__hol("https://api.bybit.com/v5/market/account-ratio?category=linear&symbol=BTCUSDT&period=5min&limit=1",
                   function (d) {
            try {
                var v = Number(d.result.list[0].buyRatio);
                if (!isNaN(v))
                    aus.push({ "id": "bybit", "name": "Bybit", "long": v });
            } catch (e) {}
            fertig();
        });
        root.__hol("https://fapi.binance.com/futures/data/globalLongShortAccountRatio?symbol=BTCUSDT&period=5m&limit=1",
                   function (d) {
            try {
                var v = Number(d[d.length - 1].longAccount);
                if (!isNaN(v))
                    aus.push({ "id": "binance", "name": "Binance", "long": v });
            } catch (e) {}
            fertig();
        });
    }

    // Trades and tape
    function __trade(ts, preis, menge, kauf, quelle) {
        if (!(preis > 0) || !(menge > 0))
            return;
        root.__trades += 1;
        var wert = preis * menge;
        if (wert < root.tapeMin)
            return;
        root.__bandNr += 1;
        root.__band.push([root.__bandNr, root.__r(ts, 2), root.__r(preis, 2),
                          Math.round(wert), kauf ? 1 : 0, quelle]);
        if (root.__band.length > root.tapeKeep)
            root.__band.splice(0, root.__band.length - root.tapeKeep);
    }

    // `band_seit()`: what came after `nr`, at most the latest 120
    function __bandSeit(nr) {
        var b = root.__band;
        var i = b.length;
        while (i > 0 && b[i - 1][0] > nr)
            i--;
        var neu = b.slice(Math.max(i, b.length - 120));
        return [neu, b.length ? b[b.length - 1][0] : 0];
    }

    function __binanceNachricht(text) {
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        // `m` means "the buyer was the maker", so the aggressor was a seller
        if (m.e === "aggTrade")
            root.__trade(Number(m.T) / 1000, Number(m.p), Number(m.q), !m.m, "binance");
    }

    function __bybitNachricht(text) {
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (String(m.topic || "").indexOf("publicTrade") !== 0)
            return;
        var d = m.data || [];
        for (var i = 0; i < d.length; i++)
            root.__trade(Number(d[i].T) / 1000, Number(d[i].p), Number(d[i].v), d[i].S === "Buy", "bybit");
    }

    // Liquidations
    function __liqAdd(ts, preis, menge, istLong, quelle) {
        if (!(preis > 0) || !(menge > 0) || isNaN(ts))
            return;
        // OKX replays recent entries on connect, and the REST backfill
        // delivers the same entries again
        var schluessel = root.__r(ts, 3) + "|" + root.__r(preis, 2) + "|" + root.__r(menge, 6) + "|" + quelle;
        if (root.__liqGesehen[schluessel])
            return;
        root.__liqGesehen[schluessel] = true;
        if (++root.__liqGesehenZahl > root.liqKeep * 2) {
            root.__liqGesehen = {};
            root.__liqGesehenZahl = 0;
        }
        var l = root.__liq;
        if (l.length && l[l.length - 1][0] > ts)
            root.__liqUnsortiert = true;
        l.push([root.__r(ts, 2), root.__r(preis, 2), root.__r(menge, 6), istLong ? 1 : 0, quelle]);
    }

    function __liqAufraeumen() {
        var l = root.__liq;
        if (root.__liqUnsortiert) {
            l.sort(function (a, b) {
                return a[0] - b[0];
            });
            root.__liqUnsortiert = false;
        }
        var grenze = root.__jetzt() - root.liqSekunden;
        var weg = 0;
        while (weg < l.length && l[weg][0] < grenze)
            weg++;
        weg = Math.max(weg, l.length - root.liqKeep);
        if (weg > 0)
            l.splice(0, weg);
        // Anything older than the cutoff is dropped and `seit` moves along, as in the service
        if (root.__liqSeit && root.__liqSeit < grenze)
            root.__liqSeit = Math.floor(grenze);
    }

    // `fenster()`: above 400 keep the largest, sorted by time again
    function __liqFenster(von, bis) {
        var drin = [];
        for (var i = 0; i < root.__liq.length; i++) {
            var x = root.__liq[i];
            if (x[0] >= von && x[0] <= bis)
                drin.push(x);
        }
        if (drin.length > 400) {
            drin.sort(function (a, b) {
                return b[1] * b[2] - a[1] * a[2];
            });
            drin = drin.slice(0, 400);
            drin.sort(function (a, b) {
                return a[0] - b[0];
            });
        }
        return drin;
    }

    // `histogramm()`: empty levels are included too, otherwise the price
    // axis is no longer an axis
    function __liqHist(von, bis, tief, hoch) {
        var stufen = 24;
        if (hoch <= tief)
            return [];
        var breite = (hoch - tief) / stufen;
        var eimer = [];
        var i;
        for (i = 0; i < stufen; i++)
            eimer.push([0, 0]);
        for (i = 0; i < root.__liq.length; i++) {
            var x = root.__liq[i];
            if (x[0] < von || x[0] > bis || x[1] < tief || x[1] > hoch)
                continue;
            var s = Math.min(stufen - 1, Math.floor((x[1] - tief) / breite));
            eimer[s][x[3] ? 0 : 1] += x[1] * x[2];
        }
        var aus = [];
        for (i = 0; i < stufen; i++)
            aus.push([root.__r(tief + (i + 0.5) * breite, 2), Math.round(eimer[i][0]), Math.round(eimer[i][1])]);
        return aus;
    }

    function __okxEintraege(daten) {
        var aeltest = 0;
        for (var b = 0; b < (daten || []).length; b++) {
            // The channel streams all swaps, `instFamily` has no effect there
            if (daten[b].instId && daten[b].instId !== "BTC-USDT-SWAP")
                continue;
            var det = daten[b].details || [];
            for (var i = 0; i < det.length; i++) {
                var ts = Number(det[i].ts);
                // `sz` is in contracts; `posSide` says what was liquidated
                root.__liqAdd(ts / 1000, Number(det[i].bkPx), Number(det[i].sz) * root.okxKontrakt,
                              det[i].posSide === "long", "okx");
                if (!isNaN(ts) && (!aeltest || ts < aeltest))
                    aeltest = ts;
            }
        }
        return aeltest;
    }

    function __okxNachricht(text) {
        if (text === "pong")
            return;
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (!m.arg || m.arg.channel !== "liquidation-orders")
            return;
        root.__okxEintraege(m.data);
    }

    // `S` is the position, not the forced order: "Buy" means a long was
    // liquidated (verified against the service)
    function __bybitLiqNachricht(text) {
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        var t = String(m.topic || "");
        if (t.indexOf("allLiquidation") !== 0 && t.indexOf("liquidation") !== 0)
            return;
        var d = m.data || [];
        for (var i = 0; i < d.length; i++)
            root.__liqAdd(Number(d[i].T) / 1000, Number(d[i].p), Number(d[i].v), d[i].S === "Buy", "bybit-liq");
    }

    // The last day from OKX over REST. Pages back with `after` until the
    // list is empty. At most every five minutes, after that the stream
    // takes over.
    //
    // `liqSince` becomes the start of this backfill. Without it the view
    // would say "listening since just now" above a day full of marks. That
    // is too generous for Bybit, which only has what arrived since connecting,
    // so each source in `liqSources` carries its own `since` and the view
    // lists Bybit separately when it started later.
    function __nachholen() {
        if (root.__jetzt() - root.__nachgeholt < 300)
            return;
        root.__nachgeholt = root.__jetzt();
        var basis = "https://www.okx.com/api/v5/public/liquidation-orders?instType=SWAP&instFamily=BTC-USDT&state=filled&limit=100";
        function seite(nach, nr) {
            root.__hol(basis + (nach ? "&after=" + nach : ""), function (d, err) {
                if (err || !d || d.code !== "0")
                    return;
                var aeltest = root.__okxEintraege(d.data);
                if (!aeltest)
                    return;
                var sek = Math.floor(aeltest / 1000);
                if (!root.__liqSeit || sek < root.__liqSeit)
                    root.__liqSeit = sek;
                // Until OKX answers empty: it delivers exactly 24 hours,
                // about 20 pages. A fixed 30 pages is not always enough.
                // 100 only as a safety limit, as in the service.
                if (nr < 100 && (!nach || aeltest < nach))
                    seite(aeltest, nr + 1);
            });
        }
        seite(0, 1);
    }

    function __liqVerbunden() {
        if (!root.__liqSeit)
            root.__liqSeit = Math.floor(root.__jetzt());
    }

    // Responses
    function __markt(q, done) {
        root.__gefragt = root.__jetzt();
        root.__pruefen();
        root.__ratioAuffrischen();

        var spanne = (root.spans[q.range] || q.range === "custom") ? q.range : "24h";
        var eigen = q.secs !== undefined ? Math.max(300, Math.min(400000000, root.__ganz(q.secs))) : 0;
        var bandAb = Math.max(0, root.__ganz(q.tape));
        var cur = root.__waehrung(q);
        var von = Math.max(0, root.__ganz(q.from));
        var bis = Math.max(0, root.__ganz(q.to));

        var rf, v = 0, b = 0;
        if (von && bis && bis > von) {
            rf = root.__rasterFuer(bis - von, 400);
            v = von;
            b = bis;
        } else if (bis) {
            if (spanne === "custom" && eigen) {
                v = bis - eigen;
                b = bis;
                rf = root.__rasterFuer(eigen, 400);
            } else {
                rf = root.spans[spanne] || root.spans["24h"];
                b = bis;
            }
        } else if (spanne === "custom" && eigen) {
            rf = root.__rasterFuer(eigen, 400);
        } else {
            rf = root.spans[spanne] || root.spans["24h"];
        }

        root.__kerzen(rf[0], rf[1], v, b, function (kerzen, err) {
            if (!kerzen.length && err) {
                done(null, err);
                return;
            }
            var band = root.__bandSeit(bandAb);
            root.__liqAufraeumen();
            var liqVon = kerzen.length ? kerzen[0][0] : 0;
            // Up to the end of the last candle, at least one day, as in the
            // service. A flat one day left the running week empty after its
            // first day with weekly candles ("all").
            var schritt = kerzen.length > 1
                          ? kerzen[kerzen.length - 1][0] - kerzen[kerzen.length - 2][0] : 0;
            var liqBis = kerzen.length
                         ? kerzen[kerzen.length - 1][0] + Math.max(86400, schritt) : 0;
            var liq = liqVon ? root.__liqFenster(liqVon, liqBis) : [];
            var hist = [];
            if (kerzen.length) {
                var tief = Infinity, hoch = -Infinity;
                for (var i = 0; i < kerzen.length; i++) {
                    tief = Math.min(tief, kerzen[i][3]);
                    hoch = Math.max(hoch, kerzen[i][2]);
                }
                hist = root.__liqHist(liqVon, liqBis, tief, hoch);
            }
            var k = root.__kurs(cur);
            var f = k[0];
            var tape = band[0];
            if (f !== 1.0) {
                // Convert prices, not amounts, those are in bitcoin
                kerzen = kerzen.map(function (x) {
                    return [x[0], root.__r(x[1] * f, 2), root.__r(x[2] * f, 2),
                            root.__r(x[3] * f, 2), root.__r(x[4] * f, 2), x[5], x[6]];
                });
                tape = tape.map(function (t) {
                    return [t[0], t[1], root.__r(t[2] * f, 2), Math.round(t[3] * f), t[4], t[5]];
                });
                liq = liq.map(function (x) {
                    return [x[0], root.__r(x[1] * f, 2), x[2], x[3], x[4]];
                });
                hist = hist.map(function (x) {
                    return [root.__r(x[0] * f, 2), Math.round(x[1] * f), Math.round(x[2] * f)];
                });
            }
            done({
                "range": spanne,
                "cur": cur,
                "converted": k[1],
                "candles": kerzen,
                "tape": tape,
                "tapeLast": band[1],
                "liq": liq,
                "liqHist": hist,
                "ratio": root.__ratio,
                "liqSince": Math.round(root.__liqSeit),
                "liqSources": [
                    { "id": "okx", "name": "OKX", "online": okxSock.status === WebSocket.Open,
                      "since": Math.round(root.__liqSeit) },
                    { "id": "bybit-liq", "name": "Bybit", "online": bybitLiqSock.status === WebSocket.Open,
                      "since": Math.round(root.__bybitSeit) }
                ],
                "sources": [
                    { "id": "binance", "name": "Binance", "online": binanceSock.status === WebSocket.Open },
                    { "id": "bybit", "name": "Bybit", "online": bybitSock.status === WebSocket.Open }
                ],
                "trades": root.__trades
            }, null);
        });
    }

    function __overview(q, done) {
        var cur = root.__waehrung(q);
        root.__uebersicht(function (kerzen, err) {
            if (!kerzen.length) {
                done(null, err || "leer");
                return;
            }
            var k = root.__kurs(cur);
            var f = k[0];
            if (f !== 1.0) {
                kerzen = kerzen.map(function (x) {
                    return [x[0], root.__r(x[1] * f, 2), root.__r(x[2] * f, 2),
                            root.__r(x[3] * f, 2), root.__r(x[4] * f, 2), x[5], x[6]];
                });
            }
            done({ "cur": cur, "converted": k[1], "candles": kerzen }, null);
        });
    }

    // Heatmap
    function __oiRasterFuer(kerzen) {
        if (kerzen.length < 2)
            return "1h";
        var schritt = kerzen[1][0] - kerzen[0][0];
        for (var i = 0; i < root.oiRaster.length; i++) {
            if (root.oiRaster[i][1] >= schritt)
                return root.oiRaster[i][0];
        }
        return "1d";
    }

    // {zeiten: [s...], werte: [BTC...]}, ascending
    function __oiAus(roh) {
        var paare = [];
        for (var i = 0; i < (roh || []).length; i++) {
            var t = Math.floor(Number(roh[i].timestamp) / 1000);
            var w = Number(roh[i].sumOpenInterest);
            if (!isNaN(t) && !isNaN(w))
                paare.push([t, w]);
        }
        paare.sort(function (a, b) {
            return a[0] - b[0];
        });
        return {
            "zeiten": paare.map(function (p) { return p[0]; }),
            "werte": paare.map(function (p) { return p[1]; })
        };
    }

    // `heatmap()` in the service, step by step: when open interest grows,
    // positions were opened at the current price; they die at
    // price*(1-1/L) or price*(1+1/L), and a level lives until the price
    // crosses it.
    function __heatmap(kerzen, oi) {
        var stufen = 64, schwelle = 0.004;
        if (kerzen.length < 3)
            return { "yAxis": [], "cells": [], "max": 0 };
        var tief = Infinity, hoch = -Infinity;
        var i, j, x, y;
        for (i = 0; i < kerzen.length; i++) {
            tief = Math.min(tief, kerzen[i][3]);
            hoch = Math.max(hoch, kerzen[i][2]);
        }
        var spanne = hoch - tief;
        if (spanne <= 0)
            return { "yAxis": [], "cells": [], "max": 0 };
        tief -= spanne * 0.04;
        hoch += spanne * 0.04;
        var breite = (hoch - tief) / stufen;
        var n = kerzen.length;

        var zeiten = oi.zeiten, werte = oi.werte;
        if (zeiten.length < 3)
            return { "yAxis": [], "cells": [], "max": 0, "kein_oi": true };

        function oiBei(ts) {
            if (ts < zeiten[0])
                return null;
            var links = 0, rechts = zeiten.length - 1;
            while (links < rechts) {
                var mitte = (links + rechts + 1) >> 1;
                if (zeiten[mitte] <= ts)
                    links = mitte;
                else
                    rechts = mitte - 1;
            }
            return werte[links];
        }

        var gitter = [];
        for (i = 0; i < n; i++) {
            var zeile = new Array(stufen);
            for (y = 0; y < stufen; y++)
                zeile[y] = 0;
            gitter.push(zeile);
        }
        var vorher = oiBei(kerzen[0][0]);
        var hoechst = 0;
        for (i = 1; i < n; i++) {
            var jetzt = oiBei(kerzen[i][0]);
            if (jetzt === null || vorher === null) {
                vorher = jetzt;
                continue;
            }
            var zuwachs = jetzt - vorher;
            vorher = jetzt;
            if (zuwachs <= 0)
                continue;
            var preis = kerzen[i][4];
            var wert = zuwachs * preis;
            for (var h = 0; h < root.hebel.length; h++) {
                for (var seite = 0; seite < 2; seite++) {
                    var istLong = seite === 0;
                    var teil = wert * root.hebel[h][1] * (istLong ? root.longAnteil : 1 - root.longAnteil);
                    var niveau = istLong ? preis * (1 - 1 / root.hebel[h][0])
                                         : preis * (1 + 1 / root.hebel[h][0]);
                    if (niveau < tief || niveau >= hoch)
                        continue;
                    y = Math.floor((niveau - tief) / breite);
                    for (j = i; j < n; j++) {
                        if (kerzen[j][3] <= niveau && niveau <= kerzen[j][2])
                            break;
                        gitter[j][y] += teil;
                        if (gitter[j][y] > hoechst)
                            hoechst = gitter[j][y];
                    }
                }
            }
        }
        var grenze = hoechst * schwelle;
        var zellen = [];
        for (x = 0; x < n; x++) {
            for (y = 0; y < stufen; y++) {
                if (gitter[x][y] > grenze)
                    zellen.push([x, y, Math.round(gitter[x][y])]);
            }
        }
        var achse = [];
        for (y = 0; y < stufen; y++)
            achse.push(root.__r(tief + (y + 0.5) * breite, 2));
        return { "yAxis": achse, "cells": zellen, "max": Math.round(hoechst) };
    }

    function __heat(q, done) {
        var spanne = (root.spans[q.range] || q.range === "custom") ? q.range : "24h";
        var eigen = q.secs !== undefined ? Math.max(300, Math.min(400000000, root.__ganz(q.secs))) : 0;
        var cur = root.__waehrung(q);

        var laenge = {};
        for (var i = 0; i < root.ladder.length; i++)
            laenge[root.ladder[i][0]] = root.ladder[i][1];
        var sp = root.spans[spanne];
        var gewuenscht = (spanne === "custom" && eigen) ? eigen
                       : (sp ? sp[1] * (laenge[sp[0]] || 3600) : 0);
        var grenze = root.oiMaxTage * 86400;
        var zuLang = gewuenscht > grenze;
        var rf;
        if (zuLang)
            rf = root.__rasterFuer(grenze, 200);
        else if (spanne === "custom" && eigen)
            rf = root.__rasterFuer(eigen, 200);
        else
            rf = root.__rasterFuer(gewuenscht > 0 ? gewuenscht : 86400, 200);

        root.__kerzen(rf[0], rf[1], 0, 0, function (kerzen, err) {
            if (!kerzen.length && err) {
                done(null, err);
                return;
            }
            var raster = root.__oiRasterFuer(kerzen);
            root.__gepuffert("https://fapi.binance.com/futures/data/openInterestHist?symbol=BTCUSDT&period="
                             + raster + "&limit=500", 240, root.__oiAus, function (oi, oiErr) {
                // No response is not "no open interest". Turning a Binance
                // Futures outage into a heatmap with `kein_oi` made the view
                // show it as valid for a minute. So it is an error: the view
                // keeps the last image and asks again soon.
                if (!oi && oiErr) {
                    done(null, oiErr);
                    return;
                }
                var d = root.__heatmap(kerzen, oi || { "zeiten": [], "werte": [] });
                var k = root.__kurs(cur);
                var f = k[0];
                if (f !== 1.0) {
                    d.yAxis = d.yAxis.map(function (v) { return root.__r(v * f, 2); });
                    d.cells = d.cells.map(function (c) { return [c[0], c[1], Math.round(c[2] * f)]; });
                    d.max = Math.round(d.max * f);
                }
                d.converted = k[1];
                d.clamped = zuLang;
                d.maxDays = root.oiMaxTage;
                d.times = kerzen.map(function (x) { return x[0]; });
                d.closes = kerzen.map(function (x) { return f !== 1.0 ? x[4] * f : x[4]; });
                d.model = { "leverage": root.hebel, "longShare": root.longAnteil };
                done(d, null);
            });
        });
    }

    // Connections
    // The streams run only while someone asks for `/market`, and for
    // `linger` seconds afterwards, see `gefragt()`/`erwuenscht()` in the service.
    function __pruefen() {
        var soll = root.__jetzt() - root.__gefragt < root.linger;
        if (soll !== root.__erwuenscht)
            root.__erwuenscht = soll;
    }

    // Assigned, not bound. Reconnecting needs `active` briefly off and on;
    // an assignment destroys a binding, and after that the stream no longer
    // followed the switch.
    function __schalten() {
        var an = root.laeuft;
        binanceSock.active = an;
        bybitSock.active = an;
        okxSock.active = an;
        bybitLiqSock.active = an;
        if (an)
            root.__nachholen();
    }

    onLaeuftChanged: root.__schalten()

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.__pruefen()
    }

    // Knock again when a connection is gone
    Timer {
        interval: 5000
        repeat: true
        running: root.laeuft

        onTriggered: {
            var alle = [binanceSock, bybitSock, okxSock, bybitLiqSock];
            for (var i = 0; i < alle.length; i++) {
                var s = alle[i];
                if (s.status === WebSocket.Error || s.status === WebSocket.Closed) {
                    s.active = false;
                    s.active = true;
                }
            }
        }
    }

    // OKX closes after 30 s of silence, Bybit after about ten minutes without a ping
    Timer {
        interval: 18000
        repeat: true
        running: root.laeuft

        onTriggered: {
            if (okxSock.status === WebSocket.Open)
                okxSock.sendTextMessage("ping");
            if (bybitSock.status === WebSocket.Open)
                bybitSock.sendTextMessage('{"op":"ping"}');
            if (bybitLiqSock.status === WebSocket.Open)
                bybitLiqSock.sendTextMessage('{"op":"ping"}');
        }
    }

    WebSocket {
        id: binanceSock

        url: "wss://stream.binance.com:9443/ws/btcusdt@aggTrade"
        active: false
        onTextMessageReceived: function (message) {
            root.__binanceNachricht(message);
        }
    }

    WebSocket {
        id: bybitSock

        url: "wss://stream.bybit.com/v5/public/spot"
        active: false
        onStatusChanged: {
            if (bybitSock.status === WebSocket.Open)
                bybitSock.sendTextMessage(JSON.stringify({ "op": "subscribe", "args": ["publicTrade.BTCUSDT"] }));
        }
        onTextMessageReceived: function (message) {
            root.__bybitNachricht(message);
        }
    }

    WebSocket {
        id: okxSock

        url: "wss://ws.okx.com:8443/ws/v5/public"
        active: false
        onStatusChanged: {
            if (okxSock.status === WebSocket.Open) {
                okxSock.sendTextMessage(JSON.stringify({
                    "op": "subscribe",
                    "args": [{ "channel": "liquidation-orders", "instType": "SWAP" }]
                }));
                root.__liqVerbunden();
            }
        }
        onTextMessageReceived: function (message) {
            root.__okxNachricht(message);
        }
    }

    WebSocket {
        id: bybitLiqSock

        url: "wss://stream.bybit.com/v5/public/linear"
        active: false
        onStatusChanged: {
            if (bybitLiqSock.status === WebSocket.Open) {
                bybitLiqSock.sendTextMessage(JSON.stringify({ "op": "subscribe", "args": ["allLiquidation.BTCUSDT"] }));
                root.__liqVerbunden();
                if (!root.__bybitSeit)
                    root.__bybitSeit = Math.floor(root.__jetzt());
            }
        }
        onTextMessageReceived: function (message) {
            root.__bybitLiqNachricht(message);
        }
    }
}
