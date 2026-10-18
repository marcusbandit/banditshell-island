import QtQuick
import Quickshell
import Quickshell.Io
import "lyrics.js" as Parse

// Word-timed lyrics for the track `music` is playing. Spicy Lyrics' own cache
// comes first, because it carries a time for every word; lrclib.net fills in
// line-timed lyrics when Spicy Lyrics has nothing for the track.
Item {
    id: root

    property var music: null
    property bool wanted: true
    property string pluginDir: ""

    readonly property string client: "banditshell.island (https://github.com/marcusbandit/banditshell-island)"

    property var lines: []
    property string source: ""
    property bool wordTimed: false

    readonly property string key: root.wanted && root.music?.hasTrack ? [root.music.artist, root.music.title, root.music.album].join("\n") : ""
    readonly property string spotifyId: {
        const m = /(?:\/com\/spotify\/track\/|spotify:track:)([A-Za-z0-9]+)$/.exec(root.music?.trackId ?? "");
        return m ? m[1] : "";
    }

    property string asked: ""
    property string trace: ""
    property int spicyTries: 0

    readonly property int index: root.lines.length > 0 ? Parse.lineAt(root.lines, root.music?.position ?? 0) : -1
    readonly property var current: root.index >= 0 ? root.lines[root.index] : null
    readonly property var next: {
        for (let i = root.index + 1; i < root.lines.length; i++)
            if (!root.lines[i].gap)
                return root.lines[i];
        return null;
    }

    function fill(word: var): real {
        return Parse.wordFill(word, root.music?.position ?? 0);
    }

    onKeyChanged: restart.restart()

    // Spotify can name the track before it hands over the track id. When the
    // id lands after lrclib already answered, Spicy Lyrics still gets asked.
    onSpotifyIdChanged: if (root.spotifyId && root.key && root.key === root.asked && root.source !== "Spicy Lyrics" && !spicy.running)
        root.askSpicy()

    Timer {
        id: restart

        interval: 200
        onTriggered: {
            if (root.key === root.asked)
                return;
            root.asked = root.key;
            root.lines = [];
            root.source = "";
            root.wordTimed = false;
            root.spicyTries = 0;
            if (!root.key)
                return;
            if (root.spotifyId)
                root.askSpicy();
            else
                root.askLrclib();
        }
    }

    function askSpicy(): void {
        spicy.key = root.key;
        spicy.command = ["python3", root.pluginDir + "/services/spicy-lyrics.py", root.spotifyId];
        spicy.running = true;
    }

    Process {
        id: spicy

        property string key: ""

        onExited: (code, status) => root.trace = `${spicy.command.join(" ")} -> ${code}`

        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.trace += ` err: ${text.trim().slice(0, 200)}`
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (spicy.key !== root.key)
                    return;
                let content = null;
                try {
                    content = text.trim() ? JSON.parse(text) : null;
                } catch (e) {
                    content = null;
                }
                const model = content ? Parse.fromSpicy(content, root.music?.length ?? 0) : null;
                if (model?.synced) {
                    root.lines = model.synced;
                    root.source = "Spicy Lyrics";
                    root.wordTimed = model.synced.some(l => l.timed);
                    return;
                }
                // Spicy Lyrics writes its cache a moment after the song starts.
                if (!content && root.spicyTries < 2) {
                    root.spicyTries++;
                    spicyLater.restart();
                    return;
                }
                root.askLrclib();
            }
        }
    }

    Timer {
        id: spicyLater

        interval: 1500
        onTriggered: root.askSpicy()
    }

    function request(path: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {
                body = null;
            }
            done(body);
        };
        xhr.open("GET", "https://lrclib.net/api/" + path);
        xhr.setRequestHeader("Lrclib-Client", root.client);
        xhr.send();
    }

    function take(record: var, key: string): bool {
        if (key !== root.key || !record?.syncedLyrics)
            return false;
        const lines = Parse.fromLrc(Parse.parseLrc(record.syncedLyrics), root.music?.length || record.duration || 0);
        if (!lines.some(l => !l.gap))
            return false;
        root.lines = lines;
        root.source = "lrclib.net";
        root.wordTimed = lines.some(l => l.timed);
        return true;
    }

    function askLrclib(): void {
        const key = root.key;
        const wanted = {
            title: root.music.title,
            artist: root.music.artist,
            album: root.music.album,
            length: root.music.length
        };
        root.request(`get?${Parse.query({
            track_name: Parse.cleanTitle(wanted.title),
            artist_name: Parse.firstArtist(wanted.artist),
            album_name: wanted.album,
            duration: wanted.length > 0 ? Math.round(wanted.length) : ""
        })}`, body => {
            if (root.take(body, key))
                return;
            root.request(`search?${Parse.query({
                track_name: Parse.cleanTitle(wanted.title),
                artist_name: Parse.firstArtist(wanted.artist)
            })}`, list => root.take(Parse.pick(list, wanted), key));
        });
    }
}
