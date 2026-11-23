// The dash panel's sheet (#83), on the shell base (#89): SESSIONS, LLM,
// TASKS and MARKET as cards 8px apart. It never scrolls
// (.claude/rules/dash-panel.md); content taller than the sheet is cut
// off at the bottom, and the bar's log says so.
//
// A click that opens something from a card (a session, tmux's tree, a
// usage page, asst, the IBKR portal) runs it and asks to close.
import QtQuick
import QtQuick.Layouts
import Quickshell

Sheet {
    id: sheet

    required property var feed
    property bool open: false
    // The cards' height and the room for them, for the no-scroll check.
    readonly property real contentHeight: cards.implicitHeight
    readonly property real room: body.height

    signal closeRequested

    // A card's click: run its command or open its link, then get out of
    // the way.
    function launch(url, cmd) {
        if (cmd && cmd.length)
            Quickshell.execDetached(cmd);
        if (url !== "")
            Qt.openUrlExternally(url);
        sheet.closeRequested();
    }

    onOpenChanged: fit.restart()

    // Only once open and settled: closed, or before the compositor sizes
    // it, the sheet is not its real height.
    Timer {
        id: fit
        interval: 500
        onTriggered: if (sheet.open && sheet.contentHeight > sheet.room)
            console.warn("dash panel overflows:", Math.ceil(sheet.contentHeight), "px of content in", Math.floor(sheet.room));
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.space.md
        clip: true
        onHeightChanged: fit.restart()

        ColumnLayout {
            id: cards
            width: parent.width
            spacing: Theme.space.sm
            onImplicitHeightChanged: fit.restart()

            DashSessions {
                Layout.fillWidth: true
                feed: sheet.feed
                onLaunch: (url, cmd) => sheet.launch(url, cmd)
            }

            DashLlm {
                Layout.fillWidth: true
                feed: sheet.feed
                onLaunch: (url, cmd) => sheet.launch(url, cmd)
            }

            DashTasks {
                Layout.fillWidth: true
                feed: sheet.feed
                onLaunch: (url, cmd) => sheet.launch(url, cmd)
            }

            DashMarket {
                Layout.fillWidth: true
                feed: sheet.feed
                onLaunch: (url, cmd) => sheet.launch(url, cmd)
            }
        }
    }
}
