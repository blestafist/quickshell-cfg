import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
        closeTimer.stop()
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
        closeTimer.restart()
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

    Timer {
        id: closeTimer
        interval: Config.ShellConfig.animationsEnabled ? 360 : 0
        onTriggered: root.presented = false
    }

    Item {
        id: sheet

        readonly property int padding: 12
        readonly property int frameInset: 18
        readonly property int frameFlare: frameInset - 16
        readonly property int frameTopRadius: Theme.Theme.radiusLarge + frameInset - frameFlare
        readonly property int rowHeight: 64
        readonly property int visibleRows: Math.min(Math.max(root.results.length, 1), 7)
        readonly property real listHeight: visibleRows * rowHeight + (visibleRows - 1) * 6 + padding * 2

        z: 1
        width: Math.min(Config.ShellConfig.launcherWidth + frameInset * 2, parent.width - 24)
        height: Math.min(Config.ShellConfig.launcherHeight, listHeight + 76)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.ShellConfig.launcherBottomMargin
        opacity: root.opened ? 1 : 0

        transform: Translate {
            y: root.opened ? 0 : sheet.height + Config.ShellConfig.launcherBottomMargin + 5

            Behavior on y {
                enabled: Config.ShellConfig.animationsEnabled
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
                }
            }
        }

        Behavior on opacity {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation {
                duration: 360
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
            }
        }

        Behavior on height {
            enabled: Config.ShellConfig.animationsEnabled
            NumberAnimation {
                duration: 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
            }
        }

        Canvas {
            id: outerFrame
            x: 0
            y: -sheet.frameInset
            width: parent.width
            height: parent.height + Config.ShellConfig.launcherBottomMargin + sheet.frameInset
            z: -1

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            Connections {
                target: Theme.Theme
                function onSurfaceChanged() { outerFrame.requestPaint() }
            }

            onPaint: {
                const context = getContext("2d")
                const flare = sheet.frameFlare
                const radius = sheet.frameTopRadius
                const frameColor = Qt.darker(Theme.Theme.surface, 1.08)
                context.reset()
                context.beginPath()
                context.moveTo(flare + radius, 0)
                context.lineTo(width - flare - radius, 0)
                context.quadraticCurveTo(width - flare, 0, width - flare, radius)
                context.lineTo(width - flare, height - flare)
                context.bezierCurveTo(width - flare, height - 10, width - 10, height, width, height)
                context.lineTo(0, height)
                context.bezierCurveTo(10, height, flare, height - 10, flare, height - flare)
                context.lineTo(flare, radius)
                context.quadraticCurveTo(flare, 0, flare + radius, 0)
                context.closePath()
                context.fillStyle = frameColor
                context.fill()
                context.strokeStyle = Qt.darker(frameColor, 1.2)
                context.lineWidth = 1
                context.stroke()
            }
        }

        Rectangle {
            id: listSurface
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: search.top; bottomMargin: 12 }
            anchors.leftMargin: sheet.frameInset
            anchors.rightMargin: sheet.frameInset
            color: Theme.Theme.surface
            radius: Theme.Theme.radiusLarge
            border.width: 1
            border.color: Qt.darker(Theme.Theme.surface, 1.2)

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
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1]
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1]
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
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
