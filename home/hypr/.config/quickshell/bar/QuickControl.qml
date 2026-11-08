// A control on the quick settings sheet, one stop for the sheet's
// keyboard: bg0 with a bg1 edge, bg1 with a bg3 edge under the pointer,
// a state as a tint of its tone (on blue, armed red: the Tint Rule), and
// under the keyboard an fg edge inside a 2px blue ring 1px out. A flat
// one (a list row) is bare at rest. A click, Enter or Space presses it.
import QtQuick

Rectangle {
    id: control

    required property var sheet
    readonly property var colors: sheet.colors
    // Where the sheet's keyboard stops. A slider takes h and l itself.
    property bool navigable: true
    property bool slider: false
    property bool flat: false
    property bool on: false
    property bool armed: false
    readonly property bool hovered: hover.hovered
    readonly property bool lit: hovered && enabled
    readonly property bool ringed: activeFocus && sheet.keyboard

    signal activated

    function press() {
        if (control.enabled)
            control.activated();
    }

    radius: 8
    opacity: enabled ? 1 : 0.5
    color: armed ? colors.withAlpha(colors.red, 0.2) : on ? colors.withAlpha(colors.blue, lit ? 0.28 : 0.18) : lit ? colors.bg1 : flat ? colors.withAlpha(colors.bg1, 0) : colors.bg0
    border.width: 1
    border.color: ringed ? colors.fg : armed ? colors.withAlpha(colors.red, 0.55) : on ? colors.withAlpha(colors.blue, 0.55) : lit ? (flat ? colors.bg1 : colors.bg3) : flat ? colors.withAlpha(colors.bg1, 0) : colors.bg1

    Behavior on color {
        ColorAnimation {
            duration: 200
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: control.radius + 3
        color: "transparent"
        border.width: 2
        border.color: control.colors.blue
        visible: control.ringed
    }

    HoverHandler {
        id: hover
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // A slider handles its own pointer.
    TapHandler {
        enabled: !control.slider
        onTapped: {
            control.sheet.keyboard = false;
            control.forceActiveFocus();
            control.press();
        }
    }
}
