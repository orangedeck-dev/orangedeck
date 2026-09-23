// Switcher between the views. A separate component so the window and the
// dashboard tab share it. Only `import QtQuick`, so it also runs on Android.
import QtQuick

pragma ComponentBehavior: Bound

Row {
    id: root

    property var labels: []
    property int current: 0
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real fontSize: 12

    signal picked(int index)

    spacing: fontSize * 1.4

    Repeater {
        model: root.labels

        Item {
            id: tab

            required property var modelData
            required property int index

            readonly property bool active: root.current === tab.index

            width: label.width
            height: label.height + root.fontSize * 0.55
            // The touch area is taller than the text, otherwise it is hard
            // to hit with a finger.
            implicitHeight: height

            Text {
                id: label

                anchors.top: parent.top
                text: tab.modelData
                color: tab.active ? root.textColor
                                  : (touch.containsMouse ? root.textColor : root.dimColor)
                font.pixelSize: root.fontSize
                font.bold: tab.active

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: tab.active ? label.width : 0
                height: Math.max(2, root.fontSize * 0.14)
                radius: height / 2
                color: root.accentColor

                Behavior on width {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }

            MouseArea {
                id: touch

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(tab.index)
            }
        }
    }
}
