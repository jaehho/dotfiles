pragma Singleton
pragma ComponentBehavior: Bound

// The session's notification daemon (#90). It holds
// org.freedesktop.Notifications, keeps every notification until it is
// dismissed, and decides which ones pop up. NotifPopups shows the
// popups, NotifCenter the list, and the bar's bell the count.
//
// Over IPC (`qs -c bar ipc call notifs <function>`): `toggle` opens or
// closes the center on the focused monitor (Super+period), `dnd` says
// "true" or "false", `setDnd`/`toggleDnd` change it, `count` says how
// many are kept, `clear` dismisses all.
//
// What swaync's config did lives here: the rules (`ignored`,
// `forcedCritical`), the hooks it ran on an action (`hook`), its
// timeouts and its 2FA copy action.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: notifs

    // Entries, newest first.
    property var list: []
    readonly property var popups: list.filter(e => e.popup)
    readonly property int count: list.length
    property alias dnd: persist.dnd
    // The center is open: nothing pops up, since the list is in view.
    property bool centerOpen: false
    // A clock for the cards' "5m" ages, ticking only while there is
    // something to age.
    property date now: new Date()

    readonly property string home: Quickshell.env("HOME")

    // The center's open/close request, for shell.qml to place: on the
    // named screen, or "" for the focused one.
    signal toggleRequested(string screen)

    onCenterOpenChanged: {
        if (centerOpen)
            for (const e of list)
                e.popup = false;
    }

    onDndChanged: {
        if (dnd)
            for (const e of list)
                e.popup = false;
    }

    // Not tracked, so the server closes them at once (swaync's
    // "ignored"): Spotify announces every track.
    function ignored(n) {
        return /spotify/i.test(n.appName);
    }

    // Shown as critical, so the popup stays: a Steno recording must not
    // be missed.
    function forcedCritical(n) {
        return n.appName === "Steno" && /^Recording/.test(n.summary);
    }

    // What runs when a notification is activated, before its own
    // action: swaync's `run-on: action` scripts.
    function hook(e) {
        if (e.appName === "screenshot" && e.summary === "Screenshot saved")
            return [home + "/.local/bin/screenshot", "open", e.body];
        if (e.appName === "Claude Code")
            return [home + "/.claude/hooks/notify.sh", "focus", e.hints["claude-window"] ?? "", e.hints["claude-tmux-socket"] ?? "", e.hints["claude-tmux"] ?? ""];
        return null;
    }

    // A one-time code in a message about one, for a Copy action.
    function otp(summary, body) {
        const text = (summary + " " + body).replace(/<[^>]*>/g, " ");
        if (!/(code|otp|verif|passcode|2fa|인증)/i.test(text))
            return "";
        const m = text.match(/\b(\d{4,8})\b/);
        return m ? m[1] : "";
    }

    // How long a popup stays, in ms; 0 stays until dismissed. Quickshell
    // documents expireTimeout as seconds, but it is the raw D-Bus value,
    // milliseconds (notification.cpp, updateProperties). 0 falls back to
    // the defaults as swaync did, rather than the spec's "never": apps
    // send it without meaning a sticky popup.
    function timeout(e) {
        if (e.critical)
            return 0;
        if (e.expireTimeout > 0)
            return e.expireTimeout;
        return e.urgency === NotificationUrgency.Low ? 3000 : 5000;
    }

    // "now", "5m", "3h", then the clock time, then the date.
    function ago(time) {
        const s = (now - time) / 1000;
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 6 * 3600)
            return `${Math.floor(s / 3600)}h`;
        if (now.toDateString() === time.toDateString())
            return Qt.formatTime(time, "HH:mm");
        return Qt.formatDate(time, "MMM d");
    }

    // A click on the card is the "default" action. The hook runs first;
    // then the action, which closes the notification unless it is
    // resident. With no such action, the click dismisses it, as
    // swaync's did.
    function activate(e, id) {
        const cmd = hook(e);
        if (cmd)
            Quickshell.execDetached(cmd);
        if (id === "otp") {
            Quickshell.execDetached(["wl-copy", "--", e.otp]);
            e.n?.dismiss();
            return;
        }
        const action = e.n?.actions.find(a => a.identifier === id);
        if (action)
            action.invoke();
        else if (!e.resident)
            e.n?.dismiss();
    }

    function dismiss(e) {
        e.n?.dismiss();
    }

    function clear() {
        for (const e of list.slice())
            e.n?.dismiss();
    }

    // Leaves the list, then the object goes once the exit animation that
    // still draws it is over.
    function drop(e) {
        console.log(`notif-debug ${Date.now() % 1e6} drop "${e.summary}" popup=${e.popup} centerOpen=${centerOpen}`);
        list = list.filter(x => x !== e);
        e.destroy(1000);
    }

    PersistentProperties {
        id: persist
        reloadableId: "notifs"

        property bool dnd: false
    }

    Timer {
        running: notifs.list.length > 0
        repeat: true
        interval: 30000
        triggeredOnStart: true
        onTriggered: notifs.now = new Date()
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            if (notifs.ignored(n))
                return;
            n.tracked = true;
            const e = entry.createObject(notifs, {
                n: n
            });
            // A reload hands the old notifications back; they already
            // popped up once.
            e.popup = !n.lastGeneration && !notifs.dnd && !notifs.centerOpen;
            notifs.list = [e, ...notifs.list];
        }
    }

    IpcHandler {
        target: "notifs"

        function toggle(): void {
            notifs.toggleRequested("");
        }

        function count(): int {
            return notifs.count;
        }

        function dnd(): string {
            return notifs.dnd ? "true" : "false";
        }

        function setDnd(on: bool): void {
            notifs.dnd = on;
        }

        function toggleDnd(): void {
            notifs.dnd = !notifs.dnd;
        }

        function clear(): void {
            notifs.clear();
        }
    }

    // One notification as the shell keeps it. Its fields are copies, not
    // bindings: the server deletes the Notification when it closes, and
    // a card still fading out must keep its text.
    component Entry: QtObject {
        id: e

        required property Notification n
        property date time: new Date()
        property bool popup: false
        // A pointer over its popup holds the timer.
        property bool held: false

        property string appName
        property string appIcon
        property string summary
        property string body
        property string image
        property int urgency
        property real expireTimeout
        property bool resident
        // `transient` is a reserved word in QML.
        property bool isTransient
        property var hints: ({})
        // [{ id, text }], without "default", which is the card's click.
        property var actions: []
        property bool hasDefault: false
        property string otp: ""
        // A progress bar, 0–100, from the `value` hint; -1 for none.
        property int progress: -1

        readonly property bool critical: urgency === NotificationUrgency.Critical || notifs.forcedCritical(e)

        function sync() {
            appName = n.appName;
            appIcon = n.appIcon;
            summary = n.summary;
            body = n.body;
            image = n.image;
            urgency = n.urgency;
            expireTimeout = n.expireTimeout;
            resident = n.resident;
            isTransient = n.transient;
            hints = n.hints;
            actions = n.actions.filter(a => a.identifier !== "default").map(a => ({
                        id: a.identifier,
                        text: a.text
                    }));
            hasDefault = n.actions.some(a => a.identifier === "default");
            otp = notifs.otp(summary, body);
            progress = typeof hints.value === "number" ? Math.max(0, Math.min(100, hints.value)) : -1;
        }

        // A replacement (same id, new content) is news again.
        function renew() {
            sync();
            time = new Date();
            if (!notifs.dnd && !notifs.centerOpen) {
                popup = true;
                timer.restart();
            }
        }

        Component.onCompleted: sync()
        Component.onDestruction: console.log(`notif-debug ${Date.now() % 1e6} entry destroyed "${e.summary}"`)

        readonly property Timer timer: Timer {
            interval: notifs.timeout(e)
            running: e.popup && !e.held && interval > 0
            onTriggered: {
                e.popup = false;
                // Transient ones are not kept once seen.
                if (e.isTransient)
                    e.n?.expire();
            }
        }

        readonly property Connections watch: Connections {
            target: e.n

            function onClosed() {
                notifs.drop(e);
            }

            function onSummaryChanged() {
                Qt.callLater(e.renew);
            }

            function onBodyChanged() {
                Qt.callLater(e.renew);
            }

            // A progress tick or new buttons: refresh, without popping up.
            function onHintsChanged() {
                Qt.callLater(e.sync);
            }

            function onActionsChanged() {
                Qt.callLater(e.sync);
            }
        }
    }

    Component {
        id: entry

        Entry {}
    }
}
