// A level on the quick settings sheet: its glyph, a track filled in fg
// up to the level, and the level in words. Dragging or clicking the
// track sets it (moved); the wheel, and h or l under the keyboard, step
// it as the keys do (stepped). The glyph's click and Enter belong to
// whoever places it.
import QtQuick

QuickControl {
    id: slider

    property real value: 0
    property int glyph
    // Off (muted): the glyph and fill turn grey0.
    property bool off: false
    property string label: ""
    property real dragged: 0
    readonly property bool held: area.pressed || hold.running
    readonly property real shown: Math.max(0, Math.min(1, held ? dragged : value))

    signal moved(real value)
    signal stepped(int steps)
    signal glyphClicked

    function step(steps) {
        if (slider.enabled)
            slider.stepped(steps);
    }

    slider: true
    flat: true
    height: 32

    // The track keeps showing where it was dragged until the level
    // read back has caught up.
    Timer {
        id: hold
        interval: 500
    }

    Item {
        id: icon
        width: 32
        height: parent.height

        Line {
            anchors.centerIn: parent
            mono: true
            size: 16
            text: String.fromCodePoint(slider.glyph)
            color: slider.off ? slider.colors.grey0 : slider.colors.fg
        }

        TapHandler {
            onTapped: {
                slider.sheet.keyboard = false;
                slider.forceActiveFocus();
                slider.glyphClicked();
            }
        }
    }

    Item {
        id: track
        x: icon.width + 6
        width: parent.width - x - words.width - 16
        height: parent.height

        Rectangle {
            id: groove
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: slider.colors.bg1

            Rectangle {
                width: Math.max(groove.height, groove.width * slider.shown)
                height: parent.height
                radius: 3
                color: slider.off ? slider.colors.grey0 : slider.colors.fg
            }
        }

        Rectangle {
            property int size: area.containsMouse || area.pressed ? 16 : 12
            x: groove.width * slider.shown - size / 2
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size
            radius: size / 2
            color: slider.off ? slider.colors.grey0 : slider.colors.fg
            border.width: 2
            border.color: slider.colors.bg_dim

            Behavior on size {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            id: area

            function follow(mouse) {
                slider.dragged = Math.max(0, Math.min(1, mouse.x / width));
                slider.moved(slider.dragged);
            }

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mouse => {
                slider.sheet.keyboard = false;
                slider.forceActiveFocus();
                follow(mouse);
            }
            onPositionChanged: mouse => {
                if (pressed)
                    follow(mouse);
            }
            onReleased: hold.restart()
        }
    }

    Line {
        id: words
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        mono: true
        size: 11
        text: slider.label
        color: slider.colors.grey2
    }

    WheelHandler {
        property real travel: 0
        onWheel: event => {
            travel += event.angleDelta.y;
            while (travel >= 120) {
                travel -= 120;
                slider.step(1);
            }
            while (travel <= -120) {
                travel += 120;
                slider.step(-1);
            }
        }
    }
}
