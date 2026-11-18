// The dash panel: a full-height sheet on the right edge of one screen,
// under the bar, that replaces the always-on desktop dashboard (issue
// #83). It is its own layer surface, since the bar's surface is 640px
// tall. Open, it reserves its width, so the windows tile beside it;
// closed, it is unmapped and the desktop stays plain.
//
// Esc or a click outside closes it (the focus grab), and so does a click
// that opens something from a card (a session, tmux's tree, a usage
// page). It holds SESSIONS and LLM and never scrolls:
// .claude/rules/dash-panel.md.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property var colors
    required property var feed
    property bool open: false

    signal closeRequested

    onOpenChanged: fit.restart()

    // A card's click: run its command or open its link, then get out of
    // the way.
    function launch(url, cmd) {
        if (cmd && cmd.length)
            Quickshell.execDetached(cmd);
        if (url !== "")
            Qt.openUrlExternally(url);
        panel.closeRequested();
    }

    // The no-scroll rule's check: content taller than the sheet is cut
    // off at the bottom, so say so in the bar's log. Only once open and
    // settled: closed, or before the compositor sizes it, the sheet is
    // not its real height.
    Timer {
        id: fit
        interval: 500
        onTriggered: if (panel.open && cards.implicitHeight > body.height)
            console.warn("dash panel overflows:", Math.ceil(cards.implicitHeight), "px of content in", Math.floor(body.height));
    }

    anchors {
        top: true
        bottom: true
        right: true
    }
    // Auto reserves the panel's width plus its right margin, so the
    // tiled windows slide aside instead of being covered, and the margins
    // count from under the bar's 40px (top 8 lands at y=48, level with
    // the windows).
    margins {
        top: 8
        right: 8
        bottom: 8
    }
    implicitWidth: 440
    color: "transparent"
    // Mapped while it slides, so the close animation is seen.
    visible: sheet.opacity > 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "bar-dash"
    WlrLayershell.keyboardFocus: panel.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: panel.closeRequested()
    }

    Item {
        id: sheet
        width: panel.width
        height: panel.height
        x: panel.open ? 0 : 24
        opacity: panel.open ? 1 : 0
        focus: panel.open

        Keys.onEscapePressed: panel.closeRequested()

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        RectangularShadow {
            anchors.fill: parent
            radius: 12
            blur: 6
            color: panel.colors.withAlpha(panel.colors.bg_dim, 0.93)
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: panel.colors.withAlpha(panel.colors.bg_dim, 0.985)
            border.width: 1
            border.color: panel.colors.withAlpha(panel.colors.blue, 0.18)
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            onHeightChanged: fit.restart()

            ColumnLayout {
                id: cards
                width: parent.width
                spacing: 12
                onImplicitHeightChanged: fit.restart()

                DashSessions {
                    Layout.fillWidth: true
                    colors: panel.colors
                    feed: panel.feed
                    onLaunch: (url, cmd) => panel.launch(url, cmd)
                }

                DashLlm {
                    Layout.fillWidth: true
                    colors: panel.colors
                    feed: panel.feed
                    onLaunch: (url, cmd) => panel.launch(url, cmd)
                }
            }
        }
    }
}
