---
name: Omnibook Desktop
description: "Everforest Dark Medium chrome for one keyboard-driven Hyprland laptop: gray at rest, a hue only when it carries news."
colors:
  # A copy of home/hypr/.config/hypr/themes/foliage.conf for DESIGN.md
  # tooling. Code reads that file by these names at runtime, never this one.
  green: "#a7c080"
  blue: "#7fbbb3"
  purple: "#d699b6"
  orange: "#e69875"
  red: "#e67e80"
  yellow: "#dbbc7f"
  bg_dim: "#232a2e"
  bg0: "#2d353b"
  bg1: "#343f44"
  bg2: "#3d484d"
  bg3: "#475258"
  fg: "#d3c6aa"
  grey2: "#9da9a0"
  grey1: "#859289"
  grey0: "#7a8478"
typography:
  headline:
    fontFamily: "Adwaita Sans, sans-serif"
    fontSize: "15px"
    fontWeight: 600
  field:
    fontFamily: "Adwaita Sans, sans-serif"
    fontSize: "14px"
    fontWeight: 400
  body:
    fontFamily: "Adwaita Sans, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: "Adwaita Sans, sans-serif"
    fontSize: "11px"
    fontWeight: 400
  heading:
    fontFamily: "Adwaita Sans, sans-serif"
    fontSize: "11px"
    fontWeight: 700
  mono:
    fontFamily: "JetBrainsMono Nerd Font, monospace"
    fontSize: "11px"
    fontWeight: 400
  icon:
    fontFamily: "JetBrainsMono Nerd Font, monospace"
    fontSize: "17px"
  bar:
    fontFamily: "JetBrainsMono Nerd Font, Noto Sans, monospace"
    fontSize: "13px"
    fontWeight: 400
  notification:
    fontFamily: "JetBrainsMono Nerd Font"
    fontSize: "14px"
    fontWeight: 400
  hangul:
    fontFamily: "Noto Sans CJK KR, sans-serif"
    fontSize: "28px"
    fontWeight: 600
rounded:
  window: "12px"
  control: "8px"
  pill: "9999px"
spacing:
  tight: "4px"
  gap: "8px"
  inline: "12px"
  sheet: "20px"
components:
  sheet:
    backgroundColor: "{colors.bg_dim}"
    textColor: "{colors.fg}"
    rounded: "{rounded.window}"
    padding: "18px 20px 14px 20px"
  button:
    backgroundColor: "{colors.bg0}"
    textColor: "{colors.fg}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "30px"
  button-hover:
    backgroundColor: "{colors.bg1}"
  field:
    backgroundColor: "{colors.bg0}"
    textColor: "{colors.fg}"
    typography: "{typography.field}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "36px"
  bar-module:
    textColor: "{colors.grey2}"
    typography: "{typography.bar}"
    rounded: "{rounded.control}"
    padding: "0 7px"
  workspace-active:
    backgroundColor: "{colors.blue}"
    textColor: "{colors.bg0}"
    typography: "{typography.bar}"
    rounded: "{rounded.control}"
    padding: "0 7px"
  workspace-urgent:
    backgroundColor: "{colors.red}"
    textColor: "{colors.bg0}"
    rounded: "{rounded.control}"
  workspace-special-active:
    backgroundColor: "{colors.purple}"
    textColor: "{colors.bg0}"
    rounded: "{rounded.control}"
  menu:
    backgroundColor: "{colors.bg0}"
    textColor: "{colors.fg}"
    rounded: "{rounded.window}"
    padding: "4px"
  menu-item:
    rounded: "{rounded.control}"
    padding: "4px 12px"
  notification:
    backgroundColor: "{colors.bg_dim}"
    textColor: "{colors.fg}"
    typography: "{typography.notification}"
    rounded: "{rounded.window}"
    padding: "7px"
  launcher-row-selected:
    backgroundColor: "{colors.fg}"
    textColor: "{colors.bg_dim}"
    rounded: "{rounded.control}"
  key-lit:
    backgroundColor: "{colors.green}"
    textColor: "{colors.bg_dim}"
    typography: "{typography.hangul}"
    rounded: "{rounded.control}"
    size: "56px"
