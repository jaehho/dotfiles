// The full-screen layer: a dim over everything, and the sheet hanging from
// the top edge, centred under the IR camera. One motion: the sheet drops
// in, and goes back up into the edge when the request ends, on the
// shell's timing (Theme.motion: arriving slow on `enter`, leaving normal
// on `exit`).
import QtQuick

FocusScope {
    id: root

    required property var controller
    property bool open: false
    readonly property alias sheet: sheet

    focus: true

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.open ? 0.4 : 0

        Behavior on opacity {
            Anim {
                curve: root.open ? "enter" : "exit"
            }
        }

        // Modal: a click on the dim goes nowhere.
        MouseArea {
            anchors.fill: parent
        }
    }

    AuthSheet {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.open ? 0 : -height - 2
        focus: true
        message: root.controller.message
        actionId: root.controller.actionId
        phase: root.controller.phase
        note: root.controller.note
        tone: root.controller.tone
        placeholder: root.controller.placeholder
        echo: root.controller.echo
        onSubmitted: value => root.controller.submit(value)
        onCancelled: root.controller.cancel()

        Behavior on y {
            Anim {
                speed: root.open ? "slow" : "normal"
                curve: root.open ? "enter" : "exit"
            }
        }
    }
}
