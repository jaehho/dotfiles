// Everforest Dark Medium for the bar, read at runtime from the palette
// file hyprlock, the hypr-* panels and the polkit prompt share. Token
// names are Everforest's; the hexes live only in themes/foliage.conf.
// The fallbacks keep the bar legible if that file is missing; they are
// neutral stand-ins, not palette values.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: colors

    readonly property var tokens: colors.parse(file.text())

    readonly property color bg_dim: tokens.bg_dim ?? "#1c1c1c"
    readonly property color bg0: tokens.bg0 ?? "#262626"
    readonly property color bg1: tokens.bg1 ?? "#303030"
    readonly property color bg2: tokens.bg2 ?? "#3a3a3a"
    readonly property color bg3: tokens.bg3 ?? "#444444"
    readonly property color fg: tokens.fg ?? "#e0e0e0"
    readonly property color grey0: tokens.grey0 ?? "#808080"
    readonly property color grey1: tokens.grey1 ?? "#989898"
    readonly property color grey2: tokens.grey2 ?? "#b0b0b0"
    readonly property color blue: tokens.blue ?? "#80b0e0"
    readonly property color aqua: tokens.aqua ?? "#80c0a0"
    readonly property color green: tokens.green ?? "#a0c080"
    readonly property color orange: tokens.orange ?? "#e09070"
    readonly property color red: tokens.red ?? "#e08080"
    readonly property color purple: tokens.purple ?? "#d0a0c0"

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // One `$name = rgb(rrggbb)` per line, as the file's header promises.
    function parse(text) {
        const out = {};
        for (const raw of text.split("\n")) {
            const m = raw.trim().match(/^\$([a-z0-9_]+)\s*=\s*rgb\(([0-9a-fA-F]{6})\)$/);
            if (m)
                out[m[1]] = "#" + m[2];
        }
        return out;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/hypr/themes/foliage.conf"
        blockLoading: true
    }
}