---

# Design System: Omnibook Desktop

## Overview

<!-- markdownlint-disable-next-line MD036 -->
**Creative North Star: "The Dark Cockpit"**

This is the chrome of one Arch Linux laptop running Hyprland: window borders and shadows, the Quickshell bar, swaync, rofi, hyprlock, the `hypr-*` GTK4 overlays and the Quickshell polkit prompt. Every surface is a native Wayland client styled in its own language: GTK4 CSS loaded from Python through gtk4-layer-shell (`home/hypr/.local/bin/hypr-*`, `home/laptop/.local/bin/speaker-eq`), GTK3 CSS for swaync, rasi for rofi, QML for Quickshell (`home/hypr/.config/quickshell/bar/` and `polkit/`) and Hyprland's Lua config (`home/hypr/.config/hypr/hyprland.lua`). There are no web pages. The terminal and CLI tools share the palette through vendored ports (`home/theme/.config/theme/README.md`); GUI apps that are not the owner's keep their stock colors (`docs/gui-app-colors.md`), and nothing in this system restyles them.

The name comes from the aviation principle that a normal state lights nothing. At rest the chrome is parchment and gray on dark green-gray grounds; a hue appears when it carries news, and a state hue means the same thing on every surface: blue is focus and "you are here," orange is worth a glance, red is act now, green is charging or approved, purple is a special workspace, yellow is caution. Overlays appear when called, say what they need in plain words, and leave; a sheet that takes the keyboard holds it only while open, and nothing takes focus unasked.

Density is compact and keyboard-paced: 13px words, 11px labels, controls 8px apart. Surfaces are dark sheets edged by a 1px hairline, with lighter controls on them; corners follow a 12/8 scale; depth is an edge, not a lift. Motion is short and serves state: the compositor's pop-in and fades, hovers that brighten in 200ms, and one authored moment on the polkit prompt, whose sheet drops from the top edge under the IR camera, breathes its lens dot while the camera looks, and retracts after "Approved."

**Key Characteristics:**

