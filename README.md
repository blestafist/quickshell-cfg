# QuickShell for niri

Runnable shell described in `PLAN.md`, with an independent Quickshell session locker (`lock.qml`, widgets under `lockscreen/`). Locking uses Wayland ext-session-lock-v1 and PAM, not the decorative power overlay. See [locker validation and limitations](docs/lockscreen.md) before the first live use.

## What Is Implemented

- Matte status bar on `DP-1` only. `HDMI-A-1` has no panel.
- NixOS button: left click opens the launcher; right click unfolds the wallpaper picker over the entire bar.
- Clock beside the launcher icon; centered MPRIS music presence; CPU, RAM, NVIDIA GPU fallback, NetworkManager connection name, PipeWire volume, keyboard layout, and power placeholder on the right.
- Bottom-sheet launcher, restricted to `DP-1`, opened over a dimmed primary display.
- Launcher IPC, XDG desktop-entry index, text search, `Escape` close, arrow-key navigation, `Enter` execution, and actions for terminal, lock screen, and shell reload.
- Launcher favorites: right-click a result or press `Ctrl+P` to toggle its pin. Pinned results appear first and persist across restarts in QuickShell's state directory (`launcher-pins.json`).
- Central runtime configuration in `config/ShellConfig.qml`, monitor configuration in `config/MachineConfig.qml`, and semantic colors in `theme/Theme.qml`.

Desktop entries are read from `$XDG_DATA_HOME/applications` and each `$XDG_DATA_DIRS/applications` directory. `Hidden=true`, `NoDisplay=true`, invalid, and non-application entries are excluded. User entries take precedence over identically named system desktop files. Applications launch through `gio launch`, which honors their desktop-file `Exec` and `Terminal` handling.

## Requirements

Required at runtime:

```text
quickshell 0.3.1
niri
python3                        # status scripts and wallpaper library/cache helper
wpctl (WirePlumber/PipeWire)
nmcli (NetworkManager)
bash, flock, timeout, realpath  # lockctl
systemctl                      # guarded suspend
/etc/pam.d/hyprlock             # PAM service supplied by hyprlock
```

Recommended or optional:

```text
JetBrainsMono Nerd Font
Noto Sans          # wallpaper picker labels
nvidia-smi         # NVIDIA GPU utilization
awww               # wallpaper picker (start awww-daemon in the graphical session)
magick             # ImageMagick; required for wallpaper previews
ffmpeg             # optional fallback decoder for wallpaper previews
matugen            # wallpaper-derived Material 3 shell palette
```

Check the local environment:

```sh
~/.config/quickshell/scripts/shellctl diagnostics
```

## Run And Control

Start from an existing graphical niri session:

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

## niri Integration

The active compositor configuration is `~/.config/niri/config.kdl`:

- Startup runs `scripts/shellctl start`, avoiding duplicate shell instances.
- `Super+R`: launcher; `Super+C`: clipboard; `Super+X`: calculator.
- `Super+S`: power menu; `Super+Alt+L`: independent QuickShell locker.
- Niri's center-column action is on `Super+Alt+C`; directional navigation is unchanged.

Keyboard state comes from `niri msg -j keyboard-layouts`, with event-stream
updates and a three-second polling fallback. Clicking the layout indicator runs
`niri msg action switch-layout next`. Configure available layouts in niri's
`input.keyboard.xkb` section; a single configured layout cannot cycle to another.
The power menu's logout action exits niri.

The locker continues to use `/etc/pam.d/hyprlock`; that PAM service is independent
of the compositor. Keep the package installed. Migration does not verify live
locking, authentication, or suspend; see the lockscreen smoke checklist before use.

Validate with `niri validate` and `scripts/shellctl diagnostics`. Use
`niri msg outputs` to check connector names and `niri msg layers` to check the bar.

## Historical Hyprland Integration

The following instructions describe the previous setup, not the active backend.

### Clipboard Island

`Super+C` toggles the horizontal clipboard history in the central island. Scroll
with the mouse wheel or trackpad, or select with Left/Right. Click or Enter copies
the original item back to the clipboard without pasting; Escape closes the island.
Only content cards are shown, with text and image previews. Image previews are
decoded lazily by cliphist into the same private runtime directory.

Requires `cliphist` and `wl-clipboard` (`sudo pacman -S cliphist wl-clipboard`).
QuickShell runs `wl-paste --watch cliphist store`; storage and byte-exact decoding
are handled by cliphist, not by a custom clipboard backend. The private database
is `$XDG_RUNTIME_DIR/quickshell-clipboard/db`, so history survives shell reloads
but is removed at reboot or when the user runtime directory is removed at logout.
Capture starts when QuickShell is running; earlier clipboard contents cannot be
recovered. History is not restricted to cliphist's default 750 items.

```lua
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs -p /home/pestit/.config/quickshell ipc call clipboard toggle"))
```

