// The MARKET card: dash-mkt's IBKR snapshot (a 30-min timer), six
// positions at most, the biggest day move first so a losing one can't
// fall off the bottom, then the account. A snapshot past one missed
// fetch (dash-data: > 35 min) dims; the amber note says why the card is
// empty or behind. The card opens the IBKR portal.
import QtQuick
import QtQuick.Layouts

DashCard {
    id: card

    required property var feed

    readonly property var m: feed.board ? feed.board.market : null
    readonly property var acct: m && m.account ? m.account : null
    readonly property var all: m && m.positions ? m.positions : []
    readonly property var rows: all.slice().sort((a, b) => Math.abs(b.dayPl || 0) - Math.abs(a.dayPl || 0)).slice(0, 6)
    readonly property real body: m && m.late ? 0.45 : 1
    readonly property int col: 72
    readonly property string note: {
        if (!m)
            return "";
        if (m.error)
            return m.error;
        if (m.last_error)
            return "refresh failed " + feed.ago(m.last_error_ts) + ": " + m.last_error;
        return m.stale ? "market data stale — is dash-mkt.timer running?" : "";
    }

    // Thousands grouped by hand: Qt's toLocaleString() writes 1,234,568
    // as $1.23457e+06 (jaehho/dash#28). Cents below $1000.
    function money(v) {
        if (v === null || v === undefined)
            return "–";
        const a = Math.abs(v);
        return "$" + (a >= 1000 ? Math.round(a).toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ",") : a.toFixed(2));
    }

    function pl(v) {
        return v === null || v === undefined ? "–" : (v >= 0 ? "+" : "-") + card.money(Math.abs(v));
    }

    function plTint(v) {
        return v === null || v === undefined ? card.colors.grey2 : v >= 0 ? card.colors.green : card.colors.red;
    }

    title: "MARKET" + (m && m.ts && !m.error ? "  ·  " + feed.ago(m.ts) : "")
    url: "https://portal.interactivebrokers.com"
    dimmed: feed.boardDown

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Line {
            visible: card.note !== ""
            Layout.fillWidth: true
            text: card.note
            color: card.colors.yellow
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        RowLayout {
            visible: card.rows.length > 0
            opacity: card.body
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: ["last", "day", "total"]

                Line {
                    required property string modelData

                    Layout.preferredWidth: card.col
                    horizontalAlignment: Text.AlignRight
                    text: modelData
                    mono: true
                    size: 12
                    color: card.colors.grey2
                }
            }
        }

        Repeater {
            model: card.rows

            RowLayout {
                id: position

                required property var modelData

                Layout.fillWidth: true
                opacity: card.body
                spacing: 10

                Line {
                    Layout.fillWidth: true
                    text: position.modelData.symbol + (position.modelData.qty !== null ? " " + Math.round(position.modelData.qty) + "sh" : "")
                    mono: true
                    color: card.colors.fg
                    elide: Text.ElideRight
                }

                Line {
                    Layout.preferredWidth: card.col
                    horizontalAlignment: Text.AlignRight
                    text: card.money(position.modelData.last)
                    mono: true
                    color: card.colors.grey2
                }

                Line {
                    Layout.preferredWidth: card.col
                    horizontalAlignment: Text.AlignRight
                    text: card.pl(position.modelData.dayPl)
                    mono: true
                    color: card.plTint(position.modelData.dayPl)
                }

                Line {
                    Layout.preferredWidth: card.col
                    horizontalAlignment: Text.AlignRight
                    text: card.pl(position.modelData.totalPl)
                    mono: true
                    color: card.plTint(position.modelData.totalPl)
                }
            }
        }

        Line {
            visible: card.all.length > card.rows.length
            opacity: card.body
            text: "…and " + (card.all.length - card.rows.length) + " more"
            mono: true
            size: 12
            color: card.colors.grey2
        }

        RowLayout {
            visible: !!card.acct && card.acct.netLiq !== undefined
            Layout.fillWidth: true
            Layout.topMargin: 4
            opacity: card.body
            spacing: 10

            Line {
                text: "account"
                color: card.colors.grey2
            }

            Item {
                Layout.fillWidth: true
            }

            Line {
                Layout.preferredWidth: card.col
                horizontalAlignment: Text.AlignRight
                text: card.acct ? card.money(card.acct.netLiq || 0) : ""
                mono: true
                color: card.colors.fg
            }

            Line {
                Layout.preferredWidth: card.col * 2 + 10
                horizontalAlignment: Text.AlignRight
                text: !card.acct ? "" : card.pl(card.acct.dayPl) + (card.acct.dayPlPct !== null && card.acct.dayPlPct !== undefined ? " (" + (card.acct.dayPlPct >= 0 ? "+" : "") + card.acct.dayPlPct.toFixed(2) + "%)" : "")
                mono: true
                color: card.plTint(card.acct ? card.acct.dayPl : null)
            }
        }

        Line {
            visible: !card.feed.board
            text: "…"
            mono: true
            color: card.colors.grey2
        }
    }
}
