// A line on a dash card (#89): 24px tall, its content at the card's
// padding. One that opens something washes under the pointer, in a pill
// that reaches 8px past the content on each side. Content goes in as
// children and fills the row.
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property bool interactive: false
    default property alias content: holder.data

    signal clicked

    Layout.fillWidth: true
    implicitHeight: 24

    StateLayer {
        anchors.leftMargin: -Theme.space.sm
        anchors.rightMargin: -Theme.space.sm
        radius: Theme.radius.pill
        visible: row.interactive
        enabled: row.interactive
        onClicked: () => row.clicked()
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
