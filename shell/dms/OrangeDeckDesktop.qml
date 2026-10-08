// Desktop widget: any view, freely placed and scaled.
//
// DMS stores each instance of a desktop widget separately and passes the
// component an instance-scoped `pluginService` (see DesktopPluginWrapper:
// `instanceScopedPluginService`). So `loadPluginData` is per instance here:
// the same feed can sit on the desktop three times, as pile, clock and miner.
//
// It shows a single view without the tab bar, but builds it from the same
// `FeedTabs` as dashboard and popout (`tabsVisible: false`), so every view
// gets its full set of options.
import QtQuick
import qs.Common
import qs.Services
import "strings.js" as Tr

Item {
    id: root

    property var pluginService: null
    property string pluginId: "orangedeck"
    // Set by DMS when this is an instance
    property string instanceId: ""
    property var instanceData: null
    property bool editMode: false
    property real widgetWidth: 420
    property real widgetHeight: 300
    // Set by DMS (DesktopPluginWrapper passes the screen it sits on)
    property var screen: null

    // A fullscreen window on this screen hides the widget completely. Then
    // nothing is fetched and nothing is drawn: without this the feed view
    // kept its 33 ms animation and its connection running under a game or a
    // video all evening. Older DMS versions lack the helper; there the
    // widget simply keeps running as before.
    readonly property bool covered: root.screen
        && typeof CompositorService.fullscreenToplevelOnScreen === "function"
        ? CompositorService.fullscreenToplevelOnScreen(root.screen) : false

    property real minWidth: 180
    property real minHeight: 120
    property real defaultWidth: 520
    property real defaultHeight: 380

    function get(key, def) {
        return root.pluginService ? root.pluginService.loadPluginData(root.pluginId, key, def) : def;
    }

    function getList(key, def) {
        var v = String(root.get(key, def) || "");
        return v.length ? v.split("|") : [];
    }

    function put(key, value) {
        if (root.pluginService)
            root.pluginService.savePluginData(root.pluginId, key, value);
    }

    // Counterpart to `getList`: lists come in as arrays and are stored as
    // strings, otherwise an empty list does not survive storage.
    // Same key list as in the bar widget (OrangeDeckWidget.setOpt).
    function setOpt(key, value) {
        if (["clockFields", "minerFields", "bigFields", "explorerParts",
             "explorerPanels", "minerPanes", "netParts", "tabRotateViews",
             "tabOrder"].indexOf(key) >= 0) {
            root.put(key + "Raw", (value || []).join("|"));
            return;
        }
        root.put(key, value);
    }

    // Desktop widget only: background and tile size depend on how large the
    // window is on screen, which differs per instance and from the dashboard.
    property int bgOpacity: root.get("desktopOpacity", 70)
    property int tileDensity: root.get("tileDensity", 100)
    // Which view this widget shows: feed | clock | miner | explorer.
    // A stored "wallet" (removed on 26.09.2026) falls back to the feed.
    property string widgetView: root.get("widgetView", "feed")

    readonly property int viewIndex: {
        switch (root.widgetView) {
        case "clock":
            return 1;
        case "miner":
            return 2;
        case "explorer":
            return 3;
        default:
            return 0;
        }
    }

    property var opts: root.buildOpts()

    function buildOpts() {
        return ({
            "dataSource": root.get("dataSource", "auto"),
            "mempoolHost": root.get("mempoolHost", ""),
            "minerHostsRaw": root.get("minerHostsRaw", ""),
            "poolUrl": root.get("poolUrl", ""),
            "poolAddress": root.get("poolAddress", ""),
            "currency": root.get("currency", "usd"),
            // Empty means FeedTabs uses the system language.
            "lang": root.get("lang", ""),
            // Tile size comes from this widget's own setting
            "density": Math.max(0.5, root.tileDensity / 100),
            "colorMode": root.get("colorMode", "age"),
            "sizeMode": root.get("sizeMode", "value"),
            "showHeader": root.get("showHeader", true),
            "showFooter": root.get("showFooter", true),
            "showBlock": root.get("showBlock", true),
            "showInfo": root.get("showInfo", true),
            "showLegend": root.get("showLegend", true),
            "showRuler": root.get("showRuler", true),
            "frosted": root.get("frosted", true),
            "tileColorMode": root.get("tileColorMode", "fee"),
            "clockBars": root.get("clockBars", true),
            "clockSpark": root.get("clockSpark", true),
            "clockTime": root.get("clockTime", false),
            "clockPrice": root.get("clockPrice", true),
            "priceSpan": root.get("priceSpan", "30d"),
            "marketRange": root.get("marketRange", "24h"),
            "marketKind": root.get("marketKind", "candles"),
            "marketLower": root.get("marketLower", "volume"),
            "marketSub": root.get("marketSub", "price"),
            "marketSecs": root.get("marketSecs", 259200),
            "marketVon": root.get("marketVon", 0),
            "marketBis": root.get("marketBis", 0),
            "marketCross": root.get("marketCross", true),
            "marketTape": root.get("marketTape", true),
            "showFeed": root.get("showFeed", true),
            "showClock": root.get("showClock", true),
            "showMiner": root.get("showMiner", true),
            "showExplorer": root.get("showExplorer", true),
            "showMarket": root.get("showMarket", true),
            "clockFields": root.getList("clockFieldsRaw", ""),
            "bigFields": root.getList("bigFieldsRaw", "height"),
            "bigRotate": root.get("bigRotate", 0),
            "minerChart": root.get("minerChart", true),
            "minerDomains": root.get("minerDomains", true),
            "minerBoard": root.get("minerBoard", true),
            "minerPane": root.get("minerPane", ""),
            "netSpan": root.get("netSpan", "1y"),
            "poolTypesView": root.get("poolTypesView", "balken"),
            "poolTypesBy": root.get("poolTypesBy", "hash"),
            "minerFields": root.getList("minerFieldsRaw", ""),
            "explorerLive": root.get("explorerLive", true),
            "explorerParts": root.getList("explorerPartsRaw", ""),
            "minerPanes": root.getList("minerPanesRaw", ""),
            "netParts": root.getList("netPartsRaw", ""),
            "minerSolo": root.get("minerSolo", true),
            "tabRotate": root.get("tabRotate", 0),
            "tabRotateViews": root.getList("tabRotateViewsRaw", ""),
            "explorerPanels": root.getList("explorerPanelsRaw", ""),
            "tabOrder": root.getList("tabOrderRaw", "")
        });
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId)
                return;
            root.bgOpacity = root.get("desktopOpacity", 70);
            root.tileDensity = root.get("tileDensity", 100);
            root.widgetView = root.get("widgetView", "feed");
            root.opts = root.buildOpts();
        }
    }

    // The feed shared through the plugin daemon (OrangeDeckDaemon.qml), as
    // long as this instance reads its data the same way as the plugin. An
    // instance with a source of its own (data source, mempool instance, miner
    // address set only here) keeps its own FeedState, as does every widget
    // while the daemon is missing.
    readonly property var daemon: PluginService.pluginDaemonInstances
        ? (PluginService.pluginDaemonInstances[root.pluginId] || null) : null
    readonly property bool sameSource: {
        SettingsData.pluginSettings;
        var o = root.opts;
        return o.dataSource === SettingsData.getPluginSetting(root.pluginId, "dataSource", "auto")
            && o.mempoolHost === SettingsData.getPluginSetting(root.pluginId, "mempoolHost", "")
            && o.minerHostsRaw === SettingsData.getPluginSetting(root.pluginId, "minerHostsRaw", "");
    }
    readonly property var sharedFeed: root.sameSource && root.daemon && root.daemon.feed
        ? root.daemon.feed : null
    readonly property var feedState: root.sharedFeed || ownFeed

    // Registered while it shows the shared feed, is visible and not covered
    readonly property string viewerKey: "desktop-" + (root.instanceId || String(root))
    readonly property bool viewing: root.sharedFeed !== null && !root.covered && root.visible

    onViewingChanged: root.anmelden()
    onDaemonChanged: root.anmelden()
    onViewerKeyChanged: root.anmelden()
    Component.onCompleted: root.anmelden()
    Component.onDestruction: root.abmelden()

    // The key under which this host is registered. DMS sets `instanceId` only
    // after creation, so the key can change once; the old entry has to go,
    // otherwise it would keep the feed at the fast pace for good.
    property string gemeldet: ""
    property var gemeldetBei: null

    function abmelden() {
        if (root.gemeldetBei && root.gemeldet)
            root.gemeldetBei.setViewer(root.gemeldet, "");
        root.gemeldet = "";
        root.gemeldetBei = null;
    }

    function anmelden() {
        root.abmelden();
        if (!root.daemon || !root.daemon.setViewer)
            return;
        var art = root.viewing ? "desktop" : "";
        if (!art)
            return;
        root.daemon.setViewer(root.viewerKey, art);
        root.gemeldet = root.viewerKey;
        root.gemeldetBei = root.daemon;
    }

    FeedState {
        id: ownFeed

        active: root.sharedFeed === null && !root.covered && root.visible
        pollMs: 500
        mode: root.get("dataSource", "auto")
        mempoolHost: root.opts.mempoolHost || ""
        minerHostsRaw: root.opts.minerHostsRaw || ""
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: Math.max(0, Math.min(100, root.bgOpacity)) / 100
        border.width: root.editMode ? 2 : 0
        border.color: root.editMode ? Theme.primary : "transparent"
    }

    FeedTabs {
        anchors.fill: parent
        // Without a choice in the plugin: the DMS language
        defaultLang: Tr.systemLang(SessionData.locale)
        anchors.margins: Theme.spacingM
        live: !root.covered
        // One view, no tab bar
        tabsVisible: false
        // One view per widget, no switching
        rotationAllowed: false
        view: root.viewIndex
        feed: root.feedState
        opts: root.opts
        // Nobody adjusts buttons on the desktop; the widget is for looking, not
        // for operating. For the same reason the explorer's search field does not
        // take keyboard focus here.
        minerActions: false
        searchFocus: false
        baseFont: Theme.fontSizeSmall
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
        lineColor: Theme.outlineMedium
        panelColor: Theme.surfaceContainerHighest
        frostedTint: Theme.surfaceContainer

        // Without this handler every toggle inside the view would go nowhere: the
        // view reports it via `optRequested` and the host has to store it.
        // `savePluginData` writes per instance here (DMS passes an
        // instance-scoped pluginService), so two widgets on the desktop stay
        // independent.
        onOptRequested: function (key, value) {
            root.setOpt(key, value);
        }
    }
}
