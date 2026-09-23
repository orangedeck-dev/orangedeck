// Bar widget: pill with the mempool count, click opens the live view.
// Right click opens it in a separate window.
// Also available as a Control Center tile with an expandable view.
//
// Popout and tile show the same set of views as the dashboard
// (`FeedTabs.qml`) and read the same settings.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "strings.js" as Tr

PluginComponent {
    id: root

    // Same language as the views inside; empty means the DMS language.
    readonly property string dmsLang: Tr.systemLang(SessionData.locale)
    readonly property string lang: String(root.get("lang", "") || "") || root.dmsLang

    function t(schluessel, a0, a1) {
        return Tr.t(schluessel, root.lang, a0, a1);
    }

    property string windowCommand: Quickshell.env("HOME") + "/.local/bin/orangedeck-window"
    readonly property string pid: "orangedeck"

    // Formatted like every other number: `Tr.group` picks the separator by
    // language, so the English UI shows "78,324 transactions in the mempool".
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function shortCount(n) {
        if (!n)
            return "–";
        return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k" : String(n);
    }

    FeedState {
        id: feedState

        // The pill only shows text: block height and mempool count. They hardly
        // change second by second, and the pill is always visible, so whatever it
        // costs it costs all day. Two requests per second would be four times
        // more than needed.
        pollMs: 2000
        mode: root.get("dataSource", "auto")
    }

    // ------------------------------------------------------ Settings
    // Same storage as the dashboard tab: `PluginService.loadPluginData`
    // passes through to `SettingsData.getPluginSetting`. Whatever is changed
    // here shows up there and vice versa.
    function get(key, def) {
        return root.pluginService ? root.pluginService.loadPluginData(root.pid, key, def) : def;
    }

    function getList(key, def) {
        var v = String(root.get(key, def) || "");
        return v.length ? v.split("|") : [];
    }

    // Rebuilt whenever DMS reports a change; one binding per setting would be
    // thirty bindings all doing the same thing.
    property var opts: root.buildOpts()
    property int view: root.get("view", 0)

    function buildOpts() {
        return ({
            "dataSource": root.get("dataSource", "auto"),
            "currency": root.get("currency", "usd"),
            // Empty means FeedTabs uses the system language.
            "lang": root.get("lang", ""),
            "density": root.get("density", 1),
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

    function put(key, value) {
        if (!root.pluginService)
            return;
        root.pluginService.savePluginData(root.pid, key, value);
    }

    function setOpt(key, value) {
        // Lists come in as arrays and are stored as strings, otherwise an empty
        // list does not survive storage.
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

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pid)
                return;
            root.opts = root.buildOpts();
            root.view = root.get("view", 0);
        }
    }

    function openInWindow() {
        openWindow.running = false;
        openWindow.running = true;
    }

    Process {
        id: openWindow

        command: [root.windowCommand]
        running: false
    }

    // The separate window only exists when OrangeDeck is installed on the
    // machine. Installed from the DMS plugin registry, the plugin is all there
    // is, and an "open in separate window" button would lead nowhere. Checked
    // once at startup, not on every click: the answer practically never
    // changes during a session, and `test -x` per right click would be a
    // process for nothing.
    property bool fensterMoeglich: false

    Process {
        id: fensterProbe

        command: ["test", "-x", root.windowCommand]
        running: true

        onExited: function (exitCode) {
            root.fensterMoeglich = exitCode === 0;
        }
    }

    // ------------------------------------------------ Control Center tile
    ccWidgetIcon: "currency_bitcoin"
    ccWidgetPrimaryText: "Bitcoin"
    ccWidgetSecondaryText: feedState.online
        ? root.t("feed.inMempool", root.grp(feedState.mempoolCount)) : root.t("dms.offline")
    ccWidgetIsActive: feedState.online

    ccDetailContent: Component {
        Rectangle {
            implicitHeight: 340
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            FeedTabs {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                feed: feedState
                opts: root.opts
                defaultLang: root.dmsLang
                view: root.view
                gap: Theme.spacingS
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
        }
    }

    // ------------------------------------------------------------- Pill
    pillRightClickAction: () => {
        if (root.fensterMoeglich)
            root.openInWindow();
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "currency_bitcoin"
                size: Theme.fontSizeMedium + 2
                color: feedState.online ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.shortCount(feedState.mempoolCount)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 0

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "currency_bitcoin"
                size: Theme.fontSizeMedium
                color: feedState.online ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.shortCount(feedState.mempoolCount)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall - 2
            }
        }
    }

    // ------------------------------------------------------------- Popout
    // With tab bar and legend the feed needs room, and below 420 px of height
    // the legend is dropped.
    popoutWidth: 720
    popoutHeight: 560

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "OrangeDeck"
            detailsText: feedState.online
                ? root.t("dms.details", root.grp(feedState.tipHeight), root.grp(feedState.mempoolCount))
                : root.t("dms.offlineHint")
            showCloseButton: true

            headerActions: Component {
                DankActionButton {
                    visible: root.fensterMoeglich
                    iconName: "open_in_new"
                    buttonSize: 30
                    tooltipText: root.t("dms.ownWindow")
                    onClicked: {
                        root.openInWindow();
                        if (popout.closePopout)
                            popout.closePopout();
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.max(200, root.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingL * 2)

                FeedTabs {
                    anchors.fill: parent
                    feed: feedState
                    opts: root.opts
                    defaultLang: root.dmsLang
                    view: root.view
                    gap: Theme.spacingM
                    tabFont: Theme.fontSizeSmall
                    baseFont: Theme.fontSizeSmall + 1
                    textColor: Theme.surfaceText
                    dimColor: Theme.surfaceVariantText
                    accentColor: Theme.primary
                    lineColor: Theme.outlineMedium
                    frostedTint: Theme.surfaceContainer
                    onOptRequested: function (key, value) {
                        root.setOpt(key, value);
                    }
                    onViewRequested: function (v) {
                        root.put("view", v);
                    }
                }
            }
        }
    }
}
