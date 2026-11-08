// The right island, clustered by what a glance is for, with a short
// hairline before each cluster after the first, as waybar drew it:
// attention, load, output, battery and radios, then quick settings and
// the power menu.
//
// It opens into the quick settings sheet (QuickSettings.qml) the way the
// center island opens into the player: it grows out of itself, leftward
// and down, and its glyph row stays where it was, live, as the sheet's
// header. Super + ;, its glyph, or a right click on the network glyph
// opens it.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: rightIsland

    required property var bar
    readonly property var colors: bar.colors
    // The status cluster, for the IPC refresh of stay-awake.
    readonly property alias attention: attention
    property bool open: false
    property string page: "main"
    property bool keys: false

    readonly property int restHeight: 26
    readonly property int restWidth: header.implicitWidth + 12
    readonly property int openWidth: Math.max(restWidth, 460)
    readonly property int openHeight: restHeight + 10 + sheet.implicitHeight + 16
    // 0 at rest and 1 open. The width follows it, so the glyph row
    // still sizes the island at once while it rests (the tray sliding
    // out); the height follows the page, so it eases when one opens.
    property real progress: open ? 1 : 0

    width: restWidth + (openWidth - restWidth) * progress
    height: open ? openHeight : restHeight

    Behavior on progress {
        NumberAnimation {
            duration: rightIsland.open ? 260 : 200
            easing.type: rightIsland.open ? Easing.OutExpo : Easing.InOutCubic
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: rightIsland.open ? 260 : 200
            easing.type: rightIsland.open ? Easing.OutExpo : Easing.InOutCubic
        }
    }

    function blend(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    component Divider: Item {
        required property color line

        width: 13
        height: 24

        Rectangle {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: parent.line
        }
    }

    // As the center island: the window edge once open, and the glass
    // giving way to the sheets' bg_dim.
    RectangularShadow {
        anchors.fill: parent
        radius: 12
        blur: 6
        color: rightIsland.colors.withAlpha(rightIsland.colors.bg_dim, 0.93)
        opacity: rightIsland.progress
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: rightIsland.blend(rightIsland.colors.withAlpha(rightIsland.colors.bg0, 0.88), rightIsland.colors.withAlpha(rightIsland.colors.bg_dim, 0.985), rightIsland.progress)
        border.width: 1
        border.color: rightIsland.colors.withAlpha(rightIsland.colors.blue, 0.18)
    }

    Row {
        id: header
        anchors.right: parent.right
        anchors.rightMargin: 6
        y: 1

        StatusCluster {
            id: attention
            bar: rightIsland.bar
        }

        Divider {
            line: rightIsland.colors.withAlpha(rightIsland.colors.blue, 0.28)
        }

        LoadGlance {
            bar: rightIsland.bar
        }

        Divider {
            line: rightIsland.colors.withAlpha(rightIsland.colors.blue, 0.28)
        }

        OutputCluster {
            bar: rightIsland.bar
        }

        Divider {
            line: rightIsland.colors.withAlpha(rightIsland.colors.blue, 0.28)
        }

        LinkCluster {
            bar: rightIsland.bar
        }

        Divider {
            line: rightIsland.colors.withAlpha(rightIsland.colors.blue, 0.28)
        }

        // fg while its sheet is open, as a control that is in use.
        BarButton {
            bar: rightIsland.bar
            text: String.fromCodePoint(0xf1542)
            tint: rightIsland.open ? rightIsland.colors.fg : rightIsland.colors.grey2
            tip: "Quick settings (Super+;)"
            onClicked: rightIsland.bar.openQuick("")
        }

        // Grey like its neighbours at rest, red only under the pointer,
        // which marks a destructive menu without spending red on a
        // steady state.
        BarButton {
            id: power

            function session(id) {
                Quickshell.execDetached(["sh", "-c", `sleep 0.2; exec "$HOME/.local/bin/hypr-settings-menu" ${id}`]);
            }

            bar: rightIsland.bar
            size: 15
            text: "⏻"
            hoverTint: rightIsland.colors.red
            pill: rightIsland.colors.withAlpha(rightIsland.colors.red, 0.14)
            onClicked: rightIsland.bar.toggleMenu(power, [
                {
                    text: "Lock",
                    run: () => session("lock")
                },
                {
                    text: "Log out",
                    confirm: true,
                    run: () => session("logout")
                },
                {
                    text: "Suspend",
                    run: () => session("suspend")
                },
                {
                    separator: true
                },
                {
                    text: "Reboot",
                    confirm: true,
                    run: () => session("reboot")
                },
                {
                    text: "Shut down",
                    confirm: true,
                    run: () => session("shutdown")
                }
            ])
        }
    }

    // The sheet, laid out at its open size against the island's right
    // edge and revealed as the island grows; it fades in once the growth
    // is under way.
    Item {
        anchors.fill: parent
        clip: true

        QuickSettings {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: rightIsland.restHeight + 10
            width: rightIsland.openWidth - 32
            bar: rightIsland.bar
            open: rightIsland.open
            page: rightIsland.page
            keys: rightIsland.keys
            opacity: rightIsland.open ? 1 : 0
            visible: opacity > 0
            enabled: rightIsland.open
            onPageRequested: page => rightIsland.bar.pageQuick(page)
            onCloseRequested: rightIsland.bar.closeRequested()

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: rightIsland.open ? 80 : 0
                    }
                    NumberAnimation {
                        duration: rightIsland.open ? 180 : 100
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
