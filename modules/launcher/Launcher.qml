import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "../../components" as Components
import "../../config" as Config
import "../../theme" as Theme

PanelWindow {
    id: root

    property bool opened: false
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
    visible: opened && targetScreen !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    focusable: true

    function open() {
        message = ""
        opened = true
        search.text = ""
        filterResults("")
        search.forceActiveFocus()
    }

    function close() { opened = false }
    function toggle() { opened ? close() : open() }
    function showMessage(text) { message = text; open() }

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
        commandRunner.running = true
        close()
    }

    Process { id: commandRunner }

    Rectangle {
        anchors.fill: parent
        color: Theme.Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Components.Surface {
        id: sheet
        width: Math.min(Config.ShellConfig.launcherWidth, parent.width - 48)
        height: Math.min(Config.ShellConfig.launcherHeight, parent.height - 48)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.ShellConfig.launcherBottomMargin
        surfaceRadius: Theme.Theme.radiusLarge
        border.width: 1
        border.color: Theme.Theme.surfaceHover

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            TextField {
                id: search
                width: parent.width
                height: 54
                placeholderText: "Search applications and commands"
                color: Theme.Theme.textPrimary
                placeholderTextColor: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                leftPadding: 48
                rightPadding: 16
                selectByMouse: true
                onTextChanged: root.filterResults(text)
                onAccepted: root.activate(root.results[root.selectedIndex])
                Keys.onEscapePressed: root.close()
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                background: Rectangle { color: Theme.Theme.surfaceRaised; radius: Theme.Theme.radiusMedium }

                Text { anchors.left: parent.left; anchors.leftMargin: 17; anchors.verticalCenter: parent.verticalCenter; text: ""; color: Theme.Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
            }

            Text {
                visible: root.message !== ""
                width: parent.width
                text: root.message
                color: Theme.Theme.accent
                font.pixelSize: 13
            }

            Row {
                width: parent.width
                Text { id: resultCount; text: root.results.length + " results"; color: Theme.Theme.textMuted; font.pixelSize: 12 }
                Item { width: parent.width - resultCount.width - shortcutHelp.width; height: 1 }
                Text { id: shortcutHelp; text: "Up/Down navigate  Enter open  Esc close"; color: Theme.Theme.textMuted; font.pixelSize: 12 }
            }

            ListView {
                id: resultList
                width: parent.width
                height: parent.height - search.height - 28 - (root.message !== "" ? 26 : 0)
                clip: true
                model: root.results
                spacing: 4
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: resultList.width
                    height: 62
                    radius: Theme.Theme.radiusSmall
                    color: index === root.selectedIndex ? Theme.Theme.surfaceHover : delegateMouse.containsMouse ? Theme.Theme.surfaceRaised : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14
                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: modelData.kind === "command" ? Theme.Theme.surfaceRaised : Theme.Theme.background
                            anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: modelData.kind === "command" ? modelData.icon : "󰏗"; color: Theme.Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
                        }
                        Column {
                            width: parent.width - 110
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text { width: parent.width; text: modelData.name; color: Theme.Theme.textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.description; color: Theme.Theme.textMuted; font.pixelSize: 12; elide: Text.ElideRight }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.kind === "command" ? "command" : "application"; color: Theme.Theme.textMuted; font.pixelSize: 11 }
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
                    visible: resultList.count === 0
                    text: "No matching application or command"
                    color: Theme.Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 32
                }
            }
        }
    }

    onApplicationsChanged: filterResults(search.text)
}
