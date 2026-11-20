// The one hover, press and keyboard-focus feedback for anything
// clickable (#89): a wash of `tint` over its parent, at Theme.state's
// opacities, in the parent's own shape. It fills its parent, so put it
// first among the children and the content draws over it.
//
// `selected` is the keyboard's pointer (a list's current row), shown
// at focus strength. Disabled, it neither tints nor takes clicks.
//
// Handle `clicked` with a function (`onClicked: () => ...`): a bare
// handler gets the signal's `button` argument injected, which hides an
// id named `button` and made every pill and icon button throw instead
// of clicking (#90).
import QtQuick

Item {
    id: layer

    property color tint: Theme.colors.fg
    property real radius: parent?.radius ?? 0
    property bool selected: false
    property int acceptedButtons: Qt.LeftButton
    property int cursorShape: Qt.PointingHandCursor
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed

    signal clicked(int button)

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        radius: layer.radius
        color: layer.tint
        opacity: !layer.enabled ? 0 : layer.pressed ? Theme.state.press + Theme.state.hover : layer.hovered ? Theme.state.hover : layer.selected ? Theme.state.focus : 0

        Behavior on opacity {
            Anim {
                speed: "fast"
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: layer.cursorShape
    }

    // Exclusive on press, so a button inside a clickable card does not
    // click the card too; a DragHandler above can still take over.
    TapHandler {
        id: tap
        acceptedButtons: layer.acceptedButtons
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint, button) => layer.clicked(button)
    }
}
