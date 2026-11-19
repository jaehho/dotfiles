// A colour animation on the shell's motion tokens (Theme.motion); see
// Anim.qml. Colour changes are state feedback, so fast by default.
import QtQuick

ColorAnimation {
    property string speed: "fast"
    property string curve: "standard"

    duration: Theme.motion[speed]
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.motion[curve]
}
