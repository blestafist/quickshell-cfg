import QtQuick

QtObject {
    id: mock
    signal clearInput()
    property bool active: false
    property bool waiting: false
    property bool responseVisible: false
    property bool failed: false
    property bool coolingDown: false
    property string statusMessage: "Mock authentication only. Use any sample text."
    property string prompt: "Sample password"
    readonly property bool canBegin: !active
    readonly property bool canRespond: waiting

    function begin() {
        active = true
        waiting = true
        failed = false
        responseVisible = false
        statusMessage = prompt = "Sample password (not your real password)"
    }
    function respond(value) {
        if (!waiting || !value.length) return
        clearInput()
        if (!responseVisible) {
            responseVisible = true
            statusMessage = prompt = "Second prompt: sample verification code"
        } else {
            waiting = active = false
            failed = true
            statusMessage = "Mock failure. Continue to try again."
        }
    }
    function reset() {
        waiting = active = failed = false
        clearInput()
        statusMessage = "Preview reset. No session was locked."
    }
}