### Shell Startup

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
6. Keep `hyprlock` installed: the locker uses its system PAM service, and it remains an alternative before acquiring a custom lock.

### Lockscreen Status

The broken prototype has been replaced. `lockctl` starts an independent, non-auto-reloading locker and waits for its read-only IPC status to report compositor acknowledgement. The locker remains resident without windows after successful PAM authentication, allowing the Wayland unlock request to flush without a process-exit race. There is no unlock IPC.

```sh
~/.config/quickshell/scripts/lockctl lock
# Only suspends after compositor acknowledgement and a second in-process check:
~/.config/quickshell/scripts/lockctl lock-and-suspend
# Read-only; does not start a locker:
~/.config/quickshell/scripts/lockctl status
```

After the isolated smoke checklist in [docs/lockscreen.md](docs/lockscreen.md), the optional Hyprland binding is:

```lua
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/quickshell/scripts/lockctl lock"))
```

Launcher and shell power-menu lock/suspend actions use `lockctl`. External Hyprland configuration was not changed. This does not protect suspend initiated elsewhere, including lid events, idle daemons, or direct `systemctl suspend`. No real-session lock, PAM authentication, or suspend has been runtime-verified by the non-live tests.

`Super+S` may still invoke `wlogout` through the existing external binding; its actions are outside this integration.

## Smoke Test

1. Confirm `qs list` shows exactly one matching instance and `pgrep -a waybar` is empty after migration.
2. Verify the panel is visible on `DP-1` and absent on the vertically rotated `HDMI-A-1`.
3. Press `Super+R`, type `term`, press `Enter`, then reopen and close it with `Escape`.
4. Change keyboard layout and check the bar within three seconds.
5. Disconnect and reconnect a network; check the connection label.
6. Change volume with media keys; check the volume value.
7. Run `shellctl reload`; the bar must return without restarting niri.
8. On an NVIDIA system, check that utilization is shown; otherwise `N/A` is expected and non-fatal.

## Configuration

`config/MachineConfig.qml` contains output names. Change it only if `niri msg outputs` reports different names.

`config/ShellConfig.qml` contains bar geometry, launcher dimensions, clock format, animations flag, and application command strings. This is the user-facing configuration surface for the current release.

`theme/Theme.qml` defines semantic colors backed by the live Matugen palette, with a built-in fallback. Components must use these names, not raw colors.

## Wallpaper Picker

Right-click the NixOS logo in the left island. The island spreads across the
entire top edge and unfolds into a single shelf, covering every part of the bar
without changing its reserved space or moving application windows. The slanted
filmstrip supports mouse-wheel scrolling, trackpad scrolling, dragging, arrow
keys, Home/End, and search (`Ctrl+F`). Click a side card to focus it, then click
the focused card or press Enter to apply. The NixOS logo morphs into a minimal
close icon above the shelf and stays clickable throughout opening and closing.
The logo stays icon-only, with no background, outline, or hover decoration.
The clock and divider fade back above the collapsing shelf before it disappears.
Left-clicking the close icon dismisses the picker; once it turns back into the
NixOS logo, left-click always opens the launcher, even while the shelf is still
collapsing. Right-click toggles the picker independently of its animation.
The shuffle button beside the navigation arrows selects another random wallpaper
from the current search results without applying it; confirm with Apply or Enter.
Escape, the close icon, right-clicking the shelf, or a click outside it dismisses
the picker. Opening/closing can reverse immediately; the droplet can also be interrupted.
Closing cancels a not-yet-submitted choice, but does not cancel an awww command
that has already started. Its late result cannot reopen the dismissed picker
or close a newly opened one. `Ctrl+R` refreshes the library.
The minimal Material 3 controls sit below the filmstrip: navigation, search,
and Apply. Labels are English; search and Apply have matching 56px pill heights.
There is no header or fullscreen image overlay.

Configure in `config/ShellConfig.qml`:

```qml
readonly property string wallpaperDirectory: "" // ~/Pictures/Wallpaper
readonly property bool wallpaperRecursive: true
readonly property int wallpaperPanelHeight: 392
readonly property real wallpaperTransitionDuration: 1.8
readonly property int wallpaperTransitionFps: 180
readonly property int wallpaperCacheLimitMiB: 128
readonly property bool wallpaperThemeEnabled: true
readonly property string wallpaperThemeMode: "dark"
readonly property string wallpaperThemeScheme: "scheme-tonal-spot"
```

This machine explicitly uses `~/.config/wallpaper`, its existing collection.
Set the directory to `"~/Pictures/Wallpaper"`, another path, or `""` for the
standard default. Missing/empty directories and backend errors appear in the
picker. Hidden files and hidden subdirectories are excluded. PNG, JPEG, WebP,
GIF, BMP, TIFF, AVIF, PNM, and TGA are indexed; support for the originals depends
on ImageMagick/ffmpeg and awww. Only the first frame is used for animated previews.

