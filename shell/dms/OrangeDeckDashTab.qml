// Dashboard tab for DMS 2.0 and newer (`components.dash` in plugin.json).
//
// Older DMS versions do not know the "dash" surface. They skip it with one
// log line and load the other surfaces as before, so this file is never
// compiled there. That is why it may use types that only exist since 2.0
// (`DashTabComponent`, `qs.DCommon.Widgets`).
//
// Open it with `dms ipc call dash open plugin_orangedeck`.
//
// The content is the same as in the dashboard tab that orangedeck-dashtab
// patches into DMS 1.6 (`BITCOIN_TAB` there): the views come from
// `FeedTabs.qml`, the settings are the plugin settings. Only the frame is
// different. DMS sets `live` itself here (tab shown and dash open), so the
// tab no longer needs a binding from outside.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DDash
import "strings.js" as Tr

DashTabComponent {
    id: root

    // The other tabs grow with their rows; this one needs a fixed minimum.
    // Below 520 the price curve in the clock view shrinks to a line (see the
    // note on the height in BITCOIN_TAB). The width comes from the dash.
    implicitHeight: Math.max(DashMetrics.tabMinHeight, 520)
    clip: true

    readonly property string pid: "orangedeck"
    readonly property string desktopInstance: "orangedeck-1"

    function t(key) {
        return Tr.t(key, root.lang);
    }

    // The same settings as the window and the bar popout. Lists are stored as
    // strings: an empty list survives neither QSettings nor the plugin store
    // reliably.
    property string colorMode: SettingsData.getPluginSetting(pid, "colorMode", "age")
    property string sizeMode: SettingsData.getPluginSetting(pid, "sizeMode", "value")
    property string dataSource: SettingsData.getPluginSetting(pid, "dataSource", "daemon")
    property string mempoolHost: SettingsData.getPluginSetting(pid, "mempoolHost", "")
    property string minerHostsRaw: SettingsData.getPluginSetting(pid, "minerHostsRaw", "")
    property string currency: SettingsData.getPluginSetting(pid, "currency", "usd")
    property string lang: SettingsData.getPluginSetting(pid, "lang", "") || Tr.systemLang(SessionData.locale)
    property bool showHeader: SettingsData.getPluginSetting(pid, "showHeader", true)
    property bool showFooter: SettingsData.getPluginSetting(pid, "showFooter", true)
    property bool showBlock: SettingsData.getPluginSetting(pid, "showBlock", true)
    property bool showRuler: SettingsData.getPluginSetting(pid, "showRuler", true)
    property bool showInfo: SettingsData.getPluginSetting(pid, "showInfo", true)
    property bool showLegend: SettingsData.getPluginSetting(pid, "showLegend", true)
    property bool frosted: SettingsData.getPluginSetting(pid, "frosted", true)
    property real density: SettingsData.getPluginSetting(pid, "density", 1)
    property string tileColorMode: SettingsData.getPluginSetting(pid, "tileColorMode", "fee")
    property bool clockBars: SettingsData.getPluginSetting(pid, "clockBars", true)
    property bool clockSpark: SettingsData.getPluginSetting(pid, "clockSpark", true)
    property bool clockTime: SettingsData.getPluginSetting(pid, "clockTime", false)
    property bool clockPrice: SettingsData.getPluginSetting(pid, "clockPrice", true)
    property string priceSpan: SettingsData.getPluginSetting(pid, "priceSpan", "30d")
    property string marketRange: SettingsData.getPluginSetting(pid, "marketRange", "24h")
    property string marketKind: SettingsData.getPluginSetting(pid, "marketKind", "candles")
    property string marketLower: SettingsData.getPluginSetting(pid, "marketLower", "volume")
    property string marketSub: SettingsData.getPluginSetting(pid, "marketSub", "price")
    property int marketSecs: SettingsData.getPluginSetting(pid, "marketSecs", 259200)
    property int marketVon: SettingsData.getPluginSetting(pid, "marketVon", 0)
    property int marketBis: SettingsData.getPluginSetting(pid, "marketBis", 0)
    property bool marketCross: SettingsData.getPluginSetting(pid, "marketCross", true)
    property bool marketTape: SettingsData.getPluginSetting(pid, "marketTape", true)
    property bool showFeed: SettingsData.getPluginSetting(pid, "showFeed", true)
    property bool showClock: SettingsData.getPluginSetting(pid, "showClock", true)
    property bool showMiner: SettingsData.getPluginSetting(pid, "showMiner", true)
    property bool showExplorer: SettingsData.getPluginSetting(pid, "showExplorer", true)
    property bool showMarket: SettingsData.getPluginSetting(pid, "showMarket", true)
    property bool minerChart: SettingsData.getPluginSetting(pid, "minerChart", true)
    property bool minerDomains: SettingsData.getPluginSetting(pid, "minerDomains", true)
    property bool minerBoard: SettingsData.getPluginSetting(pid, "minerBoard", true)
    property string minerPane: SettingsData.getPluginSetting(pid, "minerPane", "")
    property string netSpan: SettingsData.getPluginSetting(pid, "netSpan", "1y")
    property string poolTypesView: SettingsData.getPluginSetting(pid, "poolTypesView", "balken")
    property string poolTypesBy: SettingsData.getPluginSetting(pid, "poolTypesBy", "hash")
    property bool explorerLive: SettingsData.getPluginSetting(pid, "explorerLive", true)
    property string clockFieldsRaw: SettingsData.getPluginSetting(pid, "clockFieldsRaw", "")
    property string minerFieldsRaw: SettingsData.getPluginSetting(pid, "minerFieldsRaw", "")
    property string explorerPartsRaw: SettingsData.getPluginSetting(pid, "explorerPartsRaw", "")
    property string minerPanesRaw: SettingsData.getPluginSetting(pid, "minerPanesRaw", "")
    property string netPartsRaw: SettingsData.getPluginSetting(pid, "netPartsRaw", "")
    property bool minerSolo: SettingsData.getPluginSetting(pid, "minerSolo", true)
    property int tabRotate: SettingsData.getPluginSetting(pid, "tabRotate", 0)
    property string tabRotateViewsRaw: SettingsData.getPluginSetting(pid, "tabRotateViewsRaw", "")
    property string explorerPanelsRaw: SettingsData.getPluginSetting(pid, "explorerPanelsRaw", "")
    property string bigFieldsRaw: SettingsData.getPluginSetting(pid, "bigFieldsRaw", "height")
    // Tab order chosen by the user. Empty means the default order from
    // `views.js`.
    property string tabOrderRaw: SettingsData.getPluginSetting(pid, "tabOrderRaw", "")
    property int bigRotate: SettingsData.getPluginSetting(pid, "bigRotate", 0)
    readonly property var bigFields: bigFieldsRaw.length ? bigFieldsRaw.split("|") : ["height"]
    readonly property var clockFields: clockFieldsRaw.length ? clockFieldsRaw.split("|") : []
    readonly property var minerFields: minerFieldsRaw.length ? minerFieldsRaw.split("|") : []
    readonly property var explorerParts: explorerPartsRaw.length ? explorerPartsRaw.split("|") : []
    readonly property var minerPanes: minerPanesRaw.length ? minerPanesRaw.split("|") : []
    readonly property var netParts: netPartsRaw.length ? netPartsRaw.split("|") : []
    readonly property var tabRotateViews: tabRotateViewsRaw.length ? tabRotateViewsRaw.split("|") : []
    readonly property var explorerPanels: explorerPanelsRaw.length ? explorerPanelsRaw.split("|") : []
    readonly property var tabOrder: tabOrderRaw.length ? tabOrderRaw.split("|") : []
    // 0 = feed, 1 = clock, 2 = miner, 3 = explorer, 5 = settings,
    // 6 = market. A stored 4 (the old wallet) is caught by `FeedTabs`.
    property int view: SettingsData.getPluginSetting(pid, "view", 0)

    readonly property var opts: ({
        "dataSource": dataSource,
        "mempoolHost": mempoolHost,
        "minerHostsRaw": minerHostsRaw,
        "currency": currency,
        "lang": lang,
        "density": density,
        "colorMode": colorMode,
        "sizeMode": sizeMode,
        "showHeader": showHeader,
        "showFooter": showFooter,
        "showBlock": showBlock,
        "showInfo": showInfo,
        "showLegend": showLegend,
        "showRuler": showRuler,
        "frosted": frosted,
        "tileColorMode": tileColorMode,
        "clockBars": clockBars,
        "clockSpark": clockSpark,
        "clockTime": clockTime,
        "clockPrice": clockPrice,
        "priceSpan": priceSpan,
        "marketRange": marketRange,
        "marketKind": marketKind,
        "marketLower": marketLower,
        "marketSub": marketSub,
        "marketSecs": marketSecs,
        "marketVon": marketVon,
        "marketBis": marketBis,
        "marketCross": marketCross,
        "marketTape": marketTape,
        "showFeed": showFeed,
        "showClock": showClock,
        "showMiner": showMiner,
        "showExplorer": showExplorer,
        "showMarket": showMarket,
        "clockFields": clockFields,
        "bigFields": bigFields,
        "bigRotate": bigRotate,
        "minerChart": minerChart,
        "minerDomains": minerDomains,
        "minerBoard": minerBoard,
        "minerPane": minerPane,
        "netSpan": netSpan,
        "poolTypesView": poolTypesView,
        "poolTypesBy": poolTypesBy,
        "minerFields": minerFields,
        "explorerLive": explorerLive,
        "explorerParts": explorerParts,
        "minerPanes": minerPanes,
        "netParts": netParts,
        "minerSolo": minerSolo,
        "tabRotate": tabRotate,
        "tabRotateViews": tabRotateViews,
        "explorerPanels": explorerPanels,
        "tabOrder": tabOrder
    })

    function put(key, value) {
        SettingsData.setPluginSetting(pid, key, value);
        root[key] = value;
    }

    function setOpt(key, value) {
        // Lists come in as arrays and are stored as strings
        if (key === "clockFields" || key === "minerFields" || key === "bigFields"
                || key === "explorerParts" || key === "explorerPanels"
                || key === "minerPanes" || key === "netParts"
                || key === "tabRotateViews"
                || key === "tabOrder") {
            root.put(key + "Raw", (value || []).join("|"));
            return;
        }
        root.put(key, value);
    }

    property bool desktopOn: {
        const list = SettingsData.desktopWidgetInstances || [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === desktopInstance)
                return list[i].enabled === true;
        }
        return false;
    }

    function setDesktop(on) {
        SettingsData.updateDesktopWidgetInstance(desktopInstance, {
            "enabled": on
        });
        root.desktopOn = on;
    }

    function openInWindow() {
        openWindow.running = false;
        openWindow.running = true;
    }

    // The window from the dash's edit-mode menu as well.
    menuActions: fensterMoeglich ? [
        {
            label: root.t("dms.ownWindow"),
            iconName: "open_in_new",
            action: () => root.openInWindow()
        }
    ] : []

    FeedState {
        id: feedState

        // Nothing is fetched while nobody looks
        active: root.live
        mode: root.dataSource
        mempoolHost: root.mempoolHost
        minerHostsRaw: root.minerHostsRaw
    }

    FeedTabs {
        id: ansichten

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        anchors.topMargin: Theme.spacingS
        live: root.live
        feed: feedState
        opts: root.opts
        view: root.view
        // The miner buttons sit in the row at the top right, where they
        // cannot cover anything.
        minerActions: false
        // Opacity and start view belong to the window; in the dash DMS draws
        // the surface.
        windowedSettings: false
        gap: Theme.spacingM
        tabFont: Theme.fontSizeSmall
        baseFont: Theme.fontSizeSmall + 1
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
        lineColor: Theme.outlineMedium
        panelColor: Theme.surfaceContainerHighest
        frostedTint: Theme.surfaceContainer
        onOptRequested: function (key, value) {
            root.setOpt(key, value);
        }
        onViewRequested: function (v) {
            root.put("view", v);
        }
    }

    Process {
        id: openWindow

        command: [Quickshell.env("HOME") + "/.local/bin/orangedeck-window"]
        running: false
    }

    // The separate window only exists when OrangeDeck is installed on the
    // machine; installed from the registry the button would lead nowhere.
    // Checked once, as in the bar widget.
    property bool fensterMoeglich: false

    Process {
        id: fensterProbe

        command: ["test", "-x", Quickshell.env("HOME") + "/.local/bin/orangedeck-window"]
        running: true

        onExited: function (exitCode) {
            root.fensterMoeglich = exitCode === 0;
        }
    }

    Row {
        id: actions

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.spacingXS
        anchors.topMargin: Theme.spacingXXS
        spacing: 2

        DActionButton {
            visible: root.view === 2 && ansichten.minerWebUrl !== ""
            iconName: "lan"
            buttonSize: 28
            tooltipText: "Weboberfläche des Miners öffnen"
            onClicked: ansichten.minerOpenWeb()
        }

        DActionButton {
            visible: root.view === 2
            iconName: "info"
            buttonSize: 28
            tooltipText: root.t("set.legend")
            onClicked: ansichten.minerToggleInfo()
        }

        DActionButton {
            visible: root.fensterMoeglich
            iconName: "open_in_new"
            buttonSize: 28
            tooltipText: root.t("dms.ownWindow")
            onClicked: root.openInWindow()
        }

        DActionButton {
            iconName: "settings"
            buttonSize: 28
            tooltipText: root.t("tab.settings")
            onClicked: settingsPanel.visible = !settingsPanel.visible
        }
    }

    Rectangle {
        id: settingsPanel

        anchors.right: actions.right
        anchors.top: actions.bottom
        anchors.topMargin: 4
        width: 250
        height: settingsCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.outlineMedium
        visible: false
        z: 100

        Column {
            id: settingsCol

            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            DToggle {
                width: parent.width
                text: "Desktop-Widget"
                checked: root.desktopOn
                onToggled: checked => root.setDesktop(checked)
            }

            // Everything else is on the settings page; only what concerns the
            // dash stays here.
            Rectangle {
                width: parent.width
                height: mehrText.height + Theme.spacingM
                radius: Theme.cornerRadius
                color: mehrMaus.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    id: mehrText

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingS
                    text: root.t("tab.settings") + " ›"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                }

                MouseArea {
                    id: mehrMaus

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        settingsPanel.visible = false;
                        root.put("view", 5);
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 50
        visible: settingsPanel.visible
        onClicked: settingsPanel.visible = false
    }
}
