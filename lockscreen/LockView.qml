import QtQuick
import QtQuick.Shapes
import "../theme" as Theme
import "config" as Config
import "widgets"

Rectangle {
    id: view
    required property var auth
    property bool secured: false
    property bool departing: false
    property bool preview: false
    property real reveal: 0
    readonly property bool landscape: width >= 960 && width > height * 1.2
    readonly property real inset: Math.max(20, Math.min(72, width * 0.055))
    color: Theme.Theme.background
    clip: true

    Component.onCompleted: reveal = 1
    Behavior on reveal {
        enabled: Config.LockConfig.animationsEnabled
        NumberAnimation { duration: 680; easing.type: Easing.OutCubic }
    }

    Rectangle {
        width: Math.min(view.width * 0.65, 900)
        height: width
        radius: width / 2
        x: -width * 0.28
        y: -height * 0.65
        color: "transparent"
        border.width: width * 0.065
        border.color: Theme.Theme.surface
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: wave
            readonly property real horizon: view.height * (view.landscape ? 0.66 : 0.44) + (1 - view.reveal) * 60
            fillColor: Theme.Theme.surface
            strokeWidth: 0
            startX: 0
            startY: horizon
            PathCubic {
                x: view.width * 0.52; y: wave.horizon + 20
                control1X: view.width * 0.18; control1Y: wave.horizon + 130
                control2X: view.width * 0.34; control2Y: wave.horizon - 100
            }
            PathCubic {
                x: view.width; y: wave.horizon - 40
                control1X: view.width * 0.72; control1Y: wave.horizon + 120
                control2X: view.width * 0.86; control2Y: wave.horizon - 90
            }
            PathLine { x: view.width; y: view.height }
            PathLine { x: 0; y: view.height }
            PathLine { x: 0; y: wave.horizon }
        }
    }

    Rectangle {
        width: Math.min(view.width * 0.32, 400)
        height: width
        radius: width / 2
        x: view.width - width * 0.5
        y: view.height - height * 0.42
        color: "transparent"
        border.width: 24
        border.color: Theme.Theme.surfaceRaised
    }

    SecurityBadge {
        x: view.inset
        y: 24
        secure: view.secured
        preview: view.preview
    }

    Item {
        id: composition
        anchors.fill: parent
        opacity: view.departing ? 0 : view.reveal
        transform: Translate { y: view.departing ? -18 : (1 - view.reveal) * 26 }
        Behavior on opacity { NumberAnimation { duration: Config.LockConfig.animationsEnabled ? 220 : 0 } }

        LockClock {
            id: clock
            width: view.landscape ? view.width * 0.48 - view.inset : view.width - 2 * view.inset
            x: view.inset
            y: view.landscape ? (view.height - height) * 0.44 : Math.max(76, view.height * 0.18 - height * 0.3)
            large: view.landscape
            visible: view.height >= 680 || view.landscape
        }

        AuthCard {
            id: authCard
            auth: view.auth
            width: Math.min(420, view.landscape ? view.width * 0.4 : view.width - 2 * view.inset)
            x: view.landscape ? view.width * 0.57 : (view.width - width) / 2
            y: view.landscape ? (view.height - height) / 2 : view.height < 680 ? Math.max(76, (view.height - height) / 2) : Math.min(view.height - height - 48, Math.max(clock.y + clock.height + 36, view.height * 0.53))
        }
    }

    StatusStrip {
        x: view.inset
        y: view.height - height - 24
        visible: view.height >= 680
    }
}
