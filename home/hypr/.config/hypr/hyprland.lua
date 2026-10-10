-- Hyprland config — Lua format (0.55+).
-- Converted from hyprland.conf; see https://wiki.hypr.land/Configuring/
--
-- Split across files via require().

------------------
---- MONITORS ----
------------------

-- monitors.lua computes the layout and workspace assignment live; it is a
-- tracked file now rather than generated.
--
-- require caches in package.loaded and that cache survives `hyprctl reload`, so
-- without this line an edit to monitors.lua is ignored until a full restart.
package.loaded["monitors"] = nil
local ok, monitors = pcall(require, "monitors")

-- Two guards, because failure here is quiet and expensive. Hyprland's require
-- swallows an error raised inside a module and hands back an empty table, so
-- `ok` alone does not prove it loaded — check the shape too. And a real error
-- would be fatal to require, aborting the rest of this file: a bad layout is
-- survivable, a session with no keybinds is not.
if ok and (type(monitors) ~= "table" or monitors.apply == nil) then
    ok, monitors = false, "monitors.lua did not return its module table"
end
if not ok then
    hl.notification.create({ text = "monitors.lua failed: " .. tostring(monitors), timeout = 10000, icon = "error" })
    monitors = { apply = function() end }
end

-- workspaces.lua packs each monitor's ids when one is removed. Same require
-- cache/shape guards as monitors.lua above.
package.loaded["workspaces"] = nil
local ok_ws, workspaces = pcall(require, "workspaces")
if ok_ws and (type(workspaces) ~= "table" or workspaces.plan_pack == nil) then
    ok_ws, workspaces = false, "workspaces.lua did not return its module table"
end
if not ok_ws then
    hl.notification.create({ text = "workspaces.lua failed: " .. tostring(workspaces), timeout = 10000, icon = "error" })
end
-- Colors only from the official Catppuccin Mocha module (catppuccin/hyprland).
-- Active border is fixed lavender.
package.loaded["themes.catppuccin_mocha"] = nil
local ok_theme, mocha = pcall(require, "themes.catppuccin_mocha")
if not ok_theme or type(mocha) ~= "table" or mocha.lavenderAlpha == nil then
    hl.notification.create({ text = "catppuccin_mocha.lua failed to load", timeout = 10000, icon = "error" })
    mocha = { lavenderAlpha = "b4befe", overlay1Alpha = "7f849c", crustAlpha = "11111b" }
