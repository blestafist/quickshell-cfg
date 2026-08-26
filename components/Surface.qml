import QtQuick

import "../theme" as Theme

Rectangle {
    property color surfaceColor: Theme.Theme.surface
    property int surfaceRadius: Theme.Theme.radiusMedium

    color: surfaceColor
    radius: surfaceRadius
}
