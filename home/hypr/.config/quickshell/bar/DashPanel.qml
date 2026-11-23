// The dash panel: a full-height sheet (DashSheet.qml) on the right edge
// of one screen, under the bar, that replaces the always-on desktop
// dashboard (issue #83). It is its own layer surface, since the bar's
// surface is 640px tall. Open, it reserves its width, so the windows
// tile beside it; closed, it is unmapped and the desktop stays plain.
//
// Esc or a click outside closes it (the focus grab), and so does a click
// that opens something from a card.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property var feed
    property bool open: false

    signal closeRequested

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
        top: Theme.space.sm
        right: Theme.space.sm
        bottom: Theme.space.sm
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

    // Slides 24px in from the right as it arrives, and back as it leaves.
    DashSheet {
        id: sheet

        width: panel.width
        height: panel.height
        x: panel.open ? 0 : Theme.space.xl
        opacity: panel.open ? 1 : 0
        focus: panel.open
        feed: panel.feed
        open: panel.open
        onCloseRequested: panel.closeRequested()

        Keys.onEscapePressed: panel.closeRequested()

        Behavior on x {
            Anim {
                speed: panel.open ? "slow" : "normal"
                curve: panel.open ? "enter" : "exit"
            }
        }

        Behavior on opacity {
            Anim {
                speed: panel.open ? "normal" : "fast"
                curve: panel.open ? "enter" : "exit"
            }
        }
    }
}