end
local clr = {
    active   = "rgba(" .. mocha.lavenderAlpha .. "ee)",
    inactive = "rgba(" .. mocha.overlay1Alpha .. "aa)",
    shadow   = "rgba(" .. mocha.crustAlpha .. "ee)",
}

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local menu     = "rofi -show drun"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Started from its own config dir on purpose: waybar's reload_style_on_change
    -- follows the style.css symlink with a raw read_symlink and resolves stow's
    -- *relative* target (../../dotfiles/...) against its working directory, not
    -- the link's. From anywhere else it watches a path that does not exist and
    -- CSS edits never apply live. Same in the Super+B bind below.
    hl.exec_cmd([[cd ~/.config/waybar && waybar 2>&1 | grep -v 'Gtk-CRITICAL\|GTK_IS_ACCEL_GROUP' &]])
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("swaync")
    hl.exec_cmd("~/.local/bin/hypr-urgent-focus")
    hl.exec_cmd("~/.local/bin/hypr-swaync-keys")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- swayosd-server is a user unit; a copy launched here grabs its app id and
    -- makes the unit crash-loop "already running" (issue #14). Start the unit
    -- only once WAYLAND_DISPLAY is in the manager, or its condition skips it.
    -- awatcher is the same: asst track reads its :5600 sensor, and Hyprland
    -- never starts graphical-session.target, so the unit needs this kick.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user start swayosd-server awatcher")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("~/.local/bin/laptop-watchdog &")
    hl.exec_cmd("playerctld daemon")

    -- Tray apps: all started here, none from ~/.config/autostart (this session
    -- runs no XDG autostart) or a user unit. Each starts with no window, with
    -- the flag or pref that does that noted beside it, except Zotero and
    -- Spotify. Zotero has no windowless start (-silent exits at once) and
    -- Spotify maps its window under --minimized on both Wayland and XWayland,
    -- so both open a window at login.
    hl.exec_cmd("udiskie --smart-tray")
    hl.exec_cmd("tailscale systray --theme dark")  -- dark: white dots on a black tile, like the bar
    hl.exec_cmd("steno gui --background")          -- meeting listener
    hl.exec_cmd("asst-gtk --background")           -- tasks (~/projects/asst)
    hl.exec_cmd("nextcloud --background")
    hl.exec_cmd("betterbird")                      -- prefs.js: mail.startupMinimized
    hl.exec_cmd("zotero")
    -- spotify-launcher passes a URI but no flags, so update through it, then run
    -- the client it installed. Tray needs ui.minimize_to_tray in spotify/prefs.
    -- Wayland, because under XWayland a raised window takes no keys until the
    -- pointer enters it (same flags in hypr-spotify-toggle).
    hl.exec_cmd("spotify-launcher --no-exec && ~/.local/share/spotify-launcher/install/usr/share/spotify/spotify --enable-features=UseOzonePlatform --ozone-platform=wayland")

    -- Workspace management daemons
    hl.exec_cmd("hyprscratch init")
    hl.exec_cmd("hyprwhenthen run")

    -- Desktop dashboard (bottom layer; lands on an empty workspace). Last, so
    -- the daemons above are up before it switches workspace.
    hl.exec_cmd("dash show")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- GPU — hybrid Intel/NVIDIA (Intel primary, NVIDIA via prime-run)
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("AQ_DRM_DEVICES", "/dev/dri/card0:/dev/dri/card1")

-- Firefox
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron/Chromium
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- ~/Media layout (wallhelper-fetch.service sets WALLHELPER_DIR itself)
hl.env("REEL_LIB", "/home/jaeho/Media/trips")
hl.env("WALLHELPER_DIR", "/home/jaeho/Media/wallpapers")

-----------------------
----- PERMISSIONS -----
-----------------------

-- Permission changes require a Hyprland restart and are not applied on-the-fly
-- for security reasons.

hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprlock", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in         = 5,
        gaps_out        = { 10, 20, 20, 20 },
        gaps_workspaces = 50,

        border_size = 2,

        col = {
            active_border   = clr.active,
            inactive_border = clr.inactive,
        },

        -- Resize windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        -- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/
        allow_tearing = true,

        layout = "dwindle",

        snap = {
            enabled = true,
        },
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = clr.shadow,
        },

        blur = {
            enabled  = true,
            size     = 5,
            passes   = 2,

            popups   = true,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

--                NAME              TYPE      POINTS
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- "Smart gaps" / "No gaps when only" — uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

hl.config({
    dwindle = {
        preserve_split       = true,
        special_scale_factor = 0.8,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms  = true,
        key_press_enables_dpms   = true,
        middle_click_paste       = false,
        focus_on_activate        = true,
        allow_session_lock_restore = true,
        enable_swallow           = true,
        swallow_regex            = "^(kitty)$",
        swallow_exception_regex  = [[^(org\.pwmt\.zathura)$]],
    },

    cursor = {
        no_hardware_cursors = 1,
        inactive_timeout    = 3, -- hide a still cursor (fullscreen video)
    },

    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles   = true,
    },

    gestures = {
        -- Swipe past the last workspace must not mint 10+. Super+D is the
        -- only "give me empty" path; the closed set is 1-9 + special on 0.
        workspace_swipe_create_new = false,
    },
})

-- Scratchpad: semi-transparent overlay
hl.workspace_rule({ workspace = "special:󰏫", gaps_out = 30 })
hl.window_rule({
    name  = "scratchpad-see-through",
    match = { workspace = "special:󰏫" },

    opacity = 0.85,
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        repeat_rate  = 50,
        repeat_delay = 300,

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            tap_to_click         = true,
            -- Elan 012C two-finger scroll is hot at the stock 1.0 scale
            scroll_factor        = 0.5,
        },
    },
})

-- Touchpad gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Example per-device config
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + Return",         hl.dsp.exec_cmd(terminal)) -- terminal (new tmux session)
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("env NO_TMUX=1 " .. terminal)) -- terminal, no tmux
hl.bind(mainMod .. " + Q",         hl.dsp.window.close()) -- quit: close the focused window
-- asst's add-task popup: a layer surface, so no window rule; pressing again closes it
hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd("asst-gtk quick-add")) -- quick add task
hl.bind(mainMod .. " + space",     hl.dsp.exec_cmd(menu)) -- app launcher
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.local/bin/hypr-pin-toggle")) -- pin window on top
hl.bind(mainMod .. " + T",         hl.dsp.layout("togglesplit"))                    -- toggle split direction (dwindle)

