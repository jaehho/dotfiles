pragma ComponentBehavior: Bound

// The notification center (#90): NotifSheet at the top right of one
// screen, under the bar, sliding in from the right edge. It floats over
// the windows and reserves nothing. Open, it holds the keyboard
// exclusively; Esc or a click outside closes it (the focus grab).
//
// `open` is the request; `shown` is what the surface does, and trails
// it by one remap when it opens while still mapped from closing (a
// quick hop between monitors, or a quick reopen). Hyprland drops every
// focus grab when a mapped layer surface turns exclusive
// (LayerSurface.cpp, onCommit: setGrab(nullptr)), and the cleared grab
// closed the center. A fresh map checks the grab instead (onMap).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: center

    property bool open: false
    property bool shown: false
    property bool remapping: false
    readonly property int sheetWidth: 400
    // Room for the sheet's shadow inside the surface.
    readonly property int gutter: Theme.space.sm

    signal closeRequested

    onOpenChanged: {
        if (open && visible) {
            console.log("notif-debug remap", center.screen?.name);
            remapping = true;
            Qt.callLater(() => {
                center.remapping = false;
                center.shown = center.open;
            });
        } else {
            shown = open;
        }
    }

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
    visible: !remapping && (shown || sheet.opacity > 0)
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-notification-center"
    // Exclusive, as the polkit prompt: open, the keyboard stays here and
    // no window can take it (OnDemand let focus wander off while it was
    // still open). Super+period, Esc, q or a click outside close it.
    WlrLayershell.keyboardFocus: center.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [center]
        active: center.shown
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

        x: center.gutter + (center.shown ? 0 : Theme.space.xl)
        y: Theme.space.sm
        width: center.sheetWidth
        height: Math.min(implicitHeight, center.height - Theme.space.sm - center.gutter)
        open: center.shown
        opacity: center.shown ? 1 : 0
        focus: center.shown
        onCloseRequested: {
            console.log("notif-debug sheet close (key)", center.screen?.name);
            center.closeRequested();
        }

        Behavior on x {
            Anim {
                speed: "slow"
                curve: center.shown ? "enter" : "exit"
            }
        }

        Behavior on opacity {
            Anim {
                curve: center.shown ? "enter" : "exit"
            }
        }

        Behavior on height {
            Anim {}
        }
    }
}
