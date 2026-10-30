import QtQuick
import QtTest
import "../../theme" as Theme

TestCase {
    name: "Theme"
    when: windowShown
    property var originalPalette
    property string originalWallpaper

    function initTestCase() {
        originalPalette = Theme.Theme.generatedColors
        originalWallpaper = Theme.Theme.wallpaper
    }

    function cleanupTestCase() {
        Theme.Theme.generatedColors = originalPalette
        Theme.Theme.wallpaper = originalWallpaper
        wait(450)
    }

    function makePalette(accent) {
        return {version: 1, wallpaper: "/wallpaper.png", colors: {
            background: "#101010", surface: "#202020", surfaceRaised: "#303030", surfaceHover: "#404040",
            textPrimary: "#eeeeee", textSecondary: "#dddddd", textMuted: "#cccccc",
            accent: accent, accentText: "#111111", danger: "#ffb4ab"
        }}
    }

    function test_paletteUpdatesWithoutReloadAndCanReverseMidTransition() {
        verify(Theme.Theme.applyPalette(makePalette("#b0a0f0")))
        wait(80)
        verify(Theme.Theme.applyPalette(makePalette("#84d2e7")))
        tryCompare(Theme.Theme, "accent", "#84d2e7", 800)
        compare(Theme.Theme.surface, "#202020")
        compare(Theme.Theme.wallpaper, "/wallpaper.png")
    }

    function test_invalidPaletteNeverReplacesLastGoodColors() {
        const before = JSON.stringify(Theme.Theme.generatedColors)
        const invalid = makePalette("not a color")
        verify(!Theme.Theme.applyPalette(invalid))
        verify(!Theme.Theme.applyPalette({version: 1, wallpaper: "/x", colors: {}}))
        compare(JSON.stringify(Theme.Theme.generatedColors), before)
    }
}
