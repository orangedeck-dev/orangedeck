// What a public-pool knows about one payout address: the devices mining to
// it, their hashrate as the pool estimates it, when it last heard from them.
//
// Shared by the device page and the pool page of `MinerView`. The device
// page uses it as the second source for a device the app cannot reach on
// the network (guest Wi-Fi, mobile data); the pool page shows it in full.
// One request for both, once a minute, only while one of them is visible.
//
// The address is only sent to this pool, which knows it from the miner
// anyway, and kept nowhere else.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick

Item {
    id: root

    visible: false

    property bool active: true
    // As entered in the settings: "pool.solomining.de", "https://public-pool.io:40557"
    property string url: ""
    property string address: ""

    // https:// added, trailing slash and "/api" removed.
    readonly property string basis: {
        var u = String(root.url || "").trim();
        if (!u)
            return "";
        if (u.indexOf("://") < 0)
            u = "https://" + u;
        return u.replace(/\/+$/, "").replace(/\/api$/i, "");
    }
    // Without the worker name: the stratum user is "address.worker", and
    // people paste it as AxeOS shows it ("bc1q….bitaxe"). An address never
    // contains a dot, so everything from the first one on goes.
    readonly property string adresse: String(root.address || "").trim().split(".")[0]
    // Host without port, to match the stratum host of the own devices: the API
    // often runs on another port than stratum (public-pool.io: 40557 and 21496).
    readonly property string wirt: {
        var m = /^[a-z]+:\/\/([^\/:]+)/i.exec(root.basis);
        return m ? m[1].toLowerCase() : "";
    }
    readonly property bool bereit: root.basis !== "" && root.adresse !== ""

    property var client: null        // /api/client/<address>
    property var chart: []           // /api/client/<address>/chart
    property string fehler: ""
    property int __runde: 0

    function zahl(v) {
        var n = parseFloat(v);
        return isFinite(n) ? n : 0;
    }

    function holen(pfad, fertig) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status !== 200) {
                fertig(null, x.status ? "HTTP " + x.status : "");
                return;
            }
            try {
                fertig(JSON.parse(x.responseText), "");
            } catch (e) {
                fertig(null, "JSON");
            }
        };
        x.open("GET", root.basis + pfad);
        x.timeout = 10000;
        x.send();
    }

    function abrufen() {
        if (!root.active || !root.bereit)
            return;
        var runde = ++root.__runde;
        var a = encodeURIComponent(root.adresse);
        root.holen("/api/client/" + a, function (d, err) {
            if (runde !== root.__runde)
                return;
            root.fehler = d ? "" : err;
            // Keep the last answer on a failed request: one lost request
            // should not make every device jump to "off".
            if (d)
                root.client = d;
        });
        root.holen("/api/client/" + a + "/chart", function (d, err) {
            if (runde === root.__runde && Array.isArray(d))
                root.chart = d;
        });
    }

    onBasisChanged: {
        root.client = null;
        root.chart = [];
        root.abrufen();
    }
    onAdresseChanged: {
        root.client = null;
        root.chart = [];
        root.abrufen();
    }
    onActiveChanged: if (root.active) root.abrufen()
    Component.onCompleted: root.abrufen()

    // public-pool writes its worker list on every share, its statistics every
    // ten minutes. A minute is plenty.
    Timer {
        interval: 60000
        repeat: true
        running: root.active && root.bereit
        onTriggered: root.abrufen()
    }

    property real jetzt: Date.now() / 1000
    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.jetzt = Date.now() / 1000
    }

    // The devices under the address, strongest first. A device the pool has
    // not heard from for ten minutes counts as gone, and so does one it saw a
    // moment ago but credits with no hashrate.
    readonly property var arbeiter: {
        var w = (root.client && root.client.workers) || [];
        var out = [];
        for (var i = 0; i < w.length; i++) {
            var zuletzt = Date.parse(w[i].lastSeen) / 1000;
            var alter = isFinite(zuletzt) ? root.jetzt - zuletzt : Infinity;
            out.push({ "name": w[i].name || "", "h": root.zahl(w[i].hashRate),
                       "best": root.zahl(w[i].bestDifficulty), "alter": alter,
                       "aktiv": alter < 600 && root.zahl(w[i].hashRate) > 0 });
        }
        out.sort(function (a, b) {
            return b.h - a.h;
        });
        return out;
    }
}