-- Screenshots — see ~/.local/bin/screenshot.
-- Modifiers: (none)=full, SHIFT=region, SUPER=window, SUPER+SHIFT=focused monitor;
--            CTRL=clipboard only (no disk).
-- A function because a submap is exclusive (see bind_media_keys): the swaync
-- submap re-declares these, or Print goes dead while the panel is open.
local function bind_screenshots()
    hl.bind("Print",                     hl.dsp.exec_cmd("screenshot full copy"))    -- screenshot the screen
    hl.bind("SHIFT + Print",             hl.dsp.exec_cmd("screenshot region copy"))  -- screenshot a region
    hl.bind(mainMod .. " + Print",       hl.dsp.exec_cmd("screenshot window copy"))  -- screenshot the window
    hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("screenshot monitor copy")) -- screenshot the monitor
    hl.bind("CTRL + Print",              hl.dsp.exec_cmd("screenshot region clip"))  -- screenshot a region, clipboard only
    -- The snip key (F12) is sent by the firmware as Super+Shift+S.
    hl.bind(mainMod .. " + SHIFT + S",   hl.dsp.exec_cmd("screenshot region copy"))  -- snip key: screenshot a region
end
bind_screenshots()

-- Lock screen
hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd("loginctl lock-session"))

-- Fullscreen and float
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" })) -- float / unfloat

-- Browser and music
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("firefox-developer-edition"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.local/bin/hypr-spotify-toggle")) -- spotify: show / hide to tray

-- Toggle waybar: waybar-toggle reads the bar's real visibility from the
-- compositor and sends the matching signal (see its header). Killing the bar
-- instead left each custom module's child orphaned to PID 1, one more per
-- press.
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.local/bin/waybar-toggle toggle")) -- show/hide bar

-- Notifications
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("swaync-client -t"))

-- Game mode (disable effects for performance)
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.local/bin/hypr-gamemode"))

-- Night light (blue light filter)
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/.local/bin/hypr-nightlight-toggle"))

-- Keybind cheatsheet
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("~/.local/bin/hypr-keybind-cheatsheet"))

-- Settings menu: entries live in hypr-settings-menu
hl.bind(mainMod .. " + semicolon", hl.dsp.exec_cmd("~/.local/bin/hypr-settings-menu")) -- settings menu

-- Share: Taildrop a file or the clipboard, or show the clipboard as a QR code
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("~/.local/bin/hypr-share-menu")) -- share menu

-- Clipboard history (cliphist; pick copies the entry back to the clipboard)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.local/bin/hypr-cliphist")) -- clipboard history

-- Move focus with mainMod + hjkl
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Cycle floating windows (focus only reaches tiled windows in dwindle)
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.cycle_next({ floating = true }))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.bring_to_top())

-- Swap windows with mainMod + SHIFT + hjkl
hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.swap({ direction = "down" }))

-- Switch workspaces / move active window with mainMod (+ SHIFT) + [1-9]
-- Super+N is workspace id N (holes allowed; the closed set is 1-9, Super+0 is
-- the scratchpad). Each id is locked to its round-robin monitor by
-- monitors.lua, so Super+N moves focus to that monitor.
local function focus_workspace(n)
    hl.dispatch(hl.dsp.focus({ workspace = n }))
end
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, function() focus_workspace(i) end)
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i })) -- send window to workspace
end

-- Super+D / Super+Shift+D: empty workspace on the focused display.
-- Free means an id in this monitor's round-robin slots (monitors.lua, closed
-- set 1-9) with no windows (a missing id counts). slots_by_monitor is the same
-- left-to-right plan apply() locks ids to, so with one external it is laptop
-- 1/3/5/7/9 and tablet 2/4/6/8. Super+D hops there and shows dash;
-- Super+Shift+D sends the window, focus following, matching Super+Shift+N.
local function focused_monitor_name()
    for _, m in ipairs(hl.get_monitors() or {}) do
        if m.focused then
            return m.name
        end
    end
end

local function first_free_workspace()
    local mon = focused_monitor_name()
    if mon == nil then return end
    local by_mon = monitors.slots_by_monitor and monitors.slots_by_monitor() or {}
    for _, i in ipairs(by_mon[mon] or {}) do
        local ws = hl.get_workspace(i)
        if ws == nil or (ws.windows or 0) == 0 then
            return i
        end
    end
