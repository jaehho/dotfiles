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
// The launcher (LauncherWindow.qml, #89) replaced rofi's drun:
// `qs -c bar ipc call launcher toggle` opens or closes it on the focused
// monitor (Super+Space). The keybind sheet (KeybindsWindow.qml) is
// `qs -c bar ipc call keybinds toggle` (Super+/), and the clipboard
// history (ClipboardWindow.qml) `qs -c bar ipc call clipboard toggle`
// (Super+V), and the share menu (ShareWindow.qml) `qs -c bar ipc call
// share toggle` (Super+S).
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
    // The screen whose launcher is open, or "" for none.
    property string launcherOn: ""
    // The screen whose keybind sheet is open, or "" for none.
    property string keybindsOn: ""
    // The screen whose clipboard history is open, or "" for none, and when
    // Super last closed it (as launcherClosedAt).
    property string clipboardOn: ""
    property real clipboardClosedAt: 0
    // The same for the share menu.
    property string shareOn: ""
    property real shareClosedAt: 0
    // When Super last closed the center, in ms: the toggle that Super+
    // period sends right after is that close, not a reopen.
    property real superClosedAt: 0
    // The same for the launcher and Super+Space, kept apart so that
    // Super closing the center doesn't swallow the launcher's toggle.
    property real launcherClosedAt: 0
    // Hidden, the bars unmap and give their 40px back to the windows.
    property bool shown: true

    function toggle(name) {
        root.launcherOn = "";
        root.keybindsOn = "";
        root.clipboardOn = "";
        root.shareOn = "";
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
        root.launcherOn = "";
        root.keybindsOn = "";
        root.clipboardOn = "";
        root.shareOn = "";
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
        root.launcherOn = "";
        root.keybindsOn = "";
        root.clipboardOn = "";
        root.shareOn = "";
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

    // The hangul hint (HangulHint.qml), which runs hypr-hangul-hint.
    HangulHint {}

    // One sheet at a time: the launcher closes the others, the tray grid
    // included.
    function launcher(name) {
        root.openOn = "";
        root.quickOn = "";
        root.dashOn = "";
        root.notifOn = "";
        root.keybindsOn = "";
        root.clipboardOn = "";
        root.shareOn = "";
        for (const bar of bars.instances)
            bar.trayOpen = false;
        root.launcherOn = root.launcherOn === name ? "" : name;
    }

    // The keybind sheet closes the others too, and reads the binds again
    // as it opens.
    function keybinds(name) {
        root.openOn = "";
        root.quickOn = "";
        root.dashOn = "";
        root.notifOn = "";
        root.launcherOn = "";
        root.clipboardOn = "";
        root.shareOn = "";
        for (const bar of bars.instances)
            bar.trayOpen = false;
        if (root.keybindsOn !== name)
            Keybinds.refresh();
        root.keybindsOn = root.keybindsOn === name ? "" : name;
    }

    Variants {
        model: Quickshell.screens

        KeybindsWindow {
            required property var modelData

            screen: modelData
            open: root.keybindsOn === modelData.name
            onCloseRequested: root.keybindsOn = ""
        }
    }

    // The clipboard history closes the others too.
    function clipboard(name) {
        root.openOn = "";
        root.quickOn = "";
        root.dashOn = "";
        root.notifOn = "";
        root.launcherOn = "";
        root.keybindsOn = "";
        root.shareOn = "";
        for (const bar of bars.instances)
            bar.trayOpen = false;
        root.clipboardOn = root.clipboardOn === name ? "" : name;
    }

    // The share menu closes the others too.
    function share(name) {
        root.openOn = "";
        root.quickOn = "";
        root.dashOn = "";
        root.notifOn = "";
        root.launcherOn = "";
        root.keybindsOn = "";
        root.clipboardOn = "";
        for (const bar of bars.instances)
            bar.trayOpen = false;
        root.shareOn = root.shareOn === name ? "" : name;
    }

    Variants {
        model: Quickshell.screens

        ShareWindow {
            required property var modelData

            screen: modelData
            open: root.shareOn === modelData.name
            onCloseRequested: root.shareOn = ""
            onSuperPressed: {
                root.shareClosedAt = Date.now();
                root.shareOn = "";
            }
        }
    }

    IpcHandler {
        target: "share"

        function toggle(): void {
            if (root.shareOn === "" && Date.now() - root.shareClosedAt < 1000) {
                root.shareClosedAt = 0;
                return;
            }
            root.share(Hyprland.focusedMonitor?.name ?? "");
        }
    }

    Variants {
        model: Quickshell.screens

        ClipboardWindow {
            required property var modelData

            screen: modelData
            open: root.clipboardOn === modelData.name
            onCloseRequested: root.clipboardOn = ""
            // As the launcher: a Super chord closes it first, and Super+V's
            // own toggle then finds it closed.
            onSuperPressed: {
                root.clipboardClosedAt = Date.now();
                root.clipboardOn = "";
            }
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            if (root.clipboardOn === "" && Date.now() - root.clipboardClosedAt < 1000) {
                root.clipboardClosedAt = 0;
                return;
            }
            root.clipboard(Hyprland.focusedMonitor?.name ?? "");
        }
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            root.keybinds(Hyprland.focusedMonitor?.name ?? "");
        }
    }

    Variants {
        model: Quickshell.screens

        LauncherWindow {
            required property var modelData

            screen: modelData
            open: root.launcherOn === modelData.name
            onCloseRequested: root.launcherOn = ""
            // Any Super chord closes it first, so the chord acts on the
            // windows; Super+Space's own toggle then finds it closed.
            onSuperPressed: {
                root.launcherClosedAt = Date.now();
                root.launcherOn = "";
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (root.launcherOn === "" && Date.now() - root.launcherClosedAt < 1000) {
                root.launcherClosedAt = 0;
                return;
            }
            root.launcher(Hyprland.focusedMonitor?.name ?? "");
        }
    }

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
            root.launcherOn = "";
            root.keybindsOn = "";
            root.clipboardOn = "";
            root.shareOn = "";
            root.dashOn = root.dashOn === name ? "" : name;
        }

        function toggleShown(): void {
            root.openOn = "";
            root.quickOn = "";
            root.dashOn = "";
            root.notifOn = "";
            root.launcherOn = "";
            root.keybindsOn = "";
            root.clipboardOn = "";
            root.shareOn = "";
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
                    bar.toggleTray(true);
        }

        function refreshAwake(): void {
            for (const bar of bars.instances)
                bar.rightIsland.attention.probeAwake();
        }
    }
}
