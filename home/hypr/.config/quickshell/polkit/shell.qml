// Polkit authentication agent for this Hyprland session, in place of
// polkit-gnome; hyprland.lua starts it as `quickshell -c polkit`. Howdy
// answers first through /etc/pam.d/polkit-1, and the password field
// appears when PAM asks for it. One request shows at a time: the agent
// queues the rest.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland

ShellRoot {
    id: root

    // Mapped, and the sheet in its open position. They differ while the
    // sheet slides away.
    property bool shown: false
    property bool open: false
    property var target: null

    function show() {
        closeTimer.stop();
        hideTimer.stop();
        root.target = root.focusedScreen();
        ctl.begin(agent.flow);
        root.shown = true;
        root.open = true;
        prompt.forceActiveFocus();
    }

    function close() {
        closeTimer.stop();
        root.open = false;
        hideTimer.restart();
    }

    // The screen Hyprland has focused, so the prompt shows where the owner
    // is looking.
    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    Colors {
        id: everforest
    }

    Controller {
        id: ctl
        onAskedForResponse: prompt.sheet.focusField()
        onRejected: prompt.sheet.shake()
        // Held long enough to read what was approved, so a request the
        // owner did not expect cannot pass unseen.
        onApproved: closeTimer.restart()
        onFinished: root.close()
    }

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: root.show()
        onIsRegisteredChanged: console.info("polkit agent registered:", agent.isRegistered)
    }

    Timer {
        id: closeTimer
        interval: 700
        onTriggered: root.close()
    }

    // The sheet's slide-out (220 ms in Prompt.qml), then unmap.
    Timer {
        id: hideTimer
        interval: 260
        onTriggered: {
            root.shown = false;
            ctl.flow = null;
        }
    }

    PanelWindow {
        visible: root.shown
        screen: root.target
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "polkit"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Prompt {
            id: prompt
            anchors.fill: parent
            colors: everforest
            controller: ctl
            open: root.open
        }
    }
}
