import QtQuick
import QtQuick.Shapes

import "../launcher/LiquidMotion.js" as Spring
import "WallpaperMotion.js" as Motion

Item {
    id: root

    default property alias contentData: contentLayer.data
    property bool expanded: false
    property bool animationsEnabled: true
    property real seedWidth: 340
    property real barHeight: 42
    property color surfaceColor
    property real spread: 0
    property real drop: 0
    property real spreadVelocity: 0
    property real dropVelocity: 0
    readonly property bool animating: clock.running
    readonly property real outlineWidth: seedWidth + (width - seedWidth) * Motion.clamp(spread, 0, 1)
    readonly property real outlineHeight: barHeight + (height - barHeight) * Motion.clamp(drop, 0, 1.035)
    readonly property real contentProgress: Math.min(Motion.clamp(spread, 0, 1), Motion.clamp(drop, 0, 1))
    readonly property alias inputItem: viewport

    signal collapsed()

    function retarget() {
        if (!animationsEnabled) {
            clock.running = false
            spread = drop = expanded ? 1 : 0
            spreadVelocity = dropVelocity = 0
            if (!expanded) collapsed()
        } else clock.running = true
    }

    function advance(seconds) {
        const target = expanded ? 1 : 0
        // The edge spreads first; the shelf follows with one restrained recoil.
        // On dismissal, it drains upward before returning to the left island.
        const horizontal = Spring.spring(spread, spreadVelocity, target, seconds,
            expanded ? 22 : 19, 1)
        const vertical = Spring.spring(drop, dropVelocity, target, seconds,
            expanded ? 16 : 28, expanded ? 0.79 : 1)
        spread = horizontal.position
        spreadVelocity = horizontal.velocity
        drop = vertical.position
        dropVelocity = vertical.velocity
        if (Spring.settled(spread, spreadVelocity, target) && Spring.settled(drop, dropVelocity, target)) {
            clock.running = false
            spread = drop = target
            spreadVelocity = dropVelocity = 0
            if (!expanded) collapsed()
        }
    }

    onExpandedChanged: retarget()
    onAnimationsEnabledChanged: retarget()

    data: [
        FrameAnimation { id: clock; onTriggered: root.advance(frameTime) },
        Shape {
            width: root.width
            height: root.outlineHeight
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                readonly property real right: root.outlineWidth
                readonly property real bottom: root.outlineHeight
                readonly property real join: Math.min(12 * (1 - Motion.clamp(root.spread, 0, 1)), root.width - right)
                readonly property real radius: 21 + 11 * Motion.clamp(root.drop, 0, 1)
                readonly property real leftRadius: 32 * Motion.clamp(root.spread, 0, 1)
                id: outline
                strokeWidth: 0
                fillColor: root.surfaceColor
                startX: 0; startY: 0
                PathLine { x: outline.right + outline.join; y: 0 }
                PathCubic {
                    x: outline.right; y: outline.join
                    control1X: outline.right + outline.join * 0.448; control1Y: 0
                    control2X: outline.right; control2Y: outline.join * 0.448
                }
                PathLine { x: outline.right; y: outline.bottom - outline.radius }
                PathQuad { x: outline.right - outline.radius; y: outline.bottom; controlX: outline.right; controlY: outline.bottom }
                PathLine { x: outline.leftRadius; y: outline.bottom }
                PathQuad { x: 0; y: outline.bottom - outline.leftRadius; controlX: 0; controlY: outline.bottom }
                PathLine { x: 0; y: 0 }
            }
        },
        Item {
            id: viewport
            width: root.outlineWidth
            height: root.outlineHeight
            clip: true
            Item {
                id: contentLayer
                width: root.width
                height: root.height
            }
        }
    ]
}
