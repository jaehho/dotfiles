// A round icon button (#89): a Material Symbol on a state layer. `active`
// fills the icon and lays a tonal wash of `activeTint` under it, for
// toggles such as Do Not Disturb.
import QtQuick

Item {
    id: button

    property string icon: ""
    property int size: Theme.icon.normal
    property color tint: Theme.colors.grey2
    property color activeTint: Theme.colors.blue
    property bool active: false
    readonly property bool hovered: layer.hovered

    signal clicked

    implicitWidth: size + Theme.space.sm * 2
    implicitHeight: implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.pill
        color: button.active ? Theme.colors.withAlpha(button.activeTint, 0.14) : "transparent"

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            id: layer
            tint: button.active ? button.activeTint : Theme.colors.fg
            onClicked: button.clicked()
        }
    }

    Icon {
        anchors.centerIn: parent
        name: button.icon
        size: button.size
        fill: button.active ? 1 : 0
        color: button.active ? button.activeTint : layer.hovered ? Theme.colors.fg : button.tint

        Behavior on color {
            CAnim {}
        }
    }
}
