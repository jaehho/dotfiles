// CPU, RAM and GPU as one ramp glyph each, coloured by level rather than
// by metric: fg when calm, orange when busy, red when pegged. Which is
// which is learned by position; the tip labels them in their own hues
// (CPU grey2, RAM aqua, GPU blue) with bars and details. The GPU stops
// at orange, since a long job pegs the dGPU on purpose. A pegged CPU or
// RAM pulses the glance. load.py samples; a click opens the monitor.
import QtQuick
import Quickshell
import Quickshell.Io

BarButton {
    id: load

    readonly property var colors: bar.colors
    property var sample: null

    readonly property int busy: 75
    readonly property int pegged: 90
    readonly property string ramp: "▁▂▃▄▅▆▇█"
    readonly property bool critical: sample !== null && Math.max(sample.cpu, sample.ram) >= pegged
    readonly property int gpu: sample && sample.gpus.length > 0 ? Math.max(...sample.gpus.map(g => g.busy)) : -1

    function level(percent, calm, canAlert) {
        if (canAlert && percent >= load.pegged)
            return load.colors.red;
        if (percent >= load.busy)
            return load.colors.orange;
        return calm;
    }

    function chip(percent, canAlert) {
        const glyph = load.ramp[Math.floor(Math.min(percent, 100) * (load.ramp.length - 1) / 100)];
        return `<font color="${load.level(percent, load.colors.fg, canAlert)}">${glyph}</font>`;
    }

    function bar12(percent, color) {
        const filled = Math.round(percent * 12 / 100);
        return `<font color="${color}">${"━".repeat(filled)}</font><font color="${load.colors.bg1}">${"━".repeat(12 - filled)}</font>`;
    }

    function row(label, percent, hue, detail, canAlert) {
        const pad = s => s.padEnd(4).replace(/ /g, "&nbsp;");
        const pct = String(percent).padStart(3).replace(/ /g, "&nbsp;");
        return `<font color="${hue}"><b>${pad(label)}</b></font> ${load.bar12(percent, load.level(percent, hue, canAlert))} ${pct}%&nbsp;&nbsp;<font color="${load.colors.grey0}">${detail}</font>`;
    }

    textFormat: Text.StyledText
    text: sample ? chip(sample.cpu, true) + chip(sample.ram, true) + (gpu >= 0 ? chip(gpu, false) : "") : ""
    tipFormat: Text.StyledText
    tip: sample ? [row("CPU", sample.cpu, colors.grey2, sample.ghz ? `${sample.ghz.toFixed(1)} GHz` : "", true), row("RAM", sample.ram, colors.aqua, `${sample.used.toFixed(1)} / ${sample.total.toFixed(1)} GiB&nbsp;&nbsp;·&nbsp;&nbsp;swap ${sample.swap.toFixed(1)}`, true), ...sample.gpus.map(g => row(g.name, g.busy, colors.blue, g.detail.replace(/ /g, "&nbsp;"), false))].join("<br>") : ""

    onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hypr-settings-menu", "monitor"])

    SequentialAnimation on opacity {
        running: load.critical
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            to: 0.35
            duration: 500
        }
        NumberAnimation {
            to: 1
            duration: 500
        }
    }

    // Dies with the bar even if the bar is killed outright.
    Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", Qt.resolvedUrl("load.py").toString().replace(/^file:\/\//, "")]
        stdout: SplitParser {
            onRead: line => {
                try {
                    load.sample = JSON.parse(line);
                } catch (error) {}
            }
        }
    }
}
