import QtQuick
import QtQuick.Controls

import "../../config" as Config
import "../../theme" as Theme

Button {
    id: root

    property bool closeMode: false
    property real morph: closeMode ? 1 : 0
    property real iconOffsetX: -3
    property real iconOffsetY: 0
    signal rightClicked()

    implicitWidth: 42
    implicitHeight: 34
    padding: 0
    activeFocusOnTab: true
    hoverEnabled: false
    Accessible.name: closeMode ? "Close wallpaper picker" : "Open launcher"
    Accessible.description: closeMode ? "Close immediately, including during animations" : "Right-click to choose a wallpaper"

    Behavior on morph {
        NumberAnimation { duration: Config.ShellConfig.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic }
    }

    background: null
    contentItem: Item {
        Text {
            anchors.fill: parent
            text: ""
            color: Theme.Theme.textPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 1 - root.morph
            rotation: -45 * root.morph
            transform: Translate { x: root.iconOffsetX; y: root.iconOffsetY }
        }
        Item {
            anchors.centerIn: parent
            width: 18; height: 18
            opacity: root.morph
            rotation: 45 * (1 - root.morph)
            Rectangle { anchors.centerIn: parent; width: 16; height: 1.5; radius: 0.75; rotation: 45; color: Theme.Theme.textPrimary }
            Rectangle { anchors.centerIn: parent; width: 16; height: 1.5; radius: 0.75; rotation: -45; color: Theme.Theme.textPrimary }
        }
    }
    // A normal click, not a distance-limited tap: small pointer movement inside
    // the button must not cancel RMB or pass it to the shelf underneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.rightClicked()
    }
}
