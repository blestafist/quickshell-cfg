import QtQuick
import Quickshell.Io

VpnBackend {
    id: root

    property string executable: "protonvpn"
    property string pendingAction: ""
    property var pendingTarget: ({ type: "fastest", value: "", label: "Fastest server" })
    property bool startupRefreshDone: false
    readonly property var settingOptions: ({
        "netshield": ["off", "malware-only", "malware-ads-trackers"],
        "kill-switch": ["off", "standard"],
        "port-forwarding": ["off", "on"],
        "vpn-accelerator": ["off", "on"],
        "moderate-nat": ["off", "on"],
        "ipv6": ["off", "on"]
    })
    loadingLocations: countriesProcess.running || citiesProcess.running

    function clean(text) {
        return text.replace(/[\b\r]/g, "").trim()
    }

    function refresh() {
        if (!statusProcess.running) statusProcess.running = true
        if (!configProcess.running) configProcess.running = true
    }

    function loadCountries() {
        if (!countriesProcess.running) countriesProcess.running = true
    }

    function loadCities(country) {
        if (!country || citiesProcess.running) return
        citiesProcess.command = [executable, "cities", "list", country]
        citiesProcess.running = true
    }

    function connectTarget(target) {
        if (busy) return
        const args = [executable, "connect"]
        if (target.type === "country") args.push("--country", target.value)
        else if (target.type === "city") args.push("--city", target.value)
        else if (target.type === "server") args.push(target.value)
        else if (target.type === "random") args.push("--random")
        pendingTarget = target
        runAction(args, "connect", "Connecting to " + target.label + "...")
    }

    function disconnect() {
        runAction([executable, "disconnect"], "disconnect", "Disconnecting...")
    }

    function setSetting(name, value) {
        if (!settingOptions[name] || settingOptions[name].indexOf(value) < 0) {
            error = "Unsupported VPN setting: " + name
            return
        }
        runAction([executable, "config", "set", name, value], "setting", "Updating " + name + "...")
    }

    function runAction(command, kind, label) {
        if (busy) return
        error = ""
        message = label
        pendingAction = kind
        actionProcess.command = command
        actionProcess.running = true
    }

    onOpenedChanged: if (opened) { refresh(); if (!countries.length) loadCountries() }

    Process {
        id: statusProcess
        command: [root.executable, "status"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const output = root.clean(text)
                root.available = true
                root.connected = /^Status:\s*Connected/im.test(output)
                const serverMatch = output.match(/^Server:\s*(.+)$/im)
                const serverLine = serverMatch ? serverMatch[1].trim() : ""
                const locationSeparator = serverLine.indexOf(" in ")
                root.server = locationSeparator < 0 ? serverLine : serverLine.slice(0, locationSeparator)
                root.location = locationSeparator < 0 ? "" : serverLine.slice(locationSeparator + 4)
                const loadMatch = output.match(/^Load:\s*(\d+)%/im)
                root.load = loadMatch ? Number(loadMatch[1]) : -1
                const protocolMatch = output.match(/^Protocol:\s*(.+)$/im)
                root.protocol = protocolMatch ? protocolMatch[1].trim() : ""
            }
        }
        stderr: StdioCollector { id: statusError }
        onExited: code => {
            if (code !== 0) {
                root.available = false
                root.connected = false
                if (root.opened) root.error = root.clean(statusError.text) || "Proton VPN CLI is unavailable."
            }
            if (!root.startupRefreshDone) {
                root.startupRefreshDone = true
                root.actionCompleted(code === 0)
            }
        }
    }

    Process {
        id: configProcess
        command: [root.executable, "config", "list"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {}
                for (const line of root.clean(text).split("\n")) {
                    const match = line.match(/^([a-z][a-z-]+)\s{2,}(.+)$/)
                    if (match) values[match[1]] = match[2].trim()
                }
                root.settings = values
            }
        }
    }

    Process {
        id: countriesProcess
        command: [root.executable, "countries", "list"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const result = []
                for (const line of root.clean(text).split("\n")) {
                    const match = line.match(/^(.+?)\s{2,}([A-Z]{2})$/)
                    if (match && match[1] !== "Country") result.push({ name: match[1].trim(), code: match[2] })
                }
                root.countries = result
            }
        }
    }

    Process {
        id: citiesProcess
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const result = []
                for (const line of root.clean(text).split("\n")) {
                    const match = line.match(/^(.+?)\s{2,}(.+)$/)
                    if (match && match[1] !== "City" && !/^-+$/.test(match[1])) result.push({ name: match[1].trim(), features: match[2].trim() })
                }
                root.cities = result
            }
        }
    }

    Process {
        id: actionProcess
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onRunningChanged: root.busy = running
        onExited: code => {
            const details = root.clean(actionError.text) || root.clean(actionOutput.text)
            root.error = code === 0 ? "" : details || "Proton VPN could not complete the operation."
            root.message = ""
            root.actionCompleted(code === 0)
            root.pendingAction = ""
            refreshDelay.restart()
        }
    }

    Timer { id: refreshDelay; interval: 500; onTriggered: root.refresh() }
    Timer { interval: 10000; running: root.opened || root.connected; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
