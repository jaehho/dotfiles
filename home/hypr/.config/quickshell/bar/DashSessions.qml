// The SESSIONS card: the live Claude Code sessions, five at most, but a
// waiting one (it needs you) is never hidden behind "…and N more".
// Waiting is red, and its clock turns red too after 10 min, so a stuck
// session is not mistaken for one that only just asked. A row focuses
// its kitty and tmux pane (dash-focus-session); the card opens tmux's
// session tree.
import QtQuick
import QtQuick.Layouts
import Quickshell

DashCard {
    id: card

    required property var feed

    readonly property var sess: feed.board ? feed.board.sessions : null
    readonly property var items: sess && sess.items ? sess.items : []
    readonly property int shown: Math.min(items.length, Math.max(5, items.filter(i => i.status === "waiting").length))

    function tint(status) {
        return status === "waiting" ? card.colors.red : card.colors.grey2;
    }

    // "…and 8 more · 7 busy · 1 idle"
    function more() {
        const rest = card.items.slice(card.shown);
        if (!rest.length)
            return "";
        const by = {};
        for (const i of rest)
            by[i.status] = (by[i.status] || 0) + 1;
        const bits = ["waiting", "busy", "idle"].filter(k => by[k]).map(k => by[k] + " " + k);
        return "…and " + rest.length + " more" + (bits.length ? " · " + bits.join(" · ") : "");
    }

    title: "SESSIONS" + (sess && sess.total ? "  ·  " + sess.total : "")
    cmd: ["kitty", "-e", "tmux", "choose-tree", "-Zs"]
    dimmed: feed.boardDown

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: card.items.slice(0, card.shown)

            delegate: Item {
                id: sessionRow

                required property var modelData
                readonly property bool waiting: modelData.status === "waiting"
                readonly property bool stuck: waiting && !!modelData.statusAt && card.feed.since(modelData.statusAt) > 600
                // native is the default lane, so only another is said
                readonly property string meta: [modelData.project, modelData.lane !== "native" ? modelData.lane : ""].filter(x => x).join(" · ")

                Layout.fillWidth: true
                implicitHeight: rowCol.implicitHeight

                ColumnLayout {
                    id: rowCol
                    width: parent.width
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            radius: 3.5
                            color: card.tint(sessionRow.modelData.status)
                        }

                        Line {
                            Layout.fillWidth: true
                            text: sessionRow.modelData.name
                            mono: true
                            color: card.colors.fg
                            elide: Text.ElideRight
                        }

                        Line {
                            text: sessionRow.modelData.status
                            mono: true
                            size: 12
                            color: card.tint(sessionRow.modelData.status)
                        }

                        // How long in this status: busy means running,
                        // not finished.
                        Line {
                            text: card.feed.dur(card.feed.since(sessionRow.modelData.statusAt || sessionRow.modelData.startedAt))
                            mono: true
                            size: 12
                            color: sessionRow.stuck ? card.colors.red : card.colors.grey2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 15
                        spacing: 8

                        // What a waiting session waits for ("permission: Bash").
                        Line {
                            visible: text !== ""
                            Layout.maximumWidth: 220
                            text: sessionRow.waiting ? (sessionRow.modelData.waitingFor || "") : ""
                            mono: true
                            size: 12
                            color: card.colors.red
                            elide: Text.ElideRight
                        }

                        Line {
                            Layout.fillWidth: true
                            text: sessionRow.meta
                            mono: true
                            size: 12
                            color: card.colors.grey2
                            elide: Text.ElideRight
                        }
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
            color: card.colors.grey2
        }

        Line {
            visible: card.items.length === 0
            text: card.feed.board ? "no live sessions" : "…"
            color: card.colors.grey2
        }
    }
}
