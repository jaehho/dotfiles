# Color preferences

Taste guide for picking colors in UI, charts, and notebooks. Not a palette compiler and not a per-app theme. Read this before choosing or changing a color. Update it when taste changes; leave one-off surface tweaks out.

## Principle

Default is grey. A hue is a state, and each hue has one job. If one hue means two things on the same surface, split the meaning or drop one use.

## Palette

Desktop chrome and terminal/CLI surfaces use **Catppuccin Mocha**. Official ports are vendored under `home/theme` (residual tools) and each app's stow package (kitty, fish, hypr, waybar, rofi, swaync, tmux, nvim, zathura). There is no palette compiler.

Named tokens (official Catppuccin Mocha). Prefer the port's include and these
names. Do not restate hexes in app configs; parse or source the official file.

| token | job |
|---|---|
| text | primary |
| subtext0 | resting |
| overlay0 | off / dim |
| base | bar / island fill |
| mantle | notification and panel cards (opaque) |
| crust | deeper fill / shadow |

## Roles

| role | job | Mocha token | use for |
|---|---|---|---|
| grey | rest, fine, off | text / subtext / overlay / surface | default chrome, muted, inactive |
| blue | you are here | `blue` | focus, active, hover, selection |
| lavender | active window | `lavender` | Hyprland active border (fixed; not a state) |
| pink | overlay / special | `pink` | scratchpad, special workspace, secondary selection |
| peach | worth a glance | `peach` | warning, low battery, mic on, busy, pending |
| red | act now | `red` | critical, urgent, destructive, failure, DND |
| green | good / charging | `green` | charging on desktop; success in charts |

Never spend red on a steady state. Green is not decoration.

The active-window border is fixed lavender. It is the one decorative accent on the desktop and it never signals a state. (The earlier wallpaper-hue `hypr-accent` exception is retired.)

## Surfaces

| surface | follow |
|---|---|
| Desktop chrome (waybar, swaync, rofi, tmux, hypr, kitty) | Roles and Mocha greys. Prefer the official Catppuccin port for that app. |
| Charts, figures, notebooks | Grey for context and for series that are not the point. One accent marks the point. Peach and red only for thresholds or failure. Categorical series stay in a quiet ramp; do not spend state hues on decoration. |
| Project UIs | Same roles for focus / warn / critical states. Brand and logo colors stay as the brand defines them. |
| Syntax, terminal ANSI, editor themes | Follow the official Catppuccin port for that app (Mocha). If none exists, leave the tool default. |

## Updating

Edit the role table or Mocha tokens when taste itself changes. Git history is the log. Do not generate configs from this file.
