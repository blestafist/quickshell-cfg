#!/usr/bin/env python3
"""Extract a Material 3 palette with Matugen, without hooks or shell reloads."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

import wallpaper


ROLES = {
    "background": "surface",
    "surface": "surface_container_low",
    "surfaceRaised": "surface_container_high",
    "surfaceHover": "surface_container_highest",
    "textPrimary": "on_surface",
    "textSecondary": "on_surface_variant",
    "textMuted": "on_surface_variant",
    "accent": "primary",
    "accentText": "on_primary",
    "danger": "error",
}
HEX_COLOR = re.compile(r"#[0-9a-fA-F]{6}")


def state_path():
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/theme.json"


def valid_palette(data):
    return (isinstance(data, dict) and data.get("version") == 1
            and isinstance(data.get("wallpaper"), str)
            and isinstance(data.get("colors"), dict)
            and all(isinstance(data["colors"].get(name), str)
                    and HEX_COLOR.fullmatch(data["colors"][name]) for name in ROLES))


def material_roles(data, mode):
    colors = data.get("colors", {})
    # Matugen >= 4 nests modes under each role; older versions nest roles under
    # each mode. Accept both JSON layouts, but never publish a partial palette.
    nested_modes = isinstance(colors.get(mode), dict)
    source = colors[mode] if nested_modes else colors
    roles = {}
    for name, value in source.items():
        if not nested_modes and isinstance(value, dict):
            value = value.get(mode)
        if isinstance(value, dict):
            value = value.get("color")
        if isinstance(value, str) and HEX_COLOR.fullmatch(value):
            roles[name] = value.lower()
    if any(name not in roles for name in ROLES.values()):
        raise ValueError("Matugen returned an incomplete Material 3 palette.")
    return roles


def save_palette(path, data):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".theme-", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as file:
            json.dump(data, file, ensure_ascii=True)
            file.write("\n")
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def generate_palette(path, state=None, mode="dark", scheme="scheme-tonal-spot", force=False):
    path = wallpaper.directory_path(path)
    state = Path(state) if state is not None else state_path()
    if not path.is_file() or path.suffix.lower() not in wallpaper.EXTENSIONS:
        raise ValueError("Wallpaper is missing or has an unsupported format.")
    key, _ = wallpaper.preview_info(path)
    identity = {"wallpaper": str(path), "cacheKey": key, "mode": mode, "scheme": scheme}
    if not force:
        try:
            saved = json.loads(state.read_text())
            if valid_palette(saved) and all(saved.get(name) == value for name, value in identity.items()):
                return saved
        except (OSError, ValueError):
            pass
    if not shutil.which("matugen"):
        raise ValueError("Matugen is not installed. The previous theme was kept.")

    # Reuse the bounded preview: theme extraction never decodes the full-size
    # original a second time, and the bar does no image/color processing itself.
    preview = wallpaper.make_preview(path)
    preview_path = wallpaper.cache_directory() / (preview["key"] + ".jpg")
    result = subprocess.run([
        "matugen", "image", str(preview_path), "--mode", mode, "--type", scheme,
        "--source-color-index", "0", "--dry-run", "--json", "hex",
    ], capture_output=True, text=True, timeout=20, check=False)
    if result.returncode:
        raise ValueError("Matugen could not generate a theme: " + (result.stderr or result.stdout).strip()[:400])
    try:
        roles = material_roles(json.loads(result.stdout), mode)
    except (ValueError, AttributeError, TypeError) as error:
        raise ValueError("Matugen returned an invalid palette. The previous theme was kept.") from error
    data = dict(version=1, **(identity | {"cacheKey": preview["key"]}),
                colors={name: roles[role] for name, role in ROLES.items()}, material=roles)
    save_palette(state, data)
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path")
    parser.add_argument("--state", type=Path)
    parser.add_argument("--mode", choices=("dark", "light"), default="dark")
    parser.add_argument("--scheme", default="scheme-tonal-spot")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    try:
        os.nice(10)
    except OSError:
        pass
    try:
        data = generate_palette(args.path, args.state, args.mode, args.scheme, args.force)
        wallpaper.emit(event="palette", **data)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        wallpaper.emit(event="error", error=str(error))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
