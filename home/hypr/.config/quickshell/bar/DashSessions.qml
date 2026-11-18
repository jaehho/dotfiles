// The SESSIONS card: the live Claude Code sessions, one line each and
// six at most, waiting ones first (they need you). Waiting is red, with
// what it waits for in place of the project, and its clock turns red
// too after 10 min, so a stuck session is not mistaken for one that only
// just asked. A row focuses its kitty and tmux pane (dash-focus-session);
// the card opens tmux's session tree.
import QtQuick
import QtQuick.Layouts
import Quickshell

DashCard {
    id: card

    required property var feed

    // The panel never scrolls (.claude/rules/dash-panel.md): this cap is
    // the card's share of the height.
    readonly property int cap: 6
    readonly property var sess: feed.board ? feed.board.sessions : null
    readonly property var items: {
        const all = sess && sess.items ? sess.items : [];
        return all.filter(i => i.status === "waiting").concat(all.filter(i => i.status !== "waiting"));
    }
    readonly property var rest: items.slice(cap)
    readonly property int restWaiting: rest.filter(i => i.status === "waiting").length

    function tint(status) {
        return status === "waiting" ? card.colors.red : card.colors.grey2;
    }

    // "…and 8 more · 7 busy · 1 idle"
    function more() {
        if (!card.rest.length)
            return "";
        const by = {};
        for (const i of card.rest)
            by[i.status] = (by[i.status] || 0) + 1;
        const bits = ["waiting", "busy", "idle"].filter(k => by[k]).map(k => by[k] + " " + k);
        return "…and " + card.rest.length + " more" + (bits.length ? " · " + bits.join(" · ") : "");
    }

    title: "SESSIONS" + (sess && sess.total ? "  ·  " + sess.total : "")
    cmd: ["kitty", "-e", "tmux", "choose-tree", "-Zs"]
    dimmed: feed.boardDown

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: card.items.slice(0, card.cap)

            delegate: Item {
                id: sessionRow

                required property var modelData
                readonly property bool waiting: modelData.status === "waiting"
                readonly property bool stuck: waiting && !!modelData.statusAt && card.feed.since(modelData.statusAt) > 600
                // The project, unless the name already starts with it; a
                // lane only when it is not the default (native).
                readonly property string meta: [modelData.project && !(modelData.name || "").startsWith(modelData.project) ? modelData.project : "", modelData.lane !== "native" ? modelData.lane : ""].filter(x => x).join(" · ")

                Layout.fillWidth: true
                implicitHeight: line.implicitHeight

                RowLayout {
                    id: line
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 3.5
                        color: card.tint(sessionRow.modelData.status)
                    }

                    Line {
                        text: sessionRow.modelData.name
                        mono: true
                        color: card.colors.fg
                        elide: Text.ElideRight
                        Layout.maximumWidth: 150
                    }

                    // What a waiting session waits for ("permission: Bash"),
                    // else the project or lane.
                    Line {
                        Layout.fillWidth: true
                        text: sessionRow.waiting ? (sessionRow.modelData.waitingFor || "") : sessionRow.meta
                        mono: true
                        size: 12
                        color: sessionRow.waiting ? card.colors.red : card.colors.grey1
                        elide: Text.ElideRight
                    }

                    Line {
                        text: sessionRow.modelData.status
                        mono: true
                        size: 12
                        color: card.tint(sessionRow.modelData.status)
                    }

                    // How long in this status: busy means running, not
                    // finished.
                    Line {
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                        text: card.feed.dur(card.feed.since(sessionRow.modelData.statusAt || sessionRow.modelData.startedAt))
                        mono: true
                        size: 12
                        color: sessionRow.stuck ? card.colors.red : card.colors.grey2
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.launch("", [Quickshell.env("HOME") + "/.local/bin/dash-focus-session", "" + sessionRow.modelData.pid])
                }
            }
        }

        Line {
            visible: text !== ""
            text: card.more()
            mono: true
            size: 12
            color: card.restWaiting > 0 ? card.colors.red : card.colors.grey2
        }

        Line {
            visible: card.items.length === 0
            text: card.feed.board ? "no live sessions" : "…"
            color: card.colors.grey2
        }
    }
}
