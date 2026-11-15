import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../config" as Config
import "../../theme" as Theme

FocusScope {
    id: root

    signal closeRequested()
    signal actionRequested(string action)

    implicitHeight: 82
    Keys.onEscapePressed: closeRequested()
    Keys.onPressed: event => {
        if (event.isAutoRepeat || event.modifiers !== Qt.NoModifier)
            return

        const shortcuts = {
            [Qt.Key_L]: "lock",
            [Qt.Key_S]: "shutdown",
            [Qt.Key_U]: "suspend",
            [Qt.Key_R]: "reboot",
            [Qt.Key_E]: "logout"
        }
        const action = shortcuts[event.key]
        if (action) {
            event.accepted = true
            actionRequested(action)
        }
    }

    readonly property var actions: [
        { name: "Lock", key: "L", action: "lock", icon: "../../assets/power/lock.png" },
        { name: "Shutdown", key: "S", action: "shutdown", icon: "../../assets/power/power.png" },
        { name: "Suspend", key: "U", action: "suspend", icon: "../../assets/power/sleep.png" },
        { name: "Reboot", key: "R", action: "reboot", icon: "../../assets/power/restart.png" },
        { name: "Logout", key: "E", action: "logout", icon: "../../assets/power/logout.png" }
    ]

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        Repeater {
            model: root.actions

            Button {
                id: actionButton
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 54
                activeFocusOnTab: true
                Accessible.name: modelData.name + " (" + modelData.key + ")"

                background: Rectangle {
                    radius: Theme.Theme.radiusMedium
                    color: actionButton.down ? Theme.Theme.accent : actionButton.hovered || actionButton.activeFocus ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised
                    border.width: actionButton.activeFocus ? 1 : 0
                    border.color: Theme.Theme.accent

                    Behavior on color {
                        enabled: Config.ShellConfig.animationsEnabled
                        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                contentItem: Item {
                    Image {
                        anchors.centerIn: parent
                        width: 25
                        height: 25
                        source: actionButton.modelData.icon
                        sourceSize.width: 50
                        sourceSize.height: 50
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        scale: actionButton.down ? 0.82 : actionButton.hovered || actionButton.activeFocus ? 1.12 : 1
                        opacity: actionButton.enabled ? 1 : 0.45

                        Behavior on scale {
                            enabled: Config.ShellConfig.animationsEnabled
                            NumberAnimation { duration: actionButton.down ? 90 : 240; easing.type: actionButton.down ? Easing.OutCubic : Easing.OutBack }
                        }
                    }
                }

                ToolTip.visible: hovered
                ToolTip.text: modelData.name + " (" + modelData.key + ")"
                ToolTip.delay: 500
                onClicked: root.actionRequested(modelData.action)

                Component.onCompleted: if (index === 0) forceActiveFocus()
            }
        }
    }
}
