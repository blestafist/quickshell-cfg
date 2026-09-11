import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool opened: false
    property alias backend: proton
    property alias autoConnect: saved.autoConnect
    property alias savedTargetType: saved.targetType
    property alias savedTargetValue: saved.targetValue
    property alias savedTargetLabel: saved.targetLabel
    property bool startupAttempted: false
    property int startupAttempts: 0

    readonly property bool available: backend.available
    readonly property bool connected: backend.connected
    readonly property bool busy: backend.busy
    readonly property bool loadingLocations: backend.loadingLocations
    readonly property string server: backend.server
    readonly property string location: backend.location
    readonly property string protocol: backend.protocol
    readonly property int load: backend.load
    readonly property string error: backend.error
    readonly property string message: backend.message
    readonly property var countries: backend.countries
    readonly property var cities: backend.cities
    readonly property var settings: backend.settings
    readonly property var settingOptions: backend.settingOptions

    signal actionCompleted(bool success)

    function refresh() { backend.refresh() }
    function loadCountries() { backend.loadCountries() }
    function loadCities(country) { backend.loadCities(country) }
    function disconnect() { backend.disconnect() }
    function setSetting(name, value) { backend.setSetting(name, value) }

    function connectTarget(target, remember = true) {
        if (remember) {
            savedTargetType = target.type
            savedTargetValue = target.value
            savedTargetLabel = target.label
        }
        backend.connectTarget(target)
    }

    function tryAutoConnect() {
        if (startupAttempted || startupAttempts >= 4 || !autoConnect || !backend.startupRefreshDone || backend.connected || backend.busy) return
        startupAttempted = true
        startupAttempts++
        connectTarget({ type: savedTargetType, value: savedTargetValue, label: savedTargetLabel }, false)
    }

    FileView {
        path: Quickshell.shellDir + "/vpn.json"
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.tryAutoConnect()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
        }
        JsonAdapter {
            id: saved
            property bool autoConnect: false
            property string targetType: "fastest"
            property string targetValue: ""
            property string targetLabel: "Fastest server"
        }
    }

    onAutoConnectChanged: tryAutoConnect()
    onOpenedChanged: backend.opened = opened

    ProtonVpn {
        id: proton
        onActionCompleted: success => {
            root.actionCompleted(success)
            if (!success && root.autoConnect && root.startupAttempts < 4) {
                root.startupAttempted = false
                retryTimer.restart()
            }
            root.tryAutoConnect()
        }
    }

    Timer { id: retryTimer; interval: 5000; onTriggered: root.tryAutoConnect() }
}
