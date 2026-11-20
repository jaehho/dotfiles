// A page's top row on the quick settings sheet: back to the main page
// under the page's name, and at the right an on/off switch for pages
// that have one. The arrow is a Material Symbol (#89).
import QtQuick

Item {
    id: head

    required property var sheet
    property string title: ""
    property bool switchable: false
    readonly property alias toggle: radio

    signal switched

    width: parent.width
    height: 36

    // The arrow in line with the rows' icons below (QuickRow).
    QuickControl {
        sheet: head.sheet
        hintText: "Back"
        flat: true
        x: 3
        width: label.implicitWidth + Theme.space.md * 2
        height: parent.height
        onActivated: head.sheet.back()

        Row {
            id: label
            x: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "arrow_back"
                color: Theme.colors.grey2
            }

            Line {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.font.title
                weight: Font.DemiBold
                text: head.title
                color: Theme.colors.fg
            }
        }
    }

    QuickSwitch {
        id: radio
        sheet: head.sheet
        hintText: "Toggle"
        visible: head.switchable
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.xs
        anchors.verticalCenter: parent.verticalCenter
        onActivated: head.switched()
    }
}