end

-- Windows on the focused workspace. Unknown counts as busy so Super+D does
-- not treat a half-queried session as "already on empty".
local function focused_workspace_windows()
    for _, m in ipairs(hl.get_monitors() or {}) do
        if m.focused then
            local aw = m.active_workspace
            local id = type(aw) == "table" and aw.id or aw
            if id then
                local ws = hl.get_workspace(id)
                return (ws and ws.windows) or 0
            end
        end
    end
    return 1
end

hl.bind(mainMod .. " + D", function() -- empty workspace on this display, dash on it
    -- Already empty: dash's off switch (and the show, if hidden).
    if focused_workspace_windows() == 0 then
        hl.dispatch(hl.dsp.exec_cmd("dash toggle"))
        return
    end
    local target = first_free_workspace()
    if target == nil then
        hl.notification.create({ text = "No free workspace on this display", timeout = 1500, icon = "info" })
        return
    end
    hl.dispatch(hl.dsp.focus({ workspace = target }))
    -- show, not toggle: after the hop this workspace is empty, so toggle would
    -- read it as "landed on dash" and stop instead of keeping the dashboard up.
    hl.dispatch(hl.dsp.exec_cmd("dash show"))
end)

hl.bind(mainMod .. " + SHIFT + D", function() -- send window to empty workspace on this display
    local target = first_free_workspace()
    if target == nil then
        hl.notification.create({ text = "No free workspace on this display", timeout = 1500, icon = "info" })
        return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = target }))
end)

-- Move all windows in active workspace to target workspace with mainMod + CTRL + [1-9]
-- (0 is the scratchpad's row)
for i = 1, 9 do
    hl.bind(mainMod .. " + CTRL + " .. i, -- send every window here to workspace
        hl.dsp.exec_cmd("~/.local/bin/hypr-move-workspace-to " .. i))
end

-- Move active workspace to adjacent monitor
hl.bind(mainMod .. " + CTRL + comma",  hl.dsp.exec_cmd("~/.local/bin/hypr-move-ws-monitor -1")) -- workspace to the left monitor
hl.bind(mainMod .. " + CTRL + period", hl.dsp.exec_cmd("~/.local/bin/hypr-move-ws-monitor +1")) -- workspace to the right monitor

-- Smiley key (F2), sent by the firmware as Ctrl+Alt+Shift+Super+Space.
hl.bind("CTRL + ALT + SHIFT + SUPER + space", hl.dsp.exec_cmd("hypr-confetti")) -- smiley key: confetti

-- Re-apply monitor layout + workspace assignments (fixes stranded workspaces)
hl.bind(mainMod .. " + CTRL + R", function() monitors.apply() end) -- re-apply monitor layout

-- Display key (F1), which the firmware sends as Super+P: the display menu
-- (layout, per-screen on/off, tablet). Super+; reaches it through the settings menu.
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("~/.local/bin/hypr-display-menu")) -- display menu (F1)

-- Scratchpad. Native dispatchers, not `hyprctl dispatch` — under a Lua config the
-- legacy string form is rejected outright. No waybar nudge needed: the special
-- workspaces are shown by waybar's own workspaces module, which follows IPC.
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special("󰏫")) -- scratchpad
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "special:󰏫" })) -- send to scratchpad

-- Scroll through existing workspaces on this monitor with mainMod + scroll.
-- m+1/m-1, not e+1/e-1: e walks all monitors and empty/missing ids can mint
-- workspaces outside the closed 1-9 set.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" })) -- next workspace on this display
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "m-1" })) -- previous workspace on this display

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move project (all windows + name) to next/prev monitor's empty slot
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("~/.local/bin/hypr-move-project next"))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.exec_cmd("~/.local/bin/hypr-move-project prev"))

-- Sequential workspace navigation (desktop-contained, non-empty only)
hl.bind(mainMod .. " + Tab",         hl.dsp.exec_cmd("~/.local/bin/hypr-tab-nonempty")) -- next non-empty workspace
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("~/.local/bin/hypr-tab-nonempty prev")) -- previous non-empty workspace

