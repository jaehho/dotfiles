// A control on the open center island's sheet, on the shell base (#89):
// a pill on the card tone holding a Material Symbol, washing under the
// pointer; half opacity when the player can't do it.
import QtQuick

Rectangle {
    id: control

    // A Material Symbols name.
    property string icon: ""
    property int iconSize: Theme.icon.normal
    property real fill: 0

    signal clicked

    implicitWidth: 40
    implicitHeight: 32
    radius: Theme.radius.pill
    opacity: enabled ? 1 : 0.5
    color: Theme.surface.card

    StateLayer {
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: () => control.clicked()
    }

    Icon {
        anchors.centerIn: parent
        name: control.icon
        size: control.iconSize
        fill: control.fill
        color: Theme.colors.fg
    }
}
