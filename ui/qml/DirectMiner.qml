// Polls miners directly, without the daemon.
//
// On Android the Miner tab has no daemon behind it. A phone on mobile data
// cannot reach a miner on the home network, but a phone on the same Wi-Fi can,
// and standing next to the miner is exactly where you want to see its hashrate.
//
// The structure mirrors `poll_miners` and `probe_axeos` in the daemon:
// `FeedState` runs both through the same evaluation, so `MinerView` does not
// know where the numbers come from.
//
// Left to the daemon:
//   cgminer:   a raw TCP socket on port 4028. QML has no sockets; this
//              needs C++ (`QTcpSocket`).
//   discovery: `--discover-miners` scans the subnet, also over sockets.
//              Here the address comes from the settings.
import QtQuick

Item {
    id: root

    visible: false

    property bool active: true
    // Addresses as entered in the settings.
    property var hosts: []

    // Same values as the daemon (MINER_INTERVAL, MINER_HISTORY, DOMAIN_SMOOTH).
    // If they differ, the two paths drift apart without anyone noticing.
    property int intervalMs: 5000
    property int historyMax: 180
    property int domainSmooth: 12
    property int timeoutMs: 4000

    // --- Result, in the shape `FeedState` expects ---
    property var miners: []
    property var minerTotal: ({})
    property var minerHistory: ({})

    // History and domain buffers per device. Not a `property` because nothing
    // should bind to them: the view reads `minerHistory`, which is only set at
    // the end of a poll round.
    property var __hist: ({})
    property var __dom: ({})
    // History kept by the device itself, per address. See `holeStatistik`.
    property var __geraet: ({})

    // '1.23M' -> 1230000. Devices report best difficulty as text with a unit.
    // Same as `parse_diff` in the daemon.
    function parseDiff(v) {
        if (typeof v === "number")
            return v;
        if (!v)
            return 0;
        var t = String(v).trim();
        var mult = { "k": 1e3, "K": 1e3, "M": 1e6, "G": 1e9,
                     "T": 1e12, "P": 1e15, "E": 1e18 };
        var f = mult[t.slice(-1)];
        var zahl = parseFloat(f === undefined ? t : t.slice(0, -1));
        if (isNaN(zahl))
            return 0;
        return f === undefined ? zahl : zahl * f;
    }

    // AxeOS reports GH/s; everything here is in H/s.
    function gh(v) {
        return typeof v === "number" ? v * 1e9 : null;
    }

    function normalisiere(url, d) {
        // The instantaneous rate swings by about ten percent. The ten-minute value
        // is the more honest one to show; the instantaneous rate is kept alongside.
        var avg = root.gh(d.hashRate_10m) || root.gh(d.hashRate_1m)
                || root.gh(d.hashRate);

        // Keep only the host of the stratum URL. For solo mining the user name
        // contains the payout address, which must not end up in state, UI or logs.
        var pool = null;
        if (d.stratumURL) {
            var teile = String(d.stratumURL).split("//");
            pool = teile[teile.length - 1].split("/")[0] || null;
        }

        var asics = (d.hashrateMonitor && d.hashrateMonitor.asics) || [{}];
        return {
            "type": "axeos",
            "id": url,
            "name": d.hostname || d.ASICModel || d.boardVersion || "AxeOS",
            "model": d.ASICModel || d.boardVersion || "",
            "version": d.axeOSVersion || d.version || "",
            "online": true,
            "hashRate": avg || 0,
            "hashRateNow": root.gh(d.hashRate),
            "expected": root.gh(d.expectedHashrate),
            "bestDiff": root.parseDiff(d.bestDiff),
            "bestSessionDiff": root.parseDiff(d.bestSessionDiff),
            "poolDiff": root.parseDiff(d.poolDifficulty),
            "netDiffDevice": root.parseDiff(d.networkDifficulty),
            "blockFound": d.blockFound,
            "errorPct": d.errorPercentage,
            "temp": d.temp,
            "power": d.power,
            "fanRpm": d.fanrpm,
            "shares": d.sharesAccepted,
            "rejected": d.sharesRejected,
            "uptime": d.uptimeSeconds,
            "paused": d.miningPaused,
            // Seconds between two entries in the device's own log; 0 means it does not log.
            "statsFrequency": d.statsFrequency || 0,
            "pool": pool,
            "domains": (asics[0] && asics[0].domains) || []
        };
    }

    // Unreachable is a state, not an error: devices are often simply switched
    // off. The daemon handles it the same way.
    function unerreichbar(url, grund) {
        return {
            "type": "axeos",
            "id": url,
            "name": url,
            "online": false,
            "error": grund
        };
    }

    function basis(url) {
        var u = String(url).trim();
        if (u.indexOf("://") < 0)
            u = "http://" + u;
        return u.replace(/\/+$/, "");
    }

    function pfad(url) {
        return root.basis(url) + "/api/system/info";
    }

    // AxeOS 2.x keeps its own history once `statsFrequency` is set, up to
    // `statsLimit` entries (720 on a Bitaxe).
    //
    // `statsFrequency` is not the sample rate but the target span. ESP-Miner
    // (main/tasks/statistics_task.c) always samples every second; once the buffer
    // is full it thins out older entries until the span reaches
    // `statsLimit * statsFrequency` (twelve hours here), denser at the recent
    // end. So after enabling it the history grows over twelve hours and the
    // spacing is uneven, which is why MinerChart plots by timestamp. Our own
    // recording only covers the time the app was open, which after each start
    // gives just a few points.
    //
    // Only the four columns the chart needs: `columns` limits the response, the
    // timestamp always comes along. The device decides the column order, not the
    // request, so read it from `labels`.
    //
    // The timestamp counts milliseconds since device boot and `currentTimestamp`
    // is the same clock now. The difference is the entry's age; the miner has no
    // wall clock for this.
    function holeStatistik(url, jetzt) {
        var g = root.__geraet[url] || { "geholt": 0, "laeuft": 0 };
        root.__geraet[url] = g;
        // A request that never returned must not block forever.
        if (g.laeuft && jetzt - g.laeuft < 30)
            return;
        g.laeuft = jetzt;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            g.laeuft = 0;
            g.geholt = jetzt;
            if (req.status !== 200)
                return;
            try {
                var d = JSON.parse(req.responseText);
                var lab = d.labels || [];
                var zeilen = d.statistics || [];
                var iT = lab.indexOf("timestamp"), iHr = lab.indexOf("hashrate"),
                    iHr10 = lab.indexOf("hashrate_10m"), iTemp = lab.indexOf("asicTemp"),
                    iErr = lab.indexOf("errorPercentage");
                if (iT < 0 || !d.currentTimestamp)
                    return;
                var r = { "t": [], "hr": [], "hrNow": [], "temp": [], "err": [] };
                var nun = Date.now() / 1000;
                function zahl(z, i, stellen) {
                    if (i < 0 || typeof z[i] !== "number")
                        return null;
                    var f = Math.pow(10, stellen);
                    return Math.round(z[i] * f) / f;
                }
                for (var k = 0; k < zeilen.length; k++) {
                    var z = zeilen[k];
                    r.t.push(Math.round(nun - (d.currentTimestamp - z[iT]) / 1000));
                    r.hr.push(zahl(z, iHr10 >= 0 ? iHr10 : iHr, 1));
                    r.hrNow.push(zahl(z, iHr, 1));
                    r.temp.push(zahl(z, iTemp, 1));
                    r.err.push(zahl(z, iErr, 1));
                }
                g.reihe = r;
            } catch (e) {
                // No statistics is not an error: fall back to our own recording.
            }
        };
        try {
            req.open("GET", root.basis(url)
                     + "/api/system/statistics?columns=hashrate,hashrate_10m,asicTemp,errorPercentage");
            req.send();
        } catch (e2) {
            g.laeuft = 0;
        }
    }

    // One round over all addresses. Replies arrive one by one; the result is only
    // set once all are in (or timed out), otherwise the view would flicker once
    // per device.
    function lauf() {
        var liste = root.hosts || [];
        if (!root.active || liste.length === 0) {
            if (root.miners.length > 0) {
                root.miners = [];
                root.minerTotal = ({});
                root.minerHistory = ({});
            }
            return;
        }

        var offen = liste.length;
        var ergebnis = new Array(liste.length);

        for (var i = 0; i < liste.length; i++)
            frage(liste[i], i);

        function frage(url, idx) {
            var req = new XMLHttpRequest();
            var fertig = false;
            var frist = null;
            function ab(satz) {
                // Destroy the timeout on both paths. If it only goes away in the timeout
                // branch, it keeps running after a reply and fires into nothing later. At a
                // five-second interval that leaves 720 objects per hour behind.
                if (frist) {
                    frist.stop();
                    frist.destroy();
                    frist = null;
                }
                if (fertig)
                    return;
                fertig = true;
                ergebnis[idx] = satz;
                offen -= 1;
                if (offen === 0)
                    root.uebernehmen(ergebnis);
            }
            req.onreadystatechange = function () {
                if (req.readyState !== XMLHttpRequest.DONE)
                    return;
                if (req.status !== 200) {
                    ab(root.unerreichbar(url, "HTTP " + req.status));
                    return;
                }
                try {
                    ab(root.normalisiere(url, JSON.parse(req.responseText)));
                } catch (e) {
                    ab(root.unerreichbar(url, String(e)));
                }
            };
            // Own timeout: `XMLHttpRequest` in QML has no `timeout` that reports
            // reliably. Without it a round would hang as soon as one device does not
            // answer, and `offen` would never reach zero.
            frist = Qt.createQmlObject(
                'import QtQuick; Timer { }', root, "DirectMiner.frist");
            frist.interval = root.timeoutMs;
            frist.repeat = false;
            frist.triggered.connect(function () {
                req.abort();
                ab(root.unerreichbar(url, "keine Antwort"));
            });
            frist.start();
            try {
                req.open("GET", root.pfad(url));
                req.send();
            } catch (e2) {
                ab(root.unerreichbar(url, String(e2)));
            }
        }
    }

    function uebernehmen(gefunden) {
        var jetzt = Math.round(Date.now() / 1000);
        var live = [];
        var i, m;

        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m)
                continue;
            if (m.online)
                live.push(m);
        }

        // Refresh the device history as often as it can have new entries, at most
        // once a minute. The reply only takes effect in the next round.
        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m || !m.online || !(m.statsFrequency > 0))
                continue;
            var gg = root.__geraet[m.id];
            if (!gg || jetzt - gg.geholt >= Math.max(60, m.statsFrequency))
                root.holeStatistik(m.id, jetzt);
        }

        // Append to the history. Rounded like in the daemon: state is written often,
        // every digit counts.
        var hist = root.__hist;
        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m || !m.online)
                continue;
            var h = hist[m.id];
            if (!h) {
                h = { "t": [], "hr": [], "hrNow": [], "temp": [], "err": [] };
                hist[m.id] = h;
            }
            h.t.push(jetzt);
            h.hr.push(Math.round((m.hashRate || 0) / 1e9 * 10) / 10);
            h.hrNow.push(m.hashRateNow
                         ? Math.round(m.hashRateNow / 1e9 * 10) / 10 : null);
            h.temp.push(m.temp === undefined || m.temp === null
                        ? null : Math.round(m.temp * 10) / 10);
            h.err.push(m.errorPct === undefined || m.errorPct === null
                       ? null : Math.round(m.errorPct * 10) / 10);
            var felder = ["t", "hr", "hrNow", "temp", "err"];
            for (var f = 0; f < felder.length; f++) {
                var arr = h[felder[f]];
                if (arr.length > root.historyMax)
                    arr.splice(0, arr.length - root.historyMax);
            }
        }

        // Smooth the hash domains, same reason as in the daemon: a single reading
        // swings too much to draw anything from it.
        var dom = root.__dom;
        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m || !m.online || !(m.domains && m.domains.length))
                continue;
            var buf = dom[m.id];
            if (!buf) {
                buf = [];
                dom[m.id] = buf;
            }
            buf.push(m.domains);
            if (buf.length > root.domainSmooth)
                buf.splice(0, buf.length - root.domainSmooth);
            var n = buf[0].length;
            for (var b = 1; b < buf.length; b++)
                n = Math.min(n, buf[b].length);
            var mittel = [];
            for (var k = 0; k < n; k++) {
                var summe = 0;
                for (b = 0; b < buf.length; b++)
                    summe += buf[b][k];
                mittel.push(Math.round(summe / buf.length * 10) / 10);
            }
            m.domainsAvg = mittel;
            m.domainSamples = buf.length;
        }

        // Drop histories of devices that disappeared.
        var bekannt = {};
        for (i = 0; i < gefunden.length; i++)
            if (gefunden[i])
                bekannt[gefunden[i].id] = true;
        var schluessel = Object.keys(hist);
        for (i = 0; i < schluessel.length; i++)
            if (!bekannt[schluessel[i]])
                delete hist[schluessel[i]];
        schluessel = Object.keys(dom);
        for (i = 0; i < schluessel.length; i++)
            if (!bekannt[schluessel[i]])
                delete dom[schluessel[i]];
        schluessel = Object.keys(root.__geraet);
        for (i = 0; i < schluessel.length; i++)
            if (!bekannt[schluessel[i]])
                delete root.__geraet[schluessel[i]];

        var beste = 0;
        var summeHr = 0;
        for (i = 0; i < live.length; i++) {
            summeHr += live[i].hashRate || 0;
            beste = Math.max(beste, live[i].bestDiff || 0);
        }

        root.miners = gefunden;
        root.minerTotal = {
            "count": gefunden.length,
            "online": live.length,
            "hashRate": summeHr,
            "bestDiff": beste
        };
        // Copy the arrays too, not just the map. QML compares arrays by identity,
        // not content, and `MinerChart` repaints on `onHrChanged`:
        //
        //     readonly property var hr: (hist && hist.hr) || []
        //     onHrChanged: canvas.requestPaint()
        //
        // Pushing into the same array keeps its identity, so `onHrChanged` never
        // fires and the chart stays empty. The daemon path does not have this
        // problem because every poll returns a fresh JSON object.
        //
        // Copying five arrays of at most 180 numbers every five seconds costs nothing
        // measurable.
        //
        // If the device keeps a history, it is the base, and our own points are only
        // added for the time after its last entry: that is the current state it has
        // not written down yet.
        var kopie = ({});
        var felderKopie = ["t", "hr", "hrNow", "temp", "err"];
        schluessel = Object.keys(hist);
        for (i = 0; i < schluessel.length; i++) {
            var q = hist[schluessel[i]];
            var g2 = root.__geraet[schluessel[i]];
            var basisReihe = g2 && g2.reihe && g2.reihe.t.length >= 2 ? g2.reihe : null;
            var ab = 0;
            if (basisReihe) {
                var letzte = basisReihe.t[basisReihe.t.length - 1];
                while (ab < q.t.length && q.t[ab] <= letzte)
                    ab++;
            }
            var z = ({});
            for (var fk = 0; fk < felderKopie.length; fk++) {
                var eigen = (q[felderKopie[fk]] || []).slice(ab);
                z[felderKopie[fk]] = basisReihe
                    ? basisReihe[felderKopie[fk]].concat(eigen) : eigen;
            }
            kopie[schluessel[i]] = z;
        }
        root.minerHistory = kopie;
    }

    // Compare content, not identity. `minerHosts` is computed from
    // `minerHostsRaw` and returns a new array on every evaluation. QML compares
    // arrays by identity, so `onHostsChanged` fires on every re-evaluation of the
    // binding. Reacting to each of those would poll several times per second
    // (flat chart, far too many requests to the miner) and wipe the history.
    //
    // The history is only cleared when the list really changed. `hostsKey` holds
    // the list as a string, and strings are compared by content.
    property string hostsKey: ""

    onHostsChanged: {
        var jetzt = (root.hosts || []).join("|");
        if (jetzt === root.hostsKey)
            return;
        root.hostsKey = jetzt;
        root.__hist = ({});
        root.__dom = ({});
        root.__geraet = ({});
        root.lauf();
    }

    Timer {
        interval: root.intervalMs
        // Do not use `root.hosts` here. The array is a new object on every
        // evaluation, so `running` would be reassigned, and a restarted timer with
        // `triggeredOnStart` fires at once: every re-evaluation would trigger a poll.
        // `hostsKey` is a string and is compared by content.
        running: root.active && root.hostsKey.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.lauf()
    }
}
