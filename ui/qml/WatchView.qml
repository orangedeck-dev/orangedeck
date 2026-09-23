// Watched wallets, strictly read-only.
//
// Core rule of the project (ZIELBILD.md): the app never gets hold of
// anything that could move money. So only an extended public key is used
// here; the daemon derives the addresses with plain point arithmetic.
// There is no line anywhere in the program that could sign.
//
// Wallets are added on the command line, not here: the daemon accepts
// nothing, it only answers. A write path would be the first attack surface.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr
import "fonts.js" as Fonts
import "roll.js" as Roll

pragma ComponentBehavior: Bound

Item {
    id: root

    // Keyboard: Page Up/Down, Home, End (roll.js, forwarded from Main.qml via FeedTabs)
    function rollen(wie) {
        return Roll.rollen(flick, wie);
    }

    property var feed: null
    // Is anyone looking? Otherwise nothing is requested.
    property bool live: true
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    readonly property real uiFont: Math.max(11, Math.min(14, scaleUnit * 0.62))

    // Open a transaction or address in the explorer
    signal txPicked(string txid)
    signal addressPicked(string address)

    // Copy to clipboard: like in the explorer via an invisible text field,
    // QtQuick has nothing built in for this.
    TextEdit {
        id: clipboard

        visible: false
    }

    property string copied: ""

    function copyText(t) {
        if (!t)
            return;
        clipboard.text = String(t);
        clipboard.selectAll();
        clipboard.copy();
        root.copied = String(t);
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer

        interval: 1400
        onTriggered: root.copied = ""
    }

    property var wallets: []
    property bool busy: false
    property string error: ""
    property int shown: 0            // which wallet, if there are several
    property string tab: "txs"       // txs | addr
    property bool __pending: false

    readonly property var one: (wallets.length > shown) ? wallets[shown] : null
    property string currency: "eur"
    property string lang: "de"
    property string btcZeichen: "\u20BF"

    // Thousands separator per language: German uses a period, English a comma.
    // This matters: "1.234" means either one thousand two hundred thirty-four
    // or one point two three four depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function btc(sats) {
        return Tr.fixed(sats / 1e8, 8, root.lang);
    }

    function euro(sats) {
        var pr = root.feed ? root.feed.price : null;
        return Tr.fiat(sats, Money.rate(pr, root.currency),
                       Money.symbol(Money.actual(pr, root.currency)), root.lang);
    }

    function ago(ts) {
        if (!ts)
            return Tr.t("unconfirmed", root.lang);
        var m = Math.floor(Math.max(0, Date.now() / 1000 - ts) / 60);
        if (m < 60)
            return Tr.t("ago.min", root.lang, m);
        var h = Math.floor(m / 60);
        if (h < 48)
            return Tr.t("ago.hour", root.lang, h);
        var t = Math.floor(h / 24);
        return t < 60 ? Tr.t("ago.day", root.lang, t)
                      : Tr.t("ago.month", root.lang, Math.floor(t / 30));
    }

    function kindLabel(k) {
        if (k === "p2wpkh")
            return Tr.t("wallet.kindP2wpkh", root.lang);
        if (k === "p2sh-p2wpkh")
            return Tr.t("wallet.kindP2sh", root.lang);
        if (k === "p2pkh")
            return Tr.t("wallet.kindP2pkh", root.lang);
        return k || "";
    }

    function refresh() {
        if (!root.feed || root.__pending || !root.live)
            return;
        root.__pending = true;
        root.feed.getJson("/wallets", function (d, err) {
            root.__pending = false;
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.wallets = d.wallets || [];
            root.busy = !!d.busy;
            if (root.shown >= root.wallets.length)
                root.shown = 0;
        });
    }

    onLiveChanged: {
        if (root.live)
            refresh();
    }

    Component.onCompleted: refresh()

    // Five seconds is enough: the daemon scans every five minutes and after
    // every new block. Asking more often would bring nothing new.
    Timer {
        interval: 5000
        repeat: true
        running: root.live && root.feed !== null
        onTriggered: root.refresh()
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: spalte.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: spalte

            width: flick.width
            spacing: root.uiFont

            // ------------------------------------- nothing configured yet
            Column {
                width: parent.width
                spacing: root.uiFont * 0.6
                visible: root.wallets.length === 0

                Text {
                    text: Tr.t("wallet.none", root.lang)
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Tr.t("wallet.intro", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.95
                }

                Rectangle {
                    width: parent.width
                    height: befehl.height + root.uiFont * 1.4
                    radius: root.uiFont * 0.4
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    Column {
                        id: befehl

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.uiFont * 0.8
                        spacing: root.uiFont * 0.3

                        Text {
                            text: Tr.t("wallet.cmdAdd", root.lang)
                            color: root.accentColor
                            font.pixelSize: root.uiFont
                            font.family: Fonts.mono()
                        }

                        Text {
                            text: Tr.t("wallet.cmdList", root.lang) + "\n"
                                  + Tr.t("wallet.cmdRemove", root.lang) + "\n"
                                  + Tr.t("wallet.cmdRestart", root.lang)
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                            font.family: Fonts.mono()
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Tr.t("wallet.cliNote", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }
            }

            // ------------------------------------------------ Wallet selection
            Row {
                spacing: root.uiFont * 0.6
                visible: root.wallets.length > 1

                Repeater {
                    model: root.wallets

                    Rectangle {
                        id: wahl

                        required property var modelData
                        required property int index

                        readonly property bool aktiv: root.shown === wahl.index

                        width: wahlText.width + root.uiFont * 1.4
                        height: wahlText.height + root.uiFont * 0.6
                        radius: height / 2
                        color: wahl.aktiv ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: wahl.aktiv ? root.accentColor : Qt.rgba(1, 1, 1, 0.1)

                        Text {
                            id: wahlText

                            anchors.centerIn: parent
                            text: wahl.modelData.name
                            color: wahl.aktiv ? root.textColor : root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shown = wahl.index
                        }
                    }
                }
            }

            // ---------------------------------------------------- Header
            Column {
                width: parent.width
                spacing: root.uiFont * 0.25
                visible: root.one !== null

                Row {
                    spacing: root.uiFont * 0.6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.one ? root.one.name : ""
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.8
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.one ? root.kindLabel(root.one.kind) : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.busy ? Tr.t("wallet.scanning", root.lang) : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }
                }

                Text {
                    text: root.one ? root.btcZeichen + " " + root.btc(root.one.balance) : ""
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 1.7
                    font.bold: true
                }

                Text {
                    text: root.one ? root.euro(root.one.balance) : ""
                    color: root.dimColor
                    font.pixelSize: root.uiFont
                }

                Text {
                    visible: root.one && root.one.pending !== 0
                    text: root.one
                        ? Tr.t("wallet.pending", root.lang,
                               (root.one.pending > 0 ? "+" : "") + root.btcZeichen + " " + root.btc(root.one.pending))
                        : ""
                    color: root.goodColor
                    font.pixelSize: root.uiFont * 0.9
                }

                Text {
                    visible: root.one && root.one.error
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.one ? Tr.grund(root.one.error, root.lang) : ""
                    color: root.badColor
                    font.pixelSize: root.uiFont * 0.9
                }
            }

            // ------------------------------------------------- Stats
            Flow {
                width: parent.width
                spacing: root.uiFont * 1.8
                visible: root.one !== null

                Repeater {
                    model: {
                        var w = root.one;
                        if (!w)
                            return [];
                        return [
                            { "k": Tr.t("wallet.received", root.lang), "v": root.btcZeichen + " " + root.btc(w.received) },
                            { "k": Tr.t("wallet.spent", root.lang), "v": root.btcZeichen + " " + root.btc(w.sent) },
                            { "k": Tr.t("transactions", root.lang), "v": root.grp(w.txCount) },
                            { "k": Tr.t("wallet.usedAddresses", root.lang), "v": root.grp(w.used) },
                            { "k": Tr.t("wallet.fingerprint", root.lang), "v": w.fingerprint || "–" }
                        ];
                    }

                    Column {
                        id: kennzahl

                        required property var modelData

                        spacing: root.uiFont * 0.1

                        Text {
                            text: kennzahl.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.8
                        }

                        Text {
                            text: kennzahl.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 1.1
                        }
                    }
                }
            }

            // ---------------------------------- next receive address
            Column {
                width: parent.width
                spacing: root.uiFont * 0.2
                visible: root.one !== null && root.one.nextRecv

                Text {
                    text: Tr.t("wallet.nextRecv", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Row {
                    spacing: root.uiFont * 0.5

                    Text {
                        id: naechste

                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(spalte.width - root.uiFont * 4, implicitWidth)
                        elide: Text.ElideMiddle
                        text: root.one ? root.one.nextRecv : ""
                        color: root.textColor
                        font.pixelSize: root.uiFont
                        font.family: Fonts.mono()
                    }

                    CopyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.one ? root.one.nextRecv : ""
                        done: root.copied === (root.one ? root.one.nextRecv : "")
                        size: root.uiFont * 1.05
                        iconColor: root.dimColor
                        hoverColor: root.textColor
                        doneColor: root.goodColor
                        onCopy: function (was) {
                            root.copyText(was);
                        }
                    }
                }
            }

            // ----------------------------------------------------- Toggle
            Row {
                spacing: root.uiFont * 1.2
                visible: root.one !== null

                Repeater {
                    model: [
                        { "k": "txs", "l": Tr.t("transactions", root.lang) },
                        { "k": "addr", "l": Tr.t("wallet.tabAddrs", root.lang) }
                    ]

                    Item {
                        id: reiter

                        required property var modelData

                        readonly property bool aktiv: root.tab === reiter.modelData.k

                        width: reiterText.width
                        height: reiterText.height + root.uiFont * 0.5

                        Text {
                            id: reiterText

                            anchors.top: parent.top
                            text: reiter.modelData.l
                            color: reiter.aktiv ? root.textColor : root.dimColor
                            font.pixelSize: root.uiFont
                            font.bold: reiter.aktiv
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: reiter.aktiv ? parent.width : 0
                            height: 2
                            radius: 1
                            color: root.accentColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 140
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = reiter.modelData.k
                        }
                    }
                }
            }

            // ------------------------------------------ Transaction list
            Column {
                width: parent.width
                spacing: root.uiFont * 0.25
                visible: root.one !== null && root.tab === "txs"

                Repeater {
                    model: root.one ? (root.one.txs || []) : []

                    Rectangle {
                        id: zeile

                        required property var modelData

                        width: parent.width
                        height: root.uiFont * 2.4
                        radius: 4
                        color: zeileMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.07)
                                                       : Qt.rgba(1, 1, 1, 0.03)

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.uiFont * 0.7
                            spacing: root.uiFont

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 9
                                elide: Text.ElideMiddle
                                text: zeile.modelData.t
                                color: root.textColor
                                font.pixelSize: root.uiFont * 0.85
                                font.family: Fonts.mono()
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 9
                                // The sign is the point: what the wallet gained or lost.
                                text: (zeile.modelData.d > 0 ? "+" : "")
                                      + root.btcZeichen + " " + root.btc(zeile.modelData.d)
                                color: zeile.modelData.d > 0 ? root.goodColor
                                                             : root.textColor
                                font.pixelSize: root.uiFont * 0.85
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 7
                                text: zeile.modelData.ok
                                    ? root.ago(zeile.modelData.ts)
                                    : Tr.t("unconfirmed", root.lang)
                                color: zeile.modelData.ok ? root.dimColor : root.accentColor
                                font.pixelSize: root.uiFont * 0.85
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: zeile.modelData.h
                                    ? Tr.t("block", root.lang) + " " + root.grp(zeile.modelData.h)
                                    : ""
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.85
                            }
                        }

                        MouseArea {
                            id: zeileMaus

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.txPicked(String(zeile.modelData.t))
                        }
                    }
                }
            }

            // ----------------------------------------------- Address list
            Column {
                width: parent.width
                spacing: root.uiFont * 0.25
                visible: root.one !== null && root.tab === "addr"

                Repeater {
                    model: root.one ? (root.one.addresses || []) : []

                    Rectangle {
                        id: adrZeile

                        required property var modelData

                        width: parent.width
                        height: root.uiFont * 2.4
                        radius: 4
                        color: adrMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.07)
                                                     : Qt.rgba(1, 1, 1, 0.03)

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.uiFont * 0.7
                            spacing: root.uiFont

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 4
                                // Change belongs to the wallet itself, which the addresses alone do
                                // not reveal.
                                text: Tr.t(adrZeile.modelData.c === 1 ? "wallet.changeN"
                                                                      : "wallet.recvN",
                                           root.lang, adrZeile.modelData.i)
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.8
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 12
                                elide: Text.ElideMiddle
                                text: adrZeile.modelData.a
                                color: root.textColor
                                font.pixelSize: root.uiFont * 0.85
                                font.family: Fonts.mono()
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 9
                                text: root.btcZeichen + " " + root.btc(adrZeile.modelData.bal)
                                color: adrZeile.modelData.bal > 0 ? root.textColor
                                                                  : root.dimColor
                                font.pixelSize: root.uiFont * 0.85
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: adrZeile.modelData.n + "×"
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.85
                            }
                        }

                        MouseArea {
                            id: adrMaus

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addressPicked(String(adrZeile.modelData.a))
                        }
                    }
                }
            }

            // -------------------------------------------------- Footnote
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.one !== null
                text: Tr.t("wallet.footnote", root.lang)
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.8
            }

            Text {
                width: parent.width
                visible: root.error.length > 0
                text: Tr.grund(root.error, root.lang)
                color: root.badColor
                font.pixelSize: root.uiFont * 0.9
            }
        }
    }
}
