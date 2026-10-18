import QtQuick
import Quickshell
import Quickshell.Io

// Reads ~/.config/omarchy/shell.json and keeps it current. The island never
// writes the file: turning off Omarchy's own notifications is the user's call.
Item {
    id: root

    property string pluginId: "banditshell.island"

    readonly property string path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"

    property var config: ({})

    readonly property var entry: {
        const list = Array.isArray(root.config.plugins) ? root.config.plugins : [];
        return list.find(p => p && p.id === root.pluginId) ?? {};
    }

    // The island owns org.freedesktop.Notifications only once the user has
    // switched the built-in daemon off, so the two never fight over the name.
    readonly property bool notifications: Array.isArray(root.config.disabledPlugins) && root.config.disabledPlugins.indexOf("omarchy.notifications") !== -1 && root.get("notifications", true)

    function get(key: string, fallback: var): var {
        const v = root.entry[key];
        return v === undefined || v === null ? fallback : v;
    }

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.config = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn("banditshell.island: shell.json did not parse, keeping the last good copy");
            }
        }
        onLoadFailed: root.config = {}
    }
}
