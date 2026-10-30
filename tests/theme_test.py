import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from unittest.mock import patch


scripts = str(Path(__file__).resolve().parents[1] / "scripts")
sys.path.insert(0, scripts)
import theme
sys.path.remove(scripts)


def matugen_data(legacy=False):
    colors = {role: "#123456" for role in theme.ROLES.values()}
    if legacy:
        return {"colors": {"dark": colors}}
    return {"colors": {name: {"dark": {"color": color}} for name, color in colors.items()}}


class ThemeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="theme-test-", dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.image = Path(self.temp.name) / "wallpaper ' $(touch never).png"
        self.image.write_bytes(b"original")
        self.state = Path(self.temp.name) / "state/theme.json"
        self.environment = patch.dict(os.environ, {"XDG_CACHE_HOME": self.temp.name})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def decoder(self, **values):
        key, _ = theme.wallpaper.preview_info(self.image)
        defaults = {"returncode": 0, "stdout": json.dumps(matugen_data()), "stderr": ""}
        return (patch.object(theme.shutil, "which", return_value="/usr/bin/matugen"),
                patch.object(theme.wallpaper, "make_preview", return_value={"key": key}),
                patch.object(theme.subprocess, "run", return_value=subprocess.CompletedProcess([], **(defaults | values))))

    def test_current_and_legacy_json_layouts_have_identical_material_roles(self):
        self.assertEqual(theme.material_roles(matugen_data(), "dark"), theme.material_roles(matugen_data(True), "dark"))
        with self.assertRaises(ValueError):
            theme.material_roles({"colors": {}}, "dark")

    def test_generation_is_noninteractive_bounded_and_atomically_saved(self):
        tools, preview, decoder = self.decoder()
        with tools, preview, decoder as run:
            palette = theme.generate_palette(self.image, self.state)
        self.assertTrue(theme.valid_palette(palette))
        self.assertEqual(json.loads(self.state.read_text()), palette)
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(self.state.parent.glob(".theme-*")), [])
        command = run.call_args.args[0]
        self.assertEqual(command[:2], ["matugen", "image"])
        self.assertNotIn(str(self.image), command)
        self.assertIn(str(theme.wallpaper.cache_directory()), command[2])
        self.assertIn("--dry-run", command)
        self.assertEqual(command[command.index("--source-color-index") + 1], "0")
        self.assertNotIn("shell", run.call_args.kwargs)

    def test_unchanged_wallpaper_reuses_palette_even_without_matugen(self):
        tools, preview, decoder = self.decoder()
        with tools, preview, decoder:
            first = theme.generate_palette(self.image, self.state)
        with patch.object(theme.shutil, "which", return_value=None), patch.object(theme.subprocess, "run") as run:
            self.assertEqual(theme.generate_palette(self.image, self.state), first)
            run.assert_not_called()

    def test_changed_image_or_scheme_invalidates_saved_palette(self):
        tools, preview, decoder = self.decoder()
        with tools, preview, decoder:
            first = theme.generate_palette(self.image, self.state)
        self.image.write_bytes(b"changed image content")
        tools, preview, decoder = self.decoder()
        with tools, preview, decoder as run:
            second = theme.generate_palette(self.image, self.state)
            third = theme.generate_palette(self.image, self.state, scheme="scheme-neutral")
            self.assertEqual(run.call_count, 2)
        self.assertNotEqual(first["cacheKey"], second["cacheKey"])
        self.assertEqual(third["scheme"], "scheme-neutral")

    def test_failed_invalid_and_timed_out_generation_keep_previous_theme(self):
        tools, preview, decoder = self.decoder()
        with tools, preview, decoder:
            theme.generate_palette(self.image, self.state)
        previous = self.state.read_bytes()
        for failure in [dict(returncode=1, stderr="decoder failed"), dict(stdout="not json"), dict(stdout='{"colors":{}}')]:
            tools, preview, decoder = self.decoder(**failure)
            with self.subTest(failure=failure), tools, preview, decoder, self.assertRaises(ValueError):
                theme.generate_palette(self.image, self.state, force=True)
            self.assertEqual(self.state.read_bytes(), previous)
        tools, preview, decoder = self.decoder()
        with tools, preview, decoder as run:
            run.side_effect = subprocess.TimeoutExpired("matugen", 20)
            with self.assertRaises(subprocess.TimeoutExpired):
                theme.generate_palette(self.image, self.state, force=True)
        self.assertEqual(self.state.read_bytes(), previous)

    def test_missing_matugen_and_invalid_inputs_never_replace_theme(self):
        self.state.parent.mkdir()
        self.state.write_text("previous theme")
        with patch.object(theme.shutil, "which", return_value=None), self.assertRaisesRegex(ValueError, "not installed"):
            theme.generate_palette(self.image, self.state)
        for path in [self.image.parent / "missing.png", self.image.parent]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                theme.generate_palette(path, self.state)
        self.assertEqual(self.state.read_text(), "previous theme")

    def test_incomplete_or_unsafe_saved_colors_are_rejected(self):
        for colors in [{}, {name: "red" for name in theme.ROLES}, {name: "#123456;bad" for name in theme.ROLES}]:
            self.assertFalse(theme.valid_palette({"version": 1, "wallpaper": "x", "colors": colors}))

    @unittest.skipUnless(shutil.which("matugen") and shutil.which("magick"), "Matugen and ImageMagick are required")
    def test_real_matugen_generates_contrasting_dark_and_light_palettes(self):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

        row = b"\0" + b"\x9c\x40\x70" * 32
        self.image.write_bytes(b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 32, 32, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(row * 32)) + chunk(b"IEND", b""))

        def luminance(color):
            channels = [int(color[i:i + 2], 16) / 255 for i in [1, 3, 5]]
            linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
            return sum(value * weight for value, weight in zip(linear, [0.2126, 0.7152, 0.0722]))

        for mode in ["dark", "light"]:
            with self.subTest(mode=mode):
                data = theme.generate_palette(self.image, self.state, mode=mode)
                self.assertTrue(theme.valid_palette(data))
                for foreground, background in [("textPrimary", "surfaceRaised"), ("textSecondary", "surfaceRaised"), ("accentText", "accent")]:
                    a, b = sorted([luminance(data["colors"][foreground]), luminance(data["colors"][background])])
                    self.assertGreaterEqual((b + 0.05) / (a + 0.05), 4.5)


if __name__ == "__main__":
    unittest.main()
