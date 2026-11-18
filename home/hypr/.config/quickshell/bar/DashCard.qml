// A card on the dash panel: a small caps title over its rows, on the
// panel's glass. Rows go in as children.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property var colors
    property string title
    // Shown red beside the title, e.g. "live feed down".
    property string alert: ""
    default property alias content: inner.data

    implicitHeight: inner.implicitHeight + 28
    radius: 12
    color: colors.withAlpha(colors.bg1, 0.55)

    ColumnLayout {
        id: inner
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
    }
}
