import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config
import "../../theme" as Theme

FocusScope {
    id: card
    required property var auth
    implicitWidth: 420
    // Reserve prompt space so a multi-step PAM conversation never shifts the form.
    implicitHeight: 324

    Column {
        id: content
        width: parent.width
        spacing: 16

        Text {
            width: parent.width
            text: "Welcome back,"
            color: Theme.Theme.textSecondary
            font.family: "Product Sans"
            font.pixelSize: 24
        }
        Text {
            width: parent.width
            text: Quickshell.env("USER") || "user"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.Theme.textPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 32
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            height: 48
            text: card.auth.statusMessage
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: card.auth.failed ? Theme.Theme.danger : Theme.Theme.textSecondary
            font.family: "Product Sans"
            font.pixelSize: 16
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        TextField {
            id: response
            objectName: "responseInput"
            width: parent.width
            height: 56
            opacity: card.auth.waiting ? 1 : 0
            enabled: card.auth.canRespond
            echoMode: card.auth.responseVisible ? TextInput.Normal : TextInput.Password
            passwordMaskDelay: 0
            maximumLength: Config.LockConfig.maxSecretLength
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            placeholderText: card.auth.responseVisible ? "Response" : "Secret response"
            Accessible.name: card.auth.prompt
            color: Theme.Theme.textPrimary
            placeholderTextColor: Theme.Theme.textMuted
            selectionColor: Theme.Theme.accent
            selectedTextColor: Theme.Theme.accentText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            leftPadding: 18
            rightPadding: 18
            background: Rectangle {
                radius: 18
                color: Theme.Theme.background
                border.width: 1
                border.color: response.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover
                Behavior on border.color { ColorAnimation { duration: 160 } }
            }
            onAccepted: card.auth.respond(text)
            Behavior on opacity { NumberAnimation { duration: Config.LockConfig.animationsEnabled ? 140 : 0 } }
            Keys.onEscapePressed: { clear(); card.auth.reset() }
        }

        Button {
            id: submit
            width: parent.width
            height: 48
            enabled: card.auth.canBegin || (card.auth.canRespond && response.text.length > 0)
            text: card.auth.waiting ? "Continue" : card.auth.active ? "Authenticating..." : card.auth.coolingDown ? "Please wait..." : "Continue"
            Accessible.name: text
            onClicked: card.auth.waiting ? card.auth.respond(response.text) : card.auth.begin()
            contentItem: Text {
                text: submit.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: submit.enabled ? Theme.Theme.accentText : Theme.Theme.textSecondary
                font.family: "Product Sans"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            background: Rectangle {
                radius: 24
                color: submit.enabled ? Theme.Theme.accent : Theme.Theme.surfaceRaised
                border.width: submit.activeFocus ? 2 : 0
                border.color: Theme.Theme.textPrimary
                opacity: submit.down ? 0.75 : submit.hovered ? 0.9 : 1
                // Keep foreground/background contrast stable when availability changes.
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }
        Text {
            width: parent.width
            text: card.auth.waiting ? "Enter to continue  /  Esc to cancel" : "Your session stays here."
            color: Theme.Theme.textMuted
            font.family: "Product Sans"
            font.pixelSize: 14
        }
    }

    Connections {
        target: card.auth
        function onClearInput() { response.clear() }
        function onWaitingChanged() {
            if (card.auth.waiting) response.forceActiveFocus()
            else submit.forceActiveFocus()
        }
    }
    Component.onCompleted: submit.forceActiveFocus()
}
