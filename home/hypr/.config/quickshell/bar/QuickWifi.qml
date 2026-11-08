// The quick settings sheet's Wi-Fi page: the radio, the networks in range
// (connected first, then saved ones, then by signal), and nmtui for the
// rest. A saved or open network joins on a press, and the connected one
// leaves. A new network with a password (WPA or WPA3 personal) asks for
// it in a field under its row; a failure says why on a red band. One that
// signs in another way (enterprise) opens nmtui. It scans only while
// shown.
import QtQuick
import Quickshell
import Quickshell.Networking

Column {
    id: wifi

    required property var sheet
    readonly property var colors: sheet.colors
    property bool shown: false
    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var live: device && Networking.wifiEnabled ? device.networks.values : []
    // The list in the order it was last sorted. Signal changes don't
    // re-sort it, so rows hold still under the keyboard; a network
    // coming or going, joining or being saved does.
    property var order: []
    // The network whose password field is open, the one a password was
    // last sent to, and the last failure, worded.
    property var asking: null
    property var tried: null
    property var failed: null
    property string why: ""
    property string password: ""

    readonly property var pskTypes: [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae]
    readonly property var openTypes: [WifiSecurityType.Open, WifiSecurityType.Owe]

    function first() {
        return list.count > 0 ? list.itemAt(0).rowItem : head.toggle;
    }

    function reorder() {
        wifi.order = wifi.live.filter(n => n.name !== "").sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }

    function glyph(net) {
        if (!net)
            return 0xf092f;
        const lock = !wifi.openTypes.includes(net.security);
        const steps = lock ? [0xf0921, 0xf0924, 0xf0927, 0xf092a] : [0xf091f, 0xf0922, 0xf0925, 0xf0928];
        return steps[Math.max(0, Math.min(3, Math.floor(net.signalStrength * 4)))];
    }

    // A network that went out of range is null until the list re-sorts.
    function status(net) {
        if (!net)
            return "";
        if (net.state === ConnectionState.Connecting)
            return "Connecting…";
        if (net.state === ConnectionState.Disconnecting)
            return "Disconnecting…";
        if (net.connected)
            return "Connected";
        if (net.known)
            return "Saved";
        if (!wifi.pskTypes.includes(net.security) && !wifi.openTypes.includes(net.security))
            return "Needs nmtui";
        return "";
    }

    function choose(net) {
        wifi.failed = null;
        if (net.connected) {
            net.disconnect();
        } else if (net.known || wifi.openTypes.includes(net.security)) {
            // A saved network without its password fails with NoSecrets,
            // which opens the field.
            net.connect();
        } else if (wifi.pskTypes.includes(net.security)) {
            wifi.ask(net);
        } else {
            wifi.sheet.launch("wifi");
        }
    }

    function ask(net) {
        wifi.asking = net;
        wifi.password = "";
        Qt.callLater(() => {
            const entry = wifi.entryFor(net);
            if (entry)
                wifi.sheet.reveal(entry.fieldItem);
        });
    }

    function cancel() {
        const net = wifi.asking;
        wifi.asking = null;
        wifi.password = "";
        const entry = wifi.entryFor(net);
        if (entry)
            wifi.sheet.reveal(entry.rowItem);
    }

    function submit() {
        const net = wifi.asking;
        if (!net || wifi.password === "")
            return;
        wifi.tried = net;
        wifi.failed = null;
        net.connectWithPsk(wifi.password);
        wifi.cancel();
    }

    function fail(net, reason) {
        const retried = wifi.tried === net;
        wifi.tried = null;
        wifi.failed = net;
        wifi.why = reason === ConnectionFailReason.NoSecrets ? (retried ? "Wrong password, or the network turned it down." : "This network needs its password.") : reason === ConnectionFailReason.WifiClientDisconnected ? "The network dropped the connection." : reason === ConnectionFailReason.WifiAuthTimeout ? "The network didn't answer in time." : reason === ConnectionFailReason.WifiNetworkLost ? "The network went out of range." : "Couldn't join this network.";
        if (reason === ConnectionFailReason.NoSecrets && wifi.pskTypes.includes(net.security))
            wifi.ask(net);
    }

    function entryFor(net) {
        for (let i = 0; i < list.count; i++) {
            const entry = list.itemAt(i);
            if (entry && entry.net === net)
                return entry;
        }
        return null;
    }

    onLiveChanged: Qt.callLater(wifi.reorder)
    onShownChanged: {
        if (shown)
            wifi.reorder();
        else {
            wifi.asking = null;
            wifi.password = "";
            wifi.failed = null;
        }
    }

    // A rebuilt list keeps the keyboard on the network it was on.
    onOrderChanged: {
        const focused = wifi.sheet.focused();
        const net = focused?.net ?? null;
        if (net)
            Qt.callLater(() => {
                const entry = wifi.entryFor(net);
                if (entry)
                    entry.rowItem.forceActiveFocus();
            });
    }

    // Every bar has this page and they share the device, so only a shown
    // one holds the scanner on; letting go puts back what was there.
    Binding {
        when: wifi.device !== null && wifi.shown
        target: wifi.device
        property: "scannerEnabled"
        value: true
    }

    spacing: 8

    QuickBack {
        id: head
        sheet: wifi.sheet
        title: "Wi-Fi"
        switchable: true
        toggle.enabled: wifi.device !== null && Networking.wifiHardwareEnabled
        toggle.on: Networking.wifiEnabled
        onSwitched: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Why the list is empty, and a wired link, in a quiet line each.
    Line {
        x: 13
        width: parent.width - 26
        visible: text !== ""
        wrapMode: Text.Wrap
        text: wifi.device === null ? "There is no Wi-Fi device." : !Networking.wifiHardwareEnabled ? "Wi-Fi is off at the hardware switch." : !Networking.wifiEnabled ? "Wi-Fi is off." : wifi.order.length === 0 ? "Looking for networks…" : ""
        color: wifi.colors.grey2
    }

    Line {
        x: 13
        width: parent.width - 26
        visible: wifi.wired !== null
        elide: Text.ElideRight
        text: `Wired: ${wifi.wired?.name ?? ""} is connected.`
        color: wifi.colors.grey2
    }

    QuickList {
        id: scroller
        colors: wifi.colors
        visible: list.count > 0

        Repeater {
            id: list
            model: wifi.order

            Column {
                id: entry

                required property var modelData
                readonly property var net: modelData
                property alias rowItem: row
                property alias fieldItem: field

                width: scroller.rowWidth
                spacing: 4

                Connections {
                    target: entry.net

                    function onConnectionFailed(reason) {
                        wifi.fail(entry.net, reason);
                    }

                    function onConnectedChanged() {
                        if (entry.net?.connected && wifi.failed === entry.net)
                            wifi.failed = null;
                        Qt.callLater(wifi.reorder);
                    }

                    function onKnownChanged() {
                        Qt.callLater(wifi.reorder);
                    }
                }

                QuickControl {
                    id: row

                    readonly property var net: entry.net

                    sheet: wifi.sheet
                    flat: true
                    on: entry.net?.connected ?? false
                    width: parent.width
                    height: 34
                    onActivated: if (entry.net)
                        wifi.choose(entry.net)

                    Line {
                        id: strength
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        mono: true
                        size: 16
                        text: String.fromCodePoint(wifi.glyph(entry.net))
                        color: row.on ? wifi.colors.blue : wifi.colors.fg
                    }

                    Line {
                        x: 38
                        width: parent.width - x - note.width - 22
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: entry.net?.name ?? ""
                        color: wifi.colors.fg
                    }

                    Line {
                        id: note
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        size: 11
                        text: wifi.status(entry.net)
                        color: row.on ? wifi.colors.blue : wifi.colors.grey2
                    }
                }

                // The password, masked and kept out of the input method.
                QuickControl {
                    id: field

                    readonly property var net: entry.net

                    sheet: wifi.sheet
                    visible: wifi.asking === entry.net
                    x: 38
                    width: parent.width - x - 4
                    height: 36
                    color: wifi.colors.bg0
                    border.color: input.activeFocus ? wifi.colors.blue : wifi.colors.bg2
                    onActivated: input.forceActiveFocus()
                    onActiveFocusChanged: if (activeFocus)
                        input.forceActiveFocus()

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                        color: wifi.colors.fg
                        selectionColor: wifi.colors.withAlpha(wifi.colors.blue, 0.35)
                        selectedTextColor: wifi.colors.fg
                        selectByMouse: true
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        text: wifi.password
                        onTextChanged: wifi.password = text
                        Keys.onReturnPressed: wifi.submit()
                        Keys.onEnterPressed: wifi.submit()
                        Keys.onEscapePressed: wifi.cancel()

                        cursorDelegate: Rectangle {
                            width: 1
                            color: wifi.colors.blue
                            visible: input.activeFocus

                            SequentialAnimation on opacity {
                                running: input.activeFocus
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0
                                    duration: 500
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 500
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === "" && input.preeditText === ""
                            text: `Password for ${entry.net?.name ?? ""}`
                            color: wifi.colors.grey2
                            font: input.font
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // The failure, as the polkit sheet bands a wrong
                // password: red in the glyph, fill and edge, words fg.
                Rectangle {
                    visible: wifi.failed !== null && wifi.failed === entry.net && wifi.why !== ""
                    x: 38
                    width: parent.width - x - 4
                    height: words.implicitHeight + 14
                    radius: 8
                    color: wifi.colors.withAlpha(wifi.colors.red, 0.14)
                    border.width: 1
                    border.color: wifi.colors.withAlpha(wifi.colors.red, 0.45)

                    Line {
                        id: mark
                        x: 10
                        y: 7
                        mono: true
                        text: String.fromCodePoint(0xf0028)
                        color: wifi.colors.red
                    }

                    Line {
                        id: words
                        x: 32
                        y: 7
                        width: parent.width - x - 10
                        wrapMode: Text.Wrap
                        text: wifi.why
                        color: wifi.colors.fg
                    }
                }
            }
        }
    }

    QuickFoot {
        sheet: wifi.sheet
        entry: "wifi"
        text: "More in nmtui"
    }
}
