// The dash panel: a full-height sheet on the right edge of one screen,
// under the bar, that replaces the always-on desktop dashboard (issue
// #83). It is its own layer surface, since the bar's surface is 640px
// tall. Open, it reserves its width, so the windows tile beside it;
// closed, it is unmapped and the desktop stays plain.
//
// Esc or a click outside closes it (the focus grab), and so does a click
// that opens something from a card (a session, a link, asst-gtk). The
// cards are the old overlay's, from ~/projects/dash's Dashboard.qml, in
// its reading order: SYSTEM and MARKET, then SESSIONS, LLM and TASKS.
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

    // A card's click: run its command or open its link, then get out of
    // the way.
    function launch(url, cmd) {
        if (cmd && cmd.length)
            Quickshell.execDetached(cmd);
        if (url !== "")
            Qt.openUrlExternally(url);
        panel.closeRequested();
    }

    anchors {
        top: true
        bottom: true
        right: true
    }
    // Auto reserves the panel's width plus its right margin, so the
    // tiled windows slide aside instead of being covered, and the margins
    // count from under the bar's 40px (top 8 lands at y=48, level with
    // the windows).
    margins {
        top: 8
        right: 8
        bottom: 8
    }
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 2
                        color: panel.colors.bg2
                    }

                    // Failed units: absent at rest, red when present.
                    Line {
                        readonly property var failed: panel.feed.board?.failed ?? []

                        visible: failed.length > 0
                        Layout.fillWidth: true
                        opacity: panel.feed.boardDown ? 0.45 : 1
                        text: "✗ failed: " + failed.join(", ")
                        mono: true
                        size: 12
                        color: panel.colors.red
                        elide: Text.ElideRight
                    }

                    // restic: grey under 26 h, amber to 48 h, red past it
                    // or never.
                    Line {
                        readonly property var hours: panel.feed.board?.backup?.hours_ago ?? null

                        opacity: panel.feed.boardDown ? 0.45 : 1
                        text: !panel.feed.board ? "backup: …" : hours === null ? "backup: never succeeded" : "backup: " + hours + "h ago"
                        mono: true
                        size: 12
                        color: !panel.feed.board ? panel.colors.grey2 : hours === null ? panel.colors.red : hours < 26 ? panel.colors.grey2 : hours < 48 ? panel.colors.yellow : panel.colors.red
                    }
                }

                DashMarket {
                    Layout.fillWidth: true
                    colors: panel.colors
                    feed: panel.feed
                    onLaunch: (url, cmd) => panel.launch(url, cmd)
                }

                DashSessions {
                    Layout.fillWidth: true
                    colors: panel.colors
                    feed: panel.feed
                    onLaunch: (url, cmd) => panel.launch(url, cmd)
                }

                DashLlm {
                    Layout.fillWidth: true
                    colors: panel.colors
                    feed: panel.feed
                    onLaunch: (url, cmd) => panel.launch(url, cmd)
                }

                DashTasks {
                    Layout.fillWidth: true
                    colors: panel.colors
                    feed: panel.feed
                    onLaunch: (url, cmd) => panel.launch(url, cmd)
                }
            }
        }
    }
}
