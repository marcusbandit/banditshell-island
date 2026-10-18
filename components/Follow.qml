import QtQuick

// A value that eases toward its target every frame. The exponential
// approach is banditshell's motion: fast at first, settling softly, and it
// never overshoots, so a shape can retarget mid-flight without a jump.
QtObject {
    id: root

    property real target: 0
    property real value: 0
    property real speed: 14
    property real epsilon: 0.25
    property bool still: false

    readonly property bool settled: value === target

    function snap(): void {
        root.value = root.target;
    }

    readonly property FrameAnimation driver: FrameAnimation {
        running: !root.settled

        onTriggered: {
            const d = root.target - root.value;
            root.value = root.speed <= 0 || root.still || Math.abs(d) < root.epsilon ? root.target : root.value + d * (1 - Math.exp(-root.speed * Math.min(root.driver.frameTime, 0.05)));
        }
    }
}
