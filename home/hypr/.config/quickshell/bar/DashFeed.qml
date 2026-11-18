// The dash panel's live numbers: `dash-live` (one JSON line per 100 ms)
// runs only while a panel is open, so a closed panel costs nothing. The
// 1-minute samplers (dash-collect and the rest) are dash's own timers
// and keep running either way (issue #83).
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
    property double now: Date.now()

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/dash-live"]
        running: feed.active

        stdout: SplitParser {
            onRead: data => {
                try {
                    feed.live = JSON.parse(data);
                    feed.liveAt = Date.now();
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: feed.active
        repeat: true
        onTriggered: feed.now = Date.now()
    }

    onActiveChanged: if (active) {
        feed.liveAt = 0;
        feed.now = Date.now();
    }
}
