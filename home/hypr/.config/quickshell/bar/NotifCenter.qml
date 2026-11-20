pragma ComponentBehavior: Bound

// The notification center (#90): NotifSheet at the top right of one
// screen, under the bar, sliding in from the right edge. It floats over
// the windows and reserves nothing. Open, it holds the keyboard
// exclusively; Esc or a click outside closes it (the focus grab).
//
// Its keyboard mode never changes: the surface is Exclusive for as long
// as it is mapped, and opening or closing only maps or unmaps it.
// Switching a mapped surface between None and Exclusive raced its map:
// Hyprland's log showed the surface mapping before the Exclusive
// request, never taking focus, and a window getting the keyboard while
// no exclusive layer counted (#90, 2026-11-20). Mapped with Exclusive
// from its first commit, it takes focus on map, and while it is mapped
// Hyprland refuses focus to every window. The close fade is short, so
// the keyboard comes back quickly.
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

    // DEBUG(#90): what the surface does while focus goes astray.
    onVisibleChanged: console.log("notif-debug surface", screen?.name, "visible", visible, "open", open)

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
    visible: open || sheet.opacity > 0
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-notification-center"
    // Exclusive, as the polkit prompt, and constant (see the top).
    // Super+period, Esc, q or a click outside close it.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        windows: [center]
        active: center.open
        // DEBUG(#90): what closes the center during monitor hops.
        onActiveChanged: console.log("notif-debug grab", center.screen?.name, "active", active, "open", center.open)
        // Only an open center closes: a grab ended while this one was
        // already handing over to another screen says nothing.
        onCleared: {
            console.log("notif-debug grab cleared", center.screen?.name, "open", center.open);
            if (center.open)
                center.closeRequested();
        }
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
        onCloseRequested: {
            console.log("notif-debug sheet close (key)", center.screen?.name);
            center.closeRequested();
        }

        Behavior on x {
            Anim {
                speed: "slow"
                curve: center.open ? "enter" : "exit"
            }
        }

        // Closing is quick: the surface keeps the keyboard until it is
        // gone.
        Behavior on opacity {
            Anim {
                speed: center.open ? "normal" : "fast"
                curve: center.open ? "enter" : "exit"
            }
        }

        Behavior on height {
            Anim {}
        }
    }
}
