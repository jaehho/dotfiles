// The sheet that hangs from the top edge of the screen, under the IR
// camera. A view only: Controller decides what it says. Radii follow the
// desktop scale (12 for the sheet, 8 for controls); the top corners stay
// square because they meet the screen edge.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

FocusScope {
    id: sheet

    required property var colors
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
    // The two frames the owner must not miss get the settings menu's tinted
    // state (its tile.on and session.armed), not just a coloured glyph.
    readonly property bool banded: tone === "ok" || tone === "error"
    readonly property color toneColor: tone === "ok" ? colors.green : tone === "warn" ? colors.yellow : tone === "error" ? colors.red : colors.blue
    readonly property int statusGlyph: phase === "approved" ? 0xF05E0 // md-check_circle
    : tone === "error" ? 0xF0028 // md-alert_circle
    : phase === "checking" ? 0xF030B // md-key_variant
    : 0xF0C7B // md-face_recognition

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
    implicitHeight: column.implicitHeight + column.anchors.topMargin + 20
    height: implicitHeight
    focus: true
    Keys.onEscapePressed: sheet.cancelled()

    Behavior on height {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutExpo
        }
    }

    transform: Translate {
        id: nudge
    }

    // A wrong password: a short, damped shake.
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: nudge; property: "x"; to: -9; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: -5; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 3; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }

    // Hyprland's window shadow (decoration.shadow in hyprland.lua: range 4,
    // bg_dim at 0xee), which layer surfaces do not get on their own.
    RectangularShadow {
        anchors.fill: parent
        radius: 12
        blur: 6
        color: sheet.colors.withAlpha(sheet.colors.bg_dim, 0.93)
    }

    Rectangle {
        anchors.fill: parent
        // The hairline traces the sides and bottom only: the sheet stays open
        // to the edge it hangs from.
        anchors.topMargin: -1
        color: sheet.colors.withAlpha(sheet.colors.bg_dim, 0.985)
        border.width: 1
        border.color: sheet.colors.bg2
        bottomLeftRadius: 12
        bottomRightRadius: 12
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
        radius: 5
        color: sheet.toneColor

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 26
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Glyph {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                    code: 0xF099D // md-shield_lock
                    size: 22
                    color: sheet.colors.fg
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Line {
                        Layout.fillWidth: true
                        text: sheet.message
                        size: 15
                        weight: Font.DemiBold
                        color: sheet.colors.fg
                        wrapMode: Text.Wrap
                    }

                    Line {
                        Layout.fillWidth: true
                        text: sheet.actionId
                        mono: true
                        size: 11
                        color: sheet.colors.grey2
                        elide: Text.ElideMiddle
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: 16
                visible: sheet.note !== ""
                implicitHeight: status.implicitHeight

                // Drawn outside the text column, so the glyph and words stay
                // on the title's lines whether or not the band shows.
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -10
                    anchors.rightMargin: -10
                    anchors.topMargin: -7
                    anchors.bottomMargin: -7
                    radius: 8
                    color: sheet.banded ? sheet.colors.withAlpha(sheet.toneColor, 0.14) : "transparent"
                    border.width: 1
                    border.color: sheet.banded ? sheet.colors.withAlpha(sheet.toneColor, 0.45) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                }

                RowLayout {
                    id: status
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 14

                    Glyph {
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        code: sheet.statusGlyph
                        size: 16
                        color: sheet.toneColor
                    }

                    Line {
                        Layout.fillWidth: true
                        text: sheet.note
                        size: 13
                        weight: sheet.tone === "ok" ? Font.DemiBold : Font.Normal
                        // Green on the green band holds 5.5:1; red on the red
                        // band falls to 4.3:1, so an error keeps its red in the
                        // glyph, fill and border and its words in fg.
                        color: sheet.tone === "ok" ? sheet.colors.green : sheet.colors.fg
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: sheet.asking
                implicitHeight: 36
                radius: 8
                color: sheet.colors.bg0
                border.width: 1
                border.color: field.activeFocus ? sheet.colors.blue : sheet.colors.bg2

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    enabled: sheet.phase === "password"
                    echoMode: sheet.echo ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: sheet.colors.fg
                    selectionColor: sheet.colors.withAlpha(sheet.colors.blue, 0.35)
                    selectedTextColor: sheet.colors.fg
                    selectByMouse: true
                    font.family: "Adwaita Sans"
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    Keys.onReturnPressed: sheet.submit()
                    Keys.onEnterPressed: sheet.submit()

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text === "" && field.preeditText === ""
                        text: sheet.placeholder
                        color: sheet.colors.grey2
                        font: field.font
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 18
                spacing: 8
                // Gone once approved: the sheet's height animation closes the
                // gap, leaving the approval as the last thing on it.
                visible: sheet.phase !== "approved"

                SheetButton {
                    colors: sheet.colors
                    label: "Cancel"
                    hint: "Esc"
                    onClicked: sheet.cancelled()
                }

                SheetButton {
                    colors: sheet.colors
                    visible: sheet.asking
                    enabled: sheet.phase === "password"
                    primary: true
                    label: "Approve"
                    hint: "Enter"
                    onClicked: sheet.submit()
                }
            }
        }
    }

    component Glyph: Text {
        property int code
        property int size: 16
        text: String.fromCodePoint(code)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: size
        renderType: Text.NativeRendering
    }

    component Line: Text {
        property int size: 13
        property int weight: Font.Normal
        property bool mono: false
        font.family: mono ? "JetBrainsMono Nerd Font" : "Adwaita Sans"
        font.pixelSize: size
        font.weight: weight
        renderType: Text.NativeRendering
    }

    component SheetButton: Rectangle {
        id: button

        required property var colors
        property string label
        property string hint
        property bool primary: false

        signal clicked

        implicitWidth: row.implicitWidth + 24
        implicitHeight: 30
        radius: 8
        opacity: enabled ? 1 : 0.5
        color: primary ? colors.withAlpha(colors.blue, hover.hovered ? 0.28 : 0.18) : hover.hovered ? colors.bg1 : colors.bg0
        border.width: 1
        border.color: primary ? colors.withAlpha(colors.blue, 0.55) : hover.hovered ? colors.bg3 : colors.bg1

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: if (button.enabled)
                button.clicked()
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Line {
                text: button.label
                size: 13
                color: button.colors.fg
            }

            Line {
                anchors.verticalCenter: parent.verticalCenter
                text: button.hint
                mono: true
                size: 10
                color: button.primary ? button.colors.fg : button.colors.grey2
            }
        }
    }
}
