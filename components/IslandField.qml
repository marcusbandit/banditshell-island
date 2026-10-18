import QtQuick

// The island's body. One signed-distance field holds the pill, up to four
// buds that pinch off beside it, and the neck that melts the pill into the
// bar above. `source` is the island's content, clipped to the same field.
ShaderEffect {
    id: root

    property rect pillRect: Qt.rect(0, 0, 0, 0)
    property var budRects: []
    property var budReaches: []
    property real pillRadius: 0

    property real sheenWidth: 0
    property color sheenColour: "transparent"

    property color colour: "black"
    property color bandColour: "black"

    property real edge: 0
    property real neck: 0

    property real smoothing: 10
    property real feather: 1
    property real power: 4

    property var source: null

    readonly property vector4d size: Qt.vector4d(width, height, 0, 0)
    readonly property vector4d pill: Qt.vector4d(pillRect.x, pillRect.y, pillRect.width, pillRect.height)
    readonly property vector4d bud0: root.slot(0)
    readonly property vector4d bud1: root.slot(1)
    readonly property vector4d bud2: root.slot(2)
    readonly property vector4d bud3: root.slot(3)
    readonly property vector4d reaches: Qt.vector4d(root.budReaches[0] ?? 0, root.budReaches[1] ?? 0, root.budReaches[2] ?? 0, root.budReaches[3] ?? 0)
    readonly property vector4d radii: Qt.vector4d(pillRadius, 0, sheenWidth, 0)

    function slot(i: int): vector4d {
        const r = root.budRects[i];
        return r ? Qt.vector4d(r.x, r.y, r.width, r.height) : Qt.vector4d(0, 0, 0, 0);
    }

    fragmentShader: Qt.resolvedUrl("../shaders/island.frag.qsb")
}
