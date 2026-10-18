import QtQuick

// The glance for a new track: cover, title, artist, and the bars.
Item {
    id: root

    property var theme
    property var music

    signal pressed

    implicitHeight: 40
    implicitWidth: Math.min(360, 40 + Math.max(title.implicitWidth, artist.implicitWidth) + 30 + root.theme.pad)

    Art {
        id: art

        theme: root.theme
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        source: root.music?.art ?? ""
        glyph: (root.music?.title ?? "?").slice(0, 1).toUpperCase()
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 10
        anchors.right: bars.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Line {
            id: title

            theme: root.theme
            width: parent.width
            text: root.music?.title ?? ""
            font.weight: Font.Medium
        }

        Line {
            id: artist

            theme: root.theme
            width: parent.width
            text: root.music?.artist ?? ""
            color: root.theme.dim
            font.pixelSize: root.theme.small
        }
    }

    Bars {
        id: bars

        theme: root.theme
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        playing: root.music?.playing ?? false
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.pressed()
    }
}
