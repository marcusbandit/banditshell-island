import QtQuick

// One sung line. Each word lights up from left to right as it is sung, timed
// to the syllable when the source has word timing.
Flow {
    id: root

    property var theme
    property var line
    property var fillOf: w => 0
    property bool live: true
    property int size: theme?.large ?? 14

    spacing: Math.round(root.size * 0.3)

    Repeater {
        model: root.line?.lead ?? []

        Item {
            id: word

            required property var modelData

            readonly property real lit: root.live ? root.fillOf(modelData) : 0

            implicitWidth: base.implicitWidth
            implicitHeight: base.implicitHeight

            Text {
                id: base

                text: word.modelData.text
                color: root.live ? root.theme.dim : Qt.alpha(root.theme.dim, 0.7)
                font.family: root.theme.font
                font.pixelSize: root.size
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
            }

            Item {
                width: base.width * word.lit
                height: base.height
                clip: true
                visible: word.lit > 0

                Text {
                    text: word.modelData.text
                    color: root.theme.text
                    font: base.font
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
