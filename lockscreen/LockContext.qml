import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "config" as Config

Scope {
    id: root
    signal authenticated()
    signal clearInput()

    property bool permitted: false
    property bool succeeded: false
    property bool waiting: false
    property bool responseVisible: false
    property bool failed: false
    property bool coolingDown: false
    property string statusMessage: "Press Continue to sign in"
    property string prompt: "Authentication"
    readonly property bool active: pam.active
    readonly property bool canBegin: permitted && !active && !coolingDown && !succeeded
    readonly property bool canRespond: permitted && active && waiting && !succeeded

    function begin() {
        if (!canBegin) return
        failed = false
        statusMessage = "Waiting for authentication service..."
        if (!pam.start()) failure("Authentication service unavailable")
    }

    function respond(value) {
        if (!canRespond || value.length === 0) return
        waiting = false
        clearInput()
        statusMessage = "Checking response..."
        pam.respond(value)
    }

    function reset() {
        pam.abort()
        retryTimer.stop()
        waiting = false
        succeeded = false
        failed = false
        coolingDown = false
        statusMessage = "Press Continue to sign in"
        clearInput()
    }

    function failure(message) {
        waiting = false
        failed = true
        coolingDown = true
        statusMessage = message
        clearInput()
        retryTimer.restart()
    }

    PamContext {
        id: pam
        config: Config.LockConfig.pamService
        // Empty user uses getpwuid(getuid()), not a mutable USER environment variable.
        onPamMessage: {
            root.clearInput()
            root.waiting = responseRequired
            root.responseVisible = responseVisible
            if (responseRequired) root.prompt = message || "Response"
            root.statusMessage = message || "Authenticating..."
        }
        onCompleted: result => {
            root.waiting = false
            root.clearInput()
            if (result === PamResult.Success && root.permitted) {
                root.succeeded = true
                root.statusMessage = "Welcome back"
                root.authenticated()
            } else {
                root.failure(result === PamResult.Error ? "Authentication service unavailable" : "Authentication failed. Try again.")
            }
        }
    }

    Timer {
        id: retryTimer
        interval: Config.LockConfig.retryDelayMs
        onTriggered: root.coolingDown = false
    }
}
