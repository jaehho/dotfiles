// The tip under a hovered control. It is drawn in the bar's own surface,
// below the islands where the input mask lets the pointer through, so it
// needs no popup window and never takes focus. Waybar's tooltip look:
// bg0, 8px corners, the blue edge at 0.28, the bar's mono face.
import QtQuick

Rectangle {
    id: tip

    required property var bar
    // The control it last spoke for, kept while it fades out.
    property Item shown: null
    readonly property Item target: bar.tipFor
    readonly property bool wanted: target !== null && target.tip !== ""

    // From the target itself: `wanted` may not have caught up yet.
    function follow() {
        if (tip.target !== null && tip.target.tip !== "") {
            tip.shown = tip.target;
            tip.place();
        }
    }

    onTargetChanged: follow()
    onWantedChanged: follow()
    onWidthChanged: if (tip.shown)
        tip.place()

    // Centered under the control, kept 8px inside the screen.
    function place() {
        const middle = tip.shown.mapToItem(null, tip.shown.width / 2, 0).x;
        tip.x = Math.round(Math.max(8, Math.min(tip.bar.width - tip.width - 8, middle - tip.width / 2)));
    }

    y: 42
    width: body.width + 20
    height: body.height + 12
    radius: 8
    color: bar.colors.bg0
    border.width: 1
    border.color: bar.colors.withAlpha(bar.colors.blue, 0.28)
    opacity: wanted ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }

    Line {
        id: body
        x: 10
        y: 6
        mono: true
        textFormat: tip.shown?.tipFormat ?? Text.PlainText
        text: tip.shown?.tip ?? ""
        color: tip.bar.colors.fg
    }
}
