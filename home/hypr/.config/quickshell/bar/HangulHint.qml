// The hangul hint (#89), which replaced its GTK4 window: the Korean
// 2-set layout (HangulBoard.qml) at the bottom of the focused screen
// while the focused window types Hangul, gone when it switches back.
// It takes no keyboard and no pointer, so you type and click through it.
//
// hypr-hangul-hint feeds it, as a child of the bar: the layout, fcitx5's
// state, the letter keys going down and up (read from keyd's virtual
// keyboard, only while Hangul is on) and the pointer. Two looks, flipped
// by Ctrl + the AI key (`qs -c bar ipc call hangul dock`) and
// remembered in the old hint's state file:
//
//   overlay  glass floating 56px above the bottom, clearing around the
//            pointer
//   docked   a strip across the bottom that reserves its height, so the
//            windows tile around it as they do around the bar
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: hint

    property var layout: null
    property bool hangul: false
    property var lit: ({})
    // The pointer in global pixels, or null.
    property var cursor: null
    property string mode: "overlay"
    readonly property bool shown: hangul && layout !== null
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"

    // One JSON object per line (hypr-hangul-hint's docstring).
    function take(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (error) {
            return;
        }
        if (message.layout)
            hint.layout = message.layout;
        if (message.hangul !== undefined) {
            hint.hangul = message.hangul;
            if (!message.hangul) {
                hint.lit = {};
                hint.cursor = null;
            }
        }
        if (message.key) {
            const next = Object.assign({}, hint.lit);
            if (message.down)
                next[message.key] = true;
            else
                delete next[message.key];
            hint.lit = next;
        }
        if (message.cursor)
            hint.cursor = message.cursor;
    }

    function dock() {
        hint.mode = hint.mode === "docked" ? "overlay" : "docked";
        store.setText(hint.mode + "\n");
    }

    // The feed dies with the bar (pdeathsig), and comes back if it dies
    // on its own.
    Process {
        id: feed
        command: ["setpriv", "--pdeathsig", "TERM", Quickshell.env("HOME") + "/.local/bin/hypr-hangul-hint"]
        running: true

        stdout: SplitParser {
            onRead: line => hint.take(line)
        }

        onExited: code => {
            console.warn("hangul hint feed exited:", code);
            hint.hangul = false;
            again.start();
        }
    }

    Timer {
        id: again
        interval: 5000
        onTriggered: feed.running = true
    }

    FileView {
        id: store
        path: hint.stateDir + "/hypr-hangul-hint/mode"
        printErrors: false
        onLoaded: {
            const saved = text().trim();
            if (saved === "overlay" || saved === "docked")
                hint.mode = saved;
        }
    }

    IpcHandler {
        target: "hangul"

        function dock(): void {
            hint.dock();
        }
    }

    LazyLoader {
        active: hint.shown && hint.mode === "overlay"

        PanelWindow {
            id: overlay

            // Where the layer sits, in global pixels: centered at the
            // bottom, 56px up.
            readonly property real originX: (screen?.x ?? 0) + Math.round(((screen?.width ?? 0) - width) / 2)
            readonly property real originY: (screen?.y ?? 0) + (screen?.height ?? 0) - 56 - height

            screen: hint.screen
            anchors.bottom: true
            margins.bottom: 56
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: board.implicitWidth
            implicitHeight: board.implicitHeight
            color: "transparent"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hangul-hint"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            HangulBoard {
                id: board

                anchors.fill: parent
                layout: hint.layout
                lit: hint.lit
                // The pointer in the board's pixels while it is within the
                // clear patch's reach of it.
                hole: {
                    const c = hint.cursor;
                    if (!c)
                        return null;
                    const x = c[0] - overlay.originX;
                    const y = c[1] - overlay.originY;
                    const r = holeRadius;
                    return x > -r && x < width + r && y > -r && y < height + r ? [x, y] : null;
                }
            }
        }
    }

    LazyLoader {
        active: hint.shown && hint.mode === "docked"

        PanelWindow {
            screen: hint.screen
            anchors {
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Auto
            implicitHeight: docked.implicitHeight + 1
            color: Theme.colors.bg_dim
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "hangul-hint"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // The strip's top edge.
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.colors.bg2
            }

            HangulBoard {
                id: docked

                anchors.horizontalCenter: parent.horizontalCenter
                y: 1
                width: implicitWidth
                height: implicitHeight
                docked: true
                layout: hint.layout
                lit: hint.lit
            }
        }
    }
}
