pragma ComponentBehavior: Bound

// The hangul hint's board (#89, DESIGN.md Keycaps): the 2-set layout
// over the QWERTY letter keys, from hypr-hangul-hint's layout. A key is
// a 56px keycap on a 62px pitch, bg2 with a bg3 edge and a 3px bg_dim
// lip; the jamo in the middle, the Latin letter in its corner, the
// shifted jamo opposite, and F and J carry the home bump. A pressed key
// lights solid green at once and fades back as it is let go.
//
// Floating, the board is glass that clears around the pointer (`hole`)
// so what is under the mouse can be seen; docked, it is just the keys,
// and the window draws the strip.
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: board

    // {rows: [[[latin, jamo, shifted]]], offsets: [...], bumps: [...]}
    property var layout: null
    // Letters held down now.
    property var lit: ({})
    property bool docked: false
    // The pointer in the board's own pixels, or null.
    property var hole: null

    readonly property var rows: layout?.rows ?? []
    readonly property var offsets: layout?.offsets ?? []
    readonly property int pitch: 62
    readonly property int keySize: 56
    readonly property int pad: docked ? Theme.space.sm : Theme.space.lg
    readonly property int holeRadius: 96
    readonly property string hangulFont: "Noto Sans CJK KR"
    readonly property real keysWidth: rows.reduce((w, row, i) => Math.max(w, (row.length - 1 + (offsets[i] ?? 0)) * pitch + keySize), 0)
    readonly property real keysHeight: rows.length > 0 ? (rows.length - 1) * pitch + keySize : 0

    implicitWidth: keysWidth + pad * 2
    implicitHeight: keysHeight + pad * 2

    Item {
        id: content

        anchors.fill: parent
        visible: board.hole === null

        // The glass: bg_dim at 0.72 so the keys read over any window, and
        // the shell's outline.
        Rectangle {
            visible: !board.docked
            anchors.fill: parent
            radius: Theme.radius.surface
            color: Theme.colors.withAlpha(Theme.colors.bg_dim, 0.72)
            border.width: 1
            border.color: Theme.surface.outline
        }

        Item {
            x: board.pad
            y: board.pad
            width: board.keysWidth
            height: board.keysHeight

            Repeater {
                model: board.rows

                Item {
                    id: line

                    required property var modelData
                    required property int index

                    Repeater {
                        model: line.modelData

                        HangulKey {
                            required property var modelData
                            required property int index

                            x: (index + (board.offsets[line.index] ?? 0)) * board.pitch
                            y: line.index * board.pitch
                            latin: modelData[0]
                            jamo: modelData[1]
                            shifted: modelData[2]
                        }
                    }
                }
            }
        }
    }

    // The clear patch around the pointer: almost see-through at it, back
    // to solid at holeRadius, so the board never has an edge there.
    RadialGradient {
        id: mask

        anchors.fill: content
        visible: false
        horizontalOffset: (board.hole?.[0] ?? 0) - width / 2
        verticalOffset: (board.hole?.[1] ?? 0) - height / 2
        horizontalRadius: board.holeRadius
        verticalRadius: board.holeRadius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.07)
            }
            GradientStop {
                position: 0.4
                color: Qt.rgba(0, 0, 0, 0.1)
            }
            GradientStop {
                position: 0.7
                color: Qt.rgba(0, 0, 0, 0.55)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 1)
            }
        }
    }

    OpacityMask {
        anchors.fill: content
        visible: board.hole !== null
        source: content
        maskSource: mask
    }

    component HangulKey: Item {
        id: key

        property string latin
        property string jamo
        property string shifted
        readonly property bool on: board.lit[latin] === true

        width: board.keySize
        height: board.keySize

        // The lip, showing 3px under the face.
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.control
            color: key.on ? Qt.darker(Theme.colors.green, 1.6) : Theme.colors.bg_dim
        }

        Rectangle {
            width: parent.width
            height: parent.height - 3
            radius: Theme.radius.control
            color: key.on ? Theme.colors.green : Theme.colors.withAlpha(Theme.colors.bg2, 0.94)
            border.width: 1
            border.color: key.on ? Theme.colors.green : Theme.colors.bg3

            // At once on, calmly off.
            Behavior on color {
                enabled: !key.on

                CAnim {
                    speed: "normal"
                }
            }

            Text {
                anchors.centerIn: parent
                text: key.jamo
                color: key.on ? Theme.colors.bg_dim : Theme.colors.fg
                font.family: board.hangulFont
                font.pixelSize: 28
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                visible: key.shifted !== ""
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 6
                anchors.topMargin: 3
                text: key.shifted
                color: key.on ? Theme.colors.withAlpha(Theme.colors.bg_dim, 0.7) : Theme.colors.grey2
                font.family: board.hangulFont
                font.pixelSize: 13
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Line {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 6
                anchors.bottomMargin: 3
                text: key.latin.toUpperCase()
                mono: true
                size: 10
                weight: Font.Bold
                color: key.on ? Theme.colors.withAlpha(Theme.colors.bg_dim, 0.7) : Theme.colors.grey2
            }

            // The home bump.
            Rectangle {
                visible: (board.layout?.bumps ?? []).includes(key.latin)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                width: 20
                height: 3
                radius: Theme.radius.pill
                color: key.on ? Theme.colors.withAlpha(Theme.colors.bg_dim, 0.6) : Theme.colors.grey1
            }
        }
    }
}
