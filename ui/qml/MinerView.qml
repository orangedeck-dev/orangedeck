// Own miners. Shows what the devices report and compares the best share
// difficulty with the network difficulty, which is the number that actually
// matters for solo mining.
//
// Not tied to one device type: the daemon speaks AxeOS (Bitaxe, NerdAxe and
// the other ESP-Miner derivatives) and the cgminer API (Antminer, Avalon,
// Whatsminer and clones) and delivers both normalized, hashrate in H/s.
// Several devices at once are supported.
//
// Two pages, "Device" and "Network". The second shows hashrate, difficulty,
// block time and pools of the whole network (`NetworkView`), so the tab has
// content even without an own miner. With no device configured there is
// only the network page and no switcher.
//
// Only `QtQuick` and `QtCore` (for Settings), so it also runs on Android.
import QtQuick
import QtCore
import "strings.js" as Tr
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Keyboard: Page Up/Down, Home, End. On the network page its own area
    // scrolls, on the device page this one (roll.js; from Main.qml via FeedTabs)
    function rollen(wie) {
        return root.paneNow === "net" ? netz.rollen(wie)
             : root.paneNow === "pool" ? poolSeite.rollen(wie) : Roll.rollen(flick, wie);
    }

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    // With touch input not below 20, as on the network page: `width / 26` is
    // about 16 in portrait on a phone, and the list of several devices ended
    // up at ten-point text (Galaxy, 03.10.2026).
    property real scaleUnit: Math.max(root.finger ? 20 : 10, Math.min(width / 26, height / 16))
    // Touch input: larger buttons on the network chart
    property bool finger: false
    // When nobody is looking, the network page fetches nothing.
    property bool live: true

    // Which page is on top: "device", "net", or empty for automatic (the device
    // page if one is configured). The host keeps the choice.
    property string pane: ""
    property string netSpan: "1y"
    signal paneRequested(string p)
    signal netSpanRequested(string s)

    // Which pages exist at all, from the settings; empty means both. Without
    // "device" the tab only shows the network, even with a miner configured;
    // without a configured miner there is only the network anyway. If the
    // network is deselected and there is no device, it stays anyway: an empty
    // page helps nobody.
    property var panes: []
    function erlaubt(p) {
        var v = root.panes;
        if (!v || !v.length || typeof v.indexOf !== "function")
            return true;
        return v.indexOf(p) >= 0;
    }
    readonly property bool mitGeraet: root.configured && root.erlaubt("device")
    // The pool page exists as soon as a pool is entered; entering it is the choice.
    property string poolUrl: ""
    property string poolAddress: ""
    readonly property bool mitPool: root.poolUrl.trim() !== ""
    readonly property bool mitNetz: root.erlaubt("net") || (!root.mitGeraet && !root.mitPool)
    readonly property var seiten: {
        var out = [];
        if (root.mitGeraet)
            out.push("device");
        if (root.mitPool)
            out.push("pool");
        if (root.mitNetz)
            out.push("net");
        return out;
    }
    readonly property bool zweiSeiten: root.seiten.length > 1
    readonly property string paneNow: root.seiten.indexOf(root.pane) >= 0 ? root.pane : root.seiten[0]
    // Solo chance on the device page, can be turned off like chart and best list.
    property bool showSolo: true
    // What the network page shows: "stats", "chart", "pools"; empty means all.
    property var netParts: []

    // The devices as the daemon or `DirectMiner` reach them on the network.
    readonly property var miners: feed ? feed.miners : []
    readonly property bool configured: feed ? feed.minerConfigured : false
    // What the page shows: `geraete`, the devices from both sources, and their sum.
    readonly property var total: {
        var g = root.geraete, live = 0, h = 0, best = 0;
        for (var i = 0; i < g.length; i++) {
            if (!g[i].online)
                continue;
            live++;
            h += g[i].hashRate || 0;
            best = Math.max(best, g[i].bestDiff || 0);
        }
        return { "count": g.length, "online": live, "hashRate": h, "bestDiff": best };
    }
    readonly property bool anyOnline: root.total.online > 0
    readonly property real netDiff: (feed && feed.hashrate.difficulty) || 0
    readonly property real netHash: (feed && feed.hashrate.current) || 0
    // The top of the page shows the open device, otherwise the sum of all.
    readonly property real shownHash: root.one ? (root.one.hashRate || 0) : (root.total.hashRate || 0)
    readonly property real shownBest: root.one ? (root.one.bestDiff || 0) : (root.total.bestDiff || 0)
    readonly property real bestShare: (netDiff > 0 && root.shownBest)
        ? root.shownBest / netDiff : 0

    // Solo chance. Own hashrate divided by network hashrate is the share of each
    // block; with 144 blocks a day that gives the chance per day and its inverse,
    // the mean waiting time. Both are expected values of a memoryless random
    // process: after a thousand years the chance for the next day is the same.
    readonly property real soloAnteil: (root.netHash > 0 && root.shownHash > 0)
        ? root.shownHash / root.netHash : 0
    readonly property real soloTag: root.soloAnteil * 144

    // "16.600 Jahre", "64 Tage", "5 Std 20 Min"
    function warte(tage) {
        if (!(tage > 0) || !isFinite(tage))
            return "–";
        if (tage >= 730) {
            var jahre = tage / 365.25;
            return Tr.t("duration.years", root.lang,
                        jahre >= 1e6 ? Tr.big(jahre, root.lang) : Tr.group(jahre, root.lang));
        }
        if (tage >= 2)
            return Tr.t("duration.days", root.lang, Tr.group(tage, root.lang));
        return root.span(tage * 86400);
    }
    // ------------------------------------------------ Second source: the pool
    //
    // A device the app cannot reach on the network (guest Wi-Fi with client
    // isolation, phone on mobile data) still mines, and the pool shows what
    // it gets. With a pool and a payout address in the settings such a device
    // keeps its row, with the pool's numbers and the pool named as source.
    // Reachable again, the row goes back to the device's own numbers on the
    // next poll. Never both at once.
    //
    // Which row belongs to which device at the pool: the worker name, the part
    // of the stratum user after the dot ("bitaxe" in "bc1q….bitaxe"). It is
    // remembered from the last time the device was reached and kept across
    // restarts, so the match still holds after leaving the house. A device
    // that was never reached here has no name yet; if as many such devices
    // remain as unknown devices at the pool, they are paired in order. With
    // one each, the common case, that is exact.
    PoolKlient {
        id: poolKlient

        url: root.poolUrl
        address: root.poolAddress
        active: root.live && root.visible && root.mitPool
                && (root.paneNow === "device" || root.paneNow === "pool")
    }

    // Name, worker and pool host of each device as last reached, by its id.
    Settings {
        id: gemerkt

        category: "minerPool"
        property string zuordnungJson: "{}"
    }
    readonly property var zuordnung: {
        try {
            return JSON.parse(gemerkt.zuordnungJson) || ({});
        } catch (e) {
            return ({});
        }
    }
    function wirtVon(p) {
        return String(p || "").split(":")[0].toLowerCase();
    }
    // Same pool if the hosts match or one is a subdomain of the other: the
    // statistics often sit on "web." or "api." in front of the stratum host.
    function gleicherPool(stratum) {
        var a = root.wirtVon(stratum), b = poolKlient.wirt;
        if (!a || !b)
            return false;
        return a === b || a.endsWith("." + b) || b.endsWith("." + a);
    }
    onMinersChanged: {
        var zu = root.zuordnung, anders = false;
        for (var i = 0; i < root.miners.length; i++) {
            var m = root.miners[i];
            if (!m.online)
                continue;
            var alt = zu[m.id];
            if (!alt || alt.name !== m.name || alt.pool !== m.pool || alt.worker !== (m.worker || "")) {
                zu[m.id] = { "name": m.name, "pool": m.pool || "", "worker": m.worker || "" };
                anders = true;
            }
        }
        if (anders)
            gemerkt.zuordnungJson = JSON.stringify(zu);
    }

    function poolEintrag(m, w, z) {
        var name = (z && z.name) || "";
        if (!name && m && m.name && m.name !== m.id)
            name = m.name;
        return {
            "id": m ? m.id : "pool:" + w.name,
            "type": "pool",
            "quelle": "pool",
            "name": name || w.name || "–",
            "online": w.aktiv,
            "hashRate": w.aktiv ? w.h : 0,
            "bestDiff": w.best,
            "alter": w.alter,
            "pool": (z && z.pool) || poolKlient.wirt,
            "worker": w.name
        };
    }

    readonly property var geraete: {
        var lokal = root.miners;
        if (!poolKlient.bereit || !poolKlient.client)
            return lokal;
        var zu = root.zuordnung;
        var frei = poolKlient.arbeiter.slice();
        function nimm(name) {
            for (var k = 0; k < frei.length; k++)
                if (frei[k].name === name)
                    return frei.splice(k, 1)[0];
            return null;
        }
        // Devices reached on the network claim their worker first.
        for (var i = 0; i < lokal.length; i++) {
            var m = lokal[i];
            if (m.online && m.worker && root.gleicherPool(m.pool))
                nimm(m.worker);
        }
        var out = [], offen = [];
        for (i = 0; i < lokal.length; i++) {
            m = lokal[i];
            if (m.online) {
                out.push(m);
                continue;
            }
            var z = zu[m.id];
            var w = (z && z.worker && root.gleicherPool(z.pool)) ? nimm(z.worker) : null;
            if (w) {
                out.push(root.poolEintrag(m, w, z));
            } else {
                // Never reached with a worker name: a candidate for pairing.
                if (!(z && z.worker))
                    offen.push(out.length);
                out.push(m);
            }
        }
        var aktiv = frei.filter(function (x) {
            return x.aktiv;
        });
        if (offen.length > 0 && offen.length === aktiv.length) {
            for (i = 0; i < offen.length; i++) {
                out[offen[i]] = root.poolEintrag(out[offen[i]], aktiv[i], zu[out[offen[i]].id]);
                frei.splice(frei.indexOf(aktiv[i]), 1);
            }
        }
        // Devices only the pool knows, not entered here at all.
        for (i = 0; i < frei.length; i++)
            if (frei[i].aktiv)
                out.push(root.poolEintrag(null, frei[i], null));
        return out;
    }
    readonly property bool mitPoolQuelle: {
        for (var i = 0; i < root.geraete.length; i++)
            if (root.geraete[i].quelle === "pool" && root.geraete[i].online)
                return true;
        return false;
    }
    readonly property real poolAnteil: {
        var h = 0;
        for (var i = 0; i < root.geraete.length; i++)
            if (root.geraete[i].quelle === "pool" && root.geraete[i].online)
                h += root.geraete[i].hashRate || 0;
        return h;
    }
    function vor(sek) {
        if (!isFinite(sek))
            return "–";
        if (sek < 60)
            return Tr.t("net.justNow", root.lang);
        return Tr.t("net.ago", root.lang, root.span(sek));
    }

    // With several devices the page lists them, and a tap on one opens its
    // details: the same view a single device gets. The choice is only kept
    // while that device is online; then the list comes back.
    readonly property bool several: root.geraete.length > 1
    property string openId: ""
    // List and details differ in height; each starts at the top.
    onOpenIdChanged: flick.contentY = 0
    readonly property var opened: {
        if (!root.several || !root.openId)
            return null;
        for (var i = 0; i < root.geraete.length; i++)
            if (root.geraete[i].id === root.openId && root.geraete[i].online)
                return root.geraete[i];
        return null;
    }
    // The device whose details are shown: the only one, or the opened one.
    readonly property var one: root.several ? root.opened
                             : ((root.geraete.length === 1 && root.geraete[0].online) ? root.geraete[0] : null)
    readonly property bool onePool: root.one !== null && root.one.quelle === "pool"
    // Power of all running devices and what it costs per terahash. Only when
    // every running device reports its power: a sum with gaps would make the
    // efficiency look better than it is. The cgminer API has no power field,
    // the pool neither.
    readonly property var sumPower: {
        var w = 0, n = 0, live = 0;
        for (var i = 0; i < root.geraete.length; i++) {
            var m = root.geraete[i];
            if (!m.online)
                continue;
            live++;
            if (m.power > 0) {
                w += m.power;
                n++;
            }
        }
        return { "watt": w, "complete": live > 0 && n === live };
    }
    // A device seen only through the pool has no history of its own here. With
    // a single device under the address the address chart is its chart.
    readonly property var oneHist: {
        if (!root.one || !root.feed)
            return ({});
        if (root.onePool) {
            if (poolKlient.arbeiter.length !== 1)
                return ({});
            var p = (poolKlient.chart || []).map(function (x) {
                return { "t": Date.parse(x.label) / 1000, "v": parseFloat(x.data) / 1e9 };
            }).filter(function (x) {
                return isFinite(x.t) && isFinite(x.v);
            }).sort(function (a, b) {
                return a.t - b.t;
            });
            return { "t": p.map(function (x) { return x.t; }),
                     "hr": p.map(function (x) { return Math.round(x.v * 10) / 10; }),
                     "hrNow": [], "temp": [] };
        }
        return root.feed.minerHistory[root.one.id] || ({});
    }
    // Name and pool as last reported. A device that is off reports neither, and
    // without this it would show its address and drop out of its pool's group
    // for as long as it is gone.
    function nameVon(m) {
        var b = root.zuordnung[m.id];
        return (m.online ? m.name : (b && b.name)) || m.name || m.id;
    }
    function poolVon(m) {
        var b = root.zuordnung[m.id];
        return (m.online ? m.pool : (b && b.pool)) || m.pool || "";
    }

    // The list, grouped by pool once the devices mine on more than one. Each
    // entry carries the pool as `kopf` if it opens a group. Unknown pool (device
    // off, or the cgminer API, which does not report it) sorts last.
    readonly property var liste: {
        var reihen = root.geraete.slice();
        var pools = [];
        for (var i = 0; i < reihen.length; i++) {
            var p = root.poolVon(reihen[i]);
            if (pools.indexOf(p) < 0)
                pools.push(p);
        }
        var gruppiert = pools.length > 1;
        if (gruppiert) {
            // Stable: within a pool the order from the settings stays.
            var rang = function (m) {
                var p = root.poolVon(m);
                return p ? pools.indexOf(p) : pools.length;
            };
            reihen = reihen.map(function (m, k) {
                return { "m": m, "k": k };
            }).sort(function (a, b) {
                return (rang(a.m) - rang(b.m)) || (a.k - b.k);
            }).map(function (x) {
                return x.m;
            });
        }
        var out = [], vorher = null;
        for (var j = 0; j < reihen.length; j++) {
            var pool = root.poolVon(reihen[j]);
            out.push({ "m": reihen[j], "kopf": gruppiert && pool !== vorher ? (pool || "–") : "" });
            vorher = pool;
        }
        return out;
    }

    // Hashrate of all running devices over time, for the list view.
    //
    // Each device has its own timestamps: every five seconds from our own polling,
    // once a minute from a device that records its own history, and the devices
    // were not switched on together. So the sum is taken on a common grid, with
    // each device's value interpolated between its two neighbouring points, and only over the
    // span every running device covers. Outside it the sum would lack a device and
    // the curve would drop for no real reason. No temperature: a single line for
    // several devices would mean nothing.
    readonly property var sumHist: {
        if (!root.several || !root.feed)
            return ({});
        var reihen = [];
        var von = -Infinity, bis = Infinity;
        // Only devices reached directly: the pool's estimate has its own chart
        // on the pool page, and a sum of both would mix a measurement with a
        // guess.
        for (var i = 0; i < root.geraete.length; i++) {
            var m = root.geraete[i];
            if (!m.online || m.quelle === "pool")
                continue;
            var h = root.feed.minerHistory[m.id];
            if (!h || !h.t || h.t.length < 2)
                return ({});
            reihen.push(h);
            von = Math.max(von, h.t[0]);
            bis = Math.min(bis, h.t[h.t.length - 1]);
        }
        if (reihen.length < 2 || !(bis - von >= 60))
            return ({});
        var n = 120, zeit = [], summe = [];
        var pos = reihen.map(function () {
            return 0;
        });
        for (var k = 0; k < n; k++) {
            var tg = von + (bis - von) * k / (n - 1);
            var sum = 0, voll = true;
            for (var r = 0; r < reihen.length; r++) {
                var hr = reihen[r];
                // pos[r]: first point after tg. The one before it is at or before tg.
                while (pos[r] < hr.t.length && hr.t[pos[r]] <= tg)
                    pos[r]++;
                var a = pos[r] - 1, b = pos[r];
                var va = a >= 0 ? hr.hr[a] : null;
                var vb = b < hr.t.length ? hr.hr[b] : null;
                if (va === null || va === undefined) {
                    voll = false;
                    continue;
                }
                if (vb === null || vb === undefined || hr.t[b] === hr.t[a])
                    sum += va;
                else
                    sum += va + (vb - va) * (tg - hr.t[a]) / (hr.t[b] - hr.t[a]);
            }
            if (!voll)
                continue;
            zeit.push(Math.round(tg));
            summe.push(Math.round(sum * 10) / 10);
        }
        return { "t": zeit, "hr": summe, "hrNow": [], "temp": [] };
    }
    // If the host already has a button bar (the DMS one in the dashboard), it
    // provides the buttons itself and turns ours off. They then sit in the top
    // row where nothing can cover them.
    property bool showActions: true
    // For the host: expand or collapse the legend.
    function toggleInfo() {
        info.open = !info.open;
    }
    // Open the device's web UI. Works for any miner that has one.
    //
    // Add the scheme. The id is the address as entered, on the phone often
    // without "http://". `DirectMiner` prepends it for its own requests
    // (`basis()`). Without it Qt treats the bare address as a path relative to
    // the QML file, and Android fails with "No Activity found to handle Intent
    // { dat=qrc:/... }".
    readonly property string webUrl: {
        if (!(root.one && root.one.type === "axeos"))
            return "";
        var u = String(root.one.id).trim();
        return u.indexOf("://") < 0 ? "http://" + u : u;
    }
    function openWeb() {
        if (webUrl)
            Qt.openUrlExternally(webUrl);
    }
    readonly property bool roomForChart: height > 200
    // Minutes over which the hash domains are averaged: one sample every five
    // seconds, in the daemon as in `DirectMiner`.
    readonly property real domainMin: root.one && root.one.domainSamples
        ? root.one.domainSamples * 5 / 60 : 0

    // Which metrics are shown. An empty list means all; the selection comes from
    // the settings, this is only the filter.
    property var metricKeys: []
    property bool showChart: true
    property bool showDomains: true
    property bool showBoard: true
    property string lang: "de"

    readonly property var metrics: {
        var m = root.one;
        // The pool knows hashrate and best share, nothing of the device itself.
        if (!m || root.onePool)
            return [];
        var alle = [
            { "id": "temp", "k": Tr.t("miner.temp", root.lang), "v": (m.temp !== undefined && m.temp !== null)
                ? Math.round(m.temp) + " °C" : "–" },
            { "id": "power", "k": Tr.t("miner.power", root.lang), "v": m.power
                ? Tr.fixed(m.power, 1, root.lang) + " W" : "–" },
            { "id": "fan", "k": Tr.t("miner.fan", root.lang), "v": m.fanRpm ? Tr.t("miner.rpm", root.lang, m.fanRpm) : "–" },
            { "id": "error", "k": Tr.t("miner.errorRate", root.lang), "v": (m.errorPct !== undefined && m.errorPct !== null)
                ? Tr.fixed(m.errorPct, 1, root.lang) + " %" : "–" },
            { "id": "shares", "k": Tr.t("miner.shares", root.lang), "v": m.shares !== undefined
                ? (m.rejected ? Tr.t("miner.rejected", root.lang, m.shares, m.rejected)
                              : String(m.shares)) : "–" },
            { "id": "uptime", "k": Tr.t("miner.uptime", root.lang), "v": root.span(m.uptime) }
        ];
        var mk = root.metricKeys;
        if (!mk || !mk.length || typeof mk.indexOf !== "function")
            return alle;
        return alle.filter(function (x) {
            return mk.indexOf(x.id) >= 0;
        });
    }

    // From six metrics on, split into rows of three; below that one row. On a
    // narrow screen rows of two: "84213 (12 rejected)" alone takes half of it.
    readonly property bool schmal: root.width < root.scaleUnit * 22
    readonly property var metricRows: {
        var m = root.metrics;
        var je = root.schmal ? 2 : 3;
        if (!root.schmal && m.length < 6)
            return m.length ? [m] : [];
        var out = [];
        for (var i = 0; i < m.length; i += je)
            out.push(m.slice(i, i + je));
        return out;
    }
    readonly property bool roomForBoard: height > 240

    function big(n, unit) {
        if (!n)
            return "–";
        var u = ["", "k", "M", "G", "T", "P", "E"], i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return Tr.fixed(n, n >= 100 ? 0 : 2, root.lang)
             + " " + u[i] + (unit || "");
    }

    function span(sec) {
        if (!sec)
            return "–";
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600),
            m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
    }

    // All explanations in one place instead of scattered over the page.
    InfoPopup {
        id: info

        anchors.fill: parent
        buttonMargin: 0
        showButton: root.showActions
        fontSize: root.scaleUnit * 0.72
        textColor: root.textColor
        dimColor: root.dimColor
        lang: root.lang
        title: Tr.t("miner.whatIsThis", root.lang)
        // Explanations for the page currently on top.
        entries: root.paneNow === "pool" ? [
            {
                "k": Tr.t("miner.panePool", root.lang),
                "v": Tr.t("pool.help", root.lang)
            }
        ] : root.paneNow === "net" ? [
            {
                "color": root.accentColor,
                "k": Tr.t("hashrate", root.lang),
                "v": Tr.t("net.hashHelp", root.lang)
            },
            {
                "color": netz.diffColor,
                "thin": true,
                "k": Tr.t("difficulty", root.lang),
                "v": Tr.t("net.diffHelp", root.lang)
            },
            {
                "k": Tr.t("pool", root.lang),
                "v": Tr.t("net.poolsHelp", root.lang)
            }
        ] : [
            {
                "color": root.accentColor,
                "thin": true,
                "k": Tr.t("miner.hashNow", root.lang),
                "v": Tr.t("miner.hashNowHelp", root.lang)
            },
            {
                "color": root.accentColor,
                "k": Tr.t("miner.hashAvg", root.lang),
                "v": Tr.t("miner.hashAvgHelp", root.lang)
            },
            {
                "color": root.textColor,
                "k": Tr.t("miner.temp", root.lang),
                "v": Tr.t("miner.tempHelp", root.lang)
            },
            {
                "k": Tr.t("miner.oneToN", root.lang),
                "v": Tr.t("miner.oneToNHelp", root.lang)
            },
            {
                "k": Tr.t("miner.solo", root.lang),
                "v": Tr.t("miner.soloHelp", root.lang)
            },
            {
                "k": Tr.t("miner.domains", root.lang),
                "v": Tr.t("miner.domainsHelp", root.lang)
            },
            {
                "k": Tr.t("miner.errorRate", root.lang),
                "v": Tr.t("miner.errorHelp", root.lang)
            }
        ]
        z: 40
    }

    Rectangle {
        id: openBtn

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: info.buttonWidth + root.scaleUnit * 0.4
        visible: root.showActions && root.webUrl !== "" && root.paneNow === "device"
        width: info.buttonWidth
        height: width
        radius: height / 2
        color: openArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 20

        // Drawn, not a glyph. "↗" (U+2197) has an emoji presentation, and Samsung
        // uses it: a blue box with a white arrow next to the plain "i". The stroke
        // matches the color and weight of the "i" next to it.
        Canvas {
            id: pfeil

            anchors.centerIn: parent
            width: parent.width * 0.42
            height: width
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width, s = Math.max(1.5, w * 0.16), r = s / 2;
                ctx.strokeStyle = root.textColor;
                ctx.lineWidth = s;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(r, w - r);
                ctx.lineTo(w - r, r);
                ctx.moveTo(w * 0.38, r);
                ctx.lineTo(w - r, r);
                ctx.lineTo(w - r, w * 0.62);
                ctx.stroke();
            }
        }

        MouseArea {
            id: openArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWeb()
        }
    }

    // --- Device | Network ---
    // Only when there are two pages. Fixed at the top, both pages scroll below it.
    readonly property real kopfHoehe: root.zweiSeiten ? umschalter.height + root.scaleUnit * 0.5 : 0

    TileGoggles {
        id: umschalter

        visible: root.zweiSeiten
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: umschalter.schalterBreite
        modes: root.seiten.map(function (k) {
            return { "k": k, "l": Tr.t(k === "device" ? "miner.paneDevice"
                                     : k === "pool" ? "miner.panePool" : "miner.paneNet", root.lang) };
        })
        mode: root.paneNow
        labelKey: ""
        counts: []
        total: 0
        lang: root.lang
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.finger ? Math.max(15, root.scaleUnit * 0.62) : root.scaleUnit * 0.62
        minTap: root.finger ? 40 : 0
        z: 20
        onPicked: function (m) {
            root.paneRequested(m);
        }
    }

    // --- Network ---
    // Without a configured device, a hint below explains how to add one: in the
    // settings on the phone, via the service's discovery on the desktop.
    NetworkView {
        id: netz

        anchors.fill: parent
        visible: root.paneNow === "net"
        live: root.live && root.visible && root.paneNow === "net"
        // Without the switcher the page starts at the top, where the i button sits
        // and needs its row.
        topInset: root.zweiSeiten ? root.kopfHoehe
                                  : (root.showActions ? info.buttonWidth + root.scaleUnit * 0.3 : 0)
        feed: root.feed
        lang: root.lang
        span: root.netSpan
        parts: root.netParts
        finger: root.finger
        // With touch input not below 20. `scaleUnit` follows the width; in portrait
        // on a phone that is about 16, and the labels of metrics and pools ended up
        // at barely nine. The desktop is unchanged.
        scaleUnit: root.finger ? Math.max(20, root.scaleUnit) : root.scaleUnit
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        footer: root.configured ? ""
              : (root.feed && root.feed.direkt)
                ? Tr.t("net.addMiner", root.lang, Tr.t("tab.settings", root.lang),
                       Tr.t("tab.miner", root.lang))
                : Tr.t("miner.none", root.lang) + ". " + Tr.t("miner.discover", root.lang)
        footerCommand: (!root.configured && !(root.feed && root.feed.direkt))
            ? "orangedeck --discover-miners --write\nsystemctl --user restart orangedeck" : ""
        onSpanRequested: function (sp) {
            root.netSpanRequested(sp);
        }
    }

    // --- Pool ---
    PoolView {
        id: poolSeite

        anchors.fill: parent
        visible: root.paneNow === "pool"
        live: root.live && root.visible && root.paneNow === "pool"
        topInset: root.zweiSeiten ? root.kopfHoehe
                                  : (root.showActions ? info.buttonWidth + root.scaleUnit * 0.3 : 0)
        url: root.poolUrl
        klient: poolKlient
        miners: root.miners
        netDiff: root.netDiff
        lang: root.lang
        finger: root.finger
        scaleUnit: root.finger ? Math.max(20, root.scaleUnit) : root.scaleUnit
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        goodColor: root.goodColor
        badColor: root.badColor
    }

    // --- Configured, but all offline ---
    Column {
        anchors.centerIn: parent
        spacing: root.scaleUnit * 0.35
        visible: root.configured && !root.anyOnline && root.paneNow === "device"

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t(root.miners.length === 1 ? "miner.notReachable"
                                               : "miner.unreachable", root.lang)
            color: root.badColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("miner.offNote", root.lang)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }

        // Not reachable here, but the pool sees them.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.mitPool && root.poolAddress.trim() !== ""
            text: Tr.t("miner.seePool", root.lang)
            color: root.accentColor
            font.pixelSize: root.scaleUnit * 0.62

            MouseArea {
                anchors.fill: parent
                anchors.margins: -root.scaleUnit * 0.3
                cursorShape: Qt.PointingHandCursor
                onClicked: root.paneRequested("pool")
            }
        }
    }

    // --- Running ---
    // The content can be taller than the area: the dashboard tab (410 px) is not
    // enough for chart, hash domains and best list at once. So it scrolls: if
    // everything fits it stays centered, otherwise it can be dragged.
    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin: root.kopfHoehe
        clip: true
        visible: root.anyOnline && root.paneNow === "device"
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500

        // Thin bar on the right, only while there is something to scroll.
        Rectangle {
            parent: flick
            anchors.right: parent.right
            width: Math.max(2, root.scaleUnit * 0.16)
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: flick.contentHeight > flick.height + 1
            y: flick.contentY + flick.height * (flick.contentY / flick.contentHeight)
            height: flick.height * (flick.height / flick.contentHeight)
            z: 30
        }

        Column {
            id: body

                width: flick.width * 0.9
                x: (flick.width - width) / 2
                // Centered while there is room, otherwise start at the top. Pinning it to the
                // top leaves the lower half empty when only the device page is shown.
                y: Math.max(root.scaleUnit * 0.3, (flick.height - implicitHeight) / 2)
                spacing: root.scaleUnit * 0.45

            // Back to the list. Large enough for a finger on the phone.
            Text {
                visible: root.opened !== null
                text: Tr.t("miner.allDevices", root.lang)
                color: zurueckArea.containsMouse ? root.textColor : root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
                height: root.finger ? Math.max(40, implicitHeight) : implicitHeight
                verticalAlignment: Text.AlignVCenter

                MouseArea {
                    id: zurueckArea

                    anchors.fill: parent
                    anchors.margins: -root.scaleUnit * 0.3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openId = ""
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.one ? (root.one.name || root.one.id)
                    : root.total.online > 1
                    ? Tr.t("miner.devices", root.lang, root.total.online)
                    : (root.geraete[0] ? root.nameVon(root.geraete[0]) : Tr.t("miner.title", root.lang))
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.72
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.big(root.shownHash, "H/s")
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 2.6
                font.bold: true
            }

            // Where the numbers come from when the pool stands in for the device,
            // or how much of the sum is its estimate.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.onePool || (root.one === null && root.mitPoolQuelle)
                text: root.onePool
                    ? Tr.t("miner.sourcePool", root.lang, poolKlient.wirt, root.vor(root.one.alter))
                    : Tr.t("miner.inclPool", root.lang, root.big(root.poolAnteil, "H/s"), poolKlient.wirt)
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            // The instantaneous rate swings by about ten percent, so the top shows the
            // smoothed ten-minute value, and this compares it with what the device
            // should deliver at its clock setting.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.expected
                text: root.one && root.one.expected
                    ? Tr.t("miner.smoothed", root.lang, root.big(root.one.expected, "H/s"))
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            // All devices together: power and what one terahash costs.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.several && root.one === null && root.sumPower.complete
                         && root.total.hashRate > 0
                text: visible
                    ? Tr.fixed(root.sumPower.watt, 1, root.lang) + " W · "
                      + Tr.fixed(root.sumPower.watt / (root.total.hashRate / 1e12), 1, root.lang) + " J/TH"
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            // The reason anyone does this.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.blockFound > 0
                width: blockText.width + root.scaleUnit
                height: blockText.height + root.scaleUnit * 0.4
                radius: height / 2
                color: root.goodColor

                Text {
                    id: blockText

                    anchors.centerIn: parent
                    text: root.one && root.one.blockFound > 0
                        ? (root.one.blockFound === 1
                            ? Tr.t("miner.oneBlockFound", root.lang)
                            : Tr.t("miner.blocksFound", root.lang, root.one.blockFound))
                        : ""
                    color: "#0b0b12"
                    font.pixelSize: root.scaleUnit * 0.62
                    font.bold: true
                }
            }

            // The number that matters for solo mining.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.bestShare", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.shownBest
                        ? Tr.t("miner.ofNet", root.lang, root.big(root.shownBest),
                               root.big(root.netDiff))
                        : "–"
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.bestShare > 0
                    // Tiny shares: "1 in N" reads better than a percentage with eight zeros.
                    text: root.bestShare >= 1
                        ? Tr.t("miner.enoughForBlock", root.lang)
                        : Tr.t("miner.oneInN", root.lang, root.big(1 / root.bestShare))
                    color: root.bestShare >= 1 ? root.goodColor : root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            // Chance that one of the next blocks is ours. Below one block a day it shows
            // "1 in N per day" with the mean waiting time below; above that the waiting
            // time alone is enough.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.showSolo && root.soloTag > 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.solo", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.soloTag >= 1
                        ? Tr.t("miner.soloEvery", root.lang, root.warte(1 / root.soloTag))
                        : Tr.t("miner.soloDay", root.lang, root.big(1 / root.soloTag))
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.soloTag > 0 && root.soloTag < 1
                    text: Tr.t("miner.soloEvery", root.lang, root.warte(1 / root.soloTag))
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // --- Details, single device ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2
                visible: root.one !== null

                // The metrics. From six on they are split into rows of three: in a single
                // row they ran past the edge in the dashboard and the outer two were cut
                // off. Up to five stay in one row.
                Column {
                    width: parent.width
                    spacing: root.scaleUnit * 0.45

                    Repeater {
                        model: root.metricRows

                        Row {
                            id: zeile

                            required property var modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.scaleUnit * 1.1

                            Repeater {
                                model: zeile.modelData

                                Column {
                                    id: cell

                                    required property var modelData

                                    spacing: root.scaleUnit * 0.1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.k
                                        color: root.dimColor
                                        font.pixelSize: root.scaleUnit * 0.55
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.v
                                        color: root.textColor
                                        font.pixelSize: root.scaleUnit * 0.8
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Only the pool host: for solo mining the user name contains the payout
                    // address and is never shown.
                    text: root.one
                        ? [root.one.model, root.one.version, root.one.pool].filter(function (x) {
                              return !!x;
                          }).join(" · ")
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }
            }

            // --- History ---
            // One device: its own history. The list of several: their sum.
            MinerChart {
                readonly property var reihe: root.one !== null ? root.oneHist : root.sumHist

                width: parent.width
                height: root.scaleUnit * 4.2
                visible: root.showChart && root.roomForChart
                         && (root.one !== null || root.several)
                         && (reihe.hr || []).length > 1
                hist: reihe
                lang: root.lang
                lineColor: root.accentColor
                dimColor: root.dimColor
                labelSize: root.scaleUnit * 0.5
            }

            // Where a longer history would come from. If the device does not record its
            // own, the chart only reaches back as far as the app has been open. The
            // switch is in AxeOS, not here: the app does not change settings on the miner
            // behind the user's back. Only `DirectMiner` reports `statsFrequency`; the
            // daemon does not, and then this line is hidden.
            Text {
                width: parent.width
                visible: root.showChart && root.one !== null && root.roomForChart
                         && root.one.statsFrequency === 0
                text: Tr.t("miner.statsHint", root.lang)
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.45
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            // --- Individual hash domains ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.one !== null && (root.one.domains || []).length > 0
                         && root.roomForChart && root.showDomains

                Text {
                    // The chip is split internally into hash domains (four on the BM1370). Single
                    // readings fluctuate by more than ten percent, so the smoothed value is shown;
                    // otherwise noise looks like a defect.
                    // Minutes formatted per language, whole numbers from one minute up.
                    // With several chips one bar per chip (`domainsAreChips`).
                    text: root.one && root.one.domainSamples
                        ? Tr.t(root.one.domainsAreChips ? "miner.chipsAvg" : "miner.domainsAvg",
                               root.lang, root.domainMin >= 1
                               ? Math.round(root.domainMin)
                               : Tr.fixed(root.domainMin, 1, root.lang))
                        : Tr.t(root.one && root.one.domainsAreChips ? "miner.chips" : "miner.domains",
                               root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Row {
                    width: parent.width
                    spacing: root.scaleUnit * 0.25

                    Repeater {
                        model: root.one ? (root.one.domainsAvg || root.one.domains) : []

                        Rectangle {
                            id: dom

                            required property var modelData
                            required property int index

                            readonly property var vals: root.one.domainsAvg || root.one.domains || []

                            width: (root.width * 0.9 - root.scaleUnit * 0.75) / Math.max(1, dom.vals.length)
                            height: root.scaleUnit * 0.95
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Rectangle {
                                // Share relative to the strongest domain, so a weak one stands out at once.
                                width: parent.width * Math.max(0.05, Math.min(1,
                                    dom.modelData / Math.max.apply(null, dom.vals)))
                                height: parent.height
                                radius: parent.radius
                                color: root.accentColor
                                opacity: 0.75
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(dom.modelData) + " GH/s"
                                color: root.textColor
                                font.pixelSize: root.scaleUnit * 0.5
                            }
                        }
                    }
                }
            }

            // --- Best list ---
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.12
                visible: root.showBoard && root.one !== null && root.roomForBoard
                         && (root.one.scoreboard || []).length > 0

                Text {
                    text: Tr.t("miner.bestList", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Repeater {
                    model: root.one ? (root.one.scoreboard || []).slice(0, 5) : []

                    Row {
                        id: sbRow

                        required property var modelData
                        required property int index

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Text {
                            width: root.scaleUnit * 1.2
                            text: (sbRow.index + 1) + "."
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: root.big(sbRow.modelData.diff)
                            color: sbRow.index === 0 ? root.accentColor : root.textColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: root.netDiff > 0
                                ? Tr.t("miner.oneTo", root.lang,
                                       root.big(root.netDiff / sbRow.modelData.diff))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: sbRow.modelData.time
                                ? Qt.formatDate(new Date(sbRow.modelData.time * 1000), Tr.datum(root.lang))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }
                    }
                }
            }

            // --- Individual devices ---
            // A tap on a running device opens its details.
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.1

                visible: root.one === null

                Repeater {
                    model: root.liste

                    Item {
                        id: eintrag

                        required property var modelData

                        width: parent.width
                        height: (kopfText.visible ? kopfText.height + root.scaleUnit * 0.25 : 0) + line.height

                        // The pool above its devices, only the host: the user name
                        // holds the payout address.
                        Text {
                            id: kopfText

                            visible: eintrag.modelData.kopf !== ""
                            width: parent.width
                            y: 0
                            text: eintrag.modelData.kopf
                            elide: Text.ElideRight
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.5
                            topPadding: root.scaleUnit * 0.2
                        }

                        Item {
                            id: line

                            readonly property var modelData: eintrag.modelData.m

                            y: kopfText.visible ? kopfText.height + root.scaleUnit * 0.25 : 0
                            width: parent.width
                            height: root.finger ? Math.max(40, reihe.implicitHeight)
                                                : reihe.implicitHeight + root.scaleUnit * 0.3

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -root.scaleUnit * 0.3
                                anchors.rightMargin: -root.scaleUnit * 0.3
                                radius: root.scaleUnit * 0.25
                                color: zeileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            }

                            Row {
                                id: reihe

                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: root.scaleUnit * 0.5

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.scaleUnit * 0.32
                                    height: width
                                    radius: width / 2
                                    color: line.modelData.online ? root.goodColor : root.badColor
                                }

                                Text {
                                    width: root.scaleUnit * 7
                                    elide: Text.ElideRight
                                    text: root.nameVon(line.modelData)
                                    color: root.textColor
                                    font.pixelSize: root.scaleUnit * 0.62
                                }

                                Text {
                                    width: root.scaleUnit * 4
                                    text: line.modelData.online ? root.big(line.modelData.hashRate, "H/s") : Tr.t("miner.off", root.lang)
                                    color: root.dimColor
                                    font.pixelSize: root.scaleUnit * 0.62
                                }

                                // A row the pool stands in for says so where the
                                // temperature would be; the pool does not know it.
                                Text {
                                    readonly property bool ausPool: line.modelData.quelle === "pool"

                                    visible: line.modelData.online && (ausPool
                                             || (line.modelData.temp !== undefined && line.modelData.temp !== null))
                                    width: ausPool ? implicitWidth : root.scaleUnit * 2.4
                                    text: ausPool ? Tr.t("miner.viaPool", root.lang)
                                        : (line.modelData.temp !== undefined && line.modelData.temp !== null
                                           ? Math.round(line.modelData.temp) + " °C" : "")
                                    color: ausPool ? root.accentColor : root.dimColor
                                    font.pixelSize: root.scaleUnit * 0.62
                                }

                                // Left out on a narrow screen, the row would run off the edge.
                                Text {
                                    visible: line.modelData.online && !root.schmal
                                    // From the pool: when it last heard from the device.
                                    text: line.modelData.quelle === "pool" ? root.vor(line.modelData.alter)
                                                                           : root.span(line.modelData.uptime)
                                    color: root.dimColor
                                    font.pixelSize: root.scaleUnit * 0.62
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: line.modelData.online
                                text: "›"
                                color: zeileArea.containsMouse ? root.textColor : root.dimColor
                                font.pixelSize: root.scaleUnit * 0.8
                            }

                            MouseArea {
                                id: zeileArea

                                anchors.fill: parent
                                enabled: line.modelData.online
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.openId = line.modelData.id
                            }
                        }
                    }
                }
            }
        }
    }
}
