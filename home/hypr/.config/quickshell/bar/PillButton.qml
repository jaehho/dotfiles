// A tonal pill button (#89): a faint wash of `tint`, an optional
// Material Symbol in it, and the label in fg, since no tone holds
// 4.5:1 on its own wash over a card (DESIGN.md, the Tint Rule; Material
// 3's tonal buttons do the same). `badge` is a dim
// keyboard hint at its end, and the label centers in the room left of
// it. Laid out wider than its text, it centers the text; narrower, the
// text is cut with an ellipsis.
import QtQuick

Rectangle {
    id: button

    property string text: ""
    property string icon: ""
    property string badge: ""
    property color tint: Theme.colors.blue
    readonly property bool hovered: layer.hovered

    signal clicked

    implicitHeight: 30
    // From the label's own width, not the row's: the label's width
    // depends on the button's, which would loop.
    implicitWidth: label.implicitWidth + (icon !== "" ? Theme.icon.small + row.spacing : 0) + Theme.space.md * 2 + reserve
    // The badge's room, kept clear of the label.
    readonly property real reserve: badge !== "" ? hint.implicitWidth + Theme.space.sm : 0
    radius: Theme.radius.pill
    color: Theme.colors.withAlpha(tint, enabled ? 0.14 : 0.06)

    Behavior on color {
        CAnim {}
    }

    StateLayer {
        id: layer
        tint: button.tint
        onClicked: () => button.clicked()
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -button.reserve / 2
        spacing: Theme.space.xs
        opacity: button.enabled ? 1 : 0.5

        Icon {
            visible: button.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: button.icon
            size: Theme.icon.small
            color: button.tint
        }

        Line {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, button.width - Theme.space.md * 2 - button.reserve - (button.icon !== "" ? Theme.icon.small + row.spacing : 0))
            elide: Text.ElideRight
            text: button.text
            size: Theme.font.smaller
            weight: Font.Medium
            color: Theme.colors.fg
        }
    }

    Line {
        id: hint
        visible: button.badge !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        text: button.badge
        mono: true
        size: Theme.font.small
        color: Theme.colors.grey2
    }
}
