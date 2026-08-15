from __future__ import annotations

import hashlib
import importlib.util
import json
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
            "fantasydisk_987_announcement.png": b"poster fixture",
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
        (self.source_release / "update-manifest.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "version": "9.8.7",
                    "minimum_supported_version": "0.2.2",
                    "release_url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v9.8.7",
                    "assets": {
                        "macos": {
                            "name": "FantasyDisk-9.8.7-macos.dmg",
                            "url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v9.8.7/FantasyDisk-9.8.7-macos.dmg",
                            "sha256": checksum_lines[0].split()[0],
                            "size": (self.source_release / "FantasyDisk-9.8.7-macos.dmg").stat().st_size,
                        },
                        "windows": {
                            "name": "FantasyDisk-9.8.7-windows-setup.exe",
                            "url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v9.8.7/FantasyDisk-9.8.7-windows-setup.exe",
                            "sha256": checksum_lines[1].split()[0],
                            "size": (self.source_release / "FantasyDisk-9.8.7-windows-setup.exe").stat().st_size,
                        },
                    },
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
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
            ["git", *args],
            cwd=self.repo,
            check=True,
            encoding="utf-8",
            capture_output=True,
        ).stdout.strip()

    def _materialize(self, macos_channel: str = "signed"):
        with mock.patch.object(local_release.platform, "system", return_value="Linux"):
            return local_release.materialize_package(
                version="9.8.7",
                repo_root=self.repo,
                source_release=self.source_release,
                config=self.config,
                macos_channel=macos_channel,
            )

    def _verify(self, macos_channel: str = "signed"):
        return local_release.verify_local_release(
            version="9.8.7",
            repo_root=self.repo,
            config=self.config,
            require_app=False,
            macos_channel=macos_channel,
        )

    def _candidate(self) -> local_release.CandidateProvenance:
        (self.repo / "source.txt").write_text("candidate source\n", encoding="utf-8")
        self._git("add", "source.txt")
        self._git("commit", "-m", "candidate fixture")
        candidate = local_release.CandidateProvenance(
            repository="https://github.com/FomaBy/FantasyDisk.git",
            ref="refs/heads/release-candidate",
            commit=self._git("rev-parse", "HEAD"),
            tree=self._git("rev-parse", "HEAD^{tree}"),
        )
        (self.source_release / "CANDIDATE_PROVENANCE.json").write_text(
            json.dumps(
                {
                    "repository": candidate.repository,
                    "ref": candidate.ref,
                    "commit": candidate.commit,
                    "tree": candidate.tree,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        return candidate

    def test_materializes_exact_tag_and_verifies_stable_godot_project(self) -> None:
        destination, manifest = self._materialize()
        current = local_release._update_current_project(destination.parent, "9.8.7")
        self.assertEqual(
            local_release._update_current_project(destination.parent, "9.8.7"), current
        )
        local_release._register_godot(self.projects_file, current)
        verified = local_release.verify_local_release(
            version="9.8.7",
            repo_root=self.repo,
            config=self.config,
            require_app=False,
        )

        self.assertEqual(verified["tag_commit"], self._git("rev-parse", "v9.8.7^{commit}"))
        self.assertEqual(manifest["version"], "9.8.7")
        self.assertTrue(local_release._is_project_pointer(current))
        self.assertEqual(
            local_release._project_pointer_target(destination.parent, current, "9.8.7"),
            (destination / "godot-project").resolve(),
        )
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
            (destination / "fantasydisk_987_announcement.png").is_file()
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

    def test_existing_tag_manifest_without_inventory_remains_verifiable(self) -> None:
        destination, _manifest = self._materialize()
        current = local_release._update_current_project(destination.parent, "9.8.7")
        local_release._register_godot(self.projects_file, current)
        manifest_path = destination / "LOCAL_RELEASE.json"
        legacy = json.loads(manifest_path.read_text(encoding="utf-8"))
        legacy.pop("package_inventory")
        manifest_path.write_text(json.dumps(legacy) + "\n", encoding="utf-8")
        self._verify()

    def test_materializes_untagged_candidate_and_matches_tag_only_after_promotion(self) -> None:
        candidate = self._candidate()
        with mock.patch.object(local_release.platform, "system", return_value="Linux"):
            destination, manifest = local_release.materialize_package(
                version="9.8.7",
                repo_root=self.repo,
                source_release=self.source_release,
                config=self.config,
                candidate=candidate,
            )
        self.assertNotIn("tag", manifest)
        self.assertNotIn("tag_commit", manifest)
        self.assertEqual(
            manifest["candidate"],
            {
                "repository": candidate.repository,
                "ref": candidate.ref,
                "commit": candidate.commit,
                "tree": candidate.tree,
            },
        )
        self.assertEqual(
            manifest["package_inventory"]["CANDIDATE_PROVENANCE.json"],
            {
                "sha256": hashlib.sha256(
                    (destination / "CANDIDATE_PROVENANCE.json").read_bytes()
                ).hexdigest(),
                "size": (destination / "CANDIDATE_PROVENANCE.json").stat().st_size,
            },
        )
        current = local_release._update_current_project(destination.parent, "9.8.7")
        local_release._register_godot(self.projects_file, current)
        local_release.verify_local_release(
            version="9.8.7",
            repo_root=self.repo,
            config=self.config,
            require_app=False,
            require_tag_match=False,
        )
        with self.assertRaisesRegex(local_release.LocalReleaseError, "candidate provenance"):
            self._verify()

        self._git("tag", "-d", "v9.8.7")
        self._git("tag", "-a", "v9.8.7", "-m", "candidate promotion", candidate.commit)
        verified = self._verify()
        self.assertEqual(verified["candidate"]["commit"], candidate.commit)

    def test_candidate_provenance_is_complete_safe_and_prebuilt(self) -> None:
        candidate = self._candidate()
        (self.source_release / "CANDIDATE_PROVENANCE.json").unlink()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "pre-build provenance"):
            with mock.patch.object(local_release.platform, "system", return_value="Linux"):
                local_release.materialize_package(
                    version="9.8.7",
                    repo_root=self.repo,
                    source_release=self.source_release,
                    config=self.config,
                    candidate=candidate,
                )
        provenance = self.source_release / "CANDIDATE_PROVENANCE.json"
        provenance.write_text("{}\n", encoding="utf-8")
        original_is_symlink = Path.is_symlink
        with mock.patch.object(
            Path,
            "is_symlink",
            lambda path: path == provenance or original_is_symlink(path),
        ):
            with self.assertRaisesRegex(local_release.LocalReleaseError, "unsafe pre-build provenance"):
                with mock.patch.object(local_release.platform, "system", return_value="Linux"):
                    local_release.materialize_package(
                        version="9.8.7",
                        repo_root=self.repo,
                        source_release=self.source_release,
                        config=self.config,
                        candidate=candidate,
                    )
        with self.assertRaisesRegex(local_release.LocalReleaseError, "full 40-hex SHA"):
            local_release._candidate_provenance(
                candidate.repository, candidate.ref, candidate.commit[:-1], candidate.tree
            )
        with self.assertRaisesRegex(local_release.LocalReleaseError, "refs/heads"):
            local_release._candidate_provenance(
                candidate.repository, "refs/tags/v9.8.7", candidate.commit, candidate.tree
            )

    def test_release_version_parser_supports_hotfix_component(self) -> None:
        self.assertEqual(local_release._version_key("0.2.3"), (0, 2, 3, 0))
        self.assertEqual(local_release._version_key("0.2.3.1"), (0, 2, 3, 1))
        self.assertLess(local_release._version_key("0.2.3"), local_release._version_key("0.2.3.1"))
        self.assertLess(local_release._version_key("0.2.3.1"), local_release._version_key("0.2.4"))
        with self.assertRaisesRegex(local_release.LocalReleaseError, "X.Y.Z or X.Y.Z.R"):
            local_release._version_key("0.2.3.1.1")

    def test_requires_poster_and_distinct_installer_checksums(self) -> None:
        poster = self.source_release / "fantasydisk_987_announcement.png"
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
        with self.assertRaisesRegex(local_release.LocalReleaseError, "not a supported pointer"):
            local_release._update_current_project(releases, "9.8.7")

    def test_refuses_out_of_root_and_stale_current_project_pointers(self) -> None:
        releases = self.local_root / "releases"
        target = releases / "v9.8.7" / "godot-project"
        target.mkdir(parents=True)
        current = releases / "current-project"
        outside = self.root / "outside-project"
        outside.mkdir()
        local_release._create_project_pointer(
            current, outside.resolve(), os.path.relpath(outside, releases)
        )
        with self.assertRaisesRegex(local_release.LocalReleaseError, "unsafe|unexpected"):
            local_release._update_current_project(releases, "9.8.7")
        local_release._remove_project_pointer(current)

        stale_target = self.root / "stale-project"
        stale_target.mkdir()
        local_release._create_project_pointer(
            current, stale_target.resolve(), os.path.relpath(stale_target, releases)
        )
        stale_target.rmdir()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "stale"):
            local_release._update_current_project(releases, "9.8.7")
        local_release._remove_project_pointer(current)

    def test_refuses_malformed_current_project_reparse_point(self) -> None:
        releases = self.local_root / "releases"
        target = releases / "v9.8.7" / "godot-project"
        target.mkdir(parents=True)
        current = local_release._update_current_project(releases, "9.8.7")
        path_type = type(current)
        resolve = path_type.resolve

        def malformed(path: Path, strict: bool = False) -> Path:
            if path == current:
                raise OSError("malformed reparse point")
            return resolve(path, strict=strict)

        with mock.patch.object(path_type, "resolve", malformed):
            with self.assertRaisesRegex(local_release.LocalReleaseError, "malformed"):
                local_release._project_pointer_target(releases, current, "9.8.7")
        local_release._remove_project_pointer(current)

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

    def test_unsigned_channel_is_recorded_and_requires_explicit_verification(self) -> None:
        destination, manifest = self._materialize(macos_channel="unsigned")
        self.assertEqual(manifest["macos_channel"], "unsigned")
        recorded = json.loads(
            (destination / "LOCAL_RELEASE.json").read_text(encoding="utf-8")
        )
        self.assertEqual(recorded["macos_channel"], "unsigned")
        current = local_release._update_current_project(destination.parent, "9.8.7")
        local_release._register_godot(self.projects_file, current)

        verified = self._verify(macos_channel="unsigned")
        self.assertEqual(verified["macos_channel"], "unsigned")
        # The strict default never silently accepts an unsigned release.
        with self.assertRaisesRegex(local_release.LocalReleaseError, "recorded as 'unsigned'"):
            self._verify()
        # A materialized release can never be relabeled into another channel.
        with self.assertRaisesRegex(local_release.LocalReleaseError, "refusing to relabel"):
            self._materialize(macos_channel="signed")

    def test_signed_release_cannot_be_downgraded_to_unsigned_verification(self) -> None:
        destination, manifest = self._materialize()
        self.assertEqual(manifest["macos_channel"], "signed")
        current = local_release._update_current_project(destination.parent, "9.8.7")
        local_release._register_godot(self.projects_file, current)
        self._verify()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "recorded as 'signed'"):
            self._verify(macos_channel="unsigned")

    def test_macos_channel_resolution_is_explicit_and_fail_closed(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(local_release.resolve_macos_channel(), "signed")
        with mock.patch.dict(os.environ, {local_release.CHANNEL_ENV: "unsigned"}, clear=True):
            self.assertEqual(local_release.resolve_macos_channel(), "unsigned")
            self.assertEqual(local_release.resolve_macos_channel("signed"), "signed")
        with mock.patch.dict(os.environ, {local_release.CHANNEL_ENV: "adhoc"}, clear=True):
            with self.assertRaisesRegex(local_release.LocalReleaseError, "macOS channel"):
                local_release.resolve_macos_channel()
        with self.assertRaisesRegex(local_release.LocalReleaseError, "macOS channel"):
            local_release.resolve_macos_channel("notarized")

    def test_macos_verifier_checks_mapped_short_and_build_versions(self) -> None:
        app = self.root / "FantasyDisk.app"
        (app / "Contents" / "MacOS").mkdir(parents=True)
        plist = app / "Contents" / "Info.plist"
        plist.write_bytes(
            b'<?xml version="1.0" encoding="UTF-8"?>\n'
            b'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"'
            b' "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            b'<plist version="1.0"><dict>'
            b"<key>CFBundleShortVersionString</key><string>9.8.7</string>"
            b"<key>CFBundleVersion</key><string>10.8.71</string>"
            b"<key>CFBundleExecutable</key><string>FantasyDisk</string>"
            b"</dict></plist>\n"
        )
        executable = app / "Contents" / "MacOS" / "FantasyDisk"
        executable.write_bytes(b"fixture")
        executable.chmod(0o755)
        with mock.patch.object(local_release, "_run") as run_mock:
            local_release.verify_macos_app(app, "9.8.7.1", launch_smoke=False, signed=False)
        tools = [call.args[0][0] for call in run_mock.call_args_list]
        self.assertEqual(tools, ["lipo", "codesign"])
        self.assertEqual(
            run_mock.call_args_list[0].args[0],
            ["lipo", executable, "-verify_arch", "x86_64", "arm64"],
        )
        with mock.patch.object(local_release, "_run") as run_mock:
            local_release.verify_macos_app(app, "9.8.7.1", launch_smoke=False, signed=True)
        tools = [call.args[0][0] for call in run_mock.call_args_list]
        self.assertEqual(tools, ["lipo", "codesign", "xcrun", "spctl"])
        with mock.patch.object(local_release, "_run") as run_mock:
            local_release.verify_macos_app(app, "9.8.7.1", launch_smoke=True, signed=False)
        self.assertEqual(
            run_mock.call_args_list[-1].args[0],
            ["open", "-n", "-W", app, "--args", "--headless", "--quit-after", "2"],
        )
        plist.write_bytes(plist.read_bytes().replace(b"FantasyDisk", b"MissingDisk"))
        with self.assertRaisesRegex(local_release.LocalReleaseError, "CFBundleExecutable"):
            local_release.verify_macos_app(app, "9.8.7.1", launch_smoke=False, signed=False)
        plist.write_bytes(plist.read_bytes().replace(b"MissingDisk", b"FantasyDisk"))
        # The version gate stays mandatory in both channels and rejects a direct
        # four-component CFBundleVersion replacement.
        plist.write_bytes(plist.read_bytes().replace(b"10.8.71", b"9.8.7.1"))
        with self.assertRaisesRegex(local_release.LocalReleaseError, "build=10.8.71"):
            local_release.verify_macos_app(app, "9.8.7.1", launch_smoke=False, signed=False)

    def test_macos_verifier_can_use_immutable_tag_export_metadata(self) -> None:
        project = self.root / "tag-project"
        project.mkdir()
        (project / "export_presets.cfg").write_text(
            'application/short_version="0.2.4"\napplication/version="0.2.4"\n',
            encoding="utf-8",
        )
        expected = local_release._macos_bundle_versions_from_project(project)
        self.assertEqual(expected, local_release.MacOSBundleVersions("0.2.4", "0.2.4"))

    def test_build_script_macos_channel_is_fail_closed(self) -> None:
        script_path = ROOT / "tools" / "build_release.sh"
        script = script_path.read_text(encoding="utf-8")
        self.assertIn('MACOS_CHANNEL="${FANTASYDISK_MACOS_CHANNEL:-signed}"', script)
        self.assertIn('--macos-channel "${MACOS_CHANNEL}"', script)
        self.assertIn("MACOS_UPDATE_CHANNEL", script)

        if os.name == "nt":
            return

        base_env = {
            key: value
            for key, value in os.environ.items()
            if key
            not in {"MACOS_SIGN_IDENTITY", "MACOS_NOTARY_PROFILE", "FANTASYDISK_MACOS_CHANNEL"}
        }

        def run_script(extra_env: dict[str, str]) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                ["bash", str(script_path), "9.9.9"],
                cwd=ROOT,
                env={**base_env, **extra_env},
                encoding="utf-8",
                capture_output=True,
            )

        missing = run_script({})
        self.assertEqual(missing.returncode, 2)
        self.assertIn("MACOS_SIGN_IDENTITY is required", missing.stdout)

        conflicting = run_script(
            {"FANTASYDISK_MACOS_CHANNEL": "unsigned", "MACOS_SIGN_IDENTITY": "Developer ID"}
        )
        self.assertEqual(conflicting.returncode, 2)
        self.assertIn("unsigned channel refuses to run", conflicting.stdout)

        invalid = run_script({"FANTASYDISK_MACOS_CHANNEL": "adhoc"})
        self.assertEqual(invalid.returncode, 2)
        self.assertIn("must be 'signed' or 'unsigned'", invalid.stdout)

        malformed_candidate = subprocess.run(
            [
                "bash", str(script_path), "9.9.9",
                "--candidate-repository", os.fspath(self.repo),
                "--candidate-ref", "refs/heads/release-candidate",
                "--candidate-sha", "not-a-sha",
            ],
            cwd=ROOT,
            env={**base_env, "FANTASYDISK_MACOS_CHANNEL": "unsigned"},
            encoding="utf-8",
            capture_output=True,
        )
        self.assertEqual(malformed_candidate.returncode, 2)
        self.assertIn("candidate SHA must be a full 40-hex commit", malformed_candidate.stdout)

        mismatched_remote_ref = subprocess.run(
            [
                "bash", str(script_path), "9.9.9",
                "--candidate-repository", os.fspath(self.repo),
                "--candidate-ref", "refs/heads/missing-candidate",
                "--candidate-sha", "a" * 40,
            ],
            cwd=ROOT,
            env={**base_env, "FANTASYDISK_MACOS_CHANNEL": "unsigned"},
            encoding="utf-8",
            capture_output=True,
        )
        self.assertEqual(mismatched_remote_ref.returncode, 2)
        self.assertIn("candidate remote ref cannot be resolved exactly", mismatched_remote_ref.stdout)

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
        local_at = build.index(
            'python3 "${WORKTREE_DIR}/skills/codex/fantasydisk-release-director/scripts/local_release.py"'
        )
        done_at = build.index('echo "==> Готово:"')
        self.assertLess(checksum_at, local_at)
        self.assertLess(local_at, done_at)

        for name in ("release_publish.py", "telegram_publish.py"):
            source = (SCRIPT.parent / name).read_text(encoding="utf-8")
            self.assertIn("rel = verify_local_release(root, args.version)", source)
            self.assertIn('"verify", "--version"', source)
            self.assertIn('json.loads(result.stdout)["local_release"]', source)
            self.assertIn("_announcement.png", source)

        github = (SCRIPT.parent / "github_release_publish.py").read_text(encoding="utf-8")
        self.assertIn("release_dir = verify_local_release(root, args.version)", github)
        self.assertIn('"verify", "--version"', github)
        self.assertIn('json.loads(result.stdout)["local_release"]', github)
        self.assertIn('release_dir / "update-manifest.json"', github)
        self.assertIn('release_dir.glob("*.png")', github)

        self.assertNotIn('cp "${REPO_DIR}/export_presets.cfg"', build)
        self.assertIn('RELEASE_DIR="${WORKTREE_DIR}/build/release-package"', build)
        self.assertIn('"${WORKTREE_DIR}/tools/create_macos_dmg.sh"', build)
        self.assertIn('"${WORKTREE_DIR}/tools/windows_installer.nsi"', build)
        self.assertIn('"${WORKTREE_DIR}/tools/scan_release_secrets.py"', build)

        telegram = (SCRIPT.parent / "telegram_publish.py").read_text(encoding="utf-8")
        self.assertIn("ensure_telegram_release_version", telegram)
        self.assertIn("public_download_url", telegram)
        self.assertIn("CheckChatInviteRequest", telegram)
        self.assertNotIn("next((d.entity for d in client.get_dialogs()", telegram)
        self.assertIn("client.send_file(entity, poster, caption=caption", telegram)

        discord = (SCRIPT.parent / "release_publish.py").read_text(encoding="utf-8")
        self.assertIn("github_release_url(args.version)", discord)
        self.assertIn("public_download_url(root)", discord)
        self.assertIn('content_type = "image/png"', discord)
        self.assertIn("highlights = read_highlights(rel, args.version)", discord)
        self.assertIn('os.path.join(release_dir, "project", "scripts"', discord)
        self.assertNotIn("read_highlights(root, args.version", discord)
        self.assertNotIn('ap.add_argument("--highlights"', discord)
        self.assertIn("Release poster превышает лимит Discord webhook", discord)

        local_script = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('["hdiutil", "verify", dmg]', local_script)
        self.assertIn('"context:primary-signature"', local_script)


if __name__ == "__main__":
    unittest.main()
