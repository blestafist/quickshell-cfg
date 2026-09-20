import QtQuick
import QtQuick.Controls
import Quickshell.Io

import "../../theme" as Theme

FocusScope {
    id: root

    property var history
    signal closeRequested()

    implicitHeight: 192

    function activate() {
        if (!enabled) return
        forceActiveFocus()
        cards.currentIndex = cards.count ? 0 : -1
        cards.positionViewAtBeginning()
    }

    function copyCurrent() {
        if (!history || history.copying || cards.currentIndex < 0) return
        history.copy(history.entries[cards.currentIndex].id)
    }

    Keys.onEscapePressed: closeRequested()
    Keys.onLeftPressed: {
        cards.currentIndex = Math.max(0, cards.currentIndex - 1)
        cards.positionViewAtIndex(cards.currentIndex, ListView.Contain)
    }
    Keys.onRightPressed: {
        cards.currentIndex = Math.min(cards.count - 1, cards.currentIndex + 1)
        cards.positionViewAtIndex(cards.currentIndex, ListView.Contain)
    }
    Keys.onReturnPressed: copyCurrent()
    Keys.onEnterPressed: copyCurrent()

    ListView {
        id: cards
        y: 18
        width: parent.width
        height: 156
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.history ? root.history.entries : []
        onCountChanged: currentIndex = count ? Math.max(0, Math.min(currentIndex, count - 1)) : -1

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AlwaysOff
            height: 6
            contentItem: Rectangle {
                implicitWidth: 30
                implicitHeight: 6
                radius: 3
                color: parent.pressed ? Theme.Theme.accent : Theme.Theme.textMuted
            }
        }

        delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            readonly property bool copied: !!root.history && root.history.copiedId === modelData.id
            readonly property bool binary: /\[\[\s*binary\s+data\b/i.test(modelData.preview)
            property string imageSource: ""

            width: Math.max(1, Math.min(240, cards.width))
            height: 156
            radius: Theme.Theme.radiusMedium
            color: cardMouse.containsMouse ? Theme.Theme.surfaceHover : Theme.Theme.surface
            border.width: card.copied ? 2 : 1
            border.color: cards.currentIndex === index ? Theme.Theme.accent : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: (binary ? "Binary data: " : "Copy: ") + modelData.preview
            Accessible.onPressAction: {
                cards.currentIndex = card.index
                root.copyCurrent()
            }

            Process {
                command: ["sh", root.history.script, "preview", card.modelData.id]
                running: card.binary
                stdout: StdioCollector {
                    onStreamFinished: card.imageSource = text.trim()
                }
            }

            Image {
                id: image
                anchors.fill: parent
                anchors.margins: 8
                source: card.imageSource
                sourceSize.width: 480
                sourceSize.height: 312
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                x: 14
                y: 14
                width: Math.max(0, parent.width - 28)
                height: parent.height - y - 14
                text: card.modelData.preview || "(Empty preview)"
                visible: !card.binary || image.status === Image.Error
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                maximumLineCount: 7
                color: Theme.Theme.textPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.forceActiveFocus()
                    cards.currentIndex = card.index
                    root.copyCurrent()
                }
            }
        }

        // Handle both trackpad axes; ordinary vertical wheels scroll the strip.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const pixels = wheel.pixelDelta
                const angles = wheel.angleDelta
                const delta = pixels.x || pixels.y || (angles.x || angles.y) / 120 * 80
                cards.cancelFlick()
                cards.contentX = Math.max(cards.originX, Math.min(cards.originX + Math.max(0, cards.contentWidth - cards.width), cards.contentX - delta))
                wheel.accepted = true
            }
        }
    }

    Text {
        x: 12
        y: 46
        width: Math.max(0, parent.width - 24)
        height: 100
        visible: cards.count === 0
        text: root.history && root.history.loading ? "..." : root.history && root.history.error ? root.history.error : "Nothing copied yet"
        color: Theme.Theme.textSecondary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }

    ToolTip.visible: !!root.history && !!root.history.error && cards.count > 0
    ToolTip.text: root.history ? root.history.error : ""
}
