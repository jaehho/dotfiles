// An on/off switch on the quick settings sheet: a pill whose knob sits
// right in fg on the blue tint when on, and left in grey0 when off.
import QtQuick

QuickControl {
    id: toggle

    width: 40
    height: 22
    radius: height / 2

    Rectangle {
        x: toggle.on ? toggle.width - width - 4 : 4
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: toggle.on ? toggle.colors.fg : toggle.colors.grey0

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
}
