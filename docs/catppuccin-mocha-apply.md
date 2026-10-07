# Catppuccin Mocha — click-to-apply apps

Desktop chrome, terminal, and CLI tools are already switched via stow. These apps need a one-time pick or a local profile file. Files land at `~/.config/theme/apply-notes/` (stow package `theme`).

## Obsidian (vault `~/Obsidian`)

1. Appearance → Theme → Manage → search **Catppuccin** → install and enable.
2. Style Settings (if installed) → Flavor: **Mocha**, Accent: **Lavender**.

`~/Obsidian/.obsidian/appearance.json` is set to `"theme": "Catppuccin"` once the theme is present under `.obsidian/themes/`.

## Firefox (Developer Edition)

1. Open [catppuccin/firefox](https://github.com/catppuccin/firefox).
2. Pick the **Mocha** + **Lavender** Firefox Color link and accept the add-on prompt.

Profiles are not in this repo; Firefox Color writes into the live profile.

## Discord

1. Use Vencord or BetterDiscord.
2. Copy `discord-mocha.theme.css` into the themes folder, or add
   `@import url("https://catppuccin.github.io/discord/dist/mocha/theme.css");`
   in the QuickCSS / custom CSS editor.
3. Enable **Catppuccin Mocha**.

## Spotify (spicetify)

Done on this machine: theme `catppuccin`, scheme `mocha` (official
[catppuccin/spicetify](https://github.com/catppuccin/spicetify) under
`~/.config/spicetify/Themes/catppuccin`).

Update Spicetify with the package manager (`paru -Syu spicetify-bin`), never
`spicetify update` (it tries to write `/opt/spicetify` and fails). Re-apply with
`spicetify apply` after a theme change.

## Google Chrome

Web Store theme: search **Catppuccin Mocha** (or install from [catppuccin/chrome](https://github.com/catppuccin/chrome)).

## Betterbird / Thunderbird

1. Add-ons → Themes → gear → **Install Add-on From File**.
2. Choose `betterbird-mocha-lavender.xpi` from the apply-notes directory.

## GTK / Kvantum / Qt

- Kvantum: theme is stowed to `~/.config/Kvantum/catppuccin-mocha-lavender/`. Select it in Kvantum Manager.
- qt5ct: color scheme `catppuccin-mocha-lavender` is under `~/.config/qt5ct/colors/`.
- GTK has no active official port; leave Adwaita or set a dark preference.

## Not themed

visidata, thunar, qalculate, hyprpaper have no official port and keep defaults.
