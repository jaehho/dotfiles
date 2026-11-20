pragma ComponentBehavior: Bound

// One notification as a card (#90), the same in the popups and in the
// center: the sender's picture or icon, its name and age, the summary,
// the body and the action buttons.
//
// A click runs the default action (Notifs.activate). Dragging it
// sideways past a third of its width dismisses it. The pointer over it
// holds its popup timer, and shows the close button and, when the text
// is cut, the expand button. Critical ones carry a red edge.
//
// `popup` draws it as its own sheet, with a shadow, for the popups; in
// the center it is a card on the center's sheet. `selected` is the
// center's keyboard row, and `keys` shows the action keys on its
// buttons.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: card

    required property var entry
    property bool popup: false
    property bool selected: false
    property bool keys: false
    property bool expanded: false
    readonly property bool hovered: hover.hovered

    readonly property color accent: entry.critical ? Theme.colors.red : Theme.colors.blue
    // notify-send -i sends an image-path, which Quickshell serves as
    // image://icon/<it>: a theme icon name is the app's icon, not a
    // picture; a path (image://icon//home/...) is a picture.
    readonly property bool themedImage: /^image:\/\/icon\/[^\/]/.test(card.entry.image)
    readonly property string picture: card.themedImage ? "" : card.entry.image
    readonly property string iconSource: {
        const icon = card.entry.appIcon;
        if (icon === "")
            return card.themedImage ? card.entry.image : "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (/^(file|image|https?):/.test(icon))
            return icon;
        return Quickshell.iconPath(icon, true);
    }
    // Keys for the action buttons, as swaync's fork labelled them.
    readonly property var actionKeys: ["<", ">", "3", "4", "5", "6", "7", "8", "9"]
    // The buttons: the sender's actions, then Copy for a one-time code.
    readonly property var buttons: card.entry.actions.concat(card.entry.otp !== "" ? [
            {
                id: "otp",
                text: `Copy ${card.entry.otp}`
            }
        ] : [])

    implicitHeight: content.implicitHeight

    // Keep the entry this card was made for: a list drops the model
    // value to null while the card is still fading out. And hold it, so
    // a dismissed entry lives until the last card drawing it has gone
    // (Notifs.drop): the center's exit animation stops while the center
    // is unmapped, so a card closed with it outlives the dismissal until
    // the next open (#90).
    Component.onCompleted: {
        card.entry = card.entry;
        card.entry.cards++;
    }

    Component.onDestruction: {
        if (card.entry)
            card.entry.cards--;
    }

    onHoveredChanged: card.entry.held = hovered

    HoverHandler {
        id: hover
    }

    Item {
        id: content

        width: card.width
        implicitHeight: column.implicitHeight + Theme.space.md * 2

        // Back where it was after a drag that did not go far enough.
        Behavior on x {
            enabled: !drag.active
            Anim {}
        }

        DragHandler {
            id: drag
            yAxis.enabled: false
            xAxis.enabled: true
            onActiveChanged: {
                if (active)
                    return;
                if (Math.abs(content.x) > card.width / 3)
                    Notifs.dismiss(card.entry);
                else
                    content.x = 0;
            }
        }

        Sheet {
            visible: card.popup
            anchors.fill: parent
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.surface
            color: card.popup ? "transparent" : Theme.surface.card
            border.width: card.entry.critical ? 1 : 0
            border.color: Theme.colors.withAlpha(Theme.colors.red, 0.5)

            StateLayer {
                selected: card.selected
                onClicked: () => Notifs.activate(card.entry, "default")
            }
        }

        RowLayout {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.space.md
            spacing: Theme.space.md

            // The sender's picture, else its icon, else a bell, in a
            // round frame; a picture wears the app icon as a badge.
            Item {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius.pill
                    color: Theme.colors.withAlpha(card.accent, 0.14)
                    visible: card.picture === ""
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.radius.pill
                    color: "transparent"
                    visible: card.picture !== ""

                    Image {
                        anchors.fill: parent
                        source: card.picture
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(80, 80)
                        asynchronous: true
                    }
                }

                IconImage {
                    id: appIcon
                    readonly property bool badge: card.picture !== ""

                    visible: card.iconSource !== "" && status !== Image.Error
                    implicitSize: badge ? 18 : 24
                    anchors.centerIn: badge ? undefined : parent
                    anchors.right: badge ? parent.right : undefined
                    anchors.bottom: badge ? parent.bottom : undefined
                    anchors.margins: -2
                    source: card.iconSource
                    asynchronous: true
                }

                Icon {
                    visible: card.picture === "" && !appIcon.visible
                    anchors.centerIn: parent
                    name: card.entry.critical ? "priority_high" : "notifications"
                    fill: 1
                    color: card.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                // "App · 5m"; a long name gives way, the age never does.
                Row {
                    id: header

                    Layout.fillWidth: true
                    // The buttons float over this row's end; keep the
                    // text out from under them.
                    Layout.rightMargin: tools.width
                    spacing: Theme.space.xs

                    Line {
                        width: Math.min(implicitWidth, header.width - age.implicitWidth - header.spacing * 2 - dot.implicitWidth)
                        elide: Text.ElideRight
                        text: card.entry.appName || "Notification"
                        size: Theme.font.small
                        color: Theme.colors.grey2
                    }

                    Line {
                        id: dot
                        text: "·"
                        size: Theme.font.small
                        color: Theme.colors.grey2
                    }

                    Line {
                        id: age
                        text: Notifs.ago(card.entry.time)
                        size: Theme.font.small
                        color: Theme.colors.grey2
                    }
                }

                Line {
                    id: summary
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.entry.summary
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? 100 : 2
                    elide: Text.ElideRight
                    size: Theme.font.body
                    weight: Font.DemiBold
                    color: Theme.colors.fg
                }

                Line {
                    id: body
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.entry.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? 100 : 3
                    elide: Text.ElideRight
                    size: Theme.font.body
                    color: Theme.colors.grey2
                    linkColor: Theme.colors.blue
                    onLinkActivated: link => Qt.openUrlExternally(link)

                    HoverHandler {
                        enabled: body.hoveredLink !== ""
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // The `value` hint, as a thin bar.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space.xs
                    visible: card.entry.progress >= 0
                    implicitHeight: 4
                    radius: Theme.radius.pill
                    color: Theme.colors.withAlpha(card.accent, 0.18)

                    Rectangle {
                        width: parent.width * card.entry.progress / 100
                        height: parent.height
                        radius: Theme.radius.pill
                        color: card.accent

                        Behavior on width {
                            Anim {}
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space.sm
                    visible: card.buttons.length > 0
                    spacing: Theme.space.xs + 2

                    Repeater {
                        model: card.buttons

                        PillButton {
                            required property var modelData
                            required property int index

                            // Equal shares, whatever the labels.
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            text: modelData.text
                            tint: card.accent
                            badge: card.keys && index < card.actionKeys.length ? card.actionKeys[index] : ""
                            onClicked: Notifs.activate(card.entry, modelData.id)
                        }
                    }
                }
            }
        }

        // Close, and expand when the text is cut, over the header's end.
        Row {
            id: tools

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.space.xs
            opacity: card.hovered || card.selected ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    speed: "fast"
                }
            }

            IconButton {
                visible: card.expanded || summary.truncated || body.truncated
                icon: card.expanded ? "expand_less" : "expand_more"
                size: Theme.icon.small
                onClicked: card.expanded = !card.expanded
            }

            IconButton {
                icon: "close"
                size: Theme.icon.small
                onClicked: Notifs.dismiss(card.entry)
            }
        }
    }
}
