import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server, only while the user has Omarchy's own switched
// off. Every arrival lands in `entries` (newest first) and in the glance queue.
Item {
    id: root

    property bool active: false
    property int keep: 20

    property var entries: []
    property bool dnd: false

    signal arrived(var entry)
    signal historyWanted

    readonly property int unread: root.entries.filter(e => !e.seen).length

    function add(n: Notification): void {
        n.tracked = true;
        const entry = {
            key: `n${n.id}`,
            id: n.id,
            note: n,
            app: n.appName || "",
            icon: n.appIcon || "",
            image: n.image || "",
            summary: n.summary || "",
            body: n.body || "",
            critical: n.urgency === NotificationUrgency.Critical,
            timeout: n.expireTimeout > 0 ? n.expireTimeout * 1000 : 0,
            seen: false,
            at: Date.now()
        };
        n.closed.connect(() => root.drop(entry.key, false));
        root.entries = [entry, ...root.entries.filter(e => e.id !== n.id)].slice(0, root.keep);
        if (!root.dnd || entry.critical)
            root.arrived(entry);
    }

    function drop(key: string, dismiss: bool): void {
        const entry = root.entries.find(e => e.key === key);
        if (!entry)
            return;
        root.entries = root.entries.filter(e => e.key !== key);
        if (dismiss)
            entry.note?.dismiss();
    }

    function invoke(key: string): void {
        const entry = root.entries.find(e => e.key === key);
        const action = entry?.note?.actions?.find(a => a.identifier === "default") ?? entry?.note?.actions?.[0];
        if (action)
            action.invoke();
        root.drop(key, !action);
    }

    function markSeen(): void {
        if (root.entries.some(e => !e.seen))
            root.entries = root.entries.map(e => Object.assign({}, e, {
                seen: true
            }));
    }

    function clear(): void {
        for (const e of root.entries)
            e.note?.dismiss();
        root.entries = [];
    }

    LazyLoader {
        active: root.active

        NotificationServer {
            keepOnReload: false
            bodySupported: true
            bodyMarkupSupported: false
            actionsSupported: true
            imageSupported: true
            persistenceSupported: true

            onNotification: n => root.add(n)
        }
    }

    // The same target and method names as Omarchy's built-in daemon, so the
    // bar's do-not-disturb toggle and existing keybinds keep working.
    IpcHandler {
        target: "notifications"
        enabled: root.active

        function dndState(): string {
            return root.dnd ? "on" : "off";
        }
        function toggleDnd(): string {
            root.dnd = !root.dnd;
            return root.dnd ? "on" : "off";
        }
        function setDnd(value: string): string {
            root.dnd = value === "on" || value === "true" || value === "1";
            return root.dnd ? "on" : "off";
        }
        function isDnd(): string {
            return root.dnd ? "true" : "false";
        }
        function showHistory(): string {
            root.historyWanted();
            return "ok";
        }
        function clear(): string {
            root.clear();
            return "ok";
        }
        function dismissAll(): string {
            root.clear();
            return "ok";
        }
        function dismissOne(): string {
            if (root.entries.length > 0)
                root.drop(root.entries[0].key, true);
            return "ok";
        }
        function invokeLast(): string {
            if (root.entries.length > 0)
                root.invoke(root.entries[0].key);
            return "ok";
        }
        function dismiss(summary: string): string {
            for (const e of root.entries.filter(e => e.summary === summary))
                root.drop(e.key, true);
            return "ok";
        }
        function ping(): string {
            return "ok";
        }
    }
}
