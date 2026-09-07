import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../config" as Config
import "../../theme" as Theme

Scope {
    id: root

    property bool presented: false
    property real reveal: 0
    property string pendingAction: ""

    function trigger(action) {
        if (presented)
            return

        pendingAction = action
        presented = true
        reveal = 1
        actionDelay.restart()
    }

    function runPendingAction() {
        switch (pendingAction) {
        case "lock":
            actionProcess.command = ["hyprlock"]
            break
        case "shutdown":
            actionProcess.command = ["systemctl", "poweroff"]
            break
        case "suspend":
            actionProcess.command = ["sh", "-c", "hyprlock & lock_pid=$!; sleep 0.35; systemctl suspend -i; wait \"$lock_pid\""]
            break
        case "reboot":
            actionProcess.command = ["systemctl", "reboot"]
            break
        case "logout":
            actionProcess.command = ["hyprctl", "dispatch", "exit", "0"]
            break
        default:
            presented = false
            reveal = 0
            return
        }
        actionProcess.running = true
    }

    function dismiss() {
        reveal = 0
        uncoverDelay.restart()
    }

    Timer {
        id: actionDelay
        interval: Config.ShellConfig.animationsEnabled ? 680 : 40
        onTriggered: root.runPendingAction()
    }

    Timer {
        id: uncoverDelay
        interval: Config.ShellConfig.animationsEnabled ? 480 : 40
        onTriggered: {
            root.presented = false
            root.pendingAction = ""
        }
    }

    Process {
        id: actionProcess
        onExited: (exitCode, exitStatus) => {
            if (root.pendingAction === "lock" || root.pendingAction === "suspend" || exitCode !== 0)
                root.dismiss()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: curtain
            required property var modelData

            screen: modelData
            visible: root.presented
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { width: curtain.width; height: curtain.height }

            Item {
                id: topCurtain
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: (parent.height / 2 + 54) * root.reveal
                clip: true

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        id: topPath
                        readonly property real w: topCurtain.width
                        readonly property real h: topCurtain.height
                        readonly property real wave: Math.min(46 * root.reveal, h)
                        fillColor: Theme.Theme.background
                        strokeWidth: 0
                        startX: 0
                        startY: 0
                        PathLine { x: topPath.w; y: 0 }
                        PathLine { x: topPath.w; y: topPath.h - topPath.wave * 0.72 }
                        PathCubic {
                            x: topPath.w * 0.57; y: topPath.h - topPath.wave * 0.82
                            control1X: topPath.w * 0.88; control1Y: topPath.h - topPath.wave * 0.08
                            control2X: topPath.w * 0.72; control2Y: topPath.h - topPath.wave * 1.45
                        }
                        PathCubic {
                            x: 0; y: topPath.h - topPath.wave * 0.18
                            control1X: topPath.w * 0.39; control1Y: topPath.h - topPath.wave * 0.08
                            control2X: topPath.w * 0.18; control2Y: topPath.h - topPath.wave * 1.18
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Rectangle {
                    width: Math.min(parent.width * 0.42, 620)
                    height: width
                    radius: width / 2
                    x: parent.width * 0.06
                    y: -height * 0.46
                    color: "transparent"
                    border.width: Math.max(18, width * 0.075)
                    border.color: Theme.Theme.surface
                    opacity: 0.78
                    rotation: -12
                }

                Rectangle {
                    width: Math.min(parent.width * 0.14, 190)
                    height: width
                    radius: Theme.Theme.radiusLarge
                    x: parent.width * 0.73
                    y: parent.height * 0.22
                    color: Theme.Theme.surfaceRaised
                    opacity: 0.72
                    rotation: 24
                }

                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 7 + index * 3
                        height: width
                        radius: width / 2
                        x: topCurtain.width * (0.56 + index * 0.075)
                        y: topCurtain.height * (0.13 + (index % 2) * 0.12)
                        color: index === 3 ? Theme.Theme.accent : Theme.Theme.surfaceHover
                        opacity: index === 3 ? 0.48 : 0.72
                    }
                }
            }

            Item {
                id: bottomCurtain
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: (parent.height / 2 + 54) * root.reveal
                clip: true

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        id: bottomPath
                        readonly property real w: bottomCurtain.width
                        readonly property real h: bottomCurtain.height
                        readonly property real wave: Math.min(46 * root.reveal, h)
                        fillColor: Theme.Theme.surface
                        strokeWidth: 0
                        startX: 0
                        startY: bottomPath.wave * 0.74
                        PathCubic {
                            x: bottomPath.w * 0.48; y: bottomPath.wave * 0.94
                            control1X: bottomPath.w * 0.16; control1Y: bottomPath.wave * 1.48
                            control2X: bottomPath.w * 0.31; control2Y: bottomPath.wave * 0.04
                        }
                        PathCubic {
                            x: bottomPath.w; y: bottomPath.wave * 0.12
                            control1X: bottomPath.w * 0.68; control1Y: bottomPath.wave * 1.58
                            control2X: bottomPath.w * 0.85; control2Y: -bottomPath.wave * 0.25
                        }
                        PathLine { x: bottomPath.w; y: bottomPath.h }
                        PathLine { x: 0; y: bottomPath.h }
                        PathLine { x: 0; y: bottomPath.wave * 0.74 }
                    }
                }

                Rectangle {
                    width: Math.min(parent.width * 0.34, 500)
                    height: width
                    radius: width / 2
                    x: parent.width * 0.68
                    y: parent.height * 0.48
                    color: Theme.Theme.surfaceRaised
                    opacity: 0.76
                }

                Rectangle {
                    width: Math.min(parent.width * 0.18, 250)
                    height: width
                    radius: width / 2
                    x: parent.width * 0.75
                    y: parent.height * 0.62
                    color: Theme.Theme.surface
                    border.width: Math.max(12, width * 0.08)
                    border.color: Theme.Theme.surfaceHover
                    opacity: 0.92
                }

                Rectangle {
                    width: Math.min(parent.width * 0.1, 138)
                    height: width
                    radius: Theme.Theme.radiusMedium
                    x: parent.width * 0.12
                    y: parent.height * 0.52
                    color: Theme.Theme.surfaceRaised
                    opacity: 0.82
                    rotation: -18
                }
            }

            Text {
                id: farewell
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 48)
                height: 96
                text: "Goodbye, " + (Quickshell.env("USER") || "user") + " :)"
                color: Theme.Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.min(64, Math.max(36, curtain.width / 22))
                font.weight: Font.Bold
                fontSizeMode: Text.Fit
                minimumPixelSize: 20
                opacity: Math.max(0, (root.reveal - 0.52) / 0.48)
                scale: 0.84 + 0.16 * root.reveal
            }
        }
    }

    Behavior on reveal {
        enabled: Config.ShellConfig.animationsEnabled
        NumberAnimation {
            duration: root.reveal > 0 ? 580 : 420
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.reveal > 0 ? [0.76, 0, 0.24, 1, 1, 1] : [0.22, 0.72, 0.18, 1, 1, 1]
        }
    }
}
