// The tray's sheet: the apps in a grid of cells (TrayCell.qml), laid out
// under the right island's header row, which grows to hold it as it
// does for quick settings (RightIsland.qml). The island is the sheet's
// glass; this only fills it. It opens from the status cluster's
// chevron, on hover or by key, so the island never widens with the
// number of apps. A hovered app's tooltip (unread counts and the like)
// is the bar's tip, under the island.
//
// From the keyboard (Super+'), each app has a hint letter (Hints.js):
// type it to bring the app up, Shift and it to open its menu. The
// letters work unseen; f shows them on the apps and hides them again,
// as does Esc, which otherwise closes. A grid opened by hover has no
// keyboard, so it takes no letters.
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
    // The letters on show (f); they work hidden too.
    property bool hintsShown: false
    readonly property var codes: Hints.named(items.map(item => bar.trayName(item)), Hints.ALL)

    readonly property int columns: 5
    readonly property real cellWidth: (width - tiles.spacing * (columns - 1)) / columns
    readonly property int cellHeight: 68

    implicitHeight: tiles.implicitHeight

    onOpenChanged: {
        typed = "";
        hintsShown = false;
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
            else if (grid.hintsShown)
                grid.hintsShown = false;
            else
                grid.bar.trayOpen = false;
        } else if (event.key === Qt.Key_F && !(event.modifiers & Qt.ShiftModifier)) {
            if (!grid.hinting)
                return;
            grid.hintsShown = !grid.hintsShown;
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
                cells.itemAt(r.hit)?.click(event.modifiers & Qt.ShiftModifier ? Qt.RightButton : Qt.LeftButton);
        }
        event.accepted = true;
    }

    Grid {
        id: tiles
        columns: grid.columns
        spacing: Theme.space.xs

        Repeater {
            id: cells
            model: grid.items

            TrayCell {
                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight
                bar: grid.bar
                item: modelData
                hint: grid.codes[index] ?? ""
                typed: grid.typed
                hinting: grid.hinting && grid.hintsShown
                // A click leaves the sheet; a right click's menu takes
                // its place.
                onUsed: grid.bar.trayOpen = false
            }
        }
    }
}
