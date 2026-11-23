pragma Singleton

// The keybind sheet's data (#89): what `hypr-keybind-cheatsheet` parses
// from hyprland.lua, tmux and its kitty list, as JSON (its docstring
// lists the fields). Read at start and again on every open, so an edited
// hyprland.lua shows the next time the sheet opens. The chosen view
// lives in the shell's state directory (keybinds.json).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: keybinds

    // null until the first read.
    property var table: null
    // "list" or "keyboard".
    property string view: "list"

    function refresh() {
        reader.running = false;
        reader.running = true;
    }

    function setView(view) {
        keybinds.view = view;
        store.setText(JSON.stringify({
            view: view
        }) + "\n");
    }

    Component.onCompleted: refresh()

    Process {
        id: reader
        command: [Quickshell.env("HOME") + "/.local/bin/hypr-keybind-cheatsheet"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    keybinds.table = JSON.parse(text);
                } catch (error) {
                    console.warn("keybinds: unreadable output:", error);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.warn("keybinds:", text.trim())
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("keybinds.json")
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (saved.view === "list" || saved.view === "keyboard")
                    keybinds.view = saved.view;
            } catch (error) {}
        }
    }
}
