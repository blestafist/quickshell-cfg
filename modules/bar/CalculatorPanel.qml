import QtQuick
import QtQuick.Controls
import Quickshell

import "../../config" as Config
import "../../theme" as Theme
import "../../services/Calculator.js" as Calculator

FocusScope {
    id: root

    property var result: Calculator.evaluate(expression.text)
    property bool copied: false
    signal closeRequested()

    implicitHeight: 156
    Keys.onEscapePressed: closeRequested()

    function activate() {
        if (!enabled) return
        expression.forceActiveFocus()
        expression.selectAll()
    }

    function copyResult() {
        if (!result.ok) return
        Quickshell.clipboardText = result.text
        copied = true
        copiedTimer.restart()
    }

    Timer { id: copiedTimer; interval: 700; onTriggered: root.copied = false }

    TextField {
        id: expression
        y: 22
        width: parent.width
        height: 50
        leftPadding: 12
        rightPadding: 12
        maximumLength: 2048
        color: Theme.Theme.textPrimary
        selectionColor: Theme.Theme.accent
        selectedTextColor: Theme.Theme.accentText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
        selectByMouse: true
        Accessible.name: "Calculator expression"
        background: Rectangle {
            radius: 10
            color: Theme.Theme.surface
            border.width: 1
            border.color: expression.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover
        }
        onTextChanged: root.copied = false
        onAccepted: root.copyResult()
    }

    Text {
        y: 84
        width: parent.width
        height: 50
        text: root.result.ok ? "= " + root.result.text : expression.text.trim() ? root.result.error : "= 0"
        color: root.copied ? Theme.Theme.textPrimary : root.result.ok ? Theme.Theme.accent : Theme.Theme.textMuted
        Behavior on color {
            ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 }
        }
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.result.ok || !expression.text.trim() ? 32 : 14
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
