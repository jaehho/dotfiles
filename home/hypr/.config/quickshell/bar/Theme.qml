pragma Singleton

// The shell's design tokens (#89). Every surface takes its radii,
// spacing, type, motion and state-layer opacities from here instead of
// typing numbers, so the bar, its sheets and the notifications move and
// look alike. Colors are the foliage palette (Colors.qml); the surface
// roles below are the few ways the shell paints with it.
//
// Motion is Material 3's standard set, calm on purpose: no overshoot.
import QtQuick
import Quickshell

Singleton {
    id: theme

    readonly property Colors colors: Colors {}

    // CLAUDE.md's scale. Rectangle clamps a radius to half its shorter
    // side, so `pill` is round at any size.
    readonly property QtObject radius: QtObject {
        readonly property int control: 8
        readonly property int surface: 12
        readonly property int pill: 1000
    }

    readonly property QtObject space: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
    }

    readonly property QtObject font: QtObject {
        readonly property string sans: "Adwaita Sans"
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string icons: "Material Symbols Rounded"

        readonly property int small: 11
        readonly property int smaller: 12
        readonly property int body: 13
        readonly property int title: 15
        readonly property int large: 17
        readonly property int display: 28
    }

    readonly property QtObject icon: QtObject {
        readonly property int small: 16
        readonly property int normal: 20
        readonly property int large: 24
    }

    // Durations in ms, and Material 3's standard curves as BezierSpline
    // points. Anim.qml and CAnim.qml pick from these by name.
    readonly property QtObject motion: QtObject {
        // State layers, colour, small fades.
        readonly property int fast: 150
        // Moves and resizes inside a surface.
        readonly property int normal: 250
        // A surface entering or leaving.
        readonly property int slow: 400

        // Something moving within the screen.
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        // Something arriving: it slows into place.
        readonly property var enter: [0, 0, 0, 1, 1, 1]
        // Something leaving: it speeds away.
        readonly property var exit: [0.3, 0, 1, 1, 1, 1]
    }

    // How strongly a state layer tints what is under it, as Material 3
    // has them.
    readonly property QtObject state: QtObject {
        readonly property real hover: 0.08
        readonly property real focus: 0.10
        readonly property real press: 0.10
    }

    // The shell's surfaces. glass: the resting islands on the bar.
    // sheet: everything that opens over the windows (dropdowns, the side
    // panels, popups), with `shadow` under it. card: a group inside a
    // sheet. outline: the faint blue edge on glass and sheets.
    readonly property QtObject surface: QtObject {
        readonly property color glass: theme.colors.withAlpha(theme.colors.bg0, 0.88)
        readonly property color sheet: theme.colors.withAlpha(theme.colors.bg_dim, 0.985)
        readonly property color shadow: theme.colors.withAlpha(theme.colors.bg_dim, 0.93)
        readonly property color card: theme.colors.withAlpha(theme.colors.bg1, 0.55)
        readonly property color outline: theme.colors.withAlpha(theme.colors.blue, 0.18)
    }
}
