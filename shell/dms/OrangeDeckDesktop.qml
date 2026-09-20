// Desktop-Widget: **jede Ansicht**, frei platzier- und skalierbar.
//
// DMS legt jede Instanz eines Desktop-Widgets getrennt ab und reicht dem
// Bauteil einen instanzbezogenen `pluginService` durch (siehe
// DesktopPluginWrapper: `instanceScopedPluginService`). `loadPluginData` ist
// hier also **je Instanz** -- man kann denselben Feed dreimal aufs Desktop
// legen, einmal als Halde, einmal als Uhr, einmal als Miner.
//
// Gezeigt wird eine einzige Ansicht ohne Reiterzeile, gebaut wird sie aber aus
// demselben `FeedTabs` wie Dashboard und Popout (`tabsVisible: false`). Vorher
// standen die vier Ansichten hier ein zweites Mal verdrahtet -- und bekamen
// ihre Feineinstellungen nicht: die Uhr ohne Auswahl der Werte, der
// Miner ohne Kurve und Tafel, der Explorer ohne Startseite.
import QtQuick
import qs.Common

Item {
    id: root

    property var pluginService: null
    property string pluginId: "orangedeck"
    // Von DMS gesetzt, wenn es eine Instanz ist
    property string instanceId: ""
    property var instanceData: null
    property bool editMode: false
    property real widgetWidth: 420
    property real widgetHeight: 300

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

    // Gegenstueck zu `getList`: Listen kommen als Feld herein und gehen als
    // Zeichenkette hinaus -- eine leere Liste ueberlebt die Ablage sonst nicht.
    // Gleiche Schluesselliste wie im Leisten-Widget (OrangeDeckWidget.setOpt).
    function setOpt(key, value) {
        if (["clockFields", "minerFields", "bigFields", "explorerParts",
             "explorerPanels", "minerPanes", "netParts", "tabRotateViews",
             "tabOrder"].indexOf(key) >= 0) {
            root.put(key + "Raw", (value || []).join("|"));
            return;
        }
        root.put(key, value);
    }

    // Nur dem Desktop-Widget eigen: Untergrund und Kachelgroesse haengen daran,
    // wie gross das Fenster auf dem Schirm ist -- das ist je Instanz etwas
    // anderes als im Dashboard.
    property int bgOpacity: root.get("desktopOpacity", 70)
    property int tileDensity: root.get("tileDensity", 100)
    // Welche Ansicht dieses Widget zeigt: feed | clock | miner | explorer | wallet
    property string widgetView: root.get("widgetView", "feed")

    readonly property int viewIndex: {
        switch (root.widgetView) {
        case "clock":
            return 1;
        case "miner":
            return 2;
        case "explorer":
            return 3;
        case "wallet":
            return 4;
        default:
            return 0;
        }
    }

    property var opts: root.buildOpts()

    function buildOpts() {
        return ({
            "dataSource": root.get("dataSource", "auto"),
            "currency": root.get("currency", "usd"),
            // Leer heisst: FeedTabs nimmt die Sprache des Systems.
            "lang": root.get("lang", ""),
            // Die Kachelgroesse kommt hier aus der eigenen Einstellung
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
            "minerFields": root.getList("minerFieldsRaw", ""),
            "explorerLive": root.get("explorerLive", true),
            "explorerParts": root.getList("explorerPartsRaw", ""),
            "minerPanes": root.getList("minerPanesRaw", ""),
            "netParts": root.getList("netPartsRaw", ""),
            "minerSolo": root.get("minerSolo", true),
            "tabRotate": root.get("tabRotate", 0),
            "tabRotateViews": root.getList("tabRotateViewsRaw", ""),
            "explorerPanels": root.getList("explorerPanelsRaw", ""),
            "walletEnabled": root.get("walletEnabled", false),
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

    FeedState {
        id: feedState

        pollMs: 500
        mode: root.get("dataSource", "auto")
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
        anchors.margins: Theme.spacingM
        // Eine Ansicht, keine Reiterzeile
        tabsVisible: false
        // Eine Ansicht je Widget, kein Wechsel
        rotationAllowed: false
        view: root.viewIndex
        feed: feedState
        opts: root.opts
        // Auf dem Desktop stellt niemand Knoepfe -- das Widget ist zum Ansehen
        // da, nicht zum Bedienen. Aus demselben Grund holt sich das Suchfeld
        // des Explorers hier keinen Tastaturfokus.
        minerActions: false
        searchFocus: false
        baseFont: Theme.fontSizeSmall
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
        lineColor: Theme.outlineMedium
        panelColor: Theme.surfaceContainerHighest
        frostedTint: Theme.surfaceContainer

        // Ohne diesen Handler liefen alle Umschaltungen innerhalb der Ansicht
        // ins Leere: die Ansicht meldet sie ueber `optRequested`, der Wirt muss
        // sie ablegen. Das Leisten-Widget tat das, das Desktop-Widget nicht --
        // aufgefallen am 15.09.2026 am Miner-Umschalter "Network", betraf aber
        // jede Einstellung, die man in der Ansicht selbst anfasst.
        // `savePluginData` schreibt hier je Instanz (DMS reicht dem Bauteil
        // einen instanzbezogenen pluginService durch), zwei Widgets auf dem
        // Desktop bleiben also unabhaengig.
        onOptRequested: function (key, value) {
            root.setOpt(key, value);
        }
    }
}