Requires `python3`, ImageMagick (`magick`), `awww`, a running `awww-daemon`,
and Qt >= 6.8. `ffmpeg` is an optional independent fallback decoder. No Pillow,
thumbnail daemon, generated shaders, or network access is needed.

Previews are persistent JPEGs no larger than 768×480 in
`${XDG_CACHE_HOME:-~/.cache}/quickshell/wallpapers/v2-768x480`. Cache identity
includes the original path, size, and modification time. The default disk
budget is 128 MiB, with older previews pruned first. Generation runs at low
priority with at most two workers and small batches; visible cards and their
neighbours take precedence over background warming of the first 128 entries.
ImageMagick's separate temporary pixel-cache disk limit is 1 GiB per worker;
this is not a RAM allocation or the persistent preview-cache budget.

Only a bounded ring of carousel delegates is created. Moving the window by one
recycles one image source, retaining the other textures. Small previews decode
asynchronously without Qt's shared image cache or per-card offscreen layers.
QuickShell never decodes original wallpapers, even for the selection animation.
Opening/closing springs preserve momentum on reversal and behave identically
at different refresh rates. `animationsEnabled: false` disables the morph,
filmstrip motion, droplet, and awww transition.

The selected photograph straightens, narrows into a droplet, and drains upward
from its exact screen-space rectangle over 640 ms. awww's `grow` reveal starts
at the top edge below the droplet, with its Y coordinate converted to awww's
bottom-origin convention. By default the
wallpaper changes on **all outputs**. On errors the shelf returns with the
selection intact; it never reports success based only on an animation. Changes
are serialized across instances. awww manages its own wallpaper persistence.
The palette is generated after a confirmed change without restarting the bar
or invoking Waypaper hooks. Slowing awww to 1.8 seconds does not slow down the
shelf or its 640ms droplet.

```sh
qs -p ~/.config/quickshell ipc call wallpaper toggle
qs -p ~/.config/quickshell ipc call wallpaper close
qs -p ~/.config/quickshell ipc call wallpaper refresh
qs -p ~/.config/quickshell ipc call wallpaper status
```

### Wallpaper-Derived Material 3 Theme

Matugen extracts a deterministic source color from the small cached preview
using `scheme-tonal-spot`. Its Material 3 roles drive surfaces, text, accents,
and error colors throughout QuickShell. Color changes blend over 400 ms
(immediate with reduced motion). The palette is saved atomically to
`${XDG_STATE_HOME:-~/.local/state}/quickshell/theme.json` and restored on startup.
Unchanged wallpapers reuse that palette; missing Matugen, invalid output, or
generation failures keep the previous valid theme. Selecting a wallpaper still
works when theme generation fails.

Automatic generation uses Matugen's `--dry-run --json hex` mode: no application
hooks, external templates, compositor settings, or QML files are changed. The
existing `~/.config/matugen` configuration is left untouched. Use `"light"` for
`wallpaperThemeMode`, another Matugen scheme for `wallpaperThemeScheme`, or
disable `wallpaperThemeEnabled` to retain the built-in fallback palette.

```sh
qs -p ~/.config/quickshell ipc call theme status
qs -p ~/.config/quickshell ipc call theme refresh
# Palette only; does not change the wallpaper or render application templates:
python3 -B ~/.config/quickshell/scripts/theme.py /absolute/path/to/wallpaper.png
```

### Separate Application Theme Update

To also regenerate the existing Matugen application templates, use:

```sh
~/.config/quickshell/scripts/update-theme.sh /absolute/path/to/wallpaper.png
```

The script validates dependencies, sets the wallpaper through awww, runs
`matugen image ... -m dark --source-color-index 0`, and writes the live shell
palette. QuickShell watches the palette file and does not restart. Application
templates/hooks run only through this explicit command, not through the picker.

## Troubleshooting

- `shellctl open` cannot connect: start the shell with `shellctl start` or `qs -p ~/.config/quickshell` from the graphical session.
- Bar is missing: run `niri msg outputs` and compare the exact connector name with `MachineConfig.qml`.
- All values show fallback data: ensure `wpctl`, `nmcli`, and `niri msg keyboard-layouts` work in the niri user session; run `shellctl diagnostics`.
- Keyboard layout is `--`: check `niri msg -j keyboard-layouts` and the Quickshell logs. The bar parses JSON directly without `jq`.
- Launcher opens but cannot execute a command: adjust the command in `ShellConfig.qml`; verify it in a terminal first.
- Wallpaper previews remain empty: check `magick` with `shellctl diagnostics`; `ffmpeg` provides a fallback for failed decodes. Press `Ctrl+R` in the picker to retry failures and refresh the cache index. The footer shows the affected filename and decoder error.
- Need logs: run `qs log` while the shell instance is running.
