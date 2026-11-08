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

    // BlueZ's icon names, as freedesktop's device icons.
    function glyph(device) {
        const icon = device?.icon ?? "";
        if (icon.includes("headset"))
            return 0xf02ce;
        if (icon.includes("headphones"))
            return 0xf02cb;
        if (icon.startsWith("audio"))
            return 0xf04c3;
        if (icon.includes("mouse"))
            return 0xf037d;
        if (icon.includes("keyboard"))
            return 0xf030c;
        if (icon.includes("gaming"))
            return 0xf0297;
        if (icon.includes("tablet"))
            return 0xf04f6;
        if (icon.includes("phone"))
            return 0xf011c;
        if (icon.includes("computer"))
            return 0xf0322;
        if (icon.includes("video") || icon.includes("display"))
            return 0xf0379;
        if (icon.includes("printer"))
            return 0xf042a;
        return 0xf00af;
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

    spacing: 8

    QuickBack {
        id: head
        sheet: bt.sheet
        title: "Bluetooth"
        switchable: true
        toggle.enabled: bt.adapter !== null && !bt.blocked
        toggle.on: bt.adapter?.enabled ?? false
        onSwitched: bt.adapter.enabled = !bt.adapter.enabled
    }

    Line {
        x: 13
        width: parent.width - 26
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
                spacing: 4

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

                QuickControl {
                    id: row

                    readonly property var device: entry.device

                    sheet: bt.sheet
                    flat: true
                    on: entry.device?.connected ?? false
                    width: parent.width
                    height: 34
                    onActivated: if (entry.device)
                        bt.choose(entry.device)

                    Line {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        mono: true
                        size: 16
                        text: String.fromCodePoint(bt.glyph(entry.device))
                        color: row.on ? bt.colors.blue : bt.colors.fg
                    }

                    Line {
                        x: 38
                        width: parent.width - x - note.width - 22
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: entry.device?.name || entry.device?.deviceName || ""
                        color: bt.colors.fg
                    }

                    Line {
                        id: note
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        size: 11
                        text: bt.status(entry.device)
                        color: row.on ? bt.colors.blue : bt.colors.grey2
                    }
                }

                // As the Wi-Fi page's failure: red in the glyph, fill and
                // edge, words fg.
                Rectangle {
                    visible: bt.failed !== null && bt.failed === entry.device
                    x: 38
                    width: parent.width - x - 4
                    height: words.implicitHeight + 14
                    radius: 8
                    color: bt.colors.withAlpha(bt.colors.red, 0.14)
                    border.width: 1
                    border.color: bt.colors.withAlpha(bt.colors.red, 0.45)

                    Line {
                        x: 10
                        y: 7
                        mono: true
                        text: String.fromCodePoint(0xf0028)
                        color: bt.colors.red
                    }

                    Line {
                        id: words
                        x: 32
                        y: 7
                        width: parent.width - x - 10
                        wrapMode: Text.Wrap
                        text: "Couldn't connect. Check that it's on and in range."
                        color: bt.colors.fg
                    }
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
