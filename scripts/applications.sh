#!/usr/bin/env sh

set -eu

# Emit visible XDG applications as unit-separated records. Gio launches the
# desktop file itself, preserving its Exec and Terminal semantics.
data_dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

old_ifs=$IFS
IFS=:
for data_dir in $data_dirs; do
    applications_dir="$data_dir/applications"
    [ -d "$applications_dir" ] || continue

    for desktop_file in "$applications_dir"/*.desktop; do
        [ -f "$desktop_file" ] || continue
        awk -v path="$desktop_file" '
            BEGIN { in_entry = 0; type = "Application" }
            /^\[Desktop Entry\]$/ { in_entry = 1; next }
            /^\[/ { in_entry = 0 }
            !in_entry { next }
            /^Name=/ && name == "" { sub(/^Name=/, ""); name = $0 }
            /^GenericName=/ && generic == "" { sub(/^GenericName=/, ""); generic = $0 }
            /^Comment=/ && comment == "" { sub(/^Comment=/, ""); comment = $0 }
            /^Keywords=/ && keywords == "" { sub(/^Keywords=/, ""); keywords = $0 }
            /^Exec=/ && exec == "" { sub(/^Exec=/, ""); exec = $0 }
            /^Icon=/ && icon == "" { sub(/^Icon=/, ""); icon = $0 }
            /^Type=/ { sub(/^Type=/, ""); type = $0 }
            /^NoDisplay=true$/ { nodisplay = 1 }
            /^Hidden=true$/ { hidden = 1 }
            /^Terminal=true$/ { terminal = 1 }
            END {
                if (name != "" && exec != "" && type == "Application" && !nodisplay && !hidden) {
                    description = generic != "" ? generic : comment
                    gsub(/[\r\n\034]/, " ", name)
                    gsub(/[\r\n\034]/, " ", description)
                    gsub(/[\r\n\034]/, " ", keywords)
                    gsub(/[\r\n\034]/, " ", icon)
                    printf "%s\034%s\034%s\034%s\034%s\034%s\n", name, description, keywords, icon, terminal ? "1" : "0", path
                }
            }
        ' "$desktop_file"
    done
done
IFS=$old_ifs
