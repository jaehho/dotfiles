// A resting island: the shell's glass (bg0 at 0.88) with its faint blue
// edge, 26px tall with 6px inside either end, as waybar's .modules-*
// boxes were.
// What sits in it goes in its row.
import QtQuick

Rectangle {
    id: island

    required property var colors
    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26
    radius: Theme.radius.surface
    color: Theme.surface.glass
    border.width: 1
    border.color: Theme.surface.outline

    Row {
        id: row
        x: 6
        anchors.verticalCenter: parent.verticalCenter
    }
}
