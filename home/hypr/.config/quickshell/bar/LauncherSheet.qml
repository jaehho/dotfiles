pragma ComponentBehavior: Bound

// The launcher's sheet (#89), which replaced rofi's drun: a search field
// over the apps that match (Apps.qml), most used first while nothing is
// typed. Each row is a pill with the app's icon and name, its generic
// name ("Web Browser") at the end in grey2; the keyboard's row washes at
// focus strength (the One Wash Rule).
//
// Typing filters. Down, Ctrl+n or Tab move down, Up, Ctrl+p or
// Shift+Tab up, Page Down and Page Up a page; Enter launches and closes,
// Esc closes, and Super alone says `superPressed`, so a Super chord
// closes the launcher before Hyprland acts on it. A click on a row
// launches it.
import QtQuick
import Quickshell
import Quickshell.Widgets

Sheet {
    id: sheet

    property bool open: false
    property string query: ""
    readonly property var results: Apps.search(query)
    readonly property int rows: 8
    readonly property int rowHeight: 40
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

    function step(by) {
        if (list.count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + by));
    }

    onOpenChanged: {
        if (!open)
            return;
        input.text = "";
        list.currentIndex = 0;
        list.positionViewAtBeginning();
        input.forceActiveFocus();
    }

    onResultsChanged: {
        list.currentIndex = 0;
        list.positionViewAtBeginning();
    }

    Column {
        id: column

        x: Theme.space.md
        y: Theme.space.md
        width: parent.width - Theme.space.md * 2
        spacing: Theme.space.sm

        // DESIGN.md's field, with a search icon at its start.
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
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const key = event.key;
                    if (key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta) {
                        sheet.superPressed();
                        return;
                    }
                    if (key === Qt.Key_Escape)
                        sheet.closeRequested();
                    else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                        sheet.launch(sheet.results[list.currentIndex]);
                    else if (key === Qt.Key_Down || key === Qt.Key_Tab || (ctrl && key === Qt.Key_N))
                        sheet.step(1);
                    else if (key === Qt.Key_Up || key === Qt.Key_Backtab || (ctrl && key === Qt.Key_P))
                        sheet.step(-1);
                    else if (key === Qt.Key_PageDown)
                        sheet.step(sheet.rows);
                    else if (key === Qt.Key_PageUp)
                        sheet.step(-sheet.rows);
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
        }

        ListView {
            id: list

            width: parent.width
            height: Math.min(count, sheet.rows) * (sheet.rowHeight + spacing)
            visible: count > 0
            clip: true
            spacing: 2
            model: sheet.results
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
                    selected: row.ListView.isCurrentItem
                    onClicked: () => sheet.launch(row.modelData)
                }

                IconImage {
                    id: appIcon
                    x: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.icon.large
                    source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                    asynchronous: true
                }

                Line {
                    x: appIcon.x + appIcon.width + Theme.space.md
                    width: Math.min(implicitWidth, parent.width - x - kind.width - Theme.space.md * 2)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.name
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
                    text: row.modelData.genericName
                    color: Theme.colors.grey2
                }
            }
        }

        Line {
            visible: list.count === 0
            x: Theme.space.md
            text: "No app matches."
            color: Theme.colors.grey2
        }
    }
}
