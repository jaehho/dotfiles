// A card on the dash panel (#83), on the shell base (#89): the card tone
// with 12px corners and padding, a heading (its Material Symbol and its
// name in Heading type, grey2, then a detail such as a count) over its
// rows. Rows go in as children.
//
// A card with a url or cmd opens it on a click outside a row's own
// target, washing under the pointer (`launch`; the panel then closes).
// A row can launch its own (DashRow).
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property string title
    // A Material Symbols name.
    property string icon
    // After the title, e.g. "12" or "11-18 close".
    property string detail: ""
    // Shown red at the heading's end, e.g. "claude synced 2h ago".
    property string alert: ""
    // Its feed is down: the rows dim (the heading does not), so old rows
    // don't read as now.
    property bool dimmed: false
    property string url: ""
    property var cmd: null
    default property alias content: inner.data

    signal launch(string url, var cmd)

    implicitHeight: outer.implicitHeight + Theme.space.md * 2
    radius: Theme.radius.surface
    color: Theme.surface.card

    // Under the rows, so a row's own target takes its click first.
    StateLayer {
        enabled: card.url !== "" || card.cmd !== null
        onClicked: () => card.launch(card.url, card.cmd)
    }

    ColumnLayout {
        id: outer
        anchors.fill: parent
        anchors.margins: Theme.space.md
        spacing: Theme.space.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.sm

            Icon {
                name: card.icon
                size: Theme.icon.small
                color: Theme.colors.grey2
            }

            Line {
                text: card.title
                size: Theme.font.small
                weight: Font.Bold
                font.capitalization: Font.AllUppercase
                color: Theme.colors.grey2
            }

            Line {
                visible: card.detail !== ""
                text: card.detail
                size: Theme.font.small
                color: Theme.colors.grey2
            }

            Item {
                Layout.fillWidth: true
            }

            Line {
                visible: card.alert !== ""
                Layout.maximumWidth: card.width / 2
                elide: Text.ElideRight
                text: card.alert
                size: Theme.font.small
                color: Theme.colors.red
            }
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            spacing: Theme.space.sm
            opacity: card.dimmed ? 0.45 : 1
        }
    }
}
