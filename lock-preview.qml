import QtQuick
import QtQuick.Window
import Quickshell
import "lockscreen" as Locker
import "lockscreen/preview"

ShellRoot {
    MockAuth { id: mockAuth }
    Window {
        visible: true
        width: 1200
        height: 800
        minimumWidth: 320
        minimumHeight: 460
        title: "Lockscreen preview - NOT LOCKED"
        onClosing: Qt.quit()
        Locker.LockView {
            anchors.fill: parent
            auth: mockAuth
            preview: true
        }
    }
}
