//@ pragma IconTheme Papirus-Dark
// The session's top bar, which replaced waybar (issue #75). hyprland.lua
// starts it as `quickshell -c bar`, after sni-watcher.
//
// Over IPC (`qs -c bar ipc call bar <function>`): `toggleShown` hides or
// shows the bar on every monitor (Super+B), `toggle` opens or closes the
// center island on the focused monitor (Super+Shift+B), `settings` the
// right island's quick settings (Super+;), `dash` the dash panel,
// `settingsPage <page>` the same
// at a page (wifi, bluetooth or sound), `tray` the tray grid (Super+'), and `refreshAwake` makes the stay-awake glyph look
// again (hypr-idle-toggle calls it).
//
// The bar is also the notification daemon (Notifs.qml, #90): popups on
// the focused monitor and a center that opens like the other sheets.
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
    // The screen whose dash panel is open, by name, or "" for none.
    property string dashOn: ""
    // The screen whose notification center is open, or "" for none.
    property string notifOn: ""
    // When Super last closed the center, in ms: the toggle that Super+
    // period sends right after is that close, not a reopen.
    property real superClosedAt: 0
    // Hidden, the bars unmap and give their 40px back to the windows.
    property bool shown: true

    function toggle(name) {
        root.quickOn = "";
        root.dashOn = "";
        root.notifOn = "";
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
        root.dashOn = "";
        root.notifOn = "";
        root.quickKeys = keys;
        if (root.quickOn !== name)
            root.quickPage = page === "" ? "main" : page;
        else
            root.quickPage = page;
        root.quickOn = name;
    }

    // The one palette instance; Theme holds it for the primitives too.
    readonly property Colors everforest: Theme.colors

    NowPlaying {
        id: nowPlaying
    }

    // One sheet at a time: the center closes the others.
    function notif(name) {
        root.openOn = "";
        root.quickOn = "";
        root.dashOn = "";
        root.notifOn = root.notifOn === name ? "" : name;
    }

    Binding {
        target: Notifs
        property: "centerOpen"
        value: root.notifOn !== ""
    }

    Connections {
        target: Notifs

        function onToggleRequested(screen) {
            if (root.notifOn === "" && Date.now() - root.superClosedAt < 1000) {
                root.superClosedAt = 0;
                return;
            }
            root.shown = true;
            root.notif(screen !== "" ? screen : Hyprland.focusedMonitor?.name ?? "");
        }
    }

    NotifPopups {}

    Variants {
        model: Quickshell.screens

        NotifCenter {
            required property var modelData

            screen: modelData
            open: root.notifOn === modelData.name
            onCloseRequested: root.notifOn = ""
            // Any Super chord closes it first, so the chord acts on the
            // windows: the center keeps the keyboard while open.
            onSuperPressed: {
                root.superClosedAt = Date.now();
                root.notifOn = "";
            }
        }
    }

    // dash-data board runs only while a panel is open.
    DashFeed {
        id: dashFeed
        active: root.dashOn !== ""
    }

    Variants {
        model: Quickshell.screens

        DashPanel {
            required property var modelData

            screen: modelData
            colors: everforest
            feed: dashFeed
            open: root.dashOn === modelData.name && root.shown
            onCloseRequested: root.dashOn = ""
        }
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

        // The dash panel on the focused monitor (Super+D).
        function dash(): void {
            const name = Hyprland.focusedMonitor?.name ?? "";
            root.openOn = "";
            root.quickOn = "";
            root.notifOn = "";
            root.dashOn = root.dashOn === name ? "" : name;
        }

        function toggleShown(): void {
            root.openOn = "";
            root.quickOn = "";
            root.dashOn = "";
            root.notifOn = "";
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

        // The tray grid on the focused monitor.
        function tray(): void {
            root.shown = true;
            for (const bar of bars.instances)
                if (bar.screen.name === Hyprland.focusedMonitor?.name)
                    bar.toggleTray();
        }

        function refreshAwake(): void {
            for (const bar of bars.instances)
                bar.rightIsland.attention.probeAwake();
        }
    }
}
