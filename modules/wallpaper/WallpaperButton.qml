import QtQuick
import QtQuick.Controls

import "../../config" as Config
import "../../theme" as Theme

Button {
    id: root

    property string iconName: ""
    property string label: ""
    property string hint: label
    property bool primary: false
    property int labelSize: 14

    implicitWidth: label ? labelText.implicitWidth + 48 : 40
    implicitHeight: 40
    padding: 0
    activeFocusOnTab: true
    Accessible.name: hint

    background: Rectangle {
        radius: height / 2
        color: root.primary ? Theme.Theme.accent : Theme.Theme.surfaceRaised
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.Theme.accent
        opacity: root.enabled ? 1 : 0.45
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.primary ? Theme.Theme.accentText : Theme.Theme.textPrimary
            opacity: !root.enabled ? 0 : root.down || root.activeFocus ? 0.12 : root.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 100 : 0 } }
        }
    }
    contentItem: Item {
        opacity: root.enabled ? 1 : 0.45
        MaterialIcon {
            anchors.centerIn: parent
            visible: root.iconName !== ""
            name: root.iconName
            color: root.primary ? Theme.Theme.accentText : Theme.Theme.textPrimary
        }
        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.label
            color: root.primary ? Theme.Theme.accentText : Theme.Theme.textPrimary
            font.family: "Noto Sans"
            font.pixelSize: root.labelSize
            font.weight: Font.Medium
            font.letterSpacing: 0.1
        }
    }
    ToolTip.visible: hovered && hint !== ""
    ToolTip.text: hint
    ToolTip.delay: 650
}
