import QtQuick

// A running timer, or one that has rung. Pressing it clears it.
Item {
    id: root

    property var theme
    property var timers
    property var timer
    property bool rung: false
    property bool compact: false

    signal cleared

    readonly property real remaining: root.rung ? 0 : root.timers.remainingOf(root.timer)
    readonly property real share: root.timer?.total > 0 ? root.remaining / root.timer.total : 0

    implicitHeight: root.compact ? 22 : 32
    implicitWidth: ring.width + 8 + label.implicitWidth + (root.compact ? 0 : 8 + count.implicitWidth)

    Canvas {
        id: ring

        width: root.compact ? 16 : 20
        height: width
        anchors.verticalCenter: parent.verticalCenter
        property real share: root.share
        property color fg: root.rung ? root.theme.urgent : root.theme.accent
        property color bg: root.theme.track
        onShareChanged: requestPaint()
        onFgChanged: requestPaint()
        onBgChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const r = width / 2 - 2;
            c.lineWidth = 2.5;
            c.strokeStyle = bg;
            c.beginPath();
            c.arc(width / 2, height / 2, r, 0, Math.PI * 2);
            c.stroke();
            c.strokeStyle = fg;
            c.lineCap = "round";
            c.beginPath();
            c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (root.rung ? 1 : share));
            c.stroke();
        }
    }

    Line {
        id: label

        theme: root.theme
        anchors.left: ring.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.rung ? (root.timer?.label ? `${root.timer.label} is done` : "Time's up") : root.compact ? root.timers.clock(root.remaining) : (root.timer?.label || `${root.timers.spoken(root.timer?.total ?? 0)} timer`)
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
        color: root.rung ? root.theme.urgent : root.theme.text
    }

    Line {
        id: count

        theme: root.theme
        visible: !root.compact
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.rung ? "clear" : root.timers.clock(root.remaining)
        color: root.rung ? root.theme.dim : root.theme.text
        font.features: {
            "tnum": 1
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cleared()
    }
}
