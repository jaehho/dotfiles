// What the machine puts out: screen brightness and the speaker, as
// waybar's backlight and pulseaudio modules. The wheel steps both through
// hypr-level, the same perceptual steps and OSD the keys use. A click
// mutes the default sink; a right click opens its quick settings.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Row {
    id: output

    required property var bar
    readonly property var colors: bar.colors
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    function step(what, steps) {
        for (let i = 0; i < Math.abs(steps); i++)
            Quickshell.execDetached([output.bin + "hypr-level", what, steps > 0 ? "up" : "down"]);
    }

    // The ramp glyph for a 0..1 level, as waybar's format-icons picked it.
    function pick(glyphs, level) {
        return String.fromCodePoint(glyphs[Math.max(0, Math.min(glyphs.length - 1, Math.floor(level * glyphs.length)))]);
    }

    BarButton {
        id: light

        // The raw scale, as waybar's percent was; sysfs sends no change
        // events for it, so it is read each second.
        property string device: ""
        readonly property real level: Number(max.text()) > 0 ? Number(now.text()) / Number(max.text()) : 0

        visible: device !== ""
        bar: output.bar
        text: output.pick([0xf00de, 0xf00df, 0xf00e0], level)
        tip: `Brightness ${Math.round(level * 100)}%`
        onScrolled: steps => output.step("brightness", steps)

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
            id: max
            path: light.device ? `/sys/class/backlight/${light.device}/max_brightness` : ""
        }

        Timer {
            running: light.device !== ""
            interval: 1000
            repeat: true
            onTriggered: now.reload()
        }
    }

    BarButton {
        id: speaker

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property bool muted: sink?.audio?.muted ?? false
        readonly property real level: sink?.audio?.volume ?? 0
        readonly property bool bluetooth: (sink?.properties["device.api"] ?? "") === "bluez5" || (sink?.name ?? "").startsWith("bluez_output")

        bar: output.bar
        text: muted ? String.fromCodePoint(0xf075f) : bluetooth ? String.fromCodePoint(0xf00b0) : output.pick([0xf057f, 0xf0580, 0xf057e], level)
        tint: muted ? output.colors.grey0 : output.colors.grey2
        tip: sink ? `${sink.description || sink.nickname || sink.name}  ·  ${Math.round(level * 100)}%` : ""
        onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        onRightClicked: Quickshell.execDetached([output.bin + "hypr-settings-menu", "audio"])
        onScrolled: steps => output.step("volume", steps)

        PwObjectTracker {
            objects: [speaker.sink]
        }
    }
}
