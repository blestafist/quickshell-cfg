pragma Singleton

import QtQuick
import QtCore

QtObject {
    readonly property int barHeight: 38
    readonly property int barMargin: 8
    readonly property int launcherWidth: 900
    readonly property int launcherHeight: 580
    readonly property int launcherBottomMargin: 24
    readonly property string clockFormat: "dd MMM, yyyy - HH:mm:ss"
    readonly property string fullClockFormat: "ddd, dd MMMM, yyyy - HH:mm:ss"
    readonly property bool animationsEnabled: true

    readonly property int aiChatWidth: 720
    readonly property int aiChatHeight: 680
    readonly property string aiChatDefaultDirectory: StandardPaths.writableLocation(StandardPaths.HomeLocation)

    readonly property string terminalCommand: "kitty"
    readonly property string browserCommand: "zen-browser"
    readonly property string fileManagerCommand: "thunar"
    readonly property string networkSettingsCommand: "nm-connection-editor"
}
