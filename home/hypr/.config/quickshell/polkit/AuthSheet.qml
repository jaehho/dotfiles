// The sheet that hangs from the top edge of the screen, under the IR
// camera, on the shell base (#89): the shell's sheet tone, outline and
// shadow, Material Symbols, the Inputs field and tonal pills. A view
// only: Controller decides what it says. The top corners stay square
// because they meet the screen edge.
//
// The tokens and controls are the bar's own files, linked into this
// config (Theme.qml and the rest), so the prompt keeps its own process:
// a bar restart never drops a pending request.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

FocusScope {
    id: sheet

    property string message
    property string actionId
    // starting | scanning | password | checking | approved
    property string phase: "starting"
    property string note
    // info | warn | error | ok
    property string tone: "info"
    property string placeholder: "Password"
    property bool echo: false
    property alias text: field.text

    signal submitted(string value)
    signal cancelled

    readonly property bool asking: phase === "password" || phase === "checking"
    // The two frames the owner must not miss are banded (DESIGN.md,
    // Status Bands), not just a coloured icon.
    readonly property bool banded: tone === "ok" || tone === "error"
    readonly property color toneColor: tone === "ok" ? Theme.colors.green : tone === "warn" ? Theme.colors.yellow : tone === "error" ? Theme.colors.red : Theme.colors.blue
    readonly property string statusIcon: phase === "approved" ? "check_circle" : tone === "error" ? "error" : phase === "checking" ? "key" : "face"

    function focusField() {
        field.forceActiveFocus();
    }

    function shake() {
        shakeAnim.restart();
    }

    function submit() {
        // An empty Enter would only spend one of pam_faillock's attempts.
        if (phase !== "password" || field.text === "")
            return;
        const value = field.text;
        field.text = "";
        submitted(value);
    }

    implicitWidth: 440
    implicitHeight: column.implicitHeight + column.y + Theme.space.lg
    height: implicitHeight
    focus: true
    Keys.onEscapePressed: sheet.cancelled()

    Behavior on height {
        Anim {}
    }

    transform: Translate {
        id: nudge
    }

    // A wrong password: a short, damped shake, the one motion here that
    // is feedback rather than arrival.
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: nudge; property: "x"; to: -9; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: -5; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 3; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }

    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radius.surface
        blur: 6
        color: Theme.surface.shadow
    }

    Rectangle {
        anchors.fill: parent
        // The outline traces the sides and bottom only: the sheet stays
        // open to the edge it hangs from.
        anchors.topMargin: -1
        color: Theme.surface.sheet
        border.width: 1
        border.color: Theme.surface.outline
        bottomLeftRadius: Theme.radius.surface
        bottomRightRadius: Theme.radius.surface
    }

    // The lens: a dot on the top edge, right under the IR camera, like the
    // camera's own light. It breathes while PAM is busy and holds the state
    // colour after.
    Rectangle {
        id: lens
        anchors.horizontalCenter: parent.horizontalCenter
        y: 2
        width: 10
        height: 10
        radius: Theme.radius.pill
        color: sheet.toneColor

        Behavior on color {
            CAnim {}
        }

        SequentialAnimation {
            running: sheet.phase === "starting" || sheet.phase === "scanning" || sheet.phase === "checking"
            loops: Animation.Infinite
            onStopped: lens.opacity = 1
            NumberAnimation { target: lens; property: "opacity"; to: 0.25; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { target: lens; property: "opacity"; to: 1; duration: 750; easing.type: Easing.InOutSine }
        }
    }

    // Content clips while the height animates; the shadow above must not.
    Item {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            id: column
            x: Theme.space.xl
            y: Theme.space.xl
            width: parent.width - Theme.space.xl * 2
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space.md

                Icon {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Theme.icon.large
                    name: "shield_lock"
                    size: Theme.icon.large
                    color: Theme.colors.fg
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space.xs

                    Line {
                        Layout.fillWidth: true
                        text: sheet.message
                        size: Theme.font.title
                        weight: Font.DemiBold
                        color: Theme.colors.fg
                        wrapMode: Text.Wrap
                    }

                    Line {
                        Layout.fillWidth: true
                        text: sheet.actionId
                        mono: true
                        size: Theme.font.small
                        color: Theme.colors.grey2
                        elide: Text.ElideMiddle
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space.lg
                visible: sheet.note !== ""
                implicitHeight: status.implicitHeight

                // Drawn outside the text column, so the icon and words stay
                // on the title's lines whether or not the band shows.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.space.sm
                    radius: Theme.radius.control
                    color: sheet.banded ? Theme.colors.withAlpha(sheet.toneColor, 0.14) : "transparent"
                    border.width: 1
                    border.color: sheet.banded ? Theme.colors.withAlpha(sheet.toneColor, 0.45) : "transparent"

                    Behavior on color {
                        CAnim {}
                    }
                }

                RowLayout {
                    id: status
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.space.md

                    Icon {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: Theme.icon.large
                        name: sheet.statusIcon
                        size: Theme.icon.small
                        fill: sheet.banded ? 1 : 0
                        color: sheet.toneColor
                    }

                    Line {
                        Layout.fillWidth: true
                        text: sheet.note
                        weight: sheet.tone === "ok" ? Font.DemiBold : Font.Normal
                        // Green on the green band holds 5.5:1; red on the red
                        // band falls to 4.3:1, so an error keeps its red in
                        // the icon, fill and edge and its words in fg.
                        color: sheet.tone === "ok" ? Theme.colors.green : Theme.colors.fg
                        wrapMode: Text.Wrap
                    }
                }
            }

            // DESIGN.md's field.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space.lg
                visible: sheet.asking
                implicitHeight: 36
                radius: Theme.radius.control
                color: Theme.colors.bg0
                border.width: 1
                border.color: field.activeFocus ? Theme.colors.blue : Theme.colors.bg2

                Behavior on border.color {
                    CAnim {}
                }

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.md
                    anchors.rightMargin: Theme.space.md
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    enabled: sheet.phase === "password"
                    echoMode: sheet.echo ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.colors.fg
                    selectionColor: Theme.colors.withAlpha(Theme.colors.blue, 0.35)
                    selectedTextColor: Theme.colors.fg
                    selectByMouse: true
                    font.family: Theme.font.sans
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    Keys.onReturnPressed: sheet.submit()
                    Keys.onEnterPressed: sheet.submit()

                    cursorDelegate: Rectangle {
                        width: 1
                        color: Theme.colors.blue
                        visible: field.activeFocus
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text === "" && field.preeditText === ""
                        text: sheet.placeholder
                        color: Theme.colors.grey2
                        font: field.font
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Tonal pills with their keys at the end: Cancel is the sheet's
            // own housekeeping (grey2), Approve the action on offer (blue).
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: Theme.space.lg
                spacing: Theme.space.sm
                // Gone once approved: the sheet's height animation closes the
                // gap, leaving the approval as the last thing on it.
                visible: sheet.phase !== "approved"

                PillButton {
                    text: "Cancel"
                    badge: "Esc"
                    tint: Theme.colors.grey2
                    onClicked: sheet.cancelled()
                }

                PillButton {
                    visible: sheet.asking
                    enabled: sheet.phase === "password"
                    text: "Approve"
                    badge: "Enter"
                    onClicked: sheet.submit()
                }
            }
        }
    }
}
