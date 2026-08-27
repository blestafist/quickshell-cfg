import QtQuick

import "../theme" as Theme

Rectangle {
    id: root

    property string icon: ""
    property string value: ""
    property string accessibleName: ""
    property bool accentValue: false
    signal clicked()

    implicitWidth: content.width + 20
    implicitHeight: 30
    radius: Theme.Theme.radiusSmall
    color: mouse.containsMouse ? Theme.Theme.surfaceHover : "transparent"

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Text { height: 30; text: root.icon; color: Theme.Theme.textMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
        Text { height: 30; text: root.value; color: root.accentValue ? Theme.Theme.accent : Theme.Theme.textPrimary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold; verticalAlignment: Text.AlignVCenter }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
