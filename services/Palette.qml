import QtQuick
import Quickshell
import Quickshell.Io

import "../config" as Config
import "../theme" as Theme

Item {
    id: root

    property string requestedPath: ""
    property string activePath: ""
    property string error: ""
    property bool forceNext: false
    readonly property bool generating: generator.running
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/quickshell/theme.json"

    function request(path, force = false) {
        if (!Config.ShellConfig.wallpaperThemeEnabled || !path) return
        requestedPath = path
        forceNext = forceNext || force
        error = ""
        if (!generator.running) generate()
    }

    function generate() {
        if (!requestedPath || generator.running) return
        activePath = requestedPath
        generator.command = ["python3", "-B", Quickshell.shellPath("scripts/theme.py"), activePath,
            "--state", stateFile, "--mode", Config.ShellConfig.wallpaperThemeMode,
            "--scheme", Config.ShellConfig.wallpaperThemeScheme].concat(forceNext ? ["--force"] : [])
        forceNext = false
        generator.running = true
    }

    function accept(data, generated = false) {
        if (!Config.ShellConfig.wallpaperThemeEnabled) return
        const pending = generator.running || (activePath && requestedPath !== activePath)
        if ((generated || pending) && requestedPath && data.wallpaper !== requestedPath) return
        if (!Theme.Theme.applyPalette(data)) throw new Error("Invalid saved theme palette")
        // When idle, also accept palettes written by update-theme.sh. During a
        // queued generation, only the newest wallpaper may replace the theme.
        if (!generated && !pending) requestedPath = activePath = data.wallpaper
    }

    FileView {
        id: saved
        path: root.stateFile
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.accept(JSON.parse(text())) }
            catch (error) { console.warn("Cannot load theme palette:", error) }
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) console.warn("Cannot read theme palette:", error)
        }
    }

    Process {
        id: generator
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (result.event === "palette") root.accept(result, true)
                    else root.error = result.error || "Could not generate the theme."
                } catch (error) { root.error = "Could not read the generated theme: " + error }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.error) root.error = "Could not generate the theme. Check Matugen."
            // Explicit reload also handles the very first atomic file creation.
            if (code === 0) saved.reload()
            if (root.requestedPath !== root.activePath || root.forceNext) Qt.callLater(root.generate)
        }
    }

    IpcHandler {
        target: "theme"
        function refresh() { root.request(root.requestedPath || Theme.Theme.wallpaper, true) }
        function status(): string {
            return JSON.stringify({wallpaper: Theme.Theme.wallpaper, generating: root.generating,
                mode: Config.ShellConfig.wallpaperThemeMode, scheme: Config.ShellConfig.wallpaperThemeScheme,
                accent: String(Theme.Theme.accent), error: root.error})
        }
    }
}
