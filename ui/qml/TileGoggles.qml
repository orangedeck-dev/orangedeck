// Toggle and legend for the tile color, the "mempool goggles".
//
// Same tiles, two readings:
//
//   fee   teal to violet by sat/vB, the original's colors
//   type  what the transaction does, derived from the mempool.space
//         bit field `flags` (see txtype.js)
//
// The legend only lists what occurs in the block, with counts; a color
// without a tile would just be noise.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick
import "txtype.js" as TxType
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Column {
    id: root

    property string mode: "fee"           // fee | age | type
    // Which readings are offered. The explorer has two, the feed three: there
    // age is added, because the pile keeps growing and a finished block does not.
    property var modes: [
        { "k": "fee", "l": Tr.t("color.fee", lang) },
        { "k": "type", "l": Tr.t("color.type", lang) }
    ]
    // Extra line below the legend when the type reading does not apply everywhere
    property string note: ""
    // In the feed the toggle sits below the legend at the right edge
    property bool alignRight: false
    // Count per type, index as in TxType.KINDS
    property var counts: []
    property int total: 0
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    // The tap area may be larger than the button. A finger needs about 40 px
    // of height, the buttons are often drawn a third of that. Extended only up
    // and down: sideways the neighbors are too close and would compete for
    // the touch.
    property real minTap: 0
    property string lang: "de"
    // Text in front of the buttons. The toggle is also used for the price
    // chart spans, where "Color:" would be wrong. An empty value hides the
    // label.
    property string labelKey: "color.label"

    signal picked(string mode)

    // Actual width of the button row. The feed sizes itself from it so the
    // background behind it wraps the buttons exactly; a guessed width is
    // either too narrow or leaves an empty area on the left.
    readonly property real schalterBreite: schalterZeile.implicitWidth

    spacing: uiFont * 0.4

    // ------------------------------------------------------- Toggle
    Row {
        id: schalterZeile

        anchors.right: root.alignRight ? parent.right : undefined
        spacing: root.uiFont * 0.9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // No manual `width`: a `Row` skips invisible children anyway, and
            // `width: implicitWidth` on a Text is a binding loop that Qt reports on
            // every start.
            visible: root.labelKey !== ""
            text: root.labelKey === "" ? "" : Tr.t(root.labelKey, root.lang)
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }

        Repeater {
            model: root.modes

            Item {
                id: knopf

                required property var modelData

                readonly property bool aktiv: root.mode === knopf.modelData.k

                width: beschriftung.width + root.uiFont * 1.2
                height: beschriftung.height + root.uiFont * 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: knopf.aktiv ? Qt.rgba(1, 1, 1, 0.12)
                                       : (maus.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
                                                             : "transparent")
                    border.width: 1
                    border.color: knopf.aktiv ? root.accentColor : Qt.rgba(1, 1, 1, 0.1)
                }

                Text {
                    id: beschriftung

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: knopf.aktiv ? root.textColor : root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }

                MouseArea {
                    id: maus

                    anchors.fill: parent
                    anchors.topMargin: -Math.max(0, (root.minTap - knopf.height) / 2)
                    anchors.bottomMargin: -Math.max(0, (root.minTap - knopf.height) / 2)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(knopf.modelData.k)
                }
            }
        }
    }

    // ---------------------------------------------------------- Legend
    Flow {
        width: parent.width
        spacing: root.uiFont * 1.1
        // Not just `mode === "type"`. Where no counts are provided (the normal
        // case in the feed) the row stays empty but still counts as a visible
        // child in the column and adds its spacing, making the background taller
        // than what it wraps.
        visible: root.mode === "type" && (root.counts || []).length > 0

        Repeater {
            model: {
                var out = [];
                for (var i = 0; i < (root.counts || []).length; i++) {
                    if (root.counts[i] > 0)
                        out.push({ "i": i, "n": root.counts[i] });
                }
                // Most frequent first, so what shapes the picture comes first
                out.sort(function (a, b) {
                    return b.n - a.n;
                });
                return out;
            }

            Row {
                id: eintrag

                required property var modelData

                readonly property var meta: TxType.info(TxType.kindAt(eintrag.modelData.i))

                spacing: root.uiFont * 0.35

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 0.7
                    height: width
                    radius: 2
                    color: eintrag.meta.color
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t(TxType.labelKey(TxType.kindAt(eintrag.modelData.i)), root.lang)
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Something that occurs but is below half a percent must not show as
                    // "0 %"; the rare types are the reason to switch in the first place.
                    text: {
                        if (root.total <= 0)
                            return "";
                        var p = 100 * eintrag.modelData.n / root.total;
                        return p < 0.5 ? Tr.t("pct.lessThanOne", root.lang)
                                       : Math.round(p) + " %";
                    }
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }
            }
        }
    }

    // The type is an interpretation, and the UI should say so.
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        // Only where the color table is shown. In the feed the legend on the
        // right already says the same; twice would be noise.
        visible: root.mode === "type"
                 && (root.note.length > 0 || (root.counts || []).length > 0)
        text: (root.note.length ? root.note + " " : "") + Tr.t("goggles.note", root.lang)
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.75
    }
}
