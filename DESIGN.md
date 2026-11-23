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
  control-label:
    fontFamily: "Adwaita Sans, sans-serif"
    fontSize: "12px"
    fontWeight: 500
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
    fontFamily: "Material Symbols Rounded"
    fontSize: "20px"
  glyph:
    fontFamily: "JetBrainsMono Nerd Font, monospace"
    fontSize: "17px"
  bar:
    fontFamily: "JetBrainsMono Nerd Font, Noto Sans, monospace"
    fontSize: "13px"
    fontWeight: 400
  hangul:
    fontFamily: "Noto Sans CJK KR, sans-serif"
    fontSize: "28px"
    fontWeight: 600
rounded:
  # Theme.radius in the shell (home/hypr/.config/quickshell/bar/Theme.qml).
  surface: "12px"
  control: "8px"
  pill: "9999px"
spacing:
  # Theme.space in the shell.
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  sheet:
    backgroundColor: "{colors.bg_dim}"
    textColor: "{colors.fg}"
    rounded: "{rounded.surface}"
    padding: "12px"
  card:
    backgroundColor: "{colors.bg1}"
    textColor: "{colors.fg}"
    rounded: "{rounded.surface}"
    padding: "12px"
  button:
    textColor: "{colors.fg}"
    typography: "{typography.control-label}"
    rounded: "{rounded.pill}"
    padding: "0 12px"
    height: "30px"
  icon-button:
    textColor: "{colors.grey2}"
    rounded: "{rounded.pill}"
    size: "36px"
  icon-button-hover:
    textColor: "{colors.fg}"
  tile:
    backgroundColor: "{colors.bg1}"
    textColor: "{colors.fg}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    height: "48px"
  list-row:
    textColor: "{colors.fg}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    padding: "0 12px"
    height: "36px"
  button-flat:
    backgroundColor: "{colors.bg0}"
    textColor: "{colors.fg}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "30px"
  button-flat-hover:
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
    rounded: "{rounded.surface}"
    padding: "4px"
  menu-item:
    rounded: "{rounded.control}"
    padding: "4px 12px"
  notification:
    backgroundColor: "{colors.bg_dim}"
    textColor: "{colors.fg}"
    typography: "{typography.body}"
    rounded: "{rounded.surface}"
    padding: "12px"
    width: "380px"
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

This is the chrome of one Arch Linux laptop running Hyprland: window borders and shadows, the Quickshell shell (the bar, its sheets and the notifications), rofi, hyprlock, the `hypr-*` GTK4 overlays and the Quickshell polkit prompt. Every surface is a native Wayland client styled in its own language: GTK4 CSS loaded from Python through gtk4-layer-shell (`home/hypr/.local/bin/hypr-*`, `home/laptop/.local/bin/speaker-eq`), rasi for rofi, QML for Quickshell (`home/hypr/.config/quickshell/bar/` and `polkit/`) and Hyprland's Lua config (`home/hypr/.config/hypr/hyprland.lua`). There are no web pages. The terminal and CLI tools share the palette through vendored ports (`home/theme/.config/theme/README.md`); GUI apps that are not the owner's keep their stock colors (`docs/gui-app-colors.md`), and nothing in this system restyles them.

The name comes from the aviation principle that a normal state lights nothing. At rest the chrome is parchment and gray on dark green-gray grounds; a hue appears when it carries news, and a state hue means the same thing on every surface: blue is focus, "you are here" and the action on offer, orange is worth a glance, red is act now, green is charging or approved, purple is a special workspace, yellow is caution. Overlays appear when called, say what they need in plain words, and leave; a sheet that takes the keyboard holds it only while open, and nothing takes focus unasked.

Density is compact and keyboard-paced: 13px words, 11px labels, controls 8px apart. Surfaces are dark sheets edged by a 1px hairline; the controls on them are tonal pills and round icon buttons that wash with their tint under the pointer; corners follow a 12/8 scale; depth is an edge, not a lift. Motion is calm and serves state, on Material 3's standard curves with no overshoot: a wash fades in over 150ms, things move inside a surface over 250ms, and a surface arrives over 400ms, slowing into place. Beyond that and the compositor's pop-in and fades there is one authored moment, on the polkit prompt, whose sheet drops from the top edge under the IR camera, breathes its lens dot while the camera looks, and retracts after "Approved."

