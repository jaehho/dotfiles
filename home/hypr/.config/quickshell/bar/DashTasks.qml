// The TASKS card: asst's tasks due today or overdue, nothing else (the
// inbox stays in asst), six at most. Overdue (an earlier local day;
// late today is not) is red. The card opens asst-gtk.
import QtQuick
import QtQuick.Layouts
import Quickshell

DashCard {
    id: card

    required property var feed

    // The panel never scrolls (.claude/rules/dash-panel.md): this cap is
    // the card's share of the height.
    readonly property int cap: 6
    // dash-data hands back {error} instead of a list when asst failed.
    readonly property var tasks: feed.board && Array.isArray(feed.board.tasks) ? feed.board.tasks : []
    readonly property string error: feed.board && feed.board.tasks && !Array.isArray(feed.board.tasks) ? (feed.board.tasks.error || "unreadable") : ""
    // The local day, from the feed's clock, so it turns at midnight.
    readonly property string today: Qt.formatDate(new Date(feed.now), "yyyy-MM-dd")

    function overdue(t) {
        return !!t.due_date && t.due_date < card.today;
    }

    // "overdue 10-17", "due 10-20", the time for a timed task due today,
    // nothing for an undated one.
    function due(t) {
        const d = t.due_date;
        if (!d)
            return "";
        if (d === card.today)
            return t.due_time || "";
        return (d < card.today ? "overdue " : "due ") + d.slice(5);
    }

    title: "Tasks"
    icon: "task_alt"
    detail: tasks.length ? String(tasks.length) : ""
    cmd: [Quickshell.env("HOME") + "/.local/bin/asst-gtk"]
    dimmed: feed.boardDown

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: card.tasks.slice(0, card.cap)

            DashRow {
                id: taskRow

                required property var modelData

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.space.sm

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: Theme.radius.pill
                        color: card.overdue(taskRow.modelData) ? Theme.colors.red : Theme.colors.grey2
                    }

                    Line {
                        Layout.fillWidth: true
                        text: taskRow.modelData.summary
                        color: Theme.colors.fg
                        elide: Text.ElideRight
                    }

                    Line {
                        text: card.due(taskRow.modelData)
                        mono: true
                        size: Theme.font.smaller
                        color: card.overdue(taskRow.modelData) ? Theme.colors.red : Theme.colors.grey2
                    }
                }
            }
        }

        Line {
            visible: card.tasks.length > card.cap
            Layout.topMargin: Theme.space.xs
            text: "…and " + (card.tasks.length - card.cap) + " more"
            size: Theme.font.small
            color: Theme.colors.grey2
        }

        // No board yet reads as loading, never as an empty list.
        Line {
            visible: !card.feed.board || (card.error === "" && card.tasks.length === 0)
            text: card.feed.board ? "Nothing due today" : "…"
            color: Theme.colors.grey2
        }

        Line {
            visible: card.error !== ""
            Layout.fillWidth: true
            text: "Tasks unavailable: " + card.error
            color: Theme.colors.yellow
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
