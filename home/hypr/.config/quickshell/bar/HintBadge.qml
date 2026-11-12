// The small letter in a control's corner that presses it when typed.
// Subtle at rest (grey on bg_dim); the part already typed turns blue,
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
    width: Math.max(13, label.width + 6)
    height: 13
    radius: 4
    color: colors.withAlpha(colors.bg_dim, 0.94)
    border.width: 1
    border.color: colors.bg3
    opacity: live ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    Row {
        id: label
        anchors.centerIn: parent

        Line {
            mono: true
            size: 9
            weight: Font.Bold
            text: badge.code.slice(0, badge.typed.length)
            color: badge.colors.blue
        }

        Line {
            mono: true
            size: 9
            weight: Font.Bold
            text: badge.code.slice(badge.typed.length)
            color: badge.colors.grey2
        }
    }
}
