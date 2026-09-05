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
    property int joinRadius: 10
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
            width: parent.width + root.joinRadius
            height: parent.height
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                fillColor: Theme.Theme.surface
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: leftCluster.width + root.joinRadius; y: 0 }
                PathCubic {
                    x: leftCluster.width; y: root.joinRadius
                    control1X: leftCluster.width + root.joinRadius * 0.448; control1Y: 0
                    control2X: leftCluster.width; control2Y: root.joinRadius * 0.448
                }
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
        property real naturalWidth: root.stats.music === "" ? 0 : Math.min(560, musicContent.implicitWidth + 68) + root.joinRadius * 2
        property real joinRadius: Math.min(root.joinRadius, width / 4)
        property real bottomRadius: Math.min(root.islandRadius, Math.max(0, width / 2 - joinRadius))
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
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                fillColor: musicIsland.backgroundColor
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0
                startY: 0
                PathLine { x: musicIsland.width; y: 0 }
                PathCubic {
                    x: musicIsland.width - musicIsland.joinRadius; y: musicIsland.joinRadius
                    control1X: musicIsland.width - musicIsland.joinRadius * 0.552; control1Y: 0
                    control2X: musicIsland.width - musicIsland.joinRadius; control2Y: musicIsland.joinRadius * 0.448
                }
                PathLine { x: musicIsland.width - musicIsland.joinRadius; y: musicIsland.height - musicIsland.bottomRadius }
                PathCubic {
                    x: musicIsland.width - musicIsland.joinRadius - musicIsland.bottomRadius
                    y: musicIsland.height
                    control1X: musicIsland.width - musicIsland.joinRadius
                    control1Y: musicIsland.height - musicIsland.bottomRadius * 0.448
                    control2X: musicIsland.width - musicIsland.joinRadius - musicIsland.bottomRadius * 0.448
                    control2Y: musicIsland.height
                }
                PathLine { x: musicIsland.joinRadius + musicIsland.bottomRadius; y: musicIsland.height }
                PathCubic {
                    x: musicIsland.joinRadius
                    y: musicIsland.height - musicIsland.bottomRadius
                    control1X: musicIsland.joinRadius + musicIsland.bottomRadius * 0.448
                    control1Y: musicIsland.height
                    control2X: musicIsland.joinRadius
                    control2Y: musicIsland.height - musicIsland.bottomRadius * 0.448
                }
                PathLine { x: musicIsland.joinRadius; y: musicIsland.joinRadius }
                PathCubic {
                    x: 0; y: 0
                    control1X: musicIsland.joinRadius; control1Y: musicIsland.joinRadius * 0.448
                    control2X: musicIsland.joinRadius * 0.552; control2Y: 0
                }
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
            x: -root.joinRadius
            width: parent.width + root.joinRadius
            height: parent.height
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                fillColor: Theme.Theme.surface
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: rightCluster.width + root.joinRadius; y: 0 }
                PathLine { x: rightCluster.width + root.joinRadius; y: rightCluster.height }
                PathLine { x: root.joinRadius + root.edgeRadius; y: rightCluster.height }
                PathQuad { x: root.joinRadius; y: rightCluster.height - root.edgeRadius; controlX: root.joinRadius; controlY: rightCluster.height }
                PathLine { x: root.joinRadius; y: root.joinRadius }
                PathCubic {
                    x: 0; y: 0
                    control1X: root.joinRadius; control1Y: root.joinRadius * 0.448
                    control2X: root.joinRadius * 0.552; control2Y: 0
                }
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
