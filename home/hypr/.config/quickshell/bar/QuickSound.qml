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

    function glyph(node, input) {
        const api = node?.properties["device.api"] ?? "";
        const words = `${node?.name ?? ""} ${node?.description ?? ""}`.toLowerCase();
        if (api === "bluez5")
            return input ? 0xf02ce : 0xf00b0;
        if (input)
            return 0xf036c;
        if (words.includes("hdmi") || words.includes("displayport"))
            return 0xf0379;
        if (words.includes("headphone"))
            return 0xf02cb;
        return 0xf04c3;
    }

    spacing: 8

    PwObjectTracker {
        objects: sound.shown ? sound.devices : []
    }

    QuickBack {
        sheet: sound.sheet
        title: "Sound"
    }

    // In line with the rows' glyphs, further from the group above than
    // from its own.
    component Heading: Line {
        x: 13
        topPadding: 6
        bottomPadding: 4
        size: 11
        weight: Font.Bold
        font.capitalization: Font.AllUppercase
    }

    // A device row: its glyph, its name, and "Default" on the tint. It
    // takes the page it lists for as a property.
    component Device: QuickControl {
        id: device

        required property var page
        required property var node
        property bool input: false
        readonly property bool chosen: node === (input ? device.page.source : device.page.sink)

        flat: true
        on: chosen
        x: 3
        width: parent.width - 6
        height: 34
        onActivated: {
            if (input)
                Pipewire.preferredDefaultAudioSource = node;
            else
                Pipewire.preferredDefaultAudioSink = node;
        }

        Line {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            mono: true
            size: 16
            text: String.fromCodePoint(device.page.glyph(device.node, device.input))
            color: device.on ? device.colors.blue : device.colors.fg
        }

        Line {
            x: 38
            width: parent.width - x - mark.width - 22
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: device.page.name(device.node)
            color: device.colors.fg
        }

        Line {
            id: mark
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            size: 11
            text: device.chosen ? "Default" : ""
            color: device.colors.blue
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: sound.outputs.length > 0

        Heading {
            text: "Output"
            color: sound.colors.grey2
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
            color: sound.colors.grey2
        }

        // The default mic's level. Its steps are the sheet's own 5%:
        // hypr-level and the keys only move the speaker.
        QuickSlider {
            id: mic

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
            glyph: muted ? 0xf036d : 0xf036c
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
