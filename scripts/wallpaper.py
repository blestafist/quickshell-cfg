#!/usr/bin/env python3
"""Wallpaper library and awww adapter. JSON in/out; never invoke a shell."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".avif", ".pnm", ".tga"}


def cache_directory():
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell/wallpapers/v2-768x480"


def preview_info(path):
    stat = path.stat()
    key = hashlib.sha256(f"{path}\0{stat.st_size}\0{stat.st_mtime_ns}".encode()).hexdigest()[:40]
    return key, cache_directory() / f"{key}.jpg"


def make_preview(path):
    path = directory_path(path)
    key, target = preview_info(path)
    if target.is_file() and target.stat().st_size:
        os.utime(target, None)
        return {"event": "preview", "key": key, "url": target.as_uri()}
    if not shutil.which("magick"):
        raise ValueError("ImageMagick (magick) is required for wallpaper previews.")
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".preview-", suffix=".jpg", dir=target.parent)
    os.close(fd)
    try:
        # Small, persistent JPEGs; two workers at most, one decoder thread each.
        # Decode only the first GIF frame and never upscale small originals.
        try:
            result = subprocess.run([
                "magick", "-limit", "thread", "1", "-limit", "memory", "32MiB",
                "-limit", "map", "64MiB", "-limit", "disk", "1GiB",
                "-define", "jpeg:size=768x480",
                str(path) + "[0]", "-auto-orient", "-thumbnail", "768x480>",
                "-background", "black", "-alpha", "remove", "-alpha", "off",
                "-strip", "-sampling-factor", "4:2:0", "-quality", "82", "jpeg:" + temporary,
            ], capture_output=True, text=True, timeout=20, check=False)
        except subprocess.TimeoutExpired as error:
            result = subprocess.CompletedProcess(error.cmd, 1, stderr="ImageMagick: decoding timed out.")
        if result.returncode or not Path(temporary).stat().st_size:
            # Large HDRI pixel caches or an unsupported coder must not leave a
            # permanent blank. ffmpeg is an independent, one-thread fallback.
            if shutil.which("ffmpeg"):
                result = subprocess.run([
                    "ffmpeg", "-v", "error", "-nostdin", "-threads", "1",
                    "-i", str(path), "-frames:v", "1", "-filter_threads", "1",
                    "-vf", "scale=768:480:force_original_aspect_ratio=decrease:flags=area",
                    "-q:v", "3", "-threads", "1", "-y", temporary,
                ], capture_output=True, text=True, timeout=20, check=False)
            if result.returncode or not Path(temporary).stat().st_size:
                raise ValueError("Could not create a preview: " + path.name + ". " + result.stderr.strip()[:240])
        os.chmod(temporary, 0o600)
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return {"event": "preview", "key": key, "url": target.as_uri()}


def prune_cache(limit_mib):
    files = []
    for path in cache_directory().glob("*.jpg"):
        try:
            stat = path.stat()
            files.append((max(stat.st_atime_ns, stat.st_mtime_ns), stat.st_size, path))
        except FileNotFoundError:
            pass
    total = sum(item[1] for item in files)
    for _, size, path in sorted(files):
        if total <= limit_mib * 1024 * 1024:
            break
        path.unlink(missing_ok=True)
        total -= size


def cache_previews(args):
    try:
        os.nice(10)
    except OSError:
        pass
    paths = json.loads(args.paths)
    if not isinstance(paths, list) or len(paths) > 64 or not all(isinstance(path, str) for path in paths):
        raise ValueError("Expected a bounded list of image paths.")
    directory = directory_path(args.directory)
    paths = [directory_path(path) for path in dict.fromkeys(paths)]
    if any(not path.is_relative_to(directory) or path.suffix.lower() not in EXTENSIONS for path in paths):
        raise ValueError("The image is outside the wallpaper collection.")
    with ThreadPoolExecutor(max_workers=2) as executor:
        jobs = {executor.submit(make_preview, path): path for path in paths}
        for future in as_completed(jobs):
            try:
                emit(**future.result())
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                emit(event="preview-error", path=str(jobs[future]), error=str(error))
    prune_cache(int(finite_number(args.limit_mib, 8, 4096)))


def directory_path(value):
    return Path(os.path.abspath(os.path.expanduser(value or "~/Pictures/Wallpaper")))


def emit(**data):
    print(json.dumps(data, ensure_ascii=True), flush=True)


def query_current(output=""):
    if not shutil.which("awww"):
        return ""
    try:
        result = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=3, check=False)
        for line in result.stdout.splitlines():
            marker = "currently displaying: image: "
            if marker in line and (not output or f"{output}:" in line.split(marker, 1)[0]):
                return line.split(marker, 1)[1]
    except (OSError, subprocess.TimeoutExpired):
        pass
    return ""


def natural_key(value):
    return [int(part) if part.isdigit() else part.casefold() for part in re.split(r"(\d+)", value)]


def scan_library(directory, recursive=True, output=""):
    directory = directory_path(directory)
    result = {"directory": str(directory), "entries": [], "current": query_current(output), "error": ""}
    if not directory.is_dir():
        result["error"] = f"Folder not found: {directory}. Set wallpaperDirectory in ShellConfig.qml."
        return result

    def walk_error(error):
        result["error"] = f"Could not read part of the collection: {error.strerror}"

    for parent, folders, files in os.walk(directory, onerror=walk_error, followlinks=False):
        folders[:] = sorted(name for name in folders if not name.startswith(".")) if recursive else []
        for name in files:
            path = Path(parent) / name
            if name.startswith(".") or path.suffix.lower() not in EXTENSIONS or not path.is_file():
                continue
            try:
                key, preview = preview_info(path)
                cached = preview.is_file() and preview.stat().st_size > 0
            except OSError:
                continue
            result["entries"].append({
                "path": str(path), "url": path.as_uri(), "name": path.stem,
                "relative": str(path.relative_to(directory)),
                "cacheKey": key, "preview": preview.as_uri() if cached else "",
            })
    result["entries"].sort(key=lambda entry: (natural_key(entry["relative"]), entry["relative"].casefold(), entry["relative"]))
    return result


def finite_number(value, minimum, maximum):
    value = float(value)
    if not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError(f"Value must be between {minimum} and {maximum}")
    return value


def apply_command(args):
    directory = directory_path(args.directory)
    image = directory_path(args.path)
    if not image.is_relative_to(directory) or not image.is_file():
        raise ValueError("The file is missing or outside this collection. Refresh the list.")
    if image.suffix.lower() not in EXTENSIONS:
        raise ValueError("Unsupported image format.")
    x = finite_number(args.x, 0, 1)
    y = finite_number(args.y, 0, 1)
    duration = finite_number(args.duration, 0, 10)
    fps = int(finite_number(args.fps, 1, 240))
    command = ["awww", "img", str(image), "--resize", "crop", "--filter", "Lanczos3"]
    if args.output:
        command += ["--outputs", args.output]
    if duration == 0:
        command += ["--transition-type", "none"]
    else:
        # awww's Y coordinate starts at the bottom. Fixed-point notation matters:
        # integers are pixels, decimal numbers are normalized positions.
        command += [
            "--transition-type", "grow", "--transition-pos", f"{x:.6f},{1 - y:.6f}",
            "--transition-duration", str(duration), "--transition-fps", str(fps),
            "--transition-step", "90", "--transition-bezier", "0.22,0.8,0.2,1",
        ]
    return command, image


def apply_wallpaper(args):
    command, image = apply_command(args)
    if not shutil.which("awww"):
        raise ValueError("Install awww and start awww-daemon to apply wallpapers.")
    # Serialize across reloads/instances, without killing someone else's transition.
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/opencode/wallpaper-{os.getuid()}"))
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_path = runtime / "quickshell-wallpaper.lock"
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError("The previous wallpaper change is still in progress.") from error
        probe = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=3, check=False)
        if probe.returncode:
            raise ValueError("awww-daemon is unavailable. Start it and try again.")
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        emit(event="started", path=str(image))
        try:
            stdout, stderr = process.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise ValueError("awww timed out. Try another image.")
        if process.returncode:
            raise ValueError((stderr or stdout or "awww could not apply the wallpaper.").strip()[:1200])
        emit(event="applied", path=str(image))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    scan = commands.add_parser("list")
    scan.add_argument("--directory", default="")
    scan.add_argument("--recursive", choices=("true", "false"), default="true")
    scan.add_argument("--output", default="")
    cache = commands.add_parser("cache")
    cache.add_argument("--directory", default="")
    cache.add_argument("--paths", required=True)
    cache.add_argument("--limit-mib", default="128")
    apply = commands.add_parser("apply")
    apply.add_argument("--directory", default="")
    apply.add_argument("--path", required=True)
    apply.add_argument("--output", default="")
    apply.add_argument("--x", default="0.5")
    apply.add_argument("--y", default="0.12")
    apply.add_argument("--duration", default="1.8")
    apply.add_argument("--fps", default="180")
    args = parser.parse_args()
    try:
        if args.action == "list":
            emit(**scan_library(args.directory, args.recursive == "true", args.output))
        elif args.action == "cache":
            cache_previews(args)
        else:
            apply_wallpaper(args)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        emit(event="error", error=str(error))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
