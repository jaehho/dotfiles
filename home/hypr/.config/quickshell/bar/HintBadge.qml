// The small key in a control's corner that presses it when typed: a
// keycap (bg2, a blue edge) with the letter in bold fg, upper case for
// legibility though it is typed lower. The part already typed turns blue
// and codes that no longer match fade out.
import QtQuick

Rectangle {
    id: badge

    required property var colors
    property string code: ""
    property string typed: ""
    property bool shown: false
    // How far inside the top-right corner; negative overhangs it.
    property real inset: 3
    readonly property bool live: shown && code !== "" && code.startsWith(typed)

    anchors.top: parent.top
    anchors.topMargin: inset
    anchors.right: parent.right
    anchors.rightMargin: inset
    z: 10
    width: Math.max(17, label.width + 8)
    height: 17
    radius: 5
    color: colors.bg2
    border.width: 1
    border.color: colors.withAlpha(colors.blue, 0.6)
    opacity: live ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 100
        }
    }

    Row {
        id: label
        anchors.centerIn: parent

        Line {
            mono: true
            size: 12
            weight: Font.Bold
            text: badge.code.slice(0, badge.typed.length).toUpperCase()
            color: badge.colors.blue
        }

        Line {
            mono: true
            size: 12
            weight: Font.Bold
            text: badge.code.slice(badge.typed.length).toUpperCase()
            color: badge.colors.fg
        }
    }
}
