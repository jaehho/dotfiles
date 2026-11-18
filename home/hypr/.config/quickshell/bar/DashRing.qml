// dash's field-equipment LED ring (~/projects/dash qml/LedRing.qml),
// sized by `diameter` so four fit across the panel: 24 cells on a 270°
// arc, gap at 6 o'clock. Lit cells are the reading; past it the 1-min
// window max keeps its cells faint (0.30), the peak-hold ghost, so a
// spike that already passed still shows in the band it reached. Cells
// take the status ladder by their place on the scale; the hue is only
// the series. The readout sits in the bottom gap, the label under it.
//
// pct and peak are percent of the ring's scale; pct < 0 parks it (an
// idle dGPU, a down feed), peak < 0 shows no ghost.
import QtQuick
import QtQuick.Layouts

Item {
    id: ring

    required property var colors
    property real diameter: 92
    property real pct: -1
    property real peak: -1
    property real amberAt: 70
    property real redAt: 90
    property color hue: colors.blue
    property string value: ""
    property string unit: ""
    property color valueColor: colors.fg
    property string label: ""

    readonly property int cells: 24
    readonly property int lit: pct >= 0 ? Math.round(Math.max(0, Math.min(100, pct)) / 100 * cells) : 0
    readonly property int ghost: peak >= 0 ? Math.round(Math.max(0, Math.min(100, peak)) / 100 * cells) : 0
    // dash drew it at 116px; everything scales from there.
    readonly property real k: diameter / 116

    implicitWidth: diameter
    implicitHeight: diameter + 22

    Item {
        id: dial
        width: ring.diameter
        height: ring.diameter

        Repeater {
            model: ring.cells

            Rectangle {
                required property int index

                // 0° is 3 o'clock, clockwise.
                readonly property real ang: 135 + 270 * (index + 0.5) / ring.cells
                readonly property real pos: 100 * index / (ring.cells - 1)
                readonly property bool on: index < ring.lit
                readonly property bool faint: index < ring.ghost
                readonly property real al: on ? 0.9 : 0.3

                width: 14 * ring.k
                height: Math.max(4, 6 * ring.k)
                radius: height / 2
                x: dial.width / 2 + 46 * ring.k * Math.cos(ang * Math.PI / 180) - width / 2
                y: dial.height / 2 + 46 * ring.k * Math.sin(ang * Math.PI / 180) - height / 2
                rotation: ang
                color: !on && !faint ? ring.colors.bg2 : ring.colors.withAlpha(pos >= ring.redAt ? ring.colors.red : pos >= ring.amberAt ? ring.colors.yellow : ring.hue, al)
            }
        }

        Column {
            width: dial.width
            anchors.bottom: dial.bottom
            anchors.bottomMargin: 1
            spacing: -1

            Line {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: ring.value
                mono: true
                size: Math.round(18 * ring.k)
                color: ring.valueColor
            }

            Line {
                visible: ring.unit !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: ring.unit
                mono: true
                size: 10
                color: ring.colors.grey2
            }
        }
    }

    RowLayout {
        anchors.top: dial.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: dial.horizontalCenter
        spacing: 7

        Rectangle {
            Layout.preferredWidth: 6
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            radius: 3
            color: ring.hue
        }

        Line {
            text: ring.label
            mono: true
            size: 12
            color: ring.colors.grey2
            font.letterSpacing: 1
        }
    }
}
