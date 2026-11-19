// A Material Symbols Rounded glyph (#89), named by its ligature, e.g.
// `name: "notifications"`. `fill` runs from 0 (outlined) to 1 (filled)
// and animates, so a toggle can fill in as it turns on.
import QtQuick

Text {
    id: icon

    property string name: ""
    property int size: Theme.icon.normal
    property real fill: 0
    property int weight: 400

    text: name
    color: Theme.colors.fg
    font.family: Theme.font.icons
    font.pixelSize: size
    font.weight: weight
    font.variableAxes: ({
            "FILL": icon.fill,
            "wght": icon.weight,
            "opsz": Math.max(20, Math.min(48, icon.size))
        })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on fill {
        Anim {
            speed: "fast"
        }
    }
}
