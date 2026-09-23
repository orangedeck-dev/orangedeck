import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "strings.js" as Tr

// Einstellungen des Plugins in DMS.
//
// **Der grosse Teil steht nicht hier**, sondern auf der Seite "Einstellungen"
// im Dashboard-Tab und im Fenster -- dort ist er nach Ansichten geordnet und
// in allen Sprachen. Hier bleibt, was DMS selbst betrifft: die Ansicht eines
// Desktop-Widgets und dessen Aussehen.
//
// DMS legt jede Desktop-Widget-Instanz getrennt ab. Wer den Feed dreimal aufs
// Desktop legt, kann jedem Fenster eine andere Ansicht geben.
PluginSettings {
    id: seite

    pluginId: "orangedeck"

    // **Dieselbe Sprache wie die Ansichten.** Bis zum 18.09.2026 stand diese
    // Seite als einzige nur auf Deutsch da, waehrend nebenan dreizehn
    // Sprachen liefen. Der Wert liegt in derselben Ablage wie alle anderen
    // Einstellungen des Plugins; leer heisst "die von DMS", genau wie in
    // `OrangeDeckWidget.qml`.
    readonly property string lang: (seite.pluginService
        ? String(seite.pluginService.loadPluginData("orangedeck", "lang", "") || "")
        : "") || Tr.systemLang(SessionData.locale)

    function t(schluessel) {
        return Tr.t(schluessel, seite.lang);
    }

    SelectionSetting {
        settingKey: "widgetView"
        label: seite.t("dms.widgetView")
        description: seite.t("dms.widgetViewHelp")
        options: [
            {label: seite.t("tab.feed"), value: "feed"},
            {label: seite.t("tab.clock"), value: "clock"},
            {label: seite.t("tab.miner"), value: "miner"},
            {label: seite.t("tab.explorer"), value: "explorer"},
            {label: seite.t("tab.wallet"), value: "wallet"}
        ]
        defaultValue: "feed"
    }

    SelectionSetting {
        settingKey: "colorMode"
        label: seite.t("set.tileColor")
        description: seite.t("set.tileColorHelp")
        options: [
            {label: seite.t("color.age"), value: "age"},
            {label: seite.t("color.fee"), value: "fee"},
            {label: seite.t("color.type"), value: "type"}
        ]
        defaultValue: "age"
    }

    SelectionSetting {
        settingKey: "sizeMode"
        label: seite.t("set.tileMetric")
        description: seite.t("set.tileMetricHelp")
        options: [
            {label: seite.t("feed.sizeValue"), value: "value"},
            {label: seite.t("feed.sizeVbytes"), value: "vbytes"}
        ]
        defaultValue: "value"
    }

    ToggleSetting {
        settingKey: "showInfo"
        label: seite.t("set.blockInfo")
        description: seite.t("set.blockInfoHelp")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showLegend"
        label: seite.t("set.legend")
        description: seite.t("set.legendHelp")
        defaultValue: true
    }

    // Gleicher Schluessel wie "Weichzeichnung hinter der Schrift" auf der
    // Einstellungsseite der Ansicht: aus heisst, die Kaestchen hinter Kopf,
    // Blockangaben und Legende fallen ganz weg. Das Desktop-Widget hat keine
    // Reiterzeile und damit keine eigene Einstellungsseite, darum steht er
    // auch hier.
    ToggleSetting {
        settingKey: "frosted"
        label: seite.t("set.blur")
        description: seite.t("set.blurHelp")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "desktopOpacity"
        label: seite.t("dms.desktopOpacity")
        description: seite.t("dms.desktopOpacityHelp")
        defaultValue: 70
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "tileDensity"
        label: seite.t("set.tileSize")
        description: seite.t("set.tileSizeHelp")
        defaultValue: 100
        minimum: 60
        maximum: 250
        unit: "%"
    }
}
