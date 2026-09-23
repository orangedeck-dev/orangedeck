// Direct mode: the UI talks to mempool.space itself.
//
// The daemon is the better choice where several windows run side by side,
// since it keeps one connection for all of them. A phone has no daemon,
// though, and a widget that only works while the home machine is on is no
// widget. So the same processing is repeated here in QML.
//
// The structure mirrors the daemon's `/state` and `/block`: `FeedState` runs
// both through the same evaluation, and no view can tell where the numbers
// come from.
//
// Separate file on purpose: `import QtWebSockets` is not available on every
// machine (package `qt6-websockets`). If the import were in `FeedState.qml`, a
// missing package would take down the whole app; this way only direct mode
// fails and the daemon keeps working.
//
// Not handled here:
//   Wallets:  deriving from the xpub is point arithmetic on secp256k1 and
//             should not be rebuilt in QML. Stays in the daemon.
//   Miner:    polled by `DirectMiner` in its own file.
import QtQuick
import QtWebSockets
import "mondrian.js" as Mondrian
import "txtype.js" as TxType
import "colors.js" as Colors

Item {
    id: root

    visible: false

    property bool active: true
    property string host: "mempool.space"
    readonly property string api: "https://" + root.host + "/api"
    readonly property string wsUrl: "wss://" + root.host + "/api/v1/ws"

    // How often the collected state is passed on. The daemon writes at the same
    // rate; anything faster only costs CPU because the display is not faster
    // anyway.
    property int pushMs: 400

    // Result, same shape as from the daemon.
    property var snap: ({})
    property var block: ({})

    // Limits as in the daemon, so the same pictures come out.
    readonly property int recentKeep: 120
    readonly property int maxTiles: 8000
    readonly property int projectedKeep: 8
    // The projected block stays subscribed while someone is looking, then it is
    // unsubscribed: it is the most expensive stream the server sends.
    readonly property int projectedLinger: 20

    // --- Internal state ---
    property int __seq: 0
    property var __recent: []
    property var __mempool: ({ "count": 0, "vsize": 0, "totalFee": 0 })
    property var __fees: ({})
    property int __vbps: 0
    property var __nextBlock: ({})
    property var __projected: []
    property var __tip: ({})
    property var __price: ({})
    property real __blockEvent: 0
    property var __difficulty: ({})
    property var __hashrate: ({})
    property string __source: "start"
    property string __error: ""
    property bool __dirty: true
    property string __summaryFor: ""
    property bool __summaryBusy: false

    // Projected blocks: rank -> { txid: row }. Rows come from the server as
    // [txid, fee, vsize, value, rate, flags]
    property var __projRows: ({})
    property var __projAt: ({})
    property int __want: -1        // requested rank, -1 = none
    property int __tracked: -1     // rank actually subscribed
    property real __trackUntil: 0

    // --- Helpers ---
    function __num(v) {
        var n = Number(v);
        return isFinite(n) ? n : 0;
    }

    function __round(v, n) {
        var f = Math.pow(10, n);
        return Math.round(root.__num(v) * f) / f;
    }

    // The two digits per tile: edge length and fee class. Same calculation as in
    // the daemon, the pictures must match.
    function __tile(valueSats, rate) {
        return String(Mondrian.txSize(valueSats, 5)) + String(Colors.feeBucket(rate));
    }

    function __kind(flags, isCoinbase) {
        var k = TxType.fromFlags(flags, isCoinbase);
        var i = TxType.KINDS.indexOf(k);
        return String(i < 0 ? 0 : i);
    }

    function __send(obj) {
        if (sock.status === WebSocket.Open)
            sock.sendTextMessage(JSON.stringify(obj));
    }

    // --- Server messages ---
    function __handle(text) {
        var msg;
        try {
            msg = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (!msg || typeof msg !== "object")
            return;

        var p = msg["projected-block-transactions"];
        if (p !== undefined && p !== null) {
            root.__handleProjected(p);
            return;
        }

        if (msg.mempoolInfo) {
            var mi = msg.mempoolInfo;
            root.__mempool = {
                "count": Math.round(root.__num(mi.size)),
                "vsize": Math.round(root.__num(mi.bytes)),
                "totalFee": Math.round(root.__num(mi.total_fee) * 1e8)
            };
            root.__dirty = true;
        }
        if (msg.transactions)
            root.__addTxs(msg.transactions);
        if (msg["mempool-blocks"])
            root.__setProjected(msg["mempool-blocks"]);
        if (msg.fees) {
            var f = msg.fees;
            root.__fees = {
                "fastest": root.__round(f.fastestFee, 2),
                "halfHour": root.__round(f.halfHourFee, 2),
                "hour": root.__round(f.hourFee, 2),
                "economy": root.__round(f.economyFee, 2),
                "minimum": root.__round(f.minimumFee, 2)
            };
            root.__dirty = true;
        }
        if (msg.vBytesPerSecond !== undefined) {
            root.__vbps = Math.round(root.__num(msg.vBytesPerSecond));
            root.__dirty = true;
        }
        if (msg.conversions) {
            // The server sends all currencies; they cost nothing extra and spare the UI
            // any conversion.
            var c = msg.conversions;
            var np = {};
            var waehrungen = ["USD", "EUR", "GBP", "CAD", "CHF", "AUD", "JPY"];
            for (var i = 0; i < waehrungen.length; i++) {
                var k = waehrungen[i];
                if (c[k])
                    np[k.toLowerCase()] = c[k];
            }
            root.__price = np;
            root.__dirty = true;
        }
        if (msg.blocks && msg.blocks.length)
            root.__setTip(msg.blocks[msg.blocks.length - 1], false);
        if (msg.block)
            root.__setTip(msg.block, true);
    }

    // The same transaction twice. mempool.space can send the same entry in two
    // messages, which shows up as duplicate rows in "Recently seen in mempool".
    // An entry already in the list is not added again; its tile keeps its place
    // and number.
    function __addTxs(txs) {
        var rec = root.__recent.slice();
        var drin = {};
        for (var k = 0; k < rec.length; k++)
            if (rec[k].t)
                drin["x" + rec[k].t] = true;
        for (var i = 0; i < txs.length; i++) {
            var t = txs[i];
            if (!t)
                continue;
            // Without a txid nothing can be compared, so it is added.
            var id = t.txid || "";
            if (id) {
                if (drin["x" + id])
                    continue;
                drin["x" + id] = true;
            }
            var vsize = root.__num(t.vsize) || 1;
            var rate = (t.rate === undefined || t.rate === null)
                ? root.__num(t.fee) / vsize : root.__num(t.rate);
            root.__seq += 1;
            rec.push({
                "n": root.__seq,
                "t": t.txid || "",
                "v": root.__round(vsize, 1),
                "r": root.__round(rate, 3),
                "a": Math.round(root.__num(t.value)),
                "f": Math.round(root.__num(t.fee))
            });
        }
        if (rec.length > root.recentKeep)
            rec = rec.slice(rec.length - root.recentKeep);
        root.__recent = rec;
        root.__dirty = true;
    }

    function __setProjected(blocks) {
        if (!blocks || !blocks.length)
            return;
        var b = blocks[0];
        root.__nextBlock = {
            "nTx": Math.round(root.__num(b.nTx)),
            "vsize": Math.round(root.__num(b.blockVSize)),
            "medianFee": root.__round(b.medianFee, 2),
            "totalFees": Math.round(root.__num(b.totalFees)),
            "feeRange": (b.feeRange || []).map(function (v) {
                return root.__round(v, 2);
            })
        };
        var liste = [];
        for (var i = 0; i < blocks.length && i < root.projectedKeep; i++) {
            var x = blocks[i];
            liste.push({
                "nTx": Math.round(root.__num(x.nTx)),
                "blockSize": Math.round(root.__num(x.blockSize)),
                "blockVSize": Math.round(root.__num(x.blockVSize)),
                "medianFee": root.__round(x.medianFee, 2),
                "totalFees": Math.round(root.__num(x.totalFees)),
                "feeRange": (x.feeRange || []).map(function (v) {
                    return root.__round(v, 2);
                })
            });
        }
        root.__projected = liste;
        root.__dirty = true;
    }

    function __setTip(b, isNew) {
        if (!b)
            return;
        var height = Math.round(root.__num(b.height));
        if (height && height === root.__num(root.__tip.height) && !isNew)
            return;
        var ex = b.extras || {};
        root.__tip = {
            "height": height,
            "id": b.id || "",
            "time": Math.round(root.__num(b.timestamp)),
            "nTx": Math.round(root.__num(b.tx_count)),
            "size": Math.round(root.__num(b.size)),
            "weight": Math.round(root.__num(b.weight)),
            "medianFee": root.__round(ex.medianFee, 2),
            "totalFees": Math.round(root.__num(ex.totalFees)),
            "reward": Math.round(root.__num(ex.reward)),
            "pool": (ex.pool && ex.pool.name) || ""
        };
        if (isNew)
            root.__blockEvent = Date.now() / 1000;
        root.__dirty = true;
        root.__fetchSummary();
    }

    // --- The projected block, live ---
    //
    // First the full form arrives, then only changes. Unlike the daemon, no
    // change log is needed here: there is no second process that would have to
    // catch up. The rows are maintained, and the view fetches the current state.
    function __handleProjected(p) {
        var idx = parseInt(p.index, 10);
        if (isNaN(idx))
            return;

        var rows = p.blockTransactions;
        var karte;
        if (rows) {
            karte = {};
            for (var i = 0; i < rows.length; i++) {
                if (rows[i])
                    karte[rows[i][0]] = rows[i];
            }
            root.__projRows[idx] = karte;
            root.__projAt[idx] = Date.now() / 1000;
            return;
        }

        var d = p.delta;
        if (!d)
            return;
        karte = root.__projRows[idx];
        if (!karte)
            return;                       // without the full form a change is worthless

        var j, r, t;
        var weg = d.removed || [];
        for (j = 0; j < weg.length; j++) {
            t = (typeof weg[j] === "string") ? weg[j] : (weg[j] ? weg[j][0] : null);
            if (t !== null)
                delete karte[t];
        }
        var zu = d.added || [];
        for (j = 0; j < zu.length; j++) {
            if (zu[j])
                karte[zu[j][0]] = zu[j];
        }
        // Known form: [txid, rate]. The tile stays in place, only its fee color
        // changes.
        var ge = d.changed || [];
        for (j = 0; j < ge.length; j++) {
            r = ge[j];
            if (!r || r.length < 2)
                continue;
            var alt = karte[r[0]];
            if (alt) {
                var neu = alt.slice();
                neu[4] = r[1];
                karte[r[0]] = neu;
            }
        }
        root.__projAt[idx] = Date.now() / 1000;
    }

    // Tile data of a projected block in the shape `BlockTiles` expects, same as
    // the daemon's `/lookup/projectedtiles/<n>`.
    function __projectedTiles(idx) {
        var karte = root.__projRows[idx];
        if (!karte)
            return null;
        var zeilen = [];
        for (var k in karte)
            zeilen.push(karte[k]);
        // Descending by fee rate, as in the daemon.
        zeilen.sort(function (a, b) {
            return (b[4] || 0) - (a[4] || 0);
        });

        var schritt = Math.max(1, Math.ceil(zeilen.length / root.maxTiles));
        var tiles = [], kinds = [], txs = [];
        for (var i = 0; i < zeilen.length; i += schritt) {
            var r = zeilen[i];
            tiles.push(root.__tile(r[3], r[4]));
            kinds.push(root.__kind(r.length > 5 ? r[5] : 0, false));
            txs.push([r[0], root.__round(r[2], 2), Math.round(root.__num(r[1])),
                      Math.round(root.__num(r[3])), root.__round(r[4], 3)]);
        }
        return {
            "index": idx,
            "full": true,
            "count": zeilen.length,
            "tileStep": schritt,
            "tiles": tiles.join(""),
            "types": kinds.join(""),
            "txs": txs,
            "changedAt": root.__projAt[idx] || 0,
            "ts": Date.now() / 1000
        };
    }

    // --- REST ---
    function __get(path, done, fail) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status === 200 && x.responseText)
                done(x.responseText);
            else if (fail)
                fail(x.status);
        };
        try {
            x.open("GET", root.api + path);
            x.send();
        } catch (e) {
            if (fail)
                fail(0);
        }
    }

    // Tile data of the most recently found block. Only two digits are kept per
    // transaction, so a full block takes about 8 kB in memory instead of 700 kB.
    function __fetchSummary() {
        var bid = root.__tip.id;
        if (!bid || bid === root.__summaryFor || root.__summaryBusy)
            return;
        root.__summaryBusy = true;
        var tip = root.__tip;
        root.__get("/v1/block/" + bid + "/summary", function (txt) {
            root.__summaryBusy = false;
            var liste;
            try {
                liste = JSON.parse(txt);
            } catch (e) {
                return;
            }
            if (!liste || !liste.length)
                return;
            root.__summaryFor = bid;
            root.block = root.__buildBlock(liste, tip);
        }, function () {
            root.__summaryBusy = false;
        });
    }

    // Tile data from a block's transaction list. Same processing as
    // `summarize_block()` in the daemon.
    function __buildBlock(txs, base) {
        var schritt = Math.max(1, Math.ceil(txs.length / root.maxTiles));
        var summe = 0, gebuehr = 0, vsize = 0;
        for (var i = 0; i < txs.length; i++) {
            summe += root.__num(txs[i].value);
            gebuehr += root.__num(txs[i].fee);
            vsize += root.__num(txs[i].vsize);
        }
        var tiles = [], kinds = [], details = [];
        for (i = 0; i < txs.length; i += schritt) {
            var t = txs[i];
            tiles.push(root.__tile(t.value, t.rate));
            // The first transaction of a block is the coinbase. The bit field does not
            // show it, its position does.
            kinds.push(root.__kind(t.flags, i === 0));
            details.push([t.txid || "", root.__round(t.vsize, 2),
                          Math.round(root.__num(t.fee)),
                          Math.round(root.__num(t.value)),
                          root.__round(t.rate, 3)]);
        }
        var d = {};
        for (var k in base)
            d[k] = base[k];
        d.totalValue = summe;
        d.sumFees = gebuehr;
        d.avgFeeRate = vsize ? root.__round(gebuehr / vsize, 3) : 0;
        d.tileStep = schritt;
        d.tiles = tiles.join("");
        d.types = kinds.join("");
        d.txs = details;
        d.ts = Date.now() / 1000;
        return d;
    }

    // Slow metrics: every five minutes is enough, they change at most every ten
    // minutes.
    function __slow() {
        root.__get("/v1/difficulty-adjustment", function (txt) {
            try {
                var d = JSON.parse(txt);
                root.__difficulty = {
                    "progress": d.progressPercent,
                    "change": d.difficultyChange,
                    "remainingBlocks": d.remainingBlocks,
                    "remainingTime": d.remainingTime,
                    "nextHeight": d.nextRetargetHeight,
                    "previousChange": d.previousRetarget,
                    "timeAvg": d.timeAvg,
                    "retargetDate": d.estimatedRetargetDate,
                    "expectedBlocks": d.expectedBlocks
                };
                root.__dirty = true;
            } catch (e) {}
        });
        // /1m gives 31 points in 2.2 kB, enough for a curve; /3d has only three.
        root.__get("/v1/mining/hashrate/1m", function (txt) {
            try {
                var h = JSON.parse(txt);
                var reihe = (h.hashrates || []).map(function (p) {
                    return p.avgHashrate;
                });
                root.__hashrate = {
                    "current": h.currentHashrate,
                    "difficulty": h.currentDifficulty,
                    "series": reihe.slice(-40)
                };
                root.__dirty = true;
            } catch (e) {}
        });
    }

    // --- Single lookups for the explorer ---
    //
    // Same names as in the daemon (`LOOKUP_ROUTES`), so `ExplorerView` does not
    // need to know the source. Two cases are processed here instead of passed
    // through: the tiles of a block and those of a projected block.
    readonly property var __routes: ({
        "tx": "/tx/%1",
        "outspends": "/tx/%1/outspends",
        "block": "/block/%1",
        "blocktxids": "/block/%1/txids",
        "blockheight": "/block-height/%1",
        "address": "/address/%1",
        "addresstxs": "/address/%1/txs",
        "blocks": "/v1/blocks",
        "blockinfo": "/v1/block/%1",
        "mempoolblocks": "/v1/fees/mempool-blocks",
        "replacements": "/v1/replacements"
    })

    // --- Price history ---
    // Without the service nobody thins out the data, so it happens here. The full
    // set is 1.5 MB and 33,299 points; it is fetched once and kept in memory,
    // after that each span only costs computation.
    property var __preise: null
    property real __preiseTs: 0
    // Same spans and the same limit as in the service.
    readonly property var __spans: ({ "24h": 86400, "7d": 604800, "30d": 2592000,
                                      "90d": 7776000, "1y": 31536000, "max": 0 })
    readonly property int __maxPunkte: 360

    function prices(span, cur, done) {
        var alt = Date.now() / 1000 - root.__preiseTs > 3600;
        if (root.__preise && !alt) {
            done(root.__preisReihe(span, cur), null);
            return;
        }
        root.__get("/v1/historical-price?currency=EUR", function (txt) {
            var d;
            try {
                d = JSON.parse(txt);
            } catch (e) {
                done(null, "Antwort nicht lesbar");
                return;
            }
            var roh = d.prices || [], punkte = [];
            for (var i = 0; i < roh.length; i++) {
                var x = roh[i];
                // -1 means "no value", not "minus one euro". Some points carry it, and a
                // single unfiltered one pulls the whole curve down.
                var e = (x.EUR > 0) ? x.EUR : 0;
                var u = (x.USD > 0) ? x.USD : 0;
                if (x.time && (e || u))
                    punkte.push([x.time, e, u]);
            }
            punkte.sort(function (a, b) {
                return a[0] - b[0];
            });
            root.__preise = { "points": punkte, "rates": d.exchangeRates || ({}) };
            root.__preiseTs = Date.now() / 1000;
            done(root.__preisReihe(span, cur), null);
        }, function () {
            // An old history is better than none.
            if (root.__preise)
                done(root.__preisReihe(span, cur), null);
            else
                done(null, "nicht erreichbar");
        });
    }

    function __preisReihe(span, cur) {
        var alle = root.__preise.points, w = String(cur || "usd").toLowerCase();
        var dauer = root.__spans[span] || 0;
        var punkte = alle;
        if (dauer) {
            var grenze = Date.now() / 1000 - dauer;
            punkte = [];
            for (var i = 0; i < alle.length; i++) {
                if (alle[i][0] >= grenze)
                    punkte.push(alle[i]);
            }
        }
        if (!punkte.length)
            return { "span": span, "cur": w, "points": [], "converted": false };

        // Pick the currency first, then thin out. The other way round a whole bucket
        // drops out whenever the chosen point has no value in that currency, and for
        // EUR there are almost three hundred of those.
        //
        // Only EUR and USD are really in the data set. The other five are derived
        // from the USD value with today's exchange rate, which over years is a
        // conversion, not the truth. The response says so.
        var umgerechnet = (w !== "eur" && w !== "usd");
        var reihe = [], j, kurs = 1;
        if (umgerechnet) {
            kurs = root.__preise.rates["USD" + w.toUpperCase()];
            if (!kurs)
                return { "span": span, "cur": w, "points": [], "converted": true };
        }
        var sp = (w === "eur") ? 1 : 2;
        for (j = 0; j < punkte.length; j++) {
            if (punkte[j][sp] > 0) {
                reihe.push([punkte[j][0], umgerechnet
                            ? Math.round(punkte[j][2] * kurs * 100) / 100
                            : punkte[j][sp]]);
            }
        }
        if (!reihe.length)
            return { "span": span, "cur": w, "points": [], "converted": umgerechnet };

        // Buckets of equal width, one point from each, not every nth point. The
        // spacing is uneven (hourly, daily, weekly), so any fixed step distorts the
        // time axis.
        if (reihe.length > root.__maxPunkte) {
            var t0 = reihe[0][0], t1 = reihe[reihe.length - 1][0];
            var breite = Math.max(1, (t1 - t0) / root.__maxPunkte);
            var gewaehlt = [], letztes = -1;
            for (var k = 0; k < reihe.length; k++) {
                var fach = Math.floor((reihe[k][0] - t0) / breite);
                if (fach !== letztes) {
                    gewaehlt.push(reihe[k]);
                    letztes = fach;
                }
            }
            if (gewaehlt[gewaehlt.length - 1][0] !== t1)
                gewaehlt.push(reihe[reihe.length - 1]);
            reihe = gewaehlt;
        }
        return { "span": span, "cur": w, "points": reihe, "converted": umgerechnet };
    }

    // --- Network ---
    // Hashrate, difficulty and pools for the Network tab. Same shape as the
    // service's `/network` (`network_series`), same spans, same cache times. The
    // finished response is kept per span.
    readonly property var __netSpans: ({ "30d": "1m", "90d": "3m", "1y": "1y",
                                         "3y": "3y", "max": "all" })
    property var __netCache: ({})

    function network(span, done) {
        if (!root.__netSpans[span])
            span = "1y";
        var jetzt = Date.now() / 1000;
        var alt = root.__netCache[span];
        var frist = span === "max" ? 6 * 3600 : 3600;
        var fertig = function () {
            var pools = root.__netCache.pools;
            var d = {};
            var basis = root.__netCache[span] ? root.__netCache[span].d : null;
            if (!basis) {
                done(null, "nicht erreichbar");
                return;
            }
            for (var k in basis)
                d[k] = basis[k];
            d.pools = pools ? pools.d : null;
            done(d, null);
        };
        // Pools are fetched on the side; if they fail the chart still shows. So
        // `done` can be called twice: first with the chart, then again once the pools
        // are in. The caller just takes the newer response.
        var p = root.__netCache.pools;
        if (!p || jetzt - p.ts > 1800) {
            root.__get("/v1/mining/pools/1w", function (txt) {
                try {
                    var roh = JSON.parse(txt);
                    var liste = (roh.pools || []).map(function (x) {
                        return { "name": x.name || "", "slug": x.slug || "",
                                 "blocks": root.__num(x.blockCount) };
                    });
                    liste.sort(function (a, b) {
                        return b.blocks - a.blocks;
                    });
                    var c = root.__netCache;
                    c.pools = { "ts": Date.now() / 1000,
                                "d": { "span": "1w",
                                       "blockCount": root.__num(roh.blockCount),
                                       "list": liste } };
                    root.__netCache = c;
                } catch (e) {}
                if (root.__netCache[span])
                    fertig();
            });
        }
        if (alt && jetzt - alt.ts < frist) {
            fertig();
            return;
        }
        root.__get("/v1/mining/hashrate/" + root.__netSpans[span], function (txt) {
            var roh;
            try {
                roh = JSON.parse(txt);
            } catch (e) {
                if (alt)
                    fertig();
                else
                    done(null, "Antwort nicht lesbar");
                return;
            }
            var reihe = [];
            var h = roh.hashrates || [];
            for (var i = 0; i < h.length; i++) {
                var t = root.__num(h[i].timestamp), v = root.__num(h[i].avgHashrate);
                if (t && v > 0)
                    reihe.push([t, v]);
            }
            var stufen = [];
            var s = roh.difficulty || [];
            for (var j = 0; j < s.length; j++) {
                var st = root.__num(s[j].time), sd = root.__num(s[j].difficulty);
                if (st && sd > 0)
                    stufen.push([st, sd, root.__num(s[j].height),
                                 root.__num(s[j].adjustment) || 1]);
            }
            var c = root.__netCache;
            c[span] = { "ts": Date.now() / 1000,
                        "d": { "span": span,
                               "hashrate": root.__duennenMittel(reihe, root.__maxPunkte),
                               "difficulty": stufen,
                               "current": roh.currentHashrate,
                               "currentDifficulty": roh.currentDifficulty,
                               "ts": Date.now() / 1000 } };
            root.__netCache = c;
            fertig();
        }, function () {
            // Yesterday's history is better than none.
            if (alt)
                fertig();
            else
                done(null, "nicht erreichbar");
        });
    }

    // Like `_duennen_mittel` in the service: the mean per bucket, not one picked
    // day. Hashrate is a daily estimate and jumps ten to twenty percent from day
    // to day.
    function __duennenMittel(reihe, anzahl) {
        if (reihe.length <= anzahl)
            return reihe;
        var t0 = reihe[0][0], t1 = reihe[reihe.length - 1][0];
        var breite = Math.max(1, (t1 - t0) / anzahl);
        var out = [], fach = null, summe = 0, zeiten = 0, n = 0;
        for (var i = 0; i < reihe.length; i++) {
            var f = Math.floor((reihe[i][0] - t0) / breite);
            if (f !== fach && n) {
                out.push([Math.round(zeiten / n), summe / n]);
                summe = 0;
                zeiten = 0;
                n = 0;
            }
            fach = f;
            summe += reihe[i][1];
            zeiten += reihe[i][0];
            n++;
        }
        if (n)
            out.push([Math.round(zeiten / n), summe / n]);
        return out;
    }

    function lookup(kind, arg, done) {
        if (kind === "projectedtiles") {
            // Each request extends the subscription; once the view stops asking, it is
            // unsubscribed automatically.
            var rang = parseInt(String(arg).split("-")[0], 10) || 0;
            root.__want = rang;
            root.__trackUntil = Date.now() / 1000 + root.projectedLinger;
            var fertig = root.__projectedTiles(rang);
            if (fertig)
                done(fertig, null);
            else
                done(null, "noch keine Daten");
            return;
        }
        if (kind === "blocktiles") {
            root.__get("/v1/block/" + arg + "/summary", function (txt) {
                try {
                    var liste = JSON.parse(txt);
                    done(root.__buildBlock(liste, { "id": arg }), null);
                } catch (e) {
                    done(null, "Antwort nicht lesbar");
                }
            }, function () {
                done(null, "nicht erreichbar");
            });
            return;
        }

        var pfad = root.__routes[kind];
        if (!pfad) {
            done(null, "unbekannte Abfrage");
            return;
        }
        root.__get(pfad.replace("%1", encodeURIComponent(arg)), function (txt) {
            try {
                // /block-height returns plain text, not JSON.
                done(kind === "blockheight" ? txt.trim() : JSON.parse(txt), null);
            } catch (e) {
                done(null, "Antwort nicht lesbar");
            }
        }, function (status) {
            done(null, status === 404 ? "nicht gefunden" : "nicht erreichbar");
        });
    }

    // --- Output ---
    function __push() {
        if (!root.__dirty)
            return;
        root.__dirty = false;
        root.snap = {
            "ts": Date.now() / 1000,
            "source": root.__source,
            "error": root.__error,
            "mempool": root.__mempool,
            "fees": root.__fees,
            "vbps": root.__vbps,
            "nextBlock": root.__nextBlock,
            "projected": root.__projected,
            "tip": root.__tip,
            "price": root.__price,
            "blockEvent": root.__blockEvent,
            "seq": root.__seq,
            "recent": root.__recent,
            "difficulty": root.__difficulty,
            "hashrate": root.__hashrate,
            // This feed provides no miner or wallet data. Empty rather than missing, so the
            // views show "not set up" instead of running into undefined.
            "miners": [],
            "minerHistory": {},
            "minerTotal": {},
            "wallets": [],
            "walletBusy": false
        };
    }

    // --- Connection ---
    WebSocket {
        id: sock

        url: root.wsUrl
        active: root.active

        onStatusChanged: {
            if (sock.status === WebSocket.Open) {
                root.__source = "direct";
                root.__error = "";
                root.__dirty = true;
                root.__send({ "action": "init" });
                root.__send({ "action": "want",
                              "data": ["blocks", "stats", "mempool-blocks"] });
                root.__tracked = -1;
                root.__slow();
            } else if (sock.status === WebSocket.Error) {
                root.__source = "offline";
                // Qt's error text goes to the log, not the screen. It is English
                // ("Connection refused"), untranslated and tells the reader nothing they
                // could act on. The UI only translates what it knows.
                if (sock.errorString)
                    console.log("WebSocket:", sock.errorString);
                root.__error = "Verbindung gestoert";
                root.__dirty = true;
            } else if (sock.status === WebSocket.Closed) {
                root.__source = "offline";
                root.__dirty = true;
            }
        }

        onTextMessageReceived: function (message) {
            root.__handle(message);
        }
    }

    // Reconnect when the connection is lost. Toggling `active` off and on is the
    // only way to reconnect the WebSocket.
    Timer {
        interval: 5000
        repeat: true
        running: root.active

        onTriggered: {
            if (sock.status === WebSocket.Error || sock.status === WebSocket.Closed) {
                sock.active = false;
                sock.active = true;
            }
        }
    }

    Timer {
        interval: root.pushMs
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.__push()
    }

    // Subscribing and unsubscribing the projected block. Separate from the
    // requests so it happens once per change, not on every frame.
    Timer {
        interval: 1000
        repeat: true
        running: root.active

        onTriggered: {
            if (root.__want >= 0 && Date.now() / 1000 > root.__trackUntil)
                root.__want = -1;
            if (root.__want === root.__tracked || sock.status !== WebSocket.Open)
                return;
            root.__send({ "track-mempool-block": root.__want });
            root.__tracked = root.__want;
            if (root.__want < 0)
                root.__projRows = ({});
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.active
        onTriggered: root.__slow()
    }
}
