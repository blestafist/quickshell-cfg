#!/bin/sh
set -eu

# cliphist owns storage and decoding; keep its database out of persistent cache.
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
umask 077
directory="$XDG_RUNTIME_DIR/quickshell-clipboard"
mkdir -p "$directory"
export CLIPHIST_DB_PATH="$directory/db"
export CLIPHIST_CONFIG_PATH=/dev/null
export CLIPHIST_MAX_ITEMS=2147483647
export CLIPHIST_PREVIEW_WIDTH=400

case "${1:-}" in
    watch)
        exec wl-paste --watch cliphist store
        ;;
    list)
        command -v cliphist >/dev/null
        [ -f "$CLIPHIST_DB_PATH" ] || exit 0
        exec cliphist list
        ;;
    copy)
        case "${2:-}" in ''|*[!0-9]*) exit 2 ;; esac
        temporary=$(mktemp "$directory/copy.XXXXXX")
        trap 'rm -f "$temporary"' EXIT HUP INT TERM
        # Decode first: a failed lookup must not clear the current clipboard.
        cliphist decode "$2" > "$temporary"
        wl-copy < "$temporary"
        ;;
    preview)
        case "${2:-}" in ''|*[!0-9]*) exit 2 ;; esac
        mkdir -p "$directory/previews"
        preview="$directory/previews/$2"
        if [ ! -f "$preview" ]; then
            temporary=$(mktemp "$directory/previews/.XXXXXX")
            trap 'rm -f "$temporary"' EXIT HUP INT TERM
            cliphist decode "$2" > "$temporary"
            mv "$temporary" "$preview"
        fi
        printf 'file://%s\n' "$preview"
        ;;
    *) exit 2 ;;
esac
