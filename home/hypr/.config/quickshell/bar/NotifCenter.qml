pragma ComponentBehavior: Bound

// The notification center (#90): NotifSheet at the top right of one
// screen, under the bar, sliding in from the right edge. It floats over
// the windows and reserves nothing. Open, it takes the keyboard; Esc or
// a click outside closes it (the focus grab).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: center

    property bool open: false
    readonly property int sheetWidth: 400
    // Room for the sheet's shadow inside the surface.
    readonly property int gutter: Theme.space.sm

    signal closeRequested

    anchors {
        top: true
        bottom: true
        right: true
    }
    exclusiveZone: 0
    margins.right: Theme.space.sm - gutter
    implicitWidth: sheetWidth + gutter * 2
    color: "transparent"
    // Mapped while it slides, so the close animation is seen.
    visible: sheet.opacity > 0
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-notification-center"
    WlrLayershell.keyboardFocus: center.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [center]
        active: center.open
        onCleared: center.closeRequested()
    }

    NotifSheet {
        id: sheet

        x: center.gutter + (center.open ? 0 : Theme.space.xl)
        y: Theme.space.sm
        width: center.sheetWidth
        height: Math.min(implicitHeight, center.height - Theme.space.sm - center.gutter)
        open: center.open
        opacity: center.open ? 1 : 0
        focus: center.open
        onCloseRequested: center.closeRequested()

        Behavior on x {
            Anim {
                speed: "slow"
                curve: center.open ? "enter" : "exit"
            }
        }

        Behavior on opacity {
            Anim {
                curve: center.open ? "enter" : "exit"
            }
        }

        Behavior on height {
            Anim {}
        }
    }
}
