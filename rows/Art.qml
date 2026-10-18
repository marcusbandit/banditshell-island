import QtQuick

// A square picture with rounded corners: album art or a notification image,
// with a plain tile behind it while it loads or when there is none.
Item {
    id: root

    property var theme
    property string source: ""
    property string glyph: ""
    property real radius: 6

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.theme.track
        visible: img.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.theme.dim
            font.family: root.theme.font
            font.pixelSize: Math.round(parent.height * 0.42)
            font.weight: Font.DemiBold
        }
    }

    Image {
        id: img

        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    ShaderEffectSource {
        id: picture

        sourceItem: img
        hideSource: true
        visible: false
    }

    // Rounded corners without an extra module: the mask's alpha cuts the image.
    ShaderEffect {
        anchors.fill: parent
        visible: img.status === Image.Ready
        property var source: picture
        property var maskSource: ShaderEffectSource {
            sourceItem: mask
            hideSource: true
        }
        fragmentShader: Qt.resolvedUrl("../shaders/mask.frag.qsb")
    }
}
