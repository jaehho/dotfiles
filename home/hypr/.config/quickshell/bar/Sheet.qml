// The surface of everything that opens over the windows (#89): the
// side panels, the notification popups and center. The sheet colour
// with the outline, on a soft shadow. Content goes in as children.
import QtQuick
import QtQuick.Effects

Item {
    id: sheet

    property real radius: Theme.radius.surface
    default property alias content: body.data

    RectangularShadow {
        anchors.fill: parent
        radius: sheet.radius
        blur: 6
        color: Theme.surface.shadow
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: sheet.radius
        color: Theme.surface.sheet
        border.width: 1
        border.color: Theme.surface.outline
    }
}
