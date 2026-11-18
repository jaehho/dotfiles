// The dash panel's data, fetched only while a panel is open, so a closed
// panel costs nothing: `dash-live` (one JSON line per 100 ms) for the
// SYSTEM card, and `dash-data board` every 10 s for the rest (sessions,
// LLM quotas, failed units, the backup). The 1-minute
// samplers (dash-collect and the rest) are dash's own timers and keep
// running either way (issue #83).
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: feed

    // Whether any panel is open.
    property bool active: false
    // The last line, parsed; {} until one arrives.
    property var live: ({})
    // When it arrived. A feed silent for 5 s is down, and the panel then
    // shows no numbers rather than the last ones as if they were now.
    property double liveAt: 0
    readonly property bool down: !active || now - liveAt > 5000
    // The digits: the mean of each 2 s of samples, so they stay readable;
    // rings and meters take every sample. Nulls drop out of a mean, so a
    // sleeping dGPU does not read as 0. Null until the first sample.
    property var readout: null
    property var pending: []
    property double readoutAt: 0
    // The 1-min window max of each ringed or metered series (600 samples),
    // the peak-hold ghost; a series with no number in the window is null.
    property var peak: ({})
    property var series: ({})
    readonly property var meanKeys: ["cpu", "mem_used_gib", "swap_used_gib", "temp_cpu", "temp_nvme", "fan1", "fan2", "gpu_util", "gpu_temp", "gpu_mem_mib", "gpu_power_w", "disk_used_gib", "net_rx_bps", "net_tx_bps"]
    readonly property var peakKeys: ["cpu", "gpu_util", "mem_used_gib", "swap_used_gib", "net_rx_bps", "net_tx_bps"]
    // The last board, null until one arrives. dash-data caches most of
    // its sections for 30 s, so a board can be that old.
    property var board: null
    property double boardAt: 0
    // Silent for 60 s: the board's cards dim rather than read as now.
    readonly property bool boardDown: !active || now - boardAt > 60000
    property double now: Date.now()
    // When the panel last opened.
    property double openedAt: 0

    // Whole seconds from a unix time to now, by this 1 s clock, so a
    // binding that calls it ticks.
    function since(ts) {
        return Math.max(0, Math.floor(feed.now / 1000) - ts);
    }

    // "<1m", "45m", "1h20m", "2d 4h": zero units dropped.
    function dur(s) {
        if (s < 60)
            return "<1m";
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        if (d > 0)
            return h > 0 ? d + "d " + h + "h" : d + "d";
        if (h > 0)
            return m > 0 ? h + "h" + m + "m" : h + "h";
        return m + "m";
    }

    // "5m ago", "3h ago", "2d ago"; "" for no time.
    function ago(ts) {
        if (!ts)
            return "";
        const s = feed.since(ts);
        if (s < 3600)
            return Math.max(1, Math.round(s / 60)) + "m ago";
        if (s < 86400)
            return Math.round(s / 3600) + "h ago";
        return Math.round(s / 86400) + "d ago";
    }

    function mean(samples) {
        const last = samples[samples.length - 1];
        const out = {
            mem_total_gib: last.mem_total_gib,
            swap_total_gib: last.swap_total_gib,
            disk_total_gib: last.disk_total_gib,
            net_iface: last.net_iface
        };
        for (const k of feed.meanKeys) {
            let s = 0, n = 0;
            for (const d of samples) {
                const v = d[k];
                if (v !== null && v !== undefined && v === v) {
                    s += v;
                    n++;
                }
            }
            out[k] = n ? s / n : null;
        }
        return out;
    }

    function take(d) {
        feed.live = d;
        feed.liveAt = Date.now();
        feed.pending.push(d);
        if (!feed.readout || feed.liveAt - feed.readoutAt >= 2000) {
            feed.readout = feed.mean(feed.pending);
            feed.pending = [];
            feed.readoutAt = feed.liveAt;
        }
        const s = {}, p = {};
        for (const k of feed.peakKeys) {
            const run = (feed.series[k] || []).concat([d[k]]).slice(-600);
            let m = null;
            for (const v of run)
                if (v !== null && v !== undefined && (m === null || v > m))
                    m = v;
            s[k] = run;
            p[k] = m;
        }
        feed.series = s;
        feed.peak = p;
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/dash-live"]
        running: feed.active

        stdout: SplitParser {
            onRead: data => {
                try {
                    feed.take(JSON.parse(data));
                } catch (e) {}
            }
        }
    }

    Process {
        id: boardProc
        command: [Quickshell.env("HOME") + "/.local/bin/dash-data", "board"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const b = JSON.parse(this.text);
                    if (b && typeof b === "object") {
                        feed.board = b;
                        feed.boardAt = Date.now();
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 10000
        running: feed.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            boardProc.running = false;
            boardProc.running = true;
        }
    }

    Timer {
        interval: 1000
        running: feed.active
        repeat: true
        onTriggered: feed.now = Date.now()
    }

    // Each opening starts clean: no digits or ghosts from the last one.
    onActiveChanged: if (active) {
        feed.liveAt = 0;
        feed.readout = null;
        feed.pending = [];
        feed.series = {};
        feed.peak = {};
        feed.now = Date.now();
        feed.openedAt = feed.now;
    }
}
