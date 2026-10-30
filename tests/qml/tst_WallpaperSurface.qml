import QtQuick
import QtTest
import "../../modules/wallpaper"

TestCase {
    id: testCase
    name: "WallpaperSurface"
    when: windowShown
    width: 1920
    height: 720

    Component {
        id: surfaceComponent
        WallpaperSurface {
            width: 1920
            height: 392
            seedWidth: 340
            surfaceColor: "#24211d"
            Rectangle { objectName: "content"; width: 1800; height: 262 }
        }
    }

    function surface(properties) { return createTemporaryObject(surfaceComponent, testCase, properties || {}) }

    function test_morphCoversBarWithoutStretchingContent() {
        const item = surface()
        const content = findChild(item, "content")
        compare(item.outlineWidth, 340)
        compare(item.outlineHeight, 42)
        item.expanded = true
        for (let i = 0; i < 180; i++) {
            item.advance(1 / 180)
            verify(item.outlineWidth >= 340 && item.outlineWidth <= 1920)
            verify(item.outlineHeight >= 42 && item.outlineHeight < 410)
            compare(content.width, 1800)
            compare(content.scale, 1)
        }
        compare(item.outlineWidth, 1920)
        compare(item.outlineHeight, 392)
        verify(!item.animating)
    }

    function test_spreadLeadsOpeningAndHeightLeadsClosing() {
        const item = surface()
        item.expanded = true
        item.advance(0.09)
        verify(item.spread > item.drop)
        item.advance(1)
        item.expanded = false
        item.advance(0.09)
        verify(item.drop < item.spread)
        item.advance(1)
        compare(item.outlineWidth, 340)
        compare(item.outlineHeight, 42)
        verify(!item.animating)
    }

    function test_reversalPreservesMomentum() {
        const item = surface()
        item.expanded = true
        item.advance(0.1)
        const position = item.drop
        const velocity = item.dropVelocity
        item.expanded = false
        compare(item.drop, position)
        compare(item.dropVelocity, velocity)
        item.advance(0.02)
        item.expanded = true
        item.advance(1)
        compare(item.drop, 1)
        compare(item.spread, 1)
    }

    function test_reducedMotionAndIdle() {
        const item = surface({animationsEnabled: false})
        item.expanded = true
        compare(item.outlineWidth, 1920)
        compare(item.outlineHeight, 392)
        verify(!item.animating)
        item.expanded = false
        compare(item.outlineWidth, 340)
        compare(item.outlineHeight, 42)
        verify(!item.animating)
    }
}
