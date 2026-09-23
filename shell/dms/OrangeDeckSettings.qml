import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "strings.js" as Tr

// Plugin settings in DMS.
//
// Most settings are not here but on the "Settings" page in the dashboard
// tab and the window, grouped by view and translated into all languages.
// This page only holds what concerns DMS itself: the view of a desktop
// widget and its appearance.
//
// DMS stores each desktop widget instance separately. With the feed on
// the desktop three times, each window can show a different view.
PluginSettings {
    id: seite

    pluginId: "orangedeck"

    // Same language as the views. The value lives in the same storage as all
    // other plugin settings; empty means "the DMS language", as in
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

    // Same key as "Blur behind text" on the view's settings page: off means
    // the boxes behind header, block info and legend are dropped entirely.
    // The desktop widget has no tab bar and so no settings page of its own,
    // which is why the option is repeated here.
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
