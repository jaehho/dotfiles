// A control on a bar island, on the shell base (#89): a Material Symbol
// (`icon`), words (`text`), or both, resting in its own colour (grey2
// unless its state says otherwise) and brightening to `hoverTint` over
// a pill-shaped state layer in `wash` under the pointer. A tip below the
// bar says more after a moment's hover. Clicks, the wheel and what the
// tip says belong to whoever places it.
//
// A cluster not yet on Material Symbols passes its Nerd Font glyph as
// `text`, which is set in the bar's mono face.
import QtQuick

Item {
    id: control

    required property var bar
    // A Material Symbols name.
    property string icon: ""
    property int iconSize: Theme.icon.small + 2
    property real fill: 0
    property string text: ""
    property int textFormat: Text.PlainText
    property color tint: Theme.colors.grey2
    property color hoverTint: Theme.colors.fg
    // The state layer's tint: fg, or red on a destructive control.
    property color wash: Theme.colors.fg
    property int size: Theme.font.body
    property bool bold: false
    property bool italic: false
    // Longer text is cut with an ellipsis; the tip keeps all of it.
    property real maxWidth: Infinity
    // What the tip says; empty, no tip.
    property string tip: ""
    property int tipFormat: Text.PlainText
    readonly property bool hovered: hover.hovered
    // Off for text that only reports, like the window title: no wash,
    // no pointer, no clicks. The tip still shows.
    property bool interactive: true
    readonly property bool lit: interactive && hovered
    readonly property color shade: lit ? hoverTint : tint

    signal clicked
    signal rightClicked
    signal middleClicked
    // One per wheel notch: +1 away from the user, -1 toward.
    signal scrolled(int steps)

    // A lone icon sits in a near-round pill; words take room either side.
    implicitWidth: content.width + (control.text === "" ? Theme.space.xs : Theme.space.sm) * 2
    implicitHeight: 24

    HoverHandler {
        id: hover
        cursorShape: control.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: hovered ? control.bar.hint(control) : control.bar.unhint(control)
    }

    StateLayer {
        radius: Theme.radius.pill
        tint: control.wash
        enabled: control.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: which => {
            control.bar.unhint(control);
            if (which === Qt.RightButton)
                control.rightClicked();
            else if (which === Qt.MiddleButton)
                control.middleClicked();
            else
                control.clicked();
        }
    }

    WheelHandler {
        enabled: control.interactive
        property real travel: 0
        onWheel: event => {
            travel += event.angleDelta.y;
            while (travel >= 120) {
                travel -= 120;
                control.scrolled(1);
            }
            while (travel <= -120) {
                travel += 120;
                control.scrolled(-1);
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.space.xs

        Icon {
            visible: control.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: control.icon
            size: control.iconSize
            fill: control.fill
            color: control.shade

            Behavior on color {
                CAnim {
                    speed: "fast"
                }
            }
        }

        Line {
            visible: control.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, control.maxWidth)
            elide: Text.ElideRight
            mono: true
            size: control.size
            weight: control.bold ? Font.Bold : Font.Normal
            font.italic: control.italic
            textFormat: control.textFormat
            text: control.text
            color: control.shade

            Behavior on color {
                CAnim {
                    speed: "fast"
                }
            }
        }
    }
}
