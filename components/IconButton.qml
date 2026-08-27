import QtQuick

import "../theme" as Theme

Rectangle {
    id: root

    property string icon: ""
    property string tooltip: ""
    signal clicked()
    signal rightClicked()

    implicitWidth: 32
    implicitHeight: 30
    radius: Theme.Theme.radiusSmall
    color: mouseArea.containsMouse ? Theme.Theme.surfaceHover : "transparent"

    Text {
        anchors.fill: parent
        text: root.icon
        color: Theme.Theme.textPrimary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 17
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }
    }
}
