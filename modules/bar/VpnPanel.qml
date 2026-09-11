import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme" as Theme
import "../../config" as Config

FocusScope {
    id: root

    required property var vpn
    property real maximumHeight: 700
    property string page: "locations"
    property string selectedCountry: ""
    property string selectedCountryName: ""
    property string query: ""
    property string expandedSetting: ""
    property bool autoTargetExpanded: false
    property string autoTargetMode: vpn.savedTargetType === "country" ? "country" : vpn.savedTargetType === "server" ? "server" : "fastest"
    signal closeRequested()

    implicitHeight: Math.min(maximumHeight, content.implicitHeight + 40)
    Keys.onEscapePressed: {
        closeRequested()
    }
    onVisibleChanged: if (!visible) { query = ""; serverId.text = "" }

    function filteredLocations() {
        const source = vpn.countries
        const needle = query.trim().toLowerCase()
        return needle ? source.filter(item => item.name.toLowerCase().includes(needle)) : source
    }

    function flag(code) {
        if (!code || code.length !== 2) return ""
        const upper = code.toUpperCase()
        return String.fromCodePoint(0x1f1e6 + upper.charCodeAt(0) - 65, 0x1f1e6 + upper.charCodeAt(1) - 65)
    }

    component Label: Text {
        color: Theme.Theme.textPrimary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    component Action: Button {
        id: button
        implicitHeight: 34
        implicitWidth: Math.max(34, contentItem.implicitWidth + 22)
        background: Rectangle {
            radius: 9
            color: button.down || button.hovered ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised
            border.width: button.activeFocus ? 1 : 0
            border.color: Theme.Theme.accent
            Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 140 : 0 } }
        }
        contentItem: Label {
            text: button.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: button.enabled ? 1 : 0.4
        }
    }

    component Toggle: Button {
        id: toggle
        required property bool checkedValue
        implicitWidth: 48
        implicitHeight: 26
        background: Rectangle {
            radius: 13
            color: toggle.checkedValue ? Theme.Theme.accent : Theme.Theme.surfaceHover
            Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
            Rectangle {
                width: 20
                height: 20
                radius: 10
                y: 3
                x: toggle.checkedValue ? parent.width - width - 3 : 3
                color: toggle.checkedValue ? Theme.Theme.accentText : Theme.Theme.textSecondary
                Behavior on x { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 220 : 0; easing.type: Easing.OutBack } }
            }
        }
        contentItem: Item {}
    }

    ColumnLayout {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 12

        RowLayout {
            spacing: 10
            Rectangle {
                width: 42
                height: 42
                radius: 14
                color: root.vpn.connected ? Theme.Theme.accent : Theme.Theme.surfaceRaised
                Label {
                    anchors.centerIn: parent
                    text: root.vpn.connected ? "󰦝" : "󰦜"
                    font.pixelSize: 21
                    color: root.vpn.connected ? Theme.Theme.accentText : Theme.Theme.textMuted
                }
                SequentialAnimation on scale {
                    running: root.vpn.busy && Config.ShellConfig.animationsEnabled
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.9; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label { text: "Proton VPN"; font.pixelSize: 20; font.weight: Font.DemiBold }
                Label {
                    Layout.fillWidth: true
                    text: root.vpn.busy ? root.vpn.message : root.vpn.connected
                        ? root.vpn.server + (root.vpn.location ? " · " + root.vpn.location : "")
                        : root.vpn.available ? "Your connection is not protected" : "Proton VPN CLI unavailable"
                    color: root.vpn.connected ? Theme.Theme.accent : Theme.Theme.textMuted
                }
            }
            Action {
                text: root.vpn.connected ? "Disconnect" : "Quick connect"
                enabled: root.vpn.available && !root.vpn.busy
                onClicked: root.vpn.connected ? root.vpn.disconnect() : root.vpn.connectTarget({ type: "fastest", value: "", label: "Fastest server" })
            }
            Action { text: "×"; Accessible.name: "Close VPN"; onClicked: root.closeRequested() }
        }

        RowLayout {
            spacing: 6
            Repeater {
                model: [{ key: "locations", label: "Locations" }, { key: "settings", label: "Settings" }]
                Button {
                    id: tab
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    background: Rectangle {
                        radius: 9
                        color: root.page === tab.modelData.key ? Theme.Theme.surfaceRaised : tab.hovered ? Theme.Theme.surfaceHover : "transparent"
                        Rectangle {
                            width: parent.width - 20
                            height: 2
                            radius: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            color: Theme.Theme.accent
                            opacity: root.page === tab.modelData.key ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                        }
                    }
                    contentItem: Label { text: tab.modelData.label; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.page = modelData.key
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.Theme.surfaceHover }

        ColumnLayout {
            visible: root.page === "locations"
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Action {
                    text: "󰒟  Fastest"
                    enabled: !root.vpn.busy
                    onClicked: root.vpn.connectTarget({ type: "fastest", value: "", label: "Fastest server" })
                }
                Action {
                    text: "  Random"
                    enabled: !root.vpn.busy
                    onClicked: root.vpn.connectTarget({ type: "random", value: "", label: "Random server" })
                }
                TextField {
                    id: serverId
                    Layout.fillWidth: true
                    implicitHeight: 34
                    placeholderText: "Server ID, e.g. AT#113"
                    color: Theme.Theme.textPrimary
                    placeholderTextColor: Theme.Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle { radius: 9; color: Theme.Theme.surfaceRaised; border.width: 1; border.color: serverId.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover }
                    onAccepted: serverConnect.clicked()
                }
                Action {
                    id: serverConnect
                    text: "Connect"
                    enabled: !root.vpn.busy && serverId.text.trim().length > 0
                    onClicked: {
                        const id = serverId.text.trim().toUpperCase()
                        root.vpn.connectTarget({ type: "server", value: id, label: id })
                        serverId.text = ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    text: "Countries"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                TextField {
                    Layout.preferredWidth: 190
                    implicitHeight: 32
                    placeholderText: "Search"
                    text: root.query
                    onTextChanged: root.query = text
                    color: Theme.Theme.textPrimary
                    placeholderTextColor: Theme.Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle { radius: 9; color: Theme.Theme.surfaceRaised; border.width: 1; border.color: activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover }
                }
            }

            ListView {
                id: locationList
                Layout.fillWidth: true
                readonly property real resultsHeight: Math.max(56, count * 52 - 4)
                Layout.preferredHeight: Math.min(resultsHeight, 270, root.maximumHeight - 260)
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 300 : 0; easing.type: Easing.OutCubic }
                }
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredLocations()
                ScrollBar.vertical: ScrollBar {}
                add: Transition {
                    NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: Config.ShellConfig.animationsEnabled ? 180 : 0; easing.type: Easing.OutBack }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: Config.ShellConfig.animationsEnabled ? 260 : 0; easing.type: Easing.OutCubic }
                }
                delegate: Button {
                    id: locationButton
                    required property var modelData
                    width: locationList.width
                    height: 48
                    enabled: !root.vpn.busy
                    background: Rectangle {
                        radius: 10
                        color: locationButton.hovered || locationButton.activeFocus ? Theme.Theme.surfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Config.ShellConfig.animationsEnabled ? 120 : 0 } }
                    }
                    contentItem: RowLayout {
                        spacing: 10
                        Label {
                            text: root.flag(locationButton.modelData.code)
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 18
                            Layout.leftMargin: 8
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: locationButton.modelData.name; Layout.fillWidth: true }
                            Label {
                                visible: root.selectedCountry === locationButton.modelData.code
                                text: "Exact server, e.g. " + locationButton.modelData.code + "#113"
                                color: Theme.Theme.textMuted
                                font.pixelSize: 10
                            }
                        }
                        Label { text: locationButton.modelData.code; color: Theme.Theme.textSecondary }
                        Button {
                            id: citiesButton
                            text: root.selectedCountry === locationButton.modelData.code ? "Close" : "Options ›"
                            implicitWidth: 88
                            implicitHeight: 34
                            background: Rectangle { radius: 9; color: citiesButton.hovered ? Theme.Theme.surfaceHover : Theme.Theme.surfaceRaised }
                            contentItem: Label { text: citiesButton.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: {
                                root.selectedCountry = root.selectedCountry === locationButton.modelData.code ? "" : locationButton.modelData.code
                                root.selectedCountryName = root.selectedCountry ? locationButton.modelData.name : ""
                                countryServerId.text = ""
                            }
                        }
                    }
                    onClicked: root.vpn.connectTarget({ type: "country", value: modelData.code, label: modelData.name })
                }
                Label {
                    anchors.centerIn: parent
                    visible: locationList.count === 0
                    text: root.vpn.loadingLocations ? "Loading locations..." : root.query ? "No matching locations" : "No locations available"
                    color: Theme.Theme.textMuted
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.selectedCountry ? 44 : 0
                opacity: root.selectedCountry ? 1 : 0
                clip: true
                Behavior on Layout.preferredHeight { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 260 : 0; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 160 : 0 } }
                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    TextField {
                        id: countryServerId
                        Layout.fillWidth: true
                        implicitHeight: 34
                        placeholderText: "Exact " + root.selectedCountry + " server, e.g. " + root.selectedCountry + "#113"
                        color: Theme.Theme.textPrimary
                        placeholderTextColor: Theme.Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        leftPadding: 12
                        rightPadding: 12
                        background: Rectangle { radius: 9; color: Theme.Theme.surfaceRaised; border.width: 1; border.color: countryServerId.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover }
                        onAccepted: countryServerConnect.clicked()
                    }
                    Action {
                        id: countryServerConnect
                        text: "Connect"
                        enabled: countryServerId.text.trim() !== "" && countryServerId.text.trim().toUpperCase().startsWith(root.selectedCountry + "#")
                        onClicked: {
                            const id = countryServerId.text.trim().toUpperCase()
                            root.vpn.connectTarget({ type: "server", value: id, label: id })
                            countryServerId.text = ""
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: root.page === "settings"
            Layout.fillWidth: true
            spacing: 4

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Button {
                    id: netshieldButton
                    Layout.fillWidth: true
                    implicitHeight: 58
                    enabled: !root.vpn.busy
                    background: Rectangle { radius: 10; color: netshieldButton.hovered || root.expandedSetting === "netshield" ? Theme.Theme.surfaceHover : "transparent" }
                    contentItem: RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label { text: "NetShield" }
                            Label { text: "Choose what Proton DNS should block"; color: Theme.Theme.textMuted; font.pixelSize: 10 }
                        }
                        Label { text: (root.vpn.settings.netshield || "off").replace(/-/g, " "); color: Theme.Theme.accent }
                        Label { text: root.expandedSetting === "netshield" ? "⌃" : "⌄"; color: Theme.Theme.textMuted; Layout.rightMargin: 8 }
                    }
                    onClicked: root.expandedSetting = root.expandedSetting === "netshield" ? "" : "netshield"
                }
                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.preferredHeight: root.expandedSetting === "netshield" ? 112 : 0
                    opacity: root.expandedSetting === "netshield" ? 1 : 0
                    clip: true
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 280 : 0; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Theme.Theme.surfaceRaised
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2
                            Repeater {
                                model: [
                                    { value: "off", label: "Off" },
                                    { value: "malware-only", label: "Block malware" },
                                    { value: "malware-ads-trackers", label: "Block malware, ads & trackers" }
                                ]
                                Button {
                                    id: netshieldOption
                                    required property var modelData
                                    readonly property bool selected: (root.vpn.settings.netshield || "off") === modelData.value
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    background: Rectangle { radius: 7; color: netshieldOption.hovered ? Theme.Theme.surfaceHover : "transparent" }
                                    contentItem: RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 10
                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: "transparent"
                                            border.width: 1
                                            border.color: netshieldOption.selected ? Theme.Theme.accent : Theme.Theme.textMuted
                                            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.Theme.accent; scale: netshieldOption.selected ? 1 : 0; Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } } }
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            text: netshieldOption.modelData.label
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    onClicked: root.vpn.setSetting("netshield", modelData.value)
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: [
                    { key: "kill-switch", title: "Kill switch", description: "Block traffic if the VPN connection drops" },
                    { key: "vpn-accelerator", title: "VPN Accelerator", description: "Improve long-distance connection speed" },
                    { key: "port-forwarding", title: "Port forwarding", description: "Request a port on supported P2P servers" },
                    { key: "moderate-nat", title: "Moderate NAT", description: "Improve gaming and peer connectivity" },
                    { key: "ipv6", title: "IPv6", description: "Route IPv6 traffic through the tunnel" }
                ]
                Item {
                    id: settingRow
                    required property var modelData
                    readonly property bool enabledValue: (root.vpn.settings[modelData.key] || "off") !== "off"
                    Layout.fillWidth: true
                    implicitHeight: 58
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label { text: settingRow.modelData.title }
                            Label { text: settingRow.modelData.description; color: Theme.Theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                        }
                        Toggle {
                            checkedValue: settingRow.enabledValue
                            enabled: !root.vpn.busy
                            onClicked: root.vpn.setSetting(settingRow.modelData.key, settingRow.enabledValue ? "off" : (settingRow.modelData.key === "kill-switch" ? "standard" : "on"))
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.Theme.surfaceHover }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label { text: "Connect on login" }
                            Label { text: "Default: " + root.vpn.savedTargetLabel; color: Theme.Theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                        }
                        Action { text: "Choose"; onClicked: root.autoTargetExpanded = !root.autoTargetExpanded }
                        Toggle { checkedValue: root.vpn.autoConnect; onClicked: root.vpn.autoConnect = !root.vpn.autoConnect }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.autoTargetExpanded ? (root.autoTargetMode === "fastest" ? 40 : 82) : 0
                    opacity: root.autoTargetExpanded ? 1 : 0
                    clip: true
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 280 : 0; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [{ key: "fastest", label: "Fastest" }, { key: "country", label: "Country ID" }, { key: "server", label: "Exact server ID" }]
                                Button {
                                    id: targetMode
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    background: Rectangle {
                                        radius: 8
                                        color: root.autoTargetMode === targetMode.modelData.key ? Theme.Theme.surfaceHover : "transparent"
                                        border.width: root.autoTargetMode === targetMode.modelData.key ? 1 : 0
                                        border.color: Theme.Theme.accent
                                    }
                                    contentItem: Label { text: targetMode.modelData.label; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: root.autoTargetMode === targetMode.modelData.key ? Theme.Theme.accent : Theme.Theme.textSecondary }
                                    onClicked: {
                                        root.autoTargetMode = modelData.key
                                        if (modelData.key === "fastest") {
                                            root.vpn.savedTargetType = "fastest"
                                            root.vpn.savedTargetValue = ""
                                            root.vpn.savedTargetLabel = "Fastest server"
                                        }
                                    }
                                }
                            }
                        }
                        TextField {
                            id: defaultTargetId
                            Layout.fillWidth: true
                            implicitHeight: 34
                            visible: root.autoTargetMode !== "fastest"
                            placeholderText: root.autoTargetMode === "country" ? "Country ID, e.g. AT" : "Exact server ID, e.g. AT#113"
                            text: root.autoTargetMode === root.vpn.savedTargetType ? root.vpn.savedTargetValue : ""
                            color: Theme.Theme.textPrimary
                            placeholderTextColor: Theme.Theme.textMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            leftPadding: 12
                            rightPadding: 12
                            background: Rectangle { radius: 9; color: Theme.Theme.surfaceRaised; border.width: 1; border.color: defaultTargetId.activeFocus ? Theme.Theme.accent : Theme.Theme.surfaceHover }
                            onEditingFinished: {
                                const value = text.trim().toUpperCase()
                                if (!value) return
                                root.vpn.savedTargetType = root.autoTargetMode
                                root.vpn.savedTargetValue = value
                                root.vpn.savedTargetLabel = value
                            }
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.vpn.error || root.vpn.message
            color: root.vpn.error ? Theme.Theme.danger : Theme.Theme.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font.pixelSize: 11
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0 } }
        }

    }
}
