import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import struct
import tempfile
import types
import unittest
import zlib
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("wallpaper", Path(__file__).resolve().parents[1] / "scripts/wallpaper.py")
wallpaper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpaper)


class WallpaperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="wallpaper-test-", dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.library = Path(self.temp.name) / "Коллекция с пробелами"
        self.library.mkdir()
        self.image = self.library / "обои ' $(touch never).PNG"
        self.image.touch()

    def args(self, **values):
        defaults = dict(directory=str(self.library), path=str(self.image), output="", x="0.5", y="0.1", duration="1.25", fps="180")
        return types.SimpleNamespace(**(defaults | values))

    @patch.object(wallpaper, "query_current", return_value="/current.png")
    def test_scan_recursive_natural_sort_and_encoded_urls(self, _):
        (self.library / "02.jpg").touch()
        (self.library / "10.jpg").touch()
        (self.library / "2.jpg").touch()
        (self.library / "no.txt").touch()
        (self.library / ".hidden.png").touch()
        hidden = self.library / ".private"
        hidden.mkdir()
        (hidden / "no.png").touch()
        folder = self.library / "Nested"
        folder.mkdir()
        (folder / "snow.webp").touch()
        (folder / "loop").symlink_to(self.library, target_is_directory=True)
        result = wallpaper.scan_library(str(self.library))
        self.assertEqual(len(result["entries"]), 5)
        self.assertEqual([e["name"] for e in result["entries"][:3]], ["02", "2", "10"])
        self.assertIn("%20", result["entries"][-1]["url"])
        self.assertIn("%27", result["entries"][-1]["url"])
        self.assertEqual(result["current"], "/current.png")
        self.assertEqual(len(wallpaper.scan_library(str(self.library), False)["entries"]), 4)

    @patch.object(wallpaper, "query_current", return_value="")
    def test_missing_and_empty_directories(self, _):
        result = wallpaper.scan_library(str(self.library / "missing"))
        self.assertEqual(result["entries"], [])
        self.assertIn("Folder not found", result["error"])
        self.image.unlink()
        result = wallpaper.scan_library(str(self.library))
        self.assertEqual(result["entries"], [])
        self.assertEqual(result["error"], "")

    def test_standard_directory_is_default(self):
        self.assertEqual(wallpaper.directory_path(""), Path.home() / "Pictures/Wallpaper")

    def test_preview_identity_changes_when_original_changes(self):
        first, _ = wallpaper.preview_info(self.image)
        self.image.write_bytes(b"changed")
        second, _ = wallpaper.preview_info(self.image)
        self.assertNotEqual(first, second)

    @unittest.skipUnless(wallpaper.shutil.which("magick"), "ImageMagick is not installed")
    def test_large_png_preview_is_bounded_and_reused_without_decoding(self):
        # A real 4K PNG used to exhaust the overly small ImageMagick disk-cache
        # limit. Stream-compress rows to keep the test fixture itself tiny.
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        compressor = zlib.compressobj()
        row = b"\0" + b"\x48\x69\x85" * 4096
        compressed = b"".join(compressor.compress(row) for _ in range(2304)) + compressor.flush()
        self.image.write_bytes(b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 4096, 2304, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", compressed) + chunk(b"IEND", b""))
        with patch.dict(os.environ, {"XDG_CACHE_HOME": self.temp.name}):
            result = wallpaper.make_preview(self.image)
            key, cached = wallpaper.preview_info(self.image)
            self.assertEqual(result["key"], key)
            self.assertTrue(cached.read_bytes().startswith(b"\xff\xd8"))
            self.assertLess(cached.stat().st_size, 100000)
            with patch.object(wallpaper.subprocess, "run") as decoder:
                self.assertEqual(wallpaper.make_preview(self.image), result)
                decoder.assert_not_called()

    def test_cache_pruning_obeys_disk_budget(self):
        with patch.dict(os.environ, {"XDG_CACHE_HOME": self.temp.name}):
            cache = wallpaper.cache_directory()
            cache.mkdir(parents=True)
            for index in range(3):
                path = cache / f"{index}.jpg"
                with path.open("wb") as file:
                    file.truncate(5 * 1024 * 1024)
            wallpaper.prune_cache(8)
            self.assertLessEqual(sum(path.stat().st_size for path in cache.glob("*.jpg")), 8 * 1024 * 1024)

    @patch.object(wallpaper.shutil, "which", side_effect=lambda name: "/usr/bin/" + name)
    def test_preview_fallback_handles_resource_failure_and_timeout(self, _):
        for reason in ["resources", "timeout"]:
            with self.subTest(reason=reason), patch.dict(os.environ, {"XDG_CACHE_HOME": str(Path(self.temp.name) / reason)}):
                commands = []

                def decode(command, **options):
                    commands.append(command)
                    self.assertEqual(options["timeout"], 20)
                    if command[0] == "magick":
                        if reason == "timeout":
                            raise subprocess.TimeoutExpired(command, 20)
                        return subprocess.CompletedProcess(command, 1, stderr="cache resources exhausted")
                    self.assertEqual(command[0], "ffmpeg")
                    self.assertEqual(command[command.index("-threads") + 1], "1")
                    Path(command[-1]).write_bytes(b"\xff\xd8preview")
                    return subprocess.CompletedProcess(command, 0, stderr="")

                with patch.object(wallpaper.subprocess, "run", side_effect=decode):
                    result = wallpaper.make_preview(self.image)
                _, cached = wallpaper.preview_info(self.image)
                self.assertEqual(result["url"], cached.as_uri())
                self.assertEqual(len(commands), 2)
                self.assertEqual(cached.stat().st_mode & 0o777, 0o600)
                self.assertEqual(list(cached.parent.glob(".preview-*")), [])

    @patch.object(wallpaper.shutil, "which", side_effect=lambda name: "/usr/bin/" + name)
    def test_failed_decoders_never_publish_partial_previews(self, _):
        def fail(command, **options):
            Path(command[-1].removeprefix("jpeg:")).write_bytes(b"partial")
            return subprocess.CompletedProcess(command, 1, stderr="decoder failed")

        with patch.dict(os.environ, {"XDG_CACHE_HOME": self.temp.name}), patch.object(wallpaper.subprocess, "run", side_effect=fail):
            with self.assertRaisesRegex(ValueError, "decoder failed"):
                wallpaper.make_preview(self.image)
            _, cached = wallpaper.preview_info(self.image)
            self.assertFalse(cached.exists())
            self.assertEqual(list(cached.parent.iterdir()), [])

    def test_apply_has_one_literal_path_argument_and_correct_bottom_origin(self):
        command, image = wallpaper.apply_command(self.args(x="0", y="0"))
        self.assertEqual(command[:3], ["awww", "img", str(self.image)])
        self.assertEqual(command[command.index("--transition-pos") + 1], "0.000000,1.000000")
        self.assertNotIn("--outputs", command)
        self.assertNotIn("sh", command)
        command, _ = wallpaper.apply_command(self.args(x="1", y="1", output="DP-1"))
        self.assertEqual(command[command.index("--transition-pos") + 1], "1.000000,0.000000")
        self.assertIn("DP-1", command)

    def test_reduced_motion_is_an_instant_awww_change(self):
        command, _ = wallpaper.apply_command(self.args(duration="0"))
        self.assertEqual(command[-2:], ["--transition-type", "none"])
        self.assertNotIn("--transition-duration", command)

    def test_invalid_paths_and_nonfinite_configuration_are_rejected(self):
        for changes in [{"path": "/etc/passwd"}, {"path": str(self.library / "gone.png")},
                        {"x": "nan"}, {"y": "inf"}, {"duration": "-1"}, {"fps": "0"}]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                wallpaper.apply_command(self.args(**changes))

    @patch.object(wallpaper.shutil, "which", return_value="/usr/bin/awww")
    @patch.object(wallpaper.subprocess, "run")
    def test_query_selects_correct_output_and_preserves_filename_spaces(self, run, _):
        run.return_value = types.SimpleNamespace(stdout=": HDMI-A-1: 1080x1920, scale: 1, currently displaying: image: /other.png\n: DP-1: 2560x1440, scale: 1, currently displaying: image: /home/a/ wallpaper with spaces.png\n")
        self.assertEqual(wallpaper.query_current("DP-1"), "/home/a/ wallpaper with spaces.png")
        run.side_effect = subprocess.TimeoutExpired("awww", 3)
        self.assertEqual(wallpaper.query_current("DP-1"), "")

    @patch.object(wallpaper.shutil, "which", return_value="/usr/bin/awww")
    @patch.object(wallpaper.subprocess, "Popen")
    @patch.object(wallpaper.subprocess, "run")
    def test_only_confirmed_success_emits_applied(self, run, popen, _):
        run.return_value = types.SimpleNamespace(returncode=0)
        process = popen.return_value
        process.communicate.return_value = ("", "")
        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temp.name}):
            for code in [0, 1]:
                process.returncode = code
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    if code:
                        with self.assertRaises(ValueError):
                            wallpaper.apply_wallpaper(self.args())
                    else:
                        wallpaper.apply_wallpaper(self.args())
                events = [json.loads(line)["event"] for line in output.getvalue().splitlines()]
                self.assertEqual(events, ["started", "applied"] if code == 0 else ["started"])

    @patch.object(wallpaper.shutil, "which", return_value=None)
    def test_missing_backend_does_not_emit_started(self, _):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), self.assertRaises(ValueError):
            wallpaper.apply_wallpaper(self.args())
        self.assertEqual(output.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
