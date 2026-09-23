// Der ganze Satz Ansichten mit der Reiterzeile darueber -- Feed, Uhr,
// Miner, Explorer, Wallet, Einstellungen.
//
// **Einmal gebaut, dreimal benutzt**: im Dashboard-Tab von DMS, im Popout der
// Leisten-Pille und in der Kachel des Control Centers. Vorher stand der Satz
// nur im Dashboard-Tab; die beiden anderen zeigten allein den Feed und lasen
// vier von dreissig Einstellungen -- Sprache und Waehrung kamen dort nie an.
//
// Der Wirt haelt den Zustand, dieses Bauteil zeigt ihn nur:
//
//   opts          dieselbe Sammlung, die auch `SettingsView` liest
//   view          welche Ansicht gerade oben liegt
//   optRequested  "stell das bitte um" -- der Wirt legt es ab, wo er mag
//                 (QSettings im Fenster, Plugin-Ablage in DMS)
//   viewRequested dasselbe fuer den Reiter
//
// Nur `import QtQuick` -- damit laeuft es auch unter Android.
import QtQuick
import "strings.js" as Tr
import "views.js" as Views
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    // Sieht niemand hin, rechnet auch nichts
    property bool live: true
    property var opts: ({})
    // 0 Feed, 1 Uhr, 2 Miner, 3 Explorer, 4 Wallet, 5 Einstellungen
    property int view: 0
    // Die Einstellungsseite blendet Deckkraft und Startansicht aus, wo das
    // Fenster nicht dem Programm gehoert.
    property bool windowedSettings: false
    // Im Dashboard stellt die Leiste oben rechts die Knoepfe des Miners --
    // dort kann sie nichts ueberdecken.
    property bool minerActions: true
    // Das Desktop-Widget zeigt **eine** Ansicht ohne Reiterzeile. Es benutzt
    // trotzdem dieses Bauteil, damit die Ansichten nur an einer Stelle
    // verdrahtet sind.
    property bool tabsVisible: true
    // Die Einstellungen als Reiter. Die eigenstaendige Anwendung stellt das ab
    // und zeigt ein Zahnrad; Dashboard, Popout und Quickshell haben keins und
    // behalten den Reiter. Ohne Reiter bleibt Ansicht 5 trotzdem gueltig.
    property bool settingsTab: true
    // Platz rechts neben den Reitern, den der Wirt fuer eigene Knoepfe braucht
    property real tabsRechts: 0
    // Bedienung mit dem Finger (Telefon, Tablet): groessere Tippflaechen.
    // Setzt der Wirt, der weiss, wo er laeuft.
    property bool finger: false
    // Darf sich das Suchfeld des Explorers beim Aufschlagen den Tastaturfokus
    // holen? Auf dem Desktop-Widget nicht -- dort tippt niemand.
    property bool searchFocus: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    // Untergrund fuer aufklappende Flaechen (Auswahlfelder). In DMS ist das
    // dessen eigene Flaechenfarbe -- damit traegt das Auswahlfeld dieselbe
    // Deckkraft wie die Einstellungen daneben, statt eine eigene zu erfinden.
    property color panelColor: "#16161f"
    // Toenung der Milchglas-Kaestchen im Feed; getrennt von panelColor, damit
    // App und Quickshell-Fenster ihr bisheriges Dunkel behalten
    property color frostedTint: "#0b0b12"
    property real baseFont: 13
    property real tabFont: 12
    property real gap: 8

    signal optRequested(string key, var value)
    signal viewRequested(int v)
    // Der Explorer hat den Tastaturfokus wieder hergegeben.
    signal searchFocusReleased()
    signal searchFocusTaken()

    // **Rollen mit der Tastatur**, an die sichtbare Ansicht gereicht. Feed und
    // Markt rollen nicht; dort geht die Taste ins Leere.
    function rollen(wie) {
        if (root.view === 1)
            return uhr.visible && uhr.rollen(wie);
        if (root.view === 2)
            return miner.visible && miner.rollen(wie);
        if (root.view === 3)
            return explorer.visible && explorer.rollen(wie);
        if (root.view === 4)
            return wallet.visible && wallet.rollen(wie);
        if (root.view === 5)
            return einstellungen.visible && einstellungen.rollen(wie);
        return false;
    }

    function o(key, def) {
        return root.opts[key] === undefined ? def : root.opts[key];
    }

    // Nichts gewaehlt (fehlt oder leer): die Vorgabe von aussen, sonst die
    // Sprache des Systems. Das DMS-Plugin setzt die Vorgabe auf die Sprache
    // von DMS.
    property string defaultLang: ""
    readonly property string lang: root.o("lang", "") || root.defaultLang || Tr.systemLang()

    // **Das Bitcoin-Zeichen, wenn die Schrift es fuehrt -- sonst "BTC".**
    // Am 08.09.2026 auf einem Galaxy A55 stand ueberall ein leeres Kaestchen
    // mit Kreuz statt `₿`, das Euro-Zeichen daneben sass. Nachgemessen: die
    // Standardschrift des Geraets (OneUISans) fuehrt U+20BF sehr wohl
    // (`20a0-20bf`), Roboto nicht (`20a0-20be`) -- und Qt greift auf Android
    // nach Roboto. Die Schrift zu erzwingen waere geraten; gefragt wird
    // besser.
    //
    // Fragen kann man es in QML nicht, also messen: `₿` gegen ein Zeichen
    // aus dem privaten Bereich, das **keine** Schrift fuehrt. Kommen beide
    // gleich breit heraus, ist auch das erste ein Kaestchen.
    //
    // **Eine Eigenschaft, kein gemerkter Wert in der JS-Bibliothek.** Eine
    // Funktion mit verstecktem Zustand wird in einer Bindung genau einmal
    // ausgewertet; was danach gemessen wird, kommt nie an. Als Eigenschaft
    // haengt die Anzeige daran und richtet sich mit.
    //
    // **Auf Android wird nicht mehr gemessen, dort gilt immer der Text.** Am
    // 11.09.2026 im Emulator mit Android 11 ging die Messung schief: die
    // Kaestchen fuer `₿` und fuer das Vergleichszeichen kamen aus
    // verschiedenen Ersatzschriften und waren verschieden breit, die Messung
    // sagte "vorhanden", und im Feed stand wieder das Kaestchen mit Kreuz.
    // Qt nimmt auf Android Roboto, und Roboto fuehrt weder `₿` noch die
    // Pfeile -- auf dem Galaxy A55 kam deshalb schon immer "BTC" und "->"
    // heraus. Auf dem Schreibtisch bleibt die Messung: dort gibt es die
    // Schriften meist, und sie hat bisher nie getaeuscht.
    readonly property bool ohneSonderzeichen: Qt.platform.os === "android"
    readonly property string btcZeichen:
        !root.ohneSonderzeichen && probeBtc.implicitWidth !== probeLeer.implicitWidth
        ? "\u20BF" : "BTC"

    // Dieselbe Probe fuer die Pfeile. **Je Zeichen einmal gemessen, nicht von
    // einem auf das andere geschlossen:** auf dem Galaxy A55 fuehrt keine der
    // Schriften einen der beiden, aber `→` ist im Allgemeinen viel weiter
    // verbreitet als `⟶`, und eine Schrift mit dem einen und ohne das andere
    // waere nichts Besonderes. Ein anderes Pfeilzeichen zu nehmen hilft dort
    // ohnehin nicht -- es braucht einen Textrueckfall.
    readonly property string pfeilLang:
        !root.ohneSonderzeichen && probePfeilL.implicitWidth !== probeLeer.implicitWidth
        ? "\u27F6" : "->"

    readonly property string pfeilKurz:
        !root.ohneSonderzeichen && probePfeilK.implicitWidth !== probeLeer.implicitWidth
        ? "\u2192" : "->"

    readonly property string currency: root.o("currency", "usd")
    readonly property bool walletEnabled: root.o("walletEnabled", false)
    // **Ein unsichtbares Element behaelt seine Hoehe.** Ohne die Abfrage
    // stuende im nackten Widget oben ein leerer Streifen in Reiterhoehe.
    readonly property real tabSpace: root.tabsVisible ? tabs.height + root.gap : 0

    // Die Wallet faellt im Direktbezug weg, und zwar nicht aus Bequemlichkeit:
    // die Ableitung ist Rechenarbeit des Dienstes. Ein Reiter, hinter dem
    // nichts sein kann, ist schlimmer als keiner. Der Markt stand hier bis zum
    // 13.09.2026 auch; seitdem rechnet `DirectMarket` ihn selbst, und nur ein
    // fehlendes QtWebSockets nimmt ihn noch weg. (Der Miner zeigt seit dem
    // 11.09.2026 ohne Geraet das Netz.)
    readonly property bool canMarket: !!(root.feed && root.feed.canMarket)

    // **Jeder Reiter laesst sich abschalten, und die Reihenfolge gehoert dem
    // Anwender.** Wer keinen Miner hat, braucht den Reiter nicht; wer meist
    // auf den Markt sieht, stellt ihn nach vorn. Beides steht in `tabOrder`
    // und in den `show...`-Schaltern, gerechnet wird es in `views.js` -- der
    // einen Stelle, an der die Ansichten aufgezaehlt sind.
    //
    // Was technisch nicht geht, faellt ohnehin weg; der Schalter kommt oben
    // drauf und kann nichts erzwingen. Die Einstellungen bleiben immer --
    // sonst schaltet man den letzten Reiter ab und kommt an keinen Schalter
    // mehr heran.
    readonly property var tabViews: Views.reiter(
        root.o("tabOrder", []),
        function (id) {
            // Der Miner-Reiter ist immer moeglich: ohne eigenes Geraet zeigt
            // er das Netz (seit dem 11.09.2026, vorher blieb er im
            // Direktbezug ohne Adresse weg).
            if (id === 4)
                return root.walletEnabled && !!(root.feed && root.feed.canWallet);
            if (id === 6)
                return root.canMarket;
            return true;
        },
        function (schluessel) {
            return root.o(schluessel, true);
        },
        root.settingsTab)

    // Die Beschriftungen in derselben Reihenfolge, aus derselben Tabelle.
    // Hier stand vorher eine zweite, von Hand gepflegte Liste daneben, und
    // ein Kommentar bat darum, sie nicht auseinanderlaufen zu lassen.
    readonly property var tabLabels: {
        var l = [];
        for (var i = 0; i < root.tabViews.length; i++)
            l.push(Tr.t(Views.name(root.tabViews[i]), root.lang));
        return l;
    }

    // Steht die Ansicht auf einem Reiter, den es gerade nicht gibt, zurueck auf
    // den ersten vorhandenen -- sonst bliebe eine leere Seite stehen.
    //
    // **Nicht fest auf 0.** Ist der Feed abgeschaltet, ist 0 selbst kein
    // vorhandener Reiter -- die Aufforderung waere dann bei jedem Durchlauf
    // dieselbe und liefe im Kreis. `tabViews[0]` ist immer vorhanden; die
    // Liste traegt mindestens die Einstellungen.
    //
    // **Und ausdruecklich kein `onViewChanged` daneben.** Der Gedanke liegt
    // nahe -- der Rueckfall soll ja auch greifen, wenn die *Ansicht* von
    // aussen gesetzt wird -- und er zerstoert die Anzeige. `view` haengt am
    // Fenster (`view: win.view`); ein Handler, der beim Aktualisieren dieser
    // Bindung auf die Quelle zurueckschreibt, ist eine Bindungsschleife, und
    // QML loest sie, indem es die Bindung fallen laesst. Danach steht das
    // Fenster auf der richtigen Ansicht und `FeedTabs` auf der alten: am
    // 05.09.2026 gemessen als `win=0 tabs=6` bei leerer Seite. Der Fall
    // "von aussen gesetzt" gehoert deshalb nach `Main.qml`, gleich hinter
    // die Zuweisung.
    function reiterPruefen() {
        if (!root.tabsVisible || root.tabViews.length === 0)
            return;
        // Ohne Reiter kommt man ueber das Zahnrad in die Einstellungen --
        // zurueckgeworfen zu werden, sobald dort ein Schalter die Reiter
        // aendert, waere genau das Falsche.
        if (root.view === 5 && !root.settingsTab)
            return;
        if (root.tabViews.indexOf(root.view) < 0)
            root.viewRequested(root.tabViews[0]);
    }

    onTabViewsChanged: root.reiterPruefen()

    // ------------------------------------------------- Reiter im Wechsel
    // **Fuer eine Blockuhr an der Wand** (Wunsch vom 11.09.2026): alle
    // `tabRotate` Sekunden die naechste Station. Mining zaehlt doppelt --
    // Geraet und Netzwerk sind zwei Stationen, sonst saehe man an der Wand
    // immer nur die Seite, die zuletzt offen war.
    //
    // Gewechselt wird ueber dieselben Wege wie beim Antippen (`viewRequested`,
    // `optRequested("minerPane")`); der Wirt legt beides ab wie immer.
    //
    // Nicht im Wechsel: Wallet (gehoert nicht an eine Wand) und die
    // Einstellungen. Stehen die Einstellungen offen, steht der Wechsel still
    // -- sonst zoege er einem die Seite beim Einstellen weg.
    property bool rotationAllowed: true
    readonly property int rotateSec: root.o("tabRotate", 0)
    readonly property var stationen: {
        var wahl = root.o("tabRotateViews", []);
        var alle = !wahl || !wahl.length || typeof wahl.indexOf !== "function";
        function mit(k) {
            return alle || wahl.indexOf(k) >= 0;
        }
        var namen = { "0": "feed", "1": "clock", "3": "explorer", "6": "market" };
        var out = [];
        for (var i = 0; i < root.tabViews.length; i++) {
            var v = root.tabViews[i];
            if (v === 2) {
                if (miner.mitGeraet && mit("device"))
                    out.push({ "v": 2, "pane": "device" });
                if (miner.mitNetz && mit("net"))
                    out.push({ "v": 2, "pane": "net" });
            } else if (namen[String(v)] && mit(namen[String(v)])) {
                out.push({ "v": v, "pane": "" });
            }
        }
        return out;
    }

    function naechsteStation() {
        var st = root.stationen;
        var hier = -1;
        for (var i = 0; i < st.length; i++) {
            if (st[i].v === root.view && (st[i].v !== 2 || st[i].pane === miner.paneNow))
                hier = i;
        }
        var ziel = st[(hier + 1) % st.length];
        if (ziel.v === 2 && ziel.pane !== miner.paneNow)
            root.optRequested("minerPane", ziel.pane);
        if (ziel.v !== root.view)
            root.viewRequested(ziel.v);
    }

    Timer {
        id: wechsel

        interval: Math.max(10, root.rotateSec) * 1000
        repeat: true
        running: root.live && root.rotationAllowed && root.rotateSec > 0
                 && root.stationen.length > 1 && root.view !== 5
        onTriggered: root.naechsteStation()
    }

    // **Eine Beruehrung setzt den Takt zurueck.** Wer an der Wand etwas
    // nachliest, dem soll die Seite nicht unter dem Finger wegwechseln. Nur
    // mitlesen (PointHandler greift nicht zu): Knoepfe, Graphen und Rollen
    // bekommen ihre Ereignisse wie vorher.
    //
    // **In einer eigenen obersten Schicht**, nicht am Wurzelelement: dort
    // kam er erst nach den Ansichten dran, und ein Graph mit eigener
    // MouseArea hatte den Druck schon genommen (11.09.2026 im Xvfb, der
    // Wechsel kam trotz Klick nach Takt).
    Item {
        anchors.fill: parent
        z: 1000

        PointHandler {
            onActiveChanged: if (active && wechsel.running) wechsel.restart()
        }
    }

    Item {
        visible: false

        Text {
            id: probeBtc

            text: "\u20BF"
            font.family: Fonts.sans()
            font.pixelSize: 64
        }

        Text {
            id: probePfeilL

            text: "\u27F6"
            font.family: Fonts.sans()
            font.pixelSize: 64
        }

        Text {
            id: probePfeilK

            text: "\u2192"
            font.family: Fonts.sans()
            font.pixelSize: 64
        }

        Text {
            id: probeLeer

            // Privater Bereich: absichtlich nichts, was je eine Schrift fuehrt.
            text: "\uE000"
            font.family: Fonts.sans()
            font.pixelSize: 64
        }
    }

    // **Wischbar, wenn die Reiter nicht passen.** Die Zeile hat keine
    // Breitengrenze; am Galaxy (384 Punkte) lief sie mit dem Markt bis unter
    // den Vollbildknopf. `tabsRechts` haelt dem Wirt seine Knoepfe frei.
    Flickable {
        id: reiterFlaeche

        anchors.left: parent.left
        anchors.top: parent.top
        width: Math.max(0, parent.width - root.tabsRechts)
        height: tabs.height
        contentWidth: tabs.width
        contentHeight: tabs.height
        interactive: contentWidth > width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        visible: root.tabsVisible
        z: 30

        ViewTabs {
            id: tabs

            labels: root.tabLabels
            current: root.tabViews.indexOf(root.view)
            fontSize: root.tabFont
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            onPicked: function (i) {
                root.viewRequested(root.tabViews[i]);
            }
        }
    }

    FeedPanel {
        id: halde

        visible: root.live && root.view === 0
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        btcZeichen: root.btcZeichen
        pfeilLang: root.pfeilLang
        currency: root.currency
        headerVisible: root.o("showHeader", true)
        footerVisible: root.o("showFooter", true)
        blockVisible: root.o("showBlock", true)
        rulerVisible: root.o("showRuler", true)
        infoVisible: root.o("showInfo", true)
        legendVisible: root.o("showLegend", true)
        frostedInfo: root.o("frosted", true)
        frostedBlur: root.o("frosted", true)
        density: root.o("density", 1)
        colorMode: root.o("colorMode", "age")
        sizeMode: root.o("sizeMode", "value")
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        frostedTint: root.frostedTint
        baseFont: root.baseFont
        onColorModeRequested: function (m) {
            root.optRequested("colorMode", m);
        }
        onTxActivated: function (txid) {
            root.viewRequested(3);
            explorer.go("tx", txid);
        }
    }

    ClockView {
        id: uhr

        visible: root.live && root.view === 1
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        currency: root.currency
        fields: root.o("clockFields", [])
        showBars: root.o("clockBars", true)
        showSpark: root.o("clockSpark", true)
        showTime: root.o("clockTime", false)
        showPrice: root.o("clockPrice", true)
        priceSpan: root.o("priceSpan", "30d")
        finger: root.finger
        onPriceSpanRequested: function (sp) {
            root.optRequested("priceSpan", sp);
        }
        bigFields: root.o("bigFields", ["height"])
        bigRotate: root.o("bigRotate", 0)
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
    }

    MinerView {
        id: miner

        visible: root.live && root.view === 2
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        showActions: root.minerActions
        feed: root.feed
        lang: root.lang
        live: root.live
        finger: root.finger
        pane: root.o("minerPane", "")
        netSpan: root.o("netSpan", "1y")
        panes: root.o("minerPanes", [])
        netParts: root.o("netParts", [])
        showSolo: root.o("minerSolo", true)
        onPaneRequested: function (p) {
            root.optRequested("minerPane", p);
        }
        onNetSpanRequested: function (sp) {
            root.optRequested("netSpan", sp);
        }
        metricKeys: root.o("minerFields", [])
        showChart: root.o("minerChart", true)
        showDomains: root.o("minerDomains", true)
        showBoard: root.o("minerBoard", true)
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
    }

    ExplorerView {
        id: explorer

        visible: root.live && root.view === 3
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        btcZeichen: root.btcZeichen
        pfeilKurz: root.pfeilKurz
        currency: root.currency
        tileColorMode: root.o("tileColorMode", "fee")
        homeParts: root.o("explorerParts", [])
        homePanels: root.o("explorerPanels", [])
        trackProjected: root.o("explorerLive", true)
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        focusSearch: root.searchFocus
        onTileColorModeRequested: function (m) {
            root.optRequested("tileColorMode", m);
        }
        // Weiterreichen: der Wirt holt sich seine Tastenkuerzel zurueck.
        onSearchFocusReleased: root.searchFocusReleased()
        onSearchFocusTaken: root.searchFocusTaken()
    }

    MarketView {
        visible: root.live && root.view === 6 && root.canMarket
        // Nur abfragen, wenn der Reiter auch offen ist -- jede Abfrage haelt
        // im Dienst die Boersenstroeme am Leben.
        live: visible
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        panelColor: root.panelColor
        range: root.o("marketRange", "24h")
        kind: root.o("marketKind", "candles")
        lower: root.o("marketLower", "volume")
        sub: root.o("marketSub", "price")
        customSecs: root.o("marketSecs", 259200)
        vonZeit: root.o("marketVon", 0)
        bisZeit: root.o("marketBis", 0)
        crosshair: root.o("marketCross", true)
        showTape: root.o("marketTape", true)
        baseFont: root.baseFont
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        onRangeRequested: function (r) {
            root.optRequested("marketRange", r);
        }
        onKindRequested: function (k) {
            root.optRequested("marketKind", k);
        }
        onLowerRequested: function (l) {
            root.optRequested("marketLower", l);
        }
        onSubRequested: function (t) {
            root.optRequested("marketSub", t);
        }
        onCustomSecsRequested: function (sek) {
            root.optRequested("marketSecs", sek);
        }
        onVonBisRequested: function (von, bis) {
            root.optRequested("marketVon", von);
            root.optRequested("marketBis", bis);
        }
    }

    WatchView {
        id: wallet

        visible: root.live && root.view === 4 && root.walletEnabled
        // Nur nachfragen, wenn die Ansicht auch zu sehen ist
        live: visible
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        btcZeichen: root.btcZeichen
        currency: root.currency
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        onTxPicked: function (txid) {
            root.viewRequested(3);
            explorer.go("tx", txid);
        }
        onAddressPicked: function (adr) {
            root.viewRequested(3);
            explorer.go("address", adr);
        }
    }

    SettingsView {
        id: einstellungen

        visible: root.live && root.view === 5
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        opts: root.opts
        lang: root.lang
        windowed: root.windowedSettings
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        panelColor: root.panelColor
        // Damit die Darstellungs-Seite dazuschreiben kann, welche Ansicht
        // gerade nichts zeigen koennte. Dieselbe Frage wie in `tabViews`,
        // nur andersherum gestellt -- und sie steht hier, weil nur dieses
        // Bauteil den Feed kennt.
        // Was der Wirt technisch nicht kann, bekommt auch keine Seite in den
        // Einstellungen (siehe dort).
        kannMarkt: root.canMarket
        kannWallet: !!(root.feed && root.feed.canWallet)
        einstellungenAlsReiter: root.settingsTab
        nichtVerfuegbar: {
            var aus = [];
            if (!(root.walletEnabled && root.feed && root.feed.canWallet))
                aus.push(4);
            if (!root.canMarket)
                aus.push(6);
            return aus;
        }
        onChanged: function (key, value) {
            root.optRequested(key, value);
        }
    }

    // Die Blockanimation von Hand ausloesen -- das Fenster legt sie auf die
    // Taste b, zum Pruefen ohne zehn Minuten Wartezeit.
    function triggerBlockAnimation() {
        halde.triggerBlockAnimation();
    }

    // Der Miner traegt zwei Knoepfe, die im Dashboard nicht bei ihm, sondern in
    // der Leiste oben rechts sitzen. Damit der Wirt sie dort stellen kann,
    // reicht dieses Bauteil sie durch.
    readonly property string minerWebUrl: miner.webUrl

    function minerOpenWeb() {
        miner.openWeb();
    }

    function minerToggleInfo() {
        miner.toggleInfo();
    }

    // Von aussen ansteuerbar -- der Wirt kann von der Pille aus direkt in eine
    // Transaktion springen.
    function goExplorer(art, wert) {
        root.viewRequested(3);
        explorer.go(art, wert);
    }
}
