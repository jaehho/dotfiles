// A glyph control on the open island: bg0 with a bg1 edge, bg1 with a
// bg3 edge under the pointer, half opacity when the player can't do it.
import QtQuick

Rectangle {
    id: button

    required property var colors
    property int glyph
    property int glyphSize: 16

    signal clicked

    implicitWidth: 40
    implicitHeight: 30
    radius: 8
    opacity: enabled ? 1 : 0.5
    color: hover.hovered && enabled ? colors.bg1 : colors.bg0
    border.width: 1
    border.color: hover.hovered && enabled ? colors.bg3 : colors.bg1

    Behavior on color {
        ColorAnimation {
            duration: 200
        }
    }

    HoverHandler {
        id: hover
        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        onTapped: if (button.enabled)
            button.clicked()
    }

    Line {
        anchors.centerIn: parent
        mono: true
        size: button.glyphSize
        text: String.fromCodePoint(button.glyph)
        color: button.colors.fg
    }
}
