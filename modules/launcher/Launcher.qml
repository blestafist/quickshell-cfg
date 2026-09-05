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
    readonly property bool presented: opened || revealAnimation.running
    property string message: ""
    property int selectedIndex: 0
    property var applications: []
    property var commands: [
        { kind: "command", name: "Terminal", description: "Open Kitty", keywords: "shell console kitty", icon: "", command: Config.ShellConfig.terminalCommand },
        { kind: "command", name: "Lock screen", description: "Lock with hyprlock", keywords: "session security", icon: "󰌾", command: "hyprlock" },
        { kind: "command", name: "Reload shell", description: "Restart QuickShell configuration", keywords: "quickshell config", icon: "󰑓", command: "~/.config/quickshell/scripts/shellctl reload" }
    ]
    property var results: []

    property var targetScreen: Quickshell.screens.find(screen => screen.name === Config.MachineConfig.primaryMonitor) ?? null
    screen: targetScreen
    // Keep the transparent surface mapped to avoid compositor animations on every toggle.
    visible: targetScreen !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    focusable: opened
    mask: Region {
        width: root.opened ? root.width : 0
        height: root.opened ? root.height : 0
    }

    function open(clearMessage = true) {
        if (opened && clearMessage && message === "") {
            search.forceActiveFocus()
            return
        }
        if (clearMessage)
            message = ""
        if (search.text === "")
            filterResults("")
        else
            search.text = ""
        opened = true
        Qt.callLater(() => {
            if (opened)
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
        if (message !== "") {
            results = []
            selectedIndex = 0
            return
        }
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

        readonly property int padding: 16
        readonly property int frameInset: 28
        readonly property int rowHeight: 64
        readonly property int topRadius: 28
        readonly property int visibleRows: Math.min(Math.max(root.results.length, 1), 7)
        readonly property real naturalHeight: Math.min(Config.ShellConfig.launcherHeight, (root.screen ? root.screen.height : 1080) - 70, visibleRows * rowHeight + (visibleRows - 1) * 6 + padding * 2 + 86)

        z: 1
        width: Math.min(Config.ShellConfig.launcherWidth + frameInset * 2, parent.width - 24)
        height: naturalHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.opened ? root.height - height : root.height + 2
        visible: root.presented
        clip: true

        Behavior on y {
            enabled: Config.ShellConfig.animationsEnabled
            YAnimator {
                id: revealAnimation
                duration: root.opened ? 460 : 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.opened
                    ? [0.24, 0.12, 0.24, 1.08, 1, 1]
                    : [0.4, 0, 0.65, 1, 1, 1]
            }
        }

        Behavior on height {
            enabled: Config.ShellConfig.animationsEnabled && root.opened
            NumberAnimation {
                duration: 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 0, 0.28, 1, 1, 1]
            }
        }

        MouseArea { anchors.fill: parent }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                fillColor: Theme.Theme.surface
                strokeWidth: 0
                startX: sheet.frameInset + sheet.topRadius; startY: 0
                PathLine { x: sheet.width - sheet.frameInset - sheet.topRadius; y: 0 }
                PathCubic {
                    x: sheet.width - sheet.frameInset; y: sheet.topRadius
                    control1X: sheet.width - sheet.frameInset - sheet.topRadius * 0.448; control1Y: 0
                    control2X: sheet.width - sheet.frameInset; control2Y: sheet.topRadius * 0.448
                }
                PathLine { x: sheet.width - sheet.frameInset; y: sheet.height - sheet.frameInset }
                PathCubic {
                    x: sheet.width; y: sheet.height
                    control1X: sheet.width - sheet.frameInset; control1Y: sheet.height - sheet.frameInset * 0.448
                    control2X: sheet.width - sheet.frameInset * 0.448; control2Y: sheet.height
                }
                PathLine { x: 0; y: sheet.height }
                PathCubic {
                    x: sheet.frameInset; y: sheet.height - sheet.frameInset
                    control1X: sheet.frameInset * 0.448; control1Y: sheet.height
                    control2X: sheet.frameInset; control2Y: sheet.height - sheet.frameInset * 0.448
                }
                PathLine { x: sheet.frameInset; y: sheet.topRadius }
                PathCubic {
                    x: sheet.frameInset + sheet.topRadius; y: 0
                    control1X: sheet.frameInset; control1Y: sheet.topRadius * 0.448
                    control2X: sheet.frameInset + sheet.topRadius * 0.448; control2Y: 0
                }
            }
        }

        Rectangle {
            id: listSurface
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: Math.max(0, sheet.height - 86)
            anchors.leftMargin: sheet.frameInset
            anchors.rightMargin: sheet.frameInset
            color: "transparent"
            radius: Theme.Theme.radiusLarge

            ListView {
                id: resultList
                anchors.fill: parent
                anchors.margins: sheet.padding
                clip: true
                model: root.results
                currentIndex: root.selectedIndex
                spacing: 6
                reuseItems: true
                cacheBuffer: sheet.rowHeight * 2
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
                    visible: resultList.count > 0
                    y: resultList.currentItem ? resultList.currentItem.y : 0

                    Behavior on y {
                        enabled: Config.ShellConfig.animationsEnabled
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: resultDelegate
                    required property var modelData
                    required property int index

                    width: resultList.width
                    height: sheet.rowHeight
                    radius: Theme.Theme.radiusMedium
                    color: delegateMouse.containsMouse && index !== root.selectedIndex ? Theme.Theme.surfaceRaised : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: root.activate(modelData)

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
                                color: Theme.Theme.textSecondary
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
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.selectedIndex = index
                        onClicked: root.activate(modelData)
                    }
                }

            }

                Text {
                    anchors.centerIn: parent
                    width: resultList.width
                    visible: resultList.count === 0
                    text: root.message !== "" ? root.message : "No results"
                    color: root.message !== "" ? Theme.Theme.accent : Theme.Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    topPadding: 0
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
        }

        TextField {
            id: search
            height: 58
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 16 }
            anchors.leftMargin: sheet.frameInset + sheet.padding
            anchors.rightMargin: sheet.frameInset + sheet.padding
            placeholderText: "Search"
            color: Theme.Theme.textPrimary
            placeholderTextColor: Theme.Theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            Accessible.name: "Search applications and commands"
            leftPadding: 52
            rightPadding: clearButton.width + 26
            selectByMouse: true
            onTextChanged: {
                if (text !== "")
                    root.message = ""
                root.filterResults(text)
            }
            onAccepted: root.activate(root.results[root.selectedIndex])
            Keys.onEscapePressed: root.close()
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)

            background: Rectangle {
                color: Theme.Theme.surfaceRaised
                radius: Theme.Theme.radiusMedium
                border.width: 1
                border.color: Theme.Theme.surfaceHover
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
