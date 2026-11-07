// A menu that drops from the bar under the control that opened it: the
// power menu, the reboot confirmation and tray items' menus, where waybar
// used GTK popups. It is a sheet like the open center island (bg_dim at
// 0.985 over a shadow), its rows in Adwaita Sans.
//
// Entries are plain objects ({ text, run } or { separator: true }) or a
// tray item's DBus menu, whose submenus open in place under a row back.
// A click outside or Esc closes it (the bar's focus grab).
//
// An entry with `confirm: true` (Log out, Reboot, Shut down) takes a
// second press, as in hypr-settings-menu's sheet (DESIGN.md, the Second
// Press Rule): the first arms its row for 3 seconds, red and "Again?".
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: menu

    required property var bar
    readonly property var colors: bar.colors
    // The control it hangs from; null while closed.
    property Item anchor: null
    property var entries: []
    // A tray item's menu, and the submenus opened inside it.
    property var handle: null
    property var path: []
    // The row a first press armed, by index, or -1.
    property int armed: -1

    readonly property bool open: anchor !== null
    readonly property var rows: handle ? opener.children.values : entries

    function show(anchorItem, list, menuHandle) {
        menu.disarm();
        menu.entries = list;
        menu.handle = menuHandle;
        menu.path = [];
        menu.anchor = anchorItem;
        menu.place();
        menu.forceActiveFocus();
    }

    function close() {
        menu.disarm();
        menu.anchor = null;
        menu.handle = null;
        menu.path = [];
        menu.entries = [];
    }

    function disarm() {
        armTimer.stop();
        menu.armed = -1;
    }

    // Right-aligned under a control on the right half, left-aligned on
    // the left, always 8px inside the screen.
    function place() {
        const left = menu.anchor.mapToItem(null, 0, 0).x;
        const right = left + menu.anchor.width;
        const wanted = right > menu.bar.width / 2 ? right - menu.width : left;
        menu.x = Math.round(Math.max(8, Math.min(menu.bar.width - menu.width - 8, wanted)));
    }

    function choose(entry, index) {
        if (entry.hasChildren) {
            menu.path = menu.path.concat([entry]);
            return;
        }
        if (entry.confirm && menu.armed !== index) {
            menu.armed = index;
            armTimer.restart();
            return;
        }
        if (entry.run)
            entry.run();
        else
            entry.triggered();
        menu.close();
    }

    onWidthChanged: if (menu.open)
        menu.place()

    // The widest row decides; rows then stretch to the menu's width.
    readonly property real natural: {
        let widest = back.visible ? back.implicitWidth : 0;
        for (let i = 0; i < slots.count; i++)
            widest = Math.max(widest, slots.itemAt(i)?.implicitWidth ?? 0);
        return widest;
    }

    y: open ? 42 : 36
    width: Math.max(160, natural + 8)
    height: list.implicitHeight + 8
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

    Keys.onEscapePressed: menu.close()

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: menu.armed = -1
    }

    QsMenuOpener {
        id: opener
        menu: menu.path.length > 0 ? menu.path[menu.path.length - 1] : menu.handle
    }

    RectangularShadow {
        anchors.fill: parent
        radius: 12
        blur: 6
        color: menu.colors.withAlpha(menu.colors.bg_dim, 0.93)
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: menu.colors.withAlpha(menu.colors.bg_dim, 0.985)
        border.width: 1
        border.color: menu.colors.withAlpha(menu.colors.blue, 0.18)
    }

    Column {
        id: list
        x: 4
        y: 4

        readonly property real rowWidth: menu.width - 8

        // Back out of a submenu.
        MenuRow {
            id: back
            colors: menu.colors
            visible: menu.path.length > 0
            width: list.rowWidth
            glyph: 0xf0141
            text: menu.path.length > 0 ? menu.path[menu.path.length - 1].text.replace(/_(?!_)/g, "") : ""
            onChosen: menu.path = menu.path.slice(0, -1)
        }

        Repeater {
            id: slots
            model: menu.rows

            Item {
                id: slot

                required property var modelData
                required property int index
                readonly property bool separator: modelData.isSeparator ?? modelData.separator ?? false

                implicitWidth: separator ? 0 : row.implicitWidth
                width: list.rowWidth
                height: separator ? 9 : row.height

                Rectangle {
                    visible: slot.separator
                    x: 8
                    width: parent.width - 16
                    y: 4
                    height: 1
                    color: menu.colors.bg1
                }

                MenuRow {
                    id: row
                    colors: menu.colors
                    visible: !slot.separator
                    width: parent.width
                    enabled: slot.modelData.enabled ?? true
                    armed: menu.armed === slot.index
                    // DBus menus mark mnemonics with an underscore.
                    text: armed ? "Again?" : (slot.modelData.text ?? "").replace(/_(?!_)/g, "")
                    icon: slot.modelData.icon ?? ""
                    checkable: (slot.modelData.buttonType ?? 0) !== 0
                    checked: slot.modelData.checkState === Qt.Checked
                    more: slot.modelData.hasChildren ?? false
                    onChosen: menu.choose(slot.modelData, slot.index)
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: entry

        required property var colors
        property string text
        property string icon: ""
        property int glyph: 0
        property bool checkable: false
        property bool checked: false
        property bool more: false
        // Waiting for its second press: red as a tint (the Tint Rule), so
        // the words stay fg.
        property bool armed: false

        signal chosen

        implicitWidth: content.implicitWidth + 24 + (more ? 22 : 0)
        height: 30
        radius: 8
        opacity: enabled ? 1 : 0.5
        color: armed ? entry.colors.withAlpha(entry.colors.red, 0.2) : hover.hovered && enabled ? entry.colors.bg1 : "transparent"
        border.width: armed ? 1 : 0
        border.color: entry.colors.withAlpha(entry.colors.red, 0.55)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        HoverHandler {
            id: hover
            cursorShape: entry.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            onTapped: if (entry.enabled)
                entry.chosen()
        }

        Row {
            id: content
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Line {
                visible: entry.glyph !== 0 || entry.checkable
                anchors.verticalCenter: parent.verticalCenter
                mono: true
                text: entry.glyph !== 0 ? String.fromCodePoint(entry.glyph) : entry.checked ? String.fromCodePoint(0xf012c) : " "
                color: entry.colors.fg
            }

            IconImage {
                visible: entry.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: entry.icon
            }

            Line {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.text
                color: entry.colors.fg
            }
        }

        Line {
            visible: entry.more
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            mono: true
            text: String.fromCodePoint(0xf0142)
            color: entry.colors.grey2
        }
    }
}
