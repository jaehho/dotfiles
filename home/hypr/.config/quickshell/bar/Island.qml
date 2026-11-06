// A resting island: bg0 glass at 0.88 with the faint blue edge, 26px
// tall with 6px inside either end, as waybar's .modules-* boxes were.
// What sits in it goes in its row.
import QtQuick

Rectangle {
    id: island

    required property var colors
    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26
    radius: 12
    color: colors.withAlpha(colors.bg0, 0.88)
    border.width: 1
    border.color: colors.withAlpha(colors.blue, 0.18)

    Row {
        id: row
        x: 6
        anchors.verticalCenter: parent.verticalCenter
    }
}
