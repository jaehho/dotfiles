// The dash panel: a full-height sheet on the right edge of one screen,
// under the bar, that replaces the always-on desktop dashboard (issue
// #83). It is its own layer surface, since the bar's surface is 640px
// tall. Closed it is unmapped and the desktop stays plain.
//
// Esc or a click outside closes it (the focus grab). Cards are ported
// from ~/projects/dash one at a time; SYSTEM is first.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
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

    anchors {
        top: true
        bottom: true
        right: true
    }
    margins {
        top: 48
        right: 8
        bottom: 8
    }
    // The margins count from the screen's edge, not from under the
    // bar's 40px (Auto put the panel at y=88).
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 440
    color: "transparent"
    // Mapped while it slides, so the close animation is seen.
    visible: sheet.opacity > 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "bar-dash"
    WlrLayershell.keyboardFocus: panel.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: panel.closeRequested()
    }

    Item {
        id: sheet
        width: panel.width
        height: panel.height
        x: panel.open ? 0 : 24
        opacity: panel.open ? 1 : 0
        focus: panel.open

        Keys.onEscapePressed: panel.closeRequested()

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        RectangularShadow {
            anchors.fill: parent
            radius: 12
            blur: 6
            color: panel.colors.withAlpha(panel.colors.bg_dim, 0.93)
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: panel.colors.withAlpha(panel.colors.bg_dim, 0.985)
            border.width: 1
            border.color: panel.colors.withAlpha(panel.colors.blue, 0.18)
        }

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
