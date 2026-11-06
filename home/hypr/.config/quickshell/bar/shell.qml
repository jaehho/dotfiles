// The session's top bar, rebuilt in Quickshell to replace waybar
// (home/waybar) one island at a time. Only the center island exists so
// far, and hyprland.lua does not start it: waybar is still the bar. Try
// it with `quickshell -c bar`.
//
// `quickshell -c bar ipc call bar toggle` opens or closes the center
// island on the focused monitor.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    // The screen whose center island is open, by name, or "" for none.
    // One at a time, so the bind acts on the focused monitor only.
    property string openOn: ""

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
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
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

        function toggle(): void {
            root.toggle(Hyprland.focusedMonitor?.name ?? "");
        }
    }
}
