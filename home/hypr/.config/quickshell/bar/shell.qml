//@ pragma IconTheme Papirus-Dark
// The session's top bar, which replaced waybar (issue #75). hyprland.lua
// starts it as `quickshell -c bar`, after sni-watcher.
//
// Over IPC (`qs -c bar ipc call bar <function>`): `toggleShown` hides or
// shows the bar on every monitor (Super+B), `toggle` opens or closes the
// center island on the focused monitor (Super+Shift+B), and
// `refreshAwake` makes the stay-awake glyph look again (hypr-idle-toggle
// calls it).
//
// App icons resolve through Papirus-Dark, as waybar's did.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    // The screen whose center island is open, by name, or "" for none.
    // One at a time, so the bind acts on the focused monitor only.
    property string openOn: ""
    // Hidden, the bars unmap and give their 40px back to the windows.
    property bool shown: true

    function toggle(name) {
        root.openOn = root.openOn === name ? "" : name;
    }

    Colors {
        id: everforest
    }

    NowPlaying {
        id: nowPlaying
    }

    Variants {
        id: bars
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            visible: root.shown
            colors: everforest
            player: nowPlaying.player
            open: root.openOn === modelData.name
            onToggleRequested: root.toggle(modelData.name)
            onCloseRequested: if (root.openOn === modelData.name)
                root.openOn = ""
        }
    }

    IpcHandler {
        target: "bar"

        // Opening the island brings a hidden bar back first.
        function toggle(): void {
            root.shown = true;
            root.toggle(Hyprland.focusedMonitor?.name ?? "");
        }

        function toggleShown(): void {
            root.openOn = "";
            root.shown = !root.shown;
        }

        function refreshAwake(): void {
            for (const bar of bars.instances)
                bar.rightIsland.attention.probeAwake();
        }
    }
}
