// A glyph on a bar island, as waybar drew its modules: 7px either side,
// resting in its own colour (grey2 unless its state says otherwise),
// brightening over a faint blue pill under the pointer. A tip below the
// bar says more after a moment's hover. Clicks, the wheel and what the
// tip says belong to whoever places it.
import QtQuick

Rectangle {
    id: button

    required property var bar
    property string text: ""
    property int textFormat: Text.PlainText
    property color tint: bar.colors.grey2
    property color hoverTint: bar.colors.fg
    property color pill: bar.colors.withAlpha(bar.colors.blue, 0.14)
    property int size: 13
    property bool bold: false
    property bool italic: false
    // Longer text is cut with an ellipsis; the tip keeps all of it.
    property real maxWidth: Infinity
    // What the tip says; empty, no tip.
    property string tip: ""
    property int tipFormat: Text.PlainText
    readonly property bool hovered: hover.hovered
    // Off for text that only reports, like the window title: no pill,
    // no pointer, no clicks. The tip still shows.
    property bool interactive: true

    signal clicked
    signal rightClicked
    signal middleClicked
    // One per wheel notch: +1 away from the user, -1 toward.
    signal scrolled(int steps)

    implicitWidth: label.width + 14
    implicitHeight: 24
    radius: 8
    color: button.interactive && hover.hovered ? button.pill : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 200
        }
    }

    HoverHandler {
        id: hover
        cursorShape: button.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: hovered ? button.bar.hint(button) : button.bar.unhint(button)
    }

    TapHandler {
        enabled: button.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (eventPoint, pressed) => {
            button.bar.unhint(button);
            if (pressed === Qt.RightButton)
                button.rightClicked();
            else if (pressed === Qt.MiddleButton)
                button.middleClicked();
            else
                button.clicked();
        }
    }

    WheelHandler {
        enabled: button.interactive
        property real travel: 0
        onWheel: event => {
            travel += event.angleDelta.y;
            while (travel >= 120) {
                travel -= 120;
                button.scrolled(1);
            }
            while (travel <= -120) {
                travel += 120;
                button.scrolled(-1);
            }
        }
    }

    Line {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, button.maxWidth)
        elide: Text.ElideRight
        mono: true
        size: button.size
        weight: button.bold ? Font.Bold : Font.Normal
        font.italic: button.italic
        textFormat: button.textFormat
        text: button.text
        color: button.interactive && hover.hovered ? button.hoverTint : button.tint

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }
}
