// A page's last row on the quick settings sheet: the tool that does what
// the page doesn't (nmtui, bluetui, wiremix), shown while the table has
// its entry, opened on a press.
import QtQuick

QuickControl {
    id: foot

    property string entry: ""
    property int glyph: 0xf018d
    property string text: ""

    flat: true
    visible: sheet.entries.some(e => e.id === foot.entry)
    x: 3
    width: parent.width - 6
    height: 32
    onActivated: sheet.launch(foot.entry)

    Row {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Line {
            anchors.verticalCenter: parent.verticalCenter
            mono: true
            size: 16
            text: String.fromCodePoint(foot.glyph)
            color: foot.colors.fg
        }

        Line {
            anchors.verticalCenter: parent.verticalCenter
            text: foot.text
            color: foot.colors.fg
        }
    }
}
