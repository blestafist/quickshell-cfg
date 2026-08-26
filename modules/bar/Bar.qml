import QtQuick
import Quickshell
import Quickshell.Io

import "../../components" as Components
import "../../config" as Config
import "../../theme" as Theme

PanelWindow {
    id: root

    property var stats
    property var launcher
    property var targetScreen: Quickshell.screens.find(screen => screen.name === Config.MachineConfig.primaryMonitor)
    screen: targetScreen
    visible: targetScreen !== null
    anchors { top: true; left: true; right: true }
    margins { top: Config.ShellConfig.barMargin; left: Config.ShellConfig.barMargin; right: Config.ShellConfig.barMargin }
    exclusiveZone: Config.ShellConfig.barHeight + Config.ShellConfig.barMargin
    implicitHeight: Config.ShellConfig.barHeight
    color: "transparent"

    Components.Surface {
        anchors.fill: parent
        surfaceRadius: Theme.Theme.radiusLarge

        Components.IconButton {
            id: distro
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            icon: ""
            tooltip: "Open launcher"
            onClicked: root.launcher.open()
            onRightClicked: root.launcher.showMessage("Configurator is planned for a later release")
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), Config.ShellConfig.clockFormat)
            color: Theme.Theme.textPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Components.StatusItem { icon: "󰍛"; value: root.stats.cpu; accessibleName: "CPU usage" }
            Components.StatusItem { icon: "󰘚"; value: root.stats.memory; accessibleName: "Memory usage" }
            Components.StatusItem { icon: "󰢮"; value: root.stats.gpu; accessibleName: "GPU usage" }
            Rectangle { width: 1; height: 16; color: Theme.Theme.surfaceHover; anchors.verticalCenter: parent.verticalCenter }
            Components.StatusItem { icon: root.stats.network === "Offline" ? "󰤭" : "󰤨"; value: root.stats.network; accessibleName: "Network"; onClicked: networkSettings.running = true }
            Components.StatusItem { icon: root.stats.muted ? "󰝟" : "󰕾"; value: root.stats.muted ? "Muted" : root.stats.volume; accessibleName: "Audio volume"; onClicked: volumeToggle.running = true }
            Components.StatusItem { icon: "󰌌"; value: root.stats.keyboardLayout; accessibleName: "Keyboard layout"; accentValue: true; onClicked: layoutSwitch.running = true }
            Components.IconButton { icon: "⏻"; onClicked: root.launcher.showMessage("Power menu is planned for a later release") }
        }
    }

    Process { id: networkSettings; command: ["sh", "-c", Config.ShellConfig.networkSettingsCommand] }
    Process { id: volumeToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: layoutSwitch; command: ["hyprctl", "switchxkblayout", "current", "next"] }
}
