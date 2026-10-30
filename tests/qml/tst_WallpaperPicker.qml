import QtQuick
import QtTest
import "../../modules/wallpaper"
import "../../modules/bar" as Bar

TestCase {
    id: testCase
    name: "WallpaperPicker"
    when: windowShown
    visible: true
    width: 1920
    height: 900

    readonly property string imageUrl: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII="

    function initTestCase() {
        testCase.Window.window.width = width
        testCase.Window.window.height = height
    }

    Component {
        id: backendComponent
        QtObject {
            property var entries: []
            property string directory: "/library"
            property string currentPath: "/library/2.png"
            property string error: ""
            property bool loading: false
            property bool applying: false
            property int applies: 0
            property real originX: -1
            property real originY: -1
            property var previewUrls: ({})
            property string previewError: ""
            property string paletteError: ""
            property var requestedPreviews: []
            signal transitionStarted()
            signal applied()
            signal failed()
            function refresh() {}
            function ensurePreviews(items) { requestedPreviews = items }
            function apply(entry, x, y) {
                if (applying) return false
                applies++
                applying = true
                originX = x
                originY = y
                return true
            }
        }
    }
    Component { id: pickerComponent; WallpaperPicker { width: 1920; height: 900 } }
    Component {
        id: toggleComponent
        Bar.DistroButton {
            property var picker
            property int launcherRequests: 0
            property int primaryClicks: 0
            property int secondaryClicks: 0
            z: 20
            closeMode: picker.opened
            onClicked: {
                primaryClicks++
                if (picker.opened) picker.close()
                else launcherRequests++
            }
            onRightClicked: { secondaryClicks++; picker.toggle() }
        }
    }

    function picker(count) {
        const backend = createTemporaryObject(backendComponent, testCase)
        const entries = []
        for (let i = 0; i < (count || 89); i++) {
            entries.push({path: "/library/" + i + ".png", name: "Обои " + i, relative: "Обои " + i + ".png", url: imageUrl, preview: imageUrl, cacheKey: String(i)})
        }
        backend.entries = entries
        const item = createTemporaryObject(pickerComponent, testCase, {wallpapers: backend})
        verify(item !== null)
        return item
    }

    function test_openNavigationSearchAndDismissal() {
        const item = picker()
        item.open()
        compare(item.selectedIndex, 2)
        tryVerify(() => findChild(item, "wallpaperFilmstrip").activeFocus)
        keyClick(Qt.Key_Right)
        compare(item.selectedIndex, 3)
        tryVerify(() => Math.abs(item.position - 3) < 0.001)
        keyClick(Qt.Key_F, Qt.ControlModifier)
        const search = findChild(item, "wallpaperSearch")
        verify(search.activeFocus)
        search.text = "Обои 42"
        compare(item.entries.length, 1)
        compare(item.selected.name, "Обои 42")
        keyClick(Qt.Key_Escape)
        compare(search.text, "")
        compare(item.opened, true)
        item.focusGallery()
        keyClick(Qt.Key_End)
        compare(item.selectedIndex, 88)
        keyClick(Qt.Key_Home)
        compare(item.selectedIndex, 0)
        keyClick(Qt.Key_Escape)
        compare(item.opened, false)
        tryCompare(item, "presented", false, 1200)
    }

    function test_boundedDelegatesWithHugeCollectionAndNoWrapAtEdges() {
        const item = picker(10000)
        item.open()
        verify(item.slotCount < 30)
        item.select(99999)
        compare(item.selectedIndex, 9999)
        tryVerify(() => Math.abs(item.position - 9999) < 0.001, 1800)
        verify(item.firstIndex + item.slotCount <= 10000)
        item.select(-10)
        compare(item.selectedIndex, 0)
        item.close()
    }

    function test_distantSelectionTransitionsAndRequestsDestination_data() {
        return [{tag: "normal", count: 89}, {tag: "huge", count: 10000}]
    }

    function test_distantSelectionTransitionsAndRequestsDestination(data) {
        const item = picker(data.count)
        item.open()
        const start = item.position
        item.select(data.count - 1)
        compare(item.position, start)
        compare(item.travelOpacity, 1)
        tryVerify(() => item.travelOpacity < 0.9, 500)
        tryVerify(() => item.wallpapers.requestedPreviews.length > 0
            && item.wallpapers.requestedPreviews[0].path === item.selected.path, 500)
        tryCompare(item, "position", data.count - 1, 1000)
        tryCompare(item, "travelOpacity", 1, 1000)
        verify(item.slotCount < 30)
        item.close()
    }

    function test_distantSelectionCanBeRetargetedDuringTransition() {
        const item = picker()
        item.open()
        item.select(88)
        wait(70)
        item.select(70)
        tryCompare(item, "position", 70, 1000)
        tryCompare(item, "travelOpacity", 1, 1000)
        item.close()
    }

    function test_englishControlsHaveMatchingHeights() {
        const item = picker()
        const search = findChild(item, "wallpaperSearch")
        const apply = findChild(item, "wallpaperApply")
        compare(search.placeholderText, "Search wallpapers")
        compare(apply.label, "Apply")
        compare(apply.height, search.height)
        compare(apply.height, 56)
    }

    function test_logoCloseControlInterruptsOpeningAndClosing() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton)
        compare(item.opened, true)
        compare(button.closeMode, true)
        wait(30)
        mouseClick(button)
        compare(item.opened, false)
        compare(button.closeMode, false)
        wait(30)
        mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton)
        compare(item.opened, true)
        tryCompare(button, "morph", 1, 600)
        item.close()
        tryCompare(item, "presented", false, 1200)
    }

    function test_logoHasNoDecorationOnHoverPressOrFocus() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        item.open()
        compare(button.background, null)
        compare(button.hoverEnabled, false)
        button.forceActiveFocus()
        verify(button.activeFocus)
        compare(button.background, null)
        mouseMove(button, button.width / 2, button.height / 2)
        compare(button.hovered, false)
        mousePress(button)
        verify(button.down)
        compare(button.background, null)
        mouseRelease(button)
        compare(button.closeMode, false)
        compare(button.background, null)
        mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton)
        compare(button.closeMode, true)
        compare(button.background, null)
    }

    function test_logoRightClicksNeverLeakToShelf() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        item.open()
        wait(750)
        for (let i = 0; i < 12; i++) {
            const expected = !item.opened
            mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton)
            compare(button.secondaryClicks, i + 1)
            compare(button.primaryClicks, 0)
            compare(item.opened, expected, "Each right click must toggle exactly once, even above the shelf")
            wait(30)
        }
        compare(button.launcherRequests, 0)
    }

    function test_logoLeftClickDuringClosingOpensLauncherNotWallpapers() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        item.open()
        wait(750)
        mouseClick(button)
        compare(item.opened, false)
        verify(item.presented)
        mouseClick(button)
        compare(item.opened, false, "The NixOS logo must not reopen wallpapers with the left button")
        compare(button.launcherRequests, 1)
        compare(button.secondaryClicks, 0)
    }

    function test_logoRightClickAllowsMovementInsideButton() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        mousePress(button, 3, button.height / 2, Qt.RightButton)
        mouseMove(button, button.width - 3, button.height / 2)
        mouseRelease(button, button.width - 3, button.height / 2, Qt.RightButton)
        compare(button.secondaryClicks, 1)
        compare(button.primaryClicks, 0)
        compare(item.opened, true)
    }

    function test_logoRightDoubleClickStillRegistersBothClicks() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        mouseDoubleClickSequence(button, button.width / 2, button.height / 2, Qt.RightButton)
        compare(button.secondaryClicks, 2)
        compare(button.primaryClicks, 0)
        compare(item.opened, false)
    }

    function test_logoRightReleaseOutsideCancelsWithoutPoisoningNextClick() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        mousePress(button, button.width / 2, button.height / 2, Qt.RightButton)
        mouseMove(button, button.width + 30, button.height / 2)
        mouseRelease(button, button.width + 30, button.height / 2, Qt.RightButton)
        compare(button.secondaryClicks, 0)
        compare(item.opened, false)
        mouseClick(button)
        compare(button.launcherRequests, 1)
        compare(button.secondaryClicks, 0)
        mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton)
        compare(button.secondaryClicks, 1)
        compare(item.opened, true)
    }

    function test_logoKeyboardActivationKeepsPrimaryAction() {
        const item = picker()
        const button = createTemporaryObject(toggleComponent, testCase, {picker: item})
        button.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(button.launcherRequests, 1)
        compare(item.opened, false)
        item.open()
        wait(30)
        button.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(item.opened, false)
        compare(button.launcherRequests, 1)
        keyClick(Qt.Key_Space)
        compare(item.opened, false)
        compare(button.launcherRequests, 2)
        compare(button.secondaryClicks, 0)
    }

    function test_randomButtonSelectsAnotherFilteredWallpaperWithoutApplying() {
        const item = picker()
        item.open()
        wait(750)
        const random = findChild(item, "wallpaperRandom")
        verify(random !== null)
        compare(random.hint, "Random wallpaper")
        for (let i = 0; i < 12; i++) {
            const previous = item.selectedIndex
            mouseClick(random)
            verify(item.selectedIndex !== previous)
            verify(item.selectedIndex >= 0 && item.selectedIndex < item.entries.length)
            compare(item.wallpapers.applies, 0)
        }
        const search = findChild(item, "wallpaperSearch")
        search.text = "Обои 4"
        compare(item.entries.length, 11)
        mouseClick(random)
        verify(item.selected.name.startsWith("Обои 4"))
        search.text = "Обои 42"
        compare(random.enabled, false)
        search.text = "missing"
        compare(random.enabled, false)
        search.text = ""
        compare(random.enabled, true)
        item.wallpapers.applying = true
        compare(random.enabled, false)
        item.close()
    }

    function test_clockReturnsBeforeShelfFinishesClosingWithoutReversalJumps() {
        const item = picker()
        compare(item.barContentOpacity, 1)
        item.open()
        tryCompare(item, "barContentOpacity", 0, 1200)
        wait(650)
        item.close()
        compare(item.barContentOpacity, 0)
        tryVerify(() => item.barContentOpacity > 0.95 && item.presented, 800)
        compare(item.opened, false)
        compare(findChild(item, "wallpaperFilmstrip").opacity, 0)
        const beforeReopening = item.barContentOpacity
        item.open()
        compare(item.barContentOpacity, beforeReopening)
        tryCompare(item, "barContentOpacity", 0, 1200)
        item.close()
        tryCompare(item, "presented", false, 1200)
        compare(item.barContentOpacity, 1)
    }

    function test_closeDuringPreparationCancelsUnsubmittedApply() {
        const item = picker()
        item.open()
        item.applyCurrent()
        compare(item.phase, "preparing")
        item.close()
        wait(100)
        compare(item.wallpapers.applies, 0)
        compare(item.trackingApply, false)
        compare(item.opened, false)
    }

    function test_closeDuringFlightAndReopenIgnoresLateCompletion() {
        const item = picker()
        item.open()
        item.applyCurrent()
        tryCompare(item, "phase", "launching", 1500)
        item.wallpapers.transitionStarted()
        wait(80)
        verify(item.flightProgress > 0)
        item.close()
        compare(item.phase, "idle")
        compare(item.flightProgress, 0)
        compare(item.trackingApply, false)
        item.open()
        compare(item.opened, true)
        item.wallpapers.applying = false
        item.wallpapers.applied()
        compare(item.opened, true)
        compare(item.phase, "idle")
        item.close()
        item.wallpapers.failed()
        compare(item.opened, false)
        tryCompare(item, "presented", false, 1200)
    }

    function test_clickSideCardFocusesAndDragDoesNotApply() {
        const item = picker()
        item.open()
        wait(750)
        const card = findChild(item, "wallpaperCard3")
        verify(card !== null)
        mouseClick(card, card.width / 2, card.height / 2)
        compare(item.selectedIndex, 3)
        compare(item.wallpapers.applies, 0)
        tryVerify(() => Math.abs(item.position - 3) < 0.001)
        const strip = findChild(item, "wallpaperFilmstrip")
        mouseDrag(strip, strip.width / 2, strip.height / 2, -220, 0)
        compare(item.wallpapers.applies, 0)
        verify(item.selectedIndex > 3)
        item.close()
    }

    function test_failedAndSlowHandoffsRestoreShelf() {
        const item = picker()
        item.open()
        item.applyCurrent()
        tryCompare(item, "phase", "launching", 1500)
        verify(item.wallpapers.originX >= 0 && item.wallpapers.originX <= 1)
        compare(item.wallpapers.originY, 0)
        item.wallpapers.transitionStarted()
        compare(item.phase, "flying")
        tryCompare(item, "phase", "waiting", 2000)
        compare(item.flightProgress, 0)
        compare(item.opened, true)
        item.wallpapers.error = "awww failed"
        item.wallpapers.applying = false
        item.wallpapers.failed()
        compare(item.phase, "idle")
        compare(item.opened, true)
        compare(item.selectedIndex, 2)
        item.close()
    }

    function test_latePreviewsPopulateCardsAndAllowApply() {
        const item = picker()
        item.wallpapers.entries = item.wallpapers.entries.map(entry => Object.assign({}, entry, {preview: ""}))
        item.open()
        const card = findChild(item, "wallpaperCard2")
        verify(card !== null)
        compare(card.frameItem.source, "")
        compare(card.frameItem.ready, false)
        item.applyCurrent()
        compare(item.phase, "preparing")
        compare(item.wallpapers.applies, 0)
        item.wallpapers.previewUrls = {"2": imageUrl}
        tryVerify(() => card.frameItem.ready)
        tryCompare(item, "phase", "launching", 1500)
        compare(item.wallpapers.applies, 1)
        item.wallpapers.applying = false
        item.wallpapers.failed()
        item.close()
    }

    function test_confirmedSuccessClosesAfterVisualHandoff() {
        const item = picker()
        item.open()
        item.applyCurrent()
        tryCompare(item, "phase", "launching", 1500)
        item.wallpapers.transitionStarted()
        item.wallpapers.applying = false
        item.wallpapers.applied()
        compare(item.opened, true)
        tryCompare(item, "opened", false, 2000)
        compare(item.phase, "idle")
        compare(findChild(item, "wallpaperHandoff").source, "")
        // Regression: the first successful apply used to leave all opacity
        // bindings at zero on every subsequent opening.
        compare(item.flightProgress, 0)
        item.open()
        tryVerify(() => findChild(item, "wallpaperFilmstrip").opacity > 0.99, 1200)
        verify(findChild(item, "wallpaperSearch").visible)
        item.close()
    }
}
