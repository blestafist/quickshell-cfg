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

for command in awww matugen python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command is missing: %s\n' "$command" >&2
        exit 1
    fi
done

awww img "$wallpaper" --transition-type grow --transition-pos top \
    --transition-duration 1.8 --transition-fps 180 \
    --transition-bezier 0.22,0.8,0.2,1
matugen image "$wallpaper" -m dark --source-color-index 0

# The running shell watches the atomic palette file; no restart or QML rewrite.
python3 -B "$config_dir/scripts/theme.py" "$wallpaper"
