#!/usr/bin/env sh

set -eu

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

if [ "$#" -ne 1 ]; then
    printf '%s\n' "Usage: $(basename "$0") /absolute/path/to/wallpaper" >&2
    exit 2
fi

wallpaper=$1

if [ ! -f "$wallpaper" ]; then
    printf 'Wallpaper does not exist: %s\n' "$wallpaper" >&2
    exit 2
fi

for command in swww matugen qs; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command is missing: %s\n' "$command" >&2
        exit 1
    fi
done

swww img "$wallpaper"
matugen image "$wallpaper" -m dark

# Theme.qml remains a reliable fallback until a Matugen QML template is enabled.
qs -p "$config_dir" ipc call shell reload
