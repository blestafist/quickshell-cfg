import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../components" as Components
import "../../config" as Config
import "../../theme" as Theme
import "../../services" as Services
import "../wallpaper" as Wallpaper

PanelWindow {
    id: root

    property var stats
    property var launcher
    property var powerOverlay
    property var paletteController
    property var targetScreen: Quickshell.screens.find(screen => screen.name === Config.MachineConfig.primaryMonitor)
    property date currentTime: new Date()
    property int barHeight: 42
    property int edgeRadius: 21
    property int joinRadius: 12
    property int islandRadius: 24
    property bool showMemoryGigabytes: false
    property bool showFullDate: false
    property bool wifiOpened: false
    property bool vpnOpened: false
    property bool powerOpened: false
    property string islandMode: "music"
    readonly property bool calculatorOpened: islandMode === "calculator"
    readonly property bool clipboardOpened: islandMode === "clipboard"
    readonly property bool centerExpanded: calculatorOpened || clipboardOpened
    readonly property bool wallpaperOpened: wallpaperPicker.opened
    property bool menuOpened: wifiOpened || vpnOpened || powerOpened || centerExpanded || wallpaperOpened
    onClipboardOpenedChanged: {
        if (clipboardOpened) {
            wallpaperPicker.close()
            wifiOpened = false
            vpnOpened = false
            powerOpened = false
            if (launcher) launcher.close()
            Qt.callLater(() => clipboardPanel.activate())
        }
    }
    onCalculatorOpenedChanged: {
        if (calculatorOpened) {
            wallpaperPicker.close()
            wifiOpened = false
            vpnOpened = false
            powerOpened = false
            if (launcher) launcher.close()
            Qt.callLater(() => calculatorPanel.activate())
        }
    }
    onWifiOpenedChanged: {
        if (wifiOpened) {
            wallpaperPicker.close()
            islandMode = "music"
            vpnOpened = false
            powerOpened = false
            wifiPanel.forceActiveFocus()
        }
    }
    onVpnOpenedChanged: {
        if (vpnOpened) {
            wallpaperPicker.close()
            islandMode = "music"
            wifiOpened = false
            powerOpened = false
            vpnPanel.forceActiveFocus()
        }
    }
    onPowerOpenedChanged: {
        if (powerOpened) {
            wallpaperPicker.close()
            islandMode = "music"
            wifiOpened = false
            vpnOpened = false
            powerPanel.forceActiveFocus()
        }
    }

    Services.Wifi { id: wifiService; opened: root.wifiOpened }
    Services.Vpn { id: vpnService; opened: root.vpnOpened }
    Services.Clipboard { id: clipboardService; opened: root.clipboardOpened }
    Services.Wallpapers {
        id: wallpaperService
        opened: root.wallpaperOpened
        output: root.targetScreen ? root.targetScreen.name : ""
        paletteController: root.paletteController
    }
    Connections {
        target: root.launcher
        function onOpenedChanged() { if (root.launcher.opened) wallpaperPicker.close() }
    }
    IpcHandler {
        target: "clipboard"
        function toggle() { root.islandMode = root.clipboardOpened ? "music" : "clipboard" }
        function close() { if (root.clipboardOpened) root.islandMode = "music" }
    }
    IpcHandler {
        target: "calculator"
        function toggle() { root.islandMode = root.calculatorOpened ? "music" : "calculator" }
        function close() { if (root.calculatorOpened) root.islandMode = "music" }
    }
    IpcHandler {
        target: "vpn"
        function toggle() { root.vpnOpened = !root.vpnOpened }
        function close() { root.vpnOpened = false }
        function connect() { vpnService.connectTarget({ type: "fastest", value: "", label: "Fastest server" }) }
        function disconnect() { vpnService.disconnect() }
    }
    IpcHandler {
        target: "wifi"
        function toggle() { root.wifiOpened = !root.wifiOpened }
        function close() { root.wifiOpened = false }
    }
    IpcHandler {
        target: "power"
        function toggle() { root.powerOpened = !root.powerOpened }
        function close() { root.powerOpened = false }
    }
    IpcHandler {
        target: "wallpaper"
        function open() { wallpaperPicker.open() }
        function close() { wallpaperPicker.close() }
        function toggle() { wallpaperPicker.toggle() }
        function refresh() { wallpaperService.refresh() }
        function status(): string { return wallpaperPicker.status() }
    }

    screen: targetScreen
    visible: targetScreen !== null
    anchors { top: true; left: true; right: true }
    margins { top: 0; left: 0; right: 0 }
    exclusiveZone: barHeight
    // Keep the layer surface stable; only the island and its input region animate.
    implicitHeight: screen ? screen.height : 1080
    color: "transparent"
    WlrLayershell.keyboardFocus: centerExpanded || wallpaperPicker.presented ? WlrKeyboardFocus.Exclusive : menuOpened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        width: root.width
        height: wallpaperPicker.presented ? root.height : root.barHeight
        Region { item: leftCluster }
        Region { item: rightCluster }
        Region { item: musicIsland }
    }

    Item {
        id: leftCluster
        property real targetWidth: leftContent.width + root.edgeRadius + 18

        function animateWidth() {
            leftIslandWidthAnimation.stop()
            if (!Config.ShellConfig.animationsEnabled) {
                width = targetWidth
                return
            }
            const growing = targetWidth > width
            leftIslandWidthAnimation.from = width
            leftIslandWidthAnimation.to = targetWidth
            leftIslandWidthAnimation.duration = growing ? 420 : 280
            leftIslandWidthAnimation.easing.type = growing ? Easing.OutBack : Easing.OutCubic
            leftIslandWidthAnimation.start()
        }
        onTargetWidthChanged: animateWidth()

        anchors.left: parent.left
        anchors.top: parent.top
        width: 0
        height: root.barHeight

        NumberAnimation {
            id: leftIslandWidthAnimation
            target: leftCluster
            property: "width"
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
    }

    // Keep the same clock above the collapsing shelf instead of revealing it
    // abruptly when the picker finally stops presenting its surface.
    Row {
        id: leftContent
        objectName: "barLeftContent"
        z: wallpaperPicker.presented ? 20 : 0
        x: leftCluster.x + 10
        y: leftCluster.y + (root.barHeight - height) / 2
        spacing: 0
        opacity: wallpaperPicker.barContentOpacity
        enabled: !wallpaperPicker.presented

        Item {
            id: distroSlot
            width: 42
            height: 34
            anchors.verticalCenter: parent.verticalCenter
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

    Item {
        id: musicIsland
        property real clickScale: 1
        property real naturalWidth: root.stats.music === "" ? 0 : Math.min(420, musicTitle.implicitWidth) + 94 + root.joinRadius * 2
        property real joinRadius: Math.min(root.joinRadius, width / 4)
        property real bottomRadius: Math.min(root.islandRadius, Math.max(0, width / 2 - joinRadius))
        property color backgroundColor: !root.centerExpanded && musicMouse.containsMouse ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised
        property real targetWidth: root.clipboardOpened ? Math.max(0, Math.min(860, root.width - 24)) : root.calculatorOpened ? Math.min(600, root.width - 24) : naturalWidth * clickScale
        property real targetHeight: root.clipboardOpened ? clipboardPanel.implicitHeight : root.calculatorOpened ? calculatorPanel.implicitHeight : root.barHeight

        function animateSize(animation, propertyName, target) {
            animation.stop()
            if (!Config.ShellConfig.animationsEnabled || (musicClickAnimation.running && !root.centerExpanded)) {
                musicIsland[propertyName] = target
                return
            }
            animation.from = musicIsland[propertyName]
            animation.to = target
            animation.duration = root.centerExpanded ? 380 : 260
            animation.easing.type = root.centerExpanded && target > musicIsland[propertyName] ? Easing.OutBack : Easing.OutCubic
            animation.start()
        }
        // Let the mode and its derived flags settle before choosing the easing.
        // Coalesce size updates so opening clipboard cannot start a closing curve.
        function animateWidth() { animateSize(islandWidthAnimation, "width", targetWidth) }
        function animateHeight() { animateSize(centerHeightAnimation, "height", targetHeight) }
        onTargetWidthChanged: Qt.callLater(animateWidth)
        onTargetHeightChanged: Qt.callLater(animateHeight)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 0
        height: root.barHeight
        opacity: root.centerExpanded || root.stats.music !== "" ? 1 : 0
        z: root.centerExpanded ? 1 : 0
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

        NumberAnimation {
            id: islandWidthAnimation
            target: musicIsland
            property: "width"
        }

        NumberAnimation {
            id: centerHeightAnimation
            target: musicIsland
            property: "height"
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
            opacity: root.centerExpanded ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 160 : 0 }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.barHeight - height) / 2
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
                width: Math.max(0, Math.min(420, implicitWidth, musicIsland.width - 92))
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
            width: parent.width
            height: root.barHeight
            enabled: root.stats.music !== "" && !root.centerExpanded
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    musicNext.running = true
                else
                    musicToggle.running = true
                if (Config.ShellConfig.animationsEnabled && !root.centerExpanded)
                    musicClickAnimation.restart()
            }
        }

        CalculatorPanel {
            id: calculatorPanel
            x: root.joinRadius + 20
            y: 0
            width: Math.max(0, parent.width - 2 * x)
            visible: !root.clipboardOpened && (root.calculatorOpened || musicIsland.height > root.barHeight + 1)
            enabled: root.calculatorOpened
            opacity: root.calculatorOpened ? Math.max(0, Math.min(1, (musicIsland.height - root.barHeight) / (implicitHeight - root.barHeight))) : 0
            Behavior on opacity {
                NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 160 : 0 }
            }
            onCloseRequested: root.islandMode = "music"
        }

        ClipboardPanel {
            id: clipboardPanel
            x: root.joinRadius + 20
            width: Math.max(0, parent.width - 2 * x)
            history: clipboardService
            visible: root.clipboardOpened
            enabled: root.clipboardOpened
            opacity: root.clipboardOpened ? Math.max(0, Math.min(1, (musicIsland.height - root.barHeight) / (implicitHeight - root.barHeight))) : 0
            onCloseRequested: root.islandMode = "music"
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
        property real targetHeight: root.barHeight + (root.wifiOpened ? wifiPanel.implicitHeight : root.vpnOpened ? vpnPanel.implicitHeight : root.powerOpened ? powerPanel.implicitHeight : 0)
        onTargetHeightChanged: {
            islandHeightAnimation.stop()
            if (!Config.ShellConfig.animationsEnabled) {
                height = targetHeight
                return
            }
            islandHeightAnimation.from = height
            islandHeightAnimation.to = targetHeight
            islandHeightAnimation.duration = root.menuOpened ? 420 : 280
            islandHeightAnimation.easing.type = targetHeight > height ? Easing.OutBack : Easing.OutCubic
            islandHeightAnimation.start()
        }


        anchors.right: parent.right
        anchors.top: parent.top
        width: root.wifiOpened || root.vpnOpened ? Math.min(root.width, Math.max(600, rightContent.width + 64)) : root.powerOpened ? Math.max(344, rightContent.width + 20) : rightContent.width + 20
        height: root.barHeight

        NumberAnimation {
            id: islandHeightAnimation
            target: rightCluster
            property: "height"
        }

        Behavior on width {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation { duration: root.menuOpened ? 420 : 280; easing.type: root.menuOpened ? Easing.OutBack : Easing.OutCubic }
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
            y: (root.barHeight - height) / 2
            spacing: 8

            Components.StatusItem { icon: "󰍛"; value: root.stats.cpu; accessibleName: "CPU usage" }
            Components.StatusItem {
                icon: "󰘚"
                value: root.showMemoryGigabytes ? root.stats.memoryGigabytes : root.stats.memory
                accessibleName: "Memory usage"
                onClicked: root.showMemoryGigabytes = !root.showMemoryGigabytes
            }
            Rectangle { width: 1; height: 18; color: Theme.Theme.surfaceHover; anchors.verticalCenter: parent.verticalCenter }
            Components.StatusItem {
                icon: vpnService.connected ? "󰦝" : root.stats.network === "Offline" ? "󰤭" : "󰤨"
                value: root.stats.network
                accessibleName: "Network: left click Wi-Fi, right click VPN"
                onClicked: root.wifiOpened = !root.wifiOpened
                onRightClicked: root.vpnOpened = !root.vpnOpened
            }
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
                tooltip: "Power menu"
                onClicked: root.powerOpened = !root.powerOpened
            }
        }

        Item {
            x: 0
            y: root.barHeight
            width: parent.width
            height: Math.max(0, parent.height - root.barHeight - 8)
            clip: true
            WifiPanel {
                id: wifiPanel
                width: parent.width
                height: implicitHeight
                maximumHeight: root.height - root.barHeight - 24
                wifi: wifiService
                visible: parent.height > 0
                enabled: root.wifiOpened
                opacity: root.wifiOpened ? 1 : 0
                y: root.wifiOpened ? 0 : -12
                Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                Behavior on y { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? (root.wifiOpened ? 420 : 280) : 0; easing.type: root.wifiOpened ? Easing.OutBack : Easing.OutCubic } }
                onCloseRequested: root.wifiOpened = false
            }
            VpnPanel {
                id: vpnPanel
                width: parent.width
                height: implicitHeight
                maximumHeight: root.height - root.barHeight - 24
                vpn: vpnService
                visible: parent.height > 0 && !root.wifiOpened
                enabled: root.vpnOpened
                opacity: root.vpnOpened ? 1 : 0
                y: root.vpnOpened ? 0 : -12
                Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                Behavior on y { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? (root.vpnOpened ? 420 : 280) : 0; easing.type: root.vpnOpened ? Easing.OutBack : Easing.OutCubic } }
                onCloseRequested: root.vpnOpened = false
            }
            PowerPanel {
                id: powerPanel
                width: parent.width
                height: implicitHeight
                visible: parent.height > 0 && !root.wifiOpened && !root.vpnOpened
                enabled: root.powerOpened
                opacity: root.powerOpened ? 1 : 0
                y: root.powerOpened ? 0 : -12
                Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                Behavior on y { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? (root.powerOpened ? 420 : 280) : 0; easing.type: root.powerOpened ? Easing.OutBack : Easing.OutCubic } }
                onCloseRequested: root.powerOpened = false
                onActionRequested: action => {
                    root.powerOpened = false
                    root.powerOverlay.trigger(action)
                }
            }
        }
    }

    Wallpaper.WallpaperPicker {
        id: wallpaperPicker
        anchors.fill: parent
        z: 10
        visible: presented
        wallpapers: wallpaperService
        seedWidth: leftCluster.width
        barHeight: root.barHeight
        onOpening: {
            root.wifiOpened = false
            root.vpnOpened = false
            root.powerOpened = false
            root.islandMode = "music"
            if (root.launcher) root.launcher.close()
        }
    }

    // A shared control above the shelf, not a duplicate hidden beneath its
    // input shield. It stays clickable from the very first opening frame.
    DistroButton {
        id: distro
        objectName: "wallpaperToggle"
        z: 20
        x: leftContent.x + distroSlot.x
        y: leftContent.y + distroSlot.y
        width: distroSlot.width
        height: distroSlot.height
        closeMode: wallpaperPicker.opened
        onClicked: {
            if (wallpaperPicker.opened) wallpaperPicker.close()
            else root.launcher.open()
        }
        onRightClicked: wallpaperPicker.toggle()
    }

    Process { id: volumeToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volumeUp; command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"] }
    Process { id: volumeDown; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
    Process { id: musicToggle; command: ["playerctl", "play-pause"] }
    Process { id: musicNext; command: ["playerctl", "next"] }
    Process { id: layoutSwitch; command: ["niri", "msg", "action", "switch-layout", "next"] }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.currentTime = new Date() }
}
