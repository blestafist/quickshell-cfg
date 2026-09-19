import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../config" as Config
import "../../theme" as Theme

FocusScope {
    id: root

    required property var openCode
    property real maximumHeight: 900
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
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    component Action: Button {
        id: action
        implicitHeight: 40
        implicitWidth: Math.max(40, contentItem.implicitWidth + 24)
        background: Rectangle {
            radius: 12
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
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 20
        anchors.bottomMargin: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                Rectangle {
                    id: aiCore
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: 16
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
                    width: 16
                    height: 16
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
                spacing: 4
                Label { text: "Agent workspace"; font.pixelSize: 19; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Label {
                    Layout.fillWidth: true
                    text: root.openCode.ready ? (root.hasSession && root.session.busy ? "Working · " + root.session.title : root.openCode.sessions.length + " open chat" + (root.openCode.sessions.length === 1 ? "" : "s")) : root.openCode.status === "error" ? root.openCode.error : "Starting local runtime..."
                    color: root.openCode.status === "error" ? Theme.Theme.danger : root.hasSession && root.session.busy ? Theme.Theme.accent : Theme.Theme.textMuted
                    font.pixelSize: 12
                }
            }
            Action { text: "+"; font.pixelSize: 16; Accessible.name: "New chat"; enabled: root.openCode.ready; onClicked: root.openCode.createSession() }
            Action { text: "×"; font.pixelSize: 16; Accessible.name: "Close AI chat"; onClicked: root.closeRequested() }
        }

        ListView {
            id: tabList
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.openCode.sessions
            add: Transition {
                NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: Config.ShellConfig.animationsEnabled ? 240 : 0; easing.type: Easing.OutBack }
            }
            delegate: Button {
                id: tabButton
                required property var modelData
                width: Math.max(104, Math.min(184, tabLabel.implicitWidth + 54))
                height: 42
                background: Rectangle {
                    radius: 9
                    color: root.openCode.activeSessionId === tabButton.modelData.id ? Theme.Theme.surfaceHover : tabButton.hovered ? Theme.Theme.surfaceRaised : "transparent"
                    Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 160 : 0 } }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        width: root.openCode.activeSessionId === tabButton.modelData.id ? parent.width - 24 : 0
                        height: 2
                        radius: 1
                        color: Theme.Theme.accent
                        Behavior on width { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic } }
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
                    Label { id: tabLabel; Layout.fillWidth: true; text: tabButton.modelData.title; font.pixelSize: 12 }
                    Label {
                        text: "×"
                        color: closeTabMouse.containsMouse ? Theme.Theme.danger : Theme.Theme.textMuted
                        MouseArea { id: closeTabMouse; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; onClicked: mouse => { root.openCode.closeSession(tabButton.modelData.id); mouse.accepted = true } }
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
                font.pixelSize: 12
            }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: modeRow.implicitWidth + 8
                Layout.preferredHeight: 44
                radius: 13
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
                            width: 82
                            height: 36
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
                implicitHeight: 44
                visible: root.hasSession && root.session.mode === "build"
                enabled: visible && !root.session.busy
                opacity: visible ? 1 : 0
                text: root.hasSession ? root.session.directory : root.openCode.defaultDirectory
                placeholderText: "Build working directory"
                color: Theme.Theme.textPrimary
                placeholderTextColor: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
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
                        radius: 16
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
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: messageDelegate.bodyText
                                color: Theme.Theme.textPrimary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                lineHeight: 1.45
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
                                            Text { width: parent.width; text: "󰆍  " + toolCard.modelData.tool + "  ·  " + (toolCard.modelData.state ? toolCard.modelData.state.status : "pending"); color: Theme.Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                            Text { width: parent.width; text: root.toolSummary(toolCard.modelData); color: Theme.Theme.textSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 3 }
                                            Text { width: parent.width; visible: text !== ""; text: root.toolOutput(toolCard.modelData); color: Theme.Theme.textMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 6 }
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
                spacing: 16

                Item {
                    width: parent.width
                    height: 82
                    Rectangle {
                        anchors.centerIn: parent
                        width: 68
                        height: 68
                        radius: 24
                        color: Theme.Theme.surfaceRaised
                        border.width: 1
                        border.color: Theme.Theme.surfaceHover
                        rotation: -8
                    }
                    Text { anchors.centerIn: parent; text: "󰚩"; color: Theme.Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 30 }
                }
                Text {
                    width: parent.width
                    text: !root.openCode.ready ? "Preparing your workspace" : root.hasSession && root.session.mode === "build" ? "Build with full context" : "What are we exploring?"
                    color: Theme.Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: !root.openCode.ready ? "The local OpenCode runtime will be ready in a moment." : root.hasSession && root.session.mode === "build" ? "Set a working directory above, then describe the result. The agent can use project tools while other tabs continue in parallel." : "Chat stays focused and tool-free. Switch to Build when you want an agent to work directly in a project."
                    color: Theme.Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    lineHeight: 1.45
                }
            }
        }

        Rectangle {
            id: composerFrame
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(126, composer.implicitHeight + composerToolbar.height + 34)
            radius: 18
            color: Theme.Theme.surfaceRaised
            border.width: 1
            border.color: composer.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover
            Behavior on border.color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }

            TextArea {
                id: composer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: composerToolbar.top
                anchors.margins: 10
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 4
                enabled: root.hasSession && !root.session.busy
                placeholderText: root.hasSession && root.session.mode === "build" ? "Describe what to build in this directory..." : "Ask anything..."
                color: Theme.Theme.textPrimary
                placeholderTextColor: Theme.Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
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

            RowLayout {
                id: composerToolbar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.bottomMargin: 10
                height: 42
                spacing: 8

                Action {
                    id: modelButton
                    Layout.maximumWidth: 280
                    implicitWidth: Math.min(280, Math.max(148, contentItem.implicitWidth + 28))
                    text: root.hasSession && root.session.model ? root.session.model.name + " ⌄" : root.openCode.models.length ? "Choose model ⌄" : "Loading models..."
                    enabled: root.hasSession && root.openCode.models.length > 0 && !root.session.busy
                    onClicked: modelPopup.opened ? modelPopup.close() : modelPopup.open()
                    Accessible.name: "Choose AI model"

                    Popup {
                        id: modelPopup
                        parent: modelButton
                        x: 0
                        y: -height - 10
                        width: Math.min(420, composerFrame.width - 20)
                        height: Math.min(460, modelList.contentHeight + 20)
                        padding: 10
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        transformOrigin: Popup.BottomLeft
                        enter: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.ShellConfig.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Config.ShellConfig.animationsEnabled ? 240 : 0; easing.type: Easing.OutBack }
                            }
                        }
                        exit: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Config.ShellConfig.animationsEnabled ? 120 : 0; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; from: 1; to: 0.98; duration: Config.ShellConfig.animationsEnabled ? 140 : 0; easing.type: Easing.OutCubic }
                            }
                        }
                        background: Rectangle {
                            radius: 16
                            color: Theme.Theme.surfaceRaised
                            border.width: 1
                            border.color: Theme.Theme.surfaceHover
                        }
                        contentItem: ListView {
                            id: modelList
                            clip: true
                            spacing: 4
                            boundsBehavior: Flickable.StopAtBounds
                            flickDeceleration: 1800
                            maximumFlickVelocity: 1800
                            model: root.openCode.models
                            ScrollBar.vertical: ScrollBar { policy: modelList.contentHeight > modelList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                            delegate: Button {
                                id: modelOption
                                required property var modelData
                                width: modelList.width
                                height: 60
                                readonly property bool selected: root.hasSession && root.session.model && root.session.model.providerID === modelData.providerID && root.session.model.modelID === modelData.modelID
                                background: Rectangle {
                                    radius: 11
                                    color: modelOption.hovered || modelOption.activeFocus ? Theme.Theme.surfaceHover : modelOption.selected ? Theme.Theme.surface : "transparent"
                                    border.width: modelOption.selected ? 1 : 0
                                    border.color: Theme.Theme.accent
                                    Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 140 : 0 } }
                                }
                                contentItem: RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        Layout.leftMargin: 10
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelOption.selected ? Theme.Theme.accent : Theme.Theme.textMuted
                                        opacity: modelOption.selected ? 1 : 0.35
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Label { Layout.fillWidth: true; text: modelOption.modelData.name; font.pixelSize: 13; font.weight: Font.DemiBold }
                                        Label { Layout.fillWidth: true; text: modelOption.modelData.modelID; color: Theme.Theme.textMuted; font.pixelSize: 11 }
                                    }
                                    Label { text: modelOption.selected ? "✓" : ""; color: Theme.Theme.accent; font.pixelSize: 15; Layout.rightMargin: 10 }
                                }
                                onClicked: {
                                    root.openCode.setSessionModel(root.session.id, modelData)
                                    modelPopup.close()
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Action {
                    id: sendButton
                    implicitWidth: 48
                    implicitHeight: 42
                    text: root.hasSession && root.session.busy ? "■" : "↑"
                    font.pixelSize: 17
                    enabled: root.hasSession && (root.session.busy || composer.text.trim().length > 0)
                    Accessible.name: root.hasSession && root.session.busy ? "Stop agent" : "Send message"
                    onClicked: root.session.busy ? root.openCode.abort(root.session.id) : root.submit()
                }
            }
        }
    }
}
