pragma ComponentBehavior: Bound

// The notification center (#90): NotifSheet at the top right of one
// screen, under the bar, sliding in from the right edge. It floats over
// the windows and reserves nothing. Open, it holds the keyboard
// exclusively; Super+period, Esc or q close it, and so does losing the
// keyboard after having it.
//
// Its keyboard mode never changes: the surface is Exclusive for as long
// as it is mapped, and opening or closing only maps or unmaps it, as
// the polkit prompt does. No HyprlandFocusGrab: in Hyprland 0.57.2 a
// grab hands the surface the keyboard at the seat level first, so the
// layer's own takeKeyboardFocus finds it already focused and returns
// before Hyprland records it as the focused surface; mouse refocus then
// checks only that record (InputManager.cpp, allowKeyboardRefocus) and
// gave the window under the pointer the keyboard while the center
// stayed open (#90, Hyprland debug log 2026-11-20).
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: center

    property bool open: false
    readonly property int sheetWidth: 400
    // Room for the sheet's shadow inside the surface.
    readonly property int gutter: Theme.space.sm

    signal closeRequested

    // DEBUG(#90): what the surface does while focus goes astray.
    onVisibleChanged: console.log("notif-debug surface", screen?.name, "visible", visible, "open", open, "kb", WlrLayershell.keyboardFocus, "focusable", focusable)

    anchors {
        top: true
        bottom: true
        right: true
    }
    exclusiveZone: 0
    margins.right: Theme.space.sm - gutter
    implicitWidth: sheetWidth + gutter * 2
    color: "transparent"
    // Mapped exactly while open, so every open is a fresh map, which is
    // when Hyprland gives a layer the keyboard: one reopened while still
    // fading out never took it, and the closing one's unmap then gave it
    // to the window under the pointer (refocus ignores exclusive layers
    // when called from onUnmap). No close fade.
    visible: open
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-notification-center"
    // Exclusive, as the polkit prompt, and constant (see the top).
    // Super+period, Esc, q or a click outside close it.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    NotifSheet {
        id: sheet

        x: center.gutter + (center.open ? 0 : Theme.space.xl)
        y: Theme.space.sm
        width: center.sheetWidth
        height: Math.min(implicitHeight, center.height - Theme.space.sm - center.gutter)
        open: center.open
        opacity: center.open ? 1 : 0
        focus: center.open

        // Losing the keyboard after having it closes the center, so it
        // is never open while something else takes the typing.
        property bool hadKeys: false

        onActiveFocusChanged: {
            console.log("notif-debug activeFocus", center.screen?.name, activeFocus, "open", center.open);
            if (activeFocus)
                hadKeys = true;
            else if (hadKeys && center.open)
                center.closeRequested();
        }

        Connections {
            target: center

            function onOpenChanged() {
                if (!center.open)
                    sheet.hadKeys = false;
            }
        }
        onCloseRequested: {
            console.log("notif-debug sheet close (key)", center.screen?.name);
            center.closeRequested();
        }

        Behavior on x {
            Anim {
                speed: "slow"
                curve: "enter"
            }
        }

        Behavior on opacity {
            Anim {
                curve: "enter"
            }
        }

        Behavior on height {
            Anim {}
        }
    }
}
