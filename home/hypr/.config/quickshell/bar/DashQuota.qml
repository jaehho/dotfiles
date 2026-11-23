// One quota on the LLM card, ported from dash's StatRow: the name, its
// window ("week"), "25% · 3d 12h left", and a bar as long as the use.
// The tick is the even-burn pace (where use would be if spread evenly
// to the reset); the span between use and tick is faint green when
// under it (reserve), amber past it (risk), red when it burns to 100
// before the reset (exhaust). A stale snapshot draws no pace and dims.
//
// On the shell base (#89): the name and value in Mono, the window in
// words; one with a page to open washes as a block (DashRow).
import QtQuick
import QtQuick.Layouts

DashRow {
    id: row

    property string name
    property string win: ""
    property string value
    property color valueColor: Theme.colors.fg
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
    readonly property color deltaColor: paceLevel === "reserve" ? Theme.colors.withAlpha(Theme.colors.green, 0.4) : paceLevel === "risk" ? Theme.colors.yellow : paceLevel === "exhaust" ? Theme.colors.red : Theme.colors.grey2

    implicitHeight: col.implicitHeight
    radius: Theme.radius.control
    bleed: Theme.space.xs
    interactive: url !== ""
    onClicked: row.launch(row.url, null)

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.space.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.sm

            Line {
                Layout.fillWidth: true
                text: row.name
                mono: true
                color: Theme.colors.fg
                elide: Text.ElideRight
            }

            Line {
                visible: row.win !== ""
                text: row.win
                size: Theme.font.small
                color: Theme.colors.grey2
            }

            // The widest value, so the windows line up down the card.
            TextMetrics {
                id: slot
                font.family: Theme.font.mono
                font.pixelSize: Theme.font.body
                text: "100% · 29d 23h left"
            }

            Line {
                Layout.minimumWidth: row.win !== "" ? slot.width : 0
                horizontalAlignment: Text.AlignRight
                text: row.value
                mono: true
                color: row.stale ? Theme.colors.yellow : row.valueColor
            }
        }

        // The meter: a 4px pill, the use in grey2 on bg2.
        Rectangle {
            visible: row.pct >= 0
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            radius: Theme.radius.pill
            color: Theme.colors.bg2
            opacity: row.stale ? 0.45 : 1

            Rectangle {
                width: parent.width * row.core
                height: parent.height
                radius: Theme.radius.pill
                color: Theme.colors.grey2
            }

            Rectangle {
                visible: row.hasPace && row.paceLevel !== "ok"
                x: parent.width * Math.min(row.used, row.pace)
                width: parent.width * Math.abs(row.used - row.pace)
                height: parent.height
                radius: Theme.radius.pill
                color: row.deltaColor
            }

            Rectangle {
                visible: row.hasPace
                x: parent.width * row.pace - 0.5
                y: -4
                width: 1
                height: 12
                color: Theme.colors.grey2
            }
        }
    }
}
