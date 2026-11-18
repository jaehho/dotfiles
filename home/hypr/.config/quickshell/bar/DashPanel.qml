// The dash panel: a full-height sheet on the right edge of one screen,
// under the bar, that replaces the always-on desktop dashboard (issue
// #83). It is its own layer surface, since the bar's surface is 640px
// tall. Open, it reserves its width, so the windows tile beside it;
// closed, it is unmapped and the desktop stays plain.
//
// Esc or a click outside closes it (the focus grab), and so does a click
// that opens something from a card (btop, a session, a usage page). It
// holds SYSTEM, SESSIONS and LLM, in dash's look, and never scrolls:
// .claude/rules/dash-panel.md.
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

    // A down feed leaves no numbers behind: rings park, digits read "…".
    readonly property bool down: feed.down
    readonly property var d: down ? ({}) : feed.live
    readonly property var r: down ? null : feed.readout
    readonly property var p: down ? ({}) : feed.peak

    // Status hues, the waybar ladder dash used: fg when fine, yellow
    // worth a glance, red act now.
    function ladder(v, amberAt, redAt) {
        return v === null || v === undefined ? panel.colors.fg : v >= redAt ? panel.colors.red : v >= amberAt ? panel.colors.yellow : panel.colors.fg;
    }

    function share(used, total) {
        return used !== null && used !== undefined && total ? 100 * used / total : -1;
    }

    // dash's net scale: log10 from 32 KiB/s to 150e6 B/s; 0 at or under
    // the floor, -1 for no data.
    function netPct(bps) {
        if (bps === null || bps === undefined)
            return -1;
        const floor = 32 * 1024, ceil = 150e6;
        return bps <= floor ? 0 : Math.max(0, Math.min(100, 100 * Math.log10(bps / floor) / Math.log10(ceil / floor)));
    }

    function rate(bps) {
        if (bps === null || bps === undefined)
            return "…";
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MiB/s";
        if (bps >= 1024)
            return (bps / 1024).toFixed(0) + " KiB/s";
        return Math.round(bps) + " B/s";
    }

    onOpenChanged: fit.restart()

    function degrees(v) {
        return v === null || v === undefined ? "…" : Math.round(v) + "°";
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

    // The no-scroll rule's check: content taller than the sheet is cut
    // off at the bottom, so say so in the bar's log. Only once open and
    // settled: closed, or before the compositor sizes it, the sheet is
    // not its real height.
    Timer {
        id: fit
        interval: 500
        onTriggered: if (panel.open && cards.implicitHeight > body.height)
            console.warn("dash panel overflows:", Math.ceil(cards.implicitHeight), "px of content in", Math.floor(body.height));
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

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            onHeightChanged: fit.restart()

            ColumnLayout {
                id: cards
                width: parent.width
                spacing: 12
                onImplicitHeightChanged: fit.restart()

                DashCard {
                    Layout.fillWidth: true
                    colors: panel.colors
                    title: "SYSTEM"
                    // Not in the first 2 s, when no sample has come yet.
                    alert: panel.down && panel.feed.active && panel.feed.now - panel.feed.openedAt > 2000 ? "live feed down" : ""
                    cmd: [Quickshell.env("HOME") + "/.local/bin/hypr-settings-menu", "monitor"]
                    onLaunch: (url, cmd) => panel.launch(url, cmd)

                    // Four LED rings; the ghost is each one's 1-min max.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        DashRing {
                            colors: panel.colors
                            label: "cpu"
                            pct: panel.d.cpu ?? -1
                            peak: panel.p.cpu ?? -1
                            value: panel.r ? Math.round(panel.r.cpu) + "%" : "…"
                            valueColor: panel.ladder(panel.r?.cpu, 70, 90)
                        }

                        DashRing {
                            colors: panel.colors
                            label: "gpu"
                            hue: panel.colors.purple
                            pct: panel.d.gpu_util ?? -1
                            peak: panel.p.gpu_util ?? -1
                            value: !panel.r ? "…" : panel.r.gpu_util === null || panel.r.gpu_util === undefined ? "idle" : Math.round(panel.r.gpu_util) + "%"
                            valueColor: panel.r && (panel.r.gpu_util === null || panel.r.gpu_util === undefined) ? panel.colors.grey2 : panel.ladder(panel.r?.gpu_util, 70, 90)
                        }

                        DashRing {
                            colors: panel.colors
                            label: "ram"
                            amberAt: 80
                            redAt: 92
                            pct: panel.share(panel.d.mem_used_gib, panel.d.mem_total_gib)
                            peak: panel.share(panel.p.mem_used_gib, panel.d.mem_total_gib)
                            value: panel.r && panel.r.mem_total_gib ? Math.round(panel.share(panel.r.mem_used_gib, panel.r.mem_total_gib)) + "%" : "…"
                            unit: panel.r && panel.r.mem_total_gib ? "of " + panel.r.mem_total_gib.toFixed(0) + "G" : ""
                            valueColor: panel.ladder(panel.r ? panel.share(panel.r.mem_used_gib, panel.r.mem_total_gib) : null, 80, 92)
                        }

                        // 85/95: parked idle pages hold swap at 55-75% for
                        // days here, so the bands are for running out.
                        DashRing {
                            colors: panel.colors
                            label: "swap"
                            amberAt: 85
                            redAt: 95
                            pct: panel.share(panel.d.swap_used_gib, panel.d.swap_total_gib)
                            peak: panel.share(panel.p.swap_used_gib, panel.d.swap_total_gib)
                            value: panel.r && panel.r.swap_total_gib ? Math.round(panel.share(panel.r.swap_used_gib, panel.r.swap_total_gib)) + "%" : "…"
                            unit: panel.r && panel.r.swap_total_gib ? "of " + panel.r.swap_total_gib.toFixed(0) + "G" : ""
                            valueColor: panel.ladder(panel.r ? panel.share(panel.r.swap_used_gib, panel.r.swap_total_gib) : null, 85, 95)
                        }
                    }

                    // Thermals as one readout row; the bands follow the
                    // hardware: cpu 75/90 (Tjmax 100), nvme 70/80 (crit 84.8).
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 22

                        Repeater {
                            model: [
                                {
                                    dot: panel.colors.orange,
                                    name: "cpu",
                                    text: panel.degrees(panel.r?.temp_cpu),
                                    tint: panel.ladder(panel.r?.temp_cpu, 75, 90)
                                },
                                {
                                    dot: panel.colors.orange,
                                    name: "nvme",
                                    text: panel.degrees(panel.r?.temp_nvme),
                                    tint: panel.ladder(panel.r?.temp_nvme, 70, 80)
                                },
                                {
                                    dot: panel.colors.grey2,
                                    name: "fan",
                                    text: !panel.r ? "…" : [panel.r.fan1, panel.r.fan2].filter(v => v !== null && v !== undefined).map(Math.round).join(" · ") + " rpm",
                                    tint: panel.colors.fg
                                }
                            ]

                            RowLayout {
                                id: reading

                                required property var modelData

                                spacing: 7

                                Rectangle {
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: reading.modelData.dot
                                }

                                Line {
                                    text: reading.modelData.name
                                    mono: true
                                    size: 12
                                    color: panel.colors.grey2
                                    font.letterSpacing: 1
                                }

                                Line {
                                    text: reading.modelData.text
                                    mono: true
                                    color: reading.modelData.tint
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 4

                        RowLayout {
                            spacing: 7

                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: panel.colors.aqua
                            }

                            Line {
                                text: panel.d.net_iface ? "net · " + panel.d.net_iface : "net"
                                mono: true
                                size: 12
                                color: panel.colors.grey2
                                font.letterSpacing: 1
                            }
                        }

                        DashNet {
                            colors: panel.colors
                            arrow: "↓"
                            pct: panel.netPct(panel.d.net_rx_bps)
                            peak: panel.netPct(panel.p.net_rx_bps)
                            value: panel.rate(panel.r?.net_rx_bps)
                        }

                        DashNet {
                            colors: panel.colors
                            arrow: "↑"
                            showScale: true
                            pct: panel.netPct(panel.d.net_tx_bps)
                            peak: panel.netPct(panel.p.net_tx_bps)
                            value: panel.rate(panel.r?.net_tx_bps)
                        }
                    }

                    DashQuota {
                        readonly property real used: panel.share(panel.d.disk_used_gib, panel.d.disk_total_gib)

                        colors: panel.colors
                        name: "disk /"
                        value: panel.r && panel.r.disk_total_gib ? panel.r.disk_used_gib.toFixed(0) + " / " + panel.r.disk_total_gib.toFixed(0) + " GiB" : "…"
                        pct: used
                        barColor: used >= 95 ? panel.colors.red : used >= 85 ? panel.colors.yellow : panel.colors.grey2
                        valueColor: panel.ladder(panel.r ? panel.share(panel.r.disk_used_gib, panel.r.disk_total_gib) : null, 85, 95)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
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
            }
        }
    }
}
