// The bar's center island. At rest it shows what waybar's center showed:
// the player glyph with the title and artist, then the date and time.
// Clicked (or toggled over IPC) it opens into a sheet with the media
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
    property var player: null
    property bool open: false
    property date now: clock.date

    signal toggleRequested
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
        radius: 12
        blur: 6
        color: island.colors.withAlpha(island.colors.bg_dim, 0.93)
        opacity: island.progress
    }

    // The island's glass (bg0 at 0.88) at rest; open, it is a sheet over
    // windows, so it takes the sheets' bg_dim at 0.985 and its bg0
    // controls step lighter, as on the other overlays.
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: island.blend(island.colors.withAlpha(island.colors.bg0, 0.88), island.colors.withAlpha(island.colors.bg_dim, 0.985), island.progress)
        border.width: 1
        border.color: island.colors.withAlpha(island.colors.blue, 0.18)
    }

    Row {
        id: header
        anchors.horizontalCenter: parent.horizontalCenter
        y: 1
        spacing: 4

        // Waybar's mpris: a click opens the island; right is next track,
        // middle the previous one, as before.
        Rectangle {
            id: media
            visible: island.hasTrack
            width: mediaText.width + 14
            height: 24
            radius: 8
            color: mediaHover.hovered ? island.colors.withAlpha(island.colors.blue, 0.14) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            HoverHandler {
                id: mediaHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onTapped: (eventPoint, button) => {
                    if (button === Qt.RightButton)
                        island.player.next();
                    else if (button === Qt.MiddleButton)
                        island.player.previous();
                    else
                        island.toggleRequested();
                }
            }

            Line {
                id: mediaText
                anchors.centerIn: parent
                // Waybar cut its line at 45 characters.
                width: Math.min(implicitWidth, 360)
                elide: Text.ElideRight
                mono: true
                text: island.hasTrack ? String.fromCodePoint(island.player.isPlaying ? glyphFor(island.player) : 0xf03e4) + " " + [island.player.trackTitle, island.player.trackArtist].filter(s => s !== "").join(" · ") : ""
                color: island.player?.isPlaying || mediaHover.hovered ? island.colors.fg : island.colors.grey2

                // The player icons waybar's mpris module used.
                function glyphFor(player) {
                    const name = (player.desktopEntry || player.identity || "").toLowerCase();
                    if (name.includes("spotify"))
                        return 0xf04c7;
                    if (name.includes("mpv") || name.includes("vlc"))
                        return 0xf040c;
                    if (name.includes("vesktop") || name.includes("discord"))
                        return 0xf066f;
                    if (name.includes("firefox"))
                        return 0xf0239;
                    if (name.includes("chrome"))
                        return 0xf02af;
                    return 0xf040a;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }

        Rectangle {
            width: timeText.width + 14
            height: 24
            radius: 8
            color: timeHover.hovered ? island.colors.withAlpha(island.colors.blue, 0.14) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            HoverHandler {
                id: timeHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: island.toggleRequested()
            }

            Line {
                id: timeText
                anchors.centerIn: parent
                mono: true
                weight: Font.Bold
                text: Qt.formatDateTime(island.now, "ddd MMM dd  HH:mm")
                color: island.colors.fg
            }
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
