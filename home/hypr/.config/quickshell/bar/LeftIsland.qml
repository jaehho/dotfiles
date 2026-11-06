// The left island: this monitor's workspaces, each a pill holding its
// windows' app icons, then the focused window's title, as waybar's
// hyprland/workspaces (taskbar mode) and custom/window drew them.
//
// A click on a pill goes to that workspace; on an icon, to that window
// (or hides the special workspace it is raised on, as
// hypr-waybar-window-click does). The wheel steps through this monitor's
// workspaces. asstdev, the asst test harness's parking workspace, never
// shows.
//
// The title follows the focused toplevel itself, not the active
// workspace, so a raised special workspace names its own window (why
// waybar needed hypr-active-window).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Island {
    id: leftIsland

    required property var bar
    readonly property var monitor: Hyprland.monitorFor(bar.screen)
    // The special workspace raised on this monitor, by full name, or "".
    property string raisedSpecial: ""

    // Numbered workspaces by id, then named ones, then the specials.
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.monitor === leftIsland.monitor && w.name !== "asstdev").sort((a, b) => leftIsland.rank(a) - leftIsland.rank(b) || a.id - b.id)

    function rank(workspace) {
        return workspace.name.startsWith("special:") ? 2 : workspace.id > 0 ? 0 : 1;
    }

    // Chrome's "is sharing your screen" bar is a window of its own.
    function listed(toplevel) {
        return !/chrome-sharing-indicator/.test(toplevel.title + " " + leftIsland.appOf(toplevel));
    }

    function appOf(toplevel) {
        return toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
    }

    // Class to .desktop entry to the icon theme (Papirus-Dark, set in
    // shell.qml), as waybar resolved them.
    function iconOf(toplevel) {
        const app = leftIsland.appOf(toplevel);
        const entry = DesktopEntries.heuristicLookup(app);
        return Quickshell.iconPath(entry?.icon || app.toLowerCase(), "application-x-executable");
    }

    function go(workspace) {
        if (workspace.name.startsWith("special:"))
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${workspace.name.slice(8)}")`);
        else
            workspace.activate();
    }

    function focus(toplevel, workspace) {
        if (workspace.name === leftIsland.raisedSpecial)
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${workspace.name.slice(8)}")`);
        else
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`);
    }

    colors: bar.colors

    Component.onCompleted: Hyprland.refreshMonitors()

    Connections {
        target: leftIsland.monitor

        function onLastIpcObjectChanged() {
            leftIsland.raisedSpecial = leftIsland.monitor.lastIpcObject?.specialWorkspace?.name ?? "";
        }
    }

    // "activespecial>>special:name,monitor", or an empty name when the
    // special workspace is hidden again.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activespecial")
                return;
            const [name, monitor] = event.parse(2);
            if (monitor === leftIsland.monitor?.name)
                leftIsland.raisedSpecial = name;
        }
    }

    // Waybar's workspaces module: 2px inside either end.
    Row {
        leftPadding: 2
        rightPadding: 2

        // The wheel over the workspaces steps through them.
        WheelHandler {
            property real travel: 0
            onWheel: event => {
                travel += event.angleDelta.y;
                while (Math.abs(travel) >= 120) {
                    const back = travel > 0;
                    travel -= back ? 120 : -120;
                    Hyprland.dispatch(`hl.dsp.focus({ workspace = "m${back ? "-" : "+"}1" })`);
                }
            }
        }

        Repeater {
            model: leftIsland.workspaces

            Item {
                id: slot

                required property var modelData
                readonly property var workspace: modelData
                readonly property bool special: workspace.name.startsWith("special:")
                readonly property bool current: special ? leftIsland.raisedSpecial === workspace.name : leftIsland.monitor?.activeWorkspace === workspace
                readonly property var windows: workspace.toplevels.values.filter(t => leftIsland.listed(t))

                width: pill.width + 4
                height: 24

                Rectangle {
                    id: pill
                    x: 2
                    y: 3
                    width: content.width + 14
                    height: 18
                    radius: 8
                    color: slot.current ? (slot.special ? leftIsland.colors.purple : leftIsland.colors.blue) : slot.workspace.urgent ? leftIsland.colors.red : hover.hovered ? leftIsland.colors.withAlpha(slot.special ? leftIsland.colors.purple : leftIsland.colors.blue, 0.14) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: leftIsland.go(slot.workspace)
                    }

                    Row {
                        id: content
                        x: 7
                        anchors.verticalCenter: parent.verticalCenter

                        Line {
                            anchors.verticalCenter: parent.verticalCenter
                            mono: true
                            text: slot.workspace.name.replace(/^special:/, "")
                            color: slot.current || slot.workspace.urgent ? leftIsland.colors.bg0 : hover.hovered ? leftIsland.colors.fg : slot.special ? leftIsland.colors.grey1 : leftIsland.colors.grey0

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }

                        // Waybar's label kept 3px more; each window was a
                        // button 42px apart, its icon centered.
                        Item {
                            visible: slot.windows.length > 0
                            width: 3
                            height: 1
                        }

                        Repeater {
                            model: slot.windows

                            Item {
                                id: entry

                                required property var modelData
                                readonly property bool focused: Hyprland.activeToplevel === modelData && ToplevelManager.activeToplevel !== null

                                width: 42
                                height: 18

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 14
                                    // Re-resolved once the desktop entries load.
                                    source: DesktopEntries.applications.values.length >= 0 ? leftIsland.iconOf(entry.modelData) : ""
                                    opacity: iconArea.containsMouse ? 1 : entry.focused ? 0.88 : slot.current ? 0.68 : 0.45

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }

                                MouseArea {
                                    id: iconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: leftIsland.focus(entry.modelData, slot.workspace)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        visible: title.visible
        width: 2
        height: 24
    }

    // Context, not a control: italic and quiet, purple in a special
    // workspace, cut at about waybar's 60 characters, gone with no window.
    BarButton {
        id: title

        readonly property var toplevel: ToplevelManager.activeToplevel
        readonly property bool special: Hyprland.activeToplevel?.workspace?.name.startsWith("special:") ?? false

        visible: toplevel !== null
        width: visible ? implicitWidth : 0
        bar: leftIsland.bar
        interactive: false
        italic: true
        maxWidth: 470
        text: toplevel ? (toplevel.title || toplevel.appId) : ""
        tint: special ? leftIsland.colors.purple : leftIsland.colors.grey2
        tip: toplevel ? [toplevel.appId, toplevel.title].filter(s => s !== "").join("  ·  ") : ""
    }
}
