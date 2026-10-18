import QtQuick
import Quickshell
import Quickshell.Io

// Countdown timers started over IPC. A finished timer rings once and stays in
// the island until it is looked at.
Item {
    id: root

    property var running: []
    property var rung: []
    property real now: Date.now()

    signal finished(var timer)

    // "10m", "90s", "1h30m", "25" (minutes). Anything after the first space
    // is the label.
    function parse(spec: string): var {
        const text = String(spec ?? "").trim();
        const space = text.indexOf(" ");
        const span = space < 0 ? text : text.slice(0, space);
        const label = space < 0 ? "" : text.slice(space + 1).trim();
        if (/^\d+(\.\d+)?$/.test(span))
            return { ms: Number(span) * 60000, label: label };
        let ms = 0;
        const re = /(\d+(?:\.\d+)?)\s*(h|m|s)/g;
        let m, used = "";
        while ((m = re.exec(span)) !== null) {
            ms += Number(m[1]) * (m[2] === "h" ? 3600000 : m[2] === "m" ? 60000 : 1000);
            used += m[0];
        }
        return ms > 0 && used.length === span.replace(/\s/g, "").length ? { ms: ms, label: label } : null;
    }

    function start(spec: string): string {
        const p = root.parse(spec);
        if (!p)
            return "usage: timer 10m [label] (h, m, s; a bare number is minutes)";
        const t = {
            key: `t${Date.now()}`,
            label: p.label,
            total: p.ms,
            ends: Date.now() + p.ms
        };
        root.running = [...root.running, t].sort((a, b) => a.ends - b.ends);
        return `timer set for ${root.spoken(p.ms)}`;
    }

    function cancel(key: string): void {
        root.running = root.running.filter(t => t.key !== key);
        root.rung = root.rung.filter(t => t.key !== key);
    }

    function cancelAll(): void {
        root.running = [];
        root.rung = [];
    }

    function remainingOf(t: var): real {
        if (!t)
            return 0;
        return Math.max(0, t.ends - root.now);
    }

    function clock(ms: real): string {
        const s = Math.ceil(ms / 1000);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        const r = s % 60;
        const two = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${two(m)}:${two(r)}` : `${m}:${two(r)}`;
    }

    function spoken(ms: real): string {
        const s = Math.round(ms / 1000);
        const parts = [];
        if (s >= 3600)
            parts.push(`${Math.floor(s / 3600)} h`);
        if (s % 3600 >= 60)
            parts.push(`${Math.floor(s % 3600 / 60)} min`);
        if (s % 60 > 0)
            parts.push(`${s % 60} s`);
        return parts.join(" ") || "0 s";
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running.length > 0
        onTriggered: {
            root.now = Date.now();
            const done = root.running.filter(t => t.ends <= root.now);
            if (done.length === 0)
                return;
            root.running = root.running.filter(t => t.ends > root.now);
            root.rung = [...root.rung, ...done];
            for (const t of done)
                root.finished(t);
            chime.running = true;
        }
    }

    Process {
        id: chime

        command: ["sh", "-c", "for f in /usr/share/sounds/freedesktop/stereo/complete.oga /usr/share/sounds/freedesktop/stereo/bell.oga; do [ -f \"$f\" ] && exec pw-play \"$f\"; done; exit 0"]
    }
}
