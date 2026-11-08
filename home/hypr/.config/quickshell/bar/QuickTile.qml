// A tile on the quick settings sheet: its glyph, a name and a state
// line beneath. On, the glyph and state turn blue on the blue tint (4.69:1
// there); off, the glyph rests in grey0. A chevron marks a tile that opens
// a page.
import QtQuick

QuickControl {
    id: tile

    property string icon: ""
    property string name: ""
    property string detail: ""
    property bool off: false
    property bool more: false

    height: 48

    Line {
        id: glyph
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        mono: true
        size: 17
        text: tile.icon
        color: tile.on ? tile.colors.blue : tile.off ? tile.colors.grey0 : tile.colors.fg
    }

    Column {
        x: 40
        width: parent.width - x - (tile.more ? 24 : 10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Line {
            width: parent.width
            elide: Text.ElideRight
            text: tile.name
            color: tile.colors.fg
        }

        Line {
            width: parent.width
            elide: Text.ElideRight
            size: 11
            text: tile.detail
            color: tile.on ? tile.colors.blue : tile.colors.grey2
        }
    }

    Line {
        visible: tile.more
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        mono: true
        text: String.fromCodePoint(0xf0142)
        color: tile.colors.grey2
    }
}
