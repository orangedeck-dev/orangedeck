// Readable background for text that would otherwise get lost in the tile
// field, especially when zoomed, where large bright areas sit right behind
// the text.
//
// Sits behind any item (`content`) and takes over its position and size
// including a margin. With `backdropSource` set, the area behind it is
// captured and blurred; otherwise the tinted fill alone keeps it readable.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property Item content: null          // what should stay readable
    property Item backdropSource: null   // what gets blurred behind it
    property real pad: 8
    property real cornerRadius: 6
    property color tint: "#0b0b12"
    property real tintAlpha: 0.72
    property bool blurred: true
    property real blurStrength: 1.0

    visible: content ? content.visible : false
    x: content ? content.x - pad : 0
    y: content ? content.y - pad : 0
    width: content ? content.width + pad * 2 : 0
    height: content ? content.height + pad * 2 : 0
    clip: true

    readonly property bool blurActive: blurred && backdropSource !== null
                                       && width > 0 && height > 0

    // Only the area behind this panel is captured, not the whole surface;
    // otherwise every panel costs a full extra render pass.
    ShaderEffectSource {
        id: shot

        anchors.fill: parent
        visible: false
        // Not `live: true`. The background does not need to be captured sixty
        // times a second: the pile itself only redraws five times (200 ms timer
        // in FeedCanvas), and once blurred a difference is hardly visible.
        // Measured with `live: true`: 14.4 % CPU versus 9.6 % without blur.
        live: false
        hideSource: false
        recursive: false
        sourceItem: root.blurActive ? root.backdropSource : null
        sourceRect: root.backdropSource
            ? Qt.rect(root.x - root.backdropSource.x,
                      root.y - root.backdropSource.y,
                      root.width, root.height)
            : Qt.rect(0, 0, 0, 0)
    }

    // The panel shape as a mask. Without it QML only clips rectangles
    // (`clip`) while the tinted fill on top is rounded, so the four corners
    // showed blurred content without tint.
    Item {
        id: maskShape

        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "white"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.blurActive
        source: shot
        blurEnabled: true
        blur: root.blurStrength
        blurMax: 24
        maskEnabled: true
        maskSource: maskShape
        // Hard but antialiased edge exactly on the rounding
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.2
    }

    // Update at the same rate as the pile.
    Timer {
        interval: 200
        repeat: true
        running: root.blurActive && root.visible
        triggeredOnStart: true
        onTriggered: shot.scheduleUpdate()
    }

    // Position or size changed: update once right away, otherwise the old
    // area stays underneath for up to 200 ms.
    onXChanged: if (blurActive) shot.scheduleUpdate()
    onYChanged: if (blurActive) shot.scheduleUpdate()
    onWidthChanged: if (blurActive) shot.scheduleUpdate()
    onHeightChanged: if (blurActive) shot.scheduleUpdate()

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintAlpha)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
    }
}
