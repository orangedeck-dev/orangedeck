// Settings, grouped by the same tabs as the views.
//
// The values belong to the host: the standalone app stores them with
// QSettings, the Quickshell window in view.json, the dashboard tab in the
// DMS plugin settings. This file is only the UI: it reads `opts` and
// reports every change through `changed`.
//
// Uses its own small controls instead of QtQuick.Controls on purpose: the
// rest of the program only needs `import QtQuick`, and the same files run
// in the window, in the DMS plugin and on Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts
import "views.js" as Views
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Keyboard: Page Up/Down, Home, End (roll.js; from Main.qml via FeedTabs)
    function rollen(wie) {
        return Roll.rollen(flaeche, wie);
    }

    property var opts: ({})
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    // For the dropdowns on the appearance page: border and background of the
    // open list. The host passes the same colors its other surfaces use, so
    // the list does not end up with its own opacity on top of the settings.
    property color lineColor: "#2a2a38"
    property color panelColor: "#16161f"
    // Views that currently cannot show anything: the miner without a Bitaxe,
    // wallet and market in direct mode. They stay in the tab order anyway,
    // otherwise their position could not be set while they are unavailable;
    // the page only notes that they are not shown right now.
    property var nichtVerfuegbar: []

    // Hide pages for views that do not exist on this platform. On Android
    // market and wallet do not run (both need the daemon), so their switches
    // must not appear. Unlike `nichtVerfuegbar` this is not about what the user
    // turned off but about what is technically possible: the wallet page is the
    // only place where the wallet can be turned on.
    property bool kannMarkt: true
    property bool kannWallet: true
    property real uiFont: 13
    property string lang: "de"
    // Opacity and start view belong to the window. In the dashboard tab the
    // host provides the surface, so both would have no effect there.
    property bool windowed: true

    signal changed(string key, var value)

    property string tab: "allgemein"

    function val(key, fallback) {
        var v = root.opts ? root.opts[key] : undefined;
        return v === undefined ? fallback : v;
    }

    // Tab order as set by the user, filled up and cleaned of unknown entries
    // by `views.js`. Same calculation as in `FeedTabs`, from the same table.
    readonly property var reihenfolge: root.ohneEinstellungen(Views.ordnung(root.val("tabOrder", [])))

    // If "Settings" is not a tab (the app has a gear button), it is offered
    // neither in the order nor as a start view.
    property bool einstellungenAlsReiter: true

    function ohneEinstellungen(liste) {
        if (root.einstellungenAlsReiter)
            return liste;
        return liste.filter(function (id) {
            return id !== Views.EINSTELLUNGEN;
        });
    }

    // The choices in every dropdown use the default order, not the user's: a
    // list that re-sorts itself while picking jumps away under the finger.
    readonly property var ansichtsListe: {
        var out = [];
        var a = root.ohneEinstellungen(Views.alle());
        for (var i = 0; i < a.length; i++) {
            out.push({ "k": String(a[i]),
                       "l": Tr.t(Views.name(a[i]), root.lang) });
        }
        return out;
    }

    // Swap, do not insert. Picking the market for position 2 means it should
    // be there, and whatever was there has to go somewhere. A swap keeps the
    // list a permutation: every view appears exactly once without any extra
    // bookkeeping. Insert and shift would move every tab in between, and two
    // moves in a row would give an order nobody expected.
    function reiterTauschen(pos, id) {
        // Same list as in the display, otherwise `pos` would count in a
        // different order once the settings entry is filtered out
        var ord = root.ohneEinstellungen(Views.ordnung(root.val("tabOrder", [])));
        var j = ord.indexOf(id);
        if (j < 0 || j === pos)
            return;
        var merk = ord[pos];
        ord[pos] = id;
        ord[j] = merk;
        if (!root.einstellungenAlsReiter)
            ord.push(Views.EINSTELLUNGEN);
        root.changed("tabOrder", ord);
    }

    // A multi-select is stored as a list of keys. Empty means all, so a metric
    // added later shows up instead of silently missing.
    function has(key, id, alle) {
        var v = root.val(key, []);
        if (!v || !v.length || typeof v.indexOf !== "function")
            return true;
        return v.indexOf(id) >= 0;
    }

    function toggleIn(key, id, alle) {
        var v = root.val(key, []);
        var cur = (!v || !v.length || typeof v.slice !== "function")
            ? alle.slice() : v.slice();
        var i = cur.indexOf(id);
        if (i >= 0)
            cur.splice(i, 1);
        else
            cur.push(id);
        root.changed(key, cur);
    }

    // ---------------------------------------------------- Controls
    component Zeile: Item {
        id: zeileRoot

        property string label: ""
        property string help: ""
        default property alias inhalt: halter.data

        width: parent ? parent.width : 0
        height: Math.max(halter.childrenRect.height, beschriftung.height) + root.uiFont * 1.1

        Column {
            id: beschriftung

            anchors.left: parent.left
            // Align to the top when the control is taller than the label. Centering
            // works for a switch or a slider, but next to a tall grid the label ends
            // up in the grid's middle, e.g. "Language" next to "Português (BR)", five
            // rows below the first button it belongs to. On a desktop this rarely
            // shows because the grids are wider and therefore flatter.
            //
            // A computed `y`, not switching anchors. Rotating a phone from landscape
            // to portrait makes the area narrower, the language buttons wrap to more
            // rows, `halter` grows and the condition flips in the middle of the
            // geometry change notification. Re-anchoring while Qt is still iterating
            // its list of observers reads a null pointer and crashes every view,
            // since the settings are always instantiated, even when hidden.
            y: halter.height > beschriftung.height
               ? root.uiFont * 0.55 : (parent.height - height) / 2
            width: parent.width * 0.42
            spacing: 2

            Text {
                text: zeileRoot.label
                color: root.textColor
                font.pixelSize: root.uiFont * 0.95
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: zeileRoot.help
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.78
            }
        }

        Item {
            id: halter

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.54
            height: childrenRect.height
        }
    }

    component Schalter: Rectangle {
        id: schalterRoot

        property bool an: false

        signal umgelegt

        width: root.uiFont * 2.6
        height: root.uiFont * 1.4
        radius: height / 2
        color: an ? root.goodColor : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: schalterRoot.an ? schalterRoot.width - width - 2 : 2
            color: "#ffffff"

            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: schalterRoot.umgelegt()
        }
    }

    // Text input row. What needs text (wallets, the miner address) otherwise
    // only works via the command line or a file, and neither exists on a
    // phone.
    //
    // Modeled on the search field in the explorer, the only other `TextInput`
    // in `ui/qml/`, including two rules from there:
    //
    //   Focus needs a way out. Escape releases it, otherwise the tab
    //   shortcuts stop working after visiting this field.
    //
    //   On touch the field does not grab focus by itself. Focus brings up
    //   the on-screen keyboard, which covers half the view.
    //
    // The value is applied on Enter or when the field loses focus, not on
    // every keystroke. Looking up an address after the third character would
    // query half of it.
    component Textzeile: Rectangle {
        id: textRoot

        property string wert: ""
        property string platzhalter: ""

        signal uebernommen(string neu)

        width: parent ? parent.width : 0
        height: root.uiFont * 2.2
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: feld.activeFocus ? root.accentColor
                                       : Qt.rgba(1, 1, 1, 0.14)

        TextInput {
            id: feld

            anchors.fill: parent
            anchors.leftMargin: root.uiFont * 0.6
            anchors.rightMargin: root.uiFont * 0.6
            verticalAlignment: TextInput.AlignVCenter
            color: root.textColor
            font.pixelSize: root.uiFont * 0.95
            font.family: Fonts.mono()
            selectByMouse: true
            clip: true
            text: textRoot.wert

            onAccepted: textRoot.uebernommen(feld.text)
            onActiveFocusChanged: {
                if (!feld.activeFocus && feld.text !== textRoot.wert)
                    textRoot.uebernommen(feld.text);
            }

            Keys.onEscapePressed: {
                feld.text = textRoot.wert;
                feld.focus = false;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: feld.text.length === 0 && !feld.activeFocus
                text: textRoot.platzhalter
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.95
                font.family: Fonts.mono()
            }
        }
    }

    component Wahl: Flow {
        id: wahlRoot

        // `Flow` instead of `Row`: thirteen languages do not fit in one row,
        // and clipped buttons are worse than two rows.
        width: parent ? parent.width : 0

        property var eintraege: []      // [{ k, l }]
        property string gewaehlt: ""

        signal picked(string k)

        spacing: root.uiFont * 0.4

        Repeater {
            model: wahlRoot.eintraege

            Rectangle {
                id: knopf

                required property var modelData

                readonly property bool aktiv: wahlRoot.gewaehlt === knopf.modelData.k

                width: knopfText.width + root.uiFont * 1.1
                height: knopfText.height + root.uiFont * 0.55
                radius: height / 2
                color: knopf.aktiv ? Qt.rgba(1, 1, 1, 0.12)
                                   : (maus.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.width: 1
                border.color: knopf.aktiv ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)

                Text {
                    id: knopfText

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: knopf.aktiv ? root.textColor : root.dimColor
                    font.pixelSize: root.uiFont * 0.82
                }

                MouseArea {
                    id: maus

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wahlRoot.picked(knopf.modelData.k)
                }
            }
        }
    }

    component Regler: Item {
        id: reglerRoot

        property real wert: 0
        property real von: 0
        property real bis: 1
        property real schritt: 0.05
        property string einheit: ""

        signal gezogen(real w)

        // Not wider than the column. A fixed 16 font heights was wider than
        // the right half of the row on a phone, and the number next to the
        // track got cut off at the edge.
        width: Math.min(root.uiFont * 16, parent ? parent.width : root.uiFont * 16)
        height: root.uiFont * 1.6

        Rectangle {
            id: bahn

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.uiFont * 4
            height: Math.max(3, root.uiFont * 0.22)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: bahn.width * Math.max(0, Math.min(1,
                    (reglerRoot.wert - reglerRoot.von) / (reglerRoot.bis - reglerRoot.von)))
                height: parent.height
                radius: height / 2
                color: root.accentColor
            }

            Rectangle {
                width: root.uiFont
                height: width
                radius: width / 2
                y: (parent.height - height) / 2
                x: bahn.width * Math.max(0, Math.min(1,
                    (reglerRoot.wert - reglerRoot.von) / (reglerRoot.bis - reglerRoot.von)))
                   - width / 2
                color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -root.uiFont
                cursorShape: Qt.PointingHandCursor

                function setzen(mx) {
                    var f = Math.max(0, Math.min(1, mx / bahn.width));
                    var w = reglerRoot.von + f * (reglerRoot.bis - reglerRoot.von);
                    var st = reglerRoot.schritt;
                    reglerRoot.gezogen(Math.round(w / st) * st);
                }

                onPressed: mouse => setzen(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setzen(mouse.x);
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Tr.fixed(Math.round(reglerRoot.wert * 100) / 100, 2, root.lang)
                        .replace(/[.,]00$/, "")
                  + reglerRoot.einheit
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }
    }

    // Checkboxes for multi-select
    component Haken: Flow {
        id: hakenRoot

        width: parent ? parent.width : 0

        property var alle: []
        property string schluessel: ""
        property var eintraege: []     // [{ id, l }]

        spacing: root.uiFont * 0.7

        Repeater {
            model: hakenRoot.eintraege

            // An `Item` around the row: a child of a `Row` must not use
            // `anchors.fill`, but the touch area needs exactly that.
            Item {
                id: hak

                required property var modelData

                readonly property bool an: root.has(hakenRoot.schluessel, hak.modelData.id,
                                                    hakenRoot.alle)

                width: hakZeile.width
                height: Math.max(hakZeile.height, root.uiFont * 1.6)

                Row {
                    id: hakZeile

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.uiFont * 0.3

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.uiFont
                        height: width
                        radius: 3
                        color: hak.an ? root.goodColor : "transparent"
                        border.width: 1
                        border.color: hak.an ? root.goodColor : Qt.rgba(1, 1, 1, 0.25)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hak.modelData.l
                        color: hak.an ? root.textColor : root.dimColor
                        font.pixelSize: root.uiFont * 0.82
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleIn(hakenRoot.schluessel, hak.modelData.id,
                                             hakenRoot.alle)
                }
            }
        }
    }

    // ------------------------------------------------------------ Layout

    // Page keys in the order of the tabs above, kept in one place so labels
    // and behavior cannot drift apart.
    readonly property var seiten: {
        var l = ["allgemein", "darstellung", "feed", "clock", "miner", "explorer"];
        if (root.kannMarkt)
            l.push("markt");
        if (root.kannWallet)
            l.push("wallet");
        return l;
    }

    // If the open page disappears, the tab would otherwise stay without content.
    onSeitenChanged: if (root.seiten.indexOf(root.tab) < 0)
        root.tab = "allgemein";

    // Eight tabs do not fit in one row on a phone. `ViewTabs` is a `Row` and
    // simply runs off the right edge without a margin or any hint, so the
    // last page would be unreachable. The row therefore sits in a horizontal
    // Flickable that only scrolls when the row is actually too wide.
    Flickable {
        id: reiterBand

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: reiter.height
        contentWidth: reiter.width
        contentHeight: reiter.height
        flickableDirection: Flickable.HorizontalFlick
        interactive: reiter.width > width
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ViewTabs {
            id: reiter

            labels: {
                var n = { "allgemein": "set.general", "darstellung": "set.display",
                          "feed": "tab.feed", "clock": "tab.clock", "miner": "tab.miner",
                          "explorer": "tab.explorer", "markt": "tab.market",
                          "wallet": "tab.wallet" };
                var l = [];
                for (var i = 0; i < root.seiten.length; i++)
                    l.push(Tr.t(n[root.seiten[i]], root.lang));
                return l;
            }
            current: root.seiten.indexOf(root.tab)
            fontSize: root.uiFont
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            onPicked: function (i) {
                root.tab = root.seiten[i];
            }
        }
    }

    Flickable {
        id: flaeche

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: reiterBand.bottom
        anchors.topMargin: root.uiFont
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: seite.implicitHeight + root.uiFont * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: seite

            width: parent.width

            // ------------------------------------------------- General
            Column {
                width: parent.width
                visible: root.tab === "allgemein"

                // Without a daemon (Android, Windows) there is nothing to choose. The
                // DMS plugin and Quickshell do not know the key and keep both rows
                // through the default.
                Zeile {
                    label: Tr.t("set.source", root.lang)
                    help: Tr.t("set.sourceHelp", root.lang)
                    visible: root.val("dienstMoeglich", true)

                    Wahl {
                        gewaehlt: root.val("dataSource", "daemon")
                        // "auto" is offered wherever a daemon can exist at all; `FeedState`
                        // knows the mode in every host. It is the default only in the DMS
                        // plugin: there the daemon is the exception, in the app the rule.
                        eintraege: [
                            { "k": "auto", "l": Tr.t("src.auto", root.lang) },
                            { "k": "daemon", "l": Tr.t("src.daemon", root.lang) },
                            { "k": "direct", "l": Tr.t("src.direct", root.lang) }
                        ]
                        onPicked: function (k) {
                            root.changed("dataSource", k);
                        }
                    }
                }

                // Address of the daemon on another device. Empty means the daemon on
                // the same machine; filled in, it is one on the local network, which
                // gives tablets and phones market and wallet, otherwise missing outside
                // Linux.
                //
                // Only shown in daemon mode: in direct mode nothing uses it, and a field
                // without effect is a trap.
                Zeile {
                    label: Tr.t("set.daemonHost", root.lang)
                    help: Tr.t("set.daemonHostHelp", root.lang)
                    // Also shown for "auto": discovery tries exactly this address.
                    // Only direct mode never uses it, and a field without effect is a
                    // trap.
                    visible: root.val("dienstMoeglich", true)
                             && root.val("dataSource", "daemon") !== "direct"

                    Textzeile {
                        wert: root.val("daemonHost", "")
                        platzhalter: "192.168.1.42"
                        onUebernommen: function (neu) {
                            root.changed("daemonHost", neu);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.currency", root.lang)
                    help: Tr.t("set.currencyHelp", root.lang)

                    Wahl {
                        // Default is USD, not EUR. Bitcoin is quoted in dollars
                        // worldwide; euro is a deliberate choice. `DeckWidget.java`
                        // uses the same default so tab and widget agree as long as
                        // nothing has been set.
                        gewaehlt: root.val("currency", "usd")
                        eintraege: {
                            var out = [];
                            for (var i = 0; i < Money.CURRENCIES.length; i++) {
                                out.push({ "k": Money.CURRENCIES[i].k,
                                           "l": Money.CURRENCIES[i].z });
                            }
                            return out;
                        }
                        onPicked: function (k) {
                            root.changed("currency", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.language", root.lang)
                    help: Tr.t("set.languageHelp", root.lang)

                    // "System language" first: empty means follow the system.
                    // Hosts without `langWahl` (DMS, Quickshell) store the empty
                    // value under `lang`, and FeedTabs then also falls back to the
                    // system language.
                    Wahl {
                        gewaehlt: root.val("langWahl", root.val("lang", root.lang))
                        eintraege: [{ "k": "", "l": Tr.t("set.langSystem", root.lang) }]
                                   .concat(Tr.languages())
                        onPicked: function (k) {
                            root.changed("lang", k);
                        }
                    }
                }

                // Not on Android. The activity is always drawn opaque there, so
                // the slider would have no effect.
                Zeile {
                    visible: root.windowed && Qt.platform.os !== "android"
                             && Qt.platform.os !== "ios"
                    label: Tr.t("set.opacity", root.lang)
                    help: Tr.t("set.opacityHelp", root.lang)

                    Regler {
                        von: 0.15
                        bis: 1
                        schritt: 0.05
                        wert: root.val("bgOpacity", 1.0)
                        onGezogen: function (w) {
                            root.changed("bgOpacity", w);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.tileSize", root.lang)
                    help: Tr.t("set.tileSizeHelp", root.lang)

                    Regler {
                        von: 0.6
                        bis: 2
                        schritt: 0.1
                        wert: root.val("density", 1)
                        onGezogen: function (w) {
                            root.changed("density", w);
                        }
                    }
                }
            }

            // ----------------------------------------------- Appearance
            //
            // The tab order belongs to the user. Both the order and the start view
            // read the list of views from `views.js`, so a new view is available in
            // both places.
            //
            // The switches that turn a tab off entirely live here too, not on each
            // view's own page: once a tab is turned off its page can no longer be
            // reached to turn it back on.
            Column {
                width: parent.width
                visible: root.tab === "darstellung"

                Zeile {
                    visible: root.windowed
                    label: Tr.t("set.startView", root.lang)
                    help: Tr.t("set.startViewHelp", root.lang)

                    Wahl {
                        gewaehlt: String(root.val("startView", -1))
                        eintraege: {
                            var out = [{ "k": "-1",
                                         "l": Tr.t("set.lastUsed", root.lang) }];
                            var ord = root.reihenfolge;
                            for (var i = 0; i < ord.length; i++) {
                                out.push({ "k": String(ord[i]),
                                           "l": Tr.t(Views.name(ord[i]), root.lang) });
                            }
                            return out;
                        }
                        onPicked: function (k) {
                            root.changed("startView", parseInt(k, 10));
                        }
                    }
                }

                // Rotate through tabs, e.g. for a block clock on the wall. The timer
                // runs in `FeedTabs`.
                Zeile {
                    label: Tr.t("set.tabRotate", root.lang)
                    help: Tr.t("set.tabRotateHelp", root.lang)

                    Wahl {
                        gewaehlt: String(root.val("tabRotate", 0))
                        eintraege: [
                            { "k": "0", "l": Tr.t("set.off", root.lang) },
                            { "k": "30", "l": Tr.t("duration.sec", root.lang, 30) },
                            { "k": "60", "l": Tr.t("duration.min", root.lang, 1) },
                            { "k": "120", "l": Tr.t("duration.min", root.lang, 2) },
                            { "k": "300", "l": Tr.t("duration.min", root.lang, 5) },
                            { "k": "600", "l": Tr.t("duration.min", root.lang, 10) }
                        ]
                        onPicked: function (k) {
                            root.changed("tabRotate", parseInt(k, 10));
                        }
                    }
                }

                Zeile {
                    visible: root.val("tabRotate", 0) > 0
                    label: Tr.t("set.tabRotateViews", root.lang)
                    help: Tr.t("set.tabRotateViewsHelp", root.lang)

                    Haken {
                        schluessel: "tabRotateViews"
                        alle: ["feed", "clock", "device", "net", "explorer", "market"]
                        eintraege: {
                            var m = Tr.t("tab.miner", root.lang) + " · ";
                            var out = [
                                { "id": "feed", "l": Tr.t("tab.feed", root.lang) },
                                { "id": "clock", "l": Tr.t("tab.clock", root.lang) },
                                { "id": "device", "l": m + Tr.t("miner.paneDevice", root.lang) },
                                { "id": "net", "l": m + Tr.t("miner.paneNet", root.lang) },
                                { "id": "explorer", "l": Tr.t("tab.explorer", root.lang) }
                            ];
                            // Market only where it exists (not in direct mode)
                            if (root.nichtVerfuegbar.indexOf(6) < 0)
                                out.push({ "id": "market", "l": Tr.t("tab.market", root.lang) });
                            return out;
                        }
                    }
                }

                Repeater {
                    model: root.reihenfolge

                    Zeile {
                        id: platz

                        required property int index
                        required property var modelData

                        readonly property string schluessel: Views.schalter(platz.modelData)
                        readonly property bool moeglich:
                            root.nichtVerfuegbar.indexOf(platz.modelData) < 0

                        label: Tr.t("set.tabPos", root.lang, platz.index + 1)
                        // The hint appears once, on the first row. The same
                        // sentence seven times in a row reads like an error,
                        // not an explanation.
                        help: !platz.moeglich ? Tr.t("set.tabUnavailable", root.lang)
                              : (platz.index === 0 ? Tr.t("set.tabOrderHelp", root.lang) : "")

                        DropDown {
                            id: feld

                            anchors.left: parent.left
                            // Always extend to the switch, even where none is
                            // drawn. An invisible item keeps its width: letting
                            // rows without a switch run to the edge would end five
                            // fields at one edge and two at another. The empty
                            // space costs nothing, a ragged edge stands out.
                            anchors.right: schalt.left
                            anchors.rightMargin: root.uiFont * 0.7
                            // The bounds are the page, not the row. The open list
                            // reparents itself into this item, which lies outside
                            // the Flickable that clips the content. Inside the row
                            // it would be cut off at the Flickable's edge.
                            bounds: root
                            model: root.ansichtsListe
                            current: String(platz.modelData)
                            uiFont: root.uiFont * 0.9
                            textColor: platz.moeglich ? root.textColor : root.dimColor
                            dimColor: root.dimColor
                            accentColor: root.accentColor
                            lineColor: root.lineColor
                            flaecheColor: root.panelColor
                            onPicked: function (k) {
                                root.reiterTauschen(platz.index, parseInt(k, 10));
                            }

                            // The list measures its position when it opens and not
                            // afterwards, on purpose (see `DropDown.qml`). On a
                            // scrolling page it would stay behind while the content
                            // moves, so close it.
                            Connections {
                                target: flaeche

                                function onContentYChanged() {
                                    feld.offen = false;
                                }
                            }
                        }

                        Schalter {
                            id: schalt

                            anchors.right: parent.right
                            anchors.verticalCenter: feld.verticalCenter
                            // Settings and wallet have no switch: settings always
                            // stays, and the wallet depends on the switch with the
                            // warning on its page. A second one here would only
                            // raise the question which one applies.
                            visible: platz.schluessel.length > 0
                            an: root.val(platz.schluessel, true)
                            onUmgelegt: root.changed(platz.schluessel,
                                                     !root.val(platz.schluessel, true))
                        }
                    }
                }
            }

            // ------------------------------------------------------ Feed
            Column {
                width: parent.width
                visible: root.tab === "feed"


                Zeile {
                    label: Tr.t("set.tileColor", root.lang)
                    help: Tr.t("set.tileColorHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("colorMode", "age")
                        eintraege: [
                            { "k": "age", "l": Tr.t("color.age", root.lang) },
                            { "k": "fee", "l": Tr.t("color.fee", root.lang) },
                            { "k": "type", "l": Tr.t("color.type", root.lang) }
                        ]
                        onPicked: function (k) {
                            root.changed("colorMode", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.tileMetric", root.lang)
                    help: Tr.t("set.tileMetricHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("sizeMode", "value")
                        eintraege: [
                            { "k": "value", "l": Tr.t("feed.sizeValue", root.lang) },
                            { "k": "vbytes", "l": "vBytes" }
                        ]
                        onPicked: function (k) {
                            root.changed("sizeMode", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.header", root.lang)
                    help: Tr.t("set.headerHelp", root.lang)

                    Schalter {
                        an: root.val("showHeader", true)
                        onUmgelegt: root.changed("showHeader", !root.val("showHeader", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.footer", root.lang)
                    help: Tr.t("set.footerHelp", root.lang)

                    Schalter {
                        an: root.val("showFooter", true)
                        onUmgelegt: root.changed("showFooter", !root.val("showFooter", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.blockInfo", root.lang)
                    help: Tr.t("set.blockInfoHelp", root.lang)

                    Schalter {
                        an: root.val("showInfo", true)
                        onUmgelegt: root.changed("showInfo", !root.val("showInfo", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.blockTiles", root.lang)
                    help: Tr.t("set.blockTilesHelp", root.lang)

                    Schalter {
                        an: root.val("showBlock", true)
                        onUmgelegt: root.changed("showBlock", !root.val("showBlock", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.legend", root.lang)
                    help: Tr.t("set.legendHelp", root.lang)

                    Schalter {
                        an: root.val("showLegend", true)
                        onUmgelegt: root.changed("showLegend", !root.val("showLegend", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.ruler", root.lang)
                    help: Tr.t("set.rulerHelp", root.lang)

                    Schalter {
                        an: root.val("showRuler", true)
                        onUmgelegt: root.changed("showRuler", !root.val("showRuler", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.blur", root.lang)
                    help: Tr.t("set.blurHelp", root.lang)

                    Schalter {
                        an: root.val("frosted", true)
                        onUmgelegt: root.changed("frosted", !root.val("frosted", true))
                    }
                }
            }

            // ------------------------------------------------ Clock
            Column {
                width: parent.width
                visible: root.tab === "clock"


                Zeile {
                    label: Tr.t("set.metrics", root.lang)
                    help: Tr.t("set.metricsClockHelp", root.lang)

                    Haken {
                        schluessel: "clockFields"
                        alle: ["fee", "price", "moscow", "mempool", "hashrate"]
                        eintraege: [
                            { "id": "fee", "l": Tr.t("fee", root.lang) },
                            { "id": "price", "l": Tr.t("price", root.lang) },
                            { "id": "moscow", "l": Tr.t("clock.moscow", root.lang) },
                            { "id": "mempool", "l": Tr.t("mempool", root.lang) },
                            { "id": "hashrate", "l": Tr.t("hashrate", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.bigValue", root.lang)
                    help: Tr.t("set.bigValueHelp", root.lang)

                    Haken {
                        schluessel: "bigFields"
                        alle: ["height", "price", "moscow", "fee", "hashrate", "mempool", "time"]
                        eintraege: [
                            { "id": "height", "l": Tr.t("blockHeight", root.lang) },
                            { "id": "price", "l": Tr.t("price", root.lang) },
                            { "id": "moscow", "l": Tr.t("clock.moscow", root.lang) },
                            { "id": "fee", "l": Tr.t("fee", root.lang) },
                            { "id": "hashrate", "l": Tr.t("hashrate", root.lang) },
                            { "id": "mempool", "l": Tr.t("mempool", root.lang) },
                            { "id": "time", "l": Tr.t("set.clockTime", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.rotate", root.lang)
                    help: Tr.t("set.rotateHelp", root.lang)

                    Wahl {
                        gewaehlt: String(root.val("bigRotate", 0))
                        eintraege: [
                            { "k": "0", "l": Tr.t("set.off", root.lang) },
                            { "k": "5", "l": Tr.t("unit.sec", root.lang, 5) },
                            { "k": "10", "l": Tr.t("unit.sec", root.lang, 10) },
                            { "k": "30", "l": Tr.t("unit.sec", root.lang, 30) },
                            { "k": "60", "l": Tr.t("unit.sec", root.lang, 60) }
                        ]
                        onPicked: function (k) {
                            root.changed("bigRotate", parseInt(k, 10));
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.diffBars", root.lang)
                    help: Tr.t("set.diffBarsHelp", root.lang)

                    Schalter {
                        an: root.val("clockBars", true)
                        onUmgelegt: root.changed("clockBars", !root.val("clockBars", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.hashChart", root.lang)
                    help: Tr.t("set.hashChartHelp", root.lang)

                    Schalter {
                        an: root.val("clockSpark", true)
                        onUmgelegt: root.changed("clockSpark", !root.val("clockSpark", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.priceChart", root.lang)
                    help: Tr.t("set.priceChartHelp", root.lang)

                    Schalter {
                        an: root.val("clockPrice", true)
                        onUmgelegt: root.changed("clockPrice", !root.val("clockPrice", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.clockTime", root.lang)
                    help: Tr.t("set.clockTimeHelp", root.lang)

                    Schalter {
                        an: root.val("clockTime", false)
                        onUmgelegt: root.changed("clockTime", !root.val("clockTime", false))
                    }
                }
            }

            // ----------------------------------------------------- Miner
            Column {
                width: parent.width
                visible: root.tab === "miner"

                // Which pages the tab has. Without "Device" only the network,
                // even with a miner configured.
                Zeile {
                    label: Tr.t("set.minerPanes", root.lang)
                    help: Tr.t("set.minerPanesHelp", root.lang)

                    Haken {
                        schluessel: "minerPanes"
                        alle: ["device", "net"]
                        eintraege: [
                            { "id": "device", "l": Tr.t("miner.paneDevice", root.lang) },
                            { "id": "net", "l": Tr.t("miner.paneNet", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.minerHosts", root.lang)
                    help: Tr.t("set.minerHostsHelp", root.lang)

                    Textzeile {
                        wert: root.val("minerHostsRaw", "")
                        platzhalter: "http://192.168.1.42"
                        onUebernommen: function (neu) {
                            root.changed("minerHostsRaw", neu);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.metrics", root.lang)
                    help: Tr.t("set.metricsMinerHelp", root.lang)

                    Haken {
                        schluessel: "minerFields"
                        alle: ["temp", "power", "fan", "error", "shares", "uptime"]
                        eintraege: [
                            { "id": "temp", "l": Tr.t("miner.temp", root.lang) },
                            { "id": "power", "l": Tr.t("miner.power", root.lang) },
                            { "id": "fan", "l": Tr.t("miner.fan", root.lang) },
                            { "id": "error", "l": Tr.t("miner.errorRate", root.lang) },
                            { "id": "shares", "l": Tr.t("miner.shares", root.lang) },
                            { "id": "uptime", "l": Tr.t("miner.uptime", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.minerChart", root.lang)
                    help: Tr.t("set.minerChartHelp", root.lang)

                    Schalter {
                        an: root.val("minerChart", true)
                        onUmgelegt: root.changed("minerChart", !root.val("minerChart", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.minerDomains", root.lang)
                    help: Tr.t("set.minerDomainsHelp", root.lang)

                    Schalter {
                        an: root.val("minerDomains", true)
                        onUmgelegt: root.changed("minerDomains", !root.val("minerDomains", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.minerBoard", root.lang)
                    help: Tr.t("set.minerBoardHelp", root.lang)

                    Schalter {
                        an: root.val("minerBoard", true)
                        onUmgelegt: root.changed("minerBoard", !root.val("minerBoard", true))
                    }
                }

                Zeile {
                    label: Tr.t("miner.solo", root.lang)
                    help: Tr.t("set.minerSoloHelp", root.lang)

                    Schalter {
                        an: root.val("minerSolo", true)
                        onUmgelegt: root.changed("minerSolo", !root.val("minerSolo", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.netParts", root.lang)
                    help: Tr.t("set.netPartsHelp", root.lang)

                    Haken {
                        schluessel: "netParts"
                        alle: ["stats", "chart", "pools"]
                        eintraege: [
                            { "id": "stats", "l": Tr.t("set.metrics", root.lang) },
                            { "id": "chart", "l": Tr.t("set.minerChart", root.lang) },
                            { "id": "pools", "l": Tr.t("net.poolsLabel", root.lang) }
                        ]
                    }
                }
            }

            // -------------------------------------------------- Explorer
            Column {
                width: parent.width
                visible: root.tab === "explorer"


                Zeile {
                    label: Tr.t("set.explorerColor", root.lang)
                    help: Tr.t("set.explorerColorHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("tileColorMode", "fee")
                        eintraege: [
                            { "k": "fee", "l": Tr.t("color.fee", root.lang) },
                            { "k": "type", "l": Tr.t("color.type", root.lang) }
                        ]
                        onPicked: function (k) {
                            root.changed("tileColorMode", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.homeParts", root.lang)
                    help: Tr.t("set.homePartsHelp", root.lang)

                    Haken {
                        schluessel: "explorerParts"
                        alle: ["stats", "chain", "next", "panels", "recent"]
                        eintraege: [
                            { "id": "stats", "l": Tr.t("set.metrics", root.lang) },
                            { "id": "chain", "l": Tr.t("chain.label", root.lang) },
                            { "id": "next", "l": Tr.t("nextBlock", root.lang) },
                            { "id": "panels", "l": Tr.t("set.whichPanels", root.lang) },
                            { "id": "recent", "l": Tr.t("addr.lastTxs", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.whichPanels", root.lang)
                    help: Tr.t("set.whichPanelsHelp", root.lang)

                    Haken {
                        schluessel: "explorerPanels"
                        alle: ["fees", "difficulty", "mempool", "rbf"]
                        eintraege: [
                            { "id": "fees", "l": Tr.t("fees", root.lang) },
                            { "id": "difficulty", "l": Tr.t("difficulty", root.lang) },
                            { "id": "mempool", "l": Tr.t("mempool", root.lang) },
                            { "id": "rbf", "l": "RBF" }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.trackProjected", root.lang)
                    help: Tr.t("set.trackProjectedHelp", root.lang)

                    Schalter {
                        an: root.val("explorerLive", true)
                        onUmgelegt: root.changed("explorerLive", !root.val("explorerLive", true))
                    }
                }
            }

            // ------------------------------------------------------ Market
            Column {
                width: parent.width
                visible: root.tab === "markt"


                Zeile {
                    label: Tr.t("set.crosshair", root.lang)
                    help: Tr.t("set.crosshairHelp", root.lang)

                    Schalter {
                        an: root.val("marketCross", true)
                        onUmgelegt: root.changed("marketCross", !root.val("marketCross", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.tape", root.lang)
                    help: Tr.t("set.tapeHelp", root.lang)

                    Schalter {
                        an: root.val("marketTape", true)
                        onUmgelegt: root.changed("marketTape", !root.val("marketTape", true))
                    }
                }
            }

            // ---------------------------------------------------- Wallet
            Column {
                width: parent.width
                spacing: root.uiFont * 0.7
                visible: root.tab === "wallet"

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Tr.t("set.walletTitle", root.lang)
                    color: root.textColor
                    font.pixelSize: root.uiFont * 1.15
                }

                // The tab only appears after this has been read and confirmed.
                // Not because of the funds, which watch-only keeps fully safe,
                // but because of linkability: this is the only part of the
                // program where the user reveals something about themselves.
                Rectangle {
                    width: parent.width
                    height: warnung.height + root.uiFont * 1.6
                    radius: root.uiFont * 0.4
                    color: Qt.rgba(0.85, 0.55, 0.1, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(0.85, 0.55, 0.1, 0.45)

                    Column {
                        id: warnung

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.uiFont * 0.8
                        spacing: root.uiFont * 0.5

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: Tr.t("set.walletWarnTitle", root.lang)
                            color: root.accentColor
                            font.pixelSize: root.uiFont
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: Tr.t("set.walletWarn", root.lang)
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.85
                        }
                    }
                }

                Row {
                    spacing: root.uiFont * 0.6

                    Rectangle {
                        width: zusage.width + root.uiFont * 1.6
                        height: zusage.height + root.uiFont * 0.8
                        radius: height / 2
                        color: root.val("walletEnabled", false)
                            ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.rgba(0.34, 0.72, 0.58, 0.9)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)

                        Text {
                            id: zusage

                            anchors.centerIn: parent
                            text: Tr.t(root.val("walletEnabled", false)
                                       ? "set.walletDisable" : "set.walletEnable", root.lang)
                            color: root.val("walletEnabled", false) ? root.dimColor : "#0b0b12"
                            font.pixelSize: root.uiFont * 0.9
                            font.bold: !root.val("walletEnabled", false)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changed("walletEnabled",
                                                    !root.val("walletEnabled", false))
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: root.val("walletEnabled", false)
                    text: Tr.t("set.walletCli", root.lang)
                          + "\n    orangedeck --watch-add <xpub|ypub|zpub> \"Name\""
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                    font.family: Fonts.mono()
                }
            }
        }
    }
}
