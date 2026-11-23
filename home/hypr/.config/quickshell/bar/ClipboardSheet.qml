pragma ComponentBehavior: Bound

// The clipboard history (#89), which replaced rofi's cliphist menu: a
// search field over what cliphist keeps, newest first, and beside the
// list the chosen entry in full (its text, or the image). Read afresh on
// every open; cliphist stores in the background (hyprland.lua).
//
// Typing filters (fuzzy, Fuzzy.js). Down, Ctrl+n or Tab move on, Up,
// Ctrl+p or Shift+Tab back, Page Down and Page Up a page. Enter copies
// the entry back to the clipboard and closes; Shift+Delete removes it
// from the history; Esc closes, and Super alone says `superPressed`, so a
// Super chord closes the sheet before Hyprland acts on it.
import QtQuick
import Quickshell
import Quickshell.Io
import "Fuzzy.js" as Fuzzy

Sheet {
    id: sheet

    property bool open: false
    property string query: ""
    // [{ id, text, image: { size, type, width, height } | null }], newest
    // first.
    property var entries: []
    readonly property var shown: {
        const q = query.trim();
        if (q === "")
            return entries;
        return entries.map((entry, i) => ({
                    entry: entry,
                    score: Fuzzy.score(q, entry.text) - i * 0.001
                })).filter(r => r.score > -Infinity).sort((a, b) => b.score - a.score).map(r => r.entry);
    }
    property int current: 0
    readonly property var chosen: shown[current] ?? null
    // The chosen entry in full: its text, or where its image was written.
    property string full: ""
    property string picture: ""

    readonly property int rows: 8
    readonly property int rowHeight: 36
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR")
    // The field has the keyboard.
    readonly property bool typing: input.activeFocus

    signal closeRequested
    signal superPressed

    implicitHeight: column.implicitHeight + Theme.space.md * 2

    function select(index) {
        if (sheet.shown.length === 0)
            return;
        sheet.current = Math.max(0, Math.min(sheet.shown.length - 1, index));
    }

    // cliphist takes an entry by the line `list` printed, of which the id
    // before the tab is enough.
    function run(script, id) {
        return ["sh", "-c", "printf '%s\\t\\n' \"$1\" | " + script, "sh", String(id)];
    }

    function copy(entry) {
        if (!entry)
            return;
        Quickshell.execDetached(sheet.run("cliphist decode | wl-copy", entry.id));
        sheet.closeRequested();
    }

    function remove(entry) {
        if (!entry)
            return;
        Quickshell.execDetached(sheet.run("cliphist delete", entry.id));
        sheet.entries = sheet.entries.filter(e => e.id !== entry.id);
    }

    // "[[ binary data 12 KiB png 1920x1080 ]]" is how cliphist lists an
    // image.
    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            const preview = line.slice(tab + 1);
            const m = preview.match(/^\[\[ binary data (\S+ \S+) (\w+) (\d+)x(\d+) \]\]$/);
            out.push({
                id: line.slice(0, tab),
                text: m ? "" : preview,
                image: m ? {
                    size: m[1],
                    type: m[2],
                    width: Number(m[3]),
                    height: Number(m[4])
                } : null
            });
        }
        return out;
    }

    onOpenChanged: {
        if (!open)
            return;
        input.text = "";
        sheet.current = 0;
        lister.running = false;
        lister.running = true;
        input.forceActiveFocus();
    }

    onShownChanged: {
        sheet.current = 0;
        list.positionViewAtBeginning();
    }

    onChosenChanged: decodeLater.restart()

    onCurrentChanged: {
        list.currentIndex = sheet.current;
        list.positionViewAtIndex(sheet.current, ListView.Contain);
    }

    Process {
        id: lister
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: sheet.entries = sheet.parse(text)
        }
    }

    // The preview waits for the selection to settle, so holding Down
    // doesn't decode every entry on the way.
    Timer {
        id: decodeLater
        interval: 60
        onTriggered: {
            const entry = sheet.chosen;
            decoder.running = false;
            sheet.full = "";
            sheet.picture = "";
            if (!entry)
                return;
            if (entry.image) {
                const path = sheet.runtime + "/bar-clipboard-preview." + entry.image.type;
                decoder.target = path;
                decoder.command = sheet.run(`cliphist decode > '${path}.part' && mv '${path}.part' '${path}'`, entry.id);
            } else {
                decoder.target = "";
                decoder.command = sheet.run("cliphist decode | head -c 8000", entry.id);
            }
            decoder.running = true;
        }
    }

    Process {
        id: decoder

        property string target: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (decoder.target === "")
                    sheet.full = text;
            }
        }

        onExited: code => {
            if (decoder.target !== "" && code === 0)
                sheet.picture = "file://" + decoder.target + "?" + Date.now();
        }
    }

    Column {
        id: column

        x: Theme.space.md
        y: Theme.space.md
        width: parent.width - Theme.space.md * 2
        spacing: Theme.space.sm

        // DESIGN.md's field, with a search icon at its start and the count
        // at its end.
        Rectangle {
            width: parent.width
            height: 40
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

                anchors.left: parent.left
                anchors.right: tally.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: glass.x + glass.width + Theme.space.sm
                anchors.rightMargin: Theme.space.sm
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
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const shift = event.modifiers & Qt.ShiftModifier;
                    const key = event.key;
                    if (key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta) {
                        sheet.superPressed();
                        return;
                    }
                    if (key === Qt.Key_Escape)
                        sheet.closeRequested();
                    else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                        sheet.copy(sheet.chosen);
                    else if (key === Qt.Key_Delete && shift)
                        sheet.remove(sheet.chosen);
                    else if (key === Qt.Key_Down || key === Qt.Key_Tab || (ctrl && key === Qt.Key_N))
                        sheet.select(sheet.current + 1);
                    else if (key === Qt.Key_Up || key === Qt.Key_Backtab || (ctrl && key === Qt.Key_P))
                        sheet.select(sheet.current - 1);
                    else if (key === Qt.Key_PageDown)
                        sheet.select(sheet.current + sheet.rows);
                    else if (key === Qt.Key_PageUp)
                        sheet.select(sheet.current - sheet.rows);
                    else
                        return;
                    event.accepted = true;
                }

                cursorDelegate: Rectangle {
                    width: 1
                    color: Theme.colors.blue
                    visible: input.activeFocus
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === "" && input.preeditText === ""
                    text: "Search clipboard"
                    color: Theme.colors.grey2
                    font: input.font
                    renderType: Text.NativeRendering
                }
            }

            Line {
                id: tally
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.font.small
                color: Theme.colors.grey2
                text: sheet.shown.length === sheet.entries.length ? String(sheet.entries.length) : sheet.shown.length + " of " + sheet.entries.length
            }
        }

        Row {
            width: parent.width
            height: sheet.rows * (sheet.rowHeight + 2)
            spacing: Theme.space.sm
            visible: sheet.shown.length > 0

            ListView {
                id: list

                width: Math.round(parent.width * 0.48)
                height: parent.height
                clip: true
                spacing: 2
                model: sheet.shown
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: sheet.rowHeight

                    StateLayer {
                        radius: Theme.radius.pill
                        selected: row.index === sheet.current
                        onClicked: () => sheet.copy(row.modelData)
                    }

                    // An image says what it is beside its icon.
                    Icon {
                        id: kind
                        visible: row.modelData.image !== null
                        x: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        name: "image"
                        size: Theme.icon.small
                        color: Theme.colors.grey2
                    }

                    Line {
                        x: row.modelData.image ? kind.x + kind.width + Theme.space.sm : Theme.space.md
                        width: parent.width - x - Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: row.modelData.image ? "Image · " + row.modelData.image.width + "×" + row.modelData.image.height + " " + row.modelData.image.type.toUpperCase() + " · " + row.modelData.image.size : row.modelData.text.replace(/\s+/g, " ")
                        color: row.modelData.image ? Theme.colors.grey2 : Theme.colors.fg
                    }
                }
            }

            // The chosen entry in full, on the card tone.
            Rectangle {
                width: parent.width - list.width - parent.spacing
                height: parent.height
                radius: Theme.radius.surface
                color: Theme.surface.card
                clip: true

                Text {
                    visible: sheet.chosen !== null && sheet.chosen.image === null
                    anchors.fill: parent
                    anchors.margins: Theme.space.md
                    text: sheet.full
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    color: Theme.colors.fg
                    font.family: Theme.font.mono
                    font.pixelSize: Theme.font.smaller
                    renderType: Text.NativeRendering
                }

                Image {
                    visible: sheet.chosen?.image !== null && sheet.chosen?.image !== undefined
                    anchors.fill: parent
                    anchors.margins: Theme.space.md
                    source: sheet.picture
                    cache: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: width * 2
                }
            }
        }

        Line {
            visible: sheet.shown.length === 0
            x: Theme.space.md
            text: sheet.entries.length === 0 ? "The clipboard history is empty." : "Nothing matches."
            color: Theme.colors.grey2
        }

        Line {
            x: Theme.space.md
            size: Theme.font.small
            color: Theme.colors.grey2
            text: "Enter copies  ·  Shift+Delete removes  ·  Esc closes"
        }
    }
}
