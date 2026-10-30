import QtQuick
import QtQuick.Controls

import "../../config" as Config
import "../../theme" as Theme
import "../launcher/LiquidMotion.js" as Spring
import "WallpaperMotion.js" as Motion

FocusScope {
    id: root

    required property var wallpapers
    property real seedWidth: 340
    property real barHeight: 42
    property bool opened: false
    property var entries: []
    property int selectedIndex: -1
    property real position: 0
    property real velocity: 0
    property real travelOpacity: 1
    property real dragOrigin: 0
    property bool restoreCurrent: true
    property string phase: "idle"
    property var pendingEntry: null
    property rect launchRect: Qt.rect(0, 0, 1, 1)
    property real flightProgress: 0
    property bool applySucceeded: false
    property bool trackingApply: false

    readonly property bool busy: phase !== "idle" || wallpapers.applying
    readonly property bool flying: phase === "flying"
    readonly property bool presented: opened || shelf.animating || flying
    // Restore the clock before the shelf disappears, without a state-change
    // jump when opening or closing is reversed midway through the morph.
    readonly property real barContentOpacity: 1 - Motion.smoothstep(0, 0.23, shelf.contentProgress)
    readonly property var selected: entries[selectedIndex] || null
    readonly property real panelHeight: Math.max(barHeight, Math.min(Config.ShellConfig.wallpaperPanelHeight, height - 32))
    readonly property real heroWidth: Math.min(560, width * 0.38)
    readonly property real heroHeight: Math.max(60, panelHeight - 110)
    readonly property real baseWidth: Math.min(174, Math.max(90, width * 0.13))
    readonly property real cardGap: 12
    readonly property int slotCount: Math.min(entries.length, 2 * Math.ceil(width / (baseWidth + cardGap) / 2) + 7)
    readonly property int firstIndex: Motion.windowStart(position, entries.length, slotCount)

    signal opening()

    function open() {
        if (opened) return
        flight.stop()
        trackingApply = false
        phase = "idle"
        flightProgress = 0
        handoff.source = ""
        pendingEntry = null
        restoreCurrent = true
        search.text = ""
        refilter(true)
        opened = true
        opening()
        Qt.callLater(() => { if (opened) root.focusGallery() })
    }

    function close() {
        // Dismiss the presentation, not the already submitted awww command.
        // Late decoder/daemon callbacks must not reopen or close a new shelf.
        opened = false
        trackingApply = false
        flight.stop()
        scrollClock.running = false
        longTravel.stop()
        travelOpacity = 1
        snap.stop()
        phase = "idle"
        flightProgress = 0
        handoff.source = ""
        pendingEntry = null
        search.focus = false
    }

    function toggle() { opened ? close() : open() }

    function focusGallery() {
        search.focus = false
        filmstrip.forceActiveFocus()
    }

    function status(): string {
        return JSON.stringify({ opened: opened, phase: phase, count: entries.length,
            current: wallpapers.currentPath, directory: wallpapers.directory, error: wallpapers.error,
            themeError: wallpapers.paletteError || "" })
    }

    function refilter(preferCurrent) {
        const oldPath = selected ? selected.path : ""
        entries = Motion.filter(wallpapers.entries, search.text)
        const wanted = preferCurrent && !search.text.trim() ? wallpapers.currentPath : oldPath
        const found = entries.findIndex(entry => entry.path === wanted)
        selectedIndex = entries.length ? Math.max(0, found) : -1
        scrollClock.running = false
        longTravel.stop()
        travelOpacity = 1
        position = Math.max(0, selectedIndex)
        velocity = 0
        previewRequest.restart()
    }

    function previewFor(entry) {
        return entry ? wallpapers.previewUrls[entry.cacheKey] || entry.preview || "" : ""
    }

    function requestPreviews() {
        if (!entries.length) return
        const center = Math.max(0, drag.active || snap.running ? Math.round(position) : selectedIndex)
        const radius = Math.ceil(slotCount / 2) + 2
        const wanted = []
        // Centre-out priorities prepare the hero and its immediate neighbours first.
        for (let distance = 0; distance <= radius; distance++) {
            for (const index of distance ? [center - distance, center + distance] : [center]) {
                if (entries[index]) wanted.push(entries[index])
            }
        }
        wallpapers.ensurePreviews(wanted)
    }

    onFirstIndexChanged: previewRequest.restart()
    onSelectedIndexChanged: previewRequest.restart()

    function select(index) {
        if (busy || !entries.length) return
        selectedIndex = Motion.clamp(index, 0, entries.length - 1)
        if (!Config.ShellConfig.animationsEnabled) {
            longTravel.stop()
            travelOpacity = 1
            scrollClock.running = false
            position = selectedIndex
            velocity = 0
        } else if (longTravel.running || Math.abs(selectedIndex - position) >= slotCount * 2) {
            scrollClock.running = false
            velocity = 0
            longTravel.restart()
        } else scrollClock.running = true
        root.focusGallery()
    }

    function shuffle() {
        if (entries.length < 2) return
        select((Math.max(0, selectedIndex) + 1 + Math.floor(Math.random() * (entries.length - 1))) % entries.length)
    }

    function scrollGallery(wheel) {
        if (!entries.length || busy) return
        const pixels = wheel.pixelDelta.x || wheel.pixelDelta.y
        const angle = wheel.angleDelta.x || wheel.angleDelta.y
        // Some mice report pixel deltas as well as wheel ticks. Treat those as
        // discrete steps rather than waiting for half a card's worth of pixels.
        if (pixels && wheel.device && wheel.device.deviceType === PointerDevice.TouchPad) {
            scrollClock.running = false
            longTravel.stop()
            travelOpacity = 1
            velocity = 0
            position = Motion.clamp(position - pixels / (baseWidth + cardGap), 0, entries.length - 1)
            snap.restart()
        } else {
            const delta = angle || pixels
            if (delta) {
                snap.stop()
                select(selectedIndex - Math.sign(delta))
            }
        }
        wheel.accepted = true
    }

    function applyCurrent() {
        if (!selected || busy) return
        if (longTravel.running) {
            longTravel.stop()
            position = selectedIndex
            travelOpacity = 1
        }
        pendingEntry = selected
        launchRect = Qt.rect((width - heroWidth) / 2, filmstrip.y + 12, heroWidth, heroHeight)
        for (let i = 0; i < cards.count; i++) {
            const item = cards.itemAt(i)
            if (item && item.entryIndex === selectedIndex) {
                const frame = item.frameItem
                const point = frame.mapToItem(root, 0, 0)
                launchRect = Qt.rect(point.x, point.y, frame.width, frame.height)
                break
            }
        }
        flightProgress = 0
        applySucceeded = false
        trackingApply = true
        phase = "preparing"
        // Reuse the small cached preview for the droplet. Only awww decodes
        // the original: the shell never allocates a fullscreen photograph.
        handoff.source = previewFor(pendingEntry)
        Qt.callLater(startApply)
    }

    function startApply() {
        if (phase !== "preparing" || !handoff.ready) return
        phase = "launching"
        if (!wallpapers.apply(pendingEntry,
                Motion.clamp((launchRect.x + launchRect.width / 2) / width, 0, 1),
                0)) {
            fail("A wallpaper change is already in progress.")
        }
    }

    function finishFlight() {
        if (!applySucceeded) {
            // A slow daemon must not leave an invisible, keyboard-grabbing
            // fullscreen surface. Restore the shelf with progress feedback.
            phase = "waiting"
            flightProgress = 0
            return
        }
        opened = false
        trackingApply = false
        phase = "idle"
        flightProgress = 0
        handoff.source = ""
        pendingEntry = null
    }

    function fail(message) {
        flight.stop()
        trackingApply = false
        phase = "idle"
        flightProgress = 0
        handoff.source = ""
        pendingEntry = null
        if (message) wallpapers.error = message
        opened = true
        root.focusGallery()
    }

    Keys.onEscapePressed: close()
    Keys.onLeftPressed: select(selectedIndex - 1)
    Keys.onRightPressed: select(selectedIndex + 1)
    Keys.onReturnPressed: applyCurrent()
    Keys.onEnterPressed: applyCurrent()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            select(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            select(entries.length - 1)
            event.accepted = true
        } else if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_F) {
            search.forceActiveFocus()
            search.selectAll()
            event.accepted = true
        } else if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_R) {
            wallpapers.refresh()
            event.accepted = true
        }
    }

    Connections {
        target: root.wallpapers
        function onEntriesChanged() { root.refilter(root.restoreCurrent) }
        function onLoadingChanged() {
            if (!root.wallpapers.loading && root.opened && !root.busy) {
                root.refilter(root.restoreCurrent)
                root.restoreCurrent = false
            }
        }
        function onTransitionStarted() {
            if (!root.trackingApply || root.phase !== "launching") return
            root.phase = "flying"
            if (Config.ShellConfig.animationsEnabled) flight.restart()
            else { root.flightProgress = 1; root.phase = "waiting" }
        }
        function onApplied() {
            if (!root.trackingApply) return
            root.applySucceeded = true
            if (!flight.running) root.finishFlight()
        }
        function onFailed() { if (root.trackingApply) root.fail("") }
        function onPreviewUrlsChanged() {
            if (root.phase === "preparing") handoff.source = root.previewFor(root.pendingEntry)
        }
    }

    FrameAnimation {
        id: scrollClock
        onTriggered: {
            const state = Spring.spring(root.position, root.velocity, root.selectedIndex, frameTime, 19, 0.88)
            root.position = state.position
            root.velocity = state.velocity
            if (Spring.settled(root.position, root.velocity, root.selectedIndex)) {
                running = false
                root.position = root.selectedIndex
                root.velocity = 0
            }
        }
    }

    // A distant destination is outside the recycled window. Fade the strip
    // out before moving that window, then reveal the requested previews;
    // flying through thousands of unloaded images would flash and stutter.
    SequentialAnimation {
        id: longTravel
        NumberAnimation { target: root; property: "travelOpacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
        ScriptAction { script: { root.position = root.selectedIndex; root.velocity = 0 } }
        NumberAnimation { target: root; property: "travelOpacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
    }

    Timer {
        id: previewRequest
        interval: 24
        onTriggered: root.requestPreviews()
    }

    Timer {
        interval: 10000
        running: root.phase === "preparing"
        onTriggered: root.fail("Could not load this image. Try another file.")
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.presented
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()
    }

    WallpaperSurface {
        id: shelf
        width: root.width
        height: root.panelHeight
        seedWidth: root.seedWidth
        barHeight: root.barHeight
        expanded: root.opened && !(root.flying && root.flightProgress > 0.18)
        animationsEnabled: Config.ShellConfig.animationsEnabled
        surfaceColor: Theme.Theme.surface
        visible: root.presented

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => { if (mouse.button === Qt.RightButton) root.close() }
        }

        Item {
            id: filmstrip
            objectName: "wallpaperFilmstrip"
            y: 20
            width: root.width
            height: root.heroHeight + 14
            clip: true
            enabled: root.opened && !root.busy
            opacity: Motion.smoothstep(0.23, 0.88, shelf.contentProgress)
                * (1 - Motion.smoothstep(0.02, 0.34, root.flightProgress))
                * root.travelOpacity
            transform: Translate { y: (1 - Motion.smoothstep(0.15, 1, shelf.contentProgress)) * -18 }

            Repeater {
                id: cards
                model: root.slotCount
                delegate: Item {
                    id: card
                    objectName: "wallpaperCard" + entryIndex
                    required property int index
                    readonly property int entryIndex: Motion.slotIndex(index, root.firstIndex, root.slotCount)
                    readonly property var entry: root.entries[entryIndex] || null
                    readonly property real distance: entryIndex - root.position
                    readonly property var geometry: Motion.card(distance, root.baseWidth, root.heroWidth, root.heroHeight, root.cardGap)
                    readonly property bool selected: root.selectedIndex === entryIndex
                    readonly property alias frameItem: photograph

                    x: root.width / 2 + geometry.offset - width / 2
                    y: (filmstrip.height - height) / 2
                    width: geometry.width
                    height: geometry.height
                    visible: x + width > -24 && x < filmstrip.width + 24 && entry !== null
                    opacity: geometry.opacity
                    z: geometry.focus
                    Accessible.role: Accessible.Button
                    Accessible.name: entry ? "Apply wallpaper: " + entry.name : ""
                    Accessible.description: entry && entry.path === root.wallpapers.currentPath ? "Current wallpaper" : ""
                    Accessible.onPressAction: { root.select(entryIndex); root.applyCurrent() }

                    WallpaperImage {
                        id: photograph
                        anchors.fill: parent
                        source: root.previewFor(card.entry)
                        borderColor: Qt.alpha(Theme.Theme.accent, card.selected ? 0.8 : hover.hovered ? 0.35 : 0)
                        borderWidth: card.selected ? 1.5 : 1
                    }
                    Rectangle {
                        x: parent.width - photograph.slant - 40
                        y: 14
                        width: 26; height: 26; radius: 13
                        color: Qt.alpha(Theme.Theme.background, 0.85)
                        visible: card.entry !== null && card.entry.path === root.wallpapers.currentPath
                        MaterialIcon { anchors.centerIn: parent; name: "check"; width: 18; height: 18; color: Theme.Theme.accent }
                    }
                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: eventPoint => {
                            const p = eventPoint.position
                            if (p.x < photograph.slant * (1 - p.y / card.height)
                                    || p.x > card.width - photograph.slant * p.y / card.height) return
                            if (card.selected) root.applyCurrent()
                            else root.select(card.entryIndex)
                        }
                    }
                }
            }

            DragHandler {
                id: drag
                target: null
                enabled: root.entries.length > 1
                xAxis.enabled: true
                yAxis.enabled: false
                onActiveChanged: {
                    if (active) {
                        scrollClock.running = false
                        longTravel.stop()
                        root.travelOpacity = 1
                        root.velocity = 0
                        root.dragOrigin = root.position
                    } else root.select(Math.round(root.position))
                }
                onActiveTranslationChanged: if (active) {
                    root.position = Motion.clamp(root.dragOrigin - activeTranslation.x / (root.baseWidth + root.cardGap), 0, root.entries.length - 1)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => root.scrollGallery(wheel)
            }
            Timer { id: snap; interval: 140; onTriggered: root.select(Math.round(root.position)) }

            Column {
                anchors.centerIn: parent
                width: Math.min(640, parent.width - 64)
                spacing: 12
                visible: root.entries.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.wallpapers.loading ? "Loading wallpapers…" : search.text ? "No results" : "Your wallpapers will appear here"
                    color: Theme.Theme.textPrimary
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    text: root.wallpapers.error || (search.text ? "Try another name" : "Add images to your configured wallpaper folder")
                    textFormat: Text.PlainText
                    color: Theme.Theme.textSecondary
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }

        Item {
            id: footer
            x: 24
            y: root.panelHeight - 72
            width: root.width - 48
            height: 56
            enabled: root.opened && !root.busy
            opacity: Motion.smoothstep(0.48, 0.98, shelf.contentProgress)
                * (1 - Motion.smoothstep(0, 0.25, root.flightProgress))

            Row {
                id: navigation
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                WallpaperButton { iconName: "previous"; hint: "Previous wallpaper"; enabled: root.selectedIndex > 0; onClicked: root.select(root.selectedIndex - 1) }
                Text {
                    width: 80; height: 40
                    text: root.entries.length ? String(root.selectedIndex + 1).padStart(2, "0") + " / " + String(root.entries.length).padStart(2, "0") : "— / —"
                    color: Theme.Theme.textSecondary
                    font.family: "Noto Sans"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                WallpaperButton { iconName: "next"; hint: "Next wallpaper"; enabled: root.selectedIndex >= 0 && root.selectedIndex < root.entries.length - 1; onClicked: root.select(root.selectedIndex + 1) }
                WallpaperButton {
                    objectName: "wallpaperRandom"
                    iconName: "shuffle"
                    hint: "Random wallpaper"
                    enabled: root.entries.length > 1
                    onClicked: root.shuffle()
                }
            }

            Text {
                x: navigation.width + 24
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, controls.x - x - 24)
                text: root.wallpapers.error || root.wallpapers.previewError || root.wallpapers.paletteError || (root.busy ? "Applying…" : "")
                textFormat: Text.PlainText
                color: root.wallpapers.error ? Theme.Theme.danger : Theme.Theme.textSecondary
                font.family: "Noto Sans"
                font.pixelSize: 14
                elide: Text.ElideRight
                ToolTip.visible: errorHover.hovered && text !== ""
                ToolTip.text: text
                HoverHandler { id: errorHover }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                TextField {
                    id: search
                    objectName: "wallpaperSearch"
                    width: Math.min(360, Math.max(140, root.width - navigation.width - 248))
                    height: 56
                    placeholderText: "Search wallpapers"
                    color: Theme.Theme.textPrimary
                    placeholderTextColor: Theme.Theme.textSecondary
                    selectionColor: Theme.Theme.accent
                    selectedTextColor: Theme.Theme.accentText
                    font.family: "Noto Sans"
                    font.pixelSize: 16
                    leftPadding: 52
                    rightPadding: 20
                    selectByMouse: true
                    onTextChanged: root.refilter(false)
                    onAccepted: { root.focusGallery(); root.applyCurrent() }
                    Keys.onEscapePressed: text ? clear() : root.close()
                    Keys.onDownPressed: root.focusGallery()
                    Accessible.name: "Search wallpapers"
                    background: Rectangle {
                        radius: height / 2
                        color: Theme.Theme.surfaceRaised
                        border.width: search.activeFocus ? 2 : 0
                        border.color: Theme.Theme.accent
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.Theme.textPrimary
                            opacity: search.hovered ? 0.08 : 0
                        }
                    }
                    MaterialIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; color: Theme.Theme.textSecondary }
                }
                WallpaperButton {
                    objectName: "wallpaperApply"
                    label: "Apply"
                    hint: "Apply selected wallpaper"
                    width: 128
                    height: search.height
                    labelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    primary: true
                    enabled: !!root.selected
                    onClicked: root.applyCurrent()
                }
            }
        }
    }

    WallpaperImage {
        id: handoff
        objectName: "wallpaperHandoff"
        z: 5
        readonly property real drain: Motion.smoothstep(0.08, 1, root.flightProgress)
        x: root.launchRect.x + (root.launchRect.width - width) / 2
        y: root.launchRect.y * (1 - Motion.smoothstep(0, 0.52, root.flightProgress))
        width: Math.max(1, root.launchRect.width * (1 - drain))
        height: Math.max(1, root.launchRect.height * (1 - drain))
        slant: Math.min(root.launchRect.height * 0.22, root.launchRect.width * 0.38) * (1 - Motion.smoothstep(0, 0.25, root.flightProgress))
        cornerRadius: 12 + 24 * drain
        droplet: Motion.smoothstep(0, 0.6, root.flightProgress)
        visible: root.flying && Config.ShellConfig.animationsEnabled
        opacity: 1 - Motion.smoothstep(0.78, 1, root.flightProgress)
        onReadyChanged: if (ready) Qt.callLater(root.startApply)
        onBrokenChanged: if (broken) Qt.callLater(() => {
            if (broken && root.phase === "preparing") root.fail("This image is damaged or its format is unsupported.")
        })
    }

    NumberAnimation {
        id: flight
        target: root
        property: "flightProgress"
        from: 0
        to: 1
        duration: 640
        easing.type: Easing.Linear
        onFinished: root.finishFlight()
    }
}
