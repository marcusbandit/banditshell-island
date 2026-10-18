import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server, only while the user has Omarchy's own switched
// off. It follows Omarchy's rules: do not disturb lives in the same state
// file, and only Omarchy's own toasts and critical notify-send alerts get
// through it. Everything else lands in `entries`, newest first.
Item {
    id: root

    property bool active: false
    property int keep: 20

    property var entries: []
    property bool dnd: false

    signal arrived(var entry)
    signal historyWanted

    readonly property int unread: root.entries.filter(e => !e.seen).length

    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"

    function entryOf(n: Notification, seen: bool): var {
        return {
            key: `n${n.id}`,
            id: n.id,
            note: n,
            app: n.appName || "",
            icon: n.appIcon || "",
            image: n.image || "",
            summary: n.summary || "",
            body: n.body || "",
            critical: n.urgency === NotificationUrgency.Critical,
            ephemeral: n.transient || n.appName === "notify-send" || n.appName === "omarchy-action",
            timeout: n.expireTimeout > 0 ? n.expireTimeout * 1000 : 0,
            seen: seen,
            at: Date.now()
        };
    }

    function getsThrough(n: Notification): bool {
        return n.appName === "omarchy-action" || (n.urgency === NotificationUrgency.Critical && n.appName === "notify-send");
    }

    function add(n: Notification): void {
        const loud = !root.dnd || root.getsThrough(n);
        const entry = root.entryOf(n, false);
        if (!loud && entry.ephemeral) {
            n.dismiss();
            return;
        }
        n.tracked = true;
        n.closed.connect(() => root.drop(entry.key, false));
        // A sender that updates a notification in place (progress, volume, a
        // chat thread) changes this same object instead of sending a new one.
        const refresh = () => root.update(n);
        n.summaryChanged.connect(refresh);
        n.bodyChanged.connect(refresh);
        n.imageChanged.connect(refresh);
        n.appIconChanged.connect(refresh);
        root.store(entry);
        if (loud)
            root.arrived(entry);
    }

    function update(n: Notification): void {
        const old = root.entries.find(e => e.id === n.id);
        if (!old)
            return;
        const entry = root.entryOf(n, false);
        root.store(entry);
        if (!root.dnd || root.getsThrough(n))
            root.arrived(entry);
    }

    function store(entry: var): void {
        const all = [entry, ...root.entries.filter(e => e.id !== entry.id)];
        for (const gone of all.slice(root.keep))
            gone.note?.dismiss();
        root.entries = all.slice(0, root.keep);
    }

    function drop(key: string, dismiss: bool): void {
        const entry = root.entries.find(e => e.key === key);
        if (!entry)
            return;
        root.entries = root.entries.filter(e => e.key !== key);
        if (dismiss)
            entry.note?.dismiss();
    }

    // A glance has ended. Ephemeral toasts are not kept for later.
    function glanced(key: string): void {
        const entry = root.entries.find(e => e.key === key);
        if (entry?.ephemeral)
            root.drop(key, true);
    }

    function invoke(key: string): void {
        const entry = root.entries.find(e => e.key === key);
        const action = entry?.note?.actions?.find(a => a.identifier === "default") ?? entry?.note?.actions?.[0];
        if (action)
            action.invoke();
        root.drop(key, true);
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

    function setDnd(on: bool): void {
        if (root.dnd === on)
            return;
        root.dnd = on;
        let saved = {};
        try {
            saved = JSON.parse(stateFile.text() || "{}") ?? {};
        } catch (e) {
            saved = {};
        }
        saved.dnd = on;
        stateFile.setText(JSON.stringify(saved, null, 2) + "\n");
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.dnd = !!JSON.parse(text() || "{}")?.dnd;
            } catch (e) {
                root.dnd = false;
            }
        }
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
            root.setDnd(!root.dnd);
            return root.dnd ? "on" : "off";
        }
        function setDnd(value: string): string {
            root.setDnd(value === "on" || value === "true" || value === "1");
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
