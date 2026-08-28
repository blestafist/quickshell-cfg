#!/usr/bin/env sh

set -eu

case "${1:-}" in
    resources)
        awk '
            /^cpu / { idle = $5; total = 0; for (i = 2; i <= NF; i++) total += $i }
            END { print idle, total }
        ' /proc/stat > /tmp/quickshell-cpu-before-$$
        sleep 0.15
        cpu=$(awk '
            NR == FNR { old_idle = $1; old_total = $2; next }
            /^cpu / {
                idle = $5; total = 0; for (i = 2; i <= NF; i++) total += $i
                usage = (total - old_total - (idle - old_idle)) * 100 / (total - old_total)
                printf "%d\n", usage
            }
        ' /tmp/quickshell-cpu-before-$$ /proc/stat)
        rm -f /tmp/quickshell-cpu-before-$$
        memory=$(awk '/MemTotal:/ { total = $2 } /MemAvailable:/ { available = $2 } END { printf "%d|%.1f GB", (total - available) * 100 / total, (total - available) / 1048576 }' /proc/meminfo)
        gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)
        printf '%s|%s|%s\n' "${cpu:-0}" "${memory:-0|0.0 GB}" "${gpu:-N/A}"
        ;;
    network)
        wifi=$(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1 == "*" { printf "%s|%s", $2, $3; exit }')
        if [ -n "$wifi" ]; then
            printf '%s\n' "$wifi"
        elif nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^ethernet:connected'; then
            printf '%s\n' 'Ethernet|100'
        else
            printf '%s\n' 'Offline|0'
        fi
        ;;
    audio)
        wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ muted = ($3 == "[MUTED]"); printf "%d|%d\n", $2 * 100, muted }' || printf '%s\n' '0|1'
        ;;
    layout)
        hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n1
        ;;
    *)
        printf '%s\n' "Usage: $(basename "$0") {resources|network|audio|layout}" >&2
        exit 2
        ;;
esac
