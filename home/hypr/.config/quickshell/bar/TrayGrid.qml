// The tray's sheet: the apps in a grid, each with its name, laid out
// under the right island's header row, which grows to hold it as it
// does for quick settings (RightIsland.qml). The island is the sheet's
// glass; this only fills it. It opens from the status cluster's
// chevron, on hover or by key, so the island never widens with the
// number of apps. A hovered app's tooltip (unread counts and the like)
// is the bar's tip, under the island.
//
// From the keyboard (Super+'): h j k l or the arrows pick an app, Enter
// brings it up, Esc closes.
import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: grid

    required property var bar
    readonly property var colors: bar.colors
    required property var items
    property bool open: false
    // The keyboard's pick, or -1.
    property int current: -1

    readonly property int columns: 5
    readonly property real cellWidth: (width - 8) / columns
    readonly property int cellHeight: 54

    implicitHeight: tiles.implicitHeight + 8

    onOpenChanged: {
        current = -1;
        if (open)
            forceActiveFocus();
    }

    function move(step) {
        const last = items.length - 1;
        current = current < 0 ? 0 : Math.max(0, Math.min(last, current + step));
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            grid.bar.trayOpen = false;
            break;
        case Qt.Key_H:
        case Qt.Key_Left:
            grid.move(-1);
            break;
        case Qt.Key_L:
        case Qt.Key_Right:
            grid.move(1);
            break;
        case Qt.Key_J:
        case Qt.Key_Down:
            grid.move(grid.columns);
            break;
        case Qt.Key_K:
        case Qt.Key_Up:
            grid.move(-grid.columns);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            cells.itemAt(grid.current)?.slot.click(Qt.LeftButton);
            break;
        default:
            return;
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
                    selected: grid.current === cell.index
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
                    color: slot.calling ? grid.colors.orange : slot.hovered || slot.selected ? grid.colors.fg : grid.colors.grey2
                }
            }
        }
    }
}
