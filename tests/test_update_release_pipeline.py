from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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
github_release_verify = _load("github_release_verify")
telegram_publish = _load("telegram_publish")


class UpdateReleasePipelineTests(unittest.TestCase):
    def test_manifest_matches_both_installers_and_public_urls(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            mac = release / "FantasyDisk-0.2.4-macos.dmg"
            windows = release / "FantasyDisk-0.2.4-windows-setup.exe"
            mac.write_bytes(b"signed dmg")
            windows.write_bytes(b"nsis setup")
            manifest = build_update_manifest.build_manifest(
                version="0.2.4", release_dir=release
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
                "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.2.4",
            )
            self.assertIn("/releases/download/v0.2.4/", manifest["assets"]["macos"]["url"])

    def test_manifest_supports_four_component_technical_hotfix(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            version = "0.2.3.1"
            for name in (
                f"FantasyDisk-{version}-macos.dmg",
                f"FantasyDisk-{version}-windows-setup.exe",
            ):
                (release / name).write_bytes(name.encode("utf-8"))
            manifest = build_update_manifest.build_manifest(
                version=version,
                minimum_supported_version="0.2.3",
                release_dir=release,
            )
            self.assertEqual(manifest["version"], version)
            self.assertEqual(manifest["minimum_supported_version"], "0.2.3")
            self.assertIn("/releases/download/v0.2.3.1/", manifest["assets"]["windows"]["url"])

    def test_github_asset_order_publishes_manifest_last(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            version = "0.2.4"
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

    def test_telegram_delivery_is_allowed_for_current_stable_versions(self) -> None:
        telegram_publish.ensure_telegram_release_version("0.2.2")
        telegram_publish.ensure_telegram_release_version("0.2.4")
        telegram_publish.ensure_telegram_release_version("0.2.3.1")
        with self.assertRaisesRegex(SystemExit, "формат X.Y.Z"):
            telegram_publish.ensure_telegram_release_version("0.2.03")

    def test_public_distribution_publisher_allows_only_metadata_in_git_tree(self) -> None:
        self.assertEqual(
            github_release_publish.DEFAULT_REPOSITORY,
            "FomaBy/FantasyDisk-Releases",
        )
        self.assertEqual(github_release_publish.safe_distribution_paths(["README.md"]), [])
        self.assertEqual(
            github_release_publish.safe_distribution_paths(["README.md", "project.godot"]),
            ["project.godot"],
        )

    def test_public_distribution_verifier_rejects_source_or_secret_like_readme_content(self) -> None:
        self.assertEqual(github_release_verify.DEFAULT_REPOSITORY, "FomaBy/FantasyDisk-Releases")
        self.assertEqual(github_release_verify.EXPECTED_ROOT_PATHS, {"README.md"})
        self.assertIn("project.godot", github_release_verify.README_FORBIDDEN_MARKERS)
        self.assertIn("authorization:", github_release_verify.README_FORBIDDEN_MARKERS)

    def test_rejects_non_strict_release_version(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(build_update_manifest.ManifestError):
                build_update_manifest.build_manifest(
                    version="0.2.03", release_dir=Path(temporary)
                )
            with self.assertRaises(build_update_manifest.ManifestError):
                build_update_manifest.build_manifest(
                    version="0.2.3.1.1", release_dir=Path(temporary)
                )

    def test_rejects_minimum_newer_than_release(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(build_update_manifest.ManifestError):
                build_update_manifest.build_manifest(
                    version="0.2.2",
                    minimum_supported_version="0.2.3",
                    release_dir=Path(temporary),
                )

    def test_all_publication_gates_accept_both_supported_version_shapes(self) -> None:
        gates = (
            build_update_manifest,
            github_release_publish,
            github_release_verify,
            telegram_publish,
        )
        for version in ("0.2.4", "0.2.3.1"):
            for gate in gates:
                with self.subTest(version=version, gate=gate.__name__):
                    self.assertTrue(gate.RELEASE_VERSION_RE.fullmatch(version))
        for invalid in ("0.2.03", "0.2.3.1.1", "0.2.3-beta"):
            for gate in gates:
                with self.subTest(version=invalid, gate=gate.__name__):
                    self.assertIsNone(gate.RELEASE_VERSION_RE.fullmatch(invalid))

    def test_publisher_refuses_existing_immutable_tag(self) -> None:
        existing = subprocess.CompletedProcess(
            ["gh", "release", "view"], 0, stdout='{"url":"https://example.invalid"}', stderr=""
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", return_value=existing):
            with self.assertRaisesRegex(RuntimeError, "never overwrite"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )

    def test_public_verifier_cannot_prune_immutable_releases(self) -> None:
        source = (SCRIPTS / "github_release_verify.py").read_text(encoding="utf-8")
        self.assertNotIn("--prune-previous", source)
        self.assertNotIn('"gh", "release", "delete"', source)


class UnsignedChannelLabelingTests(unittest.TestCase):
    """FAN-1121: the unsigned macOS channel must be labeled truthfully everywhere."""

    # Every canonical release document a release agent may follow. FAN-1123
    # extended coverage beyond game_updates.md after current_game_state.md and
    # release_versioning.md kept mandating signed-only delivery.
    ACTIVE_RELEASE_DOCS = (
        Path("docs") / "process" / "game_updates.md",
        Path("docs") / "design" / "current_game_state.md",
        Path("docs") / "process" / "release_versioning.md",
    )

    def test_client_labels_unsigned_macos_channel_truthfully(self) -> None:
        manager = (ROOT / "scripts" / "update_manager.gd").read_text(encoding="utf-8")
        self.assertIn('const MACOS_UPDATE_CHANNEL := "unsigned"', manager)
        self.assertIn("без подписи Apple Developer ID", manager)
        self.assertIn("Конфиденциальность и безопасность", manager)
        self.assertIn("«Всё равно открыть» (Open Anyway)", manager)
        self.assertNotIn("подписанный установщик", manager)

        dialog = (ROOT / "scripts" / "ui" / "update_dialog.gd").read_text(encoding="utf-8")
        self.assertIn("MACOS_UNSIGNED_NOTICE", dialog)
        self.assertIn("macos_update_is_unsigned", dialog)

    def test_release_docs_do_not_claim_apple_trust_for_unsigned_channel(self) -> None:
        docs = (ROOT / "docs" / "process" / "game_updates.md").read_text(encoding="utf-8")
        self.assertNotIn("signed/notarized", docs)
        self.assertIn("FANTASYDISK_MACOS_CHANNEL=unsigned", docs)
        self.assertIn("Всё равно открыть", docs)
        skill = (
            ROOT / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md"
        ).read_text(encoding="utf-8")
        self.assertIn("FANTASYDISK_MACOS_CHANNEL", skill)
        self.assertIn("unsigned", skill)

    def test_every_active_release_doc_describes_both_channels(self) -> None:
        # FAN-1123: all canonical release documents must present the explicit
        # signed/unsigned channels and name unsigned as the current selection, so
        # a release agent cannot follow one document into a signed-only block.
        for relative in self.ACTIVE_RELEASE_DOCS:
            with self.subTest(doc=str(relative)):
                doc = (ROOT / relative).read_text(encoding="utf-8")
                self.assertIn("FANTASYDISK_MACOS_CHANNEL", doc)
                self.assertIn("unsigned", doc)
                self.assertIn("FAN-1121", doc)
                self.assertNotIn("signed/notarized", doc)

    def test_snapshot_and_versioning_docs_supersede_fan1094_signed_only(self) -> None:
        # FAN-1123 regression: these two documents previously mandated signed-only
        # macOS delivery and presented cancelled FAN-1094 as the current rule.
        state = (ROOT / "docs" / "design" / "current_game_state.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("FAN-1094 делает macOS installer fail-closed", state)
        self.assertIn("текущий выбранный канал", state)

        versioning = (ROOT / "docs" / "process" / "release_versioning.md").read_text(
            encoding="utf-8"
        )
        # codesign/notarytool/stapler/spctl must be scoped to the signed channel,
        # not asserted as a universal release blocker.
        self.assertNotIn(
            "отсутствие Developer ID/notary profile является release blocker",
            versioning,
        )
        self.assertIn("Канал `unsigned`", versioning)

    def test_build_script_cross_checks_client_channel_label(self) -> None:
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        label_check_at = script.index("const MACOS_UPDATE_CHANNEL := ")
        export_at = script.index('--export-release "macOS"')
        self.assertLess(label_check_at, export_at)
        self.assertIn('CLIENT_MACOS_CHANNEL="$(sed -n', script)
        self.assertIn('if [[ "${CLIENT_MACOS_CHANNEL}" != "${MACOS_CHANNEL}" ]]', script)


class Published024ReleaseDocumentationTests(unittest.TestCase):
    """FAN-1226: operator docs must describe the already published 0.2.4 release."""

    CANONICAL_RELEASE_DOCS = (
        Path("docs") / "process" / "game_updates.md",
        Path("docs") / "process" / "release_versioning.md",
        Path("docs") / "release_telegram_setup.md",
    )

    def test_snapshot_marks_024_as_the_current_published_stable_release(self) -> None:
        state = (ROOT / "docs" / "design" / "current_game_state.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("опубликован stable release 0.2.4", state)
        self.assertIn("Текущий опубликованный stable release: `0.2.4`", state)
        self.assertNotIn("release snapshot 0.2.3", state)
        self.assertNotIn("`0.2.4`, готовится из `dev`", state)
        self.assertNotIn("Игровой баланс и контент принятой версии 0.2.3 не меняются", state)

    def test_readme_requires_current_telethon_session_for_every_stable_release(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn(
            "текущая локальная Telethon-сессия (секрет) для\n"
            "  обязательной Telegram-доставки файлов каждого stable release",
            readme,
        )
        self.assertNotIn("legacy Telethon-сессия только для релиза 0.2.2", readme)

    def test_canonical_release_docs_keep_the_public_github_and_telegram_contract(self) -> None:
        for relative in self.CANONICAL_RELEASE_DOCS:
            with self.subTest(doc=str(relative)):
                doc = (ROOT / relative).read_text(encoding="utf-8")
                self.assertIn("FomaBy/FantasyDisk-Releases", doc)
                self.assertIn("Telegram", doc)


if __name__ == "__main__":
    unittest.main()
