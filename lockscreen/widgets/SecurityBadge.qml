import QtQuick

import "../../theme" as Theme

Rectangle {
    id: root

    property bool secure: false
    property bool preview: false

    implicitWidth: badgeRow.implicitWidth + 24
    implicitHeight: 32
    radius: 16
    color: Qt.rgba(Theme.Theme.surfaceRaised.r, Theme.Theme.surfaceRaised.g, Theme.Theme.surfaceRaised.b, 0.88)
    border.width: 1
    border.color: secure ? Qt.rgba(Theme.Theme.accent.r, Theme.Theme.accent.g, Theme.Theme.accent.b, 0.45) : Theme.Theme.danger

    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.secure ? "󰌾" : "󰌿"
            color: root.secure ? Theme.Theme.accent : Theme.Theme.danger
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        Text {
            text: root.preview ? "PREVIEW / NOT LOCKED" : root.secure ? "SESSION SECURED" : "SECURING SESSION"
            color: Theme.Theme.textSecondary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }
    }
}
