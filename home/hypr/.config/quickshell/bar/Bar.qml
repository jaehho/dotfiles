// One screen's bar: a full-width layer surface that reserves 40px at the
// top edge, as waybar did (a 34px bar under a 6px margin), and is taller
// than that so the center island can open into the player, the right
// island into quick settings or the tray, and menus and tips can drop below the
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
    // The tray grid, grown out of the right island under its chevron.
    property bool trayOpen: false
    // Opened by hovering, which takes neither the keyboard nor the
    // grab: it closes when the pointer leaves the island, and a click on
    // what opened it keeps it open (and takes both).
    property bool byHover: false
    // The control whose tip shows, after half a second's hover.
    property Item tipFor: null
    readonly property bool menuOpen: menu.open
    // How long the pointer rests on an island or its glyph before it
    // opens, and how long it may be gone before the sheet closes again.
    readonly property int hoverDelay: 40
    readonly property int leaveDelay: 100
    // Held while a sheet needs the keyboard and the grab.
    readonly property bool holding: (open || quickOpen || menuOpen || trayOpen) && !byHover
    // Where a tip hangs: under the island, however far it has grown.
    readonly property real tipTop: trayOpen ? rightSide.y + rightSide.height + 6 : 42
    readonly property var trayItems: rightSide.attention.trayItems
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
        bar.trayOpen = false;
        bar.byHover = false;
        menu.show(anchor, entries, null);
    }

    // "Spotify", "Bitwarden": a tray item's id less what apps add.
    function trayName(item) {
        const name = item.id.replace(/[-_]?(status_icon|systray_icon|client|tray)[-_]?\d*$/i, "").split(/[-_ ]/)[0];
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // A click on the center island while hover has it open keeps it.
    function toggleCenter() {
        if (open && byHover)
            byHover = false;
        else
            toggleRequested();
    }

    function hoverCenter() {
        if (!hoverFree || open)
            return;
        toggleRequested();
        byHover = true;
    }

    function toggleTray() {
        if (trayOpen && byHover)
            byHover = false;
        else
            trayOpen = !trayOpen;
    }

    // Hover opens over nothing, or over what hover itself opened (the
    // pointer moving from one island or glyph to the next); a sheet
    // that was clicked or keyed open is never taken from its owner.
    // Leaving closes only what hover opened.
    readonly property bool hoverFree: !menuOpen && ((!open && !quickOpen && !trayOpen) || byHover)

    function hoverTray() {
        if (!hoverFree || trayOpen)
            return;
        trayOpen = true;
        byHover = true;
    }

    function hoverQuick() {
        if (!hoverFree || quickOpen)
            return;
        quickRequested("");
        byHover = true;
    }

    function hoverLeft() {
        if (!byHover)
            return;
        trayOpen = false;
        closeRequested();
        byHover = false;
    }

    function openTrayMenu(anchor, handle) {
        bar.closeRequested();
        bar.trayOpen = false;
        bar.byHover = false;
        menu.show(anchor, [], handle);
    }

    // Nothing open, nothing to have been opened by hover.
    function settle() {
        if (!trayOpen && !quickOpen && !open)
            byHover = false;
    }

    onOpenChanged: {
        if (open) {
            menu.close();
            trayOpen = false;
        }
        settle();
    }
    onQuickOpenChanged: {
        if (quickOpen) {
            menu.close();
            trayOpen = false;
        }
        settle();
    }
    onTrayOpenChanged: {
        if (trayOpen) {
            bar.closeRequested();
            menu.close();
        }
        settle();
    }
    onVisibleChanged: if (!visible) {
        menu.close();
        trayOpen = false;
    }

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
    WlrLayershell.keyboardFocus: bar.holding ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
        active: bar.holding
        onCleared: {
            bar.closeRequested();
            bar.trayOpen = false;
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
        bar: bar
        player: bar.player
        open: bar.open
        room: bar.width / 2 - rightSide.restWidth - 16
        onToggleRequested: bar.toggleCenter()
        onHoverRequested: bar.hoverCenter()
        onCloseRequested: bar.closeRequested()
    }

    // Leaving closes what hovering opened, after a moment's grace.
    Timer {
        interval: bar.leaveDelay
        running: bar.byHover && !center.hovered && !rightSide.keepHover
        onTriggered: {
            console.log("hoverLeft: tray", bar.trayOpen, "chevron", rightSide.attention.chevron.hovered, "sheet", rightSide.sheetHovered, "height", rightSide.height);
            bar.hoverLeft();
        }
    }

    RightIsland {
        id: rightSide
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 10
        bar: bar
        open: bar.quickOpen
        trayOpen: bar.trayOpen
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