-- Resize submap (SUPER+R to enter, hjkl to resize, Esc to exit)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize")) -- resize mode
hl.define_submap("resize", "reset", function()
    -- relative = true, else x/y are treated as an absolute target size
    hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
    hl.bind("l", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
    hl.bind("k", hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
    hl.bind("j", hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
    hl.bind("escape",   hl.dsp.submap("reset")) -- leave resize mode
    hl.bind("catchall", hl.dsp.submap("reset"))
end)

-- Volume and brightness (SwayOSD, with a partial fallback)
--
-- The `|| ...` fallbacks only cover SwayOSD being *absent*. swayosd-client
-- exits non-zero when nothing owns the bus name, but exits 0 when a server
-- answers and refuses the call -- which is what a server still running a
-- binary that an upgrade deleted does, so these keys go silently dead until it
-- restarts. `make sync` now handles that; see issue #14.
--
-- Do not "fix" this by calling busctl with a literal signature here: the
-- signature is what moved in swayosd 0.3.1 -> 0.3.2, so pinning it just
-- re-breaks on the next bump. Probing the server costs more than the keypress.
-- Declared as a function because a Hyprland submap is exclusive: while one is
-- active *only* its own binds fire. The swaync submap calls this too, so
-- opening the control center does not kill the media keys.
local function bind_media_keys()
    -- Volume steps go through hypr-level (finer at low levels), which sets it
    -- with wpctl, so only the mute keys depend on the server answering.
    hl.bind("XF86AudioRaiseVolume", -- volume up
        hl.dsp.exec_cmd("hypr-level volume up"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", -- volume down
        hl.dsp.exec_cmd("hypr-level volume down"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioMute", -- mute output
        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioMicMute", -- mute the mic
        hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
        { locked = true, repeating = true })

    -- Brightness. hypr-level makes the change itself and only draws on SwayOSD,
    -- with steps that shrink at low levels.
    hl.bind("XF86MonBrightnessUp", -- brighter
        hl.dsp.exec_cmd("hypr-level brightness up"),
        { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", -- dimmer
        hl.dsp.exec_cmd("hypr-level brightness down"),
        { locked = true, repeating = true })

    -- Requires playerctl
    hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true }) -- next track
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("hypr-media-tap"),       { locked = true }) -- play / pause, double tap: next
    hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("hypr-media-tap"),       { locked = true }) -- play / pause, double tap: next
    hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true }) -- previous track
end

bind_media_keys()

-- Calculator key: qalc in a new tmux pane if focused terminal has tmux, else floating kitty
hl.bind("XF86Calculator", hl.dsp.exec_cmd("~/.local/bin/hypr-pane --float qalc-kitty -- qalc")) -- calculator

-- Copilot key, sent by the firmware as Super+Shift+F23: Claude in a tmux pane
-- beside the focused one, in that pane's directory; with no tmux focused, a
-- new terminal in ~/dotfiles.
hl.bind(mainMod .. " + SHIFT + F23", -- copilot key: Claude Code in a tmux pane
    hl.dsp.exec_cmd("~/.local/bin/hypr-pane --cwd ~/dotfiles -- claude --model opus --effort high"))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    -- Ignore maximize requests from all apps.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Picture-in-Picture
hl.window_rule({
    name  = "pip-float",
    match = { title = [[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)$]] },

    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    size              = "25% 25%",
    move              = "73% 72%",
})

-- Inhibit idle when fullscreen (browsers, media players)
hl.window_rule({
    name  = "idle-inhibit-fullscreen",
    match = {
        fullscreen = true,
        class      = "^(firefox-developer-edition|firefox|microsoft-edge.*|[Gg]oogle-chrome|brave-browser|mpv|vlc|celluloid)$",
    },

    suppress_event = "idle",
})

-- Float common dialogs
hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(nm-connection-editor|org.gnome.Calculator|xdg-desktop-portal-gtk)$" },

    float = true,
})

hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = "^(Open File|Save File|Save As|Confirm|File Upload)$" },

    float = true,
})

-- Floating TUI apps (nmtui, btop, etc.)
hl.window_rule({
    name  = "float-tui",
    match = { class = "^(floating-tui)$" },

    float  = true,
    size   = "800 600",
    center = true,
})

-- btop needs 80x24 cells at minimum and more to be useful
hl.window_rule({
    name  = "float-btop",
    match = { class = "^(floating-btop)$" },

    float  = true,
    size   = "1400 900",
    center = true,
})

