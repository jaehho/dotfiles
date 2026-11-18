// One quota on the LLM card, ported from dash's StatRow: the name, its
// window ("week"), "25% · 3d 12h left", and a bar as long as the use.
// The tick is the even-burn pace (where use would be if spread evenly
// to the reset); the span between use and tick is faint green when
// under it (reserve), amber past it (risk), red when it burns to 100
// before the reset (exhaust). A stale snapshot draws no pace and dims.
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    required property var colors
    property string name
    property string win: ""
    property string value
    property color valueColor: colors.fg
    // 0 to 100, or -1 for no bar.
    property real pct: -1
    // The even-burn %, or -1 for no tick.
    property real pacePct: -1
    // ok | reserve | risk | exhaust | stale
    property string paceLevel: ""
    property string url: ""

    signal launch(string url, var cmd)

    readonly property bool stale: paceLevel === "stale"
    readonly property bool hasPace: pacePct >= 0 && pct >= 0
    readonly property real used: Math.min(1, Math.max(0, pct / 100))
    readonly property real pace: Math.min(1, Math.max(0, pacePct / 100))
    // On pace, the bar is all use; off it, the core ends at the nearer
    // of use and tick and the span shows the difference.
    readonly property real core: !hasPace || paceLevel === "ok" ? used : Math.min(used, pace)
    readonly property color deltaColor: paceLevel === "reserve" ? colors.withAlpha(colors.green, 0.4) : paceLevel === "risk" ? colors.yellow : paceLevel === "exhaust" ? colors.red : colors.grey2

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Line {
                Layout.fillWidth: true
                text: row.name
                mono: true
                color: row.colors.fg
                elide: Text.ElideRight
            }

            Line {
                visible: row.win !== ""
                text: row.win
                mono: true
                size: 11
                color: row.colors.grey2
                font.letterSpacing: 1
            }

            // The widest value, so the window chips line up down the card.
            TextMetrics {
                id: slot
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                text: "100% · 29d 23h left"
            }

            Line {
                Layout.minimumWidth: row.win !== "" ? slot.width : 0
                horizontalAlignment: Text.AlignRight
                text: row.value
                mono: true
                color: row.stale ? row.colors.yellow : row.valueColor
            }
        }

        Rectangle {
            visible: row.pct >= 0
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            radius: 2.5
            color: row.colors.bg2
            opacity: row.stale ? 0.45 : 1

            Rectangle {
                width: parent.width * row.core
                height: parent.height
                radius: 2.5
                color: row.colors.grey2
            }

            Rectangle {
                visible: row.hasPace && row.paceLevel !== "ok"
                x: parent.width * Math.min(row.used, row.pace)
                width: parent.width * Math.abs(row.used - row.pace)
                height: parent.height
                radius: 2.5
                color: row.deltaColor
            }

            Rectangle {
                visible: row.hasPace
                x: parent.width * row.pace - 0.5
                y: -4
                width: 1
                height: 13
                color: row.colors.grey2
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.url !== ""
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.launch(row.url, null)
    }
}
