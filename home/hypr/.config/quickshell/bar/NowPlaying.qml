// The player the bar shows: the first one playing, else the first with a
// track loaded (a paused Spotify), else none. A browser tab that exposes
// MPRIS with no title (Chromium does) never counts.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: nowPlaying

    readonly property var player: nowPlaying.pick(Mpris.players.values)

    function pick(players) {
        const loaded = players.filter(p => p.trackTitle !== "");
        return loaded.find(p => p.isPlaying) ?? loaded[0] ?? null;
    }
}
