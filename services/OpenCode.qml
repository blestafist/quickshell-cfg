import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string host: "127.0.0.1"
    property int port: 0
    property string baseUrl: port > 0 ? "http://" + host + ":" + port : ""
    property string defaultDirectory: localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    property string status: "starting"
    property string error: ""
    property var sessions: []
    property var models: []
    property string activeSessionId: ""
    property var requestQueue: []
    property var currentRequest: null
    property bool shuttingDown: false
    readonly property bool ready: status === "ready"

    signal sessionChanged(string sessionId)

    function localPath(value) {
        const path = String(value || "").replace(/^file:(\/\/)?/, "")
        try { return decodeURIComponent(path) }
        catch (decodeError) { return path }
    }

    function activeSession() {
        return sessions.find(session => session.id === activeSessionId) || null
    }

    function sessionById(sessionId) {
        return sessions.find(session => session.id === sessionId) || null
    }

    function replaceSession(sessionId, transform) {
        const index = sessions.findIndex(session => session.id === sessionId)
        if (index < 0) return
        const updated = sessions.slice()
        updated[index] = transform(Object.assign({}, updated[index]))
        sessions = updated
        sessionChanged(sessionId)
    }

    function setActiveSession(sessionId) {
        if (!sessionById(sessionId)) return
        activeSessionId = sessionId
        replaceSession(sessionId, session => {
            session.unread = false
            return session
        })
        loadMessages(sessionId)
    }

    function setSessionMode(sessionId, mode) {
        let title = ""
        replaceSession(sessionId, session => {
            session.mode = mode === "build" ? "build" : "chat"
            if (/^(Chat|Build) \d+$/.test(session.title)) {
                session.title = nextSessionTitle(session.mode, session.id)
                title = session.title
            }
            return session
        })
        if (title)
            enqueue("PATCH", "/session/" + encodeURIComponent(sessionId), JSON.stringify({ title: title }), () => {})
    }

    function nextSessionTitle(mode, excludeId = "") {
        const prefix = mode === "build" ? "Build" : "Chat"
        let number = 1
        while (sessions.some(session => session.id !== excludeId && session.title === prefix + " " + number)) number++
        return prefix + " " + number
    }

    function setSessionModel(sessionId, model) {
        if (!model || !model.providerID || !model.modelID) return
        replaceSession(sessionId, session => {
            session.model = model
            return session
        })
    }

    function loadModels() {
        enqueue("GET", "/provider?directory=" + encodeURIComponent(defaultDirectory), null, (ok, data) => {
            if (!ok || !data || !Array.isArray(data.all)) return
            const connected = Array.isArray(data.connected) ? data.connected : []
            const available = []
            for (const provider of data.all) {
                if (connected.indexOf(provider.id) < 0) continue
                const providerModels = provider.models || {}
                for (const modelId of Object.keys(providerModels)) {
                    const info = providerModels[modelId] || {}
                    available.push({
                        providerID: provider.id,
                        providerName: provider.name || provider.id,
                        modelID: modelId,
                        name: info.name || modelId
                    })
                }
            }
            models = available
            const preferred = available.find(model => model.providerID === "9router" && model.modelID === "kr/claude-sonnet-4.5")
                || available.find(model => model.modelID === "kr/claude-sonnet-4.5")
                || available[0]
                || null
            if (preferred) {
                const updated = sessions.map(session => {
                    if (!session.model) session.model = preferred
                    return session
                })
                sessions = updated
            }
        })
    }

    function setSessionDirectory(sessionId, directory) {
        const normalized = localPath(directory.trim())
        if (!normalized) return
        replaceSession(sessionId, session => {
            session.directory = normalized
            return session
        })
    }

    function enqueue(method, path, body, callback) {
        requestQueue = requestQueue.concat([{ method, path, body, callback }])
        runNextRequest()
    }

    function runNextRequest() {
        if (!ready || rest.running || requestQueue.length === 0) return
        const queue = requestQueue.slice()
        currentRequest = queue.shift()
        requestQueue = queue
        rest.stdinEnabled = currentRequest.body !== null
        const args = ["curl", "-sS", "-f", "-X", currentRequest.method, baseUrl + currentRequest.path]
        if (currentRequest.body !== null)
            args.push("-H", "Content-Type: application/json", "-d", "@-")
        rest.command = args
        rest.running = true
    }

    function createSession(directory = defaultDirectory) {
        const cwd = localPath(directory.trim()) || defaultDirectory
        const title = nextSessionTitle("chat")
        enqueue("POST", "/session?directory=" + encodeURIComponent(cwd), JSON.stringify({ title: title }), (ok, data) => {
            if (!ok || !data || !data.id) return
            const session = {
                id: data.id,
                title: title,
                directory: data.directory || cwd,
                mode: "chat",
                model: models.length ? models[0] : null,
                messages: [],
                busy: false,
                unread: false,
                loaded: true
            }
            sessions = sessions.concat([session])
            activeSessionId = session.id
            sessionChanged(session.id)
        })
    }

    function closeSession(sessionId) {
        const index = sessions.findIndex(session => session.id === sessionId)
        if (index < 0) return
        const remaining = sessions.filter(session => session.id !== sessionId)
        sessions = remaining
        if (activeSessionId === sessionId)
            activeSessionId = remaining.length ? remaining[Math.min(index, remaining.length - 1)].id : ""
        enqueue("DELETE", "/session/" + encodeURIComponent(sessionId), null, () => {})
    }

    function loadMessages(sessionId) {
        const session = sessionById(sessionId)
        if (!session || session.loaded) return
        enqueue("GET", "/session/" + encodeURIComponent(sessionId) + "/message?limit=100&directory=" + encodeURIComponent(session.directory), null, (ok, data) => {
            if (!ok || !Array.isArray(data)) return
            replaceSession(sessionId, current => {
                current.messages = data.map(message => normalizedMessage(message.info, message.parts))
                current.loaded = true
                return current
            })
        })
    }

    function normalizedMessage(info, parts) {
        return {
            id: info.id,
            role: info.role,
            parts: Array.isArray(parts) ? parts : [],
            created: info.time && info.time.created ? info.time.created : Date.now()
        }
    }

    function sendMessage(sessionId, text) {
        const session = sessionById(sessionId)
        const message = text.trim()
        if (!session || !message || session.busy) return false
        replaceSession(sessionId, current => {
            current.busy = true
            return current
        })
        const body = JSON.stringify({
            agent: session.mode === "build" ? "build" : "Chat",
            model: session.model ? { providerID: session.model.providerID, modelID: session.model.modelID } : undefined,
            parts: [{ type: "text", text: message }]
        })
        enqueue("POST", "/session/" + encodeURIComponent(sessionId) + "/prompt_async?directory=" + encodeURIComponent(session.directory), body, ok => {
            if (!ok) replaceSession(sessionId, current => { current.busy = false; return current })
        })
        return true
    }

    function abort(sessionId) {
        const session = sessionById(sessionId)
        if (!session) return
        enqueue("POST", "/session/" + encodeURIComponent(sessionId) + "/abort?directory=" + encodeURIComponent(session.directory), "{}", () => {})
    }

    function handleEvent(frame) {
        const lines = frame.split("\n")
        for (const line of lines) {
            if (!line.startsWith("data:")) continue
            try {
                const event = JSON.parse(line.slice(5).trim())
                routeEvent(event)
            } catch (eventError) {
                console.warn("OpenCode: invalid SSE event", eventError)
            }
        }
    }

    function routeEvent(event) {
        const properties = event.properties || {}
        const sessionId = properties.sessionID || (properties.info && properties.info.sessionID) || (properties.part && properties.part.sessionID)
        if (!sessionId || !sessionById(sessionId)) return
        if (event.type === "session.status") {
            const busy = properties.status && properties.status.type === "busy"
            replaceSession(sessionId, session => {
                const completedInBackground = session.busy && !busy && activeSessionId !== sessionId
                session.busy = busy
                session.unread = session.unread || completedInBackground
                return session
            })
            return
        }
        if (event.type === "session.updated" && properties.info) {
            replaceSession(sessionId, session => {
                session.title = properties.info.title || session.title
                return session
            })
            return
        }
        if (event.type === "message.updated" && properties.info) {
            upsertMessage(sessionId, properties.info)
            return
        }
        if (event.type === "message.part.updated" && properties.part)
            upsertPart(sessionId, properties.part)
        else if (event.type === "message.part.delta" && properties.messageID && properties.partID)
            appendPartDelta(sessionId, properties.messageID, properties.partID, properties.field, properties.delta)
    }

    function upsertMessage(sessionId, info) {
        replaceSession(sessionId, session => {
            const messages = session.messages.slice()
            const index = messages.findIndex(message => message.id === info.id)
            if (index < 0)
                messages.push(normalizedMessage(info, []))
            else
                messages[index] = Object.assign({}, messages[index], { role: info.role })
            session.messages = messages
            return session
        })
    }

    function upsertPart(sessionId, part) {
        const messageId = part.messageID
        if (!messageId) return
        replaceSession(sessionId, session => {
            const messages = session.messages.slice()
            let messageIndex = messages.findIndex(message => message.id === messageId)
            if (messageIndex < 0) {
                messages.push({ id: messageId, role: "assistant", parts: [], created: Date.now() })
                messageIndex = messages.length - 1
            }
            const message = Object.assign({}, messages[messageIndex])
            const parts = message.parts.slice()
            const partIndex = parts.findIndex(existing => existing.id === part.id)
            if (partIndex < 0) parts.push(part)
            else parts[partIndex] = part
            message.parts = parts
            messages[messageIndex] = message
            session.messages = messages
            return session
        })
    }

    function appendPartDelta(sessionId, messageId, partId, field, delta) {
        if (field !== "text" || !delta) return
        replaceSession(sessionId, session => {
            const messages = session.messages.slice()
            let messageIndex = messages.findIndex(message => message.id === messageId)
            if (messageIndex < 0) {
                messages.push({ id: messageId, role: "assistant", parts: [], created: Date.now() })
                messageIndex = messages.length - 1
            }
            const message = Object.assign({}, messages[messageIndex])
            const parts = message.parts.slice()
            let partIndex = parts.findIndex(part => part.id === partId)
            if (partIndex < 0) {
                parts.push({ id: partId, messageID: messageId, sessionID: sessionId, type: "text", text: "" })
                partIndex = parts.length - 1
            }
            parts[partIndex] = Object.assign({}, parts[partIndex], { text: (parts[partIndex].text || "") + delta })
            message.parts = parts
            messages[messageIndex] = message
            session.messages = messages
            return session
        })
    }

    function startEventStream() {
        if (!ready || events.running) return
        events.command = ["curl", "-sN", "--no-buffer", baseUrl + "/event"]
        events.running = true
    }

    Process {
        id: server
        command: ["opencode", "serve", "--port", "0", "--hostname", root.host]
        environment: ({ PATH: root.defaultDirectory + "/.local/bin:/usr/local/bin:/usr/bin:/bin" })
        running: true
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/127\.0\.0\.1:(\d+)/)
                if (!match) return
                root.port = Number(match[1])
                root.status = "ready"
                root.error = ""
                root.loadModels()
                root.startEventStream()
                root.runNextRequest()
            }
        }
        stderr: SplitParser {
            onRead: data => {
                const match = data.match(/127\.0\.0\.1:(\d+)/)
                if (match) {
                    root.port = Number(match[1])
                    root.status = "ready"
                    root.error = ""
                    root.loadModels()
                    root.startEventStream()
                    root.runNextRequest()
                } else if (!data.includes("OPENCODE_SERVER_PASSWORD"))
                    console.warn("OpenCode server:", data.trim())
            }
        }
        onExited: code => {
            if (root.shuttingDown) return
            root.status = "error"
            root.error = "OpenCode server stopped (exit " + code + ")"
        }
    }

    Process {
        id: events
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => root.handleEvent(data)
        }
        onExited: {
            if (root.ready && !root.shuttingDown) reconnectTimer.restart()
        }
    }

    Process {
        id: rest
        stdout: StdioCollector { id: restOutput }
        stderr: StdioCollector { id: restError }
        onStarted: {
            if (root.currentRequest && root.currentRequest.body !== null)
                write(root.currentRequest.body)
            stdinEnabled = false
        }
        onExited: code => {
            const request = root.currentRequest
            let data = null
            if (restOutput.text.trim()) {
                try { data = JSON.parse(restOutput.text) }
                catch (parseError) { console.warn("OpenCode: invalid REST response", parseError) }
            }
            if (code !== 0) root.error = restError.text.trim() || "OpenCode request failed"
            root.currentRequest = null
            if (request && request.callback) request.callback(code === 0, data)
            Qt.callLater(root.runNextRequest)
        }
    }

    Timer { id: reconnectTimer; interval: 1000; onTriggered: root.startEventStream() }

    Component.onDestruction: {
        shuttingDown = true
        events.running = false
        server.running = false
    }
}
