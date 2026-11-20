// The quick settings sheet's Bluetooth page: the adapter's switch and the
// paired devices, connected first, each with its battery where it reports
// one. A press connects or disconnects; a connection that doesn't come up
// says so on a red band. Pairing a new device needs an agent Quickshell
// doesn't provide, so it stays in bluetui, a row away.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Column {
    id: bt

    required property var sheet
    readonly property var colors: sheet.colors
    property bool shown: false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    readonly property var live: adapter && adapter.enabled ? adapter.devices.values : []
    // Sorted when a device comes, goes or (dis)connects, not on battery
    // changes, so rows hold still under the keyboard.
    property var order: []
    // The device a press is connecting, whether it was seen connecting,
    // and the last one that failed to.
    property var trying: null
    property bool started: false
    property var failed: null

    function first() {
        return list.count > 0 ? list.itemAt(0).rowItem : head.toggle;
    }

    function reorder() {
        bt.order = bt.live.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
    }

    // Its Material Symbol, from BlueZ's icon name (freedesktop's device
    // icons).
    function icon(device) {
        const name = device?.icon ?? "";
        if (name.includes("headset"))
            return "headset_mic";
        if (name.includes("headphones"))
            return "headphones";
        if (name.startsWith("audio"))
            return "speaker";
        if (name.includes("mouse"))
            return "mouse";
        if (name.includes("keyboard"))
            return "keyboard";
        if (name.includes("gaming"))
            return "sports_esports";
        if (name.includes("tablet"))
            return "tablet";
        if (name.includes("phone"))
            return "smartphone";
        if (name.includes("computer"))
            return "computer";
        if (name.includes("video") || name.includes("display"))
            return "monitor";
        if (name.includes("printer"))
            return "print";
        return "bluetooth";
    }

    function status(device) {
        if (!device)
            return "";
        const state = device.state === BluetoothDeviceState.Connecting ? "Connecting…" : device.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : device.connected ? "Connected" : "";
        return device.connected && device.batteryAvailable ? `${Math.round(device.battery * 100)}%  ·  ${state}` : state;
    }

    function choose(device) {
        bt.failed = null;
        if (device.connected) {
            device.disconnect();
            return;
        }
        bt.trying = device;
        bt.started = false;
        timeout.restart();
        device.connect();
    }

    function fail(device) {
        bt.trying = null;
        timeout.stop();
        bt.failed = device;
    }

    function entryFor(device) {
        for (let i = 0; i < list.count; i++) {
            const entry = list.itemAt(i);
            if (entry && entry.device === device)
                return entry;
        }
        return null;
    }

    onLiveChanged: Qt.callLater(bt.reorder)
    onShownChanged: {
        if (shown)
            bt.reorder();
        else
            bt.failed = null;
    }

    // A rebuilt list keeps the keyboard on the device it was on.
    onOrderChanged: {
        const device = bt.sheet.focused()?.device ?? null;
        if (device)
            Qt.callLater(() => {
                const entry = bt.entryFor(device);
                if (entry)
                    entry.rowItem.forceActiveFocus();
            });
    }

    // BlueZ gives up on a device that is off or away within seconds;
    // this catches one that never says so.
    Timer {
        id: timeout
        interval: 15000
        onTriggered: if (bt.trying && !bt.trying.connected)
            bt.fail(bt.trying)
    }

    spacing: Theme.space.sm

    QuickBack {
        id: head
        sheet: bt.sheet
        title: "Bluetooth"
        switchable: true
        toggle.enabled: bt.adapter !== null && !bt.blocked
        toggle.on: bt.adapter?.enabled ?? false
        onSwitched: bt.adapter.enabled = !bt.adapter.enabled
    }

    // Why the list is empty, in line with the rows' icons.
    Line {
        x: 3 + Theme.space.md
        width: parent.width - x * 2
        visible: text !== ""
        wrapMode: Text.Wrap
        text: bt.adapter === null ? "There is no Bluetooth adapter." : bt.blocked ? "Bluetooth is blocked; rfkill unblock bluetooth lifts it." : !bt.adapter.enabled ? "Bluetooth is off." : bt.order.length === 0 ? "No paired devices yet." : ""
        color: bt.colors.grey2
    }

    QuickList {
        id: scroller
        colors: bt.colors
        visible: list.count > 0

        Repeater {
            id: list
            model: bt.order

            Column {
                id: entry

                required property var modelData
                readonly property var device: modelData
                property alias rowItem: row

                width: scroller.rowWidth
                spacing: Theme.space.xs

                Connections {
                    target: entry.device

                    function onStateChanged() {
                        const device = entry.device;
                        if (!device || bt.trying !== device)
                            return;
                        if (device.connected) {
                            bt.trying = null;
                            timeout.stop();
                        } else if (device.state === BluetoothDeviceState.Connecting) {
                            bt.started = true;
                        } else if (device.state === BluetoothDeviceState.Disconnected && bt.started) {
                            bt.fail(device);
                        }
                    }

                    function onConnectedChanged() {
                        Qt.callLater(bt.reorder);
                    }

                    function onPairedChanged() {
                        Qt.callLater(bt.reorder);
                    }
                }

                QuickRow {
                    id: row

                    readonly property var device: entry.device

                    sheet: bt.sheet
                    on: entry.device?.connected ?? false
                    width: parent.width
                    icon: bt.icon(entry.device)
                    text: entry.device?.name || entry.device?.deviceName || ""
                    note: bt.status(entry.device)
                    onActivated: if (entry.device)
                        bt.choose(entry.device)
                }

                QuickBand {
                    visible: bt.failed !== null && bt.failed === entry.device
                    x: row.textX
                    width: parent.width - x - Theme.space.xs
                    text: "Couldn't connect. Check that it's on and in range."
                }
            }
        }
    }

    QuickFoot {
        sheet: bt.sheet
        entry: "bluetooth"
        text: "Pair a new device in bluetui"
    }
}
