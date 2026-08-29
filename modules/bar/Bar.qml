import QtQuick
import QtQuick.Shapes
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
    property date currentTime: new Date()
    property int barHeight: 42
    property int edgeRadius: 21
    property int islandRadius: 24
    property bool showMemoryGigabytes: false
    property bool showFullDate: false

    screen: targetScreen
    visible: targetScreen !== null
    anchors { top: true; left: true; right: true }
    margins { top: 0; left: 0; right: 0 }
    exclusiveZone: barHeight
    implicitHeight: barHeight
    color: "transparent"

    Item {
        id: leftCluster
        anchors.left: parent.left
        anchors.top: parent.top
        width: leftContent.width + root.edgeRadius + 18
        height: root.barHeight

        Behavior on width {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation { duration: 420; easing.type: Easing.OutBack }
        }

        Shape {
            anchors.fill: parent
            antialiasing: false
            ShapePath {
                fillColor: Theme.Theme.surface
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: leftCluster.width; y: 0 }
                PathLine { x: leftCluster.width; y: leftCluster.height - root.edgeRadius }
                PathQuad { x: leftCluster.width - root.edgeRadius; y: leftCluster.height; controlX: leftCluster.width; controlY: leftCluster.height }
                PathLine { x: 0; y: leftCluster.height }
            }
        }

        Row {
            id: leftContent
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Rectangle {
                id: distro
                property real iconOffsetX: -3
                property real iconOffsetY: 0

                width: 42
                height: 34
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.Theme.radiusSmall
                color: distroMouse.containsMouse ? Theme.Theme.surfaceHover : "transparent"

                Text {
                    anchors.fill: parent
                    text: ""
                    color: Theme.Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    transform: Translate {
                        x: distro.iconOffsetX
                        y: distro.iconOffsetY
                    }
                }

                MouseArea {
                    id: distroMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            root.launcher.showMessage("Configurator is planned for a later release")
                        else
                            root.launcher.open()
                    }
                }
            }

            Rectangle {
                id: distroGap
                width: 12
                height: 1
                color: "transparent"
            }

            Rectangle {
                width: 1
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.Theme.surfaceHover
            }

            Rectangle {
                width: distroGap.width + Math.abs(distro.iconOffsetX)
                height: 1
                color: "transparent"
            }

            Item {
                id: clockButton

                property real hoverOffset: 48

                width: clockText.implicitWidth + hoverOffset
                height: 34
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.Theme.radiusSmall
                    color: clockMouse.containsMouse ? Theme.Theme.surfaceHover : "transparent"

                    Behavior on color {
                        enabled: Config.ShellConfig.animationsEnabled
                        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(root.currentTime, root.showFullDate ? Config.ShellConfig.fullClockFormat : Config.ShellConfig.clockFormat)
                    color: Theme.Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.showFullDate = !root.showFullDate
                }
            }
        }

    }

    Item {
        id: musicIsland
        property real clickScale: 1
        property real naturalWidth: root.stats.music === "" ? 0 : Math.min(560, musicContent.implicitWidth + 68)
        property color backgroundColor: musicMouse.containsMouse ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: naturalWidth * clickScale
        height: root.barHeight
        opacity: root.stats.music === "" ? 0 : 1
        visible: width > 0
        clip: true

        Shape {
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                fillColor: musicIsland.backgroundColor
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0
                startY: 0
                PathLine { x: musicIsland.width; y: 0 }
                PathLine { x: musicIsland.width; y: musicIsland.height - root.islandRadius }
                PathCubic {
                    x: musicIsland.width - root.islandRadius
                    y: musicIsland.height
                    control1X: musicIsland.width
                    control1Y: musicIsland.height - root.islandRadius * 0.448
                    control2X: musicIsland.width - root.islandRadius * 0.448
                    control2Y: musicIsland.height
                }
                PathLine { x: root.islandRadius; y: musicIsland.height }
                PathCubic {
                    x: 0
                    y: musicIsland.height - root.islandRadius
                    control1X: root.islandRadius * 0.448
                    control1Y: musicIsland.height
                    control2X: 0
                    control2Y: musicIsland.height - root.islandRadius * 0.448
                }
                PathLine { x: 0; y: 0 }
            }
        }

        Behavior on width {
            enabled: Config.ShellConfig.animationsEnabled && !musicClickAnimation.running
            NumberAnimation { duration: 420; easing.type: Easing.OutBack }
        }

        Behavior on backgroundColor {
            enabled: Config.ShellConfig.animationsEnabled
            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Row {
            id: musicContent
            anchors.centerIn: parent
            spacing: 9

            Item {
                width: 17
                height: 20

                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 3
                            height: root.stats.musicPlaying ? 7 + (index === 1 ? 7 : index * 3) : 4
                            radius: 2
                            color: root.stats.musicPlaying ? Theme.Theme.accent : Theme.Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: root.stats.musicPlaying && Config.ShellConfig.animationsEnabled
                                loops: Animation.Infinite
                                NumberAnimation { to: index === 1 ? 18 : 13; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 6 + index * 2; duration: 300 + index * 80; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            Text {
                id: musicTitle
                width: Math.min(420, implicitWidth)
                text: root.stats.music
                elide: Text.ElideRight
                color: Theme.Theme.textPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: musicMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    musicNext.running = true
                else
                    musicToggle.running = true
                if (Config.ShellConfig.animationsEnabled)
                    musicClickAnimation.restart()
            }
        }

        SequentialAnimation {
            id: musicClickAnimation

            NumberAnimation { target: musicIsland; property: "clickScale"; to: 0.97; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: musicIsland; property: "clickScale"; to: 1.03; duration: 200; easing.type: Easing.OutBack }
            NumberAnimation { target: musicIsland; property: "clickScale"; to: 1; duration: 250; easing.type: Easing.InOutCubic }
        }
    }

    Item {
        id: rightCluster

        // Properties
        property real powerButtonIconOffsetX: -6
        property real powerButtonIconOffsetY: 0


        anchors.right: parent.right
        anchors.top: parent.top
        width: rightContent.width + 20
        height: root.barHeight

        Behavior on width {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation { duration: 420; easing.type: Easing.OutBack }
        }

        Shape {
            anchors.fill: parent
            antialiasing: false
            ShapePath {
                fillColor: Theme.Theme.surface
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: rightCluster.width; y: 0 }
                PathLine { x: rightCluster.width; y: rightCluster.height }
                PathLine { x: root.edgeRadius; y: rightCluster.height }
                PathQuad { x: 0; y: rightCluster.height - root.edgeRadius; controlX: 0; controlY: rightCluster.height }
            }
        }

        Row {
            id: rightContent
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Components.StatusItem { icon: "󰍛"; value: root.stats.cpu; accessibleName: "CPU usage" }
            Components.StatusItem {
                icon: "󰘚"
                value: root.showMemoryGigabytes ? root.stats.memoryGigabytes : root.stats.memory
                accessibleName: "Memory usage"
                onClicked: root.showMemoryGigabytes = !root.showMemoryGigabytes
            }
            Rectangle { width: 1; height: 18; color: Theme.Theme.surfaceHover; anchors.verticalCenter: parent.verticalCenter }
            Components.StatusItem { icon: root.stats.network === "Offline" ? "󰤭" : "󰤨"; value: root.stats.network; accessibleName: "Network"; onClicked: networkSettings.running = true }
            Components.StatusItem {
                icon: root.stats.muted ? "󰝟" : "󰕾"
                value: root.stats.muted ? "Muted" : root.stats.volume
                accessibleName: "Audio volume"
                onClicked: volumeToggle.running = true
                onWheelScrolled: delta => {
                    if (delta > 0)
                        volumeUp.running = true
                    else if (delta < 0)
                        volumeDown.running = true
                }
            }
            Components.StatusItem { icon: "󰌌"; value: root.stats.keyboardLayout; accessibleName: "Keyboard layout"; onClicked: layoutSwitch.running = true }
            Components.IconButton {
                transform: Translate {
                    x: rightCluster.powerButtonIconOffsetX
                    y: rightCluster.powerButtonIconOffsetY
                }

                icon: "⏻";
                onClicked: root.launcher.showMessage("Power menu is planned for a later release")
            }
        }
    }

    Process { id: networkSettings; command: ["sh", "-c", Config.ShellConfig.networkSettingsCommand] }
    Process { id: volumeToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volumeUp; command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"] }
    Process { id: volumeDown; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
    Process { id: musicToggle; command: ["playerctl", "play-pause"] }
    Process { id: musicNext; command: ["playerctl", "next"] }
    Process { id: layoutSwitch; command: ["hyprctl", "switchxkblayout", "current", "next"] }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.currentTime = new Date() }
}
