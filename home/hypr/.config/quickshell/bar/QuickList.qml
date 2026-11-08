// A page's list on the quick settings sheet, scrolling past its height:
// its rows sit inset by the focus ring's reach so the clip never cuts a
// ring, a thin bg3 bar shows where the view is, and the list fades into
// the sheet while there is more below.
import QtQuick

Flickable {
    id: scroller

    required property var colors
    default property alias rows: column.data
    property real maxHeight: 304
    readonly property real rowWidth: column.width

    width: parent.width
    height: Math.min(contentHeight, maxHeight)
    contentHeight: column.implicitHeight
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        x: 3
        width: scroller.width - 6 - (scroller.interactive ? 6 : 0)
        topPadding: 3
        bottomPadding: 3
        spacing: 2
    }

    Rectangle {
        y: scroller.contentY + scroller.height - height
        width: scroller.width
        height: 24
        visible: scroller.interactive && !scroller.atYEnd
        gradient: Gradient {
            GradientStop {
                position: 0
                color: scroller.colors.withAlpha(scroller.colors.bg_dim, 0)
            }
            GradientStop {
                position: 1
                color: scroller.colors.withAlpha(scroller.colors.bg_dim, 0.985)
            }
        }
    }

    Rectangle {
        visible: scroller.interactive
        x: scroller.width - 3
        y: scroller.contentY + scroller.visibleArea.yPosition * scroller.height
        width: 3
        height: scroller.visibleArea.heightRatio * scroller.height
        radius: 1.5
        color: scroller.colors.bg3
    }
}
