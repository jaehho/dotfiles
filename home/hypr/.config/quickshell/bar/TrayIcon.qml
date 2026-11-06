// A tray item's icon. Quickshell 0.3.2 reads an item's IconThemePath as
// one flat folder of files named exactly as the icon, but the apps that
// ship a theme of their own (asst, easel, steno) lay it out as the spec
// allows, under hicolor/scalable/<context>/, and Spotify's files carry
// an extension. Quickshell then draws its missing-icon square, which
// does not fail as an image would, so such icons are looked up here
// file by file; everything else goes through the icon theme as usual.
import QtQuick
import Quickshell.Widgets

Item {
    id: icon

    required property string source
    // [request, name, theme path] for an icon in an app's own theme.
    readonly property var themed: source.match(/^image:\/\/icon\/([^?]+)\?path=(.+)$/)
    readonly property var candidates: themed ? [...["status", "apps", "actions", "devices"].map(context => `file://${themed[2]}/hicolor/scalable/${context}/${themed[1]}.svg`), `file://${themed[2]}/${themed[1]}.png`, `file://${themed[2]}/${themed[1]}.svg`, source] : []
    property int attempt: 0

    onSourceChanged: attempt = 0

    implicitWidth: 16
    implicitHeight: 16

    IconImage {
        visible: !icon.themed
        anchors.fill: parent
        source: icon.themed ? "" : icon.source
    }

    Image {
        visible: icon.themed !== null
        anchors.fill: parent
        sourceSize: Qt.size(icon.width * 2, icon.height * 2)
        source: icon.candidates[icon.attempt] ?? ""
        // Later, not inside the binding that is still settling.
        onStatusChanged: if (status === Image.Error && icon.attempt < icon.candidates.length - 1)
            Qt.callLater(() => icon.attempt += 1)
    }
}
