// The share menu (#89, replacing rofi's):
// ShareSheet a fifth of the way down one screen, centered, over the
// windows, where the launcher sits. It holds the keyboard exclusively
// while open and is mapped exactly while open, as the notification
// center is (NotifCenter.qml says why); Super+S, Esc, any Super chord or
// losing the keyboard close it.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    property bool open: false
    readonly property int sheetWidth: 440
    // Room for the sheet's shadow inside the surface.
    readonly property int gutter: Theme.space.sm

    signal closeRequested
    signal superPressed

    anchors.top: true
    exclusiveZone: 0
    margins.top: Math.round((screen?.height ?? 1080) / 5)
    implicitWidth: sheetWidth + gutter * 2
    // As tall as the sheet can grow (the QR page), so a page never resizes the
    // surface; the mask lets the pointer through below the sheet.
    implicitHeight: 400 + gutter * 2
    color: "transparent"
    visible: open
    mask: Region {
        item: sheet
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-share"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    ShareSheet {
        id: sheet

        x: window.gutter
        y: window.gutter + (window.open ? 0 : -Theme.space.lg)
        width: window.sheetWidth
        height: implicitHeight
        open: window.open
        opacity: window.open ? 1 : 0

        // Losing the keyboard after having it closes the sheet.
        property bool hadKeys: false

        onTypingChanged: {
            if (typing)
                hadKeys = true;
            else if (hadKeys && window.open)
                window.closeRequested();
        }

        Connections {
            target: window

            function onOpenChanged() {
                if (!window.open)
                    sheet.hadKeys = false;
            }
        }
        onCloseRequested: window.closeRequested()
        onSuperPressed: window.superPressed()

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
