// The bar's center island. At rest it shows what waybar's center showed:
// the player's icon with the title and artist, then the date and time.
// Rested on, clicked (or toggled over IPC) it opens into a sheet with the media
// controls beside the month. It grows out of the island itself, width
// and height together, and its header row never moves, so what the owner
// clicked stays under the pointer.
//
// While open the island holds the keyboard: Esc closes, Space plays or
// pauses, h and l (or the arrows) step through months.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: island

    required property var colors
    required property var bar
    property var player: null
    property bool open: false
    property date now: clock.date
    // How far right of the screen's center the island may reach at rest
    // (Bar.qml: short of the right island). Centered, it keeps both halves
    // in by cutting the track first, and drops it under 40px.
    property real room: Infinity
    readonly property real mediaRoom: Math.min(360, 2 * room - 12 - Theme.space.xs - time.width - Theme.space.sm * 2)

    readonly property bool hovered: pointer.hovered

    signal toggleRequested
    // The pointer has rested on the island.
    signal hoverRequested
    signal closeRequested

    readonly property bool hasTrack: player !== null && player.trackTitle !== ""
    readonly property int restHeight: 26
    readonly property int restWidth: header.width + 12
    readonly property int openWidth: Math.max(restWidth, hasTrack ? 600 : month.implicitWidth + 64)
    readonly property int openHeight: restHeight + 10 + body.height + 18
    // 0 at rest and 1 open, following the growth rather than the flag, so
    // what fades with it stays in step both ways.
    readonly property real progress: Math.max(0, Math.min(1, (height - restHeight) / (openHeight - restHeight)))

    width: open ? openWidth : restWidth
    height: open ? openHeight : restHeight

    Behavior on width {
        NumberAnimation {
            duration: island.open ? 260 : 200
            easing.type: island.open ? Easing.OutExpo : Easing.InOutCubic
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: island.open ? 260 : 200
            easing.type: island.open ? Easing.OutExpo : Easing.InOutCubic
        }
    }

    function blend(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    onOpenChanged: if (open) {
        month.offset = 0;
        island.forceActiveFocus();
    }

    HoverHandler {
        id: pointer
    }

    // Resting on it opens it; passing over does not.
    Timer {
        interval: island.bar.hoverDelay
        running: pointer.hovered && !island.open
        onTriggered: island.hoverRequested()
    }

    // Pinned by a click: the keyboard is the island's now.
    Connections {
        target: island.bar

        function onByHoverChanged() {
            if (island.open && !island.bar.byHover)
                island.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        if (!island.open)
            return;
        switch (event.key) {
        case Qt.Key_Escape:
            island.closeRequested();
            break;
        case Qt.Key_Space:
            if (island.hasTrack && island.player.canTogglePlaying)
                island.player.togglePlaying();
            break;
        case Qt.Key_H:
        case Qt.Key_Left:
            month.offset -= 1;
            break;
        case Qt.Key_L:
        case Qt.Key_Right:
            month.offset += 1;
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Hyprland's window shadow (range 4, bg_dim), as the polkit sheet
    // draws it; only the open sheet casts it.
    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radius.surface
        blur: 6
        color: Theme.surface.shadow
        opacity: island.progress
    }

    // The island's glass (bg0 at 0.88) at rest; open, it is a sheet over
    // windows, so it takes the sheets' bg_dim at 0.985 and its bg0
    // controls step lighter, as on the other overlays.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.surface
        color: island.blend(Theme.surface.glass, Theme.surface.sheet, island.progress)
        border.width: 1
        border.color: Theme.surface.outline
    }

    Row {
        id: header
        anchors.horizontalCenter: parent.horizontalCenter
        y: 1
        spacing: Theme.space.xs

        // Waybar's mpris: a click opens the island; right is next track,
        // middle the previous one, as before. Material Symbols have no
        // brands, so the player shows as what it plays (#89).
        BarButton {
            id: media

            function iconFor(player) {
                if (!player.isPlaying)
                    return "pause";
                const name = (player.desktopEntry || player.identity || "").toLowerCase();
                if (name.includes("mpv") || name.includes("vlc"))
                    return "movie";
                if (name.includes("firefox") || name.includes("chrome"))
                    return "public";
                return "music_note";
            }

            visible: island.hasTrack && island.mediaRoom >= 40
            bar: island.bar
            icon: island.hasTrack ? iconFor(island.player) : ""
            text: island.hasTrack ? [island.player.trackTitle, island.player.trackArtist].filter(s => s !== "").join(" · ") : ""
            // Waybar cut its line at 45 characters.
            maxWidth: island.mediaRoom - iconSize - Theme.space.xs
            tint: island.player?.isPlaying ? Theme.colors.fg : Theme.colors.grey2
            onClicked: island.toggleRequested()
            onRightClicked: island.player.next()
            onMiddleClicked: island.player.previous()
        }

        BarButton {
            id: time
            bar: island.bar
            bold: true
            text: Qt.formatDateTime(island.now, "ddd MMM dd  HH:mm")
            tint: Theme.colors.fg
            onClicked: island.toggleRequested()
        }
    }

    // The sheet's body, laid out at its open size and revealed by the
    // growing island; it fades in once the growth is under way.
    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: body
            anchors.horizontalCenter: parent.horizontalCenter
            y: island.restHeight + 10
            width: island.openWidth - 32
            // A four-week month is shorter than the media column.
            height: Math.max(month.implicitHeight, mediaCard.item?.implicitHeight ?? 0)
            opacity: island.open ? 1 : 0
            visible: opacity > 0
            enabled: island.open

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: island.open ? 80 : 0
                    }
                    NumberAnimation {
                        duration: island.open ? 180 : 100
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Loader {
                id: mediaCard
                active: island.hasTrack
                width: body.width - month.width - 28

                sourceComponent: MediaCard {
                    colors: island.colors
                    player: island.player
                    watching: island.open
                }
            }

            MonthGrid {
                id: month
                x: island.hasTrack ? body.width - width : (body.width - width) / 2
                colors: island.colors
                today: island.now
            }
        }
    }
}
