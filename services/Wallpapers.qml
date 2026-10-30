import QtQuick
import Quickshell
import Quickshell.Io

import "../config" as Config

Item {
    id: root

    property bool opened: false
    property string output: ""
    property var entries: []
    property string directory: ""
    property string currentPath: ""
    property string error: ""
    property bool applying: false
    property bool confirmed: false
    property var previewUrls: ({})
    property var previewQueue: []
    property var previewBatch: []
    property var previewPending: ({})
    property var previewFailed: ({})
    property string previewError: ""
    property var paletteController: null
    readonly property string paletteError: paletteController ? paletteController.error : ""
    readonly property bool loading: listing.running
    readonly property string script: Quickshell.shellPath("scripts/wallpaper.py")

    signal transitionStarted()
    signal applied()
    signal failed()

    function refresh() {
        if (loading || applying) return
        error = ""
        previewFailed = ({})
        previewError = ""
        listing.command = ["python3", script, "list", "--directory", Config.ShellConfig.wallpaperDirectory,
            "--recursive", String(Config.ShellConfig.wallpaperRecursive), "--output", output]
        listing.running = true
    }

    function ensurePreviews(items, background = false) {
        const added = []
        for (const entry of items) {
            if (!entry || entry.preview || previewUrls[entry.cacheKey]
                    || previewPending[entry.cacheKey] || previewFailed[entry.cacheKey]) continue
            previewPending[entry.cacheKey] = true
            added.push(entry)
        }
        // New viewport requests outrank stale offscreen work. Keep batches small
        // so a fast scroll never waits behind an entire collection conversion.
        if (background) previewQueue = previewQueue.concat(added)
        else {
            const rank = ({})
            items.forEach((item, index) => { rank[item.cacheKey] = index })
            previewQueue = added.concat(previewQueue).sort((a, b) =>
                (rank[a.cacheKey] === undefined ? 99999 : rank[a.cacheKey])
                - (rank[b.cacheKey] === undefined ? 99999 : rank[b.cacheKey]))
        }
        if (!previews.running) startPreviews()
    }

    function startPreviews() {
        if (!previewQueue.length || previews.running || !directory) return
        const batch = previewQueue.slice(0, 6)
        previewBatch = batch
        previewQueue = previewQueue.slice(6)
        previews.command = ["python3", script, "cache", "--directory", directory,
            "--paths", JSON.stringify(batch.map(entry => entry.path)),
            "--limit-mib", String(Config.ShellConfig.wallpaperCacheLimitMiB)]
        previews.running = true
    }

    function apply(entry, x, y) {
        if (applying || !entry) return false
        error = ""
        confirmed = false
        applying = true
        setter.command = ["python3", script, "apply", "--directory", directory, "--path", entry.path,
            "--x", String(x), "--y", String(y),
            "--duration", String(Config.ShellConfig.animationsEnabled ? Config.ShellConfig.wallpaperTransitionDuration : 0),
            "--fps", String(Config.ShellConfig.wallpaperTransitionFps)]
        setter.running = true
        return true
    }

    onOpenedChanged: if (opened) refresh()
    Component.onCompleted: refresh()

    // Warm ordinary-sized collections once, at low process priority. Huge
    // libraries stay demand-driven rather than decoding thousands of files.
    Timer {
        id: warmup
        interval: 500
        onTriggered: root.ensurePreviews(root.entries.slice(0, 128), true)
    }

    Process {
        id: previews
        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line)
                    if (result.event === "preview") {
                        delete root.previewPending[result.key]
                        root.previewUrls = Object.assign({}, root.previewUrls, { [result.key]: result.url })
                    } else if (result.event === "preview-error") {
                        const entry = root.entries.find(item => item.path === result.path)
                        if (entry) {
                            delete root.previewPending[entry.cacheKey]
                            root.previewFailed[entry.cacheKey] = true
                        }
                        root.previewError = result.error
                    } else if (result.event === "error") root.previewError = result.error
                } catch (error) { console.warn("Invalid preview response:", line) }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.previewError = "Could not prepare previews. Check ImageMagick."
            for (const entry of root.previewBatch) {
                delete root.previewPending[entry.cacheKey]
                if (!root.previewUrls[entry.cacheKey]) root.previewFailed[entry.cacheKey] = true
            }
            root.previewBatch = []
            Qt.callLater(root.startPreviews)
        }
    }

    Process {
        id: listing
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (!Array.isArray(result.entries)) throw new Error(result.error || "Invalid wallpaper library")
                    root.directory = result.directory
                    root.currentPath = result.current || ""
                    if (root.paletteController && root.currentPath) root.paletteController.request(root.currentPath)
                    root.error = result.error || ""
                    if (JSON.stringify(root.entries) !== JSON.stringify(result.entries)) root.entries = result.entries
                    warmup.restart()
                } catch (error) {
                    root.error = "Could not read the collection: " + error
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.error) root.error = "Could not run wallpaper.py. Check python3."
        }
    }

    Process {
        id: setter
        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line)
                    if (result.event === "started") root.transitionStarted()
                    else if (result.event === "applied") {
                        root.currentPath = result.path
                        root.confirmed = true
                    } else if (result.event === "error") root.error = result.error
                } catch (error) {
                    console.warn("Invalid wallpaper response:", line)
                }
            }
        }
        onExited: (code, status) => {
            root.applying = false
            if (code === 0 && root.confirmed) {
                if (root.paletteController) root.paletteController.request(root.currentPath)
                root.applied()
            }
            else {
                if (!root.error) root.error = "Could not apply the wallpaper. Check awww-daemon."
                root.failed()
            }
        }
    }
}
