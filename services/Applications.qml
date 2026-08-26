import QtQuick
import Quickshell.Io

Item {
    id: root

    property var applications: []

    function reload() {
        indexer.running = true
    }

    Process {
        id: indexer
        command: ["sh", "-c", "~/.config/quickshell/scripts/applications.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                const indexed = []
                const lines = this.text.trim().split("\n")
                for (const line of lines) {
                    const fields = line.split("\x1c")
                    if (fields.length !== 6)
                        continue
                    const desktopId = fields[5].split("/").pop()
                    if (seen[desktopId])
                        continue
                    // XDG_DATA_HOME is emitted first, so user entries override system ones.
                    seen[desktopId] = true
                    indexed.push({
                        kind: "application",
                        name: fields[0],
                        description: fields[1] || fields[5].split("/").pop(),
                        keywords: fields[2],
                        icon: fields[3],
                        terminal: fields[4] === "1",
                        desktopFile: fields[5]
                    })
                }
                indexed.sort((first, second) => first.name.localeCompare(second.name))
                root.applications = indexed
            }
        }
    }

    Component.onCompleted: reload()
}
