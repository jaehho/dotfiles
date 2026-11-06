// What keeps the machine up and connected: the battery (its power
// profile slides out to its left under the pointer), Bluetooth and the
// network, as waybar's group/link. A click swaps a glyph for its detail
// (time left, connected devices, the address), as waybar's format-alt
// did; a right click opens its quick settings.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower

Row {
    id: link

    required property var bar
    readonly property var colors: bar.colors
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    function settings(id) {
        Quickshell.execDetached([link.bin + "hypr-settings-menu", id]);
    }

    // "3 h 20 min", waybar's {time}.
    function span(seconds) {
        const minutes = Math.round(seconds / 60);
        return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
    }

    // Bits per second, as waybar's bandwidth*Bits read.
    function rate(bitsPerSecond) {
        const units = ["b/s", "kb/s", "Mb/s", "Gb/s"];
        let value = bitsPerSecond;
        let unit = 0;
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000;
            unit += 1;
        }
        return `${value.toFixed(unit === 0 ? 0 : 1)}${units[unit]}`;
    }

    Item {
        id: power

        width: drawer.width + battery.width
        height: 24

        HoverHandler {
            id: powerHover
        }

        Item {
            id: drawer
            width: powerHover.hovered ? profile.implicitWidth : 0
            height: 24
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }

            BarButton {
                id: profile

                readonly property var names: ({
                        [PowerProfile.PowerSaver]: "power-saver",
                        [PowerProfile.Balanced]: "balanced",
                        [PowerProfile.Performance]: "performance"
                    })
                readonly property var order: PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]

                function cycle(by) {
                    const at = order.indexOf(PowerProfiles.profile);
                    PowerProfiles.profile = order[(at + by + order.length) % order.length];
                }

                anchors.right: parent.right
                bar: link.bar
                text: String.fromCodePoint(PowerProfiles.profile === PowerProfile.Performance ? 0xf140b : PowerProfiles.profile === PowerProfile.PowerSaver ? 0xf032a : 0xf05d1)
                tip: `Profile: ${names[PowerProfiles.profile] ?? "unknown"}`
                onClicked: cycle(1)
                onRightClicked: cycle(-1)
            }
        }

        BarButton {
            id: battery

            readonly property var device: UPower.displayDevice
            readonly property var cell: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
            readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
            readonly property bool charging: device?.state === UPowerDeviceState.Charging
            // On the charger but holding (a charge limit): waybar's Plugged.
            readonly property bool plugged: device?.state === UPowerDeviceState.PendingCharge
            readonly property bool low: !charging && percent <= 30
            readonly property bool critical: !charging && percent <= 15
            readonly property real seconds: charging ? device?.timeToFull ?? 0 : device?.timeToEmpty ?? 0
            property bool detail: false

            readonly property string glyph: String.fromCodePoint(charging ? 0xf0084 : plugged ? 0xf06a5 : [0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079][Math.max(0, Math.min(9, Math.floor(percent / 10)))])

            x: drawer.width
            visible: device?.isPresent ?? false
            bar: link.bar
            text: detail ? `${glyph} ${seconds > 0 ? link.span(seconds) : ""}`.trim() : low && !plugged ? `${glyph} ${percent}%` : glyph
            tint: charging ? link.colors.green : critical ? (blink.on ? link.colors.fg : link.colors.red) : low ? link.colors.orange : link.colors.grey2
            hoverTint: charging ? link.colors.green : critical || low ? tint : link.colors.fg
            tip: {
                const when = seconds > 0 ? `${link.span(seconds)} until ${charging ? "full" : "empty"}` : charging ? "charging" : "full";
                const health = cell?.healthSupported ? `  ·  Health ${Math.round(cell.healthPercentage)}%` : "";
                return `${percent}%  ·  ${when}\n${(device?.changeRate ?? 0).toFixed(1)} W${health}`;
            }
            onClicked: detail = !detail
            onRightClicked: link.settings("battery")

            // Critical blinks red and fg, twice a second.
            Timer {
                id: blink
                property bool on: false
                running: battery.critical
                interval: 500
                repeat: true
                onTriggered: on = !on
                onRunningChanged: on = false
            }
        }
    }

    BarButton {
        id: bluetooth

        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool off: !adapter || !adapter.enabled
        readonly property var linked: adapter ? adapter.devices.values.filter(d => d.connected) : []
        property bool detail: false

        bar: link.bar
        text: detail ? `${String.fromCodePoint(0xf00af)} ${linked.length}` : String.fromCodePoint(off ? 0xf00b2 : linked.length > 0 ? 0xf00b1 : 0xf00af)
        tint: off ? link.colors.grey0 : link.colors.grey2
        tip: !adapter ? "No adapter" : [adapter.name, ...(linked.length > 0 ? ["", ...linked.map(d => d.batteryAvailable ? `${d.name}\t${Math.round(d.battery * 100)}%` : d.name)] : [])].join("\n")
        onClicked: detail = !detail
        onRightClicked: link.settings("bluetooth")
    }

    BarButton {
        id: network

        readonly property var devices: Networking.devices.values
        readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
        readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
        readonly property var active: wired ?? wifi
        readonly property var station: wifi ? wifi.networks.values.find(n => n.connected) ?? null : null
        property bool detail: false
        // From `ip` and /proc/net/dev, sampled only while it is read.
        property var address: ({})
        property var last: null
        property real up: 0
        property real down: 0

        bar: link.bar
        text: detail && active ? `${active.name}  ${address.ip ?? "?"}/${address.prefix ?? "?"}` : String.fromCodePoint(wired ? 0xf0200 : wifi ? 0xf0928 : 0xf092d)
        tint: active ? link.colors.grey2 : link.colors.red
        tip: {
            if (!active)
                return "Disconnected";
            const lines = [];
            if (station)
                lines.push(`${station.name} (${Math.round(station.signalStrength * 100)}%)`);
            lines.push(`${active.name} via ${address.gateway ?? "?"}`, `${address.ip ?? "?"}/${address.prefix ?? "?"}`, `↑ ${link.rate(up)} ↓ ${link.rate(down)}`);
            return lines.join("\n");
        }
        onClicked: detail = !detail
        onRightClicked: link.settings("wifi")

        Timer {
            running: network.active !== null && (network.hovered || network.detail)
            triggeredOnStart: true
            interval: 2000
            repeat: true
            onTriggered: probe.running = true
        }

        Process {
            id: probe
            command: ["sh", "-c", 'ip -j -4 addr show dev "$1"; ip -j -4 route show default dev "$1"; awk -v d="$1:" \'$1 == d { print $2, $10 }\' /proc/net/dev', "sh", network.active?.name ?? "lo"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [addr, route, bytes] = text.trim().split("\n");
                    try {
                        const info = JSON.parse(addr)[0]?.addr_info?.[0] ?? {};
                        const gateway = JSON.parse(route)[0]?.gateway;
                        network.address = {
                            ip: info.local,
                            prefix: info.prefixlen,
                            gateway: gateway
                        };
                    } catch (error) {}
                    const [rx, tx] = (bytes ?? "").split(" ").map(Number);
                    const now = Date.now();
                    if (network.last && now > network.last.at) {
                        const seconds = (now - network.last.at) / 1000;
                        network.down = Math.max(0, (rx - network.last.rx) * 8 / seconds);
                        network.up = Math.max(0, (tx - network.last.tx) * 8 / seconds);
                    }
                    network.last = {
                        rx: rx,
                        tx: tx,
                        at: now
                    };
                }
            }
        }
    }
}
