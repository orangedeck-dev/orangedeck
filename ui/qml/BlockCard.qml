// A block tile, the same for projected and confirmed blocks.
//
// No drop shadow or back plate: a block is a record, not an object, and
// in a row a shadow looks like dirt between the tiles. The gloss is
// enough for the glass look: light edge at the top, dark at the bottom,
// a diagonal light streak across.
//
// Only imports QtQuick, so it also runs on Android.
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    property color tone: "#7b5cd6"
    property bool highlighted: false
    property bool hovered: false
    property real cornerRadius: 4
    // The front face; content is parented here
    default property alias content: face.data

    readonly property color base: hovered ? Qt.lighter(tone, 1.2)
                                          : (highlighted ? Qt.lighter(tone, 1.08) : tone)

    // --- Face -------------------------------------------------------------
    Rectangle {
        id: face

        anchors.fill: parent
        radius: root.cornerRadius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.lighter(root.base, 1.18)
            }

            GradientStop {
                position: 0.55
                color: root.base
            }

            GradientStop {
                position: 1
                color: Qt.darker(root.base, 1.4)
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    // --- Gloss: brighten the upper half, fading out diagonally ------------
    // This is what makes it look like glass. `clip` keeps it inside the
    // rounded shape; without it the gloss sticks out over the corners.
    Item {
        anchors.fill: face
        clip: true

        Rectangle {
            width: parent.width * 1.6
            height: parent.height * 0.62
            x: -parent.width * 0.3
            y: -parent.height * 0.1
            rotation: -7
            transformOrigin: Item.Center
            opacity: 0.5

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.22)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
        }
    }

    // --- Edges: light at the top, dark at the bottom ----------------------
    Rectangle {
        anchors.fill: face
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    Rectangle {
        anchors.left: face.left
        anchors.right: face.right
        anchors.top: face.top
        anchors.margins: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.3)
    }
}
