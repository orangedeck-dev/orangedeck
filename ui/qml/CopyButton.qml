// Copy button as an icon. Drawn on a Canvas instead of using a glyph: there
// is no copy glyph in every font, and symbol fonts are not reliable.
//
// Only `import QtQuick`, so it also runs on Android.
import QtQuick

Item {
    id: root

    property string text: ""
    property bool done: false
    property color iconColor: "#9a94a6"
    property color hoverColor: "#f2eef8"
    property color doneColor: "#57b894"
    property real size: 14

    signal copy(string what)

    implicitWidth: size * 1.5
    implicitHeight: size * 1.5
    width: implicitWidth
    height: implicitHeight

    Canvas {
        id: icon

        anchors.centerIn: parent
        width: root.size
        height: root.size

        Connections {
            target: root
            function onDoneChanged() {
                icon.requestPaint();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var c = root.done ? root.doneColor
                              : (area.containsMouse ? root.hoverColor : root.iconColor);
            ctx.strokeStyle = c;
            ctx.lineWidth = Math.max(1.1, width * 0.09);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            if (root.done) {
                // Check mark
                ctx.beginPath();
                ctx.moveTo(width * 0.2, height * 0.55);
                ctx.lineTo(width * 0.42, height * 0.78);
                ctx.lineTo(width * 0.82, height * 0.24);
                ctx.stroke();
                return;
            }

            // Two offset sheets, the usual copy icon
            var r = width * 0.12;
            function rect(x, y, w2, h2) {
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.lineTo(x + w2 - r, y);
                ctx.quadraticCurveTo(x + w2, y, x + w2, y + r);
                ctx.lineTo(x + w2, y + h2 - r);
                ctx.quadraticCurveTo(x + w2, y + h2, x + w2 - r, y + h2);
                ctx.lineTo(x + r, y + h2);
                ctx.quadraticCurveTo(x, y + h2, x, y + h2 - r);
                ctx.lineTo(x, y + r);
                ctx.quadraticCurveTo(x, y, x + r, y);
                ctx.stroke();
            }
            rect(width * 0.06, height * 0.06, width * 0.56, height * 0.56);
            rect(width * 0.34, height * 0.34, width * 0.6, height * 0.6);
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: icon.requestPaint()
        onExited: icon.requestPaint()
        onClicked: root.copy(root.text)
    }
}
