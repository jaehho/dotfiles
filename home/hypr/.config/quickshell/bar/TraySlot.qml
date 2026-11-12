// One tray item: its icon on a 24px pill. Icons rest grey, since an
// app's own colours are not news; they take their colours under the
// pointer, or while the app asks for attention, on an orange pill.
// Left click brings up the app, middle click does its second action,
// right click opens its menu under the bar (a click on an app that only
// has a menu opens that).
import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray

Rectangle {
    id: slot

    required property var bar
    required property var item
    // Show the bar's tip under the bar on hover. The grid says it in
    // its footer instead, being in the tip's way.
    property bool tips: true
    readonly property string tip: item.tooltipTitle || item.title || item.id
    readonly property int tipFormat: Text.PlainText
    readonly property bool calling: item.status === Status.NeedsAttention
    readonly property bool hovered: area.containsMouse
    readonly property bool lit: hovered || calling

    // A click that leaves the bar's tray open or shut as it was asked.
    signal used

    width: 24
    height: 24
    radius: 8
    color: hovered ? bar.colors.withAlpha(bar.colors.blue, 0.14) : calling ? bar.colors.withAlpha(bar.colors.orange, 0.18) : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 200
        }
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
                NumberAnimation {
                    duration: 200
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (slot.tips)
                containsMouse ? slot.bar.hint(slot) : slot.bar.unhint(slot);
        }
        onClicked: mouse => {
            slot.bar.unhint(slot);
            if (mouse.button === Qt.MiddleButton) {
                slot.item.secondaryActivate();
            } else if (mouse.button === Qt.RightButton || slot.item.onlyMenu) {
                if (slot.item.hasMenu)
                    slot.bar.openTrayMenu(slot, slot.item.menu);
            } else {
                slot.item.activate();
            }
            slot.used();
        }
        onWheel: wheel => slot.item.scroll(wheel.angleDelta.y, false)
    }
}