- Everforest Dark Medium (decision #71), read by token name from `home/hypr/.config/hypr/themes/foliage.conf`.
- Gray at rest; a hue only for news, with one meaning per state hue.
- Dark `bg_dim` sheets with a 1px `bg2` hairline; `bg0` controls that step lighter on hover.
- State as a tint of its tone; a solid tone fill only for the one active marker in a row.
- Adwaita Sans for words; JetBrainsMono Nerd Font for glyph icons, identifiers and key names, and for all of the bar, notifications, launcher and lock screen.
- Radii of 12, 8 and pill; square where a surface meets a screen edge.
- A tight 4px edge shadow and blur behind translucent layers; no lift.

## Colors

Everforest Dark Medium (sainnhe/everforest): dark green-gray grounds, warm parchment text and muted role hues, chosen over Catppuccin Mocha because its text is warmer, about 5,100 K against 8,900 K (decision #71).

**Where the values live.** `home/hypr/.config/hypr/themes/foliage.conf` defines each of the 24 tokens once, as `$name = rgb(rrggbb)` under Everforest's own names. hyprlock sources it; the `hypr-*` panels, speaker-eq and the Quickshell bar's and polkit prompt's `Colors.qml` parse it at runtime and use token names, never hexes. Three packages keep same-named copies in their own formats, as decision #71 and the theme README record (hand recolors, no palette compiler): `themes/foliage.lua` for `hyprland.lua`, a `foliage.css` of `@define-color` lines for swaync, and `themes/foliage.rasi` for rofi. All matched every token on 2026-11-05; nothing checks them. The frontmatter above is one more copy, for DESIGN.md tooling only.

### Primary

- **Fern Green** (`green`): Everforest's accent. The focused window's 2px border (at `ee` alpha), hyprlock's accent (input outline, greeting), and success: the polkit "Approved" band and lens, a lit key on the hangul hint, the charging battery on the bar. 7.28:1 on `bg_dim`.

### Secondary

- **Muted Teal** (`blue`): focus and "you are here." The active workspace pill (with `bg0` text, 5.74:1), hover pills at 0.14, the 2px focus ring, `.on` toggle tiles, the polkit Approve button, a focused field's edge, the text caret, selections at 0.35 to 0.4, swaync's progress bars and DND switch, and the polkit lens while the camera looks. 6.70:1 on `bg_dim`.

### Tertiary

- **Heather Pink** (`purple`): special workspaces, as their active pill and as the window title while one holds focus, so a raised scratch surface never reads as the workspace you are on.

### Signal

- **Soft Apricot** (`orange`): on and worth a glance: stay-awake engaged, the mic in use, pending notifications, low battery, busy load, a tray app asking for attention.
- **Dusty Coral** (`red`): act now: screen sharing, failed units, critical battery, an urgent workspace, pegged CPU or RAM, do-not-disturb, a pending reboot, an armed destructive button, a wrong password, the power glyph under the pointer. 5.31:1 on `bg_dim`, 4.55:1 on `bg0`.
- **Straw** (`yellow`): caution: the polkit prompt when the camera gives up and the password takes over, Caps Lock on the lock screen, speaker-eq's warning notices.

Two widgets also use hues to tell meters apart rather than to report state: swaync's volume (`blue`) and backlight (`yellow`) sliders, and the per-metric labels in the bar's load tip (CPU `grey2`, RAM `aqua`, GPU `blue`).

### Neutral

- **Forest Shade** (`bg_dim`): the darkest plane. Overlay sheets (at 0.985), notification cards, the docked hangul strip, text on solid tone fills, keycap lips, and the color of every shadow.
- **Dark Slate** (`bg0`): controls on sheets, the bar's islands (at 0.88), menus, tooltips, the swaync control center and rofi's window.
- **Raised Slate** (`bg1`): control edges, hover fill, slider and meter tracks, hyprlock's input fill.
- **Hairline Slate** (`bg2`): sheet and card hairlines, a resting field's edge, the hangul hint's keys.
- **Lifted Slate** (`bg3`): hover edges and raised keycap faces.
- **Parchment** (`fg`): primary text and glyphs. 8.62:1 on `bg_dim`, 7.38:1 on `bg0`.
- **Sage Gray** (`grey2`): secondary text, resting bar glyphs, the polkit action id, placeholders. 5.97:1 on `bg_dim`, 5.12:1 on `bg0`.
- **Lichen Gray** (`grey1`): the inactive window border (at `aa` alpha) and a resting special workspace. 4.49:1 on `bg_dim`, so not for text.
- **Moss Gray** (`grey0`): off: muted audio, Bluetooth off, a display that is switched off, a disabled control. 3.74:1 on `bg_dim`, 3.21:1 on `bg0`.

The file's other tokens (`bg4`, `bg5`, `bg_visual`, the `bg_red` to `bg_purple` tints and `aqua`) are not chrome colors; `aqua` appears only as the RAM label in the bar's load tip and in hypr-confetti's paper.

**Drift.** Fallback palette hexes are restated in code: `hyprland.lua` (3, used if `foliage.lua` fails to load) and `hypr-confetti` (2). `Colors.qml` shows the intended pattern: neutral grays that are not palette values. `grey0` also carries text that has to be read: the 11px group headings and state lines on the settings and display sheets and in speaker-eq, the keybind sheet's tallies, footers and filter placeholder, its unbound key labels (3.21:1 on `bg0`), and the bar's resting workspace numbers (3.27:1 on an island). PRODUCT.md says the palette is never restated; the package copies above are the exception decision #71 allows.

### Color Rules

**The Dark Cockpit Rule.** At rest the chrome is `fg`, `grey2` and `grey0` on dark grounds. A hue appears when it carries news, and a state hue means the same thing on every surface.

**The One Source Rule.** Hex values are defined in `foliage.conf`. Surface code names tokens and parses that file at runtime; when the file cannot be read it falls back to neutral grays, never to palette hexes.

**The Tint Rule.** A control's state is its tone at low alpha behind (0.12 to 0.2) and at mid alpha on the 1px edge (0.45 to 0.55). Words on a band stay `fg` unless the tone holds 4.5:1 on its own band: green words measure 5.46:1 on the green band, red only 4.28:1, so error words stay `fg` (6.94:1). A solid tone fill is kept for the single active marker in a row: the current workspace, a lit key, rofi's selected row, a suggested action.

## Typography

**Body Font:** Adwaita Sans (with `sans-serif`), the session's UI face (`org.gnome.desktop.interface font-name` is `Adwaita Sans 11`).

**Label/Mono Font:** JetBrainsMono Nerd Font (with `monospace`), which also carries the icon set: Material Design Icons from the Nerd Font's `md-` range.

**Hangul Font:** Noto Sans CJK KR, for the jamo on the hangul hint.

**Character:** A plain humanist sans for anything read as words, and a monospace with a built-in icon font for everything glyph-like: icons, key names, identifiers and numbers. There is no display face; the largest type is hyprlock's clock, JetBrainsMono Nerd Font at `font_size = 120`. On the overlays, hierarchy comes from weight and color across 11 to 15px.

### Hierarchy

- **Headline** (Adwaita Sans 600, 15px): the line that says what a sheet is about; the polkit message.
- **Field** (Adwaita Sans 400, 14px): text typed into a field: the polkit password, the keybind sheet's filter.
- **Body** (Adwaita Sans 400, 13px): names on tiles and rows, status lines, button labels, keybind descriptions.
- **Label** (Adwaita Sans 400, 11px): the state under a tile's name ("On", "Balanced"), tallies, footers.
- **Heading** (Adwaita Sans 700, 11px, uppercase): group headings on the settings and display sheets ("TOGGLES", "OPEN", "SESSION") and in speaker-eq.
- **Mono** (JetBrainsMono Nerd Font 400, 11px; 700 on keycaps; 10px for the key hint inside a button): identifiers such as the polkit action id, key names on keycaps, "Esc" and "Enter" beside button labels.
- **Icon** (JetBrainsMono Nerd Font, 17px on tiles, 22px for the polkit shield, 16px for status glyphs): Material Design Icons in `fg` or the state's tone.
- **Bar** (JetBrainsMono Nerd Font 400, 13px; the clock bold, the window title italic, the power glyph 15px): everything on the bar.
- **Notification** (JetBrainsMono Nerd Font 400, 14px): swaync popups and the control center.
- **Hangul** (Noto Sans CJK KR 600, 28px; shifted jamo 500, 13px): the jamo on the hint's keycaps.

rofi sets its list in JetBrainsMono Nerd Font 11 with Papirus-Dark app icons; hyprlock sets every label in JetBrainsMono Nerd Font.

### Type Rules

**The Two Faces Rule.** Words are Adwaita Sans. JetBrainsMono Nerd Font draws glyph icons and sets identifiers, key names and numerals, and it is the whole voice of the bar, swaync, rofi and hyprlock, as built. A new sheet sets its words in Adwaita Sans.

**The Readable Gray Rule.** Text that has to be read is `fg` or `grey2`. `grey1` (4.49:1 on `bg_dim`) and `grey0` (3.74:1) carry no such text; `grey0` marks off.

## Layout

**Screen and bar.** The laptop panel is 1920×1080 at scale 1 (`eDP-1`); external monitors get rules computed in `monitors.lua`. Workspaces run 1 to 9. The bar (Quickshell, `home/hypr/.config/quickshell/bar/`) reserves 40px at the top. Its modules gather into three floating islands (left, center, right), 26px tall, 10px below the top edge and 8px from the sides, with a short 1px hairline (`blue` at 0.28, 14px tall) before each cluster on the right island.

**Windows.** Dwindle tiling with a 2px border and `gaps_in` of 5, so tiled windows sit 10px apart. Floating helper TUIs open centered at 800×600 (btop at 1400×900). Game mode (`hypr-gamemode`) drops gaps, rounding, blur, shadows and animations until a reload restores them.

**Overlays.** The sheets are layer-shell surfaces on the overlay layer that take the keyboard while open. The settings (480px), display (520px) and keybind sheets center on screen; the keybind sheet sizes to its content. The polkit prompt covers the focused monitor with a 40% black scrim and hangs a 440px sheet flush from the top edge, centered under the IR camera. The hangul hint takes no input: it floats 56px above the bottom edge, or docks as a full-width strip that reserves its own height. swaync stacks 380px popups at the top right; its control center is 420×600 with 10px margins.

**Rhythm.** Controls and rows sit 8px apart in grids of equal columns (settings: three toggle columns, two "Open" columns, five session columns). Stacked labels sit 2 to 4px apart, controls pad 12px inline, and sheets pad about 20px at the sides (settings and display 18/20/14/20, polkit 26/22/20, keybinds 20/26/16/26). The hangul board pads 16px all round.

**Drift.** `hyprland.lua` sets `gaps_out = { 10, 20, 20, 20 }`, but Hyprland 0.56.2's Lua parser reads a gap table only through its `top`, `right`, `bottom` and `left` keys (`src/config/lua/types/LuaConfigCssGap.cpp`), so the positional table resolves to 0 on every side without an error. `hyprctl getoption general:gaps_out` reports `0 0 0 0`, and tiled windows meet the screen edges and the bar's reserved zone.

## Elevation & Depth

Depth is tone and edge, not lift. A sheet is the darkest plane on screen (`bg_dim`), the controls on it step lighter (`bg0`, then `bg1` on hover), and a 1px hairline draws its boundary. Windows get a 2px border and a tight 4px dark shadow with no offset. Layer surfaces do not receive the compositor's shadow, so the polkit sheet draws its own and the GTK4 sheets rely on their hairline. Blur sits behind translucent layers so they read over busy windows.

### Shadow Vocabulary

- **Window edge** (`decoration.shadow` in `hyprland.lua`: range 4, render_power 3, `bg_dim` at `ee`, offset 0 0): every window.
- **Sheet edge** (QML `RectangularShadow`: blur 6, radius 12, `bg_dim` at 0.93): the polkit sheet, reproducing the window edge on a layer surface.
- **Notification card** (`box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px @bg2`): swaync popups; the control center uses the same shadow with an inset `bg1` line. Both come from swaync's release theme.
- **Keycap lip** (`border-bottom: 3px solid` in `bg_dim`; 2px on the keybind sheet's caps): a key's front edge, drawn as a border, on the hangul hint and the keybind sheet.

**Blur and glass.** Hyprland blurs at size 5 with 2 passes and vibrancy 0.1696, popups included. Layer rules blur behind the bar (with xray; its surface runs 360px down for the sheet, menus and tips, and `ignore_alpha` keeps the blur to what it draws), the swaync control center, the keybind sheet, the hangul hint, the settings sheet and rofi, each with `ignore_alpha 0.5`; swaync popups are not blurred, and the polkit layer has `no_anim` because it animates itself. Glass shows only where a surface is translucent: the bar islands (`bg0` at 0.88) and the hangul board (`bg_dim` at 0.72, so the hint reads over any window). Sheets at 0.985 are effectively opaque.

**Scrim.** Only the polkit prompt dims the screen: black at 40%, faded in over 220ms.

**Drift.** The display sheet's layer namespace (`display`) has no blur rule; at 0.985 it shows no difference.

### Depth Rules

**The Edge, Not Lift Rule.** Separation comes from a 1px hairline, a 2px window border and a tight dark shadow. A new layer surface that needs the window edge draws it as the polkit sheet does.

**The Glass With A Reason Rule.** Blur goes behind a layer so a translucent surface stays legible. A new translucent layer namespace gets a blur rule with `ignore_alpha 0.5`; a layer that animates itself gets `no_anim`.

## Shapes

Corners follow one scale: 12px for windows and containers (Hyprland's `decoration.rounding`, with `rounding_power` 2), 8px for controls nested inside them, and a pill for anything fully round. A corner that meets a screen edge stays square: the polkit sheet's top corners, the docked hangul strip. Edges are 1px hairlines; the only heavier lines are the 2px window border, the 2px focus ring, the keycap lip and hyprlock's 3px input outline.

On the scale today: the polkit sheet, the hangul board, the bar islands, the bar's menus and open sheet, swaync's cards, rofi's window and hyprlock's input field at 12px; the polkit buttons, field and band, the hangul keys, the bar's pills, menu rows and tips, swaync's nested cards and buttons, rofi's input bar and rows at 8px; the polkit lens dot, swaync's slider troughs and the hangul home-key bumps as pills.

**Drift.** The older GTK4 sheets run one step larger than the scale: the settings, display and keybind sheets use 16px, their tiles, cards, layout and session buttons 12px, and the settings rows and the keybind filter and chips 9px. speaker-eq's notices use 10px, the keybind sheet's key buttons 6px and its caps 5px. Waybar's tooltips, which are popups, use 8px.

### Shape Rules

**The 12/8 Rule.** Windows and containers take 12px, controls nested in them 8px, fully round elements a pill, and a corner that meets a screen edge stays square. A new surface picks from this scale.

## Components

### Sheets

A dark card that appears on demand and holds the keyboard.

- **Surface:** `bg_dim` at 0.985 with a 1px `bg2` hairline and 12px corners (16px on the older GTK4 sheets, see Shapes), padded about 20px at the sides.
- **Content:** a Heading over each group, then a grid of controls 8px apart.
- **Hanging variant:** the polkit sheet draws its hairline on the sides and bottom only and keeps square top corners, flush with the screen edge.
- **Panels in app windows:** speaker-eq's panels are the same card on a `bg0` window: `bg_dim`, a 1px `bg1` edge, 12px corners, 12px padding.

### Buttons

Quiet tiles that brighten under the pointer and ring under the keyboard.

- **Shape:** 8px corners (the settings tiles are 12px and its rows 9px, see Shapes).
- **Default:** `bg0` fill, 1px `bg1` edge, `fg` names, a Material Design glyph icon at 17px.
- **Hover:** `bg1` fill with a `bg3` edge, on the GTK4 sheets and the polkit sheet alike.
- **Focus:** an `fg` border plus a 2px `blue` outline offset 1px.
- **On:** `blue` at 0.18 behind and 0.55 on the edge; the icon and state line turn `blue` (4.69:1 on that band).
- **Primary:** the polkit Approve button: `blue` at 0.18 (0.28 on hover) behind and 0.55 on the edge, an `fg` label, 30px tall, 12px inline padding, and its key in Mono beside the label ("Enter"). Cancel is the default button with "Esc" beside it in `grey2`.
- **Armed:** Log out, Reboot and Shut down take a second press. The first arms the button for 3 seconds: `red` at 0.2 behind, a full `red` edge, and the label "Again?" in `red`.
- **Disabled:** 0.5 opacity on the polkit sheet; GTK's insensitive state elsewhere.

### Inputs / Fields

- **Style:** `bg0` fill (the keybind filter uses `bg1`), a 1px `bg2` edge, 8px corners (the keybind filter 9px), 12px inline padding, Field type in `fg`; 36px tall on the polkit sheet.
- **Focus:** the edge turns `blue` (the keybind filter adds a 1px `blue` outline at 0.35); the caret is `blue`; a selection is `blue` at 0.35 to 0.4 under `fg` text.
- **Placeholder:** `grey2` on the polkit sheet ("Password for" and the user's name).

### Status Bands

A tinted line for the frames the owner must not miss.

- **Shape:** 8px corners, reaching 10px past the text column at each side and 7px above and below.
- **Approved and wrong password:** the tone at 0.14 behind and 0.45 on the edge. "Approved" sets its words in `green` DemiBold; a wrong password keeps `red` in the glyph, fill and edge and its words in `fg`.
- **Looking and fallback:** plain status lines with a tone-colored glyph and no band: `blue` while the camera looks, `yellow` once the password takes over.
- **Notices:** speaker-eq bands info, warning and error notices in `blue`, `yellow` and `red` at 0.12 behind and 0.45 to 0.5 on the edge.

### Navigation

The bar: three quiet islands, with only the active workspace filled.

- **Islands:** `bg0` at 0.88, a 1px `blue` edge at 0.18, 12px corners, 6px inline padding.
- **Modules:** glyphs in `grey2` in 8px-corner pills; hover brightens the glyph to `fg` over a `blue` pill at 0.14, in 200ms. The clock is bold `fg`; the window title is italic and collapses on an empty workspace.
- **Workspaces:** each number is followed by its windows' app icons at 0.45 opacity (0.68 on the active pill, 0.88 for the focused window). The active workspace is a solid `blue` pill with `bg0` text, an urgent one solid `red`, an active special workspace solid `purple`.
- **State:** glyphs change color by the Signal roles; critical load pulses opacity to 0.35 every 0.5s, and a critical battery blinks toward `fg`.
- **Sheet:** a click on the center island, or Super+Shift+B, grows it in place into the player beside the month; it fades from the island's glass to `bg_dim` at 0.985 as it opens. Esc or a click outside closes it.
- **Menus:** the power menu, the reboot confirmation and tray menus drop from the control that opened them as small sheets: `bg_dim` at 0.985 over a shadow, a 1px `blue` edge at 0.18, 12px corners, 30px rows in Adwaita Sans with a `bg1` hover. A submenu opens in place under a back row.
- **Tips:** after half a second's hover, `bg0` with mono `fg` text, a 1px `blue` edge at 0.28 and 8px corners, centered under the control and drawn inside the bar's own surface.

### Notifications

- **Popups:** `bg_dim` cards with 12px corners and an 18px margin, under the notification card shadow; the summary in `fg`, time and body in `grey2`; actions as 8px `bg1` buttons with an inset `bg2` line; close as a small 8px `red` button with a `bg0` glyph.
- **Control center:** a `bg0` panel with 12px corners and 14px padding; nested cards at 8px; the DND switch is `bg1`, `blue` when on; volume in `blue`, backlight in `yellow`.
- **Inherited:** swaync's release theme also marks a critical card with an inner `red` glow and a hovered slider with a `blue` halo. New surfaces mark state with the Tint Rule instead.

### Launcher

rofi: a `bg0` window, 42em wide with 12px corners; the input bar and rows at 8px. The selected row is solid `fg` with `bg_dim` text (8.62:1); active entries are `blue` and urgent ones `red`.

### Keycaps

- **Hangul hint:** 56px keys on a 62px pitch, `bg2` at 0.94 with a `bg3` edge, a 3px `bg_dim` lip and 8px corners. The jamo is in Hangul type; the Latin letter sits in the corner in Mono 10px bold `grey1`, the shifted jamo in `grey2`. A pressed key lights at once in solid `green` with `bg_dim` jamo and fades back over 220ms on release. F and J carry a 20×3px pill bump.
- **Keybind sheet:** caps are Mono 11px bold `fg` on a `bg3` to `bg2` gradient with a 2px lip; the held prefix cap fills `blue` with `bg_dim` text. Keys on the keyboard map are `bg0` with a 3px lip: `blue` when bound, `bg3` when held, outlined in `fg` when selected.

### Polkit Prompt

The signature surface (`home/hypr/.config/quickshell/polkit/`), an approval sheet that belongs to the camera.

- **Composition:** a 10px lens dot at the top edge, centered under the IR camera; a shield glyph in a 22px slot beside the message (Headline) with the action id beneath (Mono, `grey2`); a status line in the same columns; the password field and Cancel and Approve once PAM asks.
- **Lens:** takes the state's tone (`blue` looking, `yellow` fallback, `red` after a wrong password, `green` approved) with a 180ms color change, and breathes from full to 0.25 opacity and back, 750ms each way (InOutSine), while PAM works.
- **Motion:** the sheet drops in over 360ms (OutExpo) and retracts over 220ms (InCubic); its height follows content over 240ms (OutExpo). A wrong password shakes it sideways in five steps over about 280ms.
- **Approval:** the buttons go, the sheet closes up around the green "Approved" band, holds 700ms, and retracts.

### Lock Screen

hyprlock: a blurred screenshot of the session (3 passes, size 8, brightness 0.6) behind a clock in `fg`, the date in `grey2` and a greeting in `green`; a 300×50 input with a 3px `green` outline on `bg1` and 12px corners, whose `check_color` is `green`, `fail_color` `red` and `capslock_color` `yellow`; battery and network in the top right.

**Drift.** The armed session label is `red` on its own band at 3.86:1; the hangul hint's Latin letters measure 2.98:1 and its shifted jamo 3.97:1 on their keys; the keybind filter's placeholder is `grey0`; the keybind chips and faint keys set `grey2` on `bg1` at 4.44:1, and its checked chip takes a full `blue` edge where on states elsewhere use 0.55. rofi edges its window in full `fg` (`border-color: @foreground` in the stock role map) where other surfaces use a `bg2` hairline, and colors its counts and placeholder with the CSS name `Gray`. hyprlock shows the battery in `green` at any charge, where the bar keeps `green` for charging.

### Component Rules

**The Second Press Rule.** A destructive session action arms on the first press, shows that it is armed in `red` ("Again?"), and fires only on a second press within 3 seconds.

**The Visible Approval Rule.** A face approval stays on screen as a green "Approved" band for 700ms before the sheet retracts, so a request the owner did not expect cannot pass unseen.

## Do's and Don'ts

### Do

- **Do** read colors at runtime from `home/hypr/.config/hypr/themes/foliage.conf` by Everforest's token names, and fall back to neutral grays when it is missing (`Colors.qml`).
- **Do** build an overlay as a `bg_dim` sheet at 0.985 with a 1px `bg2` hairline, 12px corners, about 20px side padding and controls 8px apart.
- **Do** draw controls as `bg0` with a 1px `bg1` edge, hover to `bg1` with a `bg3` edge, and ring keyboard focus with an `fg` border and a 2px `blue` outline offset 1px.
- **Do** show a control's state as a tint of its tone (0.12 to 0.2 behind, 0.45 to 0.55 on the edge), and keep its words `fg` unless the tone holds 4.5:1 on its band.
- **Do** set words in Adwaita Sans (15px semibold headline, 13px body, 11px labels), and glyphs, identifiers and key names in JetBrainsMono Nerd Font, with icons from its Material Design set.
- **Do** keep each state hue to its meaning: `blue` focus, `orange` worth a glance, `red` act now, `green` charging or approved, `purple` special, `yellow` caution.
- **Do** give a new translucent layer namespace a blur rule with `ignore_alpha 0.5`, and a layer that animates itself `no_anim`.
- **Do** keep a corner square where a surface meets a screen edge.

### Don't

- **Don't** write a hex in surface code or in a fallback; name the token.
- **Don't** set text that has to be read in `grey1` or `grey0` (4.49:1 and 3.74:1 on `bg_dim`); `grey0` is for off.
- **Don't** add radii outside 12px, 8px and pill.
- **Don't** theme the GUI apps in `docs/gui-app-colors.md` (Firefox, Betterbird, Obsidian, Discord, Chrome, stock GTK and Qt apps, Spotify); they keep their own colors.
