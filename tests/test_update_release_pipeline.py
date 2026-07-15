from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "codex" / "fantasydisk-release-director" / "scripts"


def _load(name: str):
    script = SCRIPTS / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"fan1112_{name}", script)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


build_update_manifest = _load("build_update_manifest")
github_release_publish = _load("github_release_publish")
telegram_publish = _load("telegram_publish")


class UpdateReleasePipelineTests(unittest.TestCase):
    def test_manifest_matches_both_installers_and_public_urls(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            mac = release / "FantasyDisk-0.2.3-macos.dmg"
            windows = release / "FantasyDisk-0.2.3-windows-setup.exe"
            mac.write_bytes(b"signed dmg")
            windows.write_bytes(b"nsis setup")
            manifest = build_update_manifest.build_manifest(
                version="0.2.3", release_dir=release
            )
            self.assertEqual(manifest["schema_version"], 1)
            self.assertEqual(manifest["minimum_supported_version"], "0.2.2")
            self.assertEqual(
                manifest["assets"]["macos"]["sha256"],
                hashlib.sha256(mac.read_bytes()).hexdigest(),
            )
            self.assertEqual(manifest["assets"]["windows"]["size"], windows.stat().st_size)
            self.assertEqual(
                manifest["release_url"],
                "https://github.com/FomaBy/FantasyDisk/releases/tag/v0.2.3",
            )
            self.assertIn("/releases/download/v0.2.3/", manifest["assets"]["macos"]["url"])

    def test_github_asset_order_publishes_manifest_last(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            version = "0.2.3"
            names = [
                f"FantasyDisk-{version}-macos.dmg",
                f"FantasyDisk-{version}-windows-setup.exe",
                "SHA256SUMS.txt",
                f"CHANGELOG-{version}.md",
                "fantasydisk_023_announcement.png",
            ]
            for name in names:
                (release / name).write_bytes(b"fixture")
            (release / "update-manifest.json").write_text(
                json.dumps({"version": version}), encoding="utf-8"
            )
            files, _changelog = github_release_publish.release_files(release, version)
            self.assertEqual(files[-1].name, "update-manifest.json")
            self.assertEqual(len(files), 6)

    def test_telegram_is_hard_stopped_after_0_2_2(self) -> None:
        telegram_publish.ensure_telegram_release_allowed("0.2.2")
        with self.assertRaisesRegex(SystemExit, "завершена после v0.2.2"):
            telegram_publish.ensure_telegram_release_allowed("0.2.3")
        with self.assertRaisesRegex(SystemExit, "формат X.Y.Z"):
            telegram_publish.ensure_telegram_release_allowed("0.2.03")

    def test_rejects_non_strict_release_version(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(build_update_manifest.ManifestError):
                build_update_manifest.build_manifest(
                    version="0.2.03", release_dir=Path(temporary)
                )

    def test_rejects_minimum_newer_than_release(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(build_update_manifest.ManifestError):
                build_update_manifest.build_manifest(
                    version="0.2.2",
                    minimum_supported_version="0.2.3",
                    release_dir=Path(temporary),
                )


if __name__ == "__main__":
    unittest.main()
