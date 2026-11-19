pragma ComponentBehavior: Bound

// The popups (#90): new notifications for a few seconds at the top
// right of the focused screen, newest on top, over everything. They
// slide in from the right edge, and the rest close up as one goes.
//
// The surface spans the screen's height so an exit animation is never
// cut off, but only the cards take the pointer (the mask), and it never
// takes the keyboard. Unmapped once the last card has gone.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: window

    readonly property int cardWidth: 380
    // Room for the cards' shadows inside the surface.
    readonly property int gutter: Theme.space.sm

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        right: true
    }
    // Below the bar, level with the windows' gap; nothing reserved.
    exclusiveZone: 0
    margins.right: Theme.space.sm - gutter
    implicitWidth: cardWidth + gutter * 2
    color: "transparent"
    visible: Notifs.popups.length > 0 || linger.running
    mask: Region {
        item: list
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Mapped a moment past the last card, for its exit.
    Timer {
        id: linger
        interval: Theme.motion.slow
    }

    Connections {
        target: Notifs

        function onPopupsChanged() {
            if (Notifs.popups.length === 0)
                linger.restart();
        }
    }

    ListView {
        id: list

        x: window.gutter
        y: Theme.space.sm
        width: window.cardWidth
        height: contentHeight
        spacing: Theme.space.sm
        interactive: false

        model: ScriptModel {
            values: Notifs.popups
        }

        delegate: NotifCard {
            required property var modelData

            width: list.width
            entry: modelData
            popup: true
        }

        add: Transition {
            Anim {
                property: "x"
                from: window.cardWidth / 3
                to: 0
                speed: "slow"
                curve: "enter"
            }
            Anim {
                property: "opacity"
                from: 0
                to: 1
                speed: "normal"
                curve: "enter"
            }
        }

        remove: Transition {
            Anim {
                property: "x"
                to: window.cardWidth / 3
                speed: "normal"
                curve: "exit"
            }
            Anim {
                property: "opacity"
                to: 0
                speed: "normal"
                curve: "exit"
            }
        }

        displaced: Transition {
            Anim {
                property: "y"
            }
            // An add cut short leaves a card half-faded; finish it.
            Anim {
                property: "opacity"
                to: 1
            }
            Anim {
                property: "x"
                to: 0
            }
        }
    }
}
