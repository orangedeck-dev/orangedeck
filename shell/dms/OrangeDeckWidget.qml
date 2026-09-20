// Leiste: Pille mit Mempool-Zahl, Klick oeffnet die Live-Ansicht.
// Rechtsklick oeffnet sie in einem eigenen Fenster.
// Ausserdem als Control-Center-Kachel mit ausklappbarer Ansicht.
//
// **Popout und Kachel zeigen denselben Satz Ansichten wie das Dashboard**
// (`FeedTabs.qml`) und lesen dieselben Einstellungen. Vorher stand hier nur der
// Feed, und von dreissig Einstellungen kamen vier an -- Sprache und Waehrung
// blieben auf den Vorgaben, obwohl sie anderswo eingestellt waren.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "strings.js" as Tr

PluginComponent {
    id: root

    // Dieselbe Sprache wie die Ansichten darin; leer heisst die des Systems.
    readonly property string lang: String(root.get("lang", "") || "") || Tr.systemLang()

    function t(schluessel, a0, a1) {
        return Tr.t(schluessel, root.lang, a0, a1);
    }

    property string windowCommand: Quickshell.env("HOME") + "/.local/bin/orangedeck-window"
    readonly property string pid: "orangedeck"

    function grp(n) {
        if (!n)
            return "–";
        var s = String(Math.round(n)), out = "", c = 0;
        for (var i = s.length - 1; i >= 0; i--) {
            out = s[i] + out;
            if (++c % 3 === 0 && i > 0)
                out = "." + out;
        }
        return out;
    }

    function shortCount(n) {
        if (!n)
            return "–";
        return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k" : String(n);
    }

    FeedState {
        id: feedState

        // Die Pille zeigt nur Text -- Blockhoehe und Mempool-Zahl. Die aendern
        // sich im Sekundentakt kaum, und die Pille ist **immer** sichtbar:
        // was sie kostet, kostet sie den ganzen Tag. Zwei Abfragen pro Sekunde
        // waren dafuer vierfach zu viel.
        pollMs: 2000
        mode: root.get("dataSource", "auto")
    }

    // ------------------------------------------------------ Einstellungen
    // Dieselbe Ablage wie im Dashboard-Tab: `PluginService.loadPluginData`
    // reicht auf `SettingsData.getPluginSetting` durch. Was hier umgestellt
    // wird, steht dort also auch -- und umgekehrt.
    function get(key, def) {
        return root.pluginService ? root.pluginService.loadPluginData(root.pid, key, def) : def;
    }

    function getList(key, def) {
        var v = String(root.get(key, def) || "");
        return v.length ? v.split("|") : [];
    }

    // Neu gebaut, sobald DMS meldet, dass sich etwas geaendert hat -- eine
    // Bindung je Einstellung waeren dreissig, die alle dasselbe tun.
    property var opts: root.buildOpts()
    property int view: root.get("view", 0)

    function buildOpts() {
        return ({
            "dataSource": root.get("dataSource", "auto"),
            "currency": root.get("currency", "usd"),
            // Leer heisst: FeedTabs nimmt die Sprache des Systems.
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
        // Listen kommen als Feld herein und gehen als Zeichenkette hinaus --
        // eine leere Liste ueberlebt die Ablage sonst nicht.
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

    // **Das eigene Fenster gibt es nur, wenn OrangeDeck auf dem Rechner
    // liegt.** Aus dem Verzeichnis von DMS installiert, ist das Plugin der
    // ganze Bestand -- dann fuehrt ein Knopf "in eigenem Fenster oeffnen" ins
    // Leere. Einmal beim Start nachgesehen, nicht bei jedem Klick: die Antwort
    // aendert sich waehrend einer Sitzung praktisch nie, und `test -x` je
    // Rechtsklick waere ein Prozess fuer nichts.
    property bool fensterMoeglich: false

    Process {
        id: fensterProbe

        command: ["test", "-x", root.windowCommand]
        running: true

        onExited: function (exitCode) {
            root.fensterMoeglich = exitCode === 0;
        }
    }

    // ------------------------------------------------ Control-Center-Kachel
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

    // ------------------------------------------------------------- Pille
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
    // Groesser als frueher: mit Reiterzeile und Legende braucht der Feed Platz,
    // und unter 420 Punkten Hoehe faellt die Legende weg.
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
