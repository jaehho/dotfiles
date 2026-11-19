// A number animation on the shell's motion tokens (Theme.motion).
// `speed` is fast, normal or slow; `curve` is standard (moving within
// the screen), enter (arriving) or exit (leaving).
import QtQuick

NumberAnimation {
    property string speed: "normal"
    property string curve: "standard"

    duration: Theme.motion[speed]
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.motion[curve]
}
