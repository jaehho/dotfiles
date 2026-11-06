// One screen's bar: a full-width layer surface that reserves 40px at the
// top edge, as waybar did (a 34px bar under a 6px margin), and is taller
// than that so the center island can open into a sheet without resizing
// the surface or moving a window. The input mask is the island, so the
// rest of the surface lets the pointer through to the windows under it.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var colors
    property var player: null
    property bool open: false

    signal toggleRequested
    signal closeRequested

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 360
    exclusiveZone: 40
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "bar"
    // The keyboard only while the island is open, which the owner asked
    // for by opening it.
    WlrLayershell.keyboardFocus: bar.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: center
    }

    // A click anywhere else clears the grab, which closes the island and
    // gives the keyboard back to the window that had it.
    HyprlandFocusGrab {
        windows: [bar]
        active: bar.open
        onCleared: bar.closeRequested()
    }

    // Waybar's islands sat 4px inside its 34px bar.
    CenterIsland {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        colors: bar.colors
        player: bar.player
        open: bar.open
        onToggleRequested: bar.toggleRequested()
        onCloseRequested: bar.closeRequested()
    }
}
