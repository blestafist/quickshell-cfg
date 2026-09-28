pragma Singleton

import QtQuick

QtObject {
    readonly property string pamService: "hyprlock"
    readonly property int retryDelayMs: 1400
    readonly property int maxSecretLength: 512
    readonly property bool animationsEnabled: true
}
