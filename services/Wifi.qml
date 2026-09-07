import QtQuick
import Quickshell.Io

Item {
    id: root
    property bool opened: false
    property bool enabled: false
    property var networks: []
    property string error: ""
    property string message: ""
    property string pendingPassword: ""
    property var profiles: []
    property var profileQueue: []
    property var pendingProfiles: []
    readonly property bool loadingProfiles: profileList.running || profileDetail.running || profileQueue.length > 0
    signal connected()
    readonly property bool busy: action.running
    readonly property bool scanning: scan.running || listing.running

    // nmcli terse output escapes both colons and backslashes.
    function fields(line) {
        const result = [""]
        let escaped = false
        for (const c of line) {
            if (escaped) { result[result.length - 1] += c; escaped = false }
            else if (c === "\\") escaped = true
            else if (c === ":") result.push("")
            else result[result.length - 1] += c
        }
        return result
    }

    function refresh(rescan = false) {
        if (!loadingProfiles) profileList.running = true
        if (!radio.running) radio.running = true
        if (rescan && !scanning && !busy) scan.running = true
        else if (!scanning) listing.running = true
    }

    function run(args, label, password = "") {
        if (busy) return
        error = ""
        message = label
        pendingPassword = password
        action.stdinEnabled = true
        action.command = ["nmcli", "--wait", "30"].concat(args)
        action.running = true
    }

    function connect(network, password) {
        const saved = savedProfile(network)
        if (saved && !password) {
            run(["connection", "up", "uuid", saved.uuid, "ifname", network.device, "ap", network.bssid], "Connecting to " + network.ssid + "...")
            return
        }
        if (/802\.1X|EAP/.test(network.security)) {
            error = "Enterprise Wi-Fi requires a configured NetworkManager profile."
            return
        }
        run((password ? ["--ask"] : []).concat(["device", "wifi", "connect", network.bssid, "ifname", network.device]),
            "Connecting to " + network.ssid + "...", password)
    }

    function savedProfile(network) {
        return profiles.find(profile => profile.ssid === network.ssid
            && (!profile.device || profile.device === network.device)
            && (!profile.bssid || profile.bssid.toUpperCase() === network.bssid.toUpperCase())
            && (profile.security === "wpa-eap" || profile.security === "ieee8021x" ? /802\.1X|EAP/.test(network.security)
                : profile.security === "sae" ? /WPA3/.test(network.security)
                : profile.security === "wpa-psk" ? /WPA/.test(network.security)
                : profile.security === "owe" ? /OWE/.test(network.security)
                : !network.security || /WEP/.test(network.security))) || null
    }

    function nextProfile() {
        if (!profileQueue.length) { profiles = pendingProfiles; return }
        const queue = profileQueue.slice()
        const uuid = queue.shift()
        profileQueue = queue
        profileDetail.command = ["nmcli", "-t", "-f", "connection.uuid,connection.interface-name,802-11-wireless.ssid,802-11-wireless.bssid,802-11-wireless-security.key-mgmt", "connection", "show", "uuid", uuid]
        profileDetail.running = true
    }

    Process {
        id: profileList
        command: ["nmcli", "-t", "-f", "UUID,TYPE", "connection", "show"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                root.pendingProfiles = []
                root.profileQueue = text.split("\n").map(root.fields).filter(f => f[1] === "802-11-wireless").map(f => f[0])
            }
        }
        onExited: root.nextProfile()
    }
    Process {
        id: profileDetail
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {}
                for (const line of text.split("\n")) {
                    const f = root.fields(line)
                    values[f[0]] = f[1] || ""
                }
                if (values["connection.uuid"] && values["802-11-wireless.ssid"])
                    root.pendingProfiles.push({ uuid: values["connection.uuid"], device: values["connection.interface-name"], ssid: values["802-11-wireless.ssid"], bssid: values["802-11-wireless.bssid"], security: values["802-11-wireless-security.key-mgmt"] })
            }
        }
        onExited: Qt.callLater(root.nextProfile)
    }

    onOpenedChanged: if (opened) refresh(true)
    Process {
        id: radio
        command: ["nmcli", "radio", "wifi"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector { onStreamFinished: root.enabled = text.trim() === "enabled" }
    }
    Process {
        id: listing
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,DEVICE", "device", "wifi", "list", "--rescan", "no"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const unique = {}
                for (const line of text.split("\n")) {
                    const f = root.fields(line)
                    if (f.length < 6 || !f[1]) continue
                    const network = { active: f[0] === "*", ssid: f[1], bssid: f[2], signal: Number(f[3]), security: f[4], device: f[5] }
                    const key = JSON.stringify([network.ssid, network.security, network.device])
                    if (!unique[key] || network.active || (!unique[key].active && network.signal > unique[key].signal)) unique[key] = network
                }
                const updated = Object.values(unique)
                // Keep visible rows in place while signal readings fluctuate.
                const previous = root.networks.map(n => JSON.stringify([n.ssid, n.security, n.device]))
                updated.sort((a, b) => {
                    if (a.active !== b.active) return Number(b.active) - Number(a.active)
                    const ai = previous.indexOf(JSON.stringify([a.ssid, a.security, a.device]))
                    const bi = previous.indexOf(JSON.stringify([b.ssid, b.security, b.device]))
                    if (ai >= 0 || bi >= 0) return (ai < 0 ? previous.length : ai) - (bi < 0 ? previous.length : bi)
                    return b.signal - a.signal
                })
                if (JSON.stringify(root.networks) !== JSON.stringify(updated)) root.networks = updated
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim() }
    }
    Process {
        id: scan
        command: ["nmcli", "--wait", "15", "device", "wifi", "rescan"]
        environment: ({ LC_ALL: "C" })
        onExited: { if (!listing.running) listing.running = true }
    }
    Process {
        id: action
        environment: ({ LC_ALL: "C" })
        stdinEnabled: true
        // Feed the secret through stdin, never through argv or a shell command.
        onStarted: {
            if (root.pendingPassword) write(root.pendingPassword + "\n")
            root.pendingPassword = ""
            stdinEnabled = false
        }
        stderr: StdioCollector { id: actionError }
        onExited: (code, status) => {
            root.pendingPassword = ""
            root.error = code === 0 ? "" : actionError.text.trim() || "NetworkManager could not complete the operation."
            root.message = ""
            if (code === 0) root.connected()
            root.refresh()
        }
    }
    Timer { interval: 10000; running: root.opened; repeat: true; onTriggered: root.refresh() }
}
