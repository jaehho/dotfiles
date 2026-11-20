// A page's last row on the quick settings sheet: the tool that does what
// the page doesn't (nmtui, bluetui, wiremix), shown while the table has
// its entry, opened on a press.
import QtQuick

QuickRow {
    id: foot

    property string entry: ""

    icon: "terminal"
    visible: sheet.entries.some(e => e.id === foot.entry)
    x: 3
    width: parent.width - 6
    onActivated: sheet.launch(foot.entry)
}
