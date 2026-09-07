import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme" as Theme
import "../../config" as Config

FocusScope {
    id: root
    required property var wifi
    property var selected: null
    property real maximumHeight: 700
    signal closeRequested()
    implicitHeight: content.implicitHeight + 40
    Keys.onEscapePressed: { selected = null; closeRequested() }
    onVisibleChanged: if (!visible) { selected = null; password.text = "" }
    Connections {
        target: root.wifi
        function onConnected() { root.selected = null; password.text = "" }
        function onEnabledChanged() { if (!root.wifi.enabled) root.selected = null }
    }

    component Label: Text {
        color: Theme.Theme.textPrimary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    component Action: Button {
        id: button
        implicitHeight: 32
        implicitWidth: Math.max(32, contentItem.implicitWidth + 24)
        background: Rectangle {
            radius: 9
            color: button.down ? Theme.Theme.surfaceHover : button.hovered ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised
            border.width: button.activeFocus ? 1 : 0
            border.color: Theme.Theme.accent
        }
        contentItem: Label { text: button.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: button.enabled ? 1 : 0.4 }
    }

    ColumnLayout {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 12
        RowLayout {
            spacing: 8
            ColumnLayout {
                spacing: 3
                Label { text: "Wi-Fi"; font.pixelSize: 20; font.weight: Font.DemiBold }
                Label { text: root.wifi.enabled ? "Wireless networks" : "Wireless is turned off"; color: Theme.Theme.textMuted }
            }
            Item { Layout.fillWidth: true }
            Action { text: root.wifi.scanning ? "Scanning..." : "Rescan"; enabled: root.wifi.enabled && !root.wifi.scanning && !root.wifi.busy; onClicked: root.wifi.refresh(true) }
            Action { text: root.wifi.enabled ? "On" : "Off"; enabled: !root.wifi.busy; onClicked: root.wifi.run(["radio", "wifi", root.wifi.enabled ? "off" : "on"], "Updating Wi-Fi...") }
            Action { text: "×"; Accessible.name: "Close Wi-Fi"; onClicked: root.closeRequested() }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.Theme.surfaceHover }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(80, Math.min(274, root.maximumHeight - 114 - (root.selected ? credentials.implicitHeight + 12 : 0) - (feedback.visible ? feedback.implicitHeight + 12 : 0)))
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800
            maximumFlickVelocity: 1800
            property real scrollTarget: 0
            property real preservedY: 0
            onContentYChanged: if (!scrollAnimation.running) preservedY = contentY
            onModelChanged: {
                const position = preservedY
                scrollAnimation.stop()
                Qt.callLater(() => {
                    contentY = Math.max(0, Math.min(position, contentHeight - height))
                    scrollTarget = contentY
                })
            }
            onMovementStarted: scrollAnimation.stop()
            NumberAnimation {
                id: scrollAnimation
                target: list
                property: "contentY"
                duration: Config.ShellConfig.animationsEnabled ? 180 : 0
                easing.type: Easing.OutCubic
                onStopped: list.preservedY = list.contentY
            }
            MouseArea {
                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * 58
                    if (!delta) { wheel.accepted = false; return }
                    const start = scrollAnimation.running ? list.scrollTarget : list.contentY
                    list.scrollTarget = Math.max(0, Math.min(start - delta, list.contentHeight - list.height))
                    scrollAnimation.stop()
                    scrollAnimation.from = list.contentY
                    scrollAnimation.to = list.scrollTarget
                    scrollAnimation.start()
                    wheel.accepted = true
                }
            }
            model: root.wifi.enabled ? root.wifi.networks : []
            ScrollBar.vertical: ScrollBar { }
            delegate: Button {
                id: networkButton
                required property var modelData
                width: list.width
                height: 54
                enabled: !root.wifi.busy && !root.wifi.loadingProfiles
                readonly property bool saved: root.wifi.savedProfile(modelData) !== null
                background: Rectangle {
                    radius: 10
                    color: networkButton.hovered || networkButton.activeFocus ? Theme.Theme.surfaceHover : networkButton.modelData.active ? Theme.Theme.surfaceRaised : "transparent"
                    border.width: root.selected && root.selected.bssid === networkButton.modelData.bssid ? 1 : 0
                    border.color: Theme.Theme.accent
                }
                contentItem: RowLayout {
                    spacing: 12
                    Label { text: "󰤨"; font.pixelSize: 20; color: networkButton.modelData.active ? Theme.Theme.accent : Theme.Theme.textMuted; Layout.leftMargin: 8 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Label { text: networkButton.modelData.ssid; Layout.fillWidth: true }
                        Label { text: networkButton.modelData.active ? "Connected" : (networkButton.saved ? "Saved · " : "") + (networkButton.modelData.security || "Open network"); color: networkButton.modelData.active ? Theme.Theme.accent : Theme.Theme.textMuted; font.pixelSize: 10 }
                    }
                    Label { text: networkButton.modelData.signal + "%"; color: Theme.Theme.textMuted }
                    Label { text: networkButton.modelData.active ? "Disconnect" : "Connect"; color: Theme.Theme.textSecondary; Layout.rightMargin: 8 }
                }
                onClicked: {
                    root.wifi.error = ""
                    password.text = ""
                    if (modelData.active) {
                        root.selected = null
                        root.wifi.run(["device", "disconnect", modelData.device], "Disconnecting...")
                    } else if (saved || !modelData.security || /802\.1X|EAP/.test(modelData.security)) {
                        root.selected = null
                        root.wifi.connect(modelData, "")
                    } else { root.selected = modelData; Qt.callLater(() => password.forceActiveFocus()) }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                text: !root.wifi.enabled ? "Turn on Wi-Fi to discover networks" : root.wifi.scanning ? "Looking for nearby networks..." : "No visible networks. Try scanning again."
                color: Theme.Theme.textMuted
            }
        }
        ColumnLayout {
            id: credentials
            visible: root.selected !== null
            Layout.fillWidth: true
            spacing: 8
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 220 : 0 } }
            Label { text: root.selected ? "Password · " + root.selected.ssid : ""; Layout.fillWidth: true }
            RowLayout {
                TextField {
                    id: password
                    Layout.fillWidth: true
                    implicitHeight: 36
                    enabled: !root.wifi.busy
                    echoMode: TextInput.Password
                    placeholderText: "Network password"
                    color: Theme.Theme.textPrimary
                    placeholderTextColor: Theme.Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    background: Rectangle { radius: 9; color: Theme.Theme.surfaceRaised; border.width: 1; border.color: password.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover }
                    onAccepted: connectButton.clicked()
                }
                Action {
                    id: connectButton
                    text: "Join"
                    enabled: !root.wifi.busy && password.text.length > 0
                    onClicked: {
                        if (!root.selected || root.wifi.busy || !password.text.length) return
                        root.wifi.connect(root.selected, password.text)
                        password.text = ""
                    }
                }
                Action { text: "Cancel"; onClicked: { root.selected = null; password.text = "" } }
            }
        }
        Label {
            id: feedback
            Layout.fillWidth: true
            visible: text !== ""
            text: root.wifi.error || root.wifi.message
            color: root.wifi.error ? Theme.Theme.danger : Theme.Theme.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font.pixelSize: 11
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 200 : 0 } }
        }
    }
}
