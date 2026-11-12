// The tray, as a sheet under the bar like BarMenu: the apps in a grid,
// each with its name, and a footer that says what the hovered one says
// in its tooltip (unread counts and the like). It opens from the status
// cluster's chevron, so the island never grows with the number of apps.
// An app asking for attention is also shown beside the chevron while
// this is shut (StatusCluster.qml). A click outside or Esc closes it,
// as the bar's focus grab does for the menus.
import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray

Item {
    id: grid

    required property var bar
    readonly property var colors: bar.colors
    required property var items
    property bool open: false
    // The island it hangs from, flush with its right edge.
    property Item anchor: null
    property var hoveredItem: null

    readonly property int columns: 4
    readonly property int cellWidth: 80
    readonly property int cellHeight: 58

    // "Bitwarden_status_icon_1" -> "Bitwarden", "spotify-client" ->
    // "Spotify", "openclaw-browser" -> "Openclaw": the id's first word,
    // less what apps add to it.
    function label(item) {
        const name = item.id.replace(/[-_]?(status_icon|systray_icon|client|tray)[-_]?\d*$/i, "").split(/[-_ ]/)[0];
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function place() {
        if (!grid.anchor)
            return;
        const right = grid.anchor.mapToItem(null, grid.anchor.width, 0).x;
        grid.x = Math.round(Math.max(8, Math.min(grid.bar.width - grid.width - 8, right - grid.width)));
    }

    onOpenChanged: if (open) {
        grid.hoveredItem = null;
        grid.place();
        grid.forceActiveFocus();
    }
    onWidthChanged: place()

    y: open ? 42 : 36
    width: columns * cellWidth + 8
    height: tiles.implicitHeight + 28
    opacity: open ? 1 : 0
    visible: opacity > 0
    enabled: open

    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Keys.onEscapePressed: grid.bar.trayOpen = false

    RectangularShadow {
        anchors.fill: parent
        radius: 12
        blur: 6
        color: grid.colors.withAlpha(grid.colors.bg_dim, 0.93)
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: grid.colors.withAlpha(grid.colors.bg_dim, 0.985)
        border.width: 1
        border.color: grid.colors.withAlpha(grid.colors.blue, 0.18)
    }

    Grid {
        id: tiles
        x: 4
        y: 4
        columns: grid.columns

        Repeater {
            model: grid.items

            Item {
                id: cell

                required property var modelData

                width: grid.cellWidth
                height: grid.cellHeight

                TraySlot {
                    id: slot
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    bar: grid.bar
                    item: cell.modelData
                    tips: false
                    onHoveredChanged: {
                        if (hovered)
                            grid.hoveredItem = cell.modelData;
                        else if (grid.hoveredItem === cell.modelData)
                            grid.hoveredItem = null;
                    }
                    // Left and middle click leave the sheet; a right
                    // click's menu takes its place.
                    onUsed: grid.bar.trayOpen = false
                }

                Line {
                    anchors.top: slot.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    size: 11
                    text: grid.label(cell.modelData)
                    color: slot.calling ? grid.colors.orange : slot.hovered ? grid.colors.fg : grid.colors.grey2
                }
            }
        }
    }

    Rectangle {
        x: 12
        y: tiles.y + tiles.implicitHeight + 2
        width: parent.width - 24
        height: 1
        color: grid.colors.bg1
    }

    Line {
        id: footer
        x: 12
        y: tiles.y + tiles.implicitHeight + 8
        width: parent.width - 24
        height: 16
        elide: Text.ElideRight
        size: 11
        textFormat: Text.PlainText
        // First line only: Betterbird's tooltip runs on to a folder list.
        text: grid.hoveredItem ? ((grid.hoveredItem.tooltipTitle || grid.hoveredItem.title || grid.hoveredItem.id).split("\n")[0]) : `${grid.items.length} apps in the tray`
        color: grid.hoveredItem ? grid.colors.fg : grid.colors.grey1
    }
}
