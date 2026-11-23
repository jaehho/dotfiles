pragma ComponentBehavior: Bound

// The share menu (#89), which replaced rofi's: one list over the channels
// that already exist. Taildrop sends a file or the clipboard to another
// tailnet device (taildrop-send does the sending; this sheet picks the
// device, skipping the page when only one is online), and a QR code puts
// the clipboard's text on a phone without moving a file at all, drawn
// here by qrencode.
//
// j/k or the arrows move, 1 to 9 pick, Enter or Space does it, Esc,
// q or Backspace go back a page, then close, and Super alone says
// `superPressed`, so a Super chord closes the sheet first.
import QtQuick
import Quickshell
import Quickshell.Io

Sheet {
    id: sheet

    property bool open: false
    // main | to | qr
    property string page: "main"
    // What a Taildrop send carries: "file" or "clip".
    property string carry: ""
    // [{ name, os }], the devices Taildrop can reach now.
    property var targets: []
    property bool targetsRead: false
    property int current: 0
    // The QR code's image, or why there is none.
    property string qrImage: ""
    property string qrNote: ""

    readonly property var actions: [
        {
            icon: "upload_file",
            name: "Send a file",
            note: "Taildrop",
            run: () => sheet.send("file")
        },
        {
            icon: "content_paste_go",
            name: "Send the clipboard",
            note: "Taildrop",
            run: () => sheet.send("clip")
        },
        {
            icon: "qr_code_2",
            name: "Show the clipboard as a QR code",
            note: "",
            run: () => sheet.showQr()
        }
    ]
    readonly property var rows: page === "main" ? actions : page === "to" ? targets.map(t => ({
                icon: sheet.iconFor(t.os),
                name: t.name,
                note: t.os,
                run: () => sheet.sendTo(t.name)
            })) : []
    readonly property string title: page === "to" ? (carry === "clip" ? "Send the clipboard to" : "Send a file to") : page === "qr" ? "The clipboard as a QR code" : "Share"
    readonly property string qrPath: Quickshell.env("XDG_RUNTIME_DIR") + "/bar-share-qr.png"
    // The sheet has the keyboard.
    readonly property bool typing: keys.activeFocus

    signal closeRequested
    signal superPressed

    implicitHeight: column.implicitHeight + Theme.space.md * 2

    function iconFor(os) {
        if (os === "iOS" || os === "android")
            return "smartphone";
        if (os === "macOS")
            return "laptop_mac";
        if (os === "windows")
            return "desktop_windows";
        return "computer";
    }

    function send(what) {
        sheet.carry = what;
        sheet.current = 0;
        if (sheet.targets.length === 1) {
            sheet.sendTo(sheet.targets[0].name);
            return;
        }
        sheet.page = "to";
    }

    function sendTo(name) {
        Quickshell.execDetached(["taildrop-send", "--to", name].concat(sheet.carry === "clip" ? ["--clip"] : []));
        sheet.closeRequested();
    }

    function showQr() {
        sheet.page = "qr";
        sheet.qrImage = "";
        sheet.qrNote = "";
        qr.running = false;
        qr.running = true;
    }

    function back() {
        if (sheet.page === "main") {
            sheet.closeRequested();
            return;
        }
        sheet.page = "main";
        sheet.current = 0;
    }

    function move(by) {
        if (sheet.rows.length > 0)
            sheet.current = (sheet.current + by + sheet.rows.length) % sheet.rows.length;
    }

    onOpenChanged: {
        if (!open)
            return;
        sheet.page = "main";
        sheet.current = 0;
        sheet.targetsRead = false;
        lister.running = false;
        lister.running = true;
        keys.forceActiveFocus();
    }

    // The devices Taildrop can send to, and what each runs (column 4 of
    // `tailscale status`).
    Process {
        id: lister
        command: ["sh", "-c", "tailscale file cp --targets 2>/dev/null; echo ---; tailscale status 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const [targetsText, statusText] = text.split("\n---\n");
                const os = {};
                for (const line of (statusText ?? "").split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length >= 4)
                        os[f[1]] = f[3];
                }
                sheet.targets = (targetsText ?? "").split("\n").map(l => l.split("\t")).filter(f => f.length === 2 && f[1] !== "").map(f => ({
                            name: f[1],
                            os: os[f[1]] ?? ""
                        }));
                sheet.targetsRead = true;
            }
        }
    }

    // The clipboard's text as a QR code, parchment on dark, or why not.
    Process {
        id: qr
        command: ["sh", "-c", `wl-paste --list-types 2>/dev/null | grep -q '^text/' || exit 3
t=$(wl-paste --no-newline 2>/dev/null)
[ -n "$t" ] || exit 3
[ \${#t} -le 2000 ] || exit 4
printf '%s' "$t" | qrencode -t PNG -s 8 -m 2 --foreground=${String(Theme.colors.bg_dim).slice(1, 7)} --background=${String(Theme.colors.fg).slice(1, 7)} -o "$1"`, "sh", sheet.qrPath]

        onExited: code => {
            if (code === 0)
                sheet.qrImage = "file://" + sheet.qrPath + "?" + Date.now();
            else if (code === 3)
                sheet.qrNote = "The clipboard holds no text.";
            else if (code === 4)
                sheet.qrNote = "The clipboard's text is too long for a QR code (over 2000 characters).";
            else
                sheet.qrNote = "qrencode couldn't draw it.";
        }
    }

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            const key = event.key;
            if (key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta) {
                sheet.superPressed();
                return;
            }
            if (key === Qt.Key_Escape || key === Qt.Key_Q || key === Qt.Key_Backspace)
                sheet.back();
            else if (key === Qt.Key_Down || key === Qt.Key_J || key === Qt.Key_Tab)
                sheet.move(1);
            else if (key === Qt.Key_Up || key === Qt.Key_K || key === Qt.Key_Backtab)
                sheet.move(-1);
            else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
                sheet.rows[sheet.current]?.run();
            else if (key >= Qt.Key_1 && key <= Qt.Key_9 && key - Qt.Key_1 < sheet.rows.length)
                sheet.rows[key - Qt.Key_1].run();
            else
                return;
            event.accepted = true;
        }
    }

    Column {
        id: column

        x: Theme.space.md
        y: Theme.space.md
        width: parent.width - Theme.space.md * 2
        spacing: Theme.space.sm

        // The page's name, with the way back on the inner pages.
        Row {
            height: 32
            spacing: Theme.space.xs

            IconButton {
                visible: sheet.page !== "main"
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_back"
                implicitWidth: 32
                implicitHeight: 32
                onClicked: sheet.back()
            }

            Line {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: sheet.page === "main" ? Theme.space.md : 0
                text: sheet.title
                size: Theme.font.title
                weight: Font.DemiBold
                color: Theme.colors.fg
            }
        }

        Repeater {
            model: sheet.rows

            Item {
                id: row

                required property var modelData
                required property int index

                width: column.width
                height: 36

                StateLayer {
                    radius: Theme.radius.pill
                    selected: row.index === sheet.current
                    onClicked: () => row.modelData.run()
                }

                Icon {
                    x: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.icon
                    color: Theme.colors.fg
                }

                Line {
                    x: Theme.space.md * 2 + Theme.icon.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: Theme.colors.fg
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.sm

                    Line {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: row.modelData.note
                        size: Theme.font.small
                        color: Theme.colors.grey2
                    }

                    Line {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.index < 9
                        text: String(row.index + 1)
                        mono: true
                        size: Theme.font.small
                        color: Theme.colors.grey2
                    }
                }
            }
        }

        Line {
            visible: sheet.page === "to" && sheet.targetsRead && sheet.targets.length === 0
            x: Theme.space.md
            text: "No Taildrop device is online."
            color: Theme.colors.grey2
        }

        // The QR page: the code on a card, or why there is none.
        Rectangle {
            visible: sheet.page === "qr"
            width: column.width
            height: 296
            radius: Theme.radius.surface
            color: Theme.surface.card

            Image {
                visible: sheet.qrImage !== ""
                anchors.centerIn: parent
                width: 264
                height: 264
                source: sheet.qrImage
                cache: false
                smooth: false
                fillMode: Image.PreserveAspectFit
            }

            Line {
                visible: sheet.qrImage === ""
                anchors.centerIn: parent
                width: parent.width - Theme.space.lg * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: sheet.qrNote !== "" ? sheet.qrNote : "…"
                color: Theme.colors.grey2
            }
        }

        Line {
            x: Theme.space.md
            size: Theme.font.small
            color: Theme.colors.grey2
            text: sheet.page === "qr" ? "Scan it with the phone's camera  ·  Esc goes back" : "Enter does it  ·  1–9 pick  ·  Esc " + (sheet.page === "main" ? "closes" : "goes back")
        }
    }
}
