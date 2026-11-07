// Things that want attention, as waybar's group/status: the tray behind
// its chevron, who is using the screen or the mic, stay-awake,
// notifications, dash's alerts, a pending reboot and failed units. All
// but the chevron, stay-awake and the bell hide while they have nothing
// to say.
//
// The tray slides out to the chevron's left, so on this right-anchored
// island it only grows the island's left edge, and stays out until the
// chevron is clicked again, so a tray icon's menu is safe to reach.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: attention

    required property var bar
    readonly property var colors: bar.colors
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property bool trayOpen: false

    // Refreshed by hypr-idle-toggle over IPC, and every 30 seconds.
    function probeAwake() {
        awakeProbe.running = true;
        awakeRecheck.restart();
    }

    function run(command) {
        Quickshell.execDetached(command);
    }

    Item {
        id: drawer
        width: attention.trayOpen ? tray.implicitWidth : 0
        height: 24
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        // Passive items (udiskie with nothing mounted) stay hidden, as in
        // waybar. 16px icons 14px apart, 3px in from either end.
        Row {
            id: tray
            anchors.right: parent.right
            leftPadding: 3
            rightPadding: 3
            spacing: 6

            Repeater {
                model: SystemTray.items.values.filter(item => item.status !== Status.Passive)

                Rectangle {
                    id: slot

                    required property var modelData
                    readonly property string tip: modelData.tooltipTitle || modelData.title || modelData.id
                    readonly property int tipFormat: Text.PlainText

                    width: 24
                    height: 24
                    radius: 8
                    color: area.containsMouse ? attention.colors.withAlpha(attention.colors.blue, 0.14) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }

                    TrayIcon {
                        anchors.centerIn: parent
                        source: slot.modelData.icon
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: containsMouse ? attention.bar.hint(slot) : attention.bar.unhint(slot)
                        onClicked: mouse => {
                            attention.bar.unhint(slot);
                            const item = slot.modelData;
                            if (mouse.button === Qt.MiddleButton)
                                item.secondaryActivate();
                            else if (mouse.button === Qt.RightButton || item.onlyMenu)
                                item.hasMenu && attention.bar.openTrayMenu(slot, item.menu);
                            else
                                item.activate();
                        }
                        onWheel: wheel => slot.modelData.scroll(wheel.angleDelta.y, false)
                    }
                }
            }
        }
    }

    BarButton {
        bar: attention.bar
        text: String.fromCodePoint(0xf0141)
        onClicked: attention.trayOpen = !attention.trayOpen
    }

    // Which app has the screen or the mic: red for the screen, which can
    // show what was not meant to be shown, orange for the mic. A stream
    // counts while its link runs (waybar: node state running); peak
    // meters on a monitor port do not count.
    Item {
        id: privacy

        readonly property var using: {
            const found = {
                screen: [],
                mic: []
            };
            for (const group of Pipewire.linkGroups.values) {
                const node = group.target;
                if (group.state !== PwLinkState.Active || !node)
                    continue;
                const props = node.properties;
                const kind = props["media.class"] ?? "";
                const name = props["application.name"] || node.description || node.name;
                if (kind.startsWith("Stream/Input/Video"))
                    found.screen.push(name);
                else if (kind.startsWith("Stream/Input/Audio") && props["stream.monitor"] !== "true")
                    found.mic.push(name);
            }
            return {
                screen: [...new Set(found.screen)],
                mic: [...new Set(found.mic)]
            };
        }

        visible: using.screen.length + using.mic.length > 0
        width: visible ? marks.width : 0
        height: 24

        PwObjectTracker {
            objects: [...Pipewire.linkGroups.values, ...Pipewire.nodes.values.filter(n => n.isStream || n.type === PwNodeType.Untracked)]
        }

        Row {
            id: marks

            BarButton {
                visible: privacy.using.screen.length > 0
                bar: attention.bar
                interactive: false
                text: String.fromCodePoint(0xf0379)
                tint: attention.colors.red
                tip: `Sharing the screen: ${privacy.using.screen.join(", ")}`
            }

            BarButton {
                visible: privacy.using.mic.length > 0
                bar: attention.bar
                interactive: false
                text: String.fromCodePoint(0xf036c)
                tint: attention.colors.orange
                tip: `Using the mic: ${privacy.using.mic.join(", ")}`
            }
        }
    }

    // Stay awake has two halves (hypr-idle-toggle): hypridle stopped, and
    // a hypr-lid-inhibit lid inhibitor held. Either alone is drift; it
    // shows as on, and a click (the toggle) then turns both off.
    BarButton {
        id: awake

        property bool idleOff: false
        property bool lidHeld: false
        readonly property bool on: idleOff || lidHeld

        bar: attention.bar
        text: String.fromCodePoint(on ? 0xf0176 : 0xf0faa)
        tint: on ? attention.colors.orange : attention.colors.grey2
        tip: idleOff && lidHeld ? "Stay awake: ON (idle + lid)" : idleOff ? "Stay awake: idle only, the lid still suspends" : lidHeld ? "Stay awake: lid only, idle still locks" : "Stay awake: OFF"
        onClicked: attention.run([attention.bin + "hypr-settings-menu", "awake"])

        // hypridle's pgrep status, then how many of our inhibitors logind
        // lists.
        Process {
            id: awakeProbe
            command: ["sh", "-c", "pgrep -x hypridle >/dev/null; echo $? $(systemd-inhibit --list --no-legend --no-pager | awk '$1 == \"hypr-lid-inhibit\"' | wc -l)"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [idle, lid] = text.trim().split(" ").map(Number);
                    awake.idleOff = idle !== 0;
                    awake.lidHeld = lid > 0;
                }
            }
        }

        Timer {
            running: true
            triggeredOnStart: true
            interval: 30000
            repeat: true
            onTriggered: attention.probeAwake()
        }

        // A toggle's halves land a moment after its refresh call.
        Timer {
            id: awakeRecheck
            interval: 1500
            onTriggered: awakeProbe.running = true
        }
    }

    // swaync's count, orange while something waits; red under do not
    // disturb, which silences everything and must not be forgotten.
    BarButton {
        id: bell

        property var state: ({
                text: "0",
                alt: "none",
                tooltip: ""
            })
        readonly property bool quiet: state.alt.startsWith("dnd")
        readonly property bool waiting: !quiet && state.alt.endsWith("notification")

        bar: attention.bar
        text: String.fromCodePoint(quiet ? 0xf009b : 0xf009a) + (quiet || state.text === "0" || state.text === "" ? "" : ` ${state.text}`)
        tint: quiet ? attention.colors.red : waiting ? attention.colors.orange : attention.colors.grey2
        tip: state.tooltip ?? ""
        onClicked: attention.run(["swaync-client", "-t", "-sw"])
        onRightClicked: attention.run([attention.bin + "hypr-settings-menu", "dnd"])

        // A subscription that only writes on change never meets a closed
        // pipe, so it is tied to the bar's life instead (issue #50).
        Process {
            id: subscription
            running: true
            command: ["setpriv", "--pdeathsig", "TERM", "swaync-client", "-swb"]
            stdout: SplitParser {
                onRead: line => {
                    try {
                        bell.state = JSON.parse(line);
                    } catch (error) {}
                }
            }
            onExited: resubscribe.start()
        }

        Timer {
            id: resubscribe
            interval: 3000
            onTriggered: subscription.running = true
        }
    }

    // dash's red-only glance (jaehho/dash#29): empty at rest, red when a
    // session waits, a unit failed, a quota ran out or a backup is stale.
    BarButton {
        id: dash

        property var state: ({})

        visible: (state.text ?? "") !== ""
        bar: attention.bar
        text: state.text ?? ""
        tint: [].concat(state.class ?? []).includes("alert") ? attention.colors.red : attention.colors.grey2
        hoverTint: tint
        tip: state.tooltip ?? ""
        onClicked: attention.run([attention.bin + "dash-data", "alerts-click"])

        Process {
            id: dashProbe
            command: [attention.bin + "dash-data", "alerts"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        dash.state = JSON.parse(text);
                    } catch (error) {}
                }
            }
        }

        Timer {
            running: true
            triggeredOnStart: true
            interval: 30000
            repeat: true
            onTriggered: dashProbe.running = true
        }
    }

    // The running kernel's modules are gone, so a driver that is not yet
    // loaded cannot load until a reboot. Asking is the confirmation: a
    // click opens a one-row menu.
    BarButton {
        id: reboot

        property string kernel: ""
        property string installed: ""

        visible: kernel !== ""
        bar: attention.bar
        bold: true
        text: String.fromCodePoint(0xf0709) + " Reboot"
        tint: attention.colors.red
        hoverTint: tint
        pill: attention.colors.withAlpha(attention.colors.red, 0.14)
        tip: `Kernel upgrade pending reboot\nrunning: ${kernel}\ninstalled: ${installed}`
        onClicked: attention.bar.toggleMenu(reboot, [
            {
                text: "Reboot now",
                run: () => attention.run(["sh", "-c", `sleep 0.2; exec "${attention.bin}hypr-settings-menu" reboot`])
            }
        ])

        Process {
            id: kernelProbe
            command: ["sh", "-c", 'r=$(uname -r); [ -d "/lib/modules/$r" ] || printf "%s\\n%s\\n" "$r" "$(ls -1 /lib/modules | paste -sd, -)"']
            stdout: StdioCollector {
                onStreamFinished: {
                    const [kernel, installed] = text.split("\n");
                    reboot.kernel = kernel ?? "";
                    reboot.installed = installed ?? "";
                }
            }
        }

        Timer {
            running: true
            triggeredOnStart: true
            interval: 300000
            repeat: true
            onTriggered: kernelProbe.running = true
        }
    }

    // Failed units, system and user alike; a click shows them in a tmux
    // pane (hypr-failed-units).
    BarButton {
        id: failed

        property int system: 0
        property int user: 0

        visible: system + user > 0
        bar: attention.bar
        text: `${String.fromCodePoint(0xf0028)} ${system + user}`
        tint: attention.colors.red
        tip: `Failed units: ${system} system, ${user} user`
        onClicked: attention.run([attention.bin + "hypr-failed-units"])

        Process {
            id: failedProbe
            command: ["sh", "-c", "systemctl show -P NFailedUnits; systemctl --user show -P NFailedUnits"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [system, user] = text.trim().split("\n").map(Number);
                    failed.system = system || 0;
                    failed.user = user || 0;
                }
            }
        }

        Timer {
            running: true
            triggeredOnStart: true
            interval: 15000
            repeat: true
            onTriggered: failedProbe.running = true
        }
    }
}
