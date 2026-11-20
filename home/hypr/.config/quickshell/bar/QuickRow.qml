// A row in a page's list on the quick settings sheet (#89): a flat pill
// with a Material Symbol, a name and a short note at the end. On, it
// takes the blue tint, and its icon fills and it and the note turn blue
// (4.69:1 there), as a tile does. What lines up under the name (the
// password field, a failure band) starts at `textX`.
import QtQuick

QuickControl {
    id: row

    // A Material Symbols name.
    property string icon: ""
    property string text: ""
    property string note: ""
    readonly property real textX: Theme.space.md * 2 + Theme.icon.normal

    flat: true
    height: 36

    Icon {
        x: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        name: row.icon
        fill: row.on ? 1 : 0
        color: row.on ? Theme.colors.blue : Theme.colors.fg

        Behavior on color {
            CAnim {
                speed: "fast"
            }
        }
    }

    Line {
        x: row.textX
        width: parent.width - x - (noteLine.text !== "" ? noteLine.width + Theme.space.sm : 0) - Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: row.text
        color: Theme.colors.fg
    }

    Line {
        id: noteLine
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.font.small
        text: row.note
        color: row.on ? Theme.colors.blue : Theme.colors.grey2
    }
}
