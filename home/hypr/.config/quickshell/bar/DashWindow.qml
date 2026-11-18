// The dash window: a normal window that Hyprland tiles in dwindle beside
// the others, replacing the always-on desktop dashboard (issue #83).
// Closed it is gone and the desktop stays plain. Super+Q or Super+D
// closes it. Cards are ported from ~/projects/dash one at a time; SYSTEM
// is first.
import QtQuick
import QtQuick.Layouts
import Quickshell

FloatingWindow {
    id: panel

    required property var colors
    required property var feed
    property bool open: false

    signal closeRequested

    readonly property var d: feed.live
    readonly property bool down: feed.down

    function pct(value, total) {
        return value !== undefined && value !== null && total ? 100 * value / total : -1;
    }

    // Log scale from 32 KiB/s (the noise floor) to 1200 Mbps, as dash's
    // net meter, so the bar means the same thing every day.
    function netPct(bps) {
        if (bps === undefined || bps === null)
            return -1;
        const lo = Math.log10(32 * 1024);
        const hi = Math.log10(150e6);
        return Math.max(0, Math.min(100, 100 * (Math.log10(Math.max(bps, 1)) - lo) / (hi - lo)));
    }

    function rate(bps) {
        return bps === undefined || bps === null ? "" : (bps / 1048576).toFixed(1) + " MiB/s";
    }

    function gib(v) {
        return v === undefined || v === null ? "" : v.toFixed(1);
    }

    function warm(c, hot, warn) {
        return c >= hot ? panel.colors.red : c >= warn ? panel.colors.orange : panel.colors.aqua;
    }

    title: "dash"
    color: colors.bg_dim
    visible: open
    onVisibleChanged: if (!visible)
        closeRequested()

    Item {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: panel.closeRequested()

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: cards.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: cards
                width: parent.width
                spacing: 12

                DashCard {
                    Layout.fillWidth: true
                    colors: panel.colors
                    title: "SYSTEM"
                    alert: panel.down ? "live feed down" : ""

                    DashMeter {
                        colors: panel.colors
                        label: "CPU"
                        pct: panel.down ? -1 : (panel.d.cpu ?? -1)
                        value: Math.round(panel.d.cpu ?? 0) + "%"
                        tint: panel.warm(panel.d.cpu ?? 0, 90, 70)
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "MEM"
                        pct: panel.down ? -1 : panel.pct(panel.d.mem_used_gib, panel.d.mem_total_gib)
                        value: panel.gib(panel.d.mem_used_gib) + " GiB"
                        tint: panel.warm(pct, 90, 75)
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "SWAP"
                        pct: panel.down ? -1 : panel.pct(panel.d.swap_used_gib, panel.d.swap_total_gib)
                        value: panel.gib(panel.d.swap_used_gib) + " GiB"
                        tint: panel.warm(pct, 50, 25)
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "DISK"
                        pct: panel.down ? -1 : panel.pct(panel.d.disk_used_gib, panel.d.disk_total_gib)
                        value: Math.round(panel.d.disk_used_gib ?? 0) + " GiB"
                        tint: panel.warm(pct, 90, 80)
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "CPU°"
                        pct: panel.down || panel.d.temp_cpu == null ? -1 : panel.d.temp_cpu
                        value: Math.round(panel.d.temp_cpu ?? 0) + "°C"
                        tint: panel.warm(panel.d.temp_cpu ?? 0, 85, 70)
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "NVMe"
                        pct: panel.down || panel.d.temp_nvme == null ? -1 : panel.d.temp_nvme
                        value: Math.round(panel.d.temp_nvme ?? 0) + "°C"
                        tint: panel.warm(panel.d.temp_nvme ?? 0, 70, 55)
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "GPU"
                        pct: panel.down ? -1 : (panel.d.gpu_util ?? -1)
                        value: Math.round(panel.d.gpu_util ?? 0) + "%"
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "↓"
                        pct: panel.down ? -1 : panel.netPct(panel.d.net_rx_bps)
                        value: panel.rate(panel.d.net_rx_bps)
                        tint: panel.colors.blue
                    }
                    DashMeter {
                        colors: panel.colors
                        label: "↑"
                        pct: panel.down ? -1 : panel.netPct(panel.d.net_tx_bps)
                        value: panel.rate(panel.d.net_tx_bps)
                        tint: panel.colors.blue
                    }
                }
            }
        }
    }
}
