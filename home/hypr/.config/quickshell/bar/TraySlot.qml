// A tray app on the bar, beside the tray's chevron while it asks for
// attention: its icon on a 24px pill. Icons rest grey, since an app's
// own colours are not news; they take their colours under the pointer,
// or while the app asks for attention, on an orange pill; the pointer
// washes it as it does the bar's buttons (#89). A click does what one in
// the grid does (Bar.trayClick). The grid draws its apps as TrayCell.
import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray

Rectangle {
    id: slot

    required property var bar
    required property var item
    readonly property string tip: item.tooltipTitle || item.title || item.id
    readonly property int tipFormat: Text.PlainText
    readonly property bool calling: item.status === Status.NeedsAttention
    readonly property bool hovered: wash.hovered
    readonly property bool lit: hovered || calling

    function click(button) {
        slot.bar.trayClick(slot.item, button, slot);
    }

    width: 24
    height: 24
    radius: Theme.radius.pill
    color: calling ? Theme.colors.withAlpha(Theme.colors.orange, 0.18) : "transparent"

    Behavior on color {
        CAnim {
            speed: "fast"
        }
    }

    StateLayer {
        id: wash
        tint: slot.calling ? Theme.colors.orange : Theme.colors.fg
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: which => slot.click(which)
        onHoveredChanged: () => hovered ? slot.bar.hint(slot) : slot.bar.unhint(slot)
    }

    WheelHandler {
        onWheel: event => slot.item.scroll(event.angleDelta.y, false)
    }

    // Grey, and a little dimmed to sit with the grey2 glyphs; any
    // lower and a dark icon (OpenClaw's red) all but vanishes.
    TrayIcon {
        anchors.centerIn: parent
        source: slot.item.icon
        opacity: slot.lit ? 1 : 0.8
        layer.enabled: true
        layer.effect: MultiEffect {
            saturation: slot.lit ? 0 : -1

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
}
