// Browsable list of a block's transactions.
//
// The tile view shows the block at a glance but not in order. This shows
// the same data as a list: in block order, with amount, size, fee rate and,
// when tiles are colored by type, the derived type.
//
// The data is already there: `blocktiles` and `projectedtiles` provide one
// row [txid, vsize, fee, value, rate] per tile. Nothing is fetched, it is
// only presented differently.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "txtype.js" as TxType
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Column {
    id: root

    // Prepared tile data
    property var block: null
    property string colorMode: "fee"
    property int perPage: 25
    property int page: 0
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    property string lang: "de"
    property string btcZeichen: "\u20BF"

    signal txPicked(string txid)

    readonly property var alle: (block && block.txs) ? block.txs : []
    readonly property int seiten: Math.max(1, Math.ceil(alle.length / perPage))
    readonly property int step: (block && block.tileStep) || 1
    readonly property string types: (block && block.types) || ""

    // Back to the start when the block changes
    onBlockChanged: root.page = 0

    spacing: uiFont * 0.3

    // Thousands separator per language: German uses a period, English a comma.
    // This matters: "1.234" means either one thousand two hundred thirty-four
    // or one point two three four depending on the language.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function seite() {
        var von = root.page * root.perPage;
        var out = [];
        for (var i = von; i < Math.min(von + root.perPage, root.alle.length); i++) {
            var d = root.alle[i];
            out.push({
                "nr": i * root.step,
                "t": d[0],
                "v": d[1],
                "f": d[2],
                "a": d[3],
                "r": d[4],
                "k": i < root.types.length ? (parseInt(root.types.charAt(i), 10) || 0) : -1
            });
        }
        return out;
    }

    // ------------------------------------------------------- Header
    Row {
        width: parent.width
        spacing: root.uiFont * 0.8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Tr.t(root.step > 1 ? "txlist.tiles" : "txlist.count", root.lang,
                       root.grp(root.alle.length))
            color: root.textColor
            font.pixelSize: root.uiFont * 0.95
        }

        // For very large blocks the list is thinned out. Say so, otherwise
        // someone counts along and is confused.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.step > 1
            text: Tr.t("txlist.sampled", root.lang, root.step)
            color: root.accentColor
            font.pixelSize: root.uiFont * 0.8
        }

        Item {
            width: root.uiFont
            height: 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Tr.t("txlist.page", root.lang, root.page + 1, root.seiten)
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }
    }

    // ------------------------------------------------------------ List
    Repeater {
        model: root.seite()

        Rectangle {
            id: zeile

            required property var modelData

            width: root.width
            height: root.uiFont * 2.2
            radius: 4
            color: maus.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: root.uiFont * 0.6
                spacing: root.uiFont * 0.8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 3
                    horizontalAlignment: Text.AlignRight
                    text: "#" + zeile.modelData.nr
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }

                // The color dot shows the same type as the tile view, but only when that
                // view is colored by type; otherwise there would be two color schemes
                // side by side.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.colorMode === "type" && zeile.modelData.k >= 0
                    width: root.uiFont * 0.6
                    height: width
                    radius: 2
                    color: TxType.info(TxType.kindAt(zeile.modelData.k)).color
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 10
                    elide: Text.ElideMiddle
                    text: zeile.modelData.t
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.85
                    font.family: Fonts.mono()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 8
                    text: root.btcZeichen + " " + Tr.fixed(zeile.modelData.a / 1e8, 8, root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 6
                    text: root.grp(zeile.modelData.v) + " vB"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: zeile.modelData.r > 0
                        ? Tr.fixed(zeile.modelData.r, 2, root.lang) + " sat/vB"
                        : Tr.t("txlist.noFee", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }
            }

            MouseArea {
                id: maus

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.txPicked(String(zeile.modelData.t))
            }
        }
    }

    // ---------------------------------------------------------- Paging
    Row {
        spacing: root.uiFont * 0.6
        visible: root.seiten > 1

        Repeater {
            model: [
                { "l": Tr.t("page.first", root.lang), "d": -1000000 },
                { "l": Tr.t("page.prev", root.lang), "d": -1 },
                { "l": Tr.t("page.next", root.lang), "d": 1 },
                { "l": Tr.t("page.last", root.lang), "d": 1000000 }
            ]

            Rectangle {
                id: knopf

                required property var modelData

                readonly property bool moeglich: {
                    var z = Math.max(0, Math.min(root.seiten - 1, root.page + knopf.modelData.d));
                    return z !== root.page;
                }

                width: knopfText.width + root.uiFont * 1.2
                height: knopfText.height + root.uiFont * 0.6
                radius: height / 2
                opacity: knopf.moeglich ? 1 : 0.35
                color: knopfMaus.containsMouse && knopf.moeglich
                    ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    id: knopfText

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.85
                }

                MouseArea {
                    id: knopfMaus

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: knopf.moeglich ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (knopf.moeglich)
                            root.page = Math.max(0, Math.min(root.seiten - 1,
                                                             root.page + knopf.modelData.d));
                    }
                }
            }
        }
    }
}
