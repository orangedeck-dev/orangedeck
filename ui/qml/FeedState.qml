// Liest den von orangedeck gelieferten Zustand und meldet neue Transaktionen
// sowie gefundene Bloecke als Signale weiter.
//
// Bewusst nur `import QtQuick`: diese Datei laeuft damit unveraendert in der
// DankMaterialShell, in der eigenstaendigen Qt-Anwendung und unter Android.
// Sie kannte frueher Quickshell (env, FileView, Process) -- alle drei sind
// ersetzt:
//
//   Quickshell.env  ->  entfaellt, der Ort steckt in `endpoint`
//   FileView        ->  XMLHttpRequest gegen die Loopback-Schnittstelle.
//                       Lesen von file:// scheidet aus: Qt sperrt das hinter
//                       QML_XHR_ALLOW_FILE_READ=1, ohne die Variable bleibt
//                       der Aufruf auf readyState 1 stehen (01.09.2026
//                       nachgemessen). Ueber HTTP gibt es diesen Sonderfall
//                       nicht -- auf keinem Desktop und auch nicht auf Android.
//   Process         ->  gehoert nicht hierher. Den Daemon starten in der
//                       Shell OrangeDeckDaemon.qml und beim eigenen Fenster
//                       orangedeck-window; beide taten das ohnehin schon.
import QtQuick

