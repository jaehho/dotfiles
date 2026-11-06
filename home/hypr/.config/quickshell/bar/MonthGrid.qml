// The open island's month: its name with previous and next, the weekday
// initials, and the weeks the month spans, today in the one solid blue
// marker. The week starts where the locale says.
import QtQuick

Item {
    id: grid

    required property var colors
    required property date today
    // Months away from today's month; h and l on the island move it.
    property int offset: 0

    readonly property int cellWidth: 32
    readonly property int cellHeight: 26
    readonly property int weekStart: Qt.locale().firstDayOfWeek
    readonly property date first: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int lead: (first.getDay() - weekStart + 7) % 7
    readonly property int days: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
    readonly property int weeks: Math.ceil((lead + days) / 7)

    implicitWidth: 7 * cellWidth
    implicitHeight: heading.height + 8 + initials.height + 4 + weeks * cellHeight

    Item {
        id: heading
        width: parent.width
        height: 26

        // Clicking the name of another month comes back to this one.
        Line {
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            text: Qt.locale().standaloneMonthName(grid.first.getMonth()) + " " + grid.first.getFullYear()
            weight: Font.DemiBold
            color: grid.colors.fg

            HoverHandler {
                cursorShape: grid.offset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                onTapped: grid.offset = 0
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 4

            SheetButton {
                colors: grid.colors
                glyph: 0xf0141
                glyphSize: 14
                implicitWidth: 28
                implicitHeight: 26
                onClicked: grid.offset -= 1
            }

            SheetButton {
                colors: grid.colors
                glyph: 0xf0142
                glyphSize: 14
                implicitWidth: 28
                implicitHeight: 26
                onClicked: grid.offset += 1
            }
        }
    }

    Row {
        id: initials
        y: heading.height + 8

        Repeater {
            model: 7

            Line {
                required property int index
                width: grid.cellWidth
                horizontalAlignment: Text.AlignHCenter
                size: 11
                text: Qt.locale().dayName((grid.weekStart + index) % 7, Locale.NarrowFormat)
                color: grid.colors.grey2
            }
        }
    }

    Grid {
        y: initials.y + initials.height + 4
        columns: 7

        Repeater {
            model: grid.weeks * 7

            Item {
                id: cell

                required property int index
                readonly property int day: index - grid.lead + 1
                readonly property bool inMonth: day >= 1 && day <= grid.days
                readonly property bool isToday: grid.offset === 0 && day === grid.today.getDate()

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: grid.cellWidth - 2
                    height: grid.cellHeight - 2
                    radius: 8
                    color: grid.colors.blue
                    visible: cell.inMonth && cell.isToday
                }

                Line {
                    anchors.centerIn: parent
                    visible: cell.inMonth
                    mono: true
                    text: cell.day
                    weight: cell.isToday ? Font.Bold : Font.Normal
                    color: cell.isToday ? grid.colors.bg0 : grid.colors.fg
                }
            }
        }
    }
}
