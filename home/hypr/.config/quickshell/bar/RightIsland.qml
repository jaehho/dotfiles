// The right island, clustered by what a glance is for, with a short
// hairline before each cluster after the first, as waybar drew it:
// attention, load, output, battery and radios, then the power menu.
import QtQuick
import Quickshell

Island {
    id: rightIsland

    required property var bar
    // The status cluster, for the IPC refresh of stay-awake.
    readonly property alias attention: attention

    colors: bar.colors

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

    // Grey like its neighbours at rest, red only under the pointer, which
    // marks a destructive menu without spending red on a steady state.
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
                run: () => session("reboot")
            },
            {
                text: "Shut down",
                run: () => session("shutdown")
            }
        ])
    }
}
