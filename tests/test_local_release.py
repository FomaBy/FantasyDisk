from __future__ import annotations

import hashlib
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills" / "codex" / "fantasydisk-release-director" / "scripts" / "local_release.py"
SPEC = importlib.util.spec_from_file_location("local_release_tested", SCRIPT)
local_release = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = local_release
SPEC.loader.exec_module(local_release)


class LocalReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self._git("init")
        self._git("config", "user.email", "release-test@example.invalid")
        self._git("config", "user.name", "Release Test")
        (self.repo / "project.godot").write_text(
            '[application]\nconfig/name="FantasyDisk"\nconfig/version="9.8.7"\n',
            encoding="utf-8",
        )
        (self.repo / "source.txt").write_text("exact tag source\n", encoding="utf-8")
        self._git("add", "project.godot", "source.txt")
        self._git("commit", "-m", "release fixture")
        self._git("tag", "-a", "v9.8.7", "-m", "fixture")

        self.source_release = self.repo / "releases" / "v9.8.7"
        self.source_release.mkdir(parents=True)
        artifacts = {
            "FantasyDisk-9.8.7-macos.dmg": b"dmg fixture",
            "FantasyDisk-9.8.7-windows-setup.exe": b"windows fixture",
            "CHANGELOG-9.8.7.md": b"# fixture\n",
            "fantasydisk_987_announcement_telegram_discord.png": b"poster fixture",
        }
        for name, data in artifacts.items():
            (self.source_release / name).write_bytes(data)
        checksum_lines = []
        for name in ("FantasyDisk-9.8.7-macos.dmg", "FantasyDisk-9.8.7-windows-setup.exe"):
            digest = hashlib.sha256((self.source_release / name).read_bytes()).hexdigest()
            checksum_lines.append(f"{digest}  {name}")
        (self.source_release / "SHA256SUMS.txt").write_text(
            "\n".join(checksum_lines) + "\n", encoding="utf-8"
        )

        self.local_root = self.root / "operator"
        self.local_root.mkdir()
        (self.local_root / "project.godot").write_text(
            'config/version="dev"\n', encoding="utf-8"
        )
        self.projects_file = self.root / "Godot" / "projects.cfg"
        self.config = local_release.LocalConfig(
            self.local_root,
            self.root / "Applications" / "FantasyDisk.app",
            self.projects_file,
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _git(self, *args: str) -> str:
        return subprocess.run(
            ["git", *args], cwd=self.repo, check=True, text=True, capture_output=True
        ).stdout.strip()

    def _materialize(self):
        with mock.patch.object(local_release.platform, "system", return_value="Linux"):
            return local_release.materialize_package(
                version="9.8.7",
                repo_root=self.repo,
                source_release=self.source_release,
                config=self.config,
            )

    def test_materializes_exact_tag_and_verifies_stable_godot_project(self) -> None:
        destination, manifest = self._materialize()
        current = local_release._update_current_project(destination.parent, "9.8.7")
        local_release._register_godot(self.projects_file, current)
        verified = local_release.verify_local_release(
            version="9.8.7",
            repo_root=self.repo,
            config=self.config,
            require_app=False,
        )

        self.assertEqual(verified["tag_commit"], self._git("rev-parse", "v9.8.7^{commit}"))
        self.assertEqual(manifest["version"], "9.8.7")
        self.assertEqual(os.readlink(current), "v9.8.7/godot-project")
        self.assertEqual(
            local_release._project_version(current / "project.godot"), "9.8.7"
        )
        self.assertEqual((current / "source.txt").read_text(), "exact tag source\n")
        (current / "source.txt").write_text("editable working copy\n", encoding="utf-8")
        local_release.verify_local_release(
            version="9.8.7",
            repo_root=self.repo,
            config=self.config,
            require_app=False,
        )
        self.assertEqual(
            (destination / "project" / "source.txt").read_text(), "exact tag source\n"
        )
        self.assertIn(f"[{current}]", self.projects_file.read_text(encoding="utf-8"))
        self.assertTrue(
            (destination / "fantasydisk_987_announcement_telegram_discord.png").is_file()
        )

    def test_refuses_to_overwrite_changed_existing_release(self) -> None:
        destination, _manifest = self._materialize()
        (destination / "FantasyDisk-9.8.7-macos.dmg").write_bytes(b"changed")
        with self.assertRaisesRegex(local_release.LocalReleaseError, "differs"):
            self._materialize()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "differs"):
            with mock.patch.object(local_release.platform, "system", return_value="Linux"):
                local_release.materialize_package(
                    version="9.8.7",
                    repo_root=self.repo,
                    source_release=self.source_release,
                    config=self.config,
                    dry_run=True,
                )

    def test_requires_poster_and_distinct_installer_checksums(self) -> None:
        poster = self.source_release / "fantasydisk_987_announcement_telegram_discord.png"
        poster.unlink()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "incomplete"):
            local_release._validate_package(self.source_release, "9.8.7")
        poster.write_bytes(b"poster fixture")

        dmg = self.source_release / "FantasyDisk-9.8.7-macos.dmg"
        digest = hashlib.sha256(dmg.read_bytes()).hexdigest()
        (self.source_release / "SHA256SUMS.txt").write_text(
            f"{digest}  {dmg.name}\n{digest}  {dmg.name}\n", encoding="utf-8"
        )
        with self.assertRaisesRegex(local_release.LocalReleaseError, "duplicate"):
            local_release._validate_package(self.source_release, "9.8.7")

    def test_refuses_regular_current_project_path(self) -> None:
        releases = self.local_root / "releases"
        releases.mkdir()
        (releases / "current-project").mkdir()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "not a symlink"):
            local_release._update_current_project(releases, "9.8.7")

    def test_registration_upgrades_existing_favorite_false(self) -> None:
        current = self.local_root / "releases" / "current-project"
        self.projects_file.parent.mkdir(parents=True)
        self.projects_file.write_text(
            f"[{current}]\n\nfavorite=false\n", encoding="utf-8"
        )
        local_release._register_godot(self.projects_file, current)
        content = self.projects_file.read_text(encoding="utf-8")
        self.assertIn("favorite=true", content)
        self.assertNotIn("favorite=false", content)

    def test_config_never_infers_or_accepts_multica_worktree(self) -> None:
        (self.repo / "release_webhook.cfg").write_text("[release]\n", encoding="utf-8")
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(local_release.LocalReleaseError, "not configured"):
                local_release.resolve_config(
                    repo_root=self.repo,
                    config_path=self.root / "missing.json",
                )

        ephemeral = self.root / "multica_workspaces" / "run" / "FantasyDisk"
        ephemeral.mkdir(parents=True)
        (ephemeral / "project.godot").write_text(
            'config/version="9.8.7"\n', encoding="utf-8"
        )
        with self.assertRaisesRegex(local_release.LocalReleaseError, "ephemeral Multica"):
            local_release.resolve_config(
                repo_root=self.repo,
                config_path=self.root / "missing.json",
                local_root=ephemeral,
            )

    def test_pipeline_and_publishers_enforce_local_gate(self) -> None:
        build = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        checksum_at = build.index('echo "==> SHA256SUMS.txt')
        local_at = build.index('local_release.py"')
        done_at = build.index('echo "==> Готово:"')
        self.assertLess(checksum_at, local_at)
        self.assertLess(local_at, done_at)

        for name in ("release_publish.py", "telegram_publish.py"):
            source = (SCRIPT.parent / name).read_text(encoding="utf-8")
            self.assertIn("rel = verify_local_release(root, a.version)", source)
            self.assertIn('"verify", "--version"', source)
            self.assertIn('json.loads(result.stdout)["local_release"]', source)
            self.assertIn('".png"', source)

        self.assertNotIn('cp "${REPO_DIR}/export_presets.cfg"', build)
        self.assertIn('RELEASE_DIR="${WORKTREE_DIR}/build/release-package"', build)
        self.assertIn('"${WORKTREE_DIR}/tools/create_macos_dmg.sh"', build)
        self.assertIn('"${WORKTREE_DIR}/tools/windows_installer.nsi"', build)
        self.assertIn('"${WORKTREE_DIR}/tools/scan_release_secrets.py"', build)

        telegram = (SCRIPT.parent / "telegram_publish.py").read_text(encoding="utf-8")
        self.assertIn("CheckChatInviteRequest", telegram)
        self.assertNotIn("next((d.entity for d in client.get_dialogs()", telegram)
        self.assertIn("posters[0], caption=caption, force_document=False", telegram)

        discord = (SCRIPT.parent / "release_publish.py").read_text(encoding="utf-8")
        self.assertIn('content_type = "image/png"', discord)
        self.assertIn("hl = read_highlights(rel, a.version)", discord)
        self.assertIn('os.path.join(release_dir, "project", "scripts"', discord)
        self.assertNotIn("read_highlights(root, a.version", discord)
        self.assertNotIn('ap.add_argument("--highlights"', discord)
        self.assertIn("Release poster превышает лимит Discord webhook", discord)

        local_script = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('["hdiutil", "verify", dmg]', local_script)
        self.assertIn('"context:primary-signature"', local_script)


if __name__ == "__main__":
    unittest.main()
