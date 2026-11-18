// dash's net meter bridge row (MeterRow in Dashboard.qml), one per
// direction: discrete LED cells on an absolute log scale from 32 KiB/s
// (the noise floor: DHCP, mDNS and keepalives read empty) to 150e6 B/s
// (this machine's WiFi PHY), so the run means the same thing every day.
// The 1-min window max is a faint ghost; net has no glance/act band, so
// the ghost only says a burst reached there. No data is a dim socket
// run, never the empty-as-calm track. `showScale` adds the 1 MiB/s and
// 100 MiB/s ticks under the run.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: meter

    required property var colors
    property string arrow: ""
    property string value: ""
    // 0 to 100 on the log scale, or -1 for no data.
    property real pct: -1
    property real peak: -1
    property color tint: colors.aqua
    property bool showScale: false

    // 22 cells, not dash's 30: the run then fits the panel's card.
    readonly property int cells: 22
    readonly property bool haveData: pct >= 0
    readonly property int lit: haveData ? Math.round(Math.max(0, Math.min(100, pct)) / 100 * cells) : 0
    readonly property int ghost: peak >= 0 ? Math.round(Math.max(0, Math.min(100, peak)) / 100 * cells) : 0
    readonly property real runW: cells * 9 + (cells - 1) * 3

    // The scale, for the ticks. Kept here so a row is self-contained.
    function at(bps) {
        const floor = 32 * 1024, ceil = 150e6;
        return bps <= floor ? 0 : Math.max(0, Math.min(1, Math.log10(bps / floor) / Math.log10(ceil / floor)));
    }

    Layout.fillWidth: true
    spacing: 10

    Line {
        Layout.alignment: Qt.AlignTop
        text: meter.arrow
        mono: true
        size: 12
        color: meter.colors.grey2
    }

    Column {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 5
        spacing: 3

        Row {
            spacing: 3

            Repeater {
                model: meter.cells

                Rectangle {
                    required property int index

                    width: 9
                    height: 5
                    radius: 2.5
                    color: !meter.haveData ? meter.colors.withAlpha(meter.colors.grey2, 0.22) : index < meter.lit ? meter.colors.withAlpha(meter.tint, 0.85) : index < meter.ghost ? meter.colors.withAlpha(meter.tint, 0.3) : meter.colors.bg2
                }
            }
        }

        Item {
            visible: meter.showScale
            width: meter.runW
            height: 14

            Repeater {
                model: [[1048576, "1 MiB/s"], [100 * 1048576, "100 MiB/s"]]

                Item {
                    required property var modelData
                    readonly property real tickX: meter.runW * meter.at(modelData[0])

                    Rectangle {
                        x: parent.tickX
                        width: 1
                        height: 4
                        color: meter.colors.grey0
                    }

                    Line {
                        x: parent.tickX - width / 2
                        y: 3
                        text: parent.modelData[1]
                        mono: true
                        size: 10
                        color: meter.colors.grey2
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
    }

    Line {
        Layout.alignment: Qt.AlignTop
        text: meter.value
        mono: true
        size: 13
        color: meter.haveData ? meter.colors.fg : meter.colors.grey2
    }
}
