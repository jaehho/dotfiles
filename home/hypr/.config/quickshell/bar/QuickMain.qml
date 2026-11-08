// The quick settings sheet's first page: the volume and brightness
// levels, tiles for Wi-Fi, Bluetooth and sound, then from
// hypr-settings-menu's table its toggles, what it opens, and the session
// row, whose Log out, Reboot and Shut down take a second press (DESIGN.md,
// the Second Press Rule).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire

Column {
    id: main

    required property var sheet
    readonly property var colors: sheet.colors
    readonly property real third: (width - 16) / 3
    readonly property real half: (width - 8) / 2
    // The session entry a first press armed, by id.
    property string armed: ""

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var station: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var linked: adapter ? adapter.devices.values.filter(d => d.connected) : []
    // Their tools are a row away on the Wi-Fi, Bluetooth and Sound pages.
    readonly property var paged: ["wifi", "bluetooth", "audio"]

    // Where the keyboard starts, and where it lands back from a page.
    function first() {
        return volume.enabled ? volume : wifiTile;
    }

    function tileFor(page) {
        return page === "wifi" ? wifiTile : page === "bluetooth" ? bluetoothTile : page === "sound" ? soundTile : null;
    }

    // The ramp glyph for a 0..1 level, as the bar picks it.
    function pick(glyphs, level) {
        return glyphs[Math.max(0, Math.min(glyphs.length - 1, Math.floor(level * glyphs.length)))];
    }

    function wifiGlyph(strength) {
        return main.pick([0xf091f, 0xf0922, 0xf0925, 0xf0928], strength);
    }

    function session(entry) {
        if (entry.confirm && main.armed !== entry.id) {
            main.armed = entry.id;
            armTimer.restart();
            return;
        }
        main.armed = "";
        main.sheet.session(entry.id);
    }

    // hypr-level's scale: raw = max * p^4, never below 1, which keeps
    // the panel lit at the bottom of the track.
    function setLight(level) {
        if (lightSet.running) {
            lightSet.wanted = level;
            return;
        }
        const raw = Math.max(1, Math.round(light.max * Math.pow(level, 4)));
        lightSet.command = ["brightnessctl", "-q", "set", String(raw)];
        lightSet.running = true;
    }

    spacing: 14

    Connections {
        target: main.sheet
        function onOpenChanged() {
            main.armed = "";
        }
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: main.armed = ""
    }

    Column {
        width: parent.width
        spacing: 4

        QuickSlider {
            id: volume

            readonly property bool muted: main.sink?.audio?.muted ?? false
            readonly property real level: main.sink?.audio?.volume ?? 0
            readonly property bool bluetooth: (main.sink?.properties["device.api"] ?? "") === "bluez5"

            function mute() {
                if (main.sink?.audio)
                    main.sink.audio.muted = !muted;
            }

            sheet: main.sheet
            width: parent.width
            enabled: main.sink !== null
            value: level
            off: muted
            glyph: muted ? 0xf075f : bluetooth ? 0xf00b0 : main.pick([0xf057f, 0xf0580, 0xf057e], level)
            label: muted && !held ? "Muted" : `${Math.round((held ? dragged : level) * 100)}%`
            onMoved: value => {
                if (!main.sink?.audio)
                    return;
                main.sink.audio.volume = value;
                if (value > 0)
                    main.sink.audio.muted = false;
            }
            onStepped: steps => main.sheet.level("volume", steps)
            onGlyphClicked: mute()
            onActivated: mute()

            PwObjectTracker {
                objects: [main.sink]
            }
        }

        // The raw backlight, as the bar reads it: sysfs sends no change
        // events, so it is read each second while the sheet is open.
        QuickSlider {
            id: light

            property string device: ""
            readonly property real raw: Number(now.text())
            readonly property real max: Number(top.text())
            readonly property real level: max > 0 ? Math.pow(raw / max, 0.25) : 0

            sheet: main.sheet
            width: parent.width
            visible: device !== ""
            value: level
            glyph: main.pick([0xf00de, 0xf00df, 0xf00e0], level)
            label: `${Math.round((held ? dragged : level) * 100)}%`
            onMoved: value => main.setLight(value)
            onStepped: steps => main.sheet.level("brightness", steps)

            Process {
                running: true
                command: ["ls", "/sys/class/backlight"]
                stdout: SplitParser {
                    onRead: name => {
                        if (light.device === "")
                            light.device = name;
                    }
                }
            }

            FileView {
                id: now
                path: light.device ? `/sys/class/backlight/${light.device}/brightness` : ""
            }

            FileView {
                id: top
                path: light.device ? `/sys/class/backlight/${light.device}/max_brightness` : ""
            }

            Timer {
                running: light.device !== "" && main.sheet.open
                interval: 1000
                repeat: true
                onTriggered: now.reload()
            }

            // One brightnessctl at a time; a drag keeps only its latest
            // level for the next.
            Process {
                id: lightSet
                property real wanted: -1
                onExited: {
                    now.reload();
                    const level = wanted;
                    wanted = -1;
                    if (level >= 0)
                        main.setLight(level);
                }
            }
        }
    }

    Row {
        spacing: 8

        QuickTile {
            id: wifiTile
            sheet: main.sheet
            width: main.third
            more: true
            off: !Networking.wifiEnabled || main.wifiDevice === null
            icon: String.fromCodePoint(off ? 0xf05aa : main.station ? main.wifiGlyph(main.station.signalStrength) : 0xf092f)
            name: "Wi-Fi"
            detail: main.wifiDevice === null ? "No device" : !Networking.wifiEnabled ? "Off" : main.station?.name ?? "Not connected"
            onActivated: main.sheet.pageRequested("wifi")
        }

        QuickTile {
            id: bluetoothTile
            sheet: main.sheet
            width: main.third
            more: true
            off: !main.adapter || !main.adapter.enabled
            icon: String.fromCodePoint(off ? 0xf00b2 : main.linked.length > 0 ? 0xf00b1 : 0xf00af)
            name: "Bluetooth"
            detail: !main.adapter ? "No adapter" : !main.adapter.enabled ? "Off" : main.linked.length === 1 ? main.linked[0].name : main.linked.length > 1 ? `${main.linked.length} connected` : "On"
            onActivated: main.sheet.pageRequested("bluetooth")
        }

        QuickTile {
            id: soundTile
            sheet: main.sheet
            width: main.third
            more: true
            icon: String.fromCodePoint(volume.bluetooth ? 0xf00b0 : 0xf04c3)
            name: "Sound"
            detail: main.sink ? main.sink.nickname || main.sink.description || main.sink.name : "No output"
            onActivated: main.sheet.pageRequested("sound")
        }
    }

    Grid {
        columns: 3
        spacing: 8
        visible: toggles.count > 0

        Repeater {
            id: toggles
            model: main.sheet.entries.filter(entry => entry.kind === "toggle" || entry.kind === "cycle")

            QuickTile {
                id: toggle

                required property var modelData
                readonly property var reading: main.sheet.stateOf(modelData)

                sheet: main.sheet
                width: main.third
                enabled: reading !== null
                on: modelData.kind === "toggle" && reading === true
                icon: modelData.icon
                name: modelData.label
                detail: reading === null ? "Unavailable" : modelData.kind === "toggle" ? (reading ? "On" : "Off") : String(reading).replace(/-/g, " ").replace(/^./, c => c.toUpperCase())
                onActivated: main.sheet.toggle(modelData)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 6
        visible: rows.count > 0

        Line {
            x: 2
            size: 11
            weight: Font.Bold
            font.capitalization: Font.AllUppercase
            text: "Open"
            color: main.colors.grey2
        }

        Grid {
            columns: 2
            spacing: 8

            Repeater {
                id: rows
                model: main.sheet.entries.filter(entry => entry.kind === "open" && !main.paged.includes(entry.id))

                QuickControl {
                    id: row

                    required property var modelData

                    sheet: main.sheet
                    width: main.half
                    height: 30
                    onActivated: main.sheet.launch(modelData.id)

                    Row {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Line {
                            anchors.verticalCenter: parent.verticalCenter
                            mono: true
                            size: 15
                            text: row.modelData.icon
                            color: main.colors.fg
                        }

                        Line {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: main.colors.fg
                        }
                    }
                }
            }
        }
    }

    Row {
        spacing: 8
        visible: sessions.count > 0

        Repeater {
            id: sessions
            model: main.sheet.entries.filter(entry => entry.kind === "session")

            QuickControl {
                id: button

                required property var modelData

                sheet: main.sheet
                width: (main.width - 8 * (sessions.count - 1)) / sessions.count
                height: 50
                armed: main.armed === modelData.id
                onActivated: main.session(modelData)

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Line {
                        anchors.horizontalCenter: parent.horizontalCenter
                        mono: true
                        size: 17
                        text: button.modelData.icon
                        color: main.colors.fg
                    }

                    Line {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 11
                        text: button.armed ? "Again?" : button.modelData.label
                        color: button.armed ? main.colors.fg : main.colors.grey2
                    }
                }
            }
        }
    }
}
