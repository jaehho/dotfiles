// A line on a dash card (#89): 24px tall unless its content sets the
// height, its content at the card's padding. One that opens something
// washes under the pointer, reaching 8px past the content at each side
// (and `bleed` above and below): a pill, or 8px corners for a block of
// more than one line. Content goes in as children and fills the row.
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property bool interactive: false
    property real radius: Theme.radius.pill
    property int bleed: 0
    default property alias content: holder.data

    signal clicked

    Layout.fillWidth: true
    implicitHeight: 24

    StateLayer {
        anchors.leftMargin: -Theme.space.sm
        anchors.rightMargin: -Theme.space.sm
        anchors.topMargin: -row.bleed
        anchors.bottomMargin: -row.bleed
        visible: row.interactive
        enabled: row.interactive
        onClicked: () => row.clicked()
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
