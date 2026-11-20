// A join failure under a row on the quick settings sheet's Wi-Fi and
// Bluetooth pages, as the polkit sheet bands a wrong password: red in
// the icon, the fill (0.14) and the edge (0.45), the words in fg.
import QtQuick

Rectangle {
    id: band

    property string text: ""

    height: words.implicitHeight + Theme.space.sm * 2
    radius: Theme.radius.control
    color: Theme.colors.withAlpha(Theme.colors.red, 0.14)
    border.width: 1
    border.color: Theme.colors.withAlpha(Theme.colors.red, 0.45)

    // Centered on the first line of the words.
    Icon {
        x: Theme.space.sm
        y: words.y
        height: words.implicitHeight / Math.max(1, words.lineCount)
        name: "error"
        size: Theme.icon.small
        fill: 1
        color: Theme.colors.red
    }

    Line {
        id: words
        x: Theme.space.sm * 2 + Theme.icon.small
        y: Theme.space.sm
        width: parent.width - x - Theme.space.sm
        wrapMode: Text.Wrap
        text: band.text
        color: Theme.colors.fg
    }
}
