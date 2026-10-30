pragma Singleton

import QtQuick

QtObject {
    readonly property int barHeight: 38
    readonly property int barMargin: 8
    readonly property int launcherWidth: 900
    readonly property int launcherHeight: 580
    readonly property int launcherBottomMargin: 24
    readonly property string clockFormat: "dd MMM, yyyy - HH:mm:ss"
    readonly property string fullClockFormat: "ddd, dd MMMM, yyyy - HH:mm:ss"
    readonly property bool animationsEnabled: true

    // Empty means ~/Pictures/Wallpaper. Use the existing collection on this machine.
    readonly property string wallpaperDirectory: "~/.config/wallpaper"
    readonly property bool wallpaperRecursive: true
    readonly property int wallpaperPanelHeight: 392
    readonly property real wallpaperTransitionDuration: 1.8
    readonly property int wallpaperTransitionFps: 180
    readonly property int wallpaperCacheLimitMiB: 128
    readonly property bool wallpaperThemeEnabled: true
    readonly property string wallpaperThemeMode: "dark"
    readonly property string wallpaperThemeScheme: "scheme-tonal-spot"

    readonly property string terminalCommand: "kitty"
    readonly property string browserCommand: "zen-browser"
    readonly property string fileManagerCommand: "thunar"
    readonly property string networkSettingsCommand: "nm-connection-editor"
}
