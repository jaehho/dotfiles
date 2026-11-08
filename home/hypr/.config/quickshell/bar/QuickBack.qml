// A page's top row on the quick settings sheet: back to the main page
// under the page's name, and at the right an on/off switch for pages
// that have one.
import QtQuick

Item {
    id: head

    required property var sheet
    property string title: ""
    property bool switchable: false
    readonly property alias toggle: radio

    signal switched

    width: parent.width
    height: 32

    QuickControl {
        sheet: head.sheet
        flat: true
        width: label.implicitWidth + 20
        height: 32
        onActivated: head.sheet.back()

        Row {
            id: label
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Line {
                anchors.verticalCenter: parent.verticalCenter
                mono: true
                size: 16
                text: String.fromCodePoint(0xf0141)
                color: head.sheet.colors.grey2
            }

            Line {
                anchors.verticalCenter: parent.verticalCenter
                size: 15
                weight: Font.DemiBold
                text: head.title
                color: head.sheet.colors.fg
            }
        }
    }

    QuickSwitch {
        id: radio
        sheet: head.sheet
        visible: head.switchable
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        onActivated: head.switched()
    }
}