Item {
    id: root

    visible: false

    property bool active: true
    // Standard ist die Loopback-Schnittstelle des lokalen Daemons. Fuer ein
    // Tablet zeigt das stattdessen auf den Rechner im eigenen Netz -- eine
    // bewusste Einstellung, kein Standardverhalten.
    property string endpoint: "http://127.0.0.1:21021"
    property int pollMs: 400

    // Woher die Daten kommen:
    //
    //   "daemon"  der eigene Dienst auf 127.0.0.1. Vorgabe auf dem Rechner --
    //             er haelt **eine** Verbindung fuer alle Fenster und Widgets,
    //             kann Wallets ableiten und den Miner im Heimnetz abfragen.
    //   "direct"  die Oberflaeche redet selbst mit mempool.space. Vorgabe auf
    //             dem Handy: dort gibt es keinen Dienst, und ein Widget, das
    //             nur laeuft, solange der Heimrechner an ist, ist keines.
    //   "auto"    erst der Dienst, und wenn binnen `autoMs` keiner antwortet,
    //             direkt weiter. Fuer das **DMS-Plugin**: wer es aus dem
    //             Verzeichnis von DMS installiert, hat nur den Ordner -- kein
    //             Repo, keine Unit, kein orangedeck im Pfad. Ein Widget, das
    //             dann leer bleibt, waere keines. Wer den Dienst hat, bekommt
    //             ihn weiterhin samt Wallet.
    //
    // Nach aussen ist der Unterschied keiner: beide Quellen laufen durch
    // dieselbe Auswertung, alle Ansichten lesen dieselben Eigenschaften.
    property string mode: "daemon"
    property int autoMs: 4000

    // **Einmal je Sitzung entschieden, und dann dabei geblieben.** Ein
    // Umschalten hin und her bei jedem Aussetzer des Dienstes wuerde den
    // Wallet-Reiter kommen und gehen lassen -- und `FeedTabs.reiterPruefen`
    // wirft eine gemerkte Ansicht dabei auf den Feed zurueck. Startet der
    // Dienst spaeter, greift die Entscheidung beim naechsten Start der Shell.
    property string __autoMode: ""
    readonly property bool __suchtDienst: root.mode === "auto" && root.__autoMode === ""
    readonly property string effMode: root.mode !== "auto" ? root.mode
        : (root.__autoMode || "daemon")
    readonly property bool direkt: root.effMode === "direct"

    // Solange gesucht wird, laeuft die Abfrage des Dienstes -- eine eigene
    // Anfrage nur zum Anklopfen braucht es nicht, die erste Antwort auf
    // `/state` ist die Antwort auf die Frage.
    Timer {
        interval: root.autoMs
        repeat: false
        running: root.active && root.__suchtDienst

        onTriggered: {
            if (root.__suchtDienst)
                root.__autoMode = "direct";
        }
    }
    // Was der Direktbezug nicht kann -- die Ansichten blenden sich danach aus.
    //
    // **Der Miner steht nicht mehr pauschal hier drin.** Die Begruendung war
    // "das Geraet steht im Heimnetz, da hilft kein Direktbezug" -- und die
    // stimmt fuer ein Handy im Mobilfunknetz. Im selben WLAN ist es
    // erreichbar, und `DirectMiner` fragt es dort selbst ab. Was fehlt, ist
    // nicht der Weg, sondern die Adresse: ohne Eintrag gibt es nichts zu
    // fragen, mit Eintrag schon.
    //
    // `canMiner` ist seit dem 11.09.2026 weg: der Miner-Reiter zeigt ohne
    // Geraet das Netz und hat damit immer einen Inhalt.
    // `__suchtDienst` gehoert dazu: waehrend der Suche ist `direkt` noch
    // falsch, aber ob es einen Dienst gibt, weiss noch niemand. Ein
    // Wallet-Reiter, der nach vier Sekunden wieder verschwindet, ist
    // schlimmer als einer, der vier Sekunden spaeter kommt.
    readonly property bool canWallet: !root.direkt && !root.__suchtDienst
    // Der Markt geht seit dem 13.09.2026 auch direkt (`DirectMarket.qml`).
    // Fehlt QtWebSockets, scheitert dessen Loader, und der Reiter bleibt weg.
    //
    // **Nicht auf `Loader.Ready` warten.** So stand es zuerst, und in dem
    // Augenblick, bevor der Loader fertig war, gab es keinen Markt-Reiter:
    // `FeedTabs.reiterPruefen` warf eine gemerkte Ansicht Markt auf den Feed
    // zurueck, bei jedem Start. Gesehen im Pruefstand am 13.09.2026.
    readonly property bool canMarket: !root.direkt || markt.status !== Loader.Error

    // Die Adressen aus den Einstellungen. Im Daemon-Betrieb bleiben sie
    // ungenutzt -- dort liest der Dienst `sources.json`.
    property var minerHosts: []

    // Ausgelesener Zustand
    property var snap: ({})
    property var block: ({})          // Kacheldaten des zuletzt gefundenen Blocks
    property int seq: 0
    property real stateTs: 0
    property real blockEventTs: 0
    property bool online: false
    property string source: ""
    property string lastError: ""

    readonly property int mempoolCount: (snap.mempool && snap.mempool.count) || 0
    readonly property int mempoolVsize: (snap.mempool && snap.mempool.vsize) || 0
    readonly property real feeFastest: (snap.fees && snap.fees.fastest) || 0
    readonly property real feeHour: (snap.fees && snap.fees.hour) || 0
    readonly property int vbps: snap.vbps || 0
    readonly property var tip: snap.tip || ({})
    readonly property var nextBlock: snap.nextBlock || ({})
    // Die ganze Reihe der geplanten Bloecke, wie sie ueber den WebSocket
    // hereinkommt -- dieselben Feldnamen wie in `/lookup/mempoolblocks/now`,
    // nur ohne eigene Abfrage und damit im Takt des Zustands.
    readonly property var projected: snap.projected || []
    readonly property var price: snap.price || ({})
    readonly property int tipHeight: tip.height || 0
    // Langsame Kennzahlen und der eigene Miner -- der Daemon holt sie nebenher
    readonly property var difficulty: snap.difficulty || ({})
    readonly property var hashrate: snap.hashrate || ({})
    // Miner: eine Liste, weil man mehr als ein Geraet haben kann. Der Daemon
    // liefert alle Felder normalisiert, Hashrate immer in H/s.
    // Im Direktbezug kommen sie von `DirectMiner`, sonst aus dem Zustand des
    // Daemons. Die Form ist dieselbe -- `MinerView` merkt den Unterschied
    // nicht, genau wie beim Mempool.
    readonly property var miners: root.direkt
        ? (bergwerk.item ? bergwerk.item.miners : [])
        : (snap.miners || [])
    readonly property var minerTotal: root.direkt
        ? (bergwerk.item ? bergwerk.item.minerTotal : ({}))
        : (snap.minerTotal || ({}))
    // Kurzfassung der beobachteten Wallets. Die vollen Angaben holt die
    // Wallet-Ansicht ueber `/wallets` -- sie sind zu gross fuer den Zustand.
    readonly property var wallets: snap.wallets || []
    readonly property bool walletBusy: snap.walletBusy || false
    readonly property bool walletConfigured: wallets.length > 0
    // Verlauf je Geraet -- vom Daemon mitgeschrieben, im Direktbezug von
    // `DirectMiner`.
    readonly property var minerHistory: root.direkt
        ? (bergwerk.item ? bergwerk.item.minerHistory : ({}))
        : (snap.minerHistory || ({}))
    readonly property bool minerConfigured: miners.length > 0
    readonly property bool minerOnline: (minerTotal.online || 0) > 0

    signal transactionsArrived(var txs)
    signal blockMined(var tip)

    // -- Abholen ----------------------------------------------------------
    // Eine Abfrage nach der anderen: bei 400 ms Takt und einem haengenden
    // Netzweg wuerden sich sonst Anfragen stapeln.
    property bool __statePending: false
    property bool __blockPending: false
    // Stand der langsamen Felder, den wir schon haben -- der Dienst laesst sie
    // dann weg. -1 heisst "noch keinen".
    property int __slowRev: -1

    function __get(path, pendingKey, onOk, onFail) {
        if (root[pendingKey])
            return;
        root[pendingKey] = true;
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            root[pendingKey] = false;
            if (x.status === 200 && x.responseText)
                onOk(x.responseText);
            else if (onFail)
                onFail();
        };
        try {
            x.open("GET", root.endpoint + path);
            x.send();
        } catch (e) {
            root[pendingKey] = false;
            if (onFail)
                onFail();
        }
    }

    // Eine beliebige Abfrage gegen den Daemon, JSON zurueck. Getrennt von
    // `lookup`, weil das die Pfade nach draussen meint -- hier geht es um die
    // eigenen Pfade des Dienstes (`/wallets`, `/market...`).
    function getJson(path, done) {
        if (root.direkt) {
            // Der Markt rechnet im Direktbezug selbst, mit denselben Antworten.
            if (path.indexOf("/market") === 0 && markt.item) {
                markt.item.getJson(path, done);
                return;
            }
            // `/wallets`: die Ableitung aus dem xpub ist Punktarithmetik auf
            // secp256k1 und bleibt im Dienst.
            done(null, "im Direktbezug nicht verfuegbar");
            return;
        }
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status !== 200) {
                done(null, "nicht erreichbar");
                return;
            }
            try {
                done(JSON.parse(x.responseText), null);
            } catch (e) {
                done(null, "Antwort nicht lesbar");
            }
        };
        try {
            x.open("GET", root.endpoint + path);
            x.send();
        } catch (e) {
            done(null, String(e));
        }
    }

    // Kursverlauf. `span` ist einer von 24h, 7d, 30d, 90d, 1y, max.
    //
    // **Nicht im Zustand**, und zwar mit Absicht: der wird zweieinhalbmal je
    // Sekunde geholt, der Verlauf aendert sich stuendlich einmal. Er kommt
    // deshalb nur, wenn jemand die Kurve auch ansieht.
    function prices(span, cur, done) {
        if (root.direkt) {
            if (direkt.item)
                direkt.item.prices(span, cur, done);
            else
                done(null, "Direktbezug nicht bereit");
            return;
        }
        root.getJson("/prices?span=" + span + "&cur=" + cur, done);
    }

    // Hashrate, Schwierigkeit und Pools fuer den Reiter "Netz". `span` ist
    // einer von 30d, 90d, 1y, 3y, max. Aus demselben Grund wie der
    // Kursverlauf nicht im Zustand: er kommt nur, wenn jemand hinsieht.
    function network(span, done) {
        if (root.direkt) {
            if (direkt.item)
                direkt.item.network(span, done);
            else
                done(null, "Direktbezug nicht bereit");
            return;
        }
        root.getJson("/network?span=" + span, done);
    }

    // Einzelabfrage fuer den Explorer. Geht ueber den Daemon, nicht direkt
    // nach draussen -- er kennt die Datenquelle (mempool.space oder ein
    // eigener Node) und puffert die Antworten.
    function lookup(kind, arg, done) {
        if (root.direkt) {
            if (direkt.item)
                direkt.item.lookup(kind, String(arg), done);
            else
                done(null, "Direktbezug nicht bereit");
            return;
        }
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status === 200) {
                try {
                    done(JSON.parse(x.responseText), null);
                    return;
                } catch (e) {
                    done(null, "Antwort nicht lesbar");
                    return;
                }
            }
            var msg = "nicht erreichbar";
            try {
                msg = JSON.parse(x.responseText).error || msg;
            } catch (e) {}
            done(null, msg);
        };
        try {
            x.open("GET", root.endpoint + "/lookup/" + kind + "/" + encodeURIComponent(arg));
            x.send();
        } catch (e) {
            done(null, String(e));
        }
    }

    function __parse(txt) {
        if (!txt)
            return;
        var d;
        try {
            d = JSON.parse(txt);
        } catch (e) {
            return;
        }
        root.__apply(d);
    }

    // Der eigentliche Kern -- er sieht nicht, woher der Zustand kommt. Der
    // Dienst liefert ihn als JSON, der Direktbezug baut ihn selbst zusammen;
    // ab hier ist es derselbe Weg.
    function __apply(d) {
        if (!d || typeof d !== "object")
            return;

        // Was der Dienst weggelassen hat, bleibt aus dem vorigen Stand stehen.
        // Er kuerzt zwei Dinge: die schon bekannten Transaktionen (`?since`)
        // und die langsamen Felder, solange sie sich nicht geaendert haben
        // (`?slow`). Gemessen am 02.09.2026: 32 kB alle 400 ms kosteten 20 %
        // CPU, gekuerzt sind es rund 2 kB.
        var alt = root.snap;
        if (alt && typeof alt === "object") {
            for (var k in alt) {
                if (d[k] === undefined)
                    d[k] = alt[k];
            }
        }
        if (typeof d.slowRev === "number")
            root.__slowRev = d.slowRev;

        root.snap = d;
        root.stateTs = d.ts || 0;
        root.source = d.source || "";
        root.lastError = d.error || "";
        root.online = (Date.now() / 1000 - root.stateTs) < 12 && root.source !== "offline";
        // Es kam eine Antwort vom Dienst -- damit ist die Frage aus `mode:
        // "auto"` beantwortet, und zwar bevor der Zeitgeber oben ablaeuft.
        if (root.__suchtDienst)
            root.__autoMode = "daemon";

        var fresh = [];
        var rec = d.recent || [];
        for (var i = 0; i < rec.length; i++) {
            if (rec[i].n > root.seq)
                fresh.push(rec[i]);
        }
        var newSeq = d.seq || root.seq;
        // Beim allerersten Laden nicht den ganzen Puffer auf einmal einregnen lassen
        if (root.seq === 0) {
            fresh = fresh.slice(-12);
        }
        root.seq = newSeq;
        if (fresh.length > 0)
            root.transactionsArrived(fresh);

        var be = d.blockEvent || 0;
        if (be > root.blockEventTs) {
            var first = root.blockEventTs === 0;
            root.blockEventTs = be;
            if (!first)
                root.blockMined(d.tip || {});
        }
    }

    Timer {
        interval: root.pollMs
        repeat: true
        running: root.active && !root.direkt
        triggeredOnStart: true
        onTriggered: root.__get("/state?since=" + root.seq + "&slow=" + root.__slowRev,
                                "__statePending", root.__parse, function () {
            root.online = false;
        })
    }

    // Der Direktbezug liegt in einer eigenen Datei, weil er `QtWebSockets`
    // braucht -- ein Paket, das nicht ueberall installiert ist. Als Loader
    // faellt bei einem fehlenden Modul nur diese Betriebsart aus, nicht die
    // ganze Anwendung.
    Loader {
        id: direkt

        active: root.direkt
        source: "DirectFeed.qml"
        onStatusChanged: {
            if (direkt.status === Loader.Error) {
                root.lastError = "Direktbezug nicht verfuegbar (QtWebSockets fehlt)";
                root.online = false;
            }
        }
    }

    // Der Miner im eigenen Netz. Eigener Loader neben `direkt`, damit ein
    // Fehler hier nicht den Mempool mitnimmt -- dieselbe Begruendung wie
    // dort. Er laeuft nur im Direktbezug: im Daemon-Betrieb fragt der Dienst.
    Loader {
        id: bergwerk

        active: root.direkt
        source: "DirectMiner.qml"
        onLoaded: {
            bergwerk.item.hosts = Qt.binding(function () {
                return root.minerHosts || [];
            });
            bergwerk.item.active = Qt.binding(function () {
                return root.active;
            });
        }
    }

    // Der Markt. Eigener Loader aus demselben Grund wie die beiden oben: faellt
    // er aus, bleiben Mempool und Miner stehen.
    Loader {
        id: markt

        active: root.direkt
        source: "DirectMarket.qml"
        onLoaded: {
            markt.item.active = Qt.binding(function () {
                return root.active;
            });
            markt.item.preise = Qt.binding(function () {
                return root.price;
            });
        }
    }

    Connections {
        target: direkt.item

        function onSnapChanged() {
            root.__apply(direkt.item.snap);
        }

        function onBlockChanged() {
            if (direkt.item.block && direkt.item.block.height)
                root.block = direkt.item.block;
        }
    }

    // Der Daemon holt die Blockdaten nach dem Blockfund im Hintergrund nach,
    // deshalb wird hier nachgefasst, bis die Hoehe passt.
    Timer {
        interval: 3000
        repeat: true
        running: root.active && !root.direkt
        triggeredOnStart: true
        onTriggered: {
            if (root.block.height && root.block.height === root.tipHeight)
                return;
            root.__get("/block", "__blockPending", function (txt) {
                try {
                    var b = JSON.parse(txt);
                    if (b && b.height)
                        root.block = b;
                } catch (e) {}
            });
        }
    }
}
