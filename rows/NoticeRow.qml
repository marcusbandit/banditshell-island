import QtQuick

// A notification: who sent it, what it says. Press runs its default action,
// a right press dismisses it.
Item {
    id: root

    property var theme
    property var entry
    property bool wide: false

    signal invoked
    signal dismissed

    implicitHeight: 40
    implicitWidth: Math.min(400, 40 + Math.max(head.implicitWidth, title.implicitWidth + (words.text ? 8 + words.implicitWidth : 0)))

    readonly property string picture: root.entry?.image || (root.entry?.icon?.startsWith("/") || root.entry?.icon?.startsWith("file:") ? root.entry.icon : root.entry?.icon ? `image://icon/${root.entry.icon}` : "")

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 10
        color: area.containsMouse && root.wide ? root.theme.hover : "transparent"
    }

    Art {
        id: art

        theme: root.theme
        width: 30
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        source: root.picture
        glyph: (root.entry?.app || root.entry?.summary || "?").slice(0, 1).toUpperCase()
        radius: 8
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Line {
            id: head

            theme: root.theme
            width: parent.width
            text: root.entry?.app || "Notification"
            color: root.entry?.critical ? root.theme.urgent : root.theme.dim
            font.pixelSize: root.theme.small
        }

        Row {
            width: parent.width
            spacing: 8

            Line {
                id: title

                theme: root.theme
                width: Math.min(implicitWidth, parent.width)
                text: root.entry?.summary ?? ""
                font.weight: Font.DemiBold
            }

            Line {
                id: words

                theme: root.theme
                width: Math.max(0, parent.width - title.width - parent.spacing)
                visible: text !== "" && width > 20
                text: (root.entry?.body ?? "").replace(/\s+/g, " ").trim()
                color: root.theme.dim
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? root.dismissed() : root.invoked()
    }
}
