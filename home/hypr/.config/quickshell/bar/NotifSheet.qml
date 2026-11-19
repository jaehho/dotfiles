pragma ComponentBehavior: Bound

// What the notification center shows (#90): a header with Do Not
// Disturb and Clear all, then every notification not yet dismissed,
// newest first; an empty sheet says so. NotifCenter places it on a
// screen; it is an Item of its own so a harness can draw it.
//
// The keyboard is native, not a Hyprland submap: Up/Down, j/k or
// Ctrl+n/p move, gg/Home and G/End jump, Enter runs the default action
// and closes, x/Delete dismisses and moves to the next, `<` or `,` and
// `>` or `.` press the first two buttons and 3–9 the rest, q or Esc
// close. It takes keys while it has focus.
//
// Its implicitHeight is what it would like; given less, the list
// scrolls.
import QtQuick
import QtQuick.Layouts
import Quickshell

Sheet {
    id: sheet

    property bool open: false
    // gg needs two presses inside a second, as in vim.
    property real gAt: 0

    signal closeRequested

    implicitHeight: column.implicitHeight + Theme.space.md * 2

    onOpenChanged: {
        if (open)
            list.currentIndex = Notifs.count > 0 ? 0 : -1;
    }

    // Activate a button of the selected notification by its place.
    function press(index) {
        const card = list.currentItem;
        if (!card || index >= card.buttons.length)
            return;
        Notifs.activate(card.entry, card.buttons[index].id);
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const last = Notifs.count - 1;
        const key = event.key;
        if (key === Qt.Key_Down || key === Qt.Key_J || (ctrl && key === Qt.Key_N))
            list.currentIndex = Math.min(last, list.currentIndex + 1);
        else if (key === Qt.Key_Up || key === Qt.Key_K || (ctrl && key === Qt.Key_P))
            list.currentIndex = Math.max(0, list.currentIndex - 1);
        else if (key === Qt.Key_Home)
            list.currentIndex = Math.min(0, last);
        else if (key === Qt.Key_End || (key === Qt.Key_G && event.modifiers & Qt.ShiftModifier))
            list.currentIndex = last;
        else if (key === Qt.Key_G) {
            if (Date.now() - gAt < 1000) {
                list.currentIndex = Math.min(0, last);
                gAt = 0;
            } else
                gAt = Date.now();
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            if (list.currentItem)
                Notifs.activate(list.currentItem.entry, "default");
            sheet.closeRequested();
        } else if (key === Qt.Key_X || key === Qt.Key_Delete) {
            if (list.currentItem)
                Notifs.dismiss(list.currentItem.entry);
        } else if (key === Qt.Key_Less || key === Qt.Key_Comma)
            sheet.press(0);
        else if (key === Qt.Key_Greater || key === Qt.Key_Period)
            sheet.press(1);
        else if (key >= Qt.Key_3 && key <= Qt.Key_9)
            sheet.press(key - Qt.Key_1);
        else if (key === Qt.Key_Q || key === Qt.Key_Escape)
            sheet.closeRequested();
        else
            return;
        event.accepted = true;
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Theme.space.md
        spacing: Theme.space.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.sm

            Line {
                Layout.leftMargin: Theme.space.xs
                text: "Notifications"
                size: Theme.font.title
                weight: Font.DemiBold
                color: Theme.colors.fg
            }

            // The count, as a small pill.
            Rectangle {
                visible: Notifs.count > 0
                implicitHeight: 20
                implicitWidth: Math.max(implicitHeight, countText.implicitWidth + Theme.space.sm * 2)
                radius: Theme.radius.pill
                color: Theme.colors.withAlpha(Theme.colors.blue, 0.14)

                Line {
                    id: countText
                    anchors.centerIn: parent
                    text: Notifs.count
                    size: Theme.font.small
                    weight: Font.Medium
                    color: Theme.colors.blue
                }
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: Notifs.dnd ? "notifications_off" : "notifications_active"
                active: Notifs.dnd
                activeTint: Theme.colors.red
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            PillButton {
                text: "Clear all"
                icon: "clear_all"
                tint: Theme.colors.grey2
                enabled: Notifs.count > 0
                onClicked: Notifs.clear()
            }
        }

        // Under Do Not Disturb, a reminder that nothing pops up.
        Line {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space.xs
            visible: Notifs.dnd
            text: "Do Not Disturb is on: nothing pops up."
            size: Theme.font.smaller
            color: Theme.colors.red
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            visible: Notifs.count > 0
            clip: true
            spacing: Theme.space.sm
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            keyNavigationEnabled: false
            currentIndex: -1

            model: ScriptModel {
                values: Notifs.list
            }

            // The list shrinks under the selection: keep it on a row.
            onCountChanged: {
                if (currentIndex >= count)
                    currentIndex = count - 1;
            }
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: NotifCard {
                required property var modelData
                required property int index

                width: list.width
                entry: modelData
                selected: sheet.open && index === list.currentIndex
                keys: selected
            }

            add: Transition {
                Anim {
                    property: "opacity"
                    from: 0
                    to: 1
                    curve: "enter"
                }
            }

            remove: Transition {
                Anim {
                    property: "opacity"
                    to: 0
                    speed: "fast"
                    curve: "exit"
                }
            }

            displaced: Transition {
                Anim {
                    property: "y"
                }
                Anim {
                    property: "opacity"
                    to: 1
                }
            }
        }

        // Nothing left.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space.xl
            Layout.bottomMargin: Theme.space.xl
            visible: Notifs.count === 0
            spacing: Theme.space.sm

            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: "notifications"
                size: 40
                weight: 300
                color: Theme.colors.grey0
            }

            Line {
                Layout.alignment: Qt.AlignHCenter
                text: "No notifications"
                size: Theme.font.body
                color: Theme.colors.grey1
            }
        }
    }
}
