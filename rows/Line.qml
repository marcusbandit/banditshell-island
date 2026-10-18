import QtQuick

// One line of text in the island's type.
Text {
    property var theme

    color: theme?.text ?? "white"
    font.family: theme?.font ?? "monospace"
    font.pixelSize: theme?.normal ?? 12
    elide: Text.ElideRight
    maximumLineCount: 1
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
