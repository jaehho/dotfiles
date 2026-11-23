// The tray's sheet: the apps in a grid of cells (TrayCell.qml), laid out
// under the right island's header row, which grows to hold it as it
// does for quick settings (RightIsland.qml). The island is the sheet's
// glass; this only fills it. It opens from the status cluster's
// chevron, on hover or by key, so the island never widens with the
// number of apps. A hovered app's tooltip (unread counts and the like)
// is the bar's tip, under the island.
//
// It holds the keyboard as quick settings does: h/j/k/l (or the arrows)
// move the selection, Tab and Shift+Tab go in order, Enter or Space
// brings the app up and Shift+Enter opens its menu, and Esc or q
// closes. The selection wears quick settings' focus ring while the
// keyboard drives: at once when Super+' opened the grid, else from the
// first key. Each app also has a hint letter (Hints.js): type it to
// bring the app up, Shift and it to open its menu. The letters work
// unseen; f shows them on the apps and hides them again, as does Esc.
// A grid opened by hover has no keyboard, so it takes no keys.
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
    readonly property var codes: Hints.named(items.map(item => bar.trayName(item)), Hints.KEYS)
    // The selected app, kept by identity so an app coming or going
    // doesn't move it; the first while it has gone.
    property var chosen: null
    readonly property int current: Math.max(0, items.indexOf(chosen))
    // The keyboard drives, so the selection's ring shows.
    property bool keyboard: false

    readonly property int columns: 5
    readonly property real cellWidth: (width - tiles.spacing * (columns - 1)) / columns
    readonly property int cellHeight: 68

    implicitHeight: tiles.implicitHeight

    // Left and right stay in the row; down from past the end of a
    // shorter last row lands on its last app.
    function move(dx, dy) {
        const n = grid.items.length;
        const at = grid.current;
        let next = at;
        if (dx !== 0) {
            next = at + dx;
            if (Math.floor(next / grid.columns) !== Math.floor(at / grid.columns))
                return;
        } else {
            next = at + dy * grid.columns;
            if (dy > 0 && next >= n && Math.floor(at / grid.columns) < Math.floor((n - 1) / grid.columns))
                next = n - 1;
        }
        if (next >= 0 && next < n)
            grid.chosen = grid.items[next];
    }

    function cycle(by) {
        const n = grid.items.length;
        if (n > 0)
            grid.chosen = grid.items[(grid.current + by + n) % n];
    }

    onOpenChanged: {
        typed = "";
        hintsShown = false;
        chosen = null;
        keyboard = open && (bar?.trayKeys ?? false);
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
        if (!grid.hinting && event.key !== Qt.Key_Escape)
            return;
        const shift = event.modifiers & Qt.ShiftModifier;
        switch (event.key) {
        case Qt.Key_Escape:
            if (grid.typed !== "")
                grid.typed = "";
            else if (grid.hintsShown)
                grid.hintsShown = false;
            else
                grid.bar.trayOpen = false;
            break;
        case Qt.Key_Q:
            grid.bar.trayOpen = false;
            break;
        case Qt.Key_F:
            grid.hintsShown = !grid.hintsShown;
            break;
        case Qt.Key_Backspace:
            if (grid.typed === "")
                return;
            grid.typed = grid.typed.slice(0, -1);
            break;
        case Qt.Key_J:
        case Qt.Key_Down:
            grid.move(0, 1);
            break;
        case Qt.Key_K:
        case Qt.Key_Up:
            grid.move(0, -1);
            break;
        case Qt.Key_H:
        case Qt.Key_Left:
            grid.move(-1, 0);
            break;
        case Qt.Key_L:
        case Qt.Key_Right:
            grid.move(1, 0);
            break;
        case Qt.Key_Tab:
            grid.cycle(1);
            break;
        case Qt.Key_Backtab:
            grid.cycle(-1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            cells.itemAt(grid.current)?.click(shift ? Qt.RightButton : Qt.LeftButton);
            break;
        default:
            const ch = Hints.letter(event.text, Hints.KEYS);
            if (ch === "")
                return;
            const r = Hints.step(grid.typed, ch, grid.codes);
            grid.typed = r.typed;
            pause.restart();
            if (r.hit >= 0)
                cells.itemAt(r.hit)?.click(shift ? Qt.RightButton : Qt.LeftButton);
        }
        grid.keyboard = true;
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
                ringed: grid.hinting && grid.keyboard && index === grid.current
                // A click leaves the sheet; a right click's menu takes
                // its place.
                onUsed: grid.bar.trayOpen = false
            }
        }
    }
}