**The shell base (decision #89).** The bar's Quickshell config is growing into one shell (bar, quick settings, dash, notifications, then a launcher) built to Caelestia's polish on Material 3's patterns, in foliage colors; Caelestia is a reference, not a dependency. Its tokens live in `home/hypr/.config/quickshell/bar/Theme.qml` (radii, spacing, type, icon sizes, motion, state-layer strengths and surface roles), and its primitives beside it: `Sheet`, `StateLayer`, `PillButton`, `IconButton`, `Icon`, `Line`, `Anim` and `CAnim`. The notifications, quick settings, the tray's grid and the bar (its islands, menus, tips and player sheet) are built on it; a launcher replaces rofi's drun next. The GTK4 sheets and the polkit prompt keep the older controls this file describes beside the new ones (Buttons).

**Key Characteristics:**

- Everforest Dark Medium (decision #71), read by token name from `home/hypr/.config/hypr/themes/foliage.conf`.
- Gray at rest; a hue only for news or an action on offer, with one meaning per state hue.
- Dark `bg_dim` sheets with a 1px hairline; on them, tonal pill buttons, and one state-layer wash for hover, press and the keyboard's row; a 2px `blue` ring only for the keyboard's stop on a sheet walked in two directions.
- State as a tint of its tone; a solid tone fill only for the one active marker in a row.
- Adwaita Sans for words; Material Symbols Rounded for the shell's icons; JetBrainsMono Nerd Font for identifiers, key names, the older surfaces' glyphs, the bar's words and numbers, the launcher and the lock screen.
- Radii of 12, 8 and pill; square where a surface meets a screen edge.
- Material 3 standard motion, calm: 150, 250 and 400ms, no overshoot.
- A tight 4px edge shadow and blur behind translucent layers; no lift.

## Colors

Everforest Dark Medium (sainnhe/everforest): dark green-gray grounds, warm parchment text and muted role hues, chosen over Catppuccin Mocha because its text is warmer, about 5,100 K against 8,900 K (decision #71).

**Where the values live.** `home/hypr/.config/hypr/themes/foliage.conf` defines each of the 24 tokens once, as `$name = rgb(rrggbb)` under Everforest's own names. hyprlock sources it; the `hypr-*` panels, speaker-eq and the Quickshell bar's and polkit prompt's `Colors.qml` parse it at runtime and use token names, never hexes. Two packages keep same-named copies in their own formats, as decision #71 and the theme README record (hand recolors, no palette compiler): `themes/foliage.lua` for `hyprland.lua` and `themes/foliage.rasi` for rofi. Both matched every token on 2026-11-05; nothing checks them. The frontmatter above is one more copy, for DESIGN.md tooling only.

### Primary

- **Fern Green** (`green`): Everforest's accent. The focused window's 2px border (at `ee` alpha), hyprlock's accent (input outline, greeting), and success: the polkit "Approved" band and lens, a lit key on the hangul hint, the charging battery on the bar. 7.28:1 on `bg_dim`.

### Secondary

- **Muted Teal** (`blue`): focus, "you are here" and the action on offer. The active workspace pill (with `bg0` text, 5.74:1), the 2px focus ring, `.on` toggle tiles, the polkit Approve button, a notification's action pills, avatar wash and progress bar, a focused field's edge, the text caret, selections at 0.35 to 0.4, links in a notification's body, and the polkit lens while the camera looks. 6.70:1 on `bg_dim`.

### Tertiary

- **Heather Pink** (`purple`): special workspaces, as their active pill and as the window title while one holds focus, so a raised scratch surface never reads as the workspace you are on.

### Signal

- **Soft Apricot** (`orange`): on and worth a glance: stay-awake engaged, the mic in use, pending notifications, low battery, busy load, a tray app asking for attention.
- **Dusty Coral** (`red`): act now: screen sharing, failed units, critical battery, an urgent workspace, pegged CPU or RAM, do-not-disturb, a pending reboot, an armed destructive button, a critical notification (its edge, avatar wash and action pills), a wrong password, the power icon and its wash under the pointer, stay awake's icon while hypridle is not running. 5.31:1 on `bg_dim`, 4.55:1 on `bg0`.
- **Straw** (`yellow`): caution: the polkit prompt when the camera gives up and the password takes over, Caps Lock on the lock screen, speaker-eq's warning notices.

One widget also uses hues to tell meters apart rather than to report state: the per-metric labels in the bar's load tip (CPU `grey2`, RAM `aqua`, GPU `blue`).

### Neutral

- **Forest Shade** (`bg_dim`): the darkest plane. Overlay sheets (at 0.985), notification cards, the docked hangul strip, text on solid tone fills, keycap lips, and the color of every shadow.
- **Dark Slate** (`bg0`): controls on sheets, the bar's islands (at 0.88), menus, tooltips and rofi's window.
- **Raised Slate** (`bg1`): control edges, hover fill, slider and meter tracks, hyprlock's input fill, the shell's cards and quick settings' controls on a sheet (at 0.55) and its count pill.
- **Hairline Slate** (`bg2`): sheet and card hairlines, a resting field's edge, rofi's window edge and list separator, the hangul hint's keys.
- **Lifted Slate** (`bg3`): hover edges and raised keycap faces.
- **Parchment** (`fg`): primary text and glyphs. 8.62:1 on `bg_dim`, 7.38:1 on `bg0`.
- **Sage Gray** (`grey2`): secondary text, resting bar icons, the polkit action id, placeholders. 5.97:1 on `bg_dim`, 5.12:1 on `bg0`.
- **Lichen Gray** (`grey1`): the inactive window border (at `aa` alpha) and a resting special workspace. 4.49:1 on `bg_dim`, so not for text.
- **Moss Gray** (`grey0`): off: muted audio, Bluetooth off, a display that is switched off, a disabled control, the empty notification center's bell. 3.74:1 on `bg_dim`, 3.21:1 on `bg0`.

The file's other tokens (`bg4`, `bg5`, `bg_visual`, the `bg_red` to `bg_purple` tints and `aqua`) are not chrome colors; `aqua` appears only as the RAM label in the bar's load tip and in hypr-confetti's paper.

**Drift.** Fallback palette hexes are restated in code: `hyprland.lua` (3, used if `foliage.lua` fails to load) and `hypr-confetti` (2). `Colors.qml` shows the intended pattern: neutral grays that are not palette values. `grey0` also carries text that has to be read: the 11px group headings and state lines in speaker-eq. PRODUCT.md says the palette is never restated; the package copies above are the exception decision #71 allows.

### Color Rules

**The Dark Cockpit Rule.** At rest the chrome is `fg`, `grey2` and `grey0` on dark grounds. A hue appears when it carries news, and a state hue means the same thing on every surface.

**The One Source Rule.** Hex values are defined in `foliage.conf`. Surface code names tokens and parses that file at runtime; when the file cannot be read it falls back to neutral grays, never to palette hexes.

**The Tint Rule.** A control's state is its tone at low alpha behind (0.12 to 0.2) and, on the older controls, at mid alpha on the 1px edge (0.45 to 0.55); the shell base's tonal pills have no edge. Words on a band stay `fg` unless the tone holds 4.5:1 on its own band: green words measure 5.46:1 on the green band, red only 4.28:1, so error words stay `fg` (6.94:1). A solid tone fill is kept for the single active marker in a row: the current workspace, a lit key, rofi's selected row, a suggested action.

## Typography

**Body Font:** Adwaita Sans (with `sans-serif`), the session's UI face (`org.gnome.desktop.interface font-name` is `Adwaita Sans 11`).

**Label/Mono Font:** JetBrainsMono Nerd Font (with `monospace`), which also carries the older surfaces' icons: Material Design Icons from the Nerd Font's `md-` range.

**Icon Font:** Material Symbols Rounded, the variable font (`extra/ttf-material-symbols-variable`), named by ligature (`Icon.qml`). The shell base draws every icon with it and the older surfaces move to it as they join (decision #89).

**Hangul Font:** Noto Sans CJK KR, for the jamo on the hangul hint.

**Character:** A plain humanist sans for anything read as words, rounded Material Symbols for icons, and a monospace for everything glyph-like: key names, identifiers and numbers. There is no display face; the largest type is hyprlock's clock, JetBrainsMono Nerd Font at `font_size = 120`. On the overlays, hierarchy comes from weight and color across 11 to 15px.

### Hierarchy

- **Headline** (Adwaita Sans 600, 15px): the line that says what a sheet is about; the polkit message.
- **Field** (Adwaita Sans 400, 14px): text typed into a field: the polkit password, the keybind sheet's filter.
- **Body** (Adwaita Sans 400, 13px): names on tiles and rows, status lines, the older button labels, keybind descriptions, a notification's body; its summary is the same size at 600.
- **Control label** (Adwaita Sans 500, 12px): the shell's pill button labels; 400 for the line under the notification center's header.
- **Label** (Adwaita Sans 400, 11px): the state under a tile's name ("On", "Balanced"), tallies, footers, a notification's "App · 5m" line; 500 in the notification center's count pill.
- **Heading** (Adwaita Sans 700, 11px, uppercase): group headings on the display sheet, quick settings ("OPEN", "OUTPUT", "INPUT", in `grey2`) and in speaker-eq.
- **Mono** (JetBrainsMono Nerd Font 400, 11px; 700 on keycaps; 10px for the key hint inside a button): identifiers such as the polkit action id, key names on keycaps, "Esc" and "Enter" beside button labels, the key hints on a notification's pills, a quick settings slider's level.
- **Icon** (Material Symbols Rounded at 16, 20 or 24px, `Theme.icon`, and 18px on the bar): outlined at rest (FILL 0), filled when on (FILL 1, animated), weight 400 with optical size following the size; the empty notification center's bell is 40px at weight 300. In `fg`, `grey2` or the state's tone.
- **Glyph** (JetBrainsMono Nerd Font, 17px on tiles, 22px for the polkit shield, 16px for status glyphs): the older surfaces' Material Design Icons, in `fg` or the state's tone.
- **Bar** (JetBrainsMono Nerd Font 400, 13px; the clock bold, the window title italic): the bar's words and numbers: the clock, the track, the window title, workspace numbers, counts, the battery's time and the load ramps. Its icons are Material Symbols at 18px.
- **Hangul** (Noto Sans CJK KR 600, 28px; shifted jamo 500, 13px): the jamo on the hint's keycaps.

rofi sets its list in JetBrainsMono Nerd Font 11 with Papirus-Dark app icons; hyprlock sets every label in JetBrainsMono Nerd Font.

### Type Rules

**The Two Faces Rule.** Words are Adwaita Sans. JetBrainsMono Nerd Font sets identifiers, key names and numerals; it is the whole voice of rofi and hyprlock, and the bar's words and numbers. Icons are Material Symbols Rounded on the shell base, the bar included, and the Nerd Font's glyphs on the surfaces not yet moved (the GTK4 sheets, the polkit prompt). A new sheet sets its words in Adwaita Sans and its icons in Material Symbols.

**The Readable Gray Rule.** Text that has to be read is `fg` or `grey2`. `grey1` (4.49:1 on `bg_dim`) and `grey0` (3.74:1) carry no such text; `grey0` marks off.

## Layout

**Screen and bar.** The laptop panel is 1920×1080 at scale 1 (`eDP-1`); external monitors take Hyprland's default rules or ones saved from nwg-displays. Workspaces run 1 to 9. The bar (Quickshell, `home/hypr/.config/quickshell/bar/`) reserves 40px at the top. Its modules gather into three floating islands (left, center, right), 26px tall, 10px below the top edge and 8px from the sides, with a short 1px hairline (`blue` at 0.28, 14px tall) before each cluster on the right island. The islands keep 8px apart: the right island holds its width, the center island cuts its track to fit, and the left island its window title.

**Windows.** Dwindle tiling with a 2px border, `gaps_in` of 5 and `gaps_out` of 8 (6 under the bar), so tiled windows sit 10px apart and 10px below the islands, their edges in line with the islands' 8px inset. A gap table must be keyed (`top`, `right`, `bottom`, `left`): Hyprland reads a positional one as 0 without an error. Floating helper TUIs open centered at 800×600 (btop at 1400×900). Game mode (`hypr-gamemode`) drops gaps, rounding, blur, shadows and animations until a reload restores them.

**Overlays.** The sheets are layer-shell surfaces on the overlay layer that take the keyboard while open. The display (520px) and keybind sheets center on screen; the keybind sheet sizes to its content. Quick settings is not one of them: the bar's right island grows into it, 460px wide, inside the bar's own surface. The polkit prompt covers the focused monitor with a 40% black scrim and hangs a 440px sheet flush from the top edge, centered under the IR camera. The hangul hint takes no input: it floats 56px above the bottom edge, or docks as a full-width strip that reserves its own height. The notification popups stack 380px cards 8px apart at the top right of the focused monitor, 8px under the bar and 8px from the edge, newest on top; they never take the keyboard. The notification center is a 400px sheet in the same corner of the screen it was opened on, as tall as its list (scrolling past the screen's height); it holds the keyboard exclusively while open, and any Super chord closes it before Hyprland acts on the chord.

**Rhythm.** Controls and rows sit 8px apart in grids of equal columns (quick settings: three tile columns, two "Open" columns, a row of five session buttons, with 12px between groups). Stacked labels sit 1 to 4px apart and controls pad 12px inline. The shell base takes its gaps from `Theme.space` (4, 8, 12, 16, 24) and pads its sheets and cards 12px (`md`), with cards 8px apart. The older sheets pad about 20px at the sides (display 18/20/14/20, polkit 26/22/20, keybinds 20/26/16/26; the bar's open islands 16). The hangul board pads 16px all round.

## Elevation & Depth

Depth is tone and edge, not lift. A sheet is the darkest plane on screen (`bg_dim`), what sits on it steps lighter (the shell's cards, `bg1` at 0.55; the older controls, `bg0`, then `bg1` on hover), and a 1px hairline draws its boundary. Windows get a 2px border and a tight 4px dark shadow with no offset. Layer surfaces do not receive the compositor's shadow, so the shell's sheets and the polkit sheet draw their own and the GTK4 sheets rely on their hairline. Blur sits behind translucent layers so they read over busy windows.

### Shadow Vocabulary

- **Window edge** (`decoration.shadow` in `hyprland.lua`: range 4, render_power 3, `bg_dim` at `ee`, offset 0 0): every window.
- **Sheet edge** (QML `RectangularShadow`: blur 6, radius 12, `bg_dim` at 0.93): the polkit sheet and the shell's `Sheet` (each notification popup and the notification center), reproducing the window edge on a layer surface. A surface that draws it leaves an 8px gutter inside itself so the shadow is not cut.
- **Keycap lip** (`border-bottom: 3px solid` in `bg_dim`; 2px on the keybind sheet's caps): a key's front edge, drawn as a border, on the hangul hint and the keybind sheet.

**Blur and glass.** Hyprland blurs at size 5 with 2 passes and vibrancy 0.1696, popups included. Layer rules blur behind the bar (with xray; its surface runs 640px down for its two sheets, menus and tips, and `ignore_alpha` keeps the blur to what it draws), the keybind sheet, the hangul hint and rofi, each with `ignore_alpha 0.5`. The notification layers (`bar-notifications`, `bar-notification-center`) are not blurred, since their sheets are opaque, and have `no_anim`, as the polkit layer does, because they animate themselves. Glass shows only where a surface is translucent: the bar islands (`bg0` at 0.88) and the hangul board (`bg_dim` at 0.72, so the hint reads over any window). Sheets at 0.985 are effectively opaque.

**Scrim.** Only the polkit prompt dims the screen: black at 40%, faded in over 220ms.

**Drift.** The display sheet's layer namespace (`display`) has no blur rule; at 0.985 it shows no difference.

### Depth Rules

**The Edge, Not Lift Rule.** Separation comes from a 1px hairline, a 2px window border and a tight dark shadow. A new layer surface that needs the window edge draws it as the polkit sheet does.

**The Glass With A Reason Rule.** Blur goes behind a layer so a translucent surface stays legible. A new translucent layer namespace gets a blur rule with `ignore_alpha 0.5`; a layer that animates itself gets `no_anim`.

## Shapes

Corners follow one scale: 12px for windows and containers (Hyprland's `decoration.rounding`, with `rounding_power` 2), 8px for controls nested inside them, and a pill for anything fully round. A corner that meets a screen edge stays square: the polkit sheet's top corners, the docked hangul strip. `Theme.radius` names them `surface`, `control` and `pill`. Edges are 1px hairlines; the only heavier lines are the 2px window border, the 2px focus ring, the keycap lip and hyprlock's 3px input outline.

On the scale today: the polkit sheet, the keybind sheet, the hangul board, the bar islands, the bar's menus and open sheets, the notification popups, center and the cards in it, quick settings' session buttons, rofi's window and hyprlock's input field at 12px; the polkit buttons, field and band, the Wi-Fi page's field and the join failure bands, the keybind sheet's filter, chips, keys and caps, the hangul keys, the bar's workspace pills, menu rows, tips and cover art, the tray grid's cells, rofi's input bar and rows at 8px; the shell's buttons, icon buttons, count pill, avatars and progress bars, the bar's buttons and the tray's attention slots, the player sheet's buttons, today's marker and progress meter, the polkit lens dot, quick settings' tiles, rows, "Open" buttons, sliders and switch, and the hangul home-key bumps as pills.

**Drift.** speaker-eq's notices use 10px. rofi keeps the stock theme's 2px dashed list separator, a heavier line than a hairline.

### Shape Rules

**The 12/8 Rule.** Windows and containers take 12px, controls nested in them 8px, fully round elements a pill, and a corner that meets a screen edge stays square. On the shell base a button is a pill and a card is a container; a tall button that stacks its icon over its label (quick settings' session row) takes the container's 12px. A new surface picks from this scale.

## Components

### Sheets

A dark card that appears on demand and holds the keyboard.

- **Surface:** `bg_dim` at 0.985 with a 1px hairline and 12px corners. The shell's `Sheet` edges it in `blue` at 0.18, as the bar's islands and menus are, draws the sheet edge shadow under it and pads it 12px; the GTK4 and polkit sheets edge it in `bg2` and pad about 20px at the sides.
- **Content:** a Heading over each group, then a grid of controls 8px apart. On the shell base, an item in a list sits on a card: `bg1` at 0.55, 12px corners, no edge.
- **Header (shell):** the sheet's name in Headline at the left with a count pill beside it, and the sheet's own controls at the right: icon buttons, then a neutral pill.
- **Hanging variant:** the polkit sheet draws its hairline on the sides and bottom only and keeps square top corners, flush with the screen edge.
- **Panels in app windows:** speaker-eq's panels are the same card on a `bg0` window: `bg_dim`, a 1px `bg1` edge, 12px corners, 12px padding.

### Buttons

On the shell base, tonal pills and round icon buttons that wash under the pointer; on the surfaces not yet moved, quiet tiles that brighten under the pointer and ring under the keyboard.

- **State layer** (`StateLayer.qml`): the shell's one hover, press and keyboard feedback, a wash of the control's tint over its own shape at `Theme.state`'s strengths: 0.08 under the pointer, 0.10 on the keyboard's row, 0.18 pressed, fading over 150ms. A button inside a clickable card takes the click before the card does.
- **Tonal pill** (`PillButton.qml`): 30px tall, 12px inline padding, its tint at 0.14 behind, an optional 16px icon in the tint and a Control label in `fg`, centered, cut with an ellipsis when narrow. The label stays `fg` by the Tint Rule: no tone holds 4.5:1 on its own wash over a card (red 3.70:1, `grey2` 4.00:1, blue 4.39:1), where `fg` holds 4.8:1 or more even under the pointer. A key hint sits at its right end in Mono 11px `grey2`. Blue for the actions something offers (red when it is critical), `grey2` for a sheet's own housekeeping ("Clear all"). Pills in one row share its width equally.
- **Icon button** (`IconButton.qml`): a round 36px target around a 20px icon (16px in a card's corner), `grey2` at rest and `fg` under the pointer. On, a toggle fills its icon and lays its tone at 0.14 under it: Do Not Disturb in `red`.
- **Quick settings controls** (`QuickControl.qml`): pills on the card tone (`bg1` at 0.55), or bare when flat (a list row), each over a `StateLayer` in its tint. On, `blue` at 0.18 behind; armed, `red` at 0.2; no edge. Under the keyboard, Material 3's focus indicator: a 2px `blue` ring 3px outside the control, shown only while the keyboard drives; a click puts it away.
  - **Tile** (`QuickTile.qml`): 48px tall, a 20px icon centered in its round end, the name in Body `fg` over the state in Label `grey2`, and a 16px `grey2` chevron at the end when it opens a page. On, the icon fills and it and the state turn `blue` (4.69:1 on that tint); off, the icon rests in `grey0`.
  - **Row** (`QuickRow.qml`): 36px tall and flat, a 20px icon 12px in, the name in Body `fg` from 44px, a note at the end in Label `grey2`; on, the tint, the icon filled and the icon and note in `blue`. The "Open" buttons are the same on the card tone, two to a row with an 18px icon.
  - **Session button:** 56px tall with 12px corners, the icon over the label in Label `grey2`; armed, the icon fills in `red` and the label says "Again?" in `fg`.
- **Older controls** (the GTK4 sheets and the polkit prompt, until they move):
  - **Shape:** 8px corners.
  - **Default:** `bg0` fill, 1px `bg1` edge, `fg` names, a Material Design glyph icon at 17px.
  - **Hover:** `bg1` fill with a `bg3` edge, on the GTK4 sheets and the polkit sheet alike. A flat control (a list row) is bare at rest and takes the `bg1` fill under the pointer.
  - **Focus:** an `fg` border plus a 2px `blue` outline offset 1px.
  - **On:** `blue` at 0.18 behind (0.28 under the pointer) and 0.55 on the edge; the icon and state line turn `blue` (4.69:1 on that band).
  - **Primary:** the polkit Approve button: `blue` at 0.18 (0.28 on hover) behind and 0.55 on the edge, an `fg` label, 30px tall, 12px inline padding, and its key in Mono beside the label ("Enter"). Cancel is the default button with "Esc" beside it in `grey2`.
- **Armed:** Log out, Reboot and Shut down take a second press. The first arms the button for 3 seconds: `red` at 0.2 behind (and 0.55 on the edge, on the older controls), and the label "Again?" in `fg`, as the Tint Rule asks. Quick settings' session row and the bar's power menu arm alike.
- **Disabled:** 0.5 opacity on the shell's pills (their wash drops to 0.06), the polkit sheet, quick settings and the display sheet's layout buttons; GTK's insensitive state elsewhere. A display card that can't be switched off (the last screen on) keeps its full strength, since it still marks the screen you are on.

### Inputs / Fields

- **Style:** `bg0` fill, a 1px `bg2` edge, 8px corners, 12px inline padding, Field type in `fg`; 36px tall on the polkit sheet and the Wi-Fi page, where it opens under the network's name.
- **Focus:** the edge turns `blue` (the keybind filter adds a 1px `blue` outline at 0.35); the caret is `blue`; a selection is `blue` at 0.35 to 0.4 under `fg` text.
- **Placeholder:** `grey2`: "Password for" and the user's name on the polkit sheet, the network's name on the Wi-Fi page, "Filter" on the keybind sheet.

### Status Bands

A tinted line for the frames the owner must not miss.

- **Shape:** 8px corners, reaching 10px past the text column at each side and 7px above and below.
- **Approved and wrong password:** the tone at 0.14 behind and 0.45 on the edge. "Approved" sets its words in `green` DemiBold; a wrong password keeps `red` in the glyph, fill and edge and its words in `fg`.
- **Looking and fallback:** plain status lines with a tone-colored glyph and no band: `blue` while the camera looks, `yellow` once the password takes over.
- **Notices:** speaker-eq bands info, warning and error notices in `blue`, `yellow` and `red` at 0.12 behind and 0.45 to 0.5 on the edge.
- **Join failures** (`QuickBand.qml`): the wrong-password band under the row's name on the Wi-Fi and Bluetooth pages, padded 8px, with a filled 16px `error` icon in `red`, saying why in plain words ("Wrong password, or the network turned it down.", "Couldn't connect. Check that it's on and in range.").

### Navigation

The bar: three quiet islands, with only the active workspace filled.

- **Islands:** `bg0` at 0.88, a 1px `blue` edge at 0.18, 12px corners, 6px inline padding.
- **Modules** (`BarButton.qml`): a Material Symbol at 18px, words in Bar type, or both, 24px tall, in its state's colour (`grey2` at rest), filled while it reports something on (stay awake, waiting notifications, the screen or mic in use). Under the pointer the icon turns `fg` over a pill-shaped `fg` wash at 0.08; the power and reboot buttons wash `red`. A lone icon sits 4px inside its pill, words 8px. The clock is bold `fg`; the window title is italic, collapses on an empty workspace, and gives way before the center island. Material Symbols have no brands, so the player shows as what it plays (a note, a film for mpv or VLC, a globe for a browser) and pause while paused.
- **Workspaces:** each number, `grey2` at rest, is followed by its windows' app icons, 8px apart, at 0.45 opacity (0.68 on the active pill, 0.88 for the focused window). The active workspace is a solid `blue` pill with `bg0` text, an urgent one solid `red`, an active special workspace solid `purple`; under the pointer a pill washes in `fg`, or in `bg0` when solid.
- **State:** icons change color by the Signal roles; critical load pulses opacity to 0.35 every 0.5s, and a critical battery blinks toward `fg`. Stay awake is `orange` while its inhibitor is held; its icon turns `red` while hypridle is not running, since then nothing answers Lock, and its tip says so.
- **Tray:** behind a chevron; resting the pointer on it, a click or Super+' drops the right island into a grid of the apps, five to a row (`TrayGrid.qml`, `TrayCell.qml`). Each app is a cell with 8px corners, its 24px icon over its name in Label, washing under the pointer. Icons rest desaturated at 0.8 and take their colours under the pointer or while the app asks for attention, which lays `orange` at 0.18 behind its cell; the name is `grey2` at rest and `fg` when lit, never `orange` (3.9:1 on that tint). An app asking for attention also comes out beside the chevron on an `orange` pill until the grid opens. The grid walks as quick settings does: h/j/k/l or the arrows move the selection, which wears the focus ring while the keyboard drives (at once from Super+'), Tab goes in order, Enter or Space brings the app up and Shift+Enter opens its menu, and Esc or q closes; the hint letters and f work as there, Shift and a letter opening the app's menu.
- **Player sheet:** a click on the center island, or Super+Shift+B, grows it in place into the player beside the month; it fades from the island's glass to `bg_dim` at 0.985 as it opens. Its transport and month buttons are pills on the card tone holding Material Symbols, play and pause wider; today is a solid `blue` pill; the progress meter is a 4px `fg` pill on `bg1`. Esc or a click outside closes it.
- **Quick settings:** Super+;, the sliders icon left of the power icon, or a right click on the speaker, Bluetooth or network icon (at that icon's page) grows the right island in place, leftward and down, into a 460px sheet; its icon row stays put and live as the header, and it fades as the player sheet does. One sheet is open at a time. The main page holds the volume and brightness sliders, Wi-Fi, Bluetooth and Sound tiles, `hypr-settings-menu`'s toggles (its `--json` table), its "Open" rows and the session row; the Wi-Fi, Bluetooth and Sound pages open in place under a back row (a `grey2` back arrow and the page's name in Headline, and the radio's switch at the right), and the height follows the page. A page's list is flat rows, the connected or default one on the `blue` tint with "Connected" or "Default" in `blue`; a long list scrolls behind a 3px `bg3` bar and fades into the sheet at the bottom. Headings, status lines and the back arrow line up with the rows' icons. Each page ends in a row, with a terminal icon, to the tool that does the rest (nmtui, bluetui, wiremix). j/k and h/l (or the arrows) move between controls, h/l step a focused slider, Tab goes in reading order, Enter or Space presses, and Esc or q backs out of a page, then closes. Each control has a hint letter that presses it (or focuses a slider), typed whether the letters show or not; they open hidden, and f shows them in the controls' corners as small keycaps and hides them again, as does Esc. The tray's grid (Super+') walks the same way (Tray).
- **Sliders and switches:** a slider is a 6px `bg1` pill track filled in `fg` to the level, a 12px `fg` knob with a 2px `bg_dim` edge that grows to 16px under the pointer, its 20px icon in a round 36px target (a click mutes the volume or mic) and the level in Mono 11px `grey2`; muted, the icon, fill and knob turn `grey0`. A switch is a 40×22 pill with a 14px knob: on, the `blue` tint with an `fg` knob at the right; off, the card tone with a `grey0` knob at the left.
- **Menus:** the power menu, the reboot confirmation and tray menus drop from the control that opened them as small sheets: `bg_dim` at 0.985 over a shadow, a 1px `blue` edge at 0.18, 12px corners, 30px rows in Adwaita Sans with 8px corners that wash under the pointer; checks, the back arrow and the submenu chevron are 16px Material Symbols. A submenu opens in place under a back row. Log out, Reboot and Shut down arm on the first click and run on a second within 3 seconds (see Buttons, Armed).
- **Tips:** after half a second's hover, `bg0` with mono `fg` text, a 1px `blue` edge at 0.28 and 8px corners, centered under the control and drawn inside the bar's own surface.

### Notifications

The bar's own daemon (`Notifs.qml`, #90) holds `org.freedesktop.Notifications` and keeps each notification until it is dismissed; the popups (`NotifPopups.qml`) and the center (`NotifCenter.qml`) draw the same card (`NotifCard.qml`).

- **Card:** 12px padding. A 40px round avatar: the sender's picture with its app icon as an 18px badge, else the app icon at 24px on the accent at 0.14, else a filled bell. Beside it, "App · 5m" in Label `grey2`; the summary in Body 600 `fg`, two lines; the body in Body `grey2`, three lines, with markup and `blue` links; a 4px progress bar in the accent on the accent at 0.18; the actions as equal tonal pills 6px apart, with a "Copy 123456" pill added for a one-time code. The accent is `blue`, or `red` with a 1px `red` edge at 0.5 when the notification is critical. Close and expand icon buttons (16px) show in the top right corner under the pointer or the keyboard. A click runs the default action; a sideways drag past a third of the card's width dismisses it.
- **Popups:** each card is its own sheet over the sheet edge shadow. It slides in from a third of its width to the right over 400ms and fades in over 250ms (enter), leaves the same way over 250ms (exit), and the rest close up over 250ms. Low urgency stays 3s, normal 5s or the sender's own timeout, critical until dismissed; the pointer over a card holds it. Nothing pops up under Do Not Disturb or while the center is open.
- **Center:** Super+period or a click on the bar's bell. A sheet headed "Notifications" with the count in a `bg1` pill, the Do Not Disturb icon button and a neutral "Clear all" pill; under Do Not Disturb a `red` line says "Do Not Disturb is on: nothing pops up."; then the cards on `bg1` at 0.55, 8px apart, newest first. Empty, a 40px `grey0` bell over "No notifications" in `grey2`, centered. It slides 24px in from the right over 400ms and fades in over 250ms, and closes at once: each open must map it afresh to take the keyboard (#91).
- **Keys:** j/k, the arrows or Ctrl+n/p move the selected card, gg/Home and G/End jump, Enter runs its default action and closes, x, d or Delete dismiss it, Shift+C clears all, `<` or `,` and `>` or `.` press its first two pills and 3 to 9 the rest (the hints show on the selected card), q or Esc close.
- **Bell:** on the bar, `grey2` with nothing kept, `orange` with the count while notifications wait, `red` under Do Not Disturb; a right click toggles Do Not Disturb.

### Launcher

rofi: a `bg0` window, 42em wide with 12px corners and a 1px `bg2` edge; the input bar and rows at 8px, with a dashed `bg2` line between them. The selected row is solid `fg` with `bg_dim` text (8.62:1); active entries are `blue` and urgent ones `red`; the placeholder and the match counts are `grey2`.

### Keycaps

- **Hangul hint:** 56px keys on a 62px pitch, `bg2` at 0.94 with a `bg3` edge, a 3px `bg_dim` lip and 8px corners. The jamo is in Hangul type; the Latin letter sits in the corner in Mono 10px bold `grey1`, the shifted jamo in `grey2`. A pressed key lights at once in solid `green` with `bg_dim` jamo and fades back over 220ms on release. F and J carry a 20×3px pill bump.
- **Keybind sheet:** caps are Mono 11px bold `fg` on a `bg3` to `bg2` gradient with a 2px lip and 8px corners; the held prefix cap fills `blue` with `bg_dim` text. Keys on the keyboard map are 8px keys with a 3px lip in three strengths: unbound, `bg0` with a `grey2` legend; bound under another modifier, raised to `bg1` with an `fg` legend; bound under what is held now, solid `blue`. A held modifier is `bg3`, and the selected key is outlined in `fg`. Under the map, what the key does now is `fg` and what it does with another modifier `grey2`. The mode chips above it are 8px buttons, on the `blue` tint when checked.

### Polkit Prompt

The signature surface (`home/hypr/.config/quickshell/polkit/`), an approval sheet that belongs to the camera.

- **Composition:** a 10px lens dot at the top edge, centered under the IR camera; a shield glyph in a 22px slot beside the message (Headline) with the action id beneath (Mono, `grey2`); a status line in the same columns; the password field and Cancel and Approve once PAM asks.
- **Lens:** takes the state's tone (`blue` looking, `yellow` fallback, `red` after a wrong password, `green` approved) with a 180ms color change, and breathes from full to 0.25 opacity and back, 750ms each way (InOutSine), while PAM works.
- **Motion:** the sheet drops in over 360ms (OutExpo) and retracts over 220ms (InCubic); its height follows content over 240ms (OutExpo). A wrong password shakes it sideways in five steps over about 280ms.
- **Approval:** the buttons go, the sheet closes up around the green "Approved" band, holds 700ms, and retracts.

### Lock Screen

hyprlock: a blurred screenshot of the session (3 passes, size 8, brightness 0.6) behind a clock in `fg`, the date in `grey2` and a greeting in `green`; a 300×50 input with a 3px `green` outline on `bg1` and 12px corners, whose `check_color` is `green`, `fail_color` `red` and `capslock_color` `yellow`; battery and network in the top right.

**Drift.** The hangul hint's Latin letters measure 2.98:1 and its shifted jamo 3.97:1 on their keys. hyprlock shows the battery in `green` at any charge, where the bar keeps `green` for charging.

### Component Rules

**The Second Press Rule.** A destructive session action arms on the first press, shows that it is armed in `red` ("Again?"), and fires only on a second press within 3 seconds.

**The Visible Approval Rule.** A face approval stays on screen as a green "Approved" band for 700ms before the sheet retracts, so a request the owner did not expect cannot pass unseen.

**The One Wash Rule.** On the shell base, hover, press and the keyboard's row are one state layer in the control's tint; no control brightens its fill. A ring is for one case only: the keyboard's stop on a sheet walked in two directions (quick settings, the tray's grid) wears Material 3's focus indicator, a 2px `blue` ring 3px outside the control, since a wash alone doesn't show where you are in a grid.

**The Calm Motion Rule.** Shell motion takes `Theme.motion` through `Anim` and `CAnim`: 150ms for washes, color and small fades, 250ms for moves and resizes inside a surface, 400ms for a surface arriving; the `enter` curve for what arrives, `exit` for what leaves, `standard` for what moves within the screen. Nothing overshoots or bounces.

## Do's and Don'ts

### Do

- **Do** read colors at runtime from `home/hypr/.config/hypr/themes/foliage.conf` by Everforest's token names, and fall back to neutral grays when it is missing (`Colors.qml`).
- **Do** build a shell surface from `Theme.qml` and its primitives: a `Sheet` (`bg_dim` at 0.985, the `blue` edge at 0.18, the sheet edge shadow, 12px corners, 12px padding) with controls 8px apart.
- **Do** make a shell button a tonal pill or an icon button over a `StateLayer`. A surface not yet moved keeps its `bg0` controls, `bg1` hover and `fg`-and-`blue` focus ring until it moves whole; don't mix the two on one surface.
- **Do** show a control's state as a tint of its tone (0.12 to 0.2 behind, 0.45 to 0.55 on the edge), and keep its words `fg` unless the tone holds 4.5:1 on its band.
- **Do** set words in Adwaita Sans (15px semibold headline, 13px body, 12px control labels, 11px labels), icons in Material Symbols Rounded, and identifiers and key names in JetBrainsMono Nerd Font.
- **Do** keep each state hue to its meaning: `blue` focus and the action on offer, `orange` worth a glance, `red` act now, `green` charging or approved, `purple` special, `yellow` caution.
- **Do** give a new translucent layer namespace a blur rule with `ignore_alpha 0.5`, and a layer that animates itself `no_anim`.
- **Do** keep a corner square where a surface meets a screen edge.
- **Do** animate through `Anim` and `CAnim` on `Theme.motion`'s durations and curves.

### Don't

- **Don't** write a hex in surface code or in a fallback; name the token.
- **Don't** set text that has to be read in `grey1` or `grey0` (4.49:1 and 3.74:1 on `bg_dim`); `grey0` is for off.
- **Don't** add radii outside 12px, 8px and pill.
- **Don't** type a radius, duration or easing curve in shell QML; take it from `Theme.qml`.
- **Don't** theme the GUI apps in `docs/gui-app-colors.md` (Firefox, Betterbird, Obsidian, Discord, Chrome, stock GTK and Qt apps, Spotify); they keep their own colors.
