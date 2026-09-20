// Einstellungen, nach denselben Reitern geordnet wie die Ansichten.
//
// Die Werte gehoeren dem Wirt: die eigenstaendige Anwendung legt sie ueber
// QSettings ab, das Quickshell-Fenster in view.json, der Dashboard-Tab in den
// Plugin-Einstellungen von DMS. Hier steht nur die Oberflaeche -- sie liest
// `opts` und meldet jede Aenderung ueber `changed` zurueck.
//
// Bewusst mit eigenen kleinen Bedienelementen statt QtQuick.Controls: der Rest
// des Programms kommt mit `import QtQuick` aus, und das soll so bleiben --
// dieselben Dateien laufen im Fenster, im DMS-Plugin und spaeter unter Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts
import "views.js" as Views
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Tastatur: Bild auf/ab, Pos1, Ende (roll.js; aus Main.qml ueber FeedTabs)
    function rollen(wie) {
        return Roll.rollen(flaeche, wie);
    }

    property var opts: ({})
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    // Fuer die Auswahlfelder der Darstellungs-Seite: Rahmen und Untergrund
    // der aufgeklappten Liste. Der Wirt reicht dieselben Toene durch, die
    // seine uebrigen Flaechen tragen -- sonst erfindet die Liste eine eigene
    // Deckkraft neben den Einstellungen, ueber denen sie liegt.
    property color lineColor: "#2a2a38"
    property color panelColor: "#16161f"
    // Ansichten, hinter denen gerade nichts sein kann -- der Miner ohne
    // Bitaxe, Wallet und Markt im Direktbezug. Sie stehen in der Reihenfolge
    // trotzdem, sonst waere ihr Platz nicht einstellbar, solange man sie
    // nicht hat; die Seite schreibt nur dazu, dass sie gerade nicht kommen.
    property var nichtVerfuegbar: []

    // **Seiten fuer Ansichten, die es hier nicht gibt, gehoeren weg.** Unter
    // Android laufen Markt und Wallet nicht (beide brauchen den Dienst), die
    // Schalter dafuer standen aber trotzdem in den Einstellungen -- am
    // 11.09.2026 im Emulator gesehen. Anders als `nichtVerfuegbar` fragt das
    // hier nicht, ob der Anwender etwas abgeschaltet hat, sondern ob es
    // technisch geht: die Wallet-Seite ist die einzige Stelle, an der sich
    // die Wallet einschalten laesst.
    property bool kannMarkt: true
    property bool kannWallet: true
    property real uiFont: 13
    property string lang: "de"
    // Deckkraft und Startansicht gehoeren dem Fenster. Im Dashboard-Tab
    // stellt die Flaeche der Wirt, dort waeren beide wirkungslos.
    property bool windowed: true

    signal changed(string key, var value)

    property string tab: "allgemein"

    function val(key, fallback) {
        var v = root.opts ? root.opts[key] : undefined;
        return v === undefined ? fallback : v;
    }

    // Die Reihenfolge der Reiter, wie sie der Anwender festgelegt hat --
    // aufgefuellt und von Unbekanntem befreit durch `views.js`. Dieselbe
    // Rechnung wie in `FeedTabs`, aus derselben Tabelle.
    readonly property var reihenfolge: root.ohneEinstellungen(Views.ordnung(root.val("tabOrder", [])))

    // Ist "Einstellungen" kein Reiter (die Anwendung hat ein Zahnrad), steht es
    // weder in der Reihenfolge noch als Startansicht zur Wahl.
    property bool einstellungenAlsReiter: true

    function ohneEinstellungen(liste) {
        if (root.einstellungenAlsReiter)
            return liste;
        return liste.filter(function (id) {
            return id !== Views.EINSTELLUNGEN;
        });
    }

    // Die Auswahl in jedem Feld steht in der **Grundreihenfolge**, nicht in
    // der des Anwenders: eine Liste, die sich beim Auswaehlen selbst
    // umsortiert, springt einem unter dem Finger weg.
    readonly property var ansichtsListe: {
        var out = [];
        var a = root.ohneEinstellungen(Views.alle());
        for (var i = 0; i < a.length; i++) {
            out.push({ "k": String(a[i]),
                       "l": Tr.t(Views.name(a[i]), root.lang) });
        }
        return out;
    }

    // **Tauschen, nicht einfuegen.** Wer an Platz 2 den Markt waehlt, will
    // ihn dort haben -- und was dort stand, muss irgendwohin. Ein Tausch
    // laesst die Liste eine Vertauschung bleiben: jede Ansicht kommt genau
    // einmal vor, ohne Nachrechnen. Beim Einfuegen und Nachruecken wandern
    // dagegen alle dazwischenliegenden Reiter mit, und zwei Zuege hintereinander
    // ergeben eine Reihenfolge, die niemand vorhergesehen hat.
    function reiterTauschen(pos, id) {
        // Dieselbe Liste wie in der Anzeige -- sonst zaehlte `pos` in einer
        // anderen Reihenfolge, sobald die Einstellungen herausgefiltert sind
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

    // Eine Mehrfachauswahl wird als Liste von Schluesseln gehalten. Leer heisst
    // **alle** -- so bleibt eine spaeter hinzukommende Kennzahl sichtbar,
    // statt stillschweigend zu fehlen.
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

    // ---------------------------------------------------- Bedienelemente
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
            // **Oben ausrichten, wenn das Bedienelement hoeher ist.** Mittig
            // stimmt fuer einen Schalter oder einen Regler. Bei einem hohen
            // Gitter rutscht die Beschriftung dagegen in seine Mitte -- auf
            // einem Telefon stand "Sprache" dadurch neben "Português (BR)",
            // fuenf Zeilen unter dem ersten Knopf, zu dem sie gehoert. Am
            // 08.09.2026 auf einem Galaxy A55 gesehen; am Schreibtisch faellt
            // es nicht auf, weil die Gitter dort breiter und damit flacher
            // sind.
            //
            // **Als gerechnete Lage, nicht als wechselnde Anker.** Bis zum
            // 10.09.2026 stand hier `anchors.verticalCenter` oder
            // `anchors.top`, je nach derselben Bedingung. Beim Drehen des
            // Telefons von quer auf hoch wird die Flaeche schmaler, die Knoepfe
            // der Sprachwahl brechen auf mehr Zeilen um, `halter` wird hoeher,
            // und die Bedingung kippt -- mitten in der Benachrichtigung ueber
            // die neue Geometrie. Qt haengte die Anker um, waehrend es die
            // Liste ihrer Beobachter noch durchlief, und las einen Nullzeiger:
            // Absturz in jeder Ansicht, denn die Einstellungen sind immer
            // angelegt, auch unsichtbar. Am Schreibtisch nachgestellt mit
            // wechselnder Fenstergroesse im Xvfb; ohne SettingsView lief es,
            // mit jeder anderen fehlenden Ansicht nicht.
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

    // **Das erste Textfeld in den Einstellungen.** Bisher gab es hier nur
    // Schalter, Auswahllisten und Regler; was Text brauchte (Wallets, die
    // Miner-Adresse), lief ueber die Befehlszeile oder eine Datei -- und
    // beides gibt es auf einem Handy nicht.
    //
    // Vorbild ist das Suchfeld im Explorer, das einzige `TextInput` in
    // `ui/qml/`. Von dort kommen auch die beiden Lehren mit:
    //
    //   Der Fokus braucht einen eigenen Ausgang. Escape gibt ihn her,
    //   sonst sind die Reiter-Kuerzel nach einem Besuch hier tot (04.09.).
    //
    //   Auf dem Finger holt sich das Feld den Fokus **nicht** von selbst.
    //   Dort haengt daran die Bildschirmtastatur, und die deckt die halbe
    //   Ansicht zu (05.09.).
    //
    // Uebernommen wird erst bei Enter oder wenn das Feld den Fokus verliert
    // -- nicht bei jedem Tastendruck. Eine Adresse, die nach dem dritten
    // Zeichen abgefragt wird, ist eine Abfrage gegen den halben Text.
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

        // `Flow` statt `Row`: dreizehn Sprachen passen in keine Zeile mehr,
        // und abgeschnittene Knoepfe sind schlimmer als zwei Zeilen.
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

        // **Nicht breiter als die Spalte.** Fest 16 Schrifthoehen waren am
        // Telefon breiter als die rechte Haelfte der Zeile, und die Zahl
        // rechts neben der Bahn stand abgeschnitten am Rand (11.09.2026,
        // Galaxy A55).
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

    // Kaestchen zum An- und Abwaehlen, fuer Mehrfachauswahl
    component Haken: Flow {
        id: hakenRoot

        width: parent ? parent.width : 0

        property var alle: []
        property string schluessel: ""
        property var eintraege: []     // [{ id, l }]

        spacing: root.uiFont * 0.7

        Repeater {
            model: hakenRoot.eintraege

            // Ein `Item` um die Zeile herum: in einem `Row` darf ein Kind
            // kein `anchors.fill` haben, die Beruehrungsflaeche braucht aber
            // genau das.
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

    // ------------------------------------------------------------ Aufbau

    // Die Schluessel der Seiten, in der Reihenfolge der Reiter darueber --
    // an **einer** Stelle, damit Beschriftung und Wirkung nicht
    // auseinanderlaufen koennen. Sie standen vorher zweimal da, einmal fuer
    // `current` und einmal im Handler.
    readonly property var seiten: {
        var l = ["allgemein", "darstellung", "feed", "clock", "miner", "explorer"];
        if (root.kannMarkt)
            l.push("markt");
        if (root.kannWallet)
            l.push("wallet");
        return l;
    }

    // Faellt die offene Seite weg, bleibt der Reiter sonst ohne Inhalt stehen.
    onSeitenChanged: if (root.seiten.indexOf(root.tab) < 0)
        root.tab = "allgemein";

    // **Acht Reiter passen auf einem Telefon nicht mehr in eine Zeile.**
    // `ViewTabs` ist eine `Row`: sie laeuft rechts einfach aus dem Bild,
    // ohne Rand und ohne Hinweis. Schon mit sieben war es auf 440 Punkten
    // knapp -- die achte Seite waere dort schlicht nicht erreichbar gewesen.
    // Die Reihe liegt deshalb in einem waagerechten Schieber, der nur dann
    // etwas tut, wenn sie wirklich zu breit ist.
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

            // ------------------------------------------------- Allgemein
            Column {
                width: parent.width
                visible: root.tab === "allgemein"

                // Ohne Dienst (Android, Windows) gibt es nichts zu waehlen. Das
                // DMS-Plugin und Quickshell kennen den Schluessel nicht und
                // behalten mit der Vorgabe beide Zeilen.
                Zeile {
                    label: Tr.t("set.source", root.lang)
                    help: Tr.t("set.sourceHelp", root.lang)
                    visible: root.val("dienstMoeglich", true)

                    Wahl {
                        gewaehlt: root.val("dataSource", "daemon")
                        // "auto" steht ueberall dort, wo es ueberhaupt einen
                        // Dienst geben kann -- `FeedState` kennt die Betriebsart
                        // in jedem Wirt. Vorgabe ist es nur im DMS-Plugin: dort
                        // ist der Dienst die Ausnahme, in der Anwendung die Regel.
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

                // **Der Weg zum Dienst auf einem anderen Geraet.** Leer ist
                // der Dienst auf demselben Rechner; eingetragen ist es der
                // im eigenen Netz -- und damit haben Tablett und Telefon
                // Markt und Wallet, die sonst ausserhalb von Linux fehlen.
                //
                // Nur im Dienst-Betrieb sichtbar: im Direktbezug fragt
                // niemand nach, und ein Feld ohne Wirkung ist eine Falle.
                Zeile {
                    label: Tr.t("set.daemonHost", root.lang)
                    help: Tr.t("set.daemonHostHelp", root.lang)
                    // Auch bei "auto" sichtbar: die Suche klopft an genau
                    // dieser Adresse an. Nur im Direktbezug fragt niemand
                    // nach, und ein Feld ohne Wirkung ist eine Falle.
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
                        // **Vorgabe ist USD, nicht EUR.** Bitcoin wird
                        // weltweit in Dollar notiert; Euro ist eine bewusste
                        // Wahl. Dieselbe Vorgabe steht in `DeckWidget.java`,
                        // damit Reiter und Widget nicht auseinanderlaufen,
                        // solange niemand etwas eingestellt hat.
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

                    // **"Systemsprache" vorn: leer heisst, dem System folgen.**
                    // Wirte ohne `langWahl` (DMS, Quickshell) speichern das
                    // Leere unter `lang`, und FeedTabs faellt dann ebenso auf
                    // die Systemsprache zurueck.
                    Wahl {
                        gewaehlt: root.val("langWahl", root.val("lang", root.lang))
                        eintraege: [{ "k": "", "l": Tr.t("set.langSystem", root.lang) }]
                                   .concat(Tr.languages())
                        onPicked: function (k) {
                            root.changed("lang", k);
                        }
                    }
                }

                // **Nicht auf Android.** Die Activity wird dort immer deckend
                // gezeichnet; der Regler bewegte am Telefon nichts
                // (11.09.2026).
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

            // ----------------------------------------------- Darstellung
            //
            // **Die Reihenfolge der Reiter gehoert dem Anwender.** Sie stand
            // vorher fest in `FeedTabs`, und die Startansicht zaehlte daneben
            // ein zweites Mal auf, welche Ansichten es ueberhaupt gibt -- eine
            // Liste, die bei Feed, Uhr, Miner, Explorer stehengeblieben war.
            // Markt und Wallet kamen spaeter dazu und fehlten dort seither:
            // wer im Markt starten wollte, konnte es nicht einstellen. Beide
            // lesen jetzt aus `views.js`.
            //
            // Hierher gehoeren auch die Schalter, mit denen sich ein Reiter
            // ganz abschalten laesst. Sie lagen vorher je auf der Seite ihrer
            // eigenen Ansicht -- also dort, wo man sie am wenigsten braucht
            // und am schlechtesten findet: **wer einen Reiter abgeschaltet
            // hat, kommt auf dessen Seite nicht mehr, um ihn wieder
            // anzuschalten.** Erreichbar war er nur noch ueber diese Seite,
            // auf der er bis eben nicht stand.
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

                // Reiter im Wechsel, fuer eine Blockuhr an der Wand. Der Takt
                // laeuft in `FeedTabs`.
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
                            // Den Markt nur, wo es ihn gibt (nicht im Direktbezug)
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
                        // Der Hinweis steht **einmal**, an der ersten Zeile.
                        // Siebenmal derselbe Satz untereinander liest sich
                        // wie ein Fehler, nicht wie eine Erklaerung.
                        help: !platz.moeglich ? Tr.t("set.tabUnavailable", root.lang)
                              : (platz.index === 0 ? Tr.t("set.tabOrderHelp", root.lang) : "")

                        DropDown {
                            id: feld

                            anchors.left: parent.left
                            // **Immer bis an den Schalter, auch wo keiner
                            // gezeichnet wird.** Ein unsichtbares Element
                            // behaelt seine Breite: laesst man die Felder
                            // ohne Schalter bis an den Rand laufen, enden
                            // fuenf an einer Kante und zwei an einer
                            // anderen. Der leere Platz kostet nichts, die
                            // ausgefranste Kante faellt sofort auf.
                            anchors.right: schalt.left
                            anchors.rightMargin: root.uiFont * 0.7
                            // **Der Rahmen ist die Seite, nicht die Zeile.**
                            // Die aufgeklappte Liste haengt sich in dieses
                            // Element um -- und es liegt ausserhalb des
                            // Schiebers, der den Inhalt beschneidet. In der
                            // Zeile stehend waere sie an dessen Rand
                            // abgeschnitten worden.
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

                            // Die Liste misst ihre Lage **beim Aufklappen**
                            // und danach nicht mehr -- absichtlich, siehe
                            // `DropDown.qml`. Auf einer Seite, die scrollt,
                            // heisst das: wer bei offener Liste schiebt,
                            // laesst sie stehen. Also zuklappen.
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
                            // Einstellungen und Wallet tragen keinen: die
                            // einen bleiben immer, die andere haengt am
                            // Schalter mit der Warnung davor. Ein zweiter
                            // daneben waere nur die Frage, welcher gilt.
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

            // ------------------------------------------------ Uhr
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

                // Welche Seiten der Reiter hat. Ohne "Geraet" nur das Netz,
                // auch mit eingetragenem Miner.
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

            // ------------------------------------------------------ Markt
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

                // Der Reiter erscheint erst, wenn das hier gelesen und
                // bestaetigt wurde. Nicht wegen der Guthaben -- die sind
                // watch-only vollstaendig geschuetzt --, sondern wegen der
                // Verkettung: das ist der einzige Teil des Programms, bei dem
                // der Benutzer etwas ueber sich preisgibt.
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
