// Eigenstaendiges Fenster. Portierung von shell/quickshell/shell.qml auf
// gewoehnliches Qt Quick:
//
//   ShellRoot/FloatingWindow  ->  Window
//   FileView (view.json)      ->  Settings aus QtCore (QSettings), portabel
//                                 und auch unter Android verfuegbar
//
// FeedState, FeedPanel, FeedCanvas sind unveraendert dieselben Dateien wie im
// DMS-Plugin -- sie liegen einmal unter ui/qml und werden hier nur zusaetzlich
// ins QML-Modul gepackt.
import QtQuick
import QtCore
import "strings.js" as Tr

Window {
    id: win

    width: 1100
    height: 800
    minimumWidth: 260
    minimumHeight: 160
    visible: true
    title: qsTr("OrangeDeck")

    // Deckkraft macht das Fenster selbst; ob geblurrt wird, entscheidet der
    // Compositor. Kacheln und Schrift bleiben deckend.
    //
    // **Die Vorgabe ist deckend.** Der milchige Eindruck entsteht erst, wenn
    // der Compositor hinter dem Fenster weichzeichnet -- niri tut das hier,
    // GNOME und die meisten anderen tun es nicht. Dort heisst 0,82 nur:
    // man liest das Fenster dahinter mit, quer durch die Graphen. In der
    // Pruef-VM am 04.09.2026 stand das Terminal mitten im Mempool. Wer den
    // milchigen Look will, holt ihn mit einem Zug am Regler oder mit `-`.
    color: Qt.rgba(0.043, 0.043, 0.071, win.bgOpacity)

    property string colorMode: "age"
    property string sizeMode: "value"
    property bool showInfo: true
    property bool showLegend: true
    property bool showRuler: true
    property bool frosted: true
    property real bgOpacity: 1.0
    property real density: 1.0
    // -1 heisst: die zuletzt benutzte Ansicht. Sonst faengt das Fenster
    // immer bei derselben an und merkt sich gar nichts mehr.
    property int startView: -1
    // "daemon" oder "direct" -- siehe FeedState.mode
    // **Den Dienst gibt es nur unter Linux.** `orangedeck` laeuft als
    // systemd-Benutzerdienst; auf einem Telefon, unter Windows und unter macOS
    // kann er nicht laufen, und 127.0.0.1:21021 antwortet dort nie. Wer die
    // App dort frisch startet, bekaeme "keine Verbindung zum Feed" und muesste
    // die Einstellung erst finden -- ein Fehlerbild als Willkommensgruss.
    //
    // Der Direktbezug ist ueberall sonst nicht die Ausnahme, sondern der
    // Regelfall. Am 04.09.2026 im Android-Emulator aufgefallen; **die Abfrage
    // stand danach erst auf "android" und haette Windows und macOS beim ersten
    // Bau genauso getroffen.** Richtig ist die Frage nach dem Dienst, nicht
    // nach dem Geraet.
    property string dataSource: Qt.platform.os === "linux" ? "daemon" : "direct"

    // **Kein Gerät mit Tastatur.** Die Abfrage stand schon beim Suchfeld des
    // Explorers; mit dem Tastaturhinweis wird sie zum zweiten Mal gebraucht,
    // und eine Bedingung, die zweimal dasteht, laeuft irgendwann auseinander.
    readonly property bool ohneTastatur: Qt.platform.os === "android"
                                      || Qt.platform.os === "ios"
    // **Ausserhalb von Linux gibt es nur den Direktbezug** (15.09.2026). Bis
    // dahin liess sich unter Android und Windows ein Dienst auf einem anderen
    // Rechner eintragen, fuer Markt und Wallet. Der Markt kommt seit dem
    // 13.09. ohne Dienst; die Wallet ging dafuer unverschluesselt durchs
    // WLAN, liess sich nur am Rechner eintragen, und der Weg funktionierte
    // nie (`daemonHost` fehlte in `setOpt`). Entschieden: der Dienst-Weg
    // faellt dort weg (die Wallet ist seit dem 26.09.2026 ganz entfernt).
    // Ein gespeichertes "daemon" von frueher wird uebergangen, statt es
    // umzuschreiben.
    readonly property bool dienstMoeglich: Qt.platform.os === "linux"
    readonly property string effSource: !win.dienstMoeglich ? "direct"
                                        : (win.forcedSource.length ? win.forcedSource
                                                                   : win.dataSource)
    // Vorgabe USD wie in FeedTabs, SettingsView, den DMS-Ansichten, dem
    // Dashtab und DeckWidget.waehrung(). Am 09.09.2026 wurden die fuenf dort
    // umgestellt und diese sechste Stelle vergessen: die Anwendung zeigte
    // ohne Einstellung EUR, das Widget daneben USD.
    property string currency: "usd"
    property string tileColorMode: "fee"
    property bool clockBars: true
    // Leere Liste heisst: alles zeigen
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string clockFieldsRaw: ""
    readonly property var clockFields: clockFieldsRaw.length ? clockFieldsRaw.split("|") : []
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string minerFieldsRaw: ""
    readonly property var minerFields: minerFieldsRaw.length ? minerFieldsRaw.split("|") : []

    // **Die Adressen der Miner, und zwar hier.** Bisher standen sie an drei
    // Stellen, von denen keine ein Handy erreicht: in
    // `~/.config/orangedeck/sources.json`, in `ORANGEDECK_MINER` und im
    // Ergebnis von `orangedeck --discover-miners`. Auf Android gibt es weder
    // eine Befehlszeile noch diese Datei -- und `--discover-miners` braucht
    // rohe Sockel, die QML nicht hat.
    //
    // Eine vierte Quelle daneben zu stellen waere genau die Vervielfachung,
    // an der dieses Projekt schon mehrfach hing (dieselbe Liste dreimal in
    // `views.js`, die Klemme auf 5 in `shell.qml`). Also wird diese hier die
    // **fuehrende**: sie liegt in den QSettings wie alles andere, damit hat
    // sie jedes Geraet. Der Daemon liest `sources.json` zusaetzlich weiter,
    // damit bestehende Einrichtungen nichts merken.
    //
    // Mehrere Adressen mit `|` getrennt, wie `minerFieldsRaw`.
    property string minerHostsRaw: ""
    readonly property var minerHosts: {
        var out = [];
        var teile = minerHostsRaw.split("|");
        for (var i = 0; i < teile.length; i++) {
            var t = teile[i].trim();
            if (t.length)
                out.push(t);
        }
        return out;
    }

    // **Wo der Dienst lauscht.** Leer heisst 127.0.0.1:21021 -- derselbe
    // Rechner, und das bleibt die Vorgabe.
    //
    // Eingetragen wird hier der Rechner im eigenen Netz. Damit bekommt ein
    // Tablett oder ein Telefon die Daten des Dienstes. Der Weg war
    // von Anfang an vorgesehen -- `FeedState.endpoint` und `ORANGEDECK_ADDR`
    // tragen beide seit dem 01.09.2026 den Satz "fuer ein Tablet im eigenen
    // Netz eine bewusste Entscheidung" --, nur fuehrte keine Einstellung
    // dorthin.
    //
    // **Es ist eine Entscheidung mit Folgen**, und deshalb steht sie im
    // Hilfetext und nicht im Kleingedruckten: der Dienst muss dafuer im Netz
    // lauschen, und dann liefert er jedem, der ihn fragt, alles, was er
    // weiss. Ein Heimnetz ist kein Personenkreis.
    property string daemonHost: ""
    // The mempool instance for every mode: FeedState.mempoolHost. The Android
    // widgets read the same key from this settings file (DeckWidget.api).
    property string mempoolHost: ""
    readonly property string effEndpoint: {
        var h = win.daemonHost.trim();
        if (!h.length)
            return "http://127.0.0.1:21021";
        if (h.indexOf("://") < 0)
            h = "http://" + h;
        // Den Port nur im Teil **nach** dem Schema suchen: sonst findet der
        // Doppelpunkt von "http://" sich selbst, und an "http://tablett"
        // haengte nie ein Port.
        var ohneSchema = h.substring(h.indexOf("://") + 3);
        if (ohneSchema.indexOf(":") < 0)
            h += ":21021";
        return h;
    }

    property bool showHeader: true
    property bool showFooter: true
    property bool showBlock: true
    property bool clockSpark: true
    property bool clockTime: false
    property bool clockPrice: true
    property string priceSpan: "30d"
    // Markt-Reiter: Zeitraum, Darstellung, eigener Zeitraum in Sekunden
    property string marketRange: "24h"
    property string marketKind: "candles"
    // Volumenbalken oder CVD unter dem Kurs
    property string marketLower: "volume"
    // Unterreiter im Markt: Kurs oder Liquidationen
    property string marketSub: "price"
    property int marketSecs: 259200
    // Ausdrueckliches Fenster im Markt, 0 = keins
    property int marketVon: 0
    property int marketBis: 0
    property bool marketCross: true
    property bool marketTape: true
    property bool showFeed: true
    property bool showClock: true
    property bool showMiner: true
    property bool showExplorer: true
    property bool showMarket: true
    property bool minerChart: true
    property bool minerDomains: true
    property bool minerBoard: true
    // Miner-Reiter: welche Seite ("" von selbst, "device", "net") und der
    // Zeitraum des Netz-Graphen
    property string minerPane: ""
    property string netSpan: "1y"
    property bool explorerLive: true
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string explorerPartsRaw: ""
    // Mining-Reiter: welche Seiten ("device", "net") und was auf der
    // Netz-Seite ("stats", "chart", "pools"). Leer heisst alles; abgelegt
    // wie `explorerPartsRaw`, aus denselben zwei Gruenden.
    property string minerPanesRaw: ""
    readonly property var minerPanes: minerPanesRaw.length ? minerPanesRaw.split("|") : []
    property string netPartsRaw: ""
    readonly property var netParts: netPartsRaw.length ? netPartsRaw.split("|") : []
    property bool minerSolo: true
    // Reiter im Wechsel: Sekunden (0 aus) und welche Stationen
    property int tabRotate: 0
    property string tabRotateViewsRaw: ""
    readonly property var tabRotateViews: tabRotateViewsRaw.length ? tabRotateViewsRaw.split("|") : []
    readonly property var explorerParts: explorerPartsRaw.length ? explorerPartsRaw.split("|") : []
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string explorerPanelsRaw: ""
    readonly property var explorerPanels: explorerPanelsRaw.length ? explorerPanelsRaw.split("|") : []
    // **Gewaehlt ist nur, was jemand waehlt.** Leer heisst: die Sprache des
    // Systems. Bis zum 10.09.2026 stand hier `lang` mit der Systemsprache als
    // Vorgabe -- und QML-Settings schreibt beim Beenden auch Vorgaben in die
    // ini. Danach war die Sprache festgeschrieben: das Telefon auf en_US
    // umgestellt, die Anwendung blieb deutsch. Gespeichert wird deshalb nur
    // noch die Wahl, unter neuem Schluessel; das alte `lang` stand bei jeder
    // Installation, auch ohne dass je jemand gewaehlt haette, und wird nicht
    // mehr gelesen. Die Widgets lesen denselben Schluessel (Texte.java).
    property string langWahl: ""
    readonly property string lang: win.langWahl.length ? win.langWahl : Tr.systemLang()
    // Grosse Anzeige der Uhr -- als Zeichenkette abgelegt, siehe
    // die uebrigen Listen.
    property string bigFieldsRaw: "height"
    readonly property var bigFields: bigFieldsRaw.length ? bigFieldsRaw.split("|") : ["height"]
    property int bigRotate: 0
    // Die Reihenfolge der Reiter, vom Anwender festgelegt. Leer heisst: die
    // Grundreihenfolge aus `views.js`. Als Zeichenkette abgelegt, getrennt
    // mit "|" -- aus denselben zwei Gruenden wie die uebrigen Listen: eine
    // leere Liste schreibt QSettings als `@Invalid()`, und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als Listentrenner.
    property string tabOrderRaw: ""
    readonly property var tabOrder: tabOrderRaw.length ? tabOrderRaw.split("|") : []
    // 0 = Feed, 1 = Uhr, 2 = Miner, 3 = Explorer, 5 = Einstellungen,
    // 6 = Markt (4 war bis 26.09.2026 die Wallet und bleibt frei). Wird
    // gemerkt, damit ein Tablet nach dem Einschalten gleich wieder als
    // Uhr hochkommt.
    property int view: 0
    // Das Suchfeld des Explorers hat den Fokus -- dann gilt eine andere Tastenhilfe
    property bool sucheOffen: false
    // Von der Befehlszeile gesetzt (`--view`, `--bare`) und **nicht**
    // gespeichert: ein Widget an der Wand soll seine Ansicht behalten, ohne
    // die zuletzt benutzte Ansicht des grossen Fensters umzuschreiben.
    property int forcedView: -1
    property bool bare: false
    // Von der Befehlszeile (`--source`), ebenfalls nicht gespeichert
    property string forcedSource: ""
    // Vom Netz-Widget: die Seite "Netz" im Miner-Reiter. **Diese wird
    // gespeichert** -- anders als `forcedView` ist sie keine Eigenschaft eines
    // Widgets an der Wand, sondern die zuletzt gewaehlte Seite, wie ein Tipp
    // auf den Umschalter.
    property string forcedPane: ""

    // **Vollbild als Blockuhr.** Ohne Systemleisten und ohne Reiterzeile,
    // und solange es an ist, bleibt der Bildschirm an (das setzt main.cpp,
    // QML kann das Fensterflag nicht). Gespeichert, damit ein altes Tablet
    // nach dem Einschalten gleich wieder als Uhr an der Wand steht -- wie
    // `view` darueber. Heraus geht es mit dem Knopf, der nach einem Tipp
    // erscheint, mit der Zurueck-Geste oder mit F11.
    property bool vollbild: false

    function vollbildAnwenden() {
        if (win.bare)
            return;
        win.visibility = win.vollbild ? Window.FullScreen : Window.Windowed;
    }

    onVollbildChanged: vollbildAnwenden()

    // Bleibt auf dem Geraet: QSettings schreibt nach
    // ~/.config/orangedeck/orangedeck.conf (Linux) bzw. in den App-Speicher (Android).
    Settings {
        id: prefs
        category: "view"
        property alias colorMode: win.colorMode
        property alias sizeMode: win.sizeMode
        property alias showInfo: win.showInfo
        property alias showLegend: win.showLegend
        property alias bgOpacity: win.bgOpacity
        property alias view: win.view
        property alias showRuler: win.showRuler
        property alias frosted: win.frosted
        property alias density: win.density
        property alias startView: win.startView
        property alias dataSource: win.dataSource
        property alias currency: win.currency
        property alias tileColorMode: win.tileColorMode
        property alias clockBars: win.clockBars
        property alias clockFieldsRaw: win.clockFieldsRaw
        property alias minerFieldsRaw: win.minerFieldsRaw
        property alias minerHostsRaw: win.minerHostsRaw
        property alias daemonHost: win.daemonHost
        property alias mempoolHost: win.mempoolHost
        property alias showHeader: win.showHeader
        property alias showFooter: win.showFooter
        property alias showBlock: win.showBlock
        property alias clockSpark: win.clockSpark
        property alias clockTime: win.clockTime
        property alias clockPrice: win.clockPrice
        property alias priceSpan: win.priceSpan
        property alias marketRange: win.marketRange
        property alias marketKind: win.marketKind
        property alias marketLower: win.marketLower
        property alias marketSub: win.marketSub
        property alias marketSecs: win.marketSecs
        property alias marketVon: win.marketVon
        property alias marketBis: win.marketBis
        property alias marketCross: win.marketCross
        property alias marketTape: win.marketTape
        property alias showFeed: win.showFeed
        property alias showClock: win.showClock
        property alias showMiner: win.showMiner
        property alias showExplorer: win.showExplorer
        property alias showMarket: win.showMarket
        property alias minerChart: win.minerChart
        property alias minerDomains: win.minerDomains
        property alias minerBoard: win.minerBoard
        property alias minerPane: win.minerPane
        property alias netSpan: win.netSpan
        property alias explorerLive: win.explorerLive
        property alias explorerPartsRaw: win.explorerPartsRaw
        property alias minerPanesRaw: win.minerPanesRaw
        property alias netPartsRaw: win.netPartsRaw
        property alias minerSolo: win.minerSolo
        property alias tabRotate: win.tabRotate
        property alias tabRotateViewsRaw: win.tabRotateViewsRaw
        property alias explorerPanelsRaw: win.explorerPanelsRaw
        property alias langWahl: win.langWahl
        property alias bigFieldsRaw: win.bigFieldsRaw
        property alias bigRotate: win.bigRotate
        property alias tabOrderRaw: win.tabOrderRaw
        property alias vollbild: win.vollbild
    }

    // Beim Start in die gemerkte Ansicht -- fuer ein Tablet an der Wand ist
    // das meist die Uhr.
    Component.onCompleted: {
        if (win.vollbild)
            vollbildAnwenden();
        if (win.forcedPane !== "")
            win.minerPane = win.forcedPane;
        if (win.forcedView >= 0)
            win.view = win.forcedView;
        // **Keine Obergrenze mehr.** Hier stand `<= 3` -- aus der Zeit, als
        // die Startansicht Feed, Uhr, Miner und Explorer kannte. Markt und
        // Wallet kamen dazu, die Grenze wanderte nicht mit: wer sie einstellen
        // konnte, dessen Wunsch wurde beim Start stillschweigend verworfen.
        // Eine Ansicht, die es gerade nicht gibt, faengt der Rueckfall gleich
        // darunter ab -- dafuer braucht es hier keine Zahl.
        else if (win.startView >= 0)
            win.view = win.startView;
        // **Jede Ansicht, die es gerade nicht gibt, faellt zurueck.** Bis
        // dahin war die Wallet der einzige geprüfte Fall; `--view 2` ohne
        // Bitaxe und `--view 6` im Direktbezug landeten auf einer
        // vollstaendig leeren Seite, bei der nicht einmal ein Reiter
        // hervorgehoben war. Am 05.09.2026 im Android-Emulator aufgefallen,
        // wo der Markt **nie** einen Reiter hat: die Verknuepfung dorthin
        // fuehrte ins Nichts, und der einzige Ausweg war zu wissen, wo man
        // hintippen muss.
        //
        // Hier und nicht in `FeedTabs`: dort haengt der Rueckfall an
        // Signalen, und beim Start aendert sich nichts, worauf sie warten
        // koennten -- der Wert ist von Anfang an falsch. Diese Zeile laeuft
        // genau einmal, gleich nachdem er gesetzt wurde. Eine gemerkte 4
        // (die Wallet bis 26.09.2026) steht in keinem Reiter mehr und landet
        // ebenfalls hier.
        // Die Einstellungen haben hier keinen Reiter, sondern das Zahnrad --
        // gueltig sind sie trotzdem.
        if (tabs.tabViews.length > 0 && tabs.tabViews.indexOf(win.view) < 0 && win.view !== 5)
            win.view = tabs.tabViews[0];
    }

    // Welche Reiter es gibt, rechnet `FeedTabs` -- samt Rueckfall auf den
    // Feed, wenn die gemerkte Ansicht gerade keinen Reiter hat. Hier stand das
    // vorher ein zweites Mal.
    //
    // Im Direktbezug fallen manche weg, und zwar nicht aus Bequemlichkeit:
    // der Miner steht im Heimnetz, und der Markt wird dort verdichtet. Ein Reiter, hinter dem
    // nichts sein kann, ist schlimmer als keiner.

    // Eine Einstellung setzen. Alles laeuft hier durch, damit es nur eine
    // Stelle gibt, an der etwas geaendert wird.
    function setOpt(key, value) {
        if (key === "bgOpacity")
            win.bgOpacity = value;
        else if (key === "density")
            win.density = value;
        else if (key === "startView")
            win.startView = value;
        else if (key === "dataSource")
            win.dataSource = value;
        // **Fehlte bis zum 15.09.2026.** Das Feld "Dienst auf einem anderen
        // Geraet" meldete seine Eingabe hierher, und ohne diesen Zweig fiel
        // sie stillschweigend weg: die Anwendung fragte weiter 127.0.0.1 auf
        // dem Telefon selbst. Am 13.09. sah das aus wie ein Netzproblem
        // (die Shell erreichte den Dienst, die App nie), am 15.09. zeigte der
        // Zaehler in /health, dass von der App gar keine Anfrage kam.
        else if (key === "daemonHost")
            win.daemonHost = (value || "").trim();
        else if (key === "mempoolHost")
            win.mempoolHost = (value || "").trim();
        else if (key === "colorMode")
            win.colorMode = value;
        else if (key === "sizeMode")
            win.sizeMode = value;
        else if (key === "showInfo")
            win.showInfo = value;
        else if (key === "showLegend")
            win.showLegend = value;
        else if (key === "showRuler")
            win.showRuler = value;
        else if (key === "frosted")
            win.frosted = value;
        else if (key === "currency")
            win.currency = value;
        else if (key === "tileColorMode")
            win.tileColorMode = value;
        else if (key === "clockBars")
            win.clockBars = value;
        else if (key === "clockFields")
            win.clockFieldsRaw = (value || []).join("|");
        else if (key === "minerFields")
            win.minerFieldsRaw = (value || []).join("|");
        else if (key === "showHeader")
            win.showHeader = value;
        else if (key === "showFooter")
            win.showFooter = value;
        else if (key === "showBlock")
            win.showBlock = value;
        else if (key === "clockSpark")
            win.clockSpark = value;
        else if (key === "clockTime")
            win.clockTime = value;
        else if (key === "clockPrice")
            win.clockPrice = value;
        else if (key === "priceSpan")
            win.priceSpan = value;
        else if (key === "marketRange")
            win.marketRange = value;
        else if (key === "marketKind")
            win.marketKind = value;
        else if (key === "marketLower")
            win.marketLower = value;
        else if (key === "marketSub")
            win.marketSub = value;
        else if (key === "marketSecs")
            win.marketSecs = value;
        else if (key === "marketVon")
            win.marketVon = value;
        else if (key === "marketBis")
            win.marketBis = value;
        else if (key === "marketCross")
            win.marketCross = value;
        else if (key === "marketTape")
            win.marketTape = value;
        else if (key === "showFeed")
            win.showFeed = value;
        else if (key === "showClock")
            win.showClock = value;
        else if (key === "showMiner")
            win.showMiner = value;
        else if (key === "showExplorer")
            win.showExplorer = value;
        else if (key === "showMarket")
            win.showMarket = value;
        else if (key === "minerHostsRaw")
            win.minerHostsRaw = value;
        else if (key === "minerChart")
            win.minerChart = value;
        else if (key === "minerDomains")
            win.minerDomains = value;
        else if (key === "minerBoard")
            win.minerBoard = value;
        else if (key === "minerPane")
            win.minerPane = value;
        else if (key === "netSpan")
            win.netSpan = value;
        else if (key === "explorerLive")
            win.explorerLive = value;
        else if (key === "explorerParts")
            win.explorerPartsRaw = (value || []).join("|");
        else if (key === "minerPanes")
            win.minerPanesRaw = (value || []).join("|");
        else if (key === "netParts")
            win.netPartsRaw = (value || []).join("|");
        else if (key === "minerSolo")
            win.minerSolo = value;
        else if (key === "tabRotate")
            win.tabRotate = value;
        else if (key === "tabRotateViews")
            win.tabRotateViewsRaw = (value || []).join("|");
        else if (key === "explorerPanels")
            win.explorerPanelsRaw = (value || []).join("|");
        else if (key === "lang")
            win.langWahl = value || "";
        else if (key === "bigFields")
            win.bigFieldsRaw = (value || []).join("|");
        else if (key === "bigRotate")
            win.bigRotate = value;
        else if (key === "tabOrder")
            win.tabOrderRaw = (value || []).join("|");
    }

    readonly property var opts: ({
        "bgOpacity": win.bgOpacity,
        "density": win.density,
        "startView": win.startView,
        "dataSource": win.dataSource,
        "daemonHost": win.daemonHost,
        "mempoolHost": win.mempoolHost,
        "dienstMoeglich": win.dienstMoeglich,
        "colorMode": win.colorMode,
        "sizeMode": win.sizeMode,
        "showInfo": win.showInfo,
        "showLegend": win.showLegend,
        "showRuler": win.showRuler,
        "frosted": win.frosted,
        "currency": win.currency,
        "tileColorMode": win.tileColorMode,
        "clockBars": win.clockBars,
        "clockFields": win.clockFields,
        "minerFields": win.minerFields,
        // **`--bare` heisst auch ohne Kopf- und Fusszeile** -- so steht es seit
        // dem 05.09.2026 in `packaging/widgets/README.md`, getan hat es das
        // nie: die beiden hingen allein an den Einstellungen. Am 12.09.2026
        // an einem Windows-Widget gesehen (Feed mit "Block --" oben und
        // "naechster Block" unten), gilt aber ueberall. Nicht gespeichert:
        // das grosse Fenster behaelt seine Wahl.
        "showHeader": win.showHeader && !win.bare,
        "showFooter": win.showFooter && !win.bare,
        "showBlock": win.showBlock,
        "clockSpark": win.clockSpark,
        "clockTime": win.clockTime,
        "clockPrice": win.clockPrice,
        "priceSpan": win.priceSpan,
        "marketRange": win.marketRange,
        "marketKind": win.marketKind,
        "marketLower": win.marketLower,
        "marketSub": win.marketSub,
        "marketSecs": win.marketSecs,
        "marketVon": win.marketVon,
        "marketBis": win.marketBis,
        "marketCross": win.marketCross,
        "marketTape": win.marketTape,
        "showFeed": win.showFeed,
        "showClock": win.showClock,
        "showMiner": win.showMiner,
        "showExplorer": win.showExplorer,
        "showMarket": win.showMarket,
        "minerHostsRaw": win.minerHostsRaw,
        "minerChart": win.minerChart,
        "minerDomains": win.minerDomains,
        "minerBoard": win.minerBoard,
        "minerPane": win.minerPane,
        "netSpan": win.netSpan,
        "explorerLive": win.explorerLive,
        "explorerParts": win.explorerParts,
        "minerPanes": win.minerPanes,
        "netParts": win.netParts,
        "minerSolo": win.minerSolo,
        "tabRotate": win.tabRotate,
        "tabRotateViews": win.tabRotateViews,
        "explorerPanels": win.explorerPanels,
        "lang": win.lang,
        "langWahl": win.langWahl,
        "bigFields": win.bigFields,
        "bigRotate": win.bigRotate,
        "tabOrder": win.tabOrder
    })

    FeedState {
        id: feedState

        mode: win.effSource
        // Leer bleibt 127.0.0.1; eingetragen zeigt es auf den Rechner im
        // eigenen Netz. Im Direktbezug ungenutzt -- dort wird niemand gefragt.
        endpoint: win.effEndpoint
        // Die Adressen der Miner. Im Daemon-Betrieb ungenutzt -- dort liest
        // der Dienst `sources.json`.
        minerHosts: win.minerHosts
        mempoolHost: win.mempoolHost
    }

    // **Der Rand, den sich das System nimmt.** Ab Android 15 (API 35)
    // zeichnet das System jede Anwendung randlos, und sie muss die Raender
    // der Systemleisten selbst anwenden. Tut sie es nicht, liegt die
    // Reiterzeile unter der Statusleiste -- am 08.09.2026 auf einem Galaxy
    // A55 (Android 16, targetSdk 36) gemessen: `mAppBounds` ist der ganze
    // Schirm, der obere Rand 89 px. "Feed" und die Uhrzeit standen
    // uebereinander gedruckt, und **die Reiter waren nicht antippbar**: die
    // Statusleiste ist ein eigenes Fenster darueber und nimmt die
    // Beruehrung. Vom Feed-Reiter kam man per Finger nicht weg.
    //
    // `SafeArea` haengt hier an einem Behaelter und **nicht an `tabs`
    // selbst**: die Raender richten sich nach der Lage des Elements, und ein
    // Element, das seine eigene Lage aus ihnen ableitet, ist eine
    // Bindungsschleife.
    //
    // Keine Plattformabfrage. Auf dem Schreibtisch sind diese Raender 0 --
    // was nichts beansprucht, kostet auch nichts, und eine Abfrage waere
    // eine zweite Stelle, an der dieselbe Entscheidung steht.
    Item {
        id: flaeche

        anchors.fill: parent

        // **Alle Ansichten stehen in `FeedTabs`** -- dasselbe Bauteil wie im
        // Dashboard, im Popout und auf dem Desktop. Vorher verdrahtete dieses
        // Fenster sie selbst, und genau daran fehlte einer Ansicht ihre
        // Sprache und der Uhr der Kursverlauf: was hier dazukam, kam
        // dort nicht an, und umgekehrt.
        FeedTabs {
            id: tabs

            anchors.fill: parent
            anchors.leftMargin: 14 + flaeche.SafeArea.margins.left
            anchors.rightMargin: 14 + flaeche.SafeArea.margins.right
            anchors.bottomMargin: 14 + flaeche.SafeArea.margins.bottom
            anchors.topMargin: 8 + flaeche.SafeArea.margins.top
            feed: feedState
            opts: win.opts
            view: win.view
            // Im nackten Widget bleibt die Reiterzeile weg -- und mit ihr der
            // Platz, den sie braucht.
            tabsVisible: !win.bare && !win.vollbild
            // Zahnrad statt Reiter, und rechts Platz fuer Zahnrad und
            // Vollbildknopf (je 44, der aeussere 6 vom Rand, abzueglich der
            // 14, die `FeedTabs` ohnehin einrueckt).
            settingsTab: false
            tabsRechts: win.bare ? 0 : 80
            // Der Reiterwechsel laeuft auch im Vollbild -- gerade dort, an
            // der Wand. Nur das nackte Widget zeigt immer dieselbe Ansicht.
            rotationAllowed: !win.bare
            finger: win.ohneTastatur
            // Deckkraft und Startansicht gehoeren dem Fenster, also stehen sie
            // hier auch in den Einstellungen.
            windowedSettings: true
            minerActions: !win.bare
            gap: 6
            tabFont: 13
            baseFont: 13
            onOptRequested: function (key, value) {
                win.setOpt(key, value);
            }
            onViewRequested: function (v) {
                win.view = v;
            }
            // Das Suchfeld des Explorers nimmt den Fokus, solange es zu sehen ist.
            // Beim Verlassen gehoert er wieder hierher -- sonst sind die
            // Tastenkuerzel nach einem Besuch im Explorer tot.
            onSearchFocusReleased: {
                win.sucheOffen = false;
                keys.forceActiveFocus();
            }
            // **Die Tastenhilfe sagt, wie man wieder herauskommt.** Das Feld
            // schluckt die Ziffern, und wer nicht weiss, dass Esc den Fokus
            // zurueckgibt, haelt die Kuerzel fuer kaputt (Idee vom 15.09.2026).
            onSearchFocusTaken: {
                win.sucheOffen = true;
                hint.flash();
            }

            // **Auf dem Telefon holt sich das Suchfeld den Fokus nicht.** Dort
            // haengt am Fokus die Bildschirmtastatur, und die deckt die halbe
            // Ansicht zu: wer den Explorer oeffnet, sieht zuerst eine Tastatur
            // und muss sie wegwischen, bevor er die Bloecke sieht. Am 05.09.2026
            // im Emulator aufgefallen -- auf dem Schreibtisch kostet der Fokus
            // nichts und spart einen Klick, deshalb bleibt er dort.
            searchFocus: !win.ohneTastatur
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_C:
                // Drei Lesarten im Kreis: Alter, Gebuehr, Art
                win.colorMode = win.colorMode === "age" ? "fee"
                    : (win.colorMode === "fee" ? "type" : "age");
                hint.flash();
                break;
            case Qt.Key_S:
                win.sizeMode = win.sizeMode === "value" ? "vbytes" : "value";
                hint.flash();
                break;
            case Qt.Key_L:
                win.showLegend = !win.showLegend;
                hint.flash();
                break;
            case Qt.Key_Plus:
            case Qt.Key_Equal:
                win.bgOpacity = Math.min(1, win.bgOpacity + 0.05);
                hint.flash();
                break;
            case Qt.Key_Minus:
                win.bgOpacity = Math.max(0.15, win.bgOpacity - 0.05);
                hint.flash();
                break;
            case Qt.Key_B:
                tabs.triggerBlockAnimation();
                break;
            case Qt.Key_I:
                win.showInfo = !win.showInfo;
                hint.flash();
                break;
            case Qt.Key_1:
            case Qt.Key_2:
            case Qt.Key_3:
            case Qt.Key_4:
            case Qt.Key_5:
            case Qt.Key_6:
                // Die Ziffer zaehlt die **sichtbaren** Reiter ab -- ist eine
                // Ansicht aus, ruecken die dahinter auf.
                var n = event.key - Qt.Key_1;
                if (n < tabs.tabViews.length) {
                    win.view = tabs.tabViews[n];
                    hint.flash();
                }
                break;
            case Qt.Key_Comma:
                // **Das Zahnrad auf der Tastatur.** Seit die Einstellungen
                // keinen Reiter mehr haben (13.09.2026), zaehlen die Ziffern
                // sie nicht mit, und ohne Maus kam man nicht mehr hinein --
                // in der Pruef-VM gar nicht (15.09.2026). Komma wie Strg+Komma
                // in vielen Programmen; ein zweites Mal fuehrt zurueck.
                if (win.bare || win.vollbild)
                    return;
                einstKnopf.offen ? einstKnopf.schliessen() : einstKnopf.oeffnen();
                hint.flash();
                break;
            case Qt.Key_Escape:
                // Nur offene Einstellungen; sonst geht Esc weiter.
                if (win.view !== 5 || win.vollbild)
                    return;
                einstKnopf.schliessen();
                break;
            case Qt.Key_PageDown:
            case Qt.Key_PageUp:
            case Qt.Key_Home:
            case Qt.Key_End:
                // An die sichtbare Ansicht (roll.js). Die Leertaste bleibt
                // frei: sie hat in Feldern ihre eigene Bedeutung.
                tabs.rollen(event.key === Qt.Key_PageDown ? "ab"
                            : event.key === Qt.Key_PageUp ? "auf"
                            : event.key === Qt.Key_Home ? "anfang" : "ende");
                break;
            case Qt.Key_F11:
                win.vollbild = !win.vollbild;
                break;
            case Qt.Key_Back:
                // Die Zurueck-Geste verlaesst zuerst das Vollbild und erst
                // beim zweiten Mal die Anwendung. Nicht angenommen, geht sie
                // an Android weiter. **Offene Einstellungen schliesst sie
                // vorher** -- seit sie ueber das Zahnrad kommen, ist das der
                // Weg zurueck, den man am Telefon erwartet.
                if (win.view === 5 && !win.vollbild) {
                    einstKnopf.schliessen();
                    break;
                }
                if (!win.vollbild)
                    return;
                win.vollbild = false;
                break;
            case Qt.Key_Q:
                Qt.quit();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    // **Mit eigenem Kasten, und er bricht um.** Bis zum 11.09.2026 stand
    // der Hinweis als blosser Text auf der Fusszeile: fuer die Sekunden, die
    // er zu sehen ist, lag "1–6 Ansicht · c Farbe ..." quer ueber "naechster
    // Block ... median ...", und im schmalen Fenster (480 Punkte) ragte er
    // links und rechts hinaus. Jetzt ein Kasten mit dem Grund des Fensters,
    // hoechstens so breit wie das Fenster abzueglich Rand.
    TextMetrics {
        id: hintMass

        font.pixelSize: 11
        text: hintText.text
    }

    Rectangle {
        id: hint

        // **Nicht auf dem Telefon.** Er zaehlt Tastenkuerzel auf, und dort
        // gibt es keine Tastatur -- gedeckt hat er dafuer die Fusszeile, quer
        // ueber "naechster Block ... median ... BTC" und rechts
        // abgeschnitten. Am 08.09.2026 beim Kaltstart gesehen. `flash()`
        // darf weiter gerufen werden (eine angesteckte Tastatur waere ja
        // moeglich), es wird nur nichts sichtbar.
        visible: !win.ohneTastatur

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Auch dieser sitzt sonst hinter der Navigationsleiste.
        anchors.bottomMargin: 10 + flaeche.SafeArea.margins.bottom
        width: hintText.width + 20
        height: hintText.height + 10
        radius: 6
        color: Qt.rgba(0.043, 0.043, 0.071, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: 0

        Text {
            id: hintText

            anchors.centerIn: parent
            width: Math.min(Math.ceil(hintMass.advanceWidth) + 1, win.width - 48)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#9a94a6"
            font.pixelSize: 11
            // ", Einstellungen" aus dem Reiternamen, der in allen Sprachen schon da ist.
            text: win.sucheOffen
                  ? Tr.t("keys.search", win.lang)
                  : Tr.t("keys.help", win.lang) + " · , " + Tr.t("tab.settings", win.lang) + " · " + Tr.t("keys.fullscreen", win.lang)
        }

        function flash() {
            opacity = 1;
            fade.restart();
        }

        Component.onCompleted: hint.flash()

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }

        Timer {
            id: fade

            interval: 2600
            onTriggered: hint.opacity = 0
        }
    }

    // **Im Vollbild zeigt ein Tipp den Knopf zum Verlassen.** Die Ansicht
    // bekommt den Tipp trotzdem: der Druck wird hier nur bemerkt und nicht
    // angenommen, er geht an das Element darunter weiter. Ein Knopf, der
    // immer da waere, laege auf der Uhr quer ueber "im Mempool" oder dem
    // Kurs -- genau dort, wo man an der Wand hinschaut.
    MouseArea {
        anchors.fill: parent
        z: 40
        enabled: win.vollbild
        onPressed: mouse => {
            vollKnopf.zeigen();
            mouse.accepted = false;
        }
    }

    Item {
        id: vollKnopf

        property bool gezeigt: false

        function zeigen() {
            gezeigt = true;
            ausblenden.restart();
        }

        // **Neben den Reitern so hoch wie ihre Zeile und auf deren Mitte.**
        // Mit 44 Punkten ab Oberkante sass er tiefer als die Beschriftungen und
        // reichte am Galaxy in den Kasten darunter -- im Feed auf dessen
        // Rahmen, im Markt auf die Zeitraum-Auswahl (13.09.2026). Im Vollbild
        // gibt es keine Reiter, dort bleibt er gross.
        //
        // **Auf die Schrift, nicht auf die Zeile.** Jeder Reiter haelt unter
        // der Beschriftung Platz fuer den Unterstrich frei (`fontSize * 0.55`,
        // ViewTabs). Auf die ganze Zeile zentriert, sass das Symbol um diesen
        // halben Streifen zu tief und beruehrte am Galaxy noch den Rahmen des
        // Kastens darunter.
        readonly property real zeile: Math.max(20, tabs.tabSpace - tabs.gap - tabs.tabFont * 0.55)

        visible: !win.bare
        z: 50
        width: 44
        height: win.vollbild ? 44 : vollKnopf.zeile
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: (win.vollbild ? 6 : 8) + flaeche.SafeArea.margins.top
        anchors.rightMargin: 6 + flaeche.SafeArea.margins.right
        opacity: win.vollbild ? (gezeigt ? 0.85 : 0) : 1
        enabled: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        Timer {
            id: ausblenden

            interval: 3000
            onTriggered: vollKnopf.gezeigt = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 36
            radius: 18
            color: win.vollbild ? "#16131f" : "transparent"
        }

        // Vier Ecken, gezeichnet statt als Schriftzeichen: fuer U+26F6 hat
        // nicht jede Schrift eine Glyphe, und ein leeres Kaestchen stand
        // hier schon einmal statt des Bitcoin-Zeichens. Nach aussen weisend
        // heisst "hinein ins Vollbild", nach innen "heraus".
        Item {
            id: zeichen

            anchors.centerIn: parent
            width: 16
            height: 16

            Repeater {
                model: 4

                Item {
                    required property int index

                    width: 6
                    height: 6
                    x: index % 2 ? zeichen.width - width : 0
                    y: index >= 2 ? zeichen.height - height : 0
                    rotation: [0, 90, 270, 180][index] + (win.vollbild ? 180 : 0)

                    Rectangle {
                        width: parent.width
                        height: 2
                        color: "#9a94a6"
                    }

                    Rectangle {
                        width: 2
                        height: parent.height
                        color: "#9a94a6"
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: win.vollbild = !win.vollbild
        }
    }

    // **Ein Zahnrad statt des Reiters "Einstellungen".** Am 13.09.2026 am
    // Galaxy: mit dem Markt reichte die Reiterzeile bis zum Rand, und der
    // Vollbildknopf lag auf "Einstellungen". Ein zweites Mal antippen fuehrt
    // zurueck, wohin man vorher sah. Im Vollbild weg, wie die Reiter.
    Item {
        id: einstKnopf

        property int vorher: 0
        readonly property bool offen: win.view === 5

        function oeffnen() {
            if (win.view === 5)
                return;
            einstKnopf.vorher = win.view;
            win.view = 5;
        }

        function schliessen() {
            var ziel = einstKnopf.vorher;
            if (tabs.tabViews.indexOf(ziel) < 0)
                ziel = tabs.tabViews.length ? tabs.tabViews[0] : 0;
            win.view = ziel;
        }

        visible: !win.bare && !win.vollbild
        z: 50
        width: 44
        height: vollKnopf.height
        anchors.top: vollKnopf.top
        anchors.right: vollKnopf.left

        onOffenChanged: zahnrad.requestPaint()

        // Gezeichnet, aus demselben Grund wie die Ecken daneben: eine
        // Symbolschrift mit Zahnrad gibt es nicht auf jedem Geraet.
        //
        // **Eine Kontur mit Zaehnen, nicht Ring und Striche.** Die erste
        // Fassung -- ein Kreis mit acht einzelnen Strichen -- las sich am
        // Galaxy eher als Sonne. Jetzt eine geschlossene Linie: acht Zaehne,
        // aussen schmaler als am Fuss, dazwischen Bogen, innen ein Loch.
        // Linienstaerke und Farbe wie die Ecken des Vollbildknopfs.
        Canvas {
            id: zahnrad

            anchors.centerIn: parent
            width: 18
            height: 18

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var mx = width / 2, my = height / 2;
                var aussen = 8, fuss = 6, loch = 2.4;
                var zahn = 0.2, sockel = 0.32;    // halbe Breite im Bogenmass
                var schritt = Math.PI / 4;
                ctx.strokeStyle = einstKnopf.offen ? "#f7931a" : "#9a94a6";
                ctx.lineWidth = 1.8;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (var i = 0; i < 8; i++) {
                    var w = i * schritt - Math.PI / 2;
                    var p1 = w - sockel, p2 = w - zahn, p3 = w + zahn, p4 = w + sockel;
                    if (i === 0)
                        ctx.moveTo(mx + Math.cos(p1) * fuss, my + Math.sin(p1) * fuss);
                    else
                        ctx.lineTo(mx + Math.cos(p1) * fuss, my + Math.sin(p1) * fuss);
                    ctx.lineTo(mx + Math.cos(p2) * aussen, my + Math.sin(p2) * aussen);
                    ctx.lineTo(mx + Math.cos(p3) * aussen, my + Math.sin(p3) * aussen);
                    ctx.lineTo(mx + Math.cos(p4) * fuss, my + Math.sin(p4) * fuss);
                    ctx.arc(mx, my, fuss, p4, w + schritt - sockel, false);
                }
                ctx.closePath();
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(mx, my, loch, 0, Math.PI * 2);
                ctx.stroke();
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: einstKnopf.offen ? einstKnopf.schliessen() : einstKnopf.oeffnen()
        }
    }
}
