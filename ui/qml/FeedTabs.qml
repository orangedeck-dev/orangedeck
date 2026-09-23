// The full set of views with the tab row above them: Feed, Clock, Miner,
// Explorer, Wallet, Settings.
//
// Built once, used in three places: the DMS dashboard tab, the bar pill
// popout and the Control Center tile. All three get the same views and read
// all settings, including language and currency.
//
// The host holds the state, this component only displays it:
//
//   opts          the same collection `SettingsView` reads
//   view          which view is currently on top
//   optRequested  "please change this"; the host stores it wherever it likes
//                 (QSettings in the window, plugin storage in DMS)
//   viewRequested the same for the tab
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick
import "strings.js" as Tr
import "views.js" as Views
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    // Nothing is computed while nobody is looking
    property bool live: true
    property var opts: ({})
    // 0 Feed, 1 Clock, 2 Miner, 3 Explorer, 4 Wallet, 5 Settings, 6 Market
    property int view: 0
    // The settings page hides opacity and start view where the window does not
    // belong to the app.
    property bool windowedSettings: false
    // In the dashboard the bar at the top right holds the miner buttons, where
    // they cannot cover anything.
    property bool minerActions: true
    // The desktop widget shows a single view without the tab row. It still uses
    // this component so the views are wired up in only one place.
    property bool tabsVisible: true
    // Settings as a tab. The standalone app turns this off and shows a gear
    // instead; dashboard, popout and Quickshell have no gear and keep the tab.
    // View 5 stays valid without the tab.
    property bool settingsTab: true
    // Space to the right of the tabs that the host needs for its own buttons
    property real tabsRechts: 0
    // Touch input (phone, tablet): larger tap targets. Set by the host, which
    // knows where it runs.
    property bool finger: false
    // May the explorer search field take keyboard focus when the view opens?
    // Not on the desktop widget, nobody types there.
    property bool searchFocus: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    // Background for popup surfaces (combo boxes). In DMS this is DMS's own
    // surface color, so a combo box gets the same opacity as the settings next
    // to it instead of its own.
    property color panelColor: "#16161f"
    // Tint of the frosted glass boxes in the feed. Separate from panelColor so
    // the app and the Quickshell window keep their darker tone.
    property color frostedTint: "#0b0b12"
    property real baseFont: 13
    property real tabFont: 12
    property real gap: 8

    signal optRequested(string key, var value)
    signal viewRequested(int v)
    // The explorer has released keyboard focus.
    signal searchFocusReleased()
    signal searchFocusTaken()

    // Keyboard scrolling, forwarded to the visible view. Feed and Market do not
    // scroll, so the key does nothing there.
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

    // Nothing chosen (missing or empty): the default from the host, otherwise
    // the system language. The DMS plugin sets the default to the DMS language.
    property string defaultLang: ""
    readonly property string lang: root.o("lang", "") || root.defaultLang || Tr.systemLang()

    // The bitcoin sign if the font has it, otherwise "BTC". Some Android
    // system fonts do have U+20BF, but Qt on Android falls back to Roboto,
    // which does not (its range ends at U+20BE), so the glyph shows up as an
    // empty box. Forcing a font would be guesswork; checking is better.
    //
    // QML cannot ask a font whether it has a glyph, so measure instead: compare
    // `₿` with a private use character that no font has. If both come out the
    // same width, the first one is a missing-glyph box too.
    //
    // A property, not a cached value inside the JS library. A function with
    // hidden state is evaluated exactly once inside a binding, and anything
    // measured later never arrives. As a property the display depends on it
    // and updates with it.
    //
    // Android always gets the text, no measuring. There the missing-glyph boxes
    // for `₿` and for the comparison character can come from different fallback
    // fonts with different widths, so the measurement says "present" and the
    // box shows up anyway. Qt uses Roboto on Android, which has neither `₿` nor
    // the arrows, so the result would be "BTC" and "->" regardless. On the
    // desktop the fonts are usually there and the measurement is reliable.
    readonly property bool ohneSonderzeichen: Qt.platform.os === "android"
    readonly property string btcZeichen:
        !root.ohneSonderzeichen && probeBtc.implicitWidth !== probeLeer.implicitWidth
        ? "\u20BF" : "BTC"

    // The same probe for the arrows. Each glyph is measured on its own instead
    // of inferring one from the other: `→` is far more common than `⟶`, and a
    // font with one but not the other is nothing unusual. Picking a different
    // arrow glyph does not help where neither exists, so a text fallback is
    // needed.
    readonly property string pfeilLang:
        !root.ohneSonderzeichen && probePfeilL.implicitWidth !== probeLeer.implicitWidth
        ? "\u27F6" : "->"

    readonly property string pfeilKurz:
        !root.ohneSonderzeichen && probePfeilK.implicitWidth !== probeLeer.implicitWidth
        ? "\u2192" : "->"

    readonly property string currency: root.o("currency", "usd")
    readonly property bool walletEnabled: root.o("walletEnabled", false)
    // An invisible item keeps its height. Without this check the bare widget
    // would show an empty strip the height of the tab row at the top.
    readonly property real tabSpace: root.tabsVisible ? tabs.height + root.gap : 0

    // The wallet is dropped in direct mode, and not for convenience: key
    // derivation is work done by the service. A tab that can never show
    // anything is worse than no tab. The market is computed locally by
    // `DirectMarket`; only a missing QtWebSockets removes it. (Without a device
    // the miner tab shows the network.)
    readonly property bool canMarket: !!(root.feed && root.feed.canMarket)

    // Every tab can be turned off, and the user owns the order. Without a miner
    // the miner tab is not needed; someone who mostly watches the market moves
    // it to the front. Both live in `tabOrder` and the `show...` switches and
    // are computed in `views.js`, the one place that lists the views.
    //
    // Whatever is technically impossible is dropped anyway; the switch comes on
    // top and cannot force anything. Settings always stay, otherwise turning off
    // the last tab would leave no way back to any switch.
    readonly property var tabViews: Views.reiter(
        root.o("tabOrder", []),
        function (id) {
            // The miner tab is always possible: without a device of its own it
            // shows the network.
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

    // The labels in the same order, from the same table, so there is no second
    // hand-maintained list that can drift apart.
    readonly property var tabLabels: {
        var l = [];
        for (var i = 0; i < root.tabViews.length; i++)
            l.push(Tr.t(Views.name(root.tabViews[i]), root.lang));
        return l;
    }

    // If the view sits on a tab that does not exist right now, fall back to the
    // first existing one, otherwise an empty page stays up.
    //
    // Not hard-coded to 0. With the feed turned off, 0 is itself not an
    // existing tab, and the request would repeat on every pass and loop.
    // `tabViews[0]` always exists; the list holds at least the settings.
    //
    // Deliberately no `onViewChanged` next to it. It is tempting, since the
    // fallback should also apply when the view is set from outside, but it
    // breaks the display. `view` is bound to the window (`view: win.view`); a
    // handler that writes back to the source while that binding updates is a
    // binding loop, and QML resolves it by dropping the binding. After that the
    // window shows the right view and `FeedTabs` the old one, leaving an empty
    // page. The "set from outside" case therefore belongs in `Main.qml`, right
    // after the assignment.
    function reiterPruefen() {
        if (!root.tabsVisible || root.tabViews.length === 0)
            return;
        // Without a settings tab, the settings are reached through the gear. Being
        // thrown out as soon as a switch there changes the tabs would be exactly
        // wrong.
        if (root.view === 5 && !root.settingsTab)
            return;
        if (root.tabViews.indexOf(root.view) < 0)
            root.viewRequested(root.tabViews[0]);
    }

    onTabViewsChanged: root.reiterPruefen()

    // ------------------------------------------------- Rotating tabs
    // For a block clock on the wall: every `tabRotate` seconds the next station.
    // Mining counts twice (device and network are two stations), otherwise the
    // wall would only ever show the page that was last open.
    //
    // Switching goes through the same paths as a tap (`viewRequested`,
    // `optRequested("minerPane")`); the host stores both as usual.
    //
    // Not in the rotation: Wallet (does not belong on a wall) and Settings.
    // While Settings is open the rotation pauses, otherwise it would pull the
    // page away while the user is changing something.
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

    // A touch resets the timer. Someone reading something on the wall should
    // not have the page switch away under their finger. Observe only
    // (PointHandler does not grab): buttons, charts and scrolling get their
    // events as before.
    //
    // In its own top layer, not on the root item: there it ran after the views,
    // and a chart with its own MouseArea had already taken the press, so the
    // rotation switched pages despite the click.
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

            // Private use area: deliberately something no font ever has.
            text: "\uE000"
            font.family: Fonts.sans()
            font.pixelSize: 64
        }
    }

    // Swipeable when the tabs do not fit. The row has no width limit and on a
    // narrow phone (384 points) it ran under the fullscreen button with the
    // market tab. `tabsRechts` keeps the host's buttons clear.
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
        // Pass it on: the host takes back its keyboard shortcuts.
        onSearchFocusReleased: root.searchFocusReleased()
        onSearchFocusTaken: root.searchFocusTaken()
    }

    MarketView {
        visible: root.live && root.view === 6 && root.canMarket
        // Only poll while the tab is open; every request keeps the exchange
        // streams alive in the service.
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
        // Only ask while the view is visible
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
        // Lets the display page note which view could show nothing right now.
        // The same question as in `tabViews`, asked the other way round; it lives
        // here because only this component knows the feed.
        // What the host technically cannot do gets no page in the settings
        // either (see there).
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

    // Trigger the block animation by hand. The window binds it to the b key,
    // for testing without waiting ten minutes.
    function triggerBlockAnimation() {
        halde.triggerBlockAnimation();
    }

    // The miner has two buttons that sit in the top right bar in the dashboard
    // instead of next to it. This component passes them through so the host
    // can place them there.
    readonly property string minerWebUrl: miner.webUrl

    function minerOpenWeb() {
        miner.openWeb();
    }

    function minerToggleInfo() {
        miner.toggleInfo();
    }

    // Controllable from outside: the host can jump straight into a transaction
    // from the pill.
    function goExplorer(art, wert) {
        root.viewRequested(3);
        explorer.go(art, wert);
    }
}