-- Battery dashboard: a window you open to answer one question and then close
hl.window_rule({
    name  = "battery-log-float",
    match = { class = "^(battery-log)$" },

    float  = true,
    size   = "1180 820",
    center = true,
})

-- Speaker EQ (speaker-eq): opened to tune by ear while music plays, then closed
hl.window_rule({
    name  = "speaker-eq-float",
    match = { class = [[^(dev\.jaeho\.speakereq)$]] },

    float  = true,
    size   = "1080 880",
    center = true,
})

hl.window_rule({
    name  = "spotify-float",
    match = { class = "^([Ss]potify)$" },

    float  = true,
    size   = "1200 800",
    center = true,
})

-- Wallpaper picker
hl.window_rule({
    name  = "waypaper-float",
    match = { class = "^(waypaper)$" },

    float  = true,
    size   = "1000 700",
    center = true,
})

-- wallhelper (the day's photo + the kept collection)
hl.window_rule({
    name  = "wallhelper-float",
    match = { class = [[^(dev\.jaeho\.Wallhelper)$]] },

    float  = true,
    size   = "1120 760",
    center = true,
})

-- Betterbird — float compose/reply windows, keep main tiled
hl.window_rule({
    name  = "betterbird-compose-float",
    match = {
        class = [[^(eu\.betterbird\.Betterbird)$]],
        title = "^(Write:|Re:|Fwd:)",
    },

    float  = true,
    size   = "800 600",
    center = true,
})

---------------------
---- LAYER RULES ----
---------------------

hl.layer_rule({
    name  = "waybar-blur",
    match = { namespace = "waybar" },

    blur         = true,
    xray         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "swaync-notification-blur",
    match = { namespace = "swaync-notification-window" },

    blur         = false,
    ignore_alpha = 1,
})

hl.layer_rule({
    name  = "swaync-control-center-blur",
    match = { namespace = "swaync-control-center" },

    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "keybind-cheatsheet-blur",
    match = { namespace = "keybinds" },

    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "settings-menu-blur",
    match = { namespace = "settings" },

    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "rofi-blur",
    match = { namespace = "rofi" },

    blur         = true,
    ignore_alpha = 0.5,
})

-- Vim-style navigation inside the control center. `hypr-swaync-keys` enters
-- and leaves this submap by watching swaync's own `visible` flag, so it is
-- never entered by hand. The helper checks visibility before restoring it.
--
-- Only the translations below are bound. Everything swaync already handles --
-- Return, Delete/BackSpace/x/d, Home/End, Escape, q (close), Shift+C (clear
-- all), 1-9 (actions) -- is deliberately left unbound so Hyprland forwards
-- it untouched, and bare letters stay free. A `catchall` here would swallow
-- the lot. Media keys and screenshots are re-declared below because they are
-- compositor binds that an exclusive submap would otherwise silence.
local function swaync_key(key)
    return hl.dsp.exec_cmd("~/.local/bin/hypr-swaync-keys send " .. key)
end

hl.define_submap("swaync", "reset", function()
    hl.bind("CTRL + n", swaync_key("Down"), { repeating = true }) -- next notification
    hl.bind("CTRL + p", swaync_key("Up"),   { repeating = true }) -- previous notification
    hl.bind("j", swaync_key("Down"), { repeating = true }) -- next notification
    hl.bind("k", swaync_key("Up"),   { repeating = true }) -- previous notification
    -- g is the gg prefix (second g sends Home). End is SHIFT+g, not the keysym
    -- "G": Hyprland treats bare "G" as the g key too, which made every g jump
    -- to the bottom.
    hl.bind("g", swaync_key("g")) -- gg: top
    hl.bind("SHIFT + g", swaync_key("End")) -- bottom
    hl.bind("d", swaync_key("Delete")) -- dismiss
    hl.bind("q", hl.dsp.exec_cmd("swaync-client -t")) -- close
    -- Swallow Shift+D so it cannot reach swaync's DND toggle. The underline
    -- on that switch is gone too (config.json).
    hl.bind("SHIFT + d", function() end)
    -- Native Up/Down, Home/End and 1-9 go straight to swaync. The fork
    -- labels action buttons with their numbers; no synthetic keypress needed.
    -- Passthroughs: a submap is exclusive, so without these it would silence
    -- the media keys and the panel's own toggle while the panel is open.
    hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("swaync-client -t")) -- close the panel
    bind_media_keys()
    bind_screenshots() -- screenshotting with the panel open is the common case
end)
