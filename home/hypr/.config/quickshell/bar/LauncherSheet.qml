pragma ComponentBehavior: Bound

// The launcher's sheet (#89), which replaced rofi's drun: a search field
// over the apps that match (Apps.qml), most used first while nothing is
// typed, in one of three views, switched by the toggles at the field's
// end or Ctrl+Tab and remembered:
//
// - list: a pill per app, its icon and name, its generic name ("Web
//   Browser") at the end in grey2;
// - grid: five to a row, the icon over the name on one line;
// - categories: the list under a heading per freedesktop main category,
//   each heading where its best app ranks.
//
// The keyboard's app washes at focus strength (the One Wash Rule).
// Typing filters. Down, Ctrl+n or Tab move on, Up, Ctrl+p or Shift+Tab
// back, Page Down and Page Up a page; in the grid, Left and Right move
// along the row and Up and Down between rows. Ctrl+Tab (Shift: back)
// or Ctrl+1, 2, 3 switch views. Enter launches and closes, Esc closes,
// and Super alone says `superPressed`, so a Super chord closes the
// launcher before Hyprland acts on it. A click on an app launches it.
import QtQuick
import Quickshell
import Quickshell.Widgets

Sheet {
    id: sheet

    property bool open: false
    property string query: ""
    readonly property string view: Apps.view
    readonly property var results: Apps.search(query)
    // The categorized view: [{ name, apps }], in the order of each
    // category's best app.
    readonly property var groups: {
        if (view !== "categories")
            return [];
        const order = [];
        const by = {};
        for (const entry of results) {
            const name = Apps.category(entry);
            if (!by[name]) {
                by[name] = [];
                order.push(name);
            }
            by[name].push(entry);
        }
        return order.map(name => ({
                    name: name,
                    apps: by[name]
                }));
    }
    // The apps in the order they show, which the keyboard walks. (QML's
    // JavaScript has no flatMap.)
    readonly property var shown: {
        if (view !== "categories")
            return results;
        const apps = [];
        for (const g of groups)
            apps.push(...g.apps);
        return apps;
    }
    // The categorized list's rows, headings among them, and the row of
    // each app in `shown`.
    readonly property var items: {
        const rows = [];
        for (const g of groups) {
            rows.push({
                heading: g.name
            });
            for (const entry of g.apps)
                rows.push({
                    entry: entry
                });
        }
        return rows;
    }
    readonly property var rowOf: {
        const map = [];
        items.forEach((item, i) => {
            if (item.entry)
                map.push(i);
        });
        return map;
    }
    property int current: 0

    readonly property int rows: 8
    readonly property int rowHeight: 40
    readonly property int columns: 5
    // Four grid rows fill the same height as eight list rows.
    readonly property int cellHeight: rows * (rowHeight + 2) / 4
    // The field has the keyboard.
    readonly property bool typing: input.activeFocus

    signal closeRequested
    signal superPressed

    implicitHeight: column.implicitHeight + Theme.space.md * 2

    function launch(entry) {
        if (!entry)
            return;
        Apps.launch(entry);
        sheet.closeRequested();
    }

    function select(index) {
        if (sheet.shown.length === 0)
            return;
        sheet.current = Math.max(0, Math.min(sheet.shown.length - 1, index));
    }

    function cycle(by) {
        const at = Apps.views.indexOf(sheet.view);
        Apps.setView(Apps.views[(at + by + Apps.views.length) % Apps.views.length]);
    }

    function reset() {
        sheet.current = 0;
        // Once the views have their new models.
        Qt.callLater(sheet.follow);
    }

    // Each view marks the keyboard's app and keeps it in sight; the
    // categorized list shows a category's heading with its first app.
    function follow() {
        list.currentIndex = sheet.current;
        list.positionViewAtIndex(sheet.current, ListView.Contain);
        grid.currentIndex = sheet.current;
        grid.positionViewAtIndex(sheet.current, GridView.Contain);
        const row = sheet.rowOf[sheet.current] ?? 0;
        sorted.currentIndex = row;
        sorted.positionViewAtIndex(row > 0 && sheet.items[row - 1]?.heading ? row - 1 : row, ListView.Contain);
    }

    onOpenChanged: {
        if (!open)
            return;
        input.text = "";
        sheet.reset();
        input.forceActiveFocus();
    }

    onShownChanged: sheet.reset()
    onCurrentChanged: sheet.follow()

    Column {
        id: column

        x: Theme.space.md
        y: Theme.space.md
        width: parent.width - Theme.space.md * 2
        spacing: Theme.space.sm

        // DESIGN.md's field, with a search icon at its start and the view
        // toggles at its end.
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
                anchors.right: toggles.left
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
                    const key = event.key;
                    const inGrid = sheet.view === "grid";
                    const down = inGrid ? sheet.columns : 1;
                    if (key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta) {
                        sheet.superPressed();
                        return;
                    }
                    if (ctrl && key === Qt.Key_Tab)
                        sheet.cycle(1);
                    else if (ctrl && key === Qt.Key_Backtab)
                        sheet.cycle(-1);
                    else if (ctrl && key >= Qt.Key_1 && key <= Qt.Key_3)
                        Apps.setView(Apps.views[key - Qt.Key_1]);
                    else if (key === Qt.Key_Escape)
                        sheet.closeRequested();
                    else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                        sheet.launch(sheet.shown[sheet.current]);
                    else if (key === Qt.Key_Down)
                        sheet.select(sheet.current + down);
                    else if (key === Qt.Key_Up)
                        sheet.select(sheet.current - down);
                    else if (key === Qt.Key_Tab || (ctrl && key === Qt.Key_N))
                        sheet.select(sheet.current + 1);
                    else if (key === Qt.Key_Backtab || (ctrl && key === Qt.Key_P))
                        sheet.select(sheet.current - 1);
                    else if (inGrid && key === Qt.Key_Right)
                        sheet.select(sheet.current + 1);
                    else if (inGrid && key === Qt.Key_Left)
                        sheet.select(sheet.current - 1);
                    else if (key === Qt.Key_PageDown)
                        sheet.select(sheet.current + (inGrid ? sheet.columns * 4 : sheet.rows));
                    else if (key === Qt.Key_PageUp)
                        sheet.select(sheet.current - (inGrid ? sheet.columns * 4 : sheet.rows));
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
                    text: "Search apps"
                    color: Theme.colors.grey2
                    font: input.font
                    renderType: Text.NativeRendering
                }
            }

            Row {
                id: toggles
                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [["list", "view_list"], ["grid", "grid_view"], ["categories", "category"]]

                    IconButton {
                        required property var modelData

                        icon: modelData[1]
                        size: Theme.icon.small + 2
                        implicitWidth: 34
                        active: sheet.view === modelData[0]
                        onClicked: Apps.setView(modelData[0])
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: sheet.shown.length > 0 ? Math.min(sheet.view === "grid" ? Math.ceil(sheet.shown.length / sheet.columns) * sheet.cellHeight : sheet.view === "categories" ? sorted.contentHeight : sheet.shown.length * (sheet.rowHeight + 2), sheet.rows * (sheet.rowHeight + 2)) : 0
            visible: height > 0

            ListView {
                id: list
                anchors.fill: parent
                visible: sheet.view === "list"
                clip: true
                spacing: 2
                model: sheet.view === "list" ? sheet.shown : []
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: AppRow {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    entry: modelData
                    selected: ListView.isCurrentItem
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                visible: sheet.view === "grid"
                clip: true
                cellWidth: width / sheet.columns
                cellHeight: sheet.cellHeight
                model: sheet.view === "grid" ? sheet.shown : []
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: AppCell {
                    required property var modelData
                    required property int index

                    entry: modelData
                    selected: GridView.isCurrentItem
                }
            }

            ListView {
                id: sorted
                anchors.fill: parent
                visible: sheet.view === "categories"
                clip: true
                spacing: 2
                model: sheet.items
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Item {
                    id: item

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: modelData.heading ? 28 : sheet.rowHeight

                    // Its icon in line with the apps' icons below.
                    Row {
                        visible: item.modelData.heading !== undefined
                        x: Theme.space.md + (Theme.icon.large - Theme.icon.small) / 2
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.space.xs
                        spacing: Theme.space.md + (Theme.icon.large - Theme.icon.small) / 2

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Apps.icons[item.modelData.heading] ?? "apps"
                            size: Theme.icon.small
                            color: Theme.colors.grey2
                        }

                        Line {
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.font.small
                            weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            text: item.modelData.heading ?? ""
                            color: Theme.colors.grey2
                        }
                    }

                    AppRow {
                        visible: item.modelData.entry !== undefined
                        entry: item.modelData.entry ?? null
                        selected: item.ListView.isCurrentItem
                    }
                }
            }
        }

        Line {
            visible: sheet.shown.length === 0
            x: Theme.space.md
            text: "No app matches."
            color: Theme.colors.grey2
        }
    }

    // An app as a list row: a pill with its icon, its name, and its
    // generic name at the end.
    component AppRow: Item {
        id: row

        property var entry: null
        property bool selected: false

        width: parent?.width ?? 0
        height: sheet.rowHeight

        StateLayer {
            radius: Theme.radius.pill
            selected: row.selected
            onClicked: () => sheet.launch(row.entry)
        }

        IconImage {
            id: rowIcon
            x: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.icon.large
            source: row.entry ? Quickshell.iconPath(row.entry.icon, "application-x-executable") : ""
            asynchronous: true
        }

        Line {
            x: rowIcon.x + rowIcon.width + Theme.space.md
            width: Math.min(implicitWidth, parent.width - x - kind.width - Theme.space.md * 2)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.entry?.name ?? ""
            color: Theme.colors.fg
        }

        Line {
            id: kind
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width / 3)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            size: Theme.font.small
            text: row.entry?.genericName ?? ""
            color: Theme.colors.grey2
        }
    }

    // An app as a grid cell: its icon over its name, in 8px corners as
    // the tray grid's cells.
    component AppCell: Item {
        id: cell

        property var entry: null
        property bool selected: false

        width: GridView.view.cellWidth
        height: GridView.view.cellHeight

        Item {
            anchors.fill: parent
            anchors.margins: 2

            StateLayer {
                radius: Theme.radius.control
                selected: cell.selected
                onClicked: () => sheet.launch(cell.entry)
            }

            IconImage {
                id: cellIcon
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.space.md
                implicitSize: 40
                source: cell.entry ? Quickshell.iconPath(cell.entry.icon, "application-x-executable") : ""
                asynchronous: true
            }

            Line {
                anchors.top: cellIcon.bottom
                anchors.topMargin: Theme.space.sm
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Theme.space.sm * 2
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                size: Theme.font.smaller
                text: cell.entry?.name ?? ""
                color: Theme.colors.fg
            }
        }
    }
}
