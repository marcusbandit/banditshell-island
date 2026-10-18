import QtQuick

// One bud beside the pill. It starts inside the pill's right end and slides
// out along the row, and the melt between them shrinks as it goes, so the
// bud pinches off instead of just appearing. Going away runs it backwards.
QtObject {
    id: root

    property string key: ""
    property var asides: []
    property bool shown: false
    property bool still: false

    property real pillX: 0
    property real pillY: 0
    property real pillW: 0
    property real pillH: 0
    property real size: 26
    property real gap: 8
    property real melt: 34

    readonly property bool wanted: root.asides.indexOf(root.key) !== -1
    readonly property int wantedSlot: root.asides.indexOf(root.key)

    // A bud that is leaving keeps its place in the row while it melts back.
    property int slot: 0
    onWantedSlotChanged: if (root.wantedSlot >= 0)
        root.slot = root.wantedSlot

    property Follow out: Follow {
        target: root.wanted && root.shown ? 1 : 0
        speed: 7
        epsilon: 0.002
        still: root.still
    }

    readonly property real amount: root.out.value

    readonly property rect shape: root.amount < 0.02 ? Qt.rect(0, 0, 0, 0) : Qt.rect(root.pillX + root.pillW - root.size + (root.size + root.gap + root.slot * (root.size + root.gap)) * root.amount, root.pillY + Math.min(root.pillH, 50) / 2 - root.size / 2, root.size, root.size)

    readonly property real reach: 4 + root.melt * 0.9 * (1 - root.amount)
}
