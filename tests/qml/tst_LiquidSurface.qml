import QtQuick
import QtTest
import "../../modules/launcher"
import "../../modules/launcher/LiquidMotion.js" as Motion

TestCase {
    id: testCase
    name: "LiquidSurface"
    when: windowShown
    width: 1100
    height: 700

    Component {
        id: surfaceComponent
        LiquidSurface {
            width: 972
            height: 586
            surfaceColor: "#24211d"
            Rectangle {
                objectName: "content"
                x: 48
                y: 12
                width: 876
                height: 64
                color: "white"
            }
        }
    }

    Component { id: spyComponent; SignalSpy { signalName: "collapsed" } }

    function surface(properties) {
        return createTemporaryObject(surfaceComponent, testCase, properties || {})
    }

    function test_openCloseAndIdle() {
        const item = surface()
        const spy = createTemporaryObject(spyComponent, testCase, {target: item})
        verify(!item.animating)
        item.expanded = true
        verify(item.animating)
        tryCompare(item, "animating", false, 1000)
        compare(item.reveal, 1)
        compare(item.spread, 1)
        compare(item.contour.bottom, item.height)
        item.expanded = false
        tryCompare(item, "animating", false, 800)
        compare(item.reveal, 0)
        compare(item.spread, 0)
        compare(spy.count, 1)
    }

    function test_speedRetimesBothAxesWithoutChangingTrajectory() {
        const item = surface()
        compare(item.motionSpeed, 0.85)
        let rise = {position: 0, velocity: 0}
        let spread = {position: 0, velocity: 0}
        for (const expanded of [true, false, true]) {
            item.expanded = expanded
            item.advance(0.1)
            rise = Motion.spring(rise.position, rise.velocity, expanded ? 1 : 0,
                0.085, expanded ? 20 : 26, expanded ? 0.72 : 1)
            spread = Motion.spring(spread.position, spread.velocity, expanded ? 1 : 0,
                0.085, expanded ? 15.5 : 32, expanded ? 0.8 : 1)
            fuzzyCompare(item.rise, rise.position, 1e-12)
            fuzzyCompare(item.riseVelocity, rise.velocity, 1e-12)
            fuzzyCompare(item.spread, spread.position, 1e-12)
            fuzzyCompare(item.spreadVelocity, spread.velocity, 1e-12)
        }
    }

    function test_rapidReversalKeepsPositionAndVelocity() {
        const item = surface()
        item.expanded = true
        item.advance(0.08)
        const position = item.rise
        const velocity = item.riseVelocity
        item.expanded = false
        compare(item.rise, position)
        compare(item.riseVelocity, velocity)
        item.advance(0.02)
        item.expanded = true
        tryCompare(item, "animating", false, 1000)
        compare(item.reveal, 1)
    }

    function test_reducedMotionAndDisablingMidFlight() {
        const item = surface({animationsEnabled: false})
        const spy = createTemporaryObject(spyComponent, testCase, {target: item})
        item.expanded = true
        compare(item.reveal, 1)
        verify(!item.animating)
        item.expanded = false
        compare(item.reveal, 0)
        compare(spy.count, 1)
        item.animationsEnabled = true
        item.expanded = true
        item.advance(0.05)
        item.animationsEnabled = false
        compare(item.reveal, 1)
        verify(!item.animating)
    }

    function test_contentDoesNotScaleOrRelayoutDuringMorph() {
        const item = surface()
        const content = findChild(item, "content")
        verify(content !== null)
        item.expanded = true
        for (let i = 0; i < 30; i++) {
            item.advance(1 / 180)
            compare(content.width, 876)
            compare(content.height, 64)
            compare(content.scale, 1)
            compare(content.parent.width, item.width)
        }
    }
}
