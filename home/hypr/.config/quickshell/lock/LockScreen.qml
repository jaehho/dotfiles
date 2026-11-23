// One screen of the lock (version A, "Lens", of the lock screen designs,
// #89): the blurred session behind a big clock and the date, the PIN field
// under them, and the lens dot at the laptop panel's top edge, right under
// the IR camera, while face unlock looks. A view only: shell.qml owns the
// PIN, the two PAM checks and when to unlock, and hears the keys from
// here.
//
// The PIN field is drawn, not a TextInput: no input method (fcitx5 typing
// Hangul) stands between the keys and the PIN, and every screen shows the
// same dots, whichever lock surface the compositor gives the keyboard.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland

Item {
    id: screenView

    // The screen this surface covers; the lens shows only on the laptop
    // panel, where the camera is.
    property var screen: null
    property bool capture: true
    property int typed: 0
    // idle | checking | wrong | unlocking
    property string phase: "idle"
    // looking | matched | off
    property string face: "off"
    property string note: ""
    property bool capsLock: false
    property string network: ""
    property string networkIcon: "network_wifi"
    property date now: new Date()

    signal typedText(string text)
    signal erased(bool all)
    signal submitted

    readonly property bool panel: screen?.name === "eDP-1"
    readonly property color tone: face === "matched" ? Theme.colors.green : phase === "wrong" ? Theme.colors.red : Theme.colors.blue
    readonly property var battery: UPower.displayDevice
    readonly property int percent: Math.round((battery?.percentage ?? 0) * 100)
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
    readonly property string statusLine: {
        if (phase === "checking")
            return "Checking…";
        if (face === "matched")
            return "Recognized. Unlocking.";
        if (phase === "unlocking")
            return "Unlocking.";
        if (face === "looking")
            return typed > 0 ? "Face unlock is looking too; the PIN goes through either way." : "Type your PIN, or just look at the camera.";
        return "";
    }

    function shake() {
        shakeAnim.restart();
    }

    // The keys must reach this item whatever happens: nothing else on the
    // lock may hold the focus.
    focus: true
    Component.onCompleted: forceActiveFocus()
    onActiveFocusChanged: if (!activeFocus)
        forceActiveFocus()

    Keys.onPressed: event => {
        const key = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (key === Qt.Key_Return || key === Qt.Key_Enter)
            screenView.submitted();
        else if (key === Qt.Key_Escape || (ctrl && (key === Qt.Key_Backspace || key === Qt.Key_U)))
            screenView.erased(true);
        else if (key === Qt.Key_Backspace)
            screenView.erased(false);
        else if (event.text !== "" && !ctrl && /^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text))
            screenView.typedText(event.text);
        else
            return;
        event.accepted = true;
    }

    // The session as it was, blurred and dimmed, as hyprlock showed it;
    // bg_dim under it in case the capture never comes.
    Rectangle {
        anchors.fill: parent
        color: Theme.colors.bg_dim
    }

    ScreencopyView {
        id: shot
        anchors.fill: parent
        visible: false
        captureSource: screenView.capture ? screenView.screen : null
    }

    MultiEffect {
        anchors.fill: parent
        visible: shot.hasContent
        source: shot
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.45
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: screenView.phase === "unlocking" ? 0 : 1

        Behavior on opacity {
            Anim {
                speed: "fast"
                curve: "exit"
            }
        }

        // The lens: under the camera, breathing while face unlock looks.
        Rectangle {
            id: lens
            visible: screenView.panel && screenView.face !== "off"
            x: Math.round((parent.width - width) / 2)
            y: 2
            width: 10
            height: 10
            radius: Theme.radius.pill
            color: screenView.tone

            Behavior on color {
                CAnim {}
            }

            SequentialAnimation {
                running: screenView.face === "looking"
                loops: Animation.Infinite
                onStopped: lens.opacity = 1
                NumberAnimation { target: lens; property: "opacity"; to: 0.25; duration: 750; easing.type: Easing.InOutSine }
                NumberAnimation { target: lens; property: "opacity"; to: 1; duration: 750; easing.type: Easing.InOutSine }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.23)
            spacing: Theme.space.md

            Line {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(screenView.now, "HH:mm")
                mono: true
                size: 120
                color: Theme.colors.fg
            }

            Line {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(screenView.now, "dddd, MMMM d")
                size: 20
                color: Theme.colors.grey2
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.52)
            spacing: 14

            // The PIN field: DESIGN.md's field, 48px tall, its dots drawn.
            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 48
                radius: Theme.radius.control
                color: Theme.colors.bg0
                border.width: 1
                border.color: screenView.phase === "wrong" ? Theme.colors.red : screenView.face === "matched" ? Theme.colors.green : Theme.colors.blue

                Behavior on border.color {
                    CAnim {}
                }

                transform: Translate {
                    id: nudge
                }

                Line {
                    visible: screenView.typed === 0
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PIN"
                    size: 18
                    color: Theme.colors.grey2
                }

                Row {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: Math.min(screenView.typed, 24)

                        Rectangle {
                            width: 8
                            height: 8
                            radius: Theme.radius.pill
                            color: Theme.colors.fg
                        }
                    }
                }

                Icon {
                    id: faceIcon
                    visible: screenView.face !== "off"
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    name: screenView.face === "matched" ? "check_circle" : "face"
                    fill: screenView.face === "matched" ? 1 : 0
                    color: screenView.face === "matched" ? Theme.colors.green : Theme.colors.grey2

                    SequentialAnimation {
                        running: screenView.face === "looking"
                        loops: Animation.Infinite
                        onStopped: faceIcon.opacity = 1
                        NumberAnimation { target: faceIcon; property: "opacity"; to: 0.25; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { target: faceIcon; property: "opacity"; to: 1; duration: 750; easing.type: Easing.InOutSine }
                    }
                }
            }

            // A wrong PIN, or what PAM said (faillock's lockout): the red
            // band, its words in fg (the Tint Rule).
            Rectangle {
                visible: screenView.phase === "wrong"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(field.width, words.implicitWidth + Theme.space.sm * 3 + Theme.icon.small)
                height: words.implicitHeight + Theme.space.sm * 2
                radius: Theme.radius.control
                color: Theme.colors.withAlpha(Theme.colors.red, 0.14)
                border.width: 1
                border.color: Theme.colors.withAlpha(Theme.colors.red, 0.45)

                Icon {
                    x: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    name: "error"
                    size: Theme.icon.small
                    fill: 1
                    color: Theme.colors.red
                }

                Line {
                    id: words
                    x: Theme.space.sm * 2 + Theme.icon.small
                    anchors.verticalCenter: parent.verticalCenter
                    text: screenView.note !== "" ? screenView.note : "Wrong PIN. Try again."
                    color: Theme.colors.fg
                }
            }

            Row {
                visible: screenView.capsLock
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "keyboard_capslock"
                    size: Theme.icon.small
                    color: Theme.colors.yellow
                }

                Line {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Caps Lock is on"
                    size: Theme.font.smaller
                    color: Theme.colors.yellow
                }
            }

            Line {
                visible: text !== "" && screenView.phase !== "wrong"
                anchors.horizontalCenter: parent.horizontalCenter
                text: screenView.statusLine
                size: Theme.font.smaller
                color: screenView.face === "matched" ? Theme.colors.green : Theme.colors.grey2
            }
        }

        // The network and the battery, in the top right corner.
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 28
            anchors.topMargin: 24
            spacing: 18

            Row {
                visible: screenView.network !== ""
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: screenView.networkIcon
                    size: 18
                    color: Theme.colors.grey2
                }

                Line {
                    anchors.verticalCenter: parent.verticalCenter
                    text: screenView.network
                    mono: true
                    color: Theme.colors.grey2
                }
            }

            Row {
                visible: screenView.battery?.isPresent ?? false
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: screenView.charging ? "battery_charging_full" : ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"][Math.max(0, Math.min(7, Math.floor(screenView.percent * 8 / 100)))]
                    size: 18
                    color: Theme.colors.grey2
                }

                Line {
                    anchors.verticalCenter: parent.verticalCenter
                    text: screenView.percent + "%"
                    mono: true
                    color: Theme.colors.grey2
                }
            }
        }
    }

    // A wrong PIN: the polkit sheet's short, damped shake.
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: nudge; property: "x"; to: -9; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: -5; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 3; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }
}
