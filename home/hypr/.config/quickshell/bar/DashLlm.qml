// The LLM card: the Claude weekly quota and the OpenRouter month
// budget, each against its even-burn pace (DashQuota). The Opus/Sonnet
// weekly rows show only with SHOW_SCOPED_QUOTAS=1 in ~/.config/dash/prefs
// (dash archives them either way). A source unsynced for 15 min is
// named red beside the title: its collector is failing (its SLA is
// 1 min).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

DashCard {
    id: card

    required property var feed

    readonly property var c: feed.board && feed.board.llm ? feed.board.llm.claude_limits : null
    readonly property var or: feed.board && feed.board.llm ? feed.board.llm.or_key : null
    property bool showScoped: false

    property FileView prefs: FileView {
        path: Quickshell.env("HOME") + "/.config/dash/prefs"
        preload: true
        watchChanges: true
        onLoaded: card.readPrefs()
        onFileChanged: card.readPrefs()
    }

    function readPrefs() {
        const on = (prefs.text() || "").split("\n").map(l => l.trim());
        card.showScoped = ["1", "true", "yes"].some(v => on.includes("SHOW_SCOPED_QUOTAS=" + v));
    }

    // "84% · 1d left"; only a frozen snapshot writes its pace text
    // ("· stale 21h"), since its bar then draws no pace.
    function line(used, resets, pace) {
        if (used === null || used === undefined)
            return "–";
        const bits = [Math.round(used) + "%"];
        if (resets)
            bits.push(feed.dur(Math.max(0, resets - Math.floor(feed.now / 1000))) + " left");
        if (pace && pace.level === "stale")
            bits.push(pace.text);
        return bits.join(" · ");
    }

    function tick(pace) {
        return pace && pace.expected !== undefined && pace.expected !== null ? Math.min(100, Math.max(0, pace.expected)) : -1;
    }

    // The number agrees with its bar: pace decides, so 82% with a day to
    // spare is no alarm. Out of quota is red whatever the pace; only
    // with no pace to judge by does the 50/80 ladder speak.
    function tint(used, pace) {
        const level = pace && pace.level ? pace.level : "";
        if (used >= 100 || level === "exhaust")
            return card.colors.red;
        if (level === "risk")
            return card.colors.yellow;
        if (level === "ok" || level === "reserve" || used === null || used === undefined)
            return card.colors.fg;
        return used >= 80 ? card.colors.red : used >= 50 ? card.colors.yellow : card.colors.fg;
    }

    function late(name, src) {
        const ts = src && src.ts ? src.ts : 0;
        if (!ts)
            return name + " never synced";
        return feed.since(ts) > 900 ? name + " synced " + feed.ago(ts) : "";
    }

    title: "LLM"
    dimmed: feed.boardDown
    alert: feed.board ? [late("claude", c), or && or.month_limit ? late("openrouter", or) : ""].filter(s => s).join(" · ") : ""

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        DashQuota {
            colors: card.colors
            name: "claude " + (card.c && card.c.plan ? card.c.plan : "max")
            win: "week"
            url: "https://claude.ai/settings/usage"
            value: card.line(card.c?.used_7d, card.c?.resets_7d, card.c?.pace_7d)
            pct: card.c && card.c.used_7d !== null && card.c.used_7d !== undefined ? card.c.used_7d : -1
            pacePct: card.tick(card.c?.pace_7d)
            paceLevel: card.c?.pace_7d?.level ?? ""
            valueColor: card.tint(card.c?.used_7d, card.c?.pace_7d)
            onLaunch: (url, cmd) => card.launch(url, cmd)
        }

        // A personal month budget (OR_MONTHLY_LIMIT), so its $ rides the
        // name, not a plan tier.
        DashQuota {
            visible: !!card.or && !!card.or.month_limit
            colors: card.colors
            name: "openrouter $" + (card.or && card.or.month_limit ? (card.or.month_limit % 1 === 0 ? card.or.month_limit : card.or.month_limit.toFixed(2)) : "")
            win: "month"
            url: "https://openrouter.ai/activity"
            value: card.line(card.or?.pct_month, card.or?.resets_month, card.or?.pace_month)
            pct: card.or && card.or.pct_month !== null && card.or.pct_month !== undefined ? card.or.pct_month : -1
            pacePct: card.tick(card.or?.pace_month)
            paceLevel: card.or?.pace_month?.level ?? ""
            valueColor: card.tint(card.or?.pct_month, card.or?.pace_month)
            onLaunch: (url, cmd) => card.launch(url, cmd)
        }

        Repeater {
            model: card.showScoped && card.c && card.c.scoped ? card.c.scoped : []

            DashQuota {
                required property var modelData

                colors: card.colors
                name: modelData.model.toLowerCase()
                win: "week"
                value: card.line(modelData.pct, modelData.resets, modelData.pace)
                pct: modelData.pct !== null && modelData.pct !== undefined ? modelData.pct : -1
                pacePct: card.tick(modelData.pace)
                paceLevel: modelData.pace?.level ?? ""
                valueColor: card.tint(modelData.pct, modelData.pace)
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
