pragma Singleton

// The launcher's apps (#89): the desktop entries rofi's drun listed,
// searched as it searched them (fuzzy, over the name, generic name,
// command and keywords; Fuzzy.js) and ordered by how often each was
// launched. The counts live in the shell's state directory
// (launcher.json); the first run starts them from rofi's own history
// (~/.cache/rofi3.druncache), so the order carries over.
import QtQuick
import Quickshell
import Quickshell.Io
import "Fuzzy.js" as Fuzzy

Singleton {
    id: apps

    readonly property string terminal: "kitty"
    readonly property var entries: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    // Launches by desktop entry id.
    property var counts: ({})
    // No launcher.json yet: read rofi's history once.
    property bool seed: false

    // The best of the fields' scores, the name weighing most.
    function scoreOf(query, entry) {
        const command = (Array.from(entry.command)[0] ?? "").split("/").pop();
        return Math.max(Fuzzy.score(query, entry.name), Fuzzy.score(query, entry.genericName) - 4, Fuzzy.score(query, command) - 6, Fuzzy.score(query, Array.from(entry.keywords).join(" ")) - 6);
    }

    // Matches, best first; the most used break near-ties, and lead when
    // nothing is typed.
    function search(query) {
        const q = query.trim();
        const used = id => Math.log2(1 + (apps.counts[id] ?? 0));
        return apps.entries.map(entry => ({
                    entry: entry,
                    score: q === "" ? 0 : apps.scoreOf(q, entry)
                })).filter(r => r.score > -Infinity).map(r => ({
                    entry: r.entry,
                    rank: r.score + 1.5 * used(r.entry.id)
                })).sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name)).map(r => r.entry);
    }

    function launch(entry) {
        const next = Object.assign({}, apps.counts);
        next[entry.id] = (next[entry.id] ?? 0) + 1;
        apps.counts = next;
        store.setText(JSON.stringify({
            counts: next
        }, null, 1));
        // Terminal apps open in kitty, as rofi's sensible-terminal did.
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [apps.terminal, "-e"].concat(Array.from(entry.command)),
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    FileView {
        id: store
        path: Quickshell.statePath("launcher.json")
        printErrors: false
        onLoaded: {
            try {
                apps.counts = JSON.parse(text()).counts ?? {};
            } catch (error) {
                console.warn("launcher.json unreadable:", error);
            }
        }
        onLoadFailed: apps.seed = true
    }

    // "count id.desktop" per line.
    FileView {
        id: rofi
        path: apps.seed ? Quickshell.env("HOME") + "/.cache/rofi3.druncache" : ""
        printErrors: false
        onLoaded: {
            const seeded = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\d+)\s+(.+)\.desktop$/);
                if (m)
                    seeded[m[2]] = Number(m[1]);
            }
            apps.counts = seeded;
        }
    }
}
