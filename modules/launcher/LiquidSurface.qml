import QtQuick
import QtQuick.Shapes

import "LiquidMotion.js" as Motion

Item {
    id: root

    default property alias contentData: contentLayer.data
    property bool expanded: false
    property bool animationsEnabled: true
    required property color surfaceColor
    property real bottomInset: 24
    readonly property int frameInset: 36
    readonly property real motionSpeed: 0.85
    readonly property real reveal: rise
    readonly property real contentProgress: Math.min(Motion.clamp(rise, 0, 1), Motion.clamp(spread, 0, 1))
    readonly property bool animating: clock.running
    readonly property var contour: Motion.geometry(width, height, frameInset, rise, spread)

    property real rise: 0
    property real spread: 0
    property real riseVelocity: 0
    property real spreadVelocity: 0

    signal collapsed()

    function retarget() {
        if (!animationsEnabled) {
            clock.running = false
            rise = spread = expanded ? 1 : 0
            riseVelocity = spreadVelocity = 0
            if (!expanded)
                collapsed()
        } else if (!Motion.settled(rise, riseVelocity, expanded ? 1 : 0)
                || !Motion.settled(spread, spreadVelocity, expanded ? 1 : 0)) {
            clock.running = true
        }
    }

    function advance(seconds) {
        const target = expanded ? 1 : 0
        const delta = seconds * motionSpeed
        // Opening has a soft, single recoil. Closing is critically damped:
        // shoulders pull inward first and the crown follows into the edge.
        const vertical = Motion.spring(rise, riseVelocity, target, delta,
            expanded ? 20 : 26, expanded ? 0.72 : 1)
        const horizontal = Motion.spring(spread, spreadVelocity, target, delta,
            expanded ? 15.5 : 32, expanded ? 0.8 : 1)
        rise = vertical.position
        riseVelocity = vertical.velocity
        spread = horizontal.position
        spreadVelocity = horizontal.velocity

        if (Motion.settled(rise, riseVelocity, target) && Motion.settled(spread, spreadVelocity, target)) {
            clock.running = false
            rise = spread = target
            riseVelocity = spreadVelocity = 0
            if (!expanded)
                collapsed()
        }
    }

    onExpandedChanged: retarget()
    onAnimationsEnabledChanged: retarget()

    data: [
    FrameAnimation {
        id: clock
        running: false
        onTriggered: root.advance(frameTime)
    },

    Shape {
        id: shell
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            id: outline
            readonly property var c: root.contour
            strokeWidth: 0
            fillColor: root.surfaceColor
            startX: c.left + c.radius
            startY: c.top

            PathLine { x: outline.c.right - outline.c.radius; y: outline.c.top }
            PathCubic {
                x: outline.c.right; y: outline.c.top + outline.c.radius
                control1X: outline.c.right - outline.c.radius * 0.448; control1Y: outline.c.top
                control2X: outline.c.right; control2Y: outline.c.top + outline.c.radius * 0.448
            }
            PathCubic {
                x: outline.c.neckRight; y: outline.c.bottom - outline.c.join
                control1X: outline.c.right; control1Y: outline.c.top + outline.c.radius + outline.c.sideLength * 0.5
                control2X: outline.c.neckRight; control2Y: outline.c.bottom - outline.c.join - outline.c.sideLength * 0.4
            }
            PathCubic {
                x: outline.c.neckRight + outline.c.join; y: outline.c.bottom
                control1X: outline.c.neckRight; control1Y: outline.c.bottom - outline.c.join * 0.448
                control2X: outline.c.neckRight + outline.c.join * 0.448; control2Y: outline.c.bottom
            }
            PathLine { x: outline.c.neckLeft - outline.c.join; y: outline.c.bottom }
            PathCubic {
                x: outline.c.neckLeft; y: outline.c.bottom - outline.c.join
                control1X: outline.c.neckLeft - outline.c.join * 0.448; control1Y: outline.c.bottom
                control2X: outline.c.neckLeft; control2Y: outline.c.bottom - outline.c.join * 0.448
            }
            PathCubic {
                x: outline.c.left; y: outline.c.top + outline.c.radius
                control1X: outline.c.neckLeft; control1Y: outline.c.bottom - outline.c.join - outline.c.sideLength * 0.4
                control2X: outline.c.left; control2Y: outline.c.top + outline.c.radius + outline.c.sideLength * 0.5
            }
            PathCubic {
                x: outline.c.left + outline.c.radius; y: outline.c.top
                control1X: outline.c.left; control1Y: outline.c.top + outline.c.radius * 0.448
                control2X: outline.c.left + outline.c.radius * 0.448; control2Y: outline.c.top
            }
        }
    },

    // Only the contour deforms. Clip/reveal full-size content instead of
    // stretching glyphs or relaying out the application list every frame.
    Item {
        id: viewport
        x: (root.width - width) / 2
        y: root.contour.top
        width: root.contour.clipWidth
        height: Math.max(0, root.height - root.bottomInset - y)
        clip: true

        Item {
            id: contentLayer
            x: -viewport.x
            y: -viewport.y + (1 - root.reveal) * 18
            width: root.width
            height: Math.max(0, root.height - root.bottomInset)
        }
    }
    ]
}
