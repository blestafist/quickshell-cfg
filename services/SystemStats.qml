import QtQuick
import Quickshell.Io

Item {
    id: root

    property string cpu: "--"
    property string memory: "--"
    property string gpu: "N/A"
    property string volume: "--"
    property bool muted: false
    property string network: "Offline"
    property string signal: ""
    property string keyboardLayout: "--"

    function run(process) {
        if (!process.running)
            process.running = true
    }

    Process {
        id: resourcesProcess
        command: ["sh", "-c", "~/.config/quickshell/scripts/status.sh resources"]
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split("|")
                if (values.length >= 3) {
                    root.cpu = values[0] + "%"
                    root.memory = values[1] + "%"
                    root.gpu = values[2] === "" ? "N/A" : values[2] === "N/A" ? "N/A" : values[2] + "%"
                }
            }
        }
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "~/.config/quickshell/scripts/status.sh network"]
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split("|")
                root.network = values[0] || "Offline"
                root.signal = values[1] ? values[1] + "%" : ""
            }
        }
    }

    Process {
        id: audioProcess
        command: ["sh", "-c", "~/.config/quickshell/scripts/status.sh audio"]
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split("|")
                root.volume = (values[0] || "0") + "%"
                root.muted = values[1] === "1"
            }
        }
    }

    Process {
        id: layoutProcess
        command: ["sh", "-c", "~/.config/quickshell/scripts/status.sh layout"]
        stdout: SplitParser {
            onRead: data => root.keyboardLayout = data.trim() || "--"
        }
    }

    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(resourcesProcess) }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(networkProcess) }
    Timer { interval: 700; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(audioProcess) }
    Timer { interval: 800; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(layoutProcess) }

}
