import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string name
    property color color
    readonly property var paths: ({
        search: "M9.5 3a6.5 6.5 0 1 0 3.98 11.64L19.85 21 21 19.85l-6.36-6.37A6.5 6.5 0 0 0 9.5 3zm0 2a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9z",
        previous: "M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12z",
        next: "M8.59 16.59 10 18l6-6-6-6-1.41 1.41L13.17 12z",
        shuffle: "M10.59 9.17 5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z",
        check: "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z",
        close: "M18.3 5.71 12 12l6.3 6.29-1.42 1.42L10.59 13.4 4.3 19.71l-1.42-1.42L9.17 12 2.88 5.71 4.3 4.29l6.29 6.3 6.29-6.3z"
    })
    implicitWidth: 24
    implicitHeight: 24
    Accessible.ignored: true
    Shape {
        width: 24; height: 24
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        transform: Scale { xScale: root.width / 24; yScale: root.height / 24 }
        ShapePath {
            fillColor: root.color
            strokeWidth: 0
            PathSvg { path: root.paths[root.name] || "" }
        }
    }
}
