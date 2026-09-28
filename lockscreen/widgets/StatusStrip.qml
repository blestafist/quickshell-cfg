import QtQuick
import Quickshell.Services.UPower

import "../../theme" as Theme

Row {
    id: root

    readonly property var battery: UPower.displayDevice
    spacing: 18

    Text {
        text: "ENDEAVOUROS"
        color: Theme.Theme.textMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 3
        radius: 2
        color: Theme.Theme.accent
    }

    Text {
        visible: root.battery && root.battery.isPresent && root.battery.isLaptopBattery
        text: "󰁹  " + Math.round(root.battery.percentage * 100) + "%"
        color: Theme.Theme.textMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
    }
}
