import QtQuick
import QtQuick.Window
import Quickshell
import "lockscreen"
import "lockscreen/preview"

ShellRoot {
    Component.onCompleted: {
        // Compile only. Never create the real root or its WlSessionLock.
        const component = Qt.createComponent("lock.qml")
        if (component.status !== Component.Ready)
            throw new Error(component.errorString())
    }
    MockAuth { id: mock }
    Window {
        id: window
        visible: true
        width: 1200
        height: 800
        LockView { id: view; anchors.fill: parent; auth: mock; preview: true }
    }
    Timer {
        property int step: 0
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (step === 0) {
                if (!view.landscape) throw new Error("Landscape layout not selected")
                if (Quickshell.env("LOCK_PREVIEW_CAPTURE")) {
                    view.grabToImage(result => {
                        result.saveToFile(Quickshell.env("LOCK_PREVIEW_CAPTURE") + "/lock-landscape.png")
                        window.width = 480
                        window.height = 900
                    })
                } else {
                    window.width = 480
                    window.height = 900
                }
                mock.begin()
                mock.respond("sample")
                if (!mock.waiting || !mock.responseVisible) throw new Error("Second prompt lost")
            } else if (step === 1) {
                if (view.landscape) throw new Error("Portrait layout not selected")
                if (Quickshell.env("LOCK_PREVIEW_CAPTURE")) {
                    view.grabToImage(result => {
                        result.saveToFile(Quickshell.env("LOCK_PREVIEW_CAPTURE") + "/lock-portrait.png")
                        window.width = 320
                        window.height = 460
                    })
                } else {
                    window.width = 320
                    window.height = 460
                }
                mock.respond("sample-code")
                if (!mock.failed) throw new Error("Failure state lost")
            } else {
                mock.reset()
                console.log("LOCK_PREVIEW_TEST_PASS")
                Qt.quit()
            }
            step++
        }
    }
}
