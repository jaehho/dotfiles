// The open island's media column: cover art, the track, a progress meter
// and the transport controls, for the player NowPlaying picked.
import QtQuick
import Quickshell.Widgets

Item {
    id: card

    required property var colors
    required property var player
    // True while the island is open, so the position is worth polling.
    property bool watching: false

    implicitHeight: column.implicitHeight

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    readonly property real fraction: card.player.lengthSupported && card.player.length > 0 ? Math.min(1, card.player.position / card.player.length) : 0

    // MPRIS pushes only jumps in position, so it is polled while shown
    // (Quickshell's documented pattern). A paused track is read once.
    Timer {
        running: card.watching && card.player.isPlaying
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: card.player.positionChanged()
    }
    onWatchingChanged: if (watching)
        card.player.positionChanged()

    Column {
        id: column
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            spacing: 14

            ClippingRectangle {
                id: frame
                width: 96
                height: 96
                radius: 8
                color: card.colors.bg1

                Image {
                    id: art
                    anchors.fill: parent
                    source: card.player.trackArtUrl
                    sourceSize: Qt.size(192, 192)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                // Music note, while the cover loads or when there is none.
                Line {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    mono: true
                    size: 28
                    text: String.fromCodePoint(0xf075a)
                    color: card.colors.grey2
                }
            }

            Column {
                width: parent.width - frame.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Line {
                    width: parent.width
                    text: card.player.trackTitle
                    size: 15
                    weight: Font.DemiBold
                    color: card.colors.fg
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Line {
                    width: parent.width
                    text: card.player.trackArtist
                    visible: text !== ""
                    color: card.colors.grey2
                    elide: Text.ElideRight
                }

                Line {
                    width: parent.width
                    text: card.player.trackAlbum
                    visible: text !== ""
                    color: card.colors.grey2
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            visible: card.player.lengthSupported

            // A 4px meter in a 12px hit strip; a click seeks when the
            // player allows it.
            Item {
                width: parent.width
                height: 12

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: card.colors.bg1

                    Rectangle {
                        width: track.width * card.fraction
                        height: parent.height
                        radius: 2
                        color: card.colors.fg
                    }
                }

                HoverHandler {
                    cursorShape: card.player.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    enabled: card.player.canSeek && card.player.positionSupported
                    onTapped: eventPoint => {
                        card.player.position = eventPoint.position.x / track.width * card.player.length;
                    }
                }
            }

            Item {
                width: parent.width
                height: times.implicitHeight

                Line {
                    id: times
                    mono: true
                    size: 11
                    text: card.clock(card.player.position)
                    color: card.colors.grey2
                }

                Line {
                    anchors.right: parent.right
                    mono: true
                    size: 11
                    text: card.clock(card.player.length)
                    color: card.colors.grey2
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            SheetButton {
                colors: card.colors
                glyph: 0xf04ae
                enabled: card.player.canGoPrevious
                onClicked: card.player.previous()
            }

            SheetButton {
                colors: card.colors
                glyph: card.player.isPlaying ? 0xf03e4 : 0xf040a
                implicitWidth: 52
                enabled: card.player.canTogglePlaying
                onClicked: card.player.togglePlaying()
            }

            SheetButton {
                colors: card.colors
                glyph: 0xf04ad
                enabled: card.player.canGoNext
                onClicked: card.player.next()
            }
        }
    }
}
