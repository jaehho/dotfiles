// A menu that drops from the bar under the control that opened it: the
// power menu, the reboot confirmation and tray items' menus, where waybar
// used GTK popups. It is a sheet like the open center island (bg_dim at
// 0.985 over a shadow), its rows in Adwaita Sans on the shell base
// (#89): a state-layer wash under the pointer, Material Symbols for the
// back arrow, checks and submenus.
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
        Anim {
            speed: "fast"
        }
    }

    Behavior on y {
        Anim {
            speed: "fast"
            curve: menu.open ? "enter" : "exit"
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
        radius: Theme.radius.surface
        blur: 6
        color: Theme.surface.shadow
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.surface
        color: Theme.surface.sheet
        border.width: 1
        border.color: Theme.surface.outline
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
            symbol: "arrow_back"
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
                    color: Theme.colors.bg1
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
        // The DBus menu's own icon, an image.
        property string icon: ""
        // A Material Symbols name, for the back row.
        property string symbol: ""
        property bool checkable: false
        property bool checked: false
        property bool more: false
        // Waiting for its second press: red as a tint (the Tint Rule), so
        // the words stay fg.
        property bool armed: false

        signal chosen

        implicitWidth: content.implicitWidth + Theme.space.md * 2 + (more ? 22 : 0)
        height: 30
        radius: Theme.radius.control
        opacity: enabled ? 1 : 0.5
        color: armed ? Theme.colors.withAlpha(Theme.colors.red, 0.2) : "transparent"

        Behavior on color {
            CAnim {
                speed: "fast"
            }
        }

        StateLayer {
            tint: entry.armed ? Theme.colors.red : Theme.colors.fg
            cursorShape: entry.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: () => entry.chosen()
        }

        Row {
            id: content
            x: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm

            // The back arrow, or a check's mark (blank room when off).
            Icon {
                visible: entry.symbol !== "" || entry.checkable
                anchors.verticalCenter: parent.verticalCenter
                name: entry.symbol !== "" ? entry.symbol : "check"
                size: Theme.icon.small
                opacity: entry.symbol !== "" || entry.checked ? 1 : 0
                color: entry.symbol !== "" ? Theme.colors.grey2 : Theme.colors.fg
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
                color: Theme.colors.fg
            }
        }

        Icon {
            visible: entry.more
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Theme.icon.small
            color: Theme.colors.grey2
        }
    }
}
