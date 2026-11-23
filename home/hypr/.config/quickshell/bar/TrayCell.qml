// An app in the tray's grid (TrayGrid.qml), on the shell base (#89): its
// icon over its name in a cell that washes under the pointer. Icons rest
// grey, since an app's own colours are not news, and take them under the
// pointer or while the app asks for attention, which lays orange at 0.18
// behind the cell. The name is grey2 at rest and fg when lit; never
// orange, which measures 3.9:1 on its own tint (the Tint Rule).
//
// Left click brings the app up, middle click does its second action,
// right click opens its menu (Bar.trayClick); the wheel scrolls it. Its
// tooltip (unread counts and the like) is the bar's tip.
import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray

Rectangle {
    id: cell

    required property var bar
    required property var item
    // The hint key that clicks it (Shift: its menu), and whether the
    // grid shows them.
    property string hint: ""
    property string typed: ""
    property bool hinting: false
    readonly property string tip: item.tooltipTitle || item.title || item.id
    readonly property int tipFormat: Text.PlainText
    readonly property bool calling: item.status === Status.NeedsAttention
    readonly property bool hovered: wash.hovered
    readonly property bool lit: hovered || calling

    // After a click, for the grid to close.
    signal used

    function click(button) {
        cell.bar.trayClick(cell.item, button, cell);
        cell.used();
    }

    // A control nested in the island, 6px in from its 12px corners.
    radius: Theme.radius.control
    color: calling ? Theme.colors.withAlpha(Theme.colors.orange, 0.18) : "transparent"

    Behavior on color {
        CAnim {
            speed: "fast"
        }
    }

    StateLayer {
        id: wash
        tint: cell.calling ? Theme.colors.orange : Theme.colors.fg
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: which => cell.click(which)
        onHoveredChanged: () => hovered ? cell.bar.hint(cell) : cell.bar.unhint(cell)
    }

    WheelHandler {
        onWheel: event => cell.item.scroll(event.angleDelta.y, false)
    }

    // A little dimmed at rest to sit with the grey2 names; any lower and
    // a dark icon (OpenClaw's red) all but vanishes.
    TrayIcon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.space.md
        width: Theme.icon.large
        height: Theme.icon.large
        source: cell.item.icon
        opacity: cell.lit ? 1 : 0.8
        layer.enabled: true
        layer.effect: MultiEffect {
            saturation: cell.lit ? 0 : -1

            Behavior on saturation {
                Anim {
                    speed: "fast"
                }
            }
        }

        Behavior on opacity {
            Anim {
                speed: "fast"
            }
        }
    }

    Line {
        anchors.top: icon.bottom
        anchors.topMargin: Theme.space.sm
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.space.sm
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        size: Theme.font.small
        text: cell.bar.trayName(cell.item)
        color: cell.lit ? Theme.colors.fg : Theme.colors.grey2

        Behavior on color {
            CAnim {
                speed: "fast"
            }
        }
    }

    HintBadge {
        colors: cell.bar.colors
        code: cell.hint
        typed: cell.typed
        shown: cell.hinting
    }
}
