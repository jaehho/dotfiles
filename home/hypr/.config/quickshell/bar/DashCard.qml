// A card on the dash panel: a small caps title over its rows, on the
// panel's glass. Rows go in as children.
//
// A card with a url or cmd opens it on a click outside a row's own
// target (`launch`; the panel then closes). A row can launch its own.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property var colors
    property string title
    // Shown red beside the title, e.g. "live feed down".
    property string alert: ""
    // Its feed is down: the rows dim (the title and alert do not), so
    // old rows don't read as now.
    property bool dimmed: false
    property string url: ""
    property var cmd: null
    default property alias content: inner.data

    signal launch(string url, var cmd)

    implicitHeight: outer.implicitHeight + 28
    radius: 12
    color: colors.withAlpha(colors.bg1, 0.55)

    // Behind the rows, so a row's own MouseArea wins where it has one.
    MouseArea {
        z: -1
        anchors.fill: parent
        enabled: card.url !== "" || card.cmd !== null
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.launch(card.url, card.cmd)
    }

    ColumnLayout {
        id: outer
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Line {
                text: card.title
                mono: true
                size: 11
                color: card.colors.grey2
                font.letterSpacing: 2
            }

            Item {
                Layout.fillWidth: true
            }

            Line {
                visible: card.alert !== ""
                text: card.alert
                size: 12
                color: card.colors.red
            }
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            spacing: 8
            opacity: card.dimmed ? 0.45 : 1
        }
    }
}
