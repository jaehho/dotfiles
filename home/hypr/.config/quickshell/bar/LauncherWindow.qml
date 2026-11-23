// The launcher (#89, replacing rofi's drun): LauncherSheet a fifth of
// the way down one screen, centered, over the windows. It holds the
// keyboard exclusively while open and is mapped exactly while open, as
// the notification center is (NotifCenter.qml says why); Super+Space,
// Esc, any Super chord or losing the keyboard close it.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: launcher

    property bool open: false
    readonly property int sheetWidth: 560
    // Room for the sheet's shadow inside the surface.
    readonly property int gutter: Theme.space.sm

    signal closeRequested
    signal superPressed

    anchors.top: true
    exclusiveZone: 0
    margins.top: Math.round((screen?.height ?? 1080) / 5)
    implicitWidth: sheetWidth + gutter * 2
    // As tall as the sheet can grow, so typing never resizes the surface;
    // the mask lets the pointer through below the sheet.
    implicitHeight: Theme.space.md * 2 + 40 + Theme.space.sm + sheet.rows * (sheet.rowHeight + 2) + gutter * 2
    color: "transparent"
    visible: open
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    LauncherSheet {
        id: sheet

        x: launcher.gutter
        y: launcher.gutter + (launcher.open ? 0 : -Theme.space.lg)
        width: launcher.sheetWidth
        height: implicitHeight
        open: launcher.open
        opacity: launcher.open ? 1 : 0

        // Losing the keyboard after having it closes the launcher.
        property bool hadKeys: false

        onTypingChanged: {
            if (typing)
                hadKeys = true;
            else if (hadKeys && launcher.open)
                launcher.closeRequested();
        }

        Connections {
            target: launcher

            function onOpenChanged() {
                if (!launcher.open)
                    sheet.hadKeys = false;
            }
        }
        onCloseRequested: launcher.closeRequested()
        onSuperPressed: launcher.superPressed()

        Behavior on y {
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
            Anim {
                speed: "fast"
            }
        }
    }
}
