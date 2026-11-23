// A key name drawn as a keycap on the keybind sheet (DESIGN.md,
// Keycaps): Mono 11px bold fg on a bg3-to-bg2 face with a 1px bg3 edge,
// 8px corners and a 2px bg_dim lip under it. `prefix` is a held key in a
// heading or the chord: solid blue with bg_dim words, a size up.
import QtQuick

Item {
    id: cap

    property string text
    property bool prefix: false

    implicitWidth: Math.max(face.height, words.implicitWidth + (prefix ? 16 : 10))
    implicitHeight: face.height + 2

    // The lip: the face's shape in bg_dim, showing 2px below it.
    Rectangle {
        y: 2
        width: parent.width
        height: face.height
        radius: Theme.radius.control
        color: Theme.colors.bg_dim
    }

    Rectangle {
        id: face
        width: parent.width
        height: words.implicitHeight + (cap.prefix ? 4 : 2)
        radius: Theme.radius.control
        border.width: 1
        border.color: cap.prefix ? Theme.colors.blue : Theme.colors.bg3
        gradient: Gradient {
            GradientStop {
                position: 0
                color: cap.prefix ? Theme.colors.blue : Theme.colors.bg3
            }
            GradientStop {
                position: 1
                color: cap.prefix ? Qt.darker(Theme.colors.blue, 1.22) : Theme.colors.bg2
            }
        }

        Line {
            id: words
            anchors.centerIn: parent
            text: cap.text
            mono: true
            size: cap.prefix ? Theme.font.smaller : Theme.font.small
            weight: Font.Bold
            color: cap.prefix ? Theme.colors.bg_dim : Theme.colors.fg
        }
    }
}
