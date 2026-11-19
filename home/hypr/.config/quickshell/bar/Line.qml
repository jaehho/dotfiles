// Text in one of the desktop's two faces: Adwaita Sans for words,
// JetBrainsMono Nerd Font for glyphs, numerals and the bar itself.
import QtQuick

Text {
    property int size: Theme.font.body
    property int weight: Font.Normal
    property bool mono: false

    font.family: mono ? Theme.font.mono : Theme.font.sans
    font.pixelSize: size
    font.weight: weight
    renderType: Text.NativeRendering
}
