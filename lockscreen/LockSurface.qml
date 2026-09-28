import QtQuick
import Quickshell.Wayland
import "../theme" as Theme

WlSessionLockSurface {
    id: surface
    required property var auth
    required property bool secured
    required property bool departing
    color: Theme.Theme.background

    LockView {
        anchors.fill: parent
        auth: surface.auth
        secured: surface.secured
        departing: surface.departing
    }
}
