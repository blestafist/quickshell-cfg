import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

import "../../config" as Config
import "../../theme" as Theme

PanelWindow {
    id: root

    property bool opened: false
    property bool presented: false
    property string message: ""
    property int selectedIndex: 0
    property var applications: []
    property var commands: [
        { kind: "command", name: "Terminal", description: "Open Kitty", keywords: "shell console kitty", icon: "", command: Config.ShellConfig.terminalCommand },
        { kind: "command", name: "Lock screen", description: "Lock with hyprlock", keywords: "session security", icon: "󰌾", command: "hyprlock" },
        { kind: "command", name: "Reload shell", description: "Restart QuickShell configuration", keywords: "quickshell config", icon: "󰑓", command: "~/.config/quickshell/scripts/shellctl reload" }
    ]
    property var results: []

    property var targetScreen: Quickshell.screens.find(screen => screen.name === Config.MachineConfig.primaryMonitor)
    screen: targetScreen
    visible: presented && targetScreen !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    focusable: opened
    mask: Region {
        width: root.opened ? root.width : 0
        height: root.opened ? root.height : 0
    }

    function open(clearMessage = true) {
        if (clearMessage)
            message = ""
        search.text = ""
        filterResults("")
        presented = true
        Qt.callLater(() => {
            opened = true
            search.forceActiveFocus()
        })
    }

    function close() {
        opened = false
    }

    function toggle() { opened ? close() : open() }
    function showMessage(text) { message = text; open(false) }

    function normalized(value) { return (value || "").toLowerCase() }

    function score(item, query) {
        const name = normalized(item.name)
        const searchable = name + " " + normalized(item.description) + " " + normalized(item.keywords)
        if (!query)
            return item.kind === "application" ? 1 : 0
        if (name.startsWith(query))
            return 100
        if (name.includes(query))
            return 70
        if (searchable.includes(query))
            return 40
        return -1
    }

    function filterResults(query) {
        const needle = normalized(query).trim()
        const scored = applications.concat(commands).map(item => ({ item: item, score: score(item, needle) })).filter(entry => entry.score >= 0)
        scored.sort((first, second) => second.score - first.score || first.item.name.localeCompare(second.item.name))
        results = scored.map(entry => entry.item)
        selectedIndex = 0
        resultList.positionViewAtBeginning()
    }

    function moveSelection(offset) {
        if (!results.length)
            return
        selectedIndex = (selectedIndex + offset + results.length) % results.length
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function activate(item) {
        if (!item)
            return
        if (item.kind === "application")
            commandRunner.command = ["gio", "launch", item.desktopFile]
        else
            commandRunner.command = ["sh", "-c", item.command]
        commandRunner.startDetached()
        close()
    }

    Process { id: commandRunner }

    Item {
        id: sheet

        readonly property int padding: 12
        readonly property int frameInset: 36
        readonly property real frameFlare: 36 + 32 * (1 - reveal)
        readonly property real frameTopRadius: Math.min(width / 2 - frameFlare, 40 + 100 * (1 - reveal))
        property real reveal: root.opened ? 1 : 0
        readonly property real swell: Math.sin(reveal * Math.PI)
        readonly property int rowHeight: 72
        readonly property int visibleRows: Math.min(Math.max(root.results.length, 1), 7)
        readonly property real listHeight: visibleRows * rowHeight + (visibleRows - 1) * 6 + padding * 2

        z: 1
        width: Math.min(Config.ShellConfig.launcherWidth + frameInset * 2, parent.width - 24)
        height: Math.min(Config.ShellConfig.launcherHeight, listHeight + 76, parent.height - Config.ShellConfig.launcherBottomMargin - frameInset - 12)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.ShellConfig.launcherBottomMargin
        enabled: root.opened
        visible: reveal > 0
        // Keep the entire surface attached to the screen edge throughout the morph.
        transform: Scale {
            origin.x: sheet.width / 2
            origin.y: sheet.height + Config.ShellConfig.launcherBottomMargin
            xScale: 0.18 + 0.82 * sheet.reveal - 0.10 * sheet.swell
            yScale: sheet.reveal + 0.12 * sheet.swell
        }

        onRevealChanged: {
            if (reveal === 0 && !root.opened)
                root.presented = false
        }

        Behavior on reveal {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation {
                duration: root.opened ? 560 : 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 0.72, 0.18, 1, 1, 1]
            }
        }

        Behavior on height {
            enabled: Config.ShellConfig.animationsEnabled && root.presented
            NumberAnimation {
                duration: 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 0.72, 0.18, 1, 1, 1]
            }
        }

        Shape {
            id: outerFrame
            x: 0
            y: -sheet.frameInset
            width: parent.width
            height: parent.height + Config.ShellConfig.launcherBottomMargin + sheet.frameInset
            z: -1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                readonly property real f: sheet.frameFlare
                readonly property real r: sheet.frameTopRadius
                readonly property real w: outerFrame.width
                readonly property real h: outerFrame.height
                id: outline
                strokeWidth: 0
                fillColor: Theme.Theme.surface
                startX: f + r
                startY: 0
                PathLine { x: outline.w - outline.f - outline.r; y: 0 }
                PathQuad { x: outline.w - outline.f; y: outline.r; controlX: outline.w - outline.f; controlY: 0 }
                PathLine { x: outline.w - outline.f; y: outline.h - outline.f }
                PathCubic {
                    x: outline.w; y: outline.h
                    control1X: outline.w - outline.f; control1Y: outline.h - outline.f * 0.35
                    control2X: outline.w - outline.f * 0.65; control2Y: outline.h
                }
                PathLine { x: 0; y: outline.h }
                PathCubic {
                    x: outline.f; y: outline.h - outline.f
                    control1X: outline.f * 0.65; control1Y: outline.h
                    control2X: outline.f; control2Y: outline.h - outline.f * 0.35
                }
                PathLine { x: outline.f; y: outline.r }
                PathQuad { x: outline.f + outline.r; y: 0; controlX: outline.f; controlY: 0 }
            }
        }

        Item {
            id: listSurface
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: search.top; bottomMargin: 12 }
            anchors.leftMargin: sheet.frameInset
            anchors.rightMargin: sheet.frameInset

            ListView {
                id: resultList
                anchors.fill: parent
                anchors.margins: sheet.padding
                clip: true
                model: root.results
                currentIndex: root.selectedIndex
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightRangeMode: ListView.ApplyRange
                highlightFollowsCurrentItem: false

                highlight: Rectangle {
                    width: resultList.width
                    height: sheet.rowHeight
                    radius: Theme.Theme.radiusMedium
                    color: Theme.Theme.surfaceHover
                    y: resultList.currentItem ? resultList.currentItem.y : 0

                    Behavior on y {
                        enabled: Config.ShellConfig.animationsEnabled
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
                        }
                    }
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.ShellConfig.animationsEnabled ? 160 : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1]
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.ShellConfig.animationsEnabled ? 120 : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1]
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Config.ShellConfig.animationsEnabled ? 280 : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.22, 0.72, 0.18, 1, 1, 1]
                    }
                }

                delegate: Rectangle {
                    id: resultDelegate
                    required property var modelData
                    required property int index

                    width: resultList.width
                    height: sheet.rowHeight
                    radius: Theme.Theme.radiusMedium
                    color: delegateMouse.containsMouse && index !== root.selectedIndex ? Theme.Theme.surfaceRaised : "transparent"

                    Behavior on color {
                        enabled: Config.ShellConfig.animationsEnabled
                        ColorAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 13

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: Theme.Theme.radiusSmall
                            color: modelData.kind === "command" ? Theme.Theme.surfaceRaised : "transparent"

                            Image {
                                id: applicationIcon
                                anchors.fill: parent
                                anchors.margins: 4
                                visible: modelData.kind === "application"
                                source: visible ? Quickshell.iconPath(modelData.icon, true) : ""
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.kind === "application" && applicationIcon.status !== Image.Ready
                                text: "󰏗"
                                color: Theme.Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 17
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.kind === "command"
                                text: modelData.icon
                                color: Theme.Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 17
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.Theme.textPrimary
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description || ""
                                visible: text !== ""
                                color: Theme.Theme.textMuted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selectedIndex = index
                        onClicked: root.activate(modelData)
                    }
                }

                footer: Text {
                    width: resultList.width
                    height: resultList.height
                    visible: resultList.count === 0
                    text: root.message !== "" ? root.message : "No results"
                    color: root.message !== "" ? Theme.Theme.accent : Theme.Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    topPadding: 0
                    font.pixelSize: 14
                }
            }
        }

        TextField {
            id: search
            height: 64
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.leftMargin: sheet.frameInset
            anchors.rightMargin: sheet.frameInset
            placeholderText: "Search applications and commands"
            color: Theme.Theme.textPrimary
            placeholderTextColor: Theme.Theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            leftPadding: 52
            rightPadding: clearButton.width + 26
            selectByMouse: true
            onTextChanged: root.filterResults(text)
            onAccepted: root.activate(root.results[root.selectedIndex])
            Keys.onEscapePressed: root.close()
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)

            background: Rectangle {
                color: Theme.Theme.surfaceRaised
                radius: height / 2
                border.width: 1
                border.color: Qt.darker(Theme.Theme.surfaceRaised, 1.15)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
            }

            Text {
                id: clearButton
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text !== ""
                text: "󰅖"
                color: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: search.clear()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        enabled: root.opened
        onClicked: root.close()
    }

    onApplicationsChanged: filterResults(search.text)
}
