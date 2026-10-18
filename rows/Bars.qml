import QtQuick

// Three bars that move while music plays and rest flat when it stops.
Item {
    id: root

    property var theme
    property bool playing: false
    property real t: 0

    implicitWidth: 14
    implicitHeight: 12

    FrameAnimation {
        running: root.playing && !root.theme.still
        onTriggered: root.t += frameTime
    }

    Repeater {
        model: 3

        Rectangle {
            required property int index

            width: 3
            radius: 1.5
            x: index * 5.5
            readonly property real wave: root.playing ? 0.35 + 0.65 * Math.abs(Math.sin(root.t * (5.1 + index * 1.7) + index * 1.3)) : 0.25
            height: Math.max(3, root.height * wave)
            y: root.height - height
            color: root.theme.accent
        }
    }
}
