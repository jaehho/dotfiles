// The quick settings sheet the right island opens into: the main page,
// and pages that open in place under a row back (Wi-Fi, Bluetooth and
// Sound). While open it
// holds the keyboard: j/k and h/l (or the arrows) move between controls,
// h/l step a focused slider, Tab and Shift+Tab go in reading order, Enter
// or Space presses, and Esc or q backs out of a page, then closes. Focus
// rings show while the keyboard drives, and a click puts them away.
// Every control also has a hint letter while the sheet holds the
// keyboard (Hints.js): type it to press the control, or to focus a
// slider, which h and l then step. The letters work unseen; f shows
// them in the controls' corners and hides them again, as does Esc.
//
// The toggles, what the sheet opens and the session row come from
// hypr-settings-menu's table (`--json`), read at start and on each open;
// a press runs the entry through the same script, as the bar's glyphs do.
import QtQuick
import Quickshell
import Quickshell.Io
import "Hints.js" as Hints

FocusScope {
    id: sheet

    required property var bar
    readonly property var colors: bar.colors
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property bool open: false
    property string page: "main"
    // Opened from the keyboard (Super + ;), so the rings show at once.
    property bool keys: false
    property bool keyboard: false
    // The page just backed out of, whose tile takes the keyboard.
    property string from: ""
    // The table's entries, and their states by id, kept apart so that a
    // refresh does not rebuild the controls under the keyboard.
    property var entries: []
    property var states: ({})
    // A pressed toggle shows its new state until a read taken late
    // enough to include it: id -> { state, after }.
    property var pending: ({})
    property bool again: false
    // Hint keys: what has been typed, and [{ item, code }] for the page.
    property string typed: ""
    property var hinted: []
    readonly property bool hinting: open && bar.holding
    // The letters on show (f); they work hidden too.
    property bool hintsShown: false

    readonly property Item current: page === "wifi" ? wifiPage : page === "bluetooth" ? bluetoothPage : page === "sound" ? soundPage : mainPage

    signal pageRequested(string page)
    signal closeRequested

    implicitHeight: current.implicitHeight

    function stateOf(entry) {
        const held = sheet.pending[entry.id];
        return held ? held.state : sheet.states[entry.id] ?? null;
    }

    function run(id) {
        Quickshell.execDetached([sheet.bin + "hypr-settings-menu", id]);
    }

    // What opens a window closes the sheet first.
    function launch(id) {
        sheet.closeRequested();
        sheet.run(id);
    }

    // Delayed and detached, so the sheet is gone before hyprlock
    // screenshots the screen.
    function session(id) {
        sheet.closeRequested();
        Quickshell.execDetached(["sh", "-c", `sleep 0.2; exec "${sheet.bin}hypr-settings-menu" ${id}`]);
    }

    // The keys' own steps and OSD (hypr-level).
    function level(what, steps) {
        for (let i = 0; i < Math.abs(steps); i++)
            Quickshell.execDetached([sheet.bin + "hypr-level", what, steps > 0 ? "up" : "down"]);
    }

    // A toggle's script may act a second later (hypr-dnd-toggle notifies
    // first), so its new state holds until then; a cycle runs inside the
    // script and is read back at once.
    function toggle(entry) {
        const now = Date.now();
        const was = sheet.stateOf(entry);
        const held = Object.assign({}, sheet.pending);
        held[entry.id] = {
            state: entry.kind === "toggle" ? !was : "…",
            after: now + (entry.kind === "toggle" ? 1400 : 200)
        };
        sheet.pending = held;
        sheet.run(entry.id);
        soon.restart();
        late.restart();
    }

    function read() {
        if (table.running) {
            sheet.again = true;
            return;
        }
        table.askedAt = Date.now();
        table.running = true;
    }

    function take(text, askedAt) {
        let list;
        try {
            list = JSON.parse(text);
        } catch (error) {
            return;
        }
        const shape = list.map(e => ({
                    id: e.id,
                    kind: e.kind,
                    icon: e.icon,
                    label: e.label,
                    confirm: e.confirm
                }));
        if (JSON.stringify(shape) !== JSON.stringify(sheet.entries))
            sheet.entries = shape;
        const states = {};
        for (const e of list)
            states[e.id] = e.state;
        sheet.states = states;
        const held = {};
        for (const id in sheet.pending)
            if (sheet.pending[id].after > askedAt)
                held[id] = sheet.pending[id];
        sheet.pending = held;
    }

    // ── the keyboard ──

    // The page's controls, wherever they sit in it.
    function controls() {
        const found = [];
        const walk = item => {
            for (const child of item.children) {
                if (!child.visible)
                    continue;
                if (child.navigable === true) {
                    if (child.enabled)
                        found.push(child);
                } else {
                    walk(child);
                }
            }
        };
        walk(sheet.current);
        return found;
    }

    // Whether a control shows, not scrolled out of a clipped list.
    function shows(item) {
        for (let up = item.parent; up && up !== sheet; up = up.parent) {
            if (up.clip !== true)
                continue;
            const r = item.mapToItem(up, 0, 0, item.width, item.height);
            if (r.y + r.height <= 0 || r.y >= up.height || r.x + r.width <= 0 || r.x >= up.width)
                return false;
        }
        return true;
    }

    // The first words a control shows, for its hint letter.
    function textOf(item) {
        for (const child of item.children) {
            if (child.mono === false && child.text)
                return child.text;
            const inner = sheet.textOf(child);
            if (inner !== "")
                return inner;
        }
        return "";
    }

    // Codes in reading order, kept while the same controls are there.
    function assignHints() {
        const list = sheet.controls().filter(item => sheet.shows(item)).map(item => ({
                    item: item,
                    at: sheet.box(item)
                })).sort((p, q) => Math.abs(p.at.y - q.at.y) > 4 ? p.at.y - q.at.y : p.at.x - q.at.x).map(p => p.item);
        if (list.length === sheet.hinted.length && list.every((item, i) => item === sheet.hinted[i].item))
            return;
        for (const old of sheet.hinted)
            if (old.item)
                old.item.hint = "";
        const codes = Hints.named(list.map(item => item.hintText || sheet.textOf(item)), Hints.KEYS);
        sheet.hinted = list.map((item, i) => ({
                    item: item,
                    code: codes[i]
                }));
        sheet.hinted.forEach(h => h.item.hint = h.code);
    }

    function clearHints() {
        sheet.typed = "";
        typing.stop();
    }

    // One more letter: press the control it completes.
    function typeHint(ch) {
        const r = Hints.step(sheet.typed, ch, sheet.hinted.map(h => h.code));
        sheet.typed = r.typed;
        typing.restart();
        if (r.hit < 0)
            return;
        const item = sheet.hinted[r.hit].item;
        sheet.keyboard = true;
        if (item.slider)
            sheet.reveal(item);
        else
            item.press();
    }

    function focused() {
        for (let item = sheet.Window.activeFocusItem; item && item !== sheet; item = item.parent)
            if (item.navigable === true)
                return item;
        return null;
    }

    function box(item) {
        return item.mapToItem(sheet, 0, 0, item.width, item.height);
    }

    // Focus a control and scroll it into view.
    function reveal(item) {
        if (!item)
            return;
        item.forceActiveFocus();
        for (let up = item.parent; up && up !== sheet; up = up.parent) {
            if (up.contentY === undefined || up.contentItem === undefined)
                continue;
            const at = item.mapToItem(up.contentItem, 0, 0).y;
            if (at < up.contentY)
                up.contentY = at;
            else if (at + item.height > up.contentY + up.height)
                up.contentY = at + item.height - up.height;
            break;
        }
    }

    // The nearest control that way. Up and down prefer the next row and,
    // in it, what lines up (the leftmost of several under a wide one);
    // left and right stay in the row.
    function move(dx, dy) {
        const all = sheet.controls();
        const here = sheet.focused();
        if (!here) {
            sheet.reveal(all[0] ?? null);
            return;
        }
        const a = sheet.box(here);
        let best = null;
        let bestScore = Infinity;
        for (const item of all) {
            if (item === here)
                continue;
            const b = sheet.box(item);
            let score;
            if (dy !== 0) {
                const ahead = dy > 0 ? b.y + b.height / 2 > a.y + a.height / 2 + 1 : b.y + b.height / 2 < a.y + a.height / 2 - 1;
                if (!ahead)
                    continue;
                const gap = Math.max(0, dy > 0 ? b.y - (a.y + a.height) : a.y - (b.y + b.height));
                const middle = b.x + b.width / 2;
                const off = Math.abs(middle - Math.max(a.x, Math.min(a.x + a.width, middle)));
                score = gap * 4 + off + b.x / 10000;
            } else {
                const overlap = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
                const ahead = dx > 0 ? b.x + b.width / 2 > a.x + a.width / 2 + 1 : b.x + b.width / 2 < a.x + a.width / 2 - 1;
                if (!ahead || overlap <= 0)
                    continue;
                score = Math.max(0, dx > 0 ? b.x - (a.x + a.width) : a.x - (b.x + b.width));
            }
            if (score < bestScore) {
                bestScore = score;
                best = item;
            }
        }
        if (best)
            sheet.reveal(best);
    }

    // Tab order: by row, then left to right.
    function cycle(by) {
        const all = sheet.controls().map(item => ({
                    item: item,
                    at: sheet.box(item)
                })).sort((p, q) => Math.abs(p.at.y - q.at.y) > 4 ? p.at.y - q.at.y : p.at.x - q.at.x).map(p => p.item);
        if (all.length === 0)
            return;
        const at = all.indexOf(sheet.focused());
        sheet.reveal(all[at < 0 ? 0 : (at + by + all.length) % all.length]);
    }

    function back() {
        if (sheet.page !== "main") {
            sheet.from = sheet.page;
            sheet.pageRequested("main");
        } else {
            sheet.closeRequested();
        }
    }

    // The page's first control, once its layout has settled; back on the
    // main page, the tile that opened the page.
    function settle() {
        Qt.callLater(() => {
            const tile = sheet.page === "main" && sheet.from !== "" ? mainPage.tileFor(sheet.from) : null;
            sheet.from = "";
            const item = tile ?? sheet.current.first();
            if (item)
                sheet.reveal(item);
            else
                sheet.forceActiveFocus();
        });
    }

    onOpenChanged: {
        sheet.clearHints();
        sheet.hintsShown = false;
        if (open) {
            sheet.keyboard = sheet.keys;
            sheet.read();
            sheet.settle();
        }
    }
    onPageChanged: {
        sheet.clearHints();
        if (open)
            sheet.settle();
    }

    // Pinned by a click: the keyboard is the sheet's now.
    Connections {
        target: sheet.bar

        function onByHoverChanged() {
            if (sheet.open && !sheet.bar.byHover)
                sheet.settle();
        }
    }

    // Controls come and go (a scan's networks), and pages settle late.
    Timer {
        interval: 250
        repeat: true
        triggeredOnStart: true
        running: sheet.hinting
        onTriggered: sheet.assignHints()
    }

    // A half-typed code is dropped after a pause.
    Timer {
        id: typing
        interval: 1500
        onTriggered: sheet.typed = ""
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        const here = sheet.focused();
        switch (event.key) {
        case Qt.Key_Escape:
            if (sheet.typed !== "")
                sheet.clearHints();
            else if (sheet.hintsShown)
                sheet.hintsShown = false;
            else
                sheet.back();
            break;
        case Qt.Key_F:
            if (!sheet.hinting)
                return;
            sheet.hintsShown = !sheet.hintsShown;
            break;
        case Qt.Key_Q:
            sheet.back();
            break;
        case Qt.Key_Backspace:
            if (sheet.typed === "")
                return;
            sheet.typed = sheet.typed.slice(0, -1);
            break;
        case Qt.Key_J:
        case Qt.Key_Down:
            sheet.move(0, 1);
            break;
        case Qt.Key_K:
        case Qt.Key_Up:
            sheet.move(0, -1);
            break;
        case Qt.Key_H:
        case Qt.Key_Left:
            if (here?.slider)
                here.step(-1);
            else
                sheet.move(-1, 0);
            break;
        case Qt.Key_L:
        case Qt.Key_Right:
            if (here?.slider)
                here.step(1);
            else
                sheet.move(1, 0);
            break;
        case Qt.Key_Tab:
            sheet.cycle(1);
            break;
        case Qt.Key_Backtab:
            sheet.cycle(-1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            here?.press();
            break;
        default:
            const ch = Hints.letter(event.text, Hints.KEYS);
            if (ch === "" || !sheet.hinting)
                return;
            sheet.typeHint(ch);
        }
        sheet.keyboard = true;
        event.accepted = true;
    }

    Process {
        id: table
        property real askedAt: 0
        command: [sheet.bin + "hypr-settings-menu", "--json"]
        stdout: StdioCollector {
            onStreamFinished: sheet.take(text, table.askedAt)
        }
        onExited: if (sheet.again) {
            sheet.again = false;
            sheet.read();
        }
    }

    Component.onCompleted: sheet.read()

    Timer {
        id: soon
        interval: 450
        onTriggered: sheet.read()
    }

    Timer {
        id: late
        interval: 1700
        onTriggered: sheet.read()
    }

    QuickMain {
        id: mainPage
        sheet: sheet
        width: parent.width
        opacity: sheet.page === "main" ? 1 : 0
        visible: opacity > 0
        enabled: sheet.page === "main"

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    QuickWifi {
        id: wifiPage
        sheet: sheet
        width: parent.width
        shown: sheet.open && sheet.page === "wifi"
        opacity: sheet.page === "wifi" ? 1 : 0
        visible: opacity > 0
        enabled: sheet.page === "wifi"

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    QuickBluetooth {
        id: bluetoothPage
        sheet: sheet
        width: parent.width
        shown: sheet.open && sheet.page === "bluetooth"
        opacity: sheet.page === "bluetooth" ? 1 : 0
        visible: opacity > 0
        enabled: sheet.page === "bluetooth"

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    QuickSound {
        id: soundPage
        sheet: sheet
        width: parent.width
        shown: sheet.open && sheet.page === "sound"
        opacity: sheet.page === "sound" ? 1 : 0
        visible: opacity > 0
        enabled: sheet.page === "sound"

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
}
