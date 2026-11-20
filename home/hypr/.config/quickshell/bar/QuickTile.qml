// A tile on the quick settings sheet (#89): a pill with its Material
// Symbol in the round end, a name and a state line beneath. On, the
// icon fills and it and the state turn blue on the blue tint (4.69:1
// there); off, the icon rests in grey0. A chevron marks a tile that
// opens a page.
import QtQuick

QuickControl {
    id: tile

    // A Material Symbols name.
    property string icon: ""
    property string name: ""
    property string detail: ""
    property bool off: false
    property bool more: false

    height: 48

    // Centered in the pill's round end.
    Icon {
        x: tile.height / 2 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        name: tile.icon
        fill: tile.on ? 1 : 0
        color: tile.on ? Theme.colors.blue : tile.off ? Theme.colors.grey0 : Theme.colors.fg

        Behavior on color {
            CAnim {
                speed: "fast"
            }
        }
    }

    Column {
        x: tile.height - Theme.space.sm
        width: parent.width - x - (tile.more ? 28 : Theme.space.md)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Line {
            width: parent.width
            elide: Text.ElideRight
            text: tile.name
            color: Theme.colors.fg
        }

        Line {
            width: parent.width
            elide: Text.ElideRight
            size: Theme.font.small
            text: tile.detail
            color: tile.on ? Theme.colors.blue : Theme.colors.grey2
        }
    }

    Icon {
        visible: tile.more
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron_right"
        size: Theme.icon.small
        color: Theme.colors.grey2
    }
}
