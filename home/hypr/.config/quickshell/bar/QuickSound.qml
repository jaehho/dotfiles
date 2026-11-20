// The quick settings sheet's Sound page: every output and input PipeWire
// has, the default of each on the blue tint, and the default mic's level.
// A press makes a device the default. Nothing is hidden: an HDMI output
// with no screen on it is listed as PipeWire lists it. Per-app volume
// stays in wiremix, a row away.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Column {
    id: sound

    required property var sheet
    readonly property var colors: sheet.colors
    property bool shown: false
    readonly property var devices: Pipewire.nodes.values.filter(n => !n.isStream && (n.type & PwNodeType.Audio))
    readonly property var outputs: devices.filter(n => n.isSink)
    readonly property var inputs: devices.filter(n => !n.isSink)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function first() {
        return outputs.length > 0 ? outputList.itemAt(0) : mic;
    }

    function name(node) {
        return node ? node.nickname || node.description || node.name : "";
    }

    // Its Material Symbol: Bluetooth audio, a mic, a screen's speakers,
    // headphones, else a speaker.
    function icon(node, input) {
        const api = node?.properties["device.api"] ?? "";
        const words = `${node?.name ?? ""} ${node?.description ?? ""}`.toLowerCase();
        if (api === "bluez5")
            return input ? "headset_mic" : "headphones";
        if (input)
            return "mic";
        if (words.includes("hdmi") || words.includes("displayport"))
            return "monitor";
        if (words.includes("headphone"))
            return "headphones";
        return "speaker";
    }

    spacing: Theme.space.sm

    PwObjectTracker {
        objects: sound.shown ? sound.devices : []
    }

    QuickBack {
        sheet: sound.sheet
        title: "Sound"
    }

    // In line with the rows' icons, further from the group above than
    // from its own: the main page's "Open" heading.
    component Heading: Line {
        x: 3 + Theme.space.md
        topPadding: Theme.space.sm
        bottomPadding: Theme.space.xs
        size: Theme.font.small
        weight: Font.Bold
        font.capitalization: Font.AllUppercase
        color: Theme.colors.grey2
    }

    // A device row, "Default" on the tint. It takes the page it lists
    // for as a property.
    component Device: QuickRow {
        id: device

        required property var page
        required property var node
        property bool input: false
        readonly property bool chosen: node === (input ? device.page.source : device.page.sink)

        on: chosen
        x: 3
        width: parent.width - 6
        icon: device.page.icon(device.node, device.input)
        text: device.page.name(device.node)
        note: chosen ? "Default" : ""
        onActivated: {
            if (input)
                Pipewire.preferredDefaultAudioSource = node;
            else
                Pipewire.preferredDefaultAudioSink = node;
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: sound.outputs.length > 0

        Heading {
            text: "Output"
        }

        Repeater {
            id: outputList
            model: sound.outputs

            Device {
                required property var modelData
                sheet: sound.sheet
                page: sound
                node: modelData
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2

        Heading {
            text: "Input"
        }

        // The default mic's level. Its steps are the sheet's own 5%:
        // hypr-level and the keys only move the speaker.
        QuickSlider {
            id: mic
            hintText: "Mic"

            readonly property bool muted: sound.source?.audio?.muted ?? false
            readonly property real level: sound.source?.audio?.volume ?? 0

            function mute() {
                if (sound.source?.audio)
                    sound.source.audio.muted = !muted;
            }

            sheet: sound.sheet
            x: 3
            width: parent.width - 6
            enabled: sound.source !== null
            value: level
            off: muted
            icon: muted ? "mic_off" : "mic"
            pressable: true
            label: muted && !held ? "Muted" : `${Math.round((held ? dragged : level) * 100)}%`
            onMoved: value => {
                if (!sound.source?.audio)
                    return;
                sound.source.audio.volume = value;
                if (value > 0)
                    sound.source.audio.muted = false;
            }
            onStepped: steps => {
                if (sound.source?.audio)
                    sound.source.audio.volume = Math.max(0, Math.min(1, level + steps * 0.05));
            }
            onGlyphClicked: mute()
            onActivated: mute()

            PwObjectTracker {
                objects: [sound.source]
            }
        }

        Repeater {
            model: sound.inputs

            Device {
                required property var modelData
                sheet: sound.sheet
                page: sound
                node: modelData
                input: true
            }
        }
    }

    QuickFoot {
        sheet: sound.sheet
        entry: "audio"
        text: "Mixer in wiremix"
    }
}
