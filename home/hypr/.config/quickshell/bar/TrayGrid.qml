// The tray's sheet: the apps in a grid, each with its name, laid out
// under the right island's header row, which grows to hold it as it
// does for quick settings (RightIsland.qml). The island is the sheet's
// glass; this only fills it. It opens from the status cluster's
// chevron, on hover or by key, so the island never widens with the
// number of apps. A hovered app's tooltip (unread counts and the like)
// is the bar's tip, under the island.
//
// From the keyboard (Super+'), each app carries a hint letter (Hints.js):
// type it to bring the app up, Shift and it to open its menu. Esc closes.
// A grid opened by hover has no keyboard, so it shows no letters.
import QtQuick
import Quickshell.Services.SystemTray
import "Hints.js" as Hints

Item {
    id: grid

    required property var bar
    readonly property var colors: bar.colors
    required property var items
    property bool open: false
    property string typed: ""
    readonly property bool hinting: open && bar.holding
    readonly property var codes: Hints.named(items.map(item => bar.trayName(item)), Hints.ALL)

    readonly property int columns: 5
    readonly property real cellWidth: (width - 8) / columns
    readonly property int cellHeight: 54

    implicitHeight: tiles.implicitHeight + 8

    onOpenChanged: {
        typed = "";
        if (open)
            forceActiveFocus();
    }

    // Pinned by a click: the keyboard is the grid's now.
    Connections {
        target: grid.bar

        function onByHoverChanged() {
            if (grid.open && !grid.bar.byHover)
                grid.forceActiveFocus();
        }
    }

    // A letter that starts no code is dropped, and so is a half-typed
    // one after a pause.
    Timer {
        id: pause
        interval: 1500
        onTriggered: grid.typed = ""
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        if (event.key === Qt.Key_Escape) {
            if (grid.typed !== "")
                grid.typed = "";
            else
                grid.bar.trayOpen = false;
        } else if (event.key === Qt.Key_Backspace && grid.typed !== "") {
            grid.typed = grid.typed.slice(0, -1);
        } else {
            const ch = Hints.letter(event.text, Hints.ALL);
            if (ch === "" || !grid.hinting)
                return;
            const r = Hints.step(grid.typed, ch, grid.codes);
            grid.typed = r.typed;
            pause.restart();
            if (r.hit >= 0)
                cells.itemAt(r.hit)?.slot.click(event.modifiers & Qt.ShiftModifier ? Qt.RightButton : Qt.LeftButton);
        }
        event.accepted = true;
    }

    Grid {
        id: tiles
        x: 4
        y: 4
        columns: grid.columns

        Repeater {
            id: cells
            model: grid.items

            Item {
                id: cell

                required property var modelData
                required property int index
                readonly property alias slot: slot

                width: grid.cellWidth
                height: grid.cellHeight

                TraySlot {
                    id: slot
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 3
                    bar: grid.bar
                    item: cell.modelData
                    hint: grid.codes[cell.index] ?? ""
                    typed: grid.typed
                    hinting: grid.hinting
                    // A click leaves the sheet; a right click's menu
                    // takes its place.
                    onUsed: grid.bar.trayOpen = false
                }

                Line {
                    anchors.top: slot.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 4
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    size: 11
                    text: grid.bar.trayName(cell.modelData)
                    color: slot.calling ? grid.colors.orange : slot.hovered ? grid.colors.fg : grid.colors.grey2
                }
            }
        }
    }
}
