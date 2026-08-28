import QtQuick

import "../theme" as Theme

Rectangle {
    property color surfaceColor: Qt.rgba(Theme.Theme.surface.r, Theme.Theme.surface.g, Theme.Theme.surface.b, 0.82)
    property int surfaceRadius: Theme.Theme.radiusMedium

    color: surfaceColor
    radius: surfaceRadius
}
