// The dash panel's data, fetched only while a panel is open, so a closed
// panel costs nothing: `dash-data board` every 10 s (sessions, LLM
// quotas, tasks, the IBKR snapshot). dash's samplers (dash-collect,
// dash-llm, dash-mkt) keep running either way (issue #83).
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: feed

    // Whether any panel is open.
    property bool active: false
    // The last board, null until one arrives. dash-data caches most of
    // its sections for 30 s, so a board can be that old.
    property var board: null
    property double boardAt: 0
    // Silent for 60 s: the board's cards dim rather than read as now.
    readonly property bool boardDown: !active || now - boardAt > 60000
    property double now: Date.now()

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

    // Opening reads the clock at once, so boardDown is not judged on the
    // last opening's time.
    onActiveChanged: if (active)
        feed.now = Date.now()
}
