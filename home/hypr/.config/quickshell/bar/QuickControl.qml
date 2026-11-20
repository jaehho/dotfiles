// A control on the quick settings sheet, one stop for the sheet's
// keyboard, on the shell base (#89): a pill on the card tone, or bare
// when flat (a list row); a state as a tint of its tone (on blue, armed
// red: the Tint Rule); hover and press as a StateLayer wash. Under the
// keyboard it wears Material 3's focus indicator, a 2px blue ring 3px
// out: a sheet you walk in two directions needs more than a wash to
// show where you are. A click, Enter or Space presses it.
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
    // The hint key that presses it, shown while the sheet hints.
    property string hint: ""
    // What its hint letter is taken from; the first name in it if empty.
    property string hintText: ""
    property real hintInset: -3
    readonly property bool hovered: layer.hovered
    readonly property bool lit: hovered && enabled
    readonly property bool ringed: activeFocus && sheet.keyboard

    signal activated

    function press() {
        if (control.enabled)
            control.activated();
    }

    radius: Theme.radius.pill
    opacity: enabled ? 1 : 0.5
    color: armed ? Theme.colors.withAlpha(Theme.colors.red, 0.2) : on ? Theme.colors.withAlpha(Theme.colors.blue, 0.18) : flat ? "transparent" : Theme.surface.card

    Behavior on color {
        CAnim {
            speed: "fast"
        }
    }

    // A slider handles its own pointer and takes no wash.
    StateLayer {
        id: layer
        visible: !control.slider
        enabled: !control.slider
        tint: control.armed ? Theme.colors.red : control.on ? Theme.colors.blue : Theme.colors.fg
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: () => {
            control.sheet.keyboard = false;
            control.forceActiveFocus();
            control.press();
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: control.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.colors.blue
        opacity: control.ringed ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                speed: "fast"
            }
        }
    }

    HintBadge {
        colors: control.colors
        code: control.hint
        typed: control.sheet.typed
        shown: control.sheet.hinting
        inset: control.hintInset
    }
}
