import QtQuick

import "../../theme" as Theme

Column {
    id: root

    property date now: new Date()
    property bool large: false

    spacing: 12

    Text {
        width: parent.width
        text: Qt.formatTime(root.now, "HH:mm")
        color: Theme.Theme.textPrimary
        font.family: "Product Sans"
        font.pixelSize: Math.min(root.large ? 156 : 112, root.width * 0.3)
        font.weight: Font.Light
        font.letterSpacing: -3
    }

    Text {
        width: parent.width
        text: Qt.formatDate(root.now, "dddd, d MMMM")
        color: Theme.Theme.textSecondary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        font.capitalization: Font.Capitalize
        wrapMode: Text.Wrap
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
