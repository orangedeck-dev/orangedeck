// Eigenstaendiges Fenster: qs -p ~/.config/quickshell/OrangeDeckApp
// oder bequemer ueber ~/.local/bin/orangedeck-window
import QtQuick
import Quickshell
import Quickshell.Io
import "strings.js" as Tr

ShellRoot {
    FloatingWindow {
        id: win

        title: "OrangeDeck"
        implicitWidth: 1100
        implicitHeight: 800
        minimumSize.width: 260
        minimumSize.height: 160
        // Deckkraft macht das Fenster selbst, den Blur macht niri (Regel in
        // ~/.config/niri/config.kdl). Kacheln und Schrift bleiben deckend.
        color: Qt.rgba(0.043, 0.043, 0.071, win.bgOpacity)

        property string colorMode: "age"
        property string sizeMode: "value"
        property bool showInfo: true
        property bool showLegend: true
        property bool showRuler: true
        property bool frosted: true
        property real bgOpacity: 0.82
        property real density: 1.0
        property int startView: -1
        // Die Reihenfolge der Reiter, vom Anwender festgelegt. Leer heisst:
        // die Grundreihenfolge aus `views.js`.
        property var tabOrder: []
        // "daemon" oder "direct" -- siehe FeedState.mode
        property string dataSource: "daemon"
        property string mempoolHost: ""
        // Vorgabe USD, wie in app/qml/Main.qml und FeedTabs.
        property string currency: "usd"
        property string tileColorMode: "fee"
        property bool clockBars: true
        property var clockFields: []
        property var minerFields: []
        property bool showHeader: true
        property bool showFooter: true
        property bool showBlock: true
        property bool clockSpark: true
        property bool clockTime: false
        property bool clockPrice: true
        property string priceSpan: "30d"
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
        property string minerPane: ""
        property string netSpan: "1y"
        property bool explorerLive: true
        property var explorerParts: []
        property var minerPanes: []
        property var netParts: []
        property bool minerSolo: true
        property int tabRotate: 0
        property var tabRotateViews: []
        property var explorerPanels: []
        property string lang: Tr.systemLang()
        property var bigFields: ["height"]
        property int bigRotate: 0
        // Aus, bis sie in den Einstellungen ausdruecklich eingeschaltet wird
        property bool walletEnabled: false
        // 0 Feed, 1 Uhr, 2 Miner, 3 Explorer, 4 Wallet, 5 Einstellungen
        property int view: 0

        // Welche Reiter es gibt, rechnet `FeedTabs` -- samt Rueckfall auf den
        // Feed, wenn die gemerkte Ansicht gerade keinen Reiter hat. Hier stand
        // dieselbe Rechnung vorher ein zweites Mal.
        //
        // Drei fallen im Direktbezug weg, und zwar nicht aus Bequemlichkeit:
        // der Miner steht im Heimnetz, die Wallet-Ableitung ist Rechenarbeit
        // des Dienstes, und die Boersentrades werden dort zu Kerzen
        // verdichtet. Ein Reiter, hinter dem nichts sein kann, ist schlimmer
        // als keiner.

        readonly property var opts: ({
            "bgOpacity": bgOpacity,
            "density": density,
            "startView": startView,
            "dataSource": dataSource,
            "mempoolHost": mempoolHost,
            "colorMode": colorMode,
            "sizeMode": sizeMode,
            "showInfo": showInfo,
            "showLegend": showLegend,
            "showRuler": showRuler,
            "frosted": frosted,
            "currency": currency,
            "tileColorMode": tileColorMode,
            "clockBars": clockBars,
            "clockFields": clockFields,
            "minerFields": minerFields,
            "showHeader": showHeader,
            "showFooter": showFooter,
            "showBlock": showBlock,
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
            "minerChart": minerChart,
            "minerDomains": minerDomains,
            "minerBoard": minerBoard,
            "minerPane": minerPane,
            "netSpan": netSpan,
            "explorerLive": explorerLive,
            "explorerParts": explorerParts,
            "minerPanes": minerPanes,
            "netParts": netParts,
            "minerSolo": minerSolo,
            "tabRotate": tabRotate,
            "tabRotateViews": tabRotateViews,
            "explorerPanels": explorerPanels,
            "lang": lang,
            "bigFields": bigFields,
            "bigRotate": bigRotate,
            "walletEnabled": walletEnabled,
            "tabOrder": tabOrder
        })

        function setOpt(key, value) {
            if (key === "bgOpacity")
                bgOpacity = value;
            else if (key === "density")
                density = value;
            else if (key === "startView")
                startView = value;
            else if (key === "dataSource")
                dataSource = value;
            else if (key === "mempoolHost")
                mempoolHost = (value || "").trim();
            else if (key === "colorMode")
                colorMode = value;
            else if (key === "sizeMode")
                sizeMode = value;
            else if (key === "showInfo")
                showInfo = value;
            else if (key === "showLegend")
                showLegend = value;
            else if (key === "showRuler")
                showRuler = value;
            else if (key === "frosted")
                frosted = value;
            else if (key === "currency")
                currency = value;
            else if (key === "tileColorMode")
                tileColorMode = value;
            else if (key === "clockBars")
                clockBars = value;
            else if (key === "clockFields")
                clockFields = value;
            else if (key === "tabOrder")
                tabOrder = value;
            else if (key === "minerFields")
                minerFields = value;
            else if (key === "showHeader")
                showHeader = value;
            else if (key === "showFooter")
                showFooter = value;
            else if (key === "showBlock")
                showBlock = value;
            else if (key === "clockSpark")
                clockSpark = value;
            else if (key === "clockTime")
                clockTime = value;
            else if (key === "clockPrice")
                clockPrice = value;
            else if (key === "priceSpan")
                priceSpan = value;
            else if (key === "marketRange")
                marketRange = value;
            else if (key === "marketKind")
                marketKind = value;
            else if (key === "marketLower")
                marketLower = value;
            else if (key === "marketSub")
                marketSub = value;
            else if (key === "marketSecs")
                marketSecs = value;
            else if (key === "marketVon")
                marketVon = value;
            else if (key === "marketBis")
                marketBis = value;
            else if (key === "marketCross")
                marketCross = value;
            else if (key === "marketTape")
                marketTape = value;
            else if (key === "showFeed")
                showFeed = value;
            else if (key === "showClock")
                showClock = value;
            else if (key === "showMiner")
                showMiner = value;
            else if (key === "showExplorer")
                showExplorer = value;
            else if (key === "showMarket")
                showMarket = value;
            else if (key === "minerChart")
                minerChart = value;
            else if (key === "minerDomains")
                minerDomains = value;
            else if (key === "minerBoard")
                minerBoard = value;
            else if (key === "minerPane")
                minerPane = value;
            else if (key === "netSpan")
                netSpan = value;
            else if (key === "explorerLive")
                explorerLive = value;
            else if (key === "explorerParts")
                explorerParts = value;
            else if (key === "minerPanes")
                minerPanes = value;
            else if (key === "netParts")
                netParts = value;
            else if (key === "minerSolo")
                minerSolo = value;
            else if (key === "tabRotate")
                tabRotate = value;
            else if (key === "tabRotateViews")
                tabRotateViews = value;
            else if (key === "explorerPanels")
                explorerPanels = value;
            else if (key === "lang")
                lang = value;
            else if (key === "bigFields")
                bigFields = value;
            else if (key === "bigRotate")
                bigRotate = value;
            else if (key === "walletEnabled") {
                walletEnabled = value;
                if (!value && view === 4)
                    view = 5;
            }
            save();
        }

        function save() {
            viewFile.setText(JSON.stringify({
                "colorMode": colorMode,
                "sizeMode": sizeMode,
                "showInfo": showInfo,
                "showLegend": showLegend,
                "bgOpacity": bgOpacity,
                "view": view,
                "showRuler": showRuler,
                "frosted": frosted,
                "density": density,
                "startView": startView,
                "dataSource": dataSource,
            "mempoolHost": mempoolHost,
                "currency": currency,
                "tileColorMode": tileColorMode,
                "clockBars": clockBars,
                "clockFields": clockFields,
                "minerFields": minerFields,
                "showHeader": showHeader,
                "showFooter": showFooter,
                "showBlock": showBlock,
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
                "minerChart": minerChart,
                "minerDomains": minerDomains,
                "minerBoard": minerBoard,
                "minerPane": minerPane,
                "netSpan": netSpan,
                "explorerLive": explorerLive,
                "explorerParts": explorerParts,
                "minerPanes": minerPanes,
                "netParts": netParts,
                "minerSolo": minerSolo,
                "tabRotate": tabRotate,
                "tabRotateViews": tabRotateViews,
                "explorerPanels": explorerPanels,
                "lang": lang,
                "bigFields": bigFields,
                "bigRotate": bigRotate,
                "walletEnabled": walletEnabled,
                "tabOrder": tabOrder
            }));
            hint.flash();
        }

        FileView {
            id: viewFile

            path: Quickshell.env("HOME") + "/.local/state/orangedeck/view.json"
            blockLoading: false
            atomicWrites: true
            printErrors: false

            onLoaded: {
                try {
                    var v = JSON.parse(text());
                    win.colorMode = v.colorMode || "age";
                    win.sizeMode = v.sizeMode || "value";
                    win.showInfo = v.showInfo !== false;
                    win.showLegend = v.showLegend !== false;
                    if (typeof v.bgOpacity === "number")
                        win.bgOpacity = Math.max(0.15, Math.min(1, v.bgOpacity));
                    // **Keine feste Obergrenze mehr.** Hier stand
                    // `Math.min(5, ...)` -- aus der Zeit, als es die
                    // Ansichten 0 bis 5 gab. Der Markt kam als 6 dazu, die
                    // Klemme wanderte nicht mit, und wer im Markt schloss,
                    // fand beim naechsten Oeffnen die Einstellungen vor: 6
                    // auf 5 gestutzt ist genau der Reiter. Geschrieben wurde
                    // dabei der echte Wert, gelesen der gestutzte -- und weil
                    // danach die 5 zurueckging, blieb es dabei.
                    //
                    // Statt die Zahl zu erhoehen (und beim naechsten Reiter
                    // dieselbe Falle zu stellen) wird gar nicht mehr geklemmt.
                    // Eine Ansicht, die es nicht gibt, faengt der Rueckfall
                    // unten ab.
                    if (typeof v.view === "number" && v.view >= 0)
                        win.view = v.view;
                    if (typeof v.showRuler === "boolean")
                        win.showRuler = v.showRuler;
                    if (typeof v.frosted === "boolean")
                        win.frosted = v.frosted;
                    if (typeof v.density === "number")
                        win.density = Math.max(0.6, Math.min(2, v.density));
                    // **Und hier dieselbe Klemme ein zweites Mal.** `min(3, ...)`
                    // stammt aus der Zeit, als die Startansicht Feed, Uhr,
                    // Miner und Explorer kannte. Wer Markt oder Wallet
                    // einstellte, bekam beim naechsten Start den Explorer --
                    // geschrieben wurde der echte Wert, gelesen der gestutzte.
                    // Eine Ansicht, die es nicht gibt, faengt der Rueckfall ab.
                    if (typeof v.startView === "number")
                        win.startView = Math.max(-1, v.startView);
                    if (v.dataSource)
                        win.dataSource = v.dataSource;
                    if (typeof v.mempoolHost === "string")
                        win.mempoolHost = v.mempoolHost;
                    if (v.currency)
                        win.currency = v.currency;
                    if (v.tileColorMode)
                        win.tileColorMode = v.tileColorMode;
                    if (typeof v.clockBars === "boolean")
                        win.clockBars = v.clockBars;
                    if (Array.isArray(v.clockFields))
                        win.clockFields = v.clockFields;
                    if (Array.isArray(v.tabOrder))
                        win.tabOrder = v.tabOrder;
                    if (Array.isArray(v.minerFields))
                        win.minerFields = v.minerFields;
                    if (typeof v.showHeader === "boolean")
                        win.showHeader = v.showHeader;
                    if (typeof v.showFooter === "boolean")
                        win.showFooter = v.showFooter;
                    if (typeof v.showBlock === "boolean")
                        win.showBlock = v.showBlock;
                    if (typeof v.clockSpark === "boolean")
                        win.clockSpark = v.clockSpark;
                    if (typeof v.clockTime === "boolean")
                        win.clockTime = v.clockTime;
                    if (typeof v.clockPrice === "boolean")
                        win.clockPrice = v.clockPrice;
                    if (typeof v.priceSpan === "string")
                        win.priceSpan = v.priceSpan;
                    if (typeof v.marketRange === "string")
                        win.marketRange = v.marketRange;
                    if (typeof v.marketKind === "string")
                        win.marketKind = v.marketKind;
                    if (typeof v.marketLower === "string")
                        win.marketLower = v.marketLower;
                    if (typeof v.marketSub === "string")
                        win.marketSub = v.marketSub;
                    if (typeof v.marketSecs === "number")
                        win.marketSecs = v.marketSecs;
                    if (typeof v.marketVon === "number")
                        win.marketVon = v.marketVon;
                    if (typeof v.marketBis === "number")
                        win.marketBis = v.marketBis;
                    if (typeof v.marketCross === "boolean")
                        win.marketCross = v.marketCross;
                    if (typeof v.marketTape === "boolean")
                        win.marketTape = v.marketTape;
                    if (typeof v.showFeed === "boolean")
                        win.showFeed = v.showFeed;
                    if (typeof v.showClock === "boolean")
                        win.showClock = v.showClock;
                    if (typeof v.showMiner === "boolean")
                        win.showMiner = v.showMiner;
                    if (typeof v.showExplorer === "boolean")
                        win.showExplorer = v.showExplorer;
                    if (typeof v.showMarket === "boolean")
                        win.showMarket = v.showMarket;
                    if (typeof v.minerChart === "boolean")
                        win.minerChart = v.minerChart;
                    if (typeof v.minerDomains === "boolean")
                        win.minerDomains = v.minerDomains;
                    if (typeof v.minerBoard === "boolean")
                        win.minerBoard = v.minerBoard;
                    if (typeof v.minerPane === "string")
                        win.minerPane = v.minerPane;
                    if (typeof v.netSpan === "string")
                        win.netSpan = v.netSpan;
                    if (typeof v.explorerLive === "boolean")
                        win.explorerLive = v.explorerLive;
                    if (Array.isArray(v.explorerParts))
                        win.explorerParts = v.explorerParts;
                    if (Array.isArray(v.minerPanes))
                        win.minerPanes = v.minerPanes;
                    if (Array.isArray(v.netParts))
                        win.netParts = v.netParts;
                    if (typeof v.minerSolo === "boolean")
                        win.minerSolo = v.minerSolo;
                    if (typeof v.tabRotate === "number")
                        win.tabRotate = v.tabRotate;
                    if (Array.isArray(v.tabRotateViews))
                        win.tabRotateViews = v.tabRotateViews;
                    if (Array.isArray(v.explorerPanels))
                        win.explorerPanels = v.explorerPanels;
                    if (v.lang)
                        win.lang = v.lang;
                    if (Array.isArray(v.bigFields))
                        win.bigFields = v.bigFields;
                    if (typeof v.bigRotate === "number")
                        win.bigRotate = v.bigRotate;
                    if (typeof v.walletEnabled === "boolean")
                        win.walletEnabled = v.walletEnabled;
                    if (win.view === 4 && !win.walletEnabled)
                        win.view = 0;
                    // **Und jede andere Ansicht, die es gerade nicht gibt.**
                    // Dieselbe Pruefung wie in `app/qml/Main.qml`, an
                    // derselben Art Stelle: einmal, gleich nachdem der Wert
                    // gesetzt wurde. **Kein `onViewChanged` daneben** -- das
                    // waere eine Bindungsschleife und liesse `FeedTabs` auf
                    // der alten Ansicht stehen.
                    if (tabs.tabViews.length > 0
                            && tabs.tabViews.indexOf(win.view) < 0)
                        win.view = tabs.tabViews[0];
                } catch (e) {}
            }
        }

        FeedState {
            id: feedState

            mode: win.dataSource
            mempoolHost: win.mempoolHost
        }

        // **Alle Ansichten stehen in `FeedTabs`** -- dasselbe Bauteil wie im
        // Fenster, im Dashboard, im Popout und auf dem Desktop. Vorher
        // verdrahtete dieses Fenster sie selbst; genau daran fehlte hier der
        // Kursverlauf, obwohl er ueberall sonst schon stand.
        FeedTabs {
            id: tabs

            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 8
            feed: feedState
            opts: win.opts
            view: win.view
            tabsVisible: !win.bare
            rotationAllowed: !win.bare
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
            // Das Suchfeld des Explorers nimmt den Fokus, solange es zu sehen
            // ist. Beim Verlassen gehoert er wieder hierher -- sonst sind die
            // Tastenkuerzel nach einem Besuch im Explorer tot.
            onSearchFocusReleased: keys.forceActiveFocus()
        }

        Item {
            id: keys

            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_C:
                    win.colorMode = win.colorMode === "age" ? "fee"
                        : (win.colorMode === "fee" ? "type" : "age");
                    win.save();
                    break;
                case Qt.Key_S:
                    win.sizeMode = win.sizeMode === "value" ? "vbytes" : "value";
                    win.save();
                    break;
                case Qt.Key_L:
                    win.showLegend = !win.showLegend;
                    win.save();
                    break;
                case Qt.Key_Plus:
                case Qt.Key_Equal:
                    win.bgOpacity = Math.min(1, win.bgOpacity + 0.05);
                    win.save();
                    break;
                case Qt.Key_Minus:
                    win.bgOpacity = Math.max(0.15, win.bgOpacity - 0.05);
                    win.save();
                    break;
                case Qt.Key_B:
                    tabs.triggerBlockAnimation();
                    break;
                case Qt.Key_I:
                    win.showInfo = !win.showInfo;
                    win.save();
                    break;
                case Qt.Key_1:
                case Qt.Key_2:
                case Qt.Key_3:
                case Qt.Key_4:
                case Qt.Key_5:
                case Qt.Key_6:
                    var n = event.key - Qt.Key_1;
                    if (n < tabs.tabViews.length) {
                        win.view = tabs.tabViews[n];
                        win.save();
                    }
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        // Mit eigenem Kasten und Umbruch, wie in app/qml/Main.qml: als
        // blosser Text lag der Hinweis auf der Fusszeile des Feeds und ragte im
        // schmalen Fenster hinaus (11.09.2026).
        TextMetrics {
            id: hintMass

            font.pixelSize: 11
            text: hintText.text
        }

        Rectangle {
            id: hint

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
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
                width: Math.min(Math.ceil(hintMass.advanceWidth) + 1, parent.parent.width - 48)
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#9a94a6"
                font.pixelSize: 11
                text: Tr.t("keys.help", win.lang)
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
    }
}
