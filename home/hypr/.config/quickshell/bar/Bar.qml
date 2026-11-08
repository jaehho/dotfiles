// One screen's bar: a full-width layer surface that reserves 40px at the
// top edge, as waybar did (a 34px bar under a 6px margin), and is taller
// than that so the center island can open into the player, the right
// island into quick settings, and menus and tips can drop below the
// islands, without resizing the surface or moving a window. The input
// mask is the islands and an open menu, so the rest of the surface lets
// the pointer through to the windows under it.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var colors
    property var player: null
    property bool open: false
    // The right island's quick settings, the page it shows, and whether
    // the keyboard opened it.
    property bool quickOpen: false
    property string quickPage: "main"
    property bool quickKeys: false
    // The control whose tip shows, after half a second's hover.
    property Item tipFor: null
    readonly property bool menuOpen: menu.open
    readonly property alias rightIsland: rightSide

    signal toggleRequested
    signal closeRequested
    // A page opens quick settings there (or closes it if it shows that
    // page already); "" opens or closes it as it is.
    signal quickRequested(string page)
    signal pageRequested(string page)

    function openQuick(page) {
        bar.quickRequested(page);
    }

    function pageQuick(page) {
        bar.pageRequested(page);
    }

    function hint(item) {
        tipDelay.target = item;
        tipDelay.restart();
    }

    function unhint(item) {
        if (tipDelay.target === item)
            tipDelay.stop();
        if (bar.tipFor === item)
            bar.tipFor = null;
    }

    // A second click on the control that opened the menu closes it.
    function toggleMenu(anchor, entries) {
        if (menu.anchor === anchor) {
            menu.close();
            return;
        }
        bar.closeRequested();
        menu.show(anchor, entries, null);
    }

    function openTrayMenu(anchor, handle) {
        bar.closeRequested();
        menu.show(anchor, [], handle);
    }

    onOpenChanged: if (open)
        menu.close()
    onQuickOpenChanged: if (quickOpen)
        menu.close()
    onVisibleChanged: if (!visible)
        menu.close()

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 640
    exclusiveZone: 40
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "bar"
    // The keyboard only while an island or a menu is open, which the
    // owner asked for by opening it.
    WlrLayershell.keyboardFocus: bar.open || bar.quickOpen || bar.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: leftSide

        Region {
            item: center
        }

        Region {
            item: rightSide
        }

        Region {
            item: bar.menuOpen ? menu : null
        }
    }

    // A click anywhere else clears the grab, which closes the island or
    // the menu and gives the keyboard back to the window that had it.
    HyprlandFocusGrab {
        windows: [bar]
        active: bar.open || bar.quickOpen || bar.menuOpen
        onCleared: {
            bar.closeRequested();
            menu.close();
        }
    }

    Timer {
        id: tipDelay
        property Item target: null
        interval: 500
        onTriggered: bar.tipFor = target
    }

    // Waybar's islands sat 4px inside its 34px bar, 8px from either edge.
    // They keep 8px apart at rest: the right island holds its width, the
    // center island cuts its track to fit, and the left island its title
    // (and as a last resort clips). An open sheet overlaps its neighbours
    // instead of squeezing them.
    LeftIsland {
        id: leftSide
        x: 8
        y: 10
        bar: bar
        limit: (bar.width - center.restWidth) / 2 - 8
        width: Math.min(implicitWidth, limit - x)
        clip: true
    }

    CenterIsland {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        colors: bar.colors
        player: bar.player
        open: bar.open
        room: bar.width / 2 - rightSide.restWidth - 16
        onToggleRequested: bar.toggleRequested()
        onCloseRequested: bar.closeRequested()
    }

    RightIsland {
        id: rightSide
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 10
        bar: bar
        open: bar.quickOpen
        page: bar.quickPage
        keys: bar.quickKeys
    }

    // Tips give way to an open sheet or menu.
    Tip {
        bar: bar
        visible: opacity > 0 && !bar.open && !bar.quickOpen && !bar.menuOpen
    }

    BarMenu {
        id: menu
        bar: bar
    }
}
