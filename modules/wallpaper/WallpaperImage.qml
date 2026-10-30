import QtQuick
import QtQuick.Shapes

import "../../theme" as Theme

Item {
    id: root

    property url source
    property real slant: Math.min(height * 0.22, width * 0.38)
    property real cornerRadius: 12
    property real droplet: 0
    property color borderColor: "transparent"
    property real borderWidth: 0
    property int decodeWidth: 768
    property int decodeHeight: 480
    readonly property bool ready: image.status === Image.Ready
    readonly property bool broken: image.status === Image.Error

    // Feed the decoder's texture straight to the contour. Cropping is a GPU
    // matrix, not a layered Item/FBO reallocated at every animation frame.
    Image {
        id: image
        visible: false
        source: root.source
        sourceSize.width: root.decodeWidth
        sourceSize.height: root.decodeHeight
        asynchronous: true
        cache: false
        retainWhileLoading: true
        smooth: true
        autoTransform: true
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        ShapePath {
            id: path
            readonly property real w: root.width
            readonly property real h: Math.max(1, root.height)
            readonly property real s: root.slant
            readonly property real r: Math.min(root.cornerRadius, w / 8, h / 8)
            readonly property real inset: s * r / h
            readonly property real belly: Math.min((w - s) / 2, h * 0.48, r + root.droplet * w * 0.45)
            readonly property real bottomInset: s * belly / h
            readonly property real neck: w * 0.31 * root.droplet
            readonly property real side1: r + (h - r - belly) * 0.35
            readonly property real side2: r + (h - r - belly) * 0.75
            readonly property real cropScale: Math.max(w / Math.max(1, image.implicitWidth), h / Math.max(1, image.implicitHeight))
            fillItem: image.status === Image.Ready ? image : null
            fillColor: Theme.Theme.surfaceRaised
            fillTransform: Qt.matrix4x4(cropScale, 0, 0, (w - image.implicitWidth * cropScale) / 2,
                0, cropScale, 0, (h - image.implicitHeight * cropScale) / 2,
                0, 0, 1, 0, 0, 0, 0, 1)
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.RoundJoin
            startX: s + neck + r; startY: 0
            PathLine { x: path.w - path.neck - path.r; y: 0 }
            PathQuad { x: path.w - path.neck - path.inset; y: path.r; controlX: path.w - path.neck; controlY: 0 }
            PathCubic {
                x: path.w - path.s + path.bottomInset; y: path.h - path.belly
                control1X: (path.w - path.s * path.side1 / path.h) * (1 - root.droplet) + (path.w - path.neck) * root.droplet
                control1Y: path.side1
                control2X: (path.w - path.s * path.side2 / path.h) * (1 - root.droplet) + (path.w - path.s + path.bottomInset) * root.droplet
                control2Y: path.side2
            }
            PathQuad { x: path.w - path.s - path.belly; y: path.h; controlX: path.w - path.s; controlY: path.h }
            PathLine { x: path.belly; y: path.h }
            PathQuad { x: path.bottomInset; y: path.h - path.belly; controlX: 0; controlY: path.h }
            PathCubic {
                x: path.s + path.neck - path.inset; y: path.r
                control1X: path.s * (1 - path.side2 / path.h) * (1 - root.droplet) + path.bottomInset * root.droplet
                control1Y: path.side2
                control2X: path.s * (1 - path.side1 / path.h) * (1 - root.droplet) + (path.s + path.neck) * root.droplet
                control2Y: path.side1
            }
            PathQuad { x: path.s + path.neck + path.r; y: 0; controlX: path.s + path.neck; controlY: 0 }
        }
    }
}
