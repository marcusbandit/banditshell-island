import QtQuick
import qs.Commons as Commons

// Every colour, size and font the island uses, taken from the active Omarchy
// theme so the island always matches the bar it melts out of.
QtObject {
    readonly property color body: Commons.Color.bar.background
    readonly property color text: Commons.Color.bar.text
    readonly property color dim: Commons.Color.muted
    readonly property color accent: Commons.Color.accent
    readonly property color urgent: Commons.Color.urgent
    readonly property color hover: Qt.alpha(Commons.Color.bar.text, 0.07)
    readonly property color track: Qt.alpha(Commons.Color.bar.text, 0.14)

    readonly property string font: Commons.Style.font.family
    readonly property int small: Commons.Style.font.caption
    readonly property int normal: Commons.Style.font.body
    readonly property int large: Commons.Style.font.title
    readonly property int huge: Commons.Style.font.heading

    readonly property bool still: Commons.Style.reduceMotion

    readonly property real gap: 8
    readonly property real pad: 12
    readonly property real melt: 34
    readonly property real power: 4
    readonly property real corner: 16
}
