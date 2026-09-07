import QtQuick
import Quickshell
import Quickshell.Io

import "modules/bar" as Bar
import "modules/launcher" as Launcher
import "modules/power" as Power
import "services" as Services

ShellRoot {
    id: root

    Services.SystemStats { id: stats }
    Services.Applications { id: applications }
    Launcher.Launcher { id: launcher; applications: applications.applications }
    Bar.Bar { stats: stats; launcher: launcher; powerOverlay: powerOverlay }
    Power.PowerOverlay { id: powerOverlay }

    IpcHandler {
        target: "shell"
        function openLauncher() { launcher.open() }
        function closeLauncher() { launcher.close() }
        function toggleLauncher() { launcher.toggle() }
        function reload() { Quickshell.reload(false) }
    }
}
