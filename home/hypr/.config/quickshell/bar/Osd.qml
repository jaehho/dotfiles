// The level pop-up (#89), which replaced SwayOSD: a small pill at the
// bottom of the focused screen when the volume, mic or brightness keys
// change a level. hypr-level makes the change and then shows it here
// (`qs -c bar ipc call osd level <kind> <percent> <label> <muted>`), so
// the keys work whether or not the bar answers.
//
// Its icon, a meter like quick settings' slider track (fg on bg1, grey0
// when muted) and the level in Mono. It arrives over 150ms, stays 1.5 s
// after the last change and leaves over 250ms. It takes no input.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: osd

    // volume | mic | brightness
    property string kind: "volume"
    property real percent: 0
    property string label: ""
    property bool muted: false
    property bool shown: false

    readonly property string icon: {
        if (kind === "brightness")
            return percent < 34 ? "brightness_low" : percent < 67 ? "brightness_medium" : "brightness_high";
        if (kind === "mic")
            return muted ? "mic_off" : "mic";
        if (muted || percent === 0)
            return "volume_off";
        return percent < 34 ? "volume_mute" : percent < 67 ? "volume_down" : "volume_up";
    }

    IpcHandler {
        target: "osd"

        function level(kind: string, percent: real, label: string, muted: bool): void {
            osd.kind = kind;
            osd.percent = Math.max(0, Math.min(100, percent));
            osd.label = label;
            osd.muted = muted;
            osd.shown = true;
            linger.restart();
        }
    }

    Timer {
        id: linger
        interval: 1500
        onTriggered: osd.shown = false
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        anchors.bottom: true
        margins.bottom: 64
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 300 + Theme.space.sm * 2
        implicitHeight: 48 + Theme.space.sm * 2
        color: "transparent"
        mask: Region {}
        visible: pill.opacity > 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bar-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Sheet {
            id: pill

            x: Theme.space.sm
            y: Theme.space.sm + (osd.shown ? 0 : Theme.space.sm)
            width: 300
            height: 48
            radius: Theme.radius.pill
            opacity: osd.shown ? 1 : 0

            Behavior on opacity {
                Anim {
                    speed: osd.shown ? "fast" : "normal"
                    curve: osd.shown ? "enter" : "exit"
                }
            }

            Behavior on y {
                Anim {
                    speed: osd.shown ? "fast" : "normal"
                    curve: osd.shown ? "enter" : "exit"
                }
            }

            Icon {
                id: glyph
                x: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                name: osd.icon
                fill: osd.muted ? 0 : 1
                color: osd.muted ? Theme.colors.grey0 : Theme.colors.fg
            }

            // The meter.
            Rectangle {
                id: track
                anchors.left: glyph.right
                anchors.leftMargin: Theme.space.md
                anchors.right: level.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: Theme.radius.pill
                color: Theme.colors.bg1

                Rectangle {
                    width: Math.max(height, parent.width * osd.percent / 100)
                    height: parent.height
                    radius: Theme.radius.pill
                    visible: osd.percent > 0
                    color: osd.muted ? Theme.colors.grey0 : Theme.colors.fg

                    Behavior on width {
                        Anim {
                            speed: "fast"
                        }
                    }
                }
            }

            Line {
                id: level
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: osd.muted ? "Muted" : osd.label
                mono: !osd.muted
                size: Theme.font.small
                color: Theme.colors.grey2
            }
        }
    }
}
