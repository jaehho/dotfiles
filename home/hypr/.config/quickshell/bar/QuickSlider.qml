// A level on the quick settings sheet: its Material Symbol, a track
// filled in fg up to the level, and the level in words. Dragging or
// clicking the track sets it (moved); the wheel, and h or l under the
// keyboard, step it as the keys do (stepped). The icon's click and
// Enter belong to whoever places it; `pressable` gives the icon a round
// state layer when the click does something (mute).
import QtQuick

QuickControl {
    id: slider

    property real value: 0
    // A Material Symbols name.
    property string icon: ""
    property bool pressable: false
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
    hintInset: -4
    flat: true
    height: 36

    // The track keeps showing where it was dragged until the level
    // read back has caught up.
    Timer {
        id: hold
        interval: 500
    }

    Item {
        id: icon
        width: parent.height
        height: parent.height

        StateLayer {
            radius: Theme.radius.pill
            enabled: slider.pressable && slider.enabled
            onClicked: () => {
                slider.sheet.keyboard = false;
                slider.forceActiveFocus();
                slider.glyphClicked();
            }
        }

        Icon {
            anchors.centerIn: parent
            name: slider.icon
            color: slider.off ? Theme.colors.grey0 : Theme.colors.fg

            Behavior on color {
                CAnim {
                    speed: "fast"
                }
            }
        }
    }

    Item {
        id: track
        x: icon.width + Theme.space.sm
        width: parent.width - x - words.width - Theme.space.lg
        height: parent.height

        Rectangle {
            id: groove
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.colors.bg1

            Rectangle {
                width: Math.max(groove.height, groove.width * slider.shown)
                height: parent.height
                radius: 3
                color: slider.off ? Theme.colors.grey0 : Theme.colors.fg

                Behavior on color {
                    CAnim {
                        speed: "fast"
                    }
                }
            }
        }

        Rectangle {
            property int size: area.containsMouse || area.pressed ? 16 : 12
            x: groove.width * slider.shown - size / 2
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size
            radius: size / 2
            color: slider.off ? Theme.colors.grey0 : Theme.colors.fg
            border.width: 2
            border.color: Theme.colors.bg_dim

            Behavior on size {
                Anim {
                    speed: "fast"
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
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        mono: true
        size: Theme.font.small
        text: slider.label
        color: Theme.colors.grey2
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
