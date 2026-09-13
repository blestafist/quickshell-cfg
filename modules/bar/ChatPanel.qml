import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../config" as Config
import "../../theme" as Theme

FocusScope {
    id: root

    required property var openCode
    property real maximumHeight: 760
    readonly property var session: openCode.activeSession()
    readonly property bool hasSession: session !== null
    signal closeRequested()

    implicitHeight: Math.min(maximumHeight, Config.ShellConfig.aiChatHeight)
    Keys.onEscapePressed: closeRequested()
    Keys.onPressed: event => {
        if (!(event.modifiers & Qt.ControlModifier) || event.key !== Qt.Key_Tab) return
        const sessions = root.openCode.sessions
        if (sessions.length < 2) return
        const current = sessions.findIndex(item => item.id === root.openCode.activeSessionId)
        const direction = event.modifiers & Qt.ShiftModifier ? -1 : 1
        root.openCode.setActiveSession(sessions[(current + direction + sessions.length) % sessions.length].id)
        event.accepted = true
    }
    onVisibleChanged: {
        if (!visible) return
        if (!hasSession && openCode.ready) openCode.createSession()
        Qt.callLater(() => composer.forceActiveFocus())
    }

    Connections {
        target: root.openCode
        function onReadyChanged() {
            if (root.visible && root.openCode.ready && !root.hasSession)
                root.openCode.createSession()
        }
        function onSessionChanged(sessionId) {
            if (sessionId !== root.openCode.activeSessionId) return
            Qt.callLater(() => {
                if (messageList.atYEnd || !messageList.moving)
                    messageList.positionViewAtEnd()
            })
        }
    }

    function messageText(message) {
        if (!message || !message.parts) return ""
        const text = []
        for (let index = 0; index < message.parts.length; index++) {
            const part = message.parts[index]
            if (part && part.type === "text" && part.text) text.push(part.text)
        }
        return text.join("\n")
    }

    function toolParts(message) {
        if (!message || !message.parts) return []
        const tools = []
        for (let index = 0; index < message.parts.length; index++) {
            const part = message.parts[index]
            if (part && part.type === "tool") tools.push(part)
        }
        return tools
    }

    function toolSummary(part) {
        const state = part.state || {}
        const input = state.input || {}
        return input.command || input.path || input.filePath || JSON.stringify(input)
    }

    function toolOutput(part) {
        const state = part.state || {}
        const metadata = state.metadata || {}
        return metadata.output || state.output || state.error || ""
    }

    function submit() {
        if (!root.hasSession || !composer.text.trim()) return
        if (root.openCode.sendMessage(root.session.id, composer.text)) {
            composer.text = ""
            Qt.callLater(() => messageList.positionViewAtEnd())
        }
    }

    component Label: Text {
        color: Theme.Theme.textPrimary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    component Action: Button {
        id: action
        implicitHeight: 34
        implicitWidth: Math.max(34, contentItem.implicitWidth + 22)
        background: Rectangle {
            radius: 10
            color: action.down || action.hovered ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised
            border.width: action.activeFocus ? 1 : 0
            border.color: Theme.Theme.accent
            Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 140 : 0 } }
        }
        contentItem: Label {
            text: action.text
            opacity: action.enabled ? 1 : 0.35
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 16
        anchors.bottomMargin: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44

                Rectangle {
                    id: aiCore
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    radius: 14
                    color: Theme.Theme.surfaceRaised
                    border.width: 1
                    border.color: root.openCode.ready ? Theme.Theme.accent : Theme.Theme.surfaceHover
                    Behavior on color { ColorAnimation { duration: 280 } }
                    SequentialAnimation on scale {
                        running: root.session && root.session.busy && Config.ShellConfig.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.82; duration: 520; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 5
                    rotation: 45
                    color: root.openCode.ready ? Theme.Theme.accent : Theme.Theme.textMuted
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.Theme.accentText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: root.hasSession ? root.session.title : "AI workspace"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Label {
                    Layout.fillWidth: true
                    text: root.openCode.ready ? (root.hasSession && root.session.busy ? "Working in " + root.session.directory : root.openCode.sessions.length + " open workspace" + (root.openCode.sessions.length === 1 ? "" : "s")) : root.openCode.status === "error" ? root.openCode.error : "Starting local OpenCode runtime..."
                    color: root.openCode.status === "error" ? Theme.Theme.danger : root.hasSession && root.session.busy ? Theme.Theme.accent : Theme.Theme.textMuted
                    font.pixelSize: 10
                }
            }
            Action {
                id: modelButton
                implicitWidth: Math.min(190, Math.max(108, contentItem.implicitWidth + 22))
                text: root.hasSession && root.session.model ? root.session.model.name : root.openCode.models.length ? "Choose model" : "Models..."
                enabled: root.hasSession && root.openCode.models.length > 0 && !root.session.busy
                onClicked: modelPopup.open()

                Popup {
                    id: modelPopup
                    parent: modelButton
                    x: modelButton.width - width
                    y: modelButton.height + 8
                    width: 320
                    height: Math.min(360, modelList.contentHeight + 16)
                    padding: 8
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle {
                        radius: 14
                        color: Theme.Theme.surfaceRaised
                        border.width: 1
                        border.color: Theme.Theme.surfaceHover
                    }
                    contentItem: ListView {
                        id: modelList
                        clip: true
                        spacing: 3
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.openCode.models
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Button {
                            id: modelOption
                            required property var modelData
                            width: modelList.width
                            height: 46
                            background: Rectangle {
                                radius: 10
                                color: modelOption.hovered || (root.hasSession && root.session.model && root.session.model.providerID === modelOption.modelData.providerID && root.session.model.modelID === modelOption.modelData.modelID) ? Theme.Theme.surfaceHover : "transparent"
                            }
                            contentItem: Column {
                                leftPadding: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Label { width: modelOption.width - 24; text: modelOption.modelData.name; font.pixelSize: 10 }
                                Label { width: modelOption.width - 24; text: modelOption.modelData.providerName + " · " + modelOption.modelData.modelID; color: Theme.Theme.textMuted; font.pixelSize: 8 }
                            }
                            onClicked: {
                                root.openCode.setSessionModel(root.session.id, modelData)
                                modelPopup.close()
                            }
                        }
                    }
                }
            }
            Action { text: "+"; Accessible.name: "New chat"; enabled: root.openCode.ready; onClicked: root.openCode.createSession() }
            Action { text: "×"; Accessible.name: "Close AI chat"; onClicked: root.closeRequested() }
        }

        ListView {
            id: tabList
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.openCode.sessions
            add: Transition {
                NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: Config.ShellConfig.animationsEnabled ? 240 : 0; easing.type: Easing.OutBack }
            }
            delegate: Button {
                id: tabButton
                required property var modelData
                width: Math.max(112, Math.min(190, tabLabel.implicitWidth + 62))
                height: 38
                background: Rectangle {
                    radius: 12
                    color: root.openCode.activeSessionId === tabButton.modelData.id ? Theme.Theme.surfaceRaised : tabButton.hovered ? Theme.Theme.surfaceHover : "transparent"
                    border.width: root.openCode.activeSessionId === tabButton.modelData.id ? 1 : 0
                    border.color: Theme.Theme.accent
                    Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 160 : 0 } }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 24
                        height: 2
                        radius: 1
                        color: Theme.Theme.accent
                        opacity: root.openCode.activeSessionId === tabButton.modelData.id ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                    }
                }
                contentItem: RowLayout {
                    spacing: 7
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 4
                        color: tabButton.modelData.unread ? Theme.Theme.danger : tabButton.modelData.busy ? Theme.Theme.accent : Theme.Theme.textMuted
                        opacity: tabButton.modelData.busy || tabButton.modelData.unread ? 1 : 0.45
                        SequentialAnimation on opacity {
                            running: tabButton.modelData.busy && Config.ShellConfig.animationsEnabled
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 460 }
                            NumberAnimation { to: 1; duration: 460 }
                        }
                    }
                    Label { id: tabLabel; Layout.fillWidth: true; text: tabButton.modelData.title; font.pixelSize: 10 }
                    Label {
                        text: "×"
                        color: closeTabMouse.containsMouse ? Theme.Theme.danger : Theme.Theme.textMuted
                        MouseArea { id: closeTabMouse; anchors.fill: parent; anchors.margins: -7; hoverEnabled: true; onClicked: root.openCode.closeSession(tabButton.modelData.id) }
                    }
                }
                onClicked: root.openCode.setActiveSession(modelData.id)
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.Theme.surfaceHover }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? errorLabel.implicitHeight + 18 : 0
            visible: root.openCode.error !== ""
            radius: 10
            color: Theme.Theme.surfaceRaised
            border.width: 1
            border.color: Theme.Theme.danger
            opacity: visible ? 1 : 0
            Label {
                id: errorLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                text: root.openCode.error
                color: Theme.Theme.danger
                wrapMode: Text.Wrap
                font.pixelSize: 9
            }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: modeRow.implicitWidth + 8
                Layout.preferredHeight: 36
                radius: 11
                color: Theme.Theme.surfaceRaised
                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: [{ key: "chat", label: "Chat" }, { key: "build", label: "Build" }]
                        Button {
                            id: modeButton
                            required property var modelData
                            width: 72
                            height: 30
                            enabled: root.hasSession
                            background: Rectangle {
                                radius: 9
                                color: root.hasSession && root.session.mode === modeButton.modelData.key ? Theme.Theme.accent : modeButton.hovered ? Theme.Theme.surfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                            }
                            contentItem: Label {
                                text: modeButton.modelData.label
                                color: root.hasSession && root.session.mode === modeButton.modelData.key ? Theme.Theme.accentText : Theme.Theme.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.openCode.setSessionMode(root.session.id, modelData.key)
                        }
                    }
                }
            }

            TextField {
                id: cwdField
                Layout.fillWidth: true
                Layout.preferredWidth: visible ? 420 : 0
                implicitHeight: 36
                visible: root.hasSession && root.session.mode === "build"
                enabled: visible && !root.session.busy
                opacity: visible ? 1 : 0
                text: root.hasSession ? root.session.directory : root.openCode.defaultDirectory
                placeholderText: "Build working directory"
                color: Theme.Theme.textPrimary
                placeholderTextColor: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                leftPadding: 12
                rightPadding: 12
                selectByMouse: true
                background: Rectangle {
                    radius: 10
                    color: Theme.Theme.surfaceRaised
                    border.width: cwdField.activeFocus ? 1 : 0
                    border.color: Theme.Theme.accent
                    opacity: cwdField.enabled ? 1 : 0.55
                }
                onAccepted: {
                    root.openCode.setSessionDirectory(root.session.id, text)
                    focus = false
                }
                onActiveFocusChanged: if (!activeFocus && root.hasSession && text !== root.session.directory) text = root.session.directory
                ToolTip.visible: hovered
                ToolTip.text: "Working directory for the next Build message"
                Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: messageList
                anchors.fill: parent
                clip: true
                spacing: 9
                boundsBehavior: Flickable.StopAtBounds
                model: root.hasSession ? root.session.messages : []
                ScrollBar.vertical: ScrollBar { policy: messageList.contentHeight > messageList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.ShellConfig.animationsEnabled ? 220 : 0 }
                        NumberAnimation { property: "y"; from: 18; duration: Config.ShellConfig.animationsEnabled ? 280 : 0; easing.type: Easing.OutCubic }
                    }
                }
                delegate: Item {
                    id: messageDelegate
                    required property var modelData
                    width: messageList.width
                    height: messageContent.height + 12
                    readonly property bool userMessage: modelData.role === "user"
                    readonly property string bodyText: root.messageText(modelData)
                    readonly property var tools: root.toolParts(modelData)

                    Rectangle {
                        id: messageContent
                        width: messageDelegate.userMessage ? parent.width * 0.76 : parent.width
                        height: messageColumn.height + 24
                        anchors.right: messageDelegate.userMessage ? parent.right : undefined
                        anchors.left: messageDelegate.userMessage ? undefined : parent.left
                        radius: 14
                        color: messageDelegate.userMessage ? Theme.Theme.surfaceRaised : "transparent"
                        border.width: 0

                        Column {
                            id: messageColumn
                            x: messageDelegate.userMessage ? 14 : 4
                            y: 11
                            width: parent.width - (messageDelegate.userMessage ? 28 : 8)
                            height: childrenRect.height
                            spacing: 6

                            Text {
                                width: parent.width
                                text: messageDelegate.userMessage ? "You" : (root.session && root.session.model ? root.session.model.name : "Assistant")
                                color: messageDelegate.userMessage ? Theme.Theme.textMuted : Theme.Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: messageDelegate.bodyText
                                color: Theme.Theme.textPrimary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                lineHeight: 1.35
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                height: Math.max(implicitHeight, text === "" ? 14 : 0)
                            }

                            Column {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: messageDelegate.tools
                                    Rectangle {
                                        id: toolCard
                                        required property var modelData
                                        width: messageColumn.width
                                        height: toolContent.height + 18
                                        radius: 11
                                        color: Theme.Theme.surfaceRaised
                                        border.width: 1
                                        border.color: modelData.state && modelData.state.status === "error" ? Theme.Theme.danger : modelData.state && modelData.state.status === "completed" ? Theme.Theme.textMuted : Theme.Theme.accent

                                        Column {
                                            id: toolContent
                                            x: 10
                                            y: 9
                                            width: parent.width - 20
                                            height: childrenRect.height
                                            spacing: 4
                                            Text { width: parent.width; text: "󰆍  " + toolCard.modelData.tool + "  ·  " + (toolCard.modelData.state ? toolCard.modelData.state.status : "pending"); color: Theme.Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.DemiBold }
                                            Text { width: parent.width; text: root.toolSummary(toolCard.modelData); color: Theme.Theme.textSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; wrapMode: Text.Wrap; maximumLineCount: 3 }
                                            Text { width: parent.width; visible: text !== ""; text: root.toolOutput(toolCard.modelData); color: Theme.Theme.textMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; wrapMode: Text.Wrap; maximumLineCount: 6 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: !root.hasSession || messageList.count === 0
                width: Math.min(460, parent.width - 48)
                spacing: 12

                Item {
                    width: parent.width
                    height: 72
                    Rectangle {
                        anchors.centerIn: parent
                        width: 62
                        height: 62
                        radius: 22
                        color: Theme.Theme.surfaceRaised
                        border.width: 1
                        border.color: Theme.Theme.surfaceHover
                        rotation: -8
                    }
                    Text { anchors.centerIn: parent; text: "󰚩"; color: Theme.Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 28 }
                }
                Text {
                    width: parent.width
                    text: !root.openCode.ready ? "Preparing your workspace" : root.hasSession && root.session.mode === "build" ? "Build with full context" : "What are we exploring?"
                    color: Theme.Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: !root.openCode.ready ? "The local OpenCode runtime will be ready in a moment." : root.hasSession && root.session.mode === "build" ? "Set a working directory above, then describe the result. The agent can use project tools while other tabs continue in parallel." : "Chat stays focused and tool-free. Switch to Build when you want an agent to work directly in a project."
                    color: Theme.Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    lineHeight: 1.35
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(82, composer.implicitHeight + 24)
            radius: 17
            color: Theme.Theme.surfaceRaised
            border.width: 1
            border.color: composer.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover
            Behavior on border.color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }

            TextArea {
                id: composer
                anchors.left: parent.left
                anchors.right: sendButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                enabled: root.hasSession && !root.session.busy
                placeholderText: root.hasSession && root.session.mode === "build" ? "Describe what to build in this directory..." : "Ask anything..."
                color: Theme.Theme.textPrimary
                placeholderTextColor: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                topPadding: 7
                bottomPadding: 7
                leftPadding: 0
                rightPadding: 0
                verticalAlignment: TextEdit.AlignTop
                background: Item {}
                Keys.onReturnPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier) {
                        insert(cursorPosition, "\n")
                    } else {
                        root.submit()
                    }
                    event.accepted = true
                }
            }

            Action {
                id: sendButton
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: 46
                text: root.hasSession && root.session.busy ? "■" : "↑"
                enabled: root.hasSession && (root.session.busy || composer.text.trim().length > 0)
                Accessible.name: root.hasSession && root.session.busy ? "Stop agent" : "Send message"
                onClicked: root.session.busy ? root.openCode.abort(root.session.id) : root.submit()
            }
        }
    }
}
