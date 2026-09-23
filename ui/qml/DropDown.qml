// A select box. Collapsed it is one row, expanded it shows a list below.
//
// Hand-made because the project does not use Qt Quick Controls: the shared
// components depend on nothing but Qt Quick, otherwise they would run
// neither under Quickshell nor on Android. For the same reason there is no
// `Popup`: the list is a plain item with a high `z`, and the host must not
// clip it (`clip`).
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    // [{ "k": <key>, "l": <label> }, ...]
    property var model: []
    property string current: ""
    // Text for the closed box when it should differ from the model label,
    // e.g. shorter where space is tight. The list keeps its labels.
    property string anzeige: ""
    property bool offen: false
    // Maximum number of rows the expanded list shows
    property int maxZeilen: 9
    // The frame the list has to stay inside. In QML a child draws freely
    // beyond its parent's bounds, so in the dashboard tab the list ended up
    // in the transparent margin of the popout window. The list is aligned to
    // this item instead: pushed in sideways, and opened upwards when there is
    // no room below.
    property Item bounds: root.parent

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property color flaecheColor: "#16161f"
    property real uiFont: 12

    signal picked(string key)

    readonly property real zeilenHoehe: Math.round(root.uiFont * 2.0)
    readonly property real listeHoehe: Math.min(root.maxZeilen, root.model.length)
                                       * root.zeilenHoehe + 6
    readonly property real listeBreite: Math.max(feld.width,
                                                 inhalt.breiteste + root.uiFont * 2)
    // Position of the box within the frame.
    //
    // Not a binding. `mapToItem` reads the position once and never notifies
    // again, so a binding would use the state at creation time, before the
    // anchors were resolved. A box at the bottom would then think it is at the
    // top and put its list in the wrong place. So it is measured when the list
    // opens, which is the only time it matters.
    property point lage: Qt.point(0, 0)

    function lageMessen() {
        if (root.bounds)
            root.lage = root.mapToItem(root.bounds, 0, 0);
    }

    onOffenChanged: if (root.offen) root.lageMessen()
    onWidthChanged: if (root.offen) root.lageMessen()
    onHeightChanged: if (root.offen) root.lageMessen()
    Component.onCompleted: root.lageMessen()
    // No room below but room above: open upwards
    readonly property bool nachOben: root.bounds
        && root.lage.y + feld.height + root.listeHoehe + 3 > root.bounds.height
        && root.lage.y - root.listeHoehe - 3 >= 0

    implicitWidth: feld.implicitWidth
    implicitHeight: feld.height
    height: feld.height

    function beschriftung(k) {
        for (var i = 0; i < root.model.length; i++) {
            if (root.model[i].k === k)
                return root.model[i].l;
        }
        return k;
    }

    Rectangle {
        id: feld

        width: root.width
        implicitWidth: text.implicitWidth + pfeil.width + root.uiFont * 2.2
        height: Math.round(root.uiFont * 2.0)
        radius: height / 2
        color: maus.containsMouse || root.offen ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        border.width: 1
        border.color: root.offen ? root.accentColor : root.lineColor

        Text {
            id: text

            anchors.left: parent.left
            anchors.leftMargin: root.uiFont * 0.8
            anchors.verticalCenter: parent.verticalCenter
            text: root.anzeige.length ? root.anzeige : root.beschriftung(root.current)
            color: root.textColor
            font.pixelSize: root.uiFont
        }

        // A drawn triangle instead of a glyph; a glyph would change size and
        // position with the font.
        Canvas {
            id: pfeil

            anchors.right: parent.right
            anchors.rightMargin: root.uiFont * 0.7
            anchors.verticalCenter: parent.verticalCenter
            width: root.uiFont * 0.7
            height: root.uiFont * 0.45

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.dimColor;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width / 2, height);
                ctx.closePath();
                ctx.fill();
            }
        }

        MouseArea {
            id: maus

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.offen = !root.offen
        }
    }

    // Catch area: a click outside closes the list. It sits below the list
    // but above everything else.
    //
    // Not attached to `root.parent`. The select box sits in a `Row`, which is
    // a positioner and lays out every child. The catch area would become
    // another item in the row, `anchors.fill` would stretch it to the row's
    // width, the row would grow, and so on; since the row is right-aligned,
    // box and toggle were pushed off screen to the left.
    //
    // The frame is a plain item and lays out nothing.
    MouseArea {
        parent: root.bounds ? root.bounds : root
        anchors.fill: parent
        z: 90
        visible: root.offen
        onClicked: root.offen = false
    }

    Rectangle {
        id: liste

        // Same parent as the catch area. `z` only orders siblings: with the list
        // in the row and the catch area in the frame, the catch area covered the
        // whole row and every click on an entry just closed the list.
        parent: root.bounds ? root.bounds : root

        // Right-aligned below the box, as long as that stays inside the frame.
        // Otherwise it is pushed in.
        x: {
            var wunsch = feld.width - root.listeBreite;
            if (!root.bounds)
                return wunsch;
            return Math.max(0, Math.min(root.bounds.width - root.listeBreite,
                                        root.lage.x + wunsch));
        }
        y: {
            var unter = root.nachOben ? -root.listeHoehe - 3 : feld.height + 3;
            return root.bounds ? root.lage.y + unter : unter;
        }
        width: root.listeBreite
        height: root.listeHoehe
        readonly property real zeilenHoehe: root.zeilenHoehe
        radius: root.uiFont * 0.5
        color: root.flaecheColor
        border.width: 1
        border.color: root.lineColor
        visible: root.offen
        z: 100
        clip: true

        Column {
            id: inhalt

            anchors.fill: parent
            anchors.margins: 3

            // Measured, not computed, and declaratively: one hidden Text per entry.
            // A function that sets a shared measuring text would be a side effect in
            // a binding: it computes correctly once and then never updates.
            property real breiteste: {
                var w = 0;
                for (var i = 0; i < masse.count; i++) {
                    var e = masse.itemAt(i);
                    if (e)
                        w = Math.max(w, e.implicitWidth);
                }
                return w;
            }

            Repeater {
                model: root.model

                Rectangle {
                    id: zeile

                    required property var modelData

                    width: inhalt.width
                    height: liste.zeilenHoehe
                    radius: root.uiFont * 0.4
                    color: zeile.modelData.k === root.current
                           ? Qt.rgba(root.accentColor.r, root.accentColor.g,
                                     root.accentColor.b, 0.18)
                           : (zeileMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: root.uiFont * 0.7
                        anchors.verticalCenter: parent.verticalCenter
                        text: zeile.modelData.l
                        color: zeile.modelData.k === root.current ? root.accentColor : root.textColor
                        font.pixelSize: root.uiFont
                    }

                    MouseArea {
                        id: zeileMaus

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.offen = false;
                            root.picked(zeile.modelData.k);
                        }
                    }
                }
            }
        }
    }

    // Invisible ruler for the list width
    Item {
        visible: false

        Repeater {
            id: masse

            model: root.model

            Text {
                required property var modelData

                text: modelData.l
                font.pixelSize: root.uiFont
            }
        }
    }
}
