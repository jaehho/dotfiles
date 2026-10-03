# Color preferences

Taste guide for picking colors in UI, charts, and notebooks. Not a palette compiler and not a per-app theme. Read this before choosing or changing a color. Update it when taste changes; leave one-off surface tweaks out.

## Principle

Default is grey. A hue is a state, and each hue has one job. If one hue means two things on the same surface, split the meaning or drop one use.

## Roles

| role | job | use for |
|---|---|---|
| grey | rest, fine, off | default chrome, muted, inactive |
| blue | you are here | focus, active, hover, selection |
| pink | overlay / special | scratchpad, special workspace, secondary selection |
| amber | worth a glance | warning, low battery, mic on, busy, pending |
| red | act now | critical, urgent, destructive, failure, DND |
| green | good / charging | charging on desktop; success in charts |

Never spend red on a steady state. Green is not decoration.

## Grey ramp

Current desktop values. Named tool colors (fish `blue`, `brblack`, `yellow`, `green`, `red`) beat invented hexes.

| token | hex | job |
|---|---|---|
| text | `#e8e8e8` | primary |
| subtext | `#b0b0b0` | resting |
| overlay | `#777777` | off / dim |
| base | `#232323` | bar / island fill |
| card | `#202020` | notification and panel cards (opaque) |
| crust | `#111111` | deeper fill / shadow |

## Surfaces

| surface | follow |
|---|---|
| Desktop chrome (waybar, swaync, rofi, tmux, hypr, kitty) | Roles and grey ramp. Prefer upstream defaults when not actively customizing. |
| Charts, figures, notebooks | Grey for context and for series that are not the point. One accent marks the point. Amber and red only for thresholds or failure. Categorical series stay in a quiet ramp; do not spend state hues on decoration. |
| Project UIs | Same roles for focus / warn / critical states. Brand and logo colors stay as the brand defines them. |
| Syntax, terminal ANSI, editor themes | Leave the tool default. Do not recolor for taste. |

## Updating

Edit the role table or grey ramp when taste itself changes. Git history is the log. Do not generate configs from this file.
