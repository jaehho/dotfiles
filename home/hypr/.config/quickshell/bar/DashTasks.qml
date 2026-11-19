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

    title: "TASKS" + (tasks.length ? "  ·  " + tasks.length : "")
    cmd: [Quickshell.env("HOME") + "/.local/bin/asst-gtk"]
    dimmed: feed.boardDown

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: card.tasks.slice(0, card.cap)

            RowLayout {
                id: taskRow

                required property var modelData

                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 3.5
                    color: card.overdue(taskRow.modelData) ? card.colors.red : card.colors.grey2
                }

                Line {
                    Layout.fillWidth: true
                    text: taskRow.modelData.summary
                    color: card.colors.fg
                    elide: Text.ElideRight
                }

                Line {
                    text: card.due(taskRow.modelData)
                    mono: true
                    size: 12
                    color: card.overdue(taskRow.modelData) ? card.colors.red : card.colors.grey2
                }
            }
        }

        Line {
            visible: card.tasks.length > card.cap
            text: "…and " + (card.tasks.length - card.cap) + " more"
            mono: true
            size: 12
            color: card.colors.grey2
        }

        // No board yet reads as loading, never as an empty list.
        Line {
            visible: !card.feed.board || (card.error === "" && card.tasks.length === 0)
            text: card.feed.board ? "nothing due today" : "…"
            color: card.colors.grey2
        }

        Line {
            visible: card.error !== ""
            Layout.fillWidth: true
            text: "tasks unavailable: " + card.error
            color: card.colors.yellow
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
