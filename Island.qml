pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "components"
import "services"
import "rows"

// The banditshell island for Omarchy. Nothing sits on screen at rest. When
// something happens, a pill melts out of the bottom of the bar, says it, and
// goes back up. Anything else going on waits beside it as a bud that pinched
// off the pill. Hover it, or bind `omarchy-shell shell toggle banditshell.island`,
// to open everything at once.
Item {
    id: root

    property var shell: null
    property var manifest: null
    property string omarchyPath: ""

    readonly property string pluginId: root.manifest?.id ?? "banditshell.island"
    readonly property string dir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")

    // The panel contract: Omarchy's toggle, summon and hide land here.
    property bool opened: false

    function open(payload: var): void {
        root.opened = true;
        notices.markSeen();
    }

    function close(): void {
        root.opened = false;
    }

    Theme {
        id: theme
    }

    Settings {
        id: settings

        pluginId: root.pluginId
    }

    Notices {
        id: notices

        active: settings.notifications
        keep: settings.get("history", 20)
        onArrived: entry => root.glanceAt({
                kind: "notification",
                key: entry.key,
                entry: entry,
                ms: entry.critical ? 0 : Math.max(root.glanceMs, entry.timeout || 0)
            })
        onHistoryWanted: root.open(null)
        onEntriesChanged: root.prune()
    }

    Music {
        id: music

        ticking: root.mode === "open" || root.mode === "sing"
        onStarted: if (settings.get("nowPlaying", true))
            root.glanceAt({
                kind: "music",
                key: "music",
                ms: root.glanceMs
            })
    }

    Lyrics {
        id: lyrics

        music: music
        wanted: settings.get("lyrics", true)
        pluginDir: root.dir
    }

    Timers {
        id: timers

        onFinished: t => root.glanceAt({
                kind: "timer",
                key: t.key,
                timer: t,
                ms: 0
            })
        onRungChanged: root.prune()
    }

    // Glances: one at a time, newest last in the queue. A glance with ms 0
    // stays until it is pressed (critical notifications, a timer that rang).
    readonly property int glanceMs: settings.get("glanceSeconds", 4) * 1000

    property var glance: null
    property var queue: []

    function glanceAt(g: var): void {
        if (root.glance?.key === g.key) {
            root.show(g);
            return;
        }
        if (!root.glance) {
            root.show(g);
            return;
        }
        root.queue = [...root.queue.filter(q => q.key !== g.key), g];
    }

    function show(g: var): void {
        root.glance = g;
        glanceTimer.stop();
        if (g.ms > 0) {
            glanceTimer.interval = g.ms;
            glanceTimer.start();
        }
    }

    function nextGlance(): void {
        const n = root.queue[0] ?? null;
        root.queue = root.queue.slice(1);
        if (n)
            root.show(n);
        else
            root.glance = null;
    }

    function alive(g: var): bool {
        if (!g)
            return false;
        if (g.kind === "notification")
            return notices.entries.some(e => e.key === g.key);
        if (g.kind === "timer")
            return timers.rung.some(t => t.key === g.key);
        return g.kind !== "music" || music.hasTrack;
    }

    function prune(): void {
        root.queue = root.queue.filter(q => root.alive(q));
        if (root.glance && !root.alive(root.glance))
            root.nextGlance();
    }

    Timer {
        id: glanceTimer

        onTriggered: root.attending ? restart() : root.nextGlance()
    }

    // What the island is doing right now.
    property bool singAlong: false
    property bool hoverOpen: false

    readonly property bool expanded: root.opened || root.hoverOpen
    readonly property bool singing: root.singAlong && music.playing && !music.inFront && lyrics.lines.length > 0
    readonly property string mode: root.expanded ? "open" : root.glance ? "glance" : timers.running.length > 0 ? "compact" : root.singing ? "sing" : "hidden"
    readonly property bool attending: root.hoverOpen || hover.hovered

    onModeChanged: if (root.mode === "open")
        notices.markSeen()

    // The bar this melts out of. Without Omarchy's bar on top the island
    // melts out of the screen's top edge instead.
    readonly property string screenName: win.screen?.name ?? ""
    readonly property real edge: {
        const bar = root.shell?.bar;
        if (!bar || bar.barHidden || bar.position !== "top")
            return 0;
        return bar.barSizeFor ? bar.barSizeFor(root.screenName) : (bar.barSize ?? 0);
    }

    readonly property var targetScreen: {
        const screens = Quickshell.screens.filter(s => s.name !== "" && s.name !== "FALLBACK");
        if (screens.length === 0)
            return null;
        let wanted = settings.get("monitor", "focused");
        if (wanted === "focused")
            wanted = Hyprland.focusedMonitor?.name ?? "";
        return screens.find(s => s.name === wanted) ?? screens[0];
    }

    // Sizes for each mode, read off the content that mode shows.
    readonly property real padX: theme.pad
    readonly property real padY: root.mode === "open" ? 14 : root.mode === "compact" ? 6 : 7
    readonly property real wideW: settings.get("width", 440)

    readonly property real glanceW: glanceView.item?.implicitWidth ?? 0
    readonly property real glanceH: glanceView.item?.implicitHeight ?? 36

    readonly property real targetW: {
        switch (root.mode) {
        case "open":
            return root.wideW;
        case "glance":
            return Math.max(220, Math.min(420, root.glanceW + root.padX * 2));
        case "compact":
            return compactView.implicitWidth + root.padX * 2 + 4;
        case "sing":
            return Math.max(200, Math.min(620, singMetrics.advanceWidth + root.padX * 2 + 16));
        default:
            return 140;
        }
    }

    readonly property real targetH: {
        switch (root.mode) {
        case "open":
            return Math.min(root.fieldHeight - root.edge - theme.gap * 3, openView.implicitHeight + root.padY * 2);
        case "glance":
            return root.glanceH + root.padY * 2;
        case "compact":
            return 22 + root.padY * 2;
        case "sing":
            return Math.round(theme.large * 1.5) + root.padY * 2;
        default:
            return 30;
        }
    }

    Follow {
        id: fw

        target: root.targetW
        speed: 13
        still: theme.still
    }

    Follow {
        id: fh

        target: root.targetH
        speed: 13
        still: theme.still
    }

    Follow {
        id: presence

        target: root.mode === "hidden" ? 0 : 1
        speed: 10
        epsilon: 0.002
        still: theme.still
    }

    // The neck: thick while the pill drops, thinning to nothing once it
    // hangs on its own, and back again as it is pulled up.
    Follow {
        id: settle

        target: root.mode !== "hidden" && presence.value > 0.85 ? 1 : 0
        speed: target > value ? 4.5 : 24
        epsilon: 0.002
        still: theme.still
    }

    readonly property real fieldWidth: 1100
    readonly property real fieldHeight: Math.ceil(root.edge + 560)
    readonly property real centre: root.fieldWidth / 2

    readonly property real pillW: fw.value
    readonly property real pillH: fh.value
    readonly property real pillX: root.centre - root.pillW / 2
    readonly property real tuckedY: root.edge - root.pillH - 2
    readonly property real dropY: root.edge + theme.gap
    readonly property real pillY: root.tuckedY + (root.dropY - root.tuckedY) * presence.value
    readonly property real squared: Math.max(0, Math.min(1, (root.pillH - 34) / 34))
    readonly property real pillRadius: root.pillH / 2 + (theme.corner - root.pillH / 2) * root.squared
    readonly property real pillPower: 2 + (theme.power - 2) * root.squared
    readonly property real neck: presence.value > 0.001 ? theme.melt * (1 - settle.value) : 0

    // Buds: what else is going on while the pill is busy with one thing.
    readonly property var asides: {
        if (root.mode === "open" || root.mode === "hidden")
            return [];
        const out = [];
        if (music.playing && root.glance?.kind !== "music" && root.mode !== "sing")
            out.push("music");
        if (timers.running.length > 0 && root.mode !== "compact")
            out.push("timer");
        if (root.queue.length > 0)
            out.push("queue");
        return out;
    }

    readonly property real budSize: 26

    component BudOf: Bud {
        asides: root.asides
        shown: presence.value > 0.6
        still: theme.still
        pillX: root.pillX
        pillY: root.pillY
        pillW: root.pillW
        pillH: root.pillH
        size: root.budSize
        gap: theme.gap
        melt: theme.melt
    }

    BudOf {
        id: budMusic

        key: "music"
    }

    BudOf {
        id: budTimer

        key: "timer"
    }

    BudOf {
        id: budQueue

        key: "queue"
    }

    readonly property var budList: [budMusic, budTimer, budQueue]

    PanelWindow {
        id: win

        screen: root.targetScreen
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: root.fieldHeight
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "banditshell-island"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: hit

            Region {
                item: budHit
                intersection: Intersection.Combine
            }
        }

        Item {
            id: field

            width: root.fieldWidth
            height: root.fieldHeight
            anchors.horizontalCenter: parent.horizontalCenter

            // Input: the pill and its neck while it is out, a thin strip under
            // the bar's middle while it is not.
            Item {
                id: hit

                readonly property bool out: presence.value > 0.5
                x: hit.out ? root.pillX : root.centre - 110
                y: root.edge
                width: hit.out ? root.pillW : 220
                height: hit.out ? Math.max(4, root.pillY + root.pillH - root.edge) : 4

                HoverHandler {
                    id: hover

                    onHoveredChanged: {
                        if (hovered) {
                            leave.stop();
                            dwell.interval = root.mode === "hidden" ? 260 : 160;
                            dwell.restart();
                        } else {
                            dwell.stop();
                            leave.restart();
                        }
                    }
                }
            }

            Item {
                id: budHit

                readonly property rect span: {
                    let r = Qt.rect(0, 0, 0, 0);
                    for (const b of [budMusic.shape, budTimer.shape, budQueue.shape])
                        if (b.width > 0)
                            r = r.width > 0 ? Qt.rect(Math.min(r.x, b.x), Math.min(r.y, b.y), Math.max(r.x + r.width, b.x + b.width) - Math.min(r.x, b.x), Math.max(r.y + r.height, b.y + b.height) - Math.min(r.y, b.y)) : b;
                    return r;
                }
                x: span.x
                y: span.y
                width: span.width
                height: span.height

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open(null)
                }
            }

            Timer {
                id: dwell

                onTriggered: root.hoverOpen = true
            }

            Timer {
                id: leave

                interval: 450
                onTriggered: root.hoverOpen = false
            }

            IslandField {
                id: shape

                anchors.fill: parent
                visible: presence.value > 0.001

                pillRect: Qt.rect(root.pillX, root.pillY, root.pillW, root.pillH)
                pillRadius: root.pillRadius
                power: root.pillPower
                budRects: [budMusic.shape, budTimer.shape, budQueue.shape]
                budReaches: [budMusic.reach, budTimer.reach, budQueue.reach]
                edge: root.edge
                neck: root.neck
                colour: theme.body
                bandColour: theme.body
                smoothing: theme.melt / 2
                source: inkSource
            }

            ShaderEffectSource {
                id: inkSource

                sourceItem: ink
                hideSource: true
                live: true
                visible: false
            }

            // Everything drawn inside the island. The field clips it to the
            // same shape, neck and buds included.
            Item {
                id: ink

                width: root.fieldWidth
                height: root.fieldHeight

                Item {
                    id: stage

                    x: root.pillX
                    y: root.pillY
                    width: root.pillW
                    height: root.pillH
                    clip: true
                    opacity: Math.max(0, Math.min(1, (presence.value - 0.55) / 0.35))

                    Item {
                        id: glanceBox

                        width: root.mode === "glance" ? root.targetW - root.padX * 2 : Math.max(0, root.glanceW)
                        height: root.glanceH
                        x: (stage.width - width) / 2
                        y: root.padY
                        opacity: root.mode === "glance" ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }

                        Loader {
                            id: glanceView

                            anchors.fill: parent
                            readonly property var g: root.glance
                            sourceComponent: g?.kind === "notification" ? noticeGlance : g?.kind === "music" ? musicGlance : g?.kind === "timer" ? timerGlance : null
                        }
                    }

                    Item {
                        width: compactView.implicitWidth
                        height: 22
                        x: (stage.width - width) / 2
                        y: root.padY
                        opacity: root.mode === "compact" ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }

                        TimerRow {
                            id: compactView

                            theme: theme
                            timers: timers
                            timer: timers.running[0] ?? null
                            compact: true
                            onCleared: root.open(null)
                        }
                    }

                    Item {
                        width: Math.max(0, root.targetW - root.padX * 2 - 16)
                        height: stage.height
                        x: (stage.width - width) / 2
                        opacity: root.mode === "sing" ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }

                        TextMetrics {
                            id: singMetrics

                            font.family: theme.font
                            font.pixelSize: theme.large
                            font.weight: Font.DemiBold
                            text: (lyrics.current && !lyrics.current.gap ? lyrics.current.text : lyrics.next?.text) ?? ""
                        }

                        LyricLine {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            theme: theme
                            line: lyrics.current && !lyrics.current.gap ? lyrics.current : lyrics.next
                            live: !!lyrics.current && !lyrics.current.gap
                            fillOf: w => lyrics.fill(w)
                            size: theme.large
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.open(null)
                        }
                    }

                    Item {
                        width: root.wideW - root.padX * 2
                        height: openView.implicitHeight
                        x: (stage.width - width) / 2
                        y: root.padY
                        opacity: root.mode === "open" ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                            }
                        }

                        Column {
                            id: openView

                            width: parent.width
                            spacing: 12

                            MusicCard {
                                width: parent.width
                                visible: music.hasTrack
                                theme: theme
                                music: music
                                lyrics: lyrics
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: theme.track
                                visible: music.hasTrack && (timerList.count > 0 || notices.entries.length > 0 || !notices.active)
                            }

                            Column {
                                width: parent.width
                                spacing: 4
                                visible: timerList.count > 0

                                Repeater {
                                    id: timerList

                                    model: [...timers.rung.map(t => ({
                                                t: t,
                                                rung: true
                                            })), ...timers.running.map(t => ({
                                                t: t,
                                                rung: false
                                            }))]

                                    TimerRow {
                                        required property var modelData

                                        width: parent.width
                                        theme: theme
                                        timers: timers
                                        timer: modelData.t
                                        rung: modelData.rung
                                        onCleared: {
                                            timers.cancel(modelData.t.key);
                                            root.prune();
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 16
                                visible: notices.entries.length > 0

                                Line {
                                    theme: theme
                                    anchors.left: parent.left
                                    text: notices.dnd ? "Notifications, do not disturb is on" : "Notifications"
                                    color: theme.dim
                                    font.pixelSize: theme.small
                                }

                                Line {
                                    theme: theme
                                    anchors.right: parent.right
                                    text: "Clear all"
                                    color: clearArea.containsMouse ? theme.text : theme.dim
                                    font.pixelSize: theme.small

                                    MouseArea {
                                        id: clearArea

                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notices.clear()
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 8
                                visible: notices.entries.length > 0

                                Repeater {
                                    model: notices.entries.slice(0, settings.get("shown", 4))

                                    NoticeRow {
                                        required property var modelData

                                        width: parent.width
                                        theme: theme
                                        entry: modelData
                                        wide: true
                                        onInvoked: notices.invoke(modelData.key)
                                        onDismissed: notices.drop(modelData.key, true)
                                    }
                                }
                            }

                            Line {
                                theme: theme
                                width: parent.width
                                visible: !music.hasTrack && timerList.count === 0 && notices.entries.length === 0
                                text: "Nothing going on"
                                color: theme.dim
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                width: parent.width
                                visible: !notices.active
                                text: "Notifications show up here once Omarchy's own are off: omarchy plugin disable omarchy.notifications"
                                color: Qt.alpha(theme.dim, 0.8)
                                font.family: theme.font
                                font.pixelSize: theme.small
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }

                // What each bud holds.
                Repeater {
                    model: root.budList

                    Item {
                        id: budInk

                        required property var modelData

                        readonly property rect r: budInk.modelData.shape
                        readonly property string kind: budInk.modelData.key
                        x: r.x
                        y: r.y
                        width: root.budSize
                        height: root.budSize
                        visible: r.width > 0
                        opacity: Math.min(1, budInk.modelData.amount * 1.6)

                        Bars {
                            anchors.centerIn: parent
                            visible: budInk.kind === "music"
                            theme: theme
                            playing: music.playing
                            width: 12
                            height: 10
                        }

                        Canvas {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            visible: budInk.kind === "timer"
                            property real share: {
                                const t = timers.running[0];
                                return t ? timers.remainingOf(t) / t.total : 0;
                            }
                            onShareChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                c.lineWidth = 2;
                                c.strokeStyle = theme.track;
                                c.beginPath();
                                c.arc(7, 7, 5.5, 0, Math.PI * 2);
                                c.stroke();
                                c.strokeStyle = theme.accent;
                                c.lineCap = "round";
                                c.beginPath();
                                c.arc(7, 7, 5.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * share);
                                c.stroke();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: budInk.kind === "queue"
                            text: String(root.queue.length)
                            color: theme.text
                            font.family: theme.font
                            font.pixelSize: theme.small
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    Component {
        id: noticeGlance

        NoticeRow {
            theme: theme
            entry: root.glance?.entry ?? null
            onInvoked: notices.invoke(root.glance.key)
            onDismissed: notices.drop(root.glance.key, true)
        }
    }

    Component {
        id: musicGlance

        MusicRow {
            theme: theme
            music: music
            onPressed: root.open(null)
        }
    }

    Component {
        id: timerGlance

        TimerRow {
            theme: theme
            timers: timers
            timer: root.glance?.timer ?? null
            rung: true
            onCleared: {
                timers.cancel(root.glance.key);
                root.prune();
            }
        }
    }

    IpcHandler {
        target: "banditshell-island"

        function toggle(): string {
            root.opened = !root.opened;
            return root.opened ? "open" : "closed";
        }

        function show(): string {
            root.open(null);
            return "open";
        }

        function hide(): string {
            root.close();
            return "closed";
        }

        function timer(spec: string): string {
            return timers.start(spec);
        }

        function cancelTimers(): string {
            timers.cancelAll();
            root.prune();
            return "ok";
        }

        function sing(): string {
            root.singAlong = !root.singAlong;
            return root.singAlong ? "singing along" : "quiet";
        }

        function state(): string {
            return JSON.stringify({
                mode: root.mode,
                edge: root.edge,
                notifications: notices.active,
                entries: notices.entries.length,
                queue: root.queue.length,
                playing: music.playing,
                track: music.title,
                lyrics: lyrics.source,
                wordTimed: lyrics.wordTimed,
                timers: timers.running.length,
                position: music.position,
                line: lyrics.current?.text ?? "",
                gap: lyrics.current?.gap ?? false,
                fill: lyrics.current?.lead?.length ? lyrics.fill(lyrics.current.lead[0]) : -1,
                asides: root.asides,
                buds: root.budList.map(b => b.amount),
                spotifyId: lyrics.spotifyId,
                trackId: music.trackId,
                trace: lyrics.trace
            });
        }
    }
}
