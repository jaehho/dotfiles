// The session's lock screen (#89), which replaced hyprlock: version A,
// "Lens", of the lock screen designs. hypridle's lock_cmd starts it
// through hypr-lock, which falls back to hyprlock if this does not take
// the lock within 3 s. It is its own instance, as the polkit prompt is,
// so the bar can restart under it; one process per lock, gone on unlock.
//
// Two PAM checks (Auth.qml), so face unlock never stands in the PIN's way:
//
// - the PIN goes to the `hyprlock` service, the stack hyprlock used
//   (login's: pam_unix with faillock). The keys reach the field from the
//   first moment, and Enter checks them whatever the camera is doing.
// - face unlock is Howdy alone (pam/face, served from this config), run
//   beside it when the lock takes hold and again on each wake
//   (`qs -c lock ipc call lock wake`, from hypr-lock --wake). It shows
//   only as the lens dot and an icon in the field; a match unlocks, a
//   miss stops quietly.
//
// The tokens and primitives are the bar's files, linked into this config.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool capsLock: false
    property string network: ""
    property string networkIcon: "network_wifi"
    property date now: new Date()
    // hypr-lock waits for this file: the compositor has the lock.
    readonly property string secureFile: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-lock.secure"

    Auth {
        id: auth

        secure: lock.secure
        onReleased: {
            remover.running = true;
            lock.locked = false;
        }
    }

    WlSessionLock {
        id: lock

        locked: true

        onSecureChanged: if (secure)
            marker.setText("1\n")

        WlSessionLockSurface {
            id: surface

            color: Theme.colors.bg_dim

            LockScreen {
                id: view

                anchors.fill: parent
                screen: surface.screen
                typed: auth.buffer.length
                phase: auth.phase
                face: auth.face
                note: auth.note
                capsLock: root.capsLock
                network: root.network
                networkIcon: root.networkIcon
                now: root.now
                onTypedText: text => auth.type(text)
                onErased: all => auth.erase(all)
                onSubmitted: auth.submit()

                Connections {
                    target: auth

                    function onWrongPin() {
                        view.shake();
                    }
                }
            }
        }
    }

    FileView {
        id: marker
        path: root.secureFile
        printErrors: false
    }

    Process {
        id: remover
        command: ["rm", "-f", root.secureFile]
        onExited: Qt.quit()
    }

    IpcHandler {
        target: "lock"

        function wake(): void {
            auth.lookAgain();
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Caps Lock, read as hyprlock read it.
    Process {
        id: caps
        command: ["sh", "-c", "cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.trim() === "1"
        }
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: caps.running = true
    }

    // The active connection, as hyprlock showed it.
    Process {
        id: net
        command: ["nmcli", "-t", "-f", "TYPE,NAME", "connection", "show", "--active"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l !== "" && !l.startsWith("loopback")) ?? "";
                const cut = line.indexOf(":");
                root.network = cut < 0 ? "" : line.slice(cut + 1);
                root.networkIcon = line.includes("ethernet") ? "lan" : "network_wifi";
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: net.running = true
    }
}
