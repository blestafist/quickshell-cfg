# QuickShell for Hyprland

Initial, runnable version of the shell described in `PLAN.md`. It intentionally replaces only the permanent Waybar panel and the application-launcher hotkey first. `hyprlock` remains the lock screen. Rofi, Wlogout, and their Hyprland rules must stay in place until the smoke test is successful.

## What Is Implemented

- Matte status bar on `DP-1` only. `HDMI-A-1` has no panel.
- EndeavourOS button: left click opens the launcher; right click shows the future-configurator notice.
- Centered clock; CPU, RAM, NVIDIA GPU fallback, NetworkManager connection name, PipeWire volume, keyboard layout, and power placeholder on the right.
- Bottom-sheet launcher, restricted to `DP-1`, opened over a dimmed primary display.
- Launcher IPC, XDG desktop-entry index, text search, `Escape` close, arrow-key navigation, `Enter` execution, and actions for terminal, lock screen, and shell reload.
- Central runtime configuration in `config/ShellConfig.qml`, monitor configuration in `config/MachineConfig.qml`, and semantic colors in `theme/Theme.qml`.

Desktop entries are read from `$XDG_DATA_HOME/applications` and each `$XDG_DATA_DIRS/applications` directory. `Hidden=true`, `NoDisplay=true`, invalid, and non-application entries are excluded. User entries take precedence over identically named system desktop files. Applications launch through `gio launch`, which honors their desktop-file `Exec` and `Terminal` handling.

## Requirements

Required at runtime:

```text
quickshell 0.3.1
hyprland 0.56.2
wpctl (WirePlumber/PipeWire)
nmcli (NetworkManager)
```

Recommended or optional:

```text
JetBrainsMono Nerd Font
jq                 # more accurate keyboard layout parsing
nvidia-smi         # NVIDIA GPU utilization
swww and matugen   # wallpaper and palette workflow
```

Check the local environment:

```sh
~/.config/quickshell/scripts/shellctl diagnostics
```

## Run And Control

Start without changing Hyprland first, from an existing graphical Hyprland session:

```sh
qs -p ~/.config/quickshell
```

Run it in the background after the initial test:

```sh
~/.config/quickshell/scripts/shellctl start
```

Control the active instance:

```sh
~/.config/quickshell/scripts/shellctl open
~/.config/quickshell/scripts/shellctl toggle
~/.config/quickshell/scripts/shellctl close
~/.config/quickshell/scripts/shellctl reload
```

`qs -p ~/.config/quickshell` is deliberate. This directory contains `shell.qml`, so QuickShell registers it as the default configuration. Supplying the path makes scripts independent of a changed `XDG_CONFIG_HOME`.

## Hyprland Integration

This machine uses `~/.config/hypr/hyprland.lua`, generated with `hyprlang2lua`; edit it as Lua rather than adding a second `hyprland.conf`.

After manually starting QuickShell and confirming the bar appears only on `DP-1`, make these three edits.

1. Replace the launcher command near the program variables:

```lua
local menu = "~/.config/quickshell/scripts/shellctl toggle"
```

2. Keep the current binding and it will now call the native launcher:

```lua
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
```

3. Replace Waybar in `hl.on("hyprland.start", ...)`:

```lua
hl.exec_cmd("~/.config/quickshell/scripts/shellctl start")
hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
```

Do not keep `waybar` in the same `exec_cmd`: two bars reserve or overlap the same usable area. Do not add `quickshell` more than once, as the startup script uses `qs -n` to avoid duplicate processes.

Reload the Lua configuration through the normal Hyprland reload flow, then either log out and in or start the shell explicitly once with `shellctl start`.

## Safe Migration From Waybar And Rofi

1. Start QuickShell manually and run the smoke test below.
2. Change the `menu` variable and startup command as shown above.
3. Reload Hyprland; stop the old Waybar process only after confirming QuickShell is visible.
4. Preserve both `namespace = "rofi"` and `namespace = "waybar"` layer rules during the first login using QuickShell.
5. After a clean login with the new shell, remove the old Rofi and Waybar layer rules from `hyprland.lua` if those programs are no longer used.
6. Keep `hyprlock`; the shell calls it but never implements locking itself.

`Super+S` continues to invoke `wlogout` for now. The button and a confirmed QuickShell power menu are intentionally deferred, so removing Wlogout at this point would remove a working session action.

## Smoke Test

1. Confirm `qs list` shows exactly one matching instance and `pgrep -a waybar` is empty after migration.
2. Verify the panel is visible on `DP-1` and absent on the vertically rotated `HDMI-A-1`.
3. Press `Super+R`, type `term`, press `Enter`, then reopen and close it with `Escape`.
4. Change keyboard layout and check the bar within three seconds.
5. Disconnect and reconnect a network; check the connection label.
6. Change volume with media keys; check the volume value.
7. Run `shellctl reload`; the bar must return without restarting Hyprland.
8. On an NVIDIA system, check that utilization is shown; otherwise `N/A` is expected and non-fatal.

## Configuration

`config/MachineConfig.qml` contains output names. Change it only if `hyprctl monitors` reports different names.

`config/ShellConfig.qml` contains bar geometry, launcher dimensions, clock format, animations flag, and application command strings. This is the user-facing configuration surface for the current release.

`theme/Theme.qml` defines semantic colors. Components must use these names, not raw colors, so generated Matugen themes can replace the fallback palette later.

## Wallpaper And Theme

The installed system currently has `matugen`, but `swww` is not installed. When both are available and the swww daemon is running, use:

```sh
~/.config/quickshell/scripts/update-theme.sh /absolute/path/to/wallpaper.png
```

The script validates dependencies, sets the wallpaper, runs `matugen image ... -m dark`, then reloads QuickShell. At this initial stage, Matugen continues generating the existing formats while `theme/Theme.qml` remains the QML fallback. A dedicated `Colors.qml` Matugen template and generated Hyprland border colors should be introduced together in the next theme increment, so no partially generated theme is ever loaded.

## Troubleshooting

- `shellctl open` cannot connect: start the shell with `shellctl start` or `qs -p ~/.config/quickshell` from the graphical session.
- Bar is missing: run `hyprctl monitors` and compare the exact connector name with `MachineConfig.qml`.
- All values show fallback data: ensure `wpctl`, `nmcli`, and `hyprctl` work in the Hyprland user session; run `shellctl diagnostics`.
- Keyboard layout is `--`: install `jq`, or use the displayed fallback while the service is extended.
- Launcher opens but cannot execute a command: adjust the command in `ShellConfig.qml`; verify it in a terminal first.
- Need logs: run `qs log` while the shell instance is running.
