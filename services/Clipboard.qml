import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool opened: false
    property var entries: []
    property string error: ""
    property string copiedId: ""
    property string pendingId: ""
    readonly property bool loading: listing.running
    readonly property bool copying: copier.running
    readonly property string script: Quickshell.shellPath("scripts/clipboard.sh")

    function refresh() {
        if (!loading && !copying) listing.running = true
    }

    function copy(id) {
        if (copying || !/^\d+$/.test(id)) return
        pendingId = id
        error = ""
        copier.command = ["sh", script, "copy", id]
        copier.running = true
    }

    onOpenedChanged: if (opened) {
        copiedId = ""
        refresh()
    }

    Process {
        id: watcher
        command: ["sh", root.script, "watch"]
        running: true
        onExited: {
            root.error = "Clipboard watcher stopped. Check cliphist and wl-clipboard."
            retry.restart()
        }
    }
    Timer { id: retry; interval: 5000; onTriggered: watcher.running = true }
    Timer { interval: 1500; repeat: true; running: root.opened; onTriggered: root.refresh() }
    Timer { id: feedback; interval: 1800; onTriggered: root.copiedId = "" }

    Process {
        id: listing
        command: ["sh", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = text.split("\n").filter(line => /^\d+\t/.test(line)).map(line => {
                    const tab = line.indexOf("\t")
                    return { id: line.slice(0, tab), preview: line.slice(tab + 1) }
                })
                // Avoid rebuilding the strip (and losing scroll/selection) on every poll.
                if (JSON.stringify(items) !== JSON.stringify(root.entries)) root.entries = items
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.error = "Cannot read clipboard history. Check cliphist."
        }
    }
    Process {
        id: copier
        onExited: (code, status) => {
            if (code === 0) {
                root.copiedId = root.pendingId
                feedback.restart()
                root.refresh()
            } else root.error = "Copy failed. The clipboard has not been replaced."
        }
    }
}
