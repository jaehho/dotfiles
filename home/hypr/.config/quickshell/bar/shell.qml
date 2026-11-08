//@ pragma IconTheme Papirus-Dark
// The session's top bar, which replaced waybar (issue #75). hyprland.lua
// starts it as `quickshell -c bar`, after sni-watcher.
//
// Over IPC (`qs -c bar ipc call bar <function>`): `toggleShown` hides or
// shows the bar on every monitor (Super+B), `toggle` opens or closes the
// center island on the focused monitor (Super+Shift+B), `settings` the
// right island's quick settings (Super+;), `settingsPage <page>` the same
// at a page (wifi, bluetooth or sound), and `refreshAwake` makes the stay-awake glyph look
// again (hypr-idle-toggle calls it).
//
// App icons resolve through Papirus-Dark, as waybar's did.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    // The screen whose center island is open, by name, or "" for none,
    // and likewise the screen whose quick settings are open, at which
    // page. One sheet at a time, so a bind acts on the focused monitor
    // only and opening one closes the other.
    property string openOn: ""
    property string quickOn: ""
    property string quickPage: "main"
    property bool quickKeys: false
    // Hidden, the bars unmap and give their 40px back to the windows.
    property bool shown: true

    function toggle(name) {
        root.quickOn = "";
        root.openOn = root.openOn === name ? "" : name;
    }

    // Page "" opens or closes the sheet as it is; a page opens it there,
    // or closes it if it is already showing that page.
    function quick(name, page, keys) {
        if (root.quickOn === name && (page === "" || root.quickPage === page)) {
            root.quickOn = "";
            return;
        }
        root.openOn = "";
        root.quickKeys = keys;
        if (root.quickOn !== name)
            root.quickPage = page === "" ? "main" : page;
        else
            root.quickPage = page;
        root.quickOn = name;
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
            quickOpen: root.quickOn === modelData.name
            quickPage: root.quickPage
            quickKeys: root.quickKeys
            onToggleRequested: root.toggle(modelData.name)
            onQuickRequested: page => root.quick(modelData.name, page, false)
            onPageRequested: page => root.quickPage = page
            onCloseRequested: {
                if (root.openOn === modelData.name)
                    root.openOn = "";
                if (root.quickOn === modelData.name)
                    root.quickOn = "";
            }
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
            root.quickOn = "";
            root.shown = !root.shown;
        }

        function settings(): void {
            root.shown = true;
            root.quick(Hyprland.focusedMonitor?.name ?? "", "", true);
        }

        function settingsPage(page: string): void {
            root.shown = true;
            root.quick(Hyprland.focusedMonitor?.name ?? "", page, true);
        }

        function refreshAwake(): void {
            for (const bar of bars.instances)
                bar.rightIsland.attention.probeAwake();
        }
    }
}
