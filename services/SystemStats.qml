import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    property string cpu: "--"
    property string memory: "--"
    property string memoryGigabytes: "-- GB"
    property string gpu: "N/A"
    property string volume: "--"
    property bool muted: false
    property string network: "Offline"
    property string signal: ""
    property string keyboardLayout: "--"
    property string music: ""
    property bool musicPlaying: false

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
                if (values.length >= 4) {
                    root.cpu = values[0] + "%"
                    root.memory = values[1] + "%"
                    root.memoryGigabytes = values[2]
                    root.gpu = values[3] === "" ? "N/A" : values[3] === "N/A" ? "N/A" : values[3] + "%"
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

    Process {
        id: audioEvents
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => root.run(audioProcess)
        }
    }

    Process {
        id: networkEvents
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => root.run(networkProcess)
        }
    }

    Process {
        id: musicProcess
        command: ["playerctl", "metadata", "--follow", "--format", "{{status}}|{{artist}}|{{title}}"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split("|")
                root.musicPlaying = values[0] === "Playing"
                root.music = values.length >= 3 ? [values[1], values.slice(2).join("|")].filter(value => value !== "").join(" - ") : ""
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.run(layoutProcess)
        }
    }

    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(resourcesProcess) }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(networkProcess) }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(audioProcess) }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(layoutProcess) }

}
