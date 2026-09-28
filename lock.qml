import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "lockscreen"
import "lockscreen/config" as Config

ShellRoot {
    id: root

    property bool releasing: false
    property bool suspendPending: false
    property string suspendResult: "idle"

    Component.onCompleted: Quickshell.watchFiles = false

    function finishUnlock() {
        if (!authState.succeeded || !sessionLock.secure || suspendPending)
            return
        releasing = true
        releaseAnimation.restart()
    }

    LockContext {
        id: authState
        permitted: sessionLock.secure && !root.releasing && !root.suspendPending
        onAuthenticated: root.finishUnlock()
    }

    Timer {
        id: releaseAnimation
        interval: Config.LockConfig.animationsEnabled ? 240 : 0
        onTriggered: {
            // Stay alive: Qt's Wayland event loop must deliver unlock_and_destroy.
            if (authState.succeeded && sessionLock.secure && !root.suspendPending)
                sessionLock.locked = false
            root.releasing = false
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true
        onSecureStateChanged: {
            if (!secure)
                authState.reset()
        }
        LockSurface {
            auth: authState
            secured: sessionLock.secure
            departing: root.releasing
        }
    }

    Process {
        id: suspendProcess
        command: ["systemctl", "suspend"]
        onRunningChanged: {
            if (!running && root.suspendPending) {
                root.suspendResult = "failed"
                root.suspendPending = false
            }
        }
        onExited: (code, status) => {
            root.suspendResult = code === 0 && status === 0 ? "done" : "failed"
            root.suspendPending = false
            root.finishUnlock()
        }
    }

    IpcHandler {
        target: "locker"
        function status(): string {
            if (root.releasing || authState.succeeded) return "unlocking"
            if (root.suspendPending) return "suspending"
            return sessionLock.secure && sessionLock.locked ? "secure" : sessionLock.locked ? "acquiring" : "idle"
        }
        function lock(): bool {
            if (root.releasing || authState.succeeded || root.suspendPending) return false
            if (!sessionLock.locked) {
                authState.reset()
                sessionLock.locked = true
            }
            return true
        }
        function suspend(): bool {
            // Recheck in the owning event loop, not just in the caller: no ack/unlock TOCTOU.
            if (!sessionLock.secure || !sessionLock.locked || root.releasing
                    || authState.succeeded || root.suspendPending) return false
            root.suspendPending = true
            root.suspendResult = "pending"
            authState.reset()
            suspendProcess.running = true
            return true
        }
        function suspendStatus(): string { return root.suspendResult }
    }
}
