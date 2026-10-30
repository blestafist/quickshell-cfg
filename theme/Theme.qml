pragma Singleton

import QtQuick
import "../config" as Config

Item {
    id: root
    property var generatedColors: ({})
    property string wallpaper: ""
    readonly property int transitionDuration: Config.ShellConfig.animationsEnabled ? 400 : 0

    function applyPalette(data) {
        const names = ["background", "surface", "surfaceRaised", "surfaceHover", "textPrimary",
            "textSecondary", "textMuted", "accent", "accentText", "danger"]
        if (!data || data.version !== 1 || typeof data.wallpaper !== "string" || !data.colors
                || !names.every(name => typeof data.colors[name] === "string" && /^#[0-9a-fA-F]{6}$/.test(data.colors[name]))) return false
        generatedColors = Object.assign({}, data.colors)
        wallpaper = data.wallpaper
        return true
    }

    property color background: generatedColors.background || "#191714"
    property color surface: generatedColors.surface || "#24211d"
    property color surfaceRaised: generatedColors.surfaceRaised || "#302c26"
    property color surfaceHover: generatedColors.surfaceHover || "#3b362e"
    property color textPrimary: generatedColors.textPrimary || "#f1e9df"
    property color textSecondary: generatedColors.textSecondary || "#c7bdb1"
    property color textMuted: generatedColors.textMuted || "#9b9186"
    property color accent: generatedColors.accent || "#d8a56b"
    property color accentText: generatedColors.accentText || "#251a0e"
    property color danger: generatedColors.danger || "#e28a83"
    Behavior on background { ColorAnimation { duration: root.transitionDuration } }
    Behavior on surface { ColorAnimation { duration: root.transitionDuration } }
    Behavior on surfaceRaised { ColorAnimation { duration: root.transitionDuration } }
    Behavior on surfaceHover { ColorAnimation { duration: root.transitionDuration } }
    Behavior on textPrimary { ColorAnimation { duration: root.transitionDuration } }
    Behavior on textSecondary { ColorAnimation { duration: root.transitionDuration } }
    Behavior on textMuted { ColorAnimation { duration: root.transitionDuration } }
    Behavior on accent { ColorAnimation { duration: root.transitionDuration } }
    Behavior on accentText { ColorAnimation { duration: root.transitionDuration } }
    Behavior on danger { ColorAnimation { duration: root.transitionDuration } }
    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 16
    readonly property int radiusLarge: 24
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 20
}
