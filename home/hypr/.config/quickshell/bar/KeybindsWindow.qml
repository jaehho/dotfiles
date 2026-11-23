// The keybind sheet (KeybindsSheet.qml, #89), centered on one screen
// over the windows. The surface covers the screen so the sheet can
// resize between its views in place; the mask passes the pointer through
// everywhere but the sheet. It holds the keyboard exclusively while open
// and is mapped exactly while open, as the notification center is
// (NotifCenter.qml says why).
//
// In the keyboard view it suspends Hyprland's binds (the
// keyboard-shortcuts-inhibit protocol), so Super+Q names Q instead of
// closing a window. The compositor ties the inhibitor to this surface
// and its focus, so nothing stays captured once the sheet closes.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    property bool open: false

    signal closeRequested

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"
    visible: open
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-keybinds"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    ShortcutInhibitor {
        window: window
        enabled: window.open && sheet.view === "keyboard"
    }

    KeybindsSheet {
        id: sheet

        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: implicitWidth
        height: implicitHeight
        open: window.open
        opacity: window.open ? 1 : 0
        // As the GTK sheet sized itself: clear of the screen's edges.
        maxListHeight: Math.round(window.height * 0.86) - 120
        onCloseRequested: window.closeRequested()

        // Drops 16px into place as it opens, apart from y, which follows
        // the height to stay centered.
        transform: Translate {
            y: window.open ? 0 : -Theme.space.lg

            Behavior on y {
                Anim {
                    speed: "slow"
                    curve: "enter"
                }
            }
        }

        Behavior on opacity {
            Anim {
                curve: "enter"
            }
        }

        Behavior on width {
            Anim {}
        }

        Behavior on height {
            Anim {}
        }
    }
}
