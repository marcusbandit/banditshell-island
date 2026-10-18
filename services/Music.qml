import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland

// Now playing. Follows the player that is playing, or the one that played
// last, and says when a new track starts while its window is not in front.
Item {
    id: root

    property MprisPlayer last: null

    readonly property MprisPlayer player: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? (all.includes(root.last) ? root.last : null) ?? null;
    }

    onPlayingChanged: if (root.playing)
        root.last = root.player

    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property string album: root.player?.trackAlbum ?? ""
    readonly property string art: root.player?.trackArtUrl ?? ""
    readonly property real length: root.player?.length ?? 0
    readonly property string trackId: root.pathOf(root.player?.metadata?.["mpris:trackid"])
    readonly property bool isAdvert: root.trackId.includes("/ad/") || root.trackId.startsWith("spotify:ad:")

    // D-Bus object paths reach QML wrapped in a QVariant string.
    function pathOf(value: var): string {
        if (!value)
            return "";
        const text = String(value);
        const wrapped = /QDBusObjectPath\("([^"]*)"\)/.exec(text);
        return wrapped ? wrapped[1] : text;
    }
    readonly property bool hasTrack: root.title !== "" && !root.isAdvert

    property real position: 0

    // A player whose window is focused is already in view; announcing its
    // track change in the island would only repeat what is on screen.
    readonly property bool inFront: {
        const app = String(ToplevelManager.activeToplevel?.appId ?? "").toLowerCase();
        if (!app || !root.player)
            return false;
        const names = [root.player.desktopEntry, root.player.identity].map(n => String(n ?? "").toLowerCase()).filter(n => n);
        return names.some(n => app === n || app.includes(n) || n.includes(app));
    }

    property bool ticking: false

    signal started

    function seekTo(seconds: real): void {
        if (root.player?.canSeek)
            root.player.position = seconds;
    }

    FrameAnimation {
        running: root.ticking && root.playing
        onTriggered: root.refresh()
    }

    // Nothing reads the position while the island is shut, so it is only
    // read when something that shows it opens, and every frame while it shows.
    function refresh(): void {
        if (!root.player)
            return;
        root.player.positionChanged();
        root.position = root.player.position;
    }

    onTickingChanged: if (root.ticking)
        root.refresh()
    onPlayerChanged: {
        if (root.playing)
            root.last = root.player;
        root.refresh();
    }

    property string announced: ""

    onTitleChanged: settle.restart()

    Timer {
        id: settle

        interval: 350
        onTriggered: {
            const key = `${root.artist}\n${root.title}`;
            if (!root.hasTrack || key === root.announced)
                return;
            root.announced = key;
            if (root.playing && !root.inFront)
                root.started();
        }
    }
}
