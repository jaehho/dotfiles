pragma ComponentBehavior: Bound

// The keybind sheet (#89), which replaced the GTK4 one: every key this
// machine binds (Keybinds.qml reads them), in two views, switched by Tab
// or the toggles at the header's end, and remembered:
//
// - list: groups by the prefix you hold, in balanced columns. Typing
//   filters; holding modifiers narrows to the binds of exactly that chord
//   (a query wins, since typing capitals needs Shift).
// - keyboard: the binds filed by physical key. A key is solid blue when
//   it does something with what is held now (or latched by a click on a
//   modifier cap), raised when it needs another modifier, flat when
//   unbound. The switch above it picks Normal or a mode the board shows
//   instead (tmux's prefix). Hovering, clicking or pressing a key lists
//   its binds under the board.
//
// Bare Esc closes and bare Tab switches views; with a modifier held they
// are chords to look up. In the keyboard view the window suspends
// Hyprland's binds (KeybindsWindow.qml), so Super+/ closes from here.
//
// Modifiers are tracked by their own presses and releases: the bare
// Super press reaches the sheet, but no modifier state does.
import QtQuick
import QtQuick.Layouts

Sheet {
    id: sheet

    property bool open: false
    property string query: ""
    // Tallest the list grows before it scrolls.
    property real maxListHeight: 700
    readonly property string view: Keybinds.view
    readonly property var table: Keybinds.table
    readonly property var order: table?.chordOrder ?? ["Super", "Ctrl", "Alt", "Shift"]

    // Modifiers physically down, and those clicked on in the keyboard
    // view (Super + click is Hyprland's window drag, so holding Super
    // can't be combined with clicking).
    property var held: []
    property var latched: []
    // The keyboard view's mode ("", "resize", "tmux"), the key whose binds
    // show, and the key under the pointer, which shows first.
    property string mode: ""
    property string selected: ""
    property string hover: ""

    readonly property var holding: chord(held.concat(latched))
    readonly property var modCaps: ({
            super: "Super",
            ctrl: "Ctrl",
            alt: "Alt",
            shift: "Shift"
        })

    // The list view: what the filter keeps of each group, by index.
    readonly property var words: query.trim().toLowerCase().split(/\s+/).filter(w => w !== "")
    readonly property string narrow: words.length > 0 ? "" : chord(held).join("+")
    readonly property var kept: (table?.groups ?? []).map(group => group.rows.filter(row => {
            const hay = (group.name + " " + row.keys.join(" ") + " " + row.label).toLowerCase();
            return words.every(w => hay.includes(w)) && (narrow === "" || row.chord.join("+") === narrow);
        }))
    readonly property int total: (table?.groups ?? []).reduce((n, group) => n + group.rows.length, 0)
    readonly property int shown: kept.reduce((n, rows) => n + rows.length, 0)

    // The keyboard view: the keys bound in this mode with what is held
    // now (here) or with anything (near), and how many binds that is.
    readonly property var lit: {
        const here = {};
        const near = {};
        let count = 0;
        const key = holding.join("+");
        for (const entry of table?.board ?? []) {
            if (entry.mode !== mode)
                continue;
            near[entry.cap] = true;
            if (entry.mods.join("+") === key) {
                here[entry.cap] = true;
                count += entry.binds.length;
            }
        }
        return {
            here: here,
            near: near,
            count: count,
            keys: Object.keys(here).length
        };
    }
    readonly property string pointed: hover !== "" ? hover : selected
    // The pointed key's binds in this mode, the ones that need another
    // modifier after the ones that fire now.
    readonly property var binds: {
        if (pointed === "" || modCaps[pointed])
            return [];
        const key = holding.join("+");
        const out = [];
        for (const entry of table?.board ?? [])
            if (entry.mode === mode && entry.cap === pointed)
                for (const bind of entry.binds)
                    out.push({
                        combo: bind.combo,
                        label: bind.label,
                        note: bind.note,
                        now: entry.mods.join("+") === key,
                        size: entry.mods.length
                    });
        return out.sort((a, b) => (a.now === b.now ? 0 : a.now ? -1 : 1) || a.size - b.size);
    }
    readonly property var keys: table?.keys ?? []
    readonly property int pitch: 50
    readonly property int gap: 5
    readonly property real boardWidth: keys.reduce((w, k) => Math.max(w, (k.x + k.w) * pitch - gap), 0)
    readonly property real boardHeight: keys.reduce((h, k) => Math.max(h, (k.y + k.h) * pitch - gap), 0)

    signal closeRequested

    implicitWidth: Math.max(header.implicitWidth, view === "list" ? listBody.implicitWidth : boardWidth) + Theme.space.md * 2
    implicitHeight: column.implicitHeight + Theme.space.md * 2

    // A set of modifiers in the sheet's order, Super first.
    function chord(mods) {
        return sheet.order.filter(m => mods.includes(m));
    }

    function legend(cap) {
        return sheet.table?.legends?.[cap] ?? cap;
    }

    function modOf(key) {
        switch (key) {
        case Qt.Key_Super_L:
        case Qt.Key_Super_R:
        case Qt.Key_Meta:
            return "Super";
        case Qt.Key_Control:
            return "Ctrl";
        case Qt.Key_Alt:
        case Qt.Key_AltGr:
            return "Alt";
        case Qt.Key_Shift:
            return "Shift";
        }
        return "";
    }

    // The cap a key press names: its unshifted legend, so Shift + / still
    // finds the / cap.
    function capOf(event) {
        const k = event.key;
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12)
            return "f" + (k - Qt.Key_F1 + 1);
        switch (k) {
        case Qt.Key_Escape:
            return "esc";
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            return "tab";
        case Qt.Key_Backspace:
            return "backspace";
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "enter";
        case Qt.Key_Space:
            return "space";
        case Qt.Key_Left:
            return "left";
        case Qt.Key_Right:
            return "right";
        case Qt.Key_Up:
            return "up";
        case Qt.Key_Down:
            return "down";
        case Qt.Key_PageUp:
            return "pgup";
        case Qt.Key_PageDown:
            return "pgdn";
        case Qt.Key_Delete:
            return "delete";
        case Qt.Key_Print:
            return "print";
        case Qt.Key_CapsLock:
            return "caps";
        case Qt.Key_VolumeUp:
            return "xf86audioraisevolume";
        case Qt.Key_VolumeDown:
            return "xf86audiolowervolume";
        case Qt.Key_VolumeMute:
            return "xf86audiomute";
        case Qt.Key_MicMute:
            return "xf86audiomicmute";
        case Qt.Key_MonBrightnessUp:
            return "xf86monbrightnessup";
        case Qt.Key_MonBrightnessDown:
            return "xf86monbrightnessdown";
        case Qt.Key_MediaNext:
            return "xf86audionext";
        case Qt.Key_MediaPrevious:
            return "xf86audioprev";
        case Qt.Key_MediaPlay:
            return "xf86audioplay";
        case Qt.Key_MediaPause:
            return "xf86audiopause";
        case Qt.Key_Calculator:
            return "xf86calculator";
        }
        if (k < 0x20 || k >= 0x7f)
            return "";
        const ch = String.fromCharCode(k).toLowerCase();
        const at = '~!@#$%^&*()_+{}|:"<>?'.indexOf(ch);
        return at >= 0 ? "`1234567890-=[]\\;',./"[at] : ch;
    }

    // A key press, from the field or the board; true when the sheet took it.
    function press(event) {
        const mod = sheet.modOf(event.key);
        if (mod !== "") {
            if (!sheet.held.includes(mod))
                sheet.held = sheet.chord(sheet.held.concat([mod]));
            return false;
        }
        const bare = sheet.held.length === 0 || sheet.view === "list";
        if ((event.key === Qt.Key_Escape && bare) || (event.key === Qt.Key_Slash && sheet.held.join("+") === "Super")) {
            sheet.closeRequested();
            return true;
        }
        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && bare) {
            Keybinds.setView(sheet.view === "keyboard" ? "list" : "keyboard");
            return true;
        }
        if (sheet.view === "keyboard") {
            const cap = sheet.capOf(event);
            if (cap !== "" && sheet.keys.some(k => k.cap === cap)) {
                sheet.selected = cap;
                sheet.hover = "";
                return true;
            }
        }
        return false;
    }

    function release(event) {
        const mod = sheet.modOf(event.key);
        if (mod !== "")
            sheet.held = sheet.held.filter(m => m !== mod);
    }

    // The keyboard goes to the field in the list view and to the board in
    // the keyboard view.
    function takeKeys() {
        if (sheet.view === "list")
            input.forceActiveFocus();
        else
            catcher.forceActiveFocus();
    }

    onOpenChanged: {
        if (!open)
            return;
        input.text = "";
        sheet.held = [];
        sheet.latched = [];
        sheet.mode = "";
        sheet.selected = "";
        sheet.hover = "";
        scroller.contentY = 0;
        sheet.takeKeys();
    }
    onViewChanged: if (open)
        sheet.takeKeys()

    // A key released elsewhere would leave its modifier stuck on.
    readonly property bool hasKeys: input.activeFocus || catcher.activeFocus
    onHasKeysChanged: if (!hasKeys)
        sheet.held = []

    Item {
        id: catcher
        Keys.onPressed: event => {
            if (sheet.press(event))
                event.accepted = true;
        }
        Keys.onReleased: event => sheet.release(event)
    }

    // The width and height animate between the views; the content clips
    // to them, the shadow does not.
    Item {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            id: column

            x: Theme.space.md
            y: Theme.space.md
            width: sheet.width - Theme.space.md * 2
            spacing: Theme.space.md

            RowLayout {
                id: header

                Layout.fillWidth: true
                spacing: Theme.space.md

                // DESIGN.md's field, with a search icon at its start.
                Rectangle {
                    visible: sheet.view === "list"
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 36
                    radius: Theme.radius.control
                    color: Theme.colors.bg0
                    border.width: 1
                    border.color: input.activeFocus ? Theme.colors.blue : Theme.colors.bg2

                    Icon {
                        id: glass
                        x: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        color: Theme.colors.grey2
                    }

                    TextInput {
                        id: input

                        anchors.fill: parent
                        anchors.leftMargin: glass.x + glass.width + Theme.space.sm
                        anchors.rightMargin: Theme.space.md
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.colors.fg
                        selectionColor: Theme.colors.withAlpha(Theme.colors.blue, 0.35)
                        selectedTextColor: Theme.colors.fg
                        selectByMouse: true
                        font.family: Theme.font.sans
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        onTextChanged: sheet.query = text
                        Keys.onPressed: event => {
                            if (sheet.press(event))
                                event.accepted = true;
                        }
                        Keys.onReleased: event => sheet.release(event)

                        cursorDelegate: Rectangle {
                            width: 1
                            color: Theme.colors.blue
                            visible: input.activeFocus
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === "" && input.preeditText === ""
                            text: "Filter"
                            color: Theme.colors.grey2
                            font: input.font
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // The mode switch stands where the filter does.
                ModeSwitch {
                    visible: sheet.view === "keyboard"
                }

                Item {
                    Layout.fillWidth: true
                }

                // What is held, as the prefix caps.
                Row {
                    spacing: 3

                    Repeater {
                        model: sheet.view === "keyboard" ? sheet.holding : sheet.held

                        Keycap {
                            required property string modelData

                            text: modelData
                            prefix: true
                        }
                    }
                }

                Line {
                    size: Theme.font.small
                    color: Theme.colors.grey2
                    text: sheet.view === "keyboard" ? sheet.lit.count + " binds on " + sheet.lit.keys + " keys" : sheet.shown === sheet.total ? sheet.total + " binds" : sheet.shown + " of " + sheet.total
                }

                Row {
                    Repeater {
                        model: [["list", "view_list"], ["keyboard", "keyboard"]]

                        IconButton {
                            required property var modelData

                            icon: modelData[1]
                            size: Theme.icon.small + 2
                            implicitWidth: 34
                            active: sheet.view === modelData[0]
                            onClicked: Keybinds.setView(modelData[0])
                        }
                    }
                }
            }

            // The list view: balanced columns of groups, scrolling past
            // maxListHeight behind a thin bar.
            Flickable {
                id: scroller

                visible: sheet.view === "list"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(listBody.implicitHeight, sheet.maxListHeight)
                contentHeight: listBody.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: listBody
                    spacing: Theme.space.xl

                    Repeater {
                        model: sheet.table?.columns ?? []

                        Column {
                            required property var modelData

                            // A column the filter emptied takes no room.
                            visible: modelData.some(i => (sheet.kept[i] ?? []).length > 0)
                            spacing: Theme.space.lg

                            Repeater {
                                model: parent.modelData

                                Group {}
                            }
                        }
                    }
                }

                Rectangle {
                    visible: scroller.interactive
                    x: scroller.width - width
                    y: scroller.contentY + scroller.visibleArea.yPosition * scroller.height
                    width: 3
                    height: scroller.visibleArea.heightRatio * scroller.height
                    radius: Theme.radius.pill
                    color: Theme.colors.bg3
                }
            }

            Line {
                visible: sheet.view === "list" && sheet.shown === 0 && sheet.table !== null
                text: sheet.words.length > 0 ? "No bind matches “" + sheet.query.trim() + "”." : "Nothing is bound to " + sheet.held.join(" + ") + "."
                color: Theme.colors.grey2
            }

            // The keyboard view.
            Item {
                visible: sheet.view === "keyboard"
                Layout.preferredWidth: sheet.boardWidth
                Layout.preferredHeight: sheet.boardHeight
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: sheet.keys

                    BoardKey {}
                }
            }

            // What the pointed key does, under the board.
            Item {
                visible: sheet.view === "keyboard"
                Layout.fillWidth: true
                Layout.preferredHeight: 6 * 24

                Line {
                    visible: sheet.binds.length === 0
                    size: Theme.font.small
                    color: Theme.colors.grey2
                    text: {
                        if (sheet.pointed === "")
                            return "Lit keys do something with what is held now; raised ones need a different modifier.";
                        const mod = sheet.modCaps[sheet.pointed];
                        if (mod)
                            return "Click to " + (sheet.latched.includes(mod) ? "release " : "latch ") + mod + ".";
                        const name = sheet.legend(sheet.pointed) || "Space";
                        const where = (sheet.table?.modes ?? []).find(m => m.mode === sheet.mode);
                        return "Nothing is bound to " + name + (where ? " in " + where.name.toLowerCase() : "") + ".";
                    }
                }

                GridLayout {
                    visible: sheet.binds.length > 0
                    columns: 3
                    columnSpacing: Theme.space.md
                    rowSpacing: Theme.space.xs

                    Repeater {
                        model: sheet.binds

                        Row {
                            required property var modelData
                            required property int index

                            Layout.row: index
                            Layout.column: 0
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 3

                            Repeater {
                                model: parent.modelData.combo

                                Keycap {
                                    required property string modelData

                                    text: modelData
                                }
                            }
                        }
                    }

                    Repeater {
                        model: sheet.binds

                        Line {
                            required property var modelData
                            required property int index

                            Layout.row: index
                            Layout.column: 1
                            text: modelData.label
                            color: modelData.now ? Theme.colors.fg : Theme.colors.grey2
                        }
                    }

                    Repeater {
                        model: sheet.binds

                        Line {
                            required property var modelData
                            required property int index

                            Layout.row: index
                            Layout.column: 2
                            text: modelData.note
                            size: Theme.font.small
                            color: Theme.colors.grey2
                        }
                    }
                }
            }

            Line {
                size: Theme.font.small
                color: Theme.colors.grey2
                text: sheet.view === "keyboard" ? "Esc closes  ·  Tab switches to the list  ·  hold or click a modifier, then hover, click or press a key" : "Esc closes  ·  Super + / toggles  ·  Tab switches to the keyboard  ·  hold a modifier to narrow"
            }
        }
    }

    // One group of the list: the keys against the gutter and the labels
    // against the spine, under the held prefix's caps and a note.
    component Group: GridLayout {
        id: group

        required property int modelData
        // Undefined for a moment when a fresh read has fewer groups, until
        // the columns catch up.
        readonly property var info: sheet.table.groups[modelData]
        readonly property var shownRows: sheet.kept[modelData] ?? []

        visible: shownRows.length > 0
        columns: 2
        columnSpacing: Theme.space.md
        rowSpacing: Theme.space.xs

        Row {
            Layout.row: 0
            Layout.column: 0
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.bottomMargin: Theme.space.sm
            spacing: 3

            Repeater {
                model: group.info?.head ?? []

                Keycap {
                    required property string modelData

                    text: modelData
                    prefix: true
                }
            }
        }

        Line {
            Layout.row: 0
            Layout.column: 1
            Layout.bottomMargin: Theme.space.sm
            text: group.info?.note ?? ""
            size: Theme.font.small
            color: Theme.colors.grey2
        }

        Repeater {
            model: group.shownRows

            Row {
                required property var modelData
                required property int index

                Layout.row: index + 1
                Layout.column: 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 3

                Repeater {
                    model: parent.modelData.keys

                    Keycap {
                        required property string modelData

                        text: modelData
                    }
                }
            }
        }

        Repeater {
            model: group.shownRows

            Line {
                required property var modelData
                required property int index

                Layout.row: index + 1
                Layout.column: 1
                Layout.maximumWidth: 240
                elide: Text.ElideRight
                text: modelData.label
                color: Theme.colors.grey2
            }
        }
    }

    // The keyboard view's mode switch, Material 3's segmented button: one
    // pill on the card tone, Normal and then each mode by name with the
    // keys that enter it after in Mono, so the keys read as a note and not
    // as a bind. The chosen segment sits on the blue tint, which slides to
    // the next choice.
    component ModeSwitch: Rectangle {
        id: modes

        readonly property var choices: [{
                mode: "",
                name: "Normal",
                keys: null
            }].concat(sheet.table?.modes ?? [])
        readonly property Item chosen: segments.count > 0 ? segments.itemAt(choices.findIndex(c => c.mode === sheet.mode)) : null

        implicitWidth: row.implicitWidth + 4
        implicitHeight: 32
        radius: Theme.radius.pill
        color: Theme.surface.card

        Rectangle {
            x: (modes.chosen?.x ?? 0) + 2
            y: 2
            width: modes.chosen?.width ?? 0
            height: parent.height - 4
            radius: Theme.radius.pill
            color: Theme.colors.withAlpha(Theme.colors.blue, 0.18)

            Behavior on x {
                Anim {}
            }

            Behavior on width {
                Anim {}
            }
        }

        Row {
            id: row
            x: 2
            y: 2
            height: parent.height - 4

            Repeater {
                id: segments
                model: modes.choices

                Item {
                    id: segment

                    required property var modelData
                    readonly property bool on: sheet.mode === modelData.mode
                    readonly property real radius: Theme.radius.pill

                    implicitWidth: words.implicitWidth + Theme.space.md * 2
                    height: row.height

                    StateLayer {
                        tint: segment.on ? Theme.colors.blue : Theme.colors.fg
                        onClicked: () => sheet.mode = segment.modelData.mode
                    }

                    Row {
                        id: words
                        anchors.centerIn: parent
                        spacing: Theme.space.sm

                        Line {
                            anchors.verticalCenter: parent.verticalCenter
                            text: segment.modelData.name
                            size: Theme.font.smaller
                            weight: Font.Medium
                            color: segment.on ? Theme.colors.fg : Theme.colors.grey2
                        }

                        Line {
                            visible: text !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: (segment.modelData.keys ?? []).join("+")
                            mono: true
                            size: Theme.font.small
                            color: Theme.colors.grey2
                        }
                    }
                }
            }
        }
    }

    // A key on the board: its legend in the corner, and one of four
    // strengths over a 3px bg_dim lip. It washes under the pointer; the
    // selected key wears the focus ring.
    component BoardKey: Item {
        id: key

        required property var modelData
        readonly property string cap: modelData.cap
        readonly property bool bound: sheet.lit.here[cap] === true
        readonly property bool raised: !bound && sheet.lit.near[cap] === true
        readonly property bool down: sheet.holding.includes(sheet.modCaps[cap] ?? "")

        x: modelData.x * sheet.pitch
        y: modelData.y * sheet.pitch
        width: modelData.w * sheet.pitch - sheet.gap
        height: modelData.h * (sheet.pitch - sheet.gap)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.control
            color: Theme.colors.bg_dim
        }

        Rectangle {
            id: face

            width: parent.width
            height: parent.height - 3
            radius: Theme.radius.control
            color: key.bound ? Theme.colors.blue : key.down ? Theme.colors.bg3 : key.raised ? Theme.colors.bg1 : Theme.colors.bg0
            border.width: 1
            border.color: key.bound ? Theme.colors.blue : key.down ? Theme.colors.grey0 : Theme.colors.bg1

            Behavior on color {
                CAnim {}
            }

            StateLayer {
                tint: key.bound ? Theme.colors.bg0 : Theme.colors.fg
                onClicked: () => {
                    const mod = sheet.modCaps[key.cap];
                    if (mod)
                        sheet.latched = sheet.latched.includes(mod) ? sheet.latched.filter(m => m !== mod) : sheet.latched.concat([mod]);
                    else
                        sheet.selected = sheet.selected === key.cap ? "" : key.cap;
                }
                onHoveredChanged: {
                    if (hovered)
                        sheet.hover = key.cap;
                    else if (sheet.hover === key.cap)
                        sheet.hover = "";
                }
            }

            Line {
                x: 6
                y: 3
                width: parent.width - 10
                elide: Text.ElideRight
                text: sheet.legend(key.cap)
                mono: true
                size: Theme.font.small
                weight: Font.Bold
                color: key.bound ? Theme.colors.bg_dim : key.down || key.raised ? Theme.colors.fg : Theme.colors.grey2
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radius.control + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.colors.blue
            opacity: key.cap === sheet.selected ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    speed: "fast"
                }
            }
        }
    }
}
