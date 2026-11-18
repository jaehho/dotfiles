// One labelled reading: a name, a thin bar, the value. A null pct is no
// data: the bar is empty and the value a dash.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: meter

    required property var colors
    property string label
    property string value: ""
    // 0 to 100, or -1 for no data.
    property real pct: -1
    property color tint: colors.aqua

    Layout.fillWidth: true
    spacing: 10

    Line {
        Layout.preferredWidth: 44
        text: meter.label
        mono: true
        size: 12
        color: meter.colors.grey2
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 5
        radius: 2.5
        color: meter.colors.bg1

        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, meter.pct)) / 100
            height: parent.height
            radius: parent.radius
            color: meter.colors.withAlpha(meter.tint, 0.85)
            visible: meter.pct >= 0

            Behavior on width {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }

    Line {
        Layout.preferredWidth: 96
        horizontalAlignment: Text.AlignRight
        text: meter.pct >= 0 ? meter.value : "–"
        mono: true
        size: 13
        color: meter.pct >= 0 ? meter.colors.fg : meter.colors.grey2
    }
}
