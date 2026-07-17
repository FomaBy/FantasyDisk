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
local_release = _load("local_release")
telegram_publish = _load("telegram_publish")

VERSION_CONTRACT = json.loads(
    (ROOT / "tests" / "release_version_contract.json").read_text(encoding="utf-8")
)
SUPPORTED_RELEASE_VERSIONS = tuple(VERSION_CONTRACT["valid"])
INVALID_RELEASE_VERSIONS = tuple(VERSION_CONTRACT["invalid"])

# FAN-1249 publisher fixtures: the exact commit the publisher claims for the
# immutable release tag, and a foreign commit a racing actor could inject.
CLAIMED_COMMIT = "a" * 40
FOREIGN_COMMIT = "b" * 40


def _gh(args: list[str], returncode: int = 0, stdout: str = "", stderr: str = ""):
    return subprocess.CompletedProcess(args, returncode, stdout=stdout, stderr=stderr)


def _auth_ok():
    return _gh(["gh", "auth"], 0)


def _immutability_enforced():
    return _gh(
        ["gh", "api"], 0,
        'HTTP/2.0 200 OK\n\n{"enabled":true,"enforced_by_owner":true}',
    )


def _missing_release():
    return _gh(["gh", "api"], 1, "HTTP/2 404 Not Found\n")


def _absent_tag():
    return _gh(["gh", "api"], 0, "[]")


def _branch_head(branch: str = "main", sha: str = CLAIMED_COMMIT):
    return _gh(
        ["gh", "api"], 0,
        json.dumps({"ref": f"refs/heads/{branch}", "object": {"type": "commit", "sha": sha}}),
    )


def _tag_ref(tag: str, sha: str = CLAIMED_COMMIT):
    return _gh(
        ["gh", "api"], 0,
        json.dumps({"ref": f"refs/tags/{tag}", "object": {"type": "commit", "sha": sha}}),
    )


def _release_view(*, draft: bool, immutable: bool, url: str = "https://example.invalid/tag"):
    return _gh(
        ["gh", "release", "view"], 0,
        json.dumps({"url": url, "isDraft": draft, "isImmutable": immutable, "assets": []}),
    )


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
            for version in INVALID_RELEASE_VERSIONS:
                with self.subTest(version=version), self.assertRaises(
                    build_update_manifest.ManifestError
                ):
                    build_update_manifest.build_manifest(
                        version=version, release_dir=Path(temporary)
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
            local_release,
            telegram_publish,
        )
        for version in SUPPORTED_RELEASE_VERSIONS:
            for gate in gates:
                with self.subTest(version=version, gate=gate.__name__):
                    self.assertTrue(gate.is_valid_release_version(version))
        for invalid in INVALID_RELEASE_VERSIONS:
            for gate in gates:
                with self.subTest(version=invalid, gate=gate.__name__):
                    self.assertFalse(gate.is_valid_release_version(invalid))

    def test_publisher_refuses_existing_immutable_tag(self) -> None:
        existing = subprocess.CompletedProcess(
            ["gh", "api"], 0, stdout="HTTP/2 200 OK\n{}", stderr=""
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 existing,
             ]):
            with self.assertRaisesRegex(RuntimeError, "never overwrite"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )

    def test_publisher_refuses_existing_bare_immutable_tag(self) -> None:
        bare_tag = subprocess.CompletedProcess(
            ["gh", "api"], 0,
            stdout='[{"ref":"refs/tags/v0.2.3.1"}]', stderr=""
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 bare_tag,
             ]) as run_mock:
            with self.assertRaisesRegex(RuntimeError, "never reuse"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )
        self.assertFalse(any("create" in call.args[0] for call in run_mock.call_args_list))

    def test_publisher_fails_closed_when_bare_tag_preflight_is_unavailable(self) -> None:
        failed_preflight = subprocess.CompletedProcess(
            ["gh", "api"], 1, stdout="", stderr="network failure"
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 failed_preflight,
             ]):
            with self.assertRaisesRegex(RuntimeError, "cannot verify"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )

    def test_publisher_allows_a_missing_bare_tag(self) -> None:
        tag = "v0.2.3.1"
        created = subprocess.CompletedProcess(["gh", "release", "create"], 0, stdout="", stderr="")
        published = subprocess.CompletedProcess(["gh", "release", "edit"], 0, stdout="", stderr="")
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "_assert_release_assets", return_value="https://example.invalid/v0.2.3.1"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(tag),
                 created,
                 _tag_ref(tag),
                 published,
                 _tag_ref(tag),
                 published,
             ]) as run_mock:
            published_url = github_release_publish.publish(
                "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
            )
        self.assertEqual(published_url, "https://example.invalid/v0.2.3.1")
        self.assertTrue(any("create" in call.args[0] for call in run_mock.call_args_list))

    def test_publisher_fails_closed_when_release_preflight_returns_server_error(self) -> None:
        unavailable = subprocess.CompletedProcess(
            ["gh", "api"], 1, stdout="HTTP/2 503 Service Unavailable\n", stderr=""
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 unavailable,
             ]) as run_mock:
            with self.assertRaisesRegex(RuntimeError, "cannot verify"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )
        self.assertFalse(any("create" in call.args[0] for call in run_mock.call_args_list))

    def test_publisher_checks_draft_assets_before_publication_or_latest(self) -> None:
        tag = "v0.2.3.1"
        created = subprocess.CompletedProcess(["gh", "release", "create"], 0, stdout="", stderr="")
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "_assert_release_assets", side_effect=RuntimeError("draft assets are incomplete")), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(tag),
                 created,
                 _tag_ref(tag),
             ]) as run_mock:
            with self.assertRaisesRegex(RuntimeError, "draft assets are incomplete"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )
        self.assertFalse(
            any(call.args[0][:3] == ["gh", "release", "edit"] for call in run_mock.call_args_list)
        )

    def test_draft_asset_verification_requires_uploaded_exact_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            asset = Path(temporary) / "FantasyDisk-0.2.4-macos.dmg"
            asset.write_bytes(b"verified-byte-fixture")
            payload = {
                "url": "https://example.invalid/v0.2.4",
                "isDraft": True,
                "assets": [{
                    "name": asset.name,
                    "state": "uploaded",
                    "size": asset.stat().st_size,
                    "digest": f"sha256:{hashlib.sha256(asset.read_bytes()).hexdigest()}",
                }],
            }
            completed = subprocess.CompletedProcess(
                ["gh", "release", "view"], 0, stdout=json.dumps(payload), stderr=""
            )
            with mock.patch.object(github_release_publish, "run", return_value=completed):
                self.assertEqual(
                    github_release_publish._assert_release_assets(
                        "FomaBy/FantasyDisk-Releases", "v0.2.4", [asset], draft=True
                    ),
                    "https://example.invalid/v0.2.4",
                )
            payload["assets"][0]["state"] = "starter"
            completed = subprocess.CompletedProcess(
                ["gh", "release", "view"], 0, stdout=json.dumps(payload), stderr=""
            )
            with mock.patch.object(github_release_publish, "run", return_value=completed):
                with self.assertRaisesRegex(RuntimeError, "asset verification failed"):
                    github_release_publish._assert_release_assets(
                        "FomaBy/FantasyDisk-Releases", "v0.2.4", [asset], draft=True
                    )

    def test_verifier_rejects_malformed_checksum_entries_before_downloads(self) -> None:
        version = "0.2.4"
        repository = "FomaBy/FantasyDisk-Releases"
        names = {
            f"FantasyDisk-{version}-macos.dmg",
            f"FantasyDisk-{version}-windows-setup.exe",
            "SHA256SUMS.txt",
            f"CHANGELOG-{version}.md",
            f"fantasydisk_{version.replace('.', '')}_announcement.png",
            "update-manifest.json",
        }
        assets = [
            {
                "name": name,
                "browser_download_url": (
                    f"https://github.com/{repository}/releases/download/v{version}/{name}"
                ),
            }
            for name in names
        ]
        latest = {"tag_name": f"v{version}", "draft": False, "prerelease": False, "assets": assets}
        manifest = {
            "version": version,
            "release_url": f"https://github.com/{repository}/releases/tag/v{version}",
            "assets": {
                platform: {
                    "name": name,
                    "url": f"https://github.com/{repository}/releases/download/v{version}/{name}",
                }
                for platform, name in (
                    ("macos", f"FantasyDisk-{version}-macos.dmg"),
                    ("windows", f"FantasyDisk-{version}-windows-setup.exe"),
                )
            },
        }
        with mock.patch.object(github_release_verify, "_verify_public_tree"), \
             mock.patch.object(github_release_verify, "_json", return_value=latest), \
             mock.patch.object(github_release_verify, "_request", side_effect=[
                 json.dumps(manifest).encode("utf-8"), b"not-a-checksum\n",
             ]), \
             mock.patch.object(github_release_verify, "_sha256_download") as download:
            with self.assertRaisesRegex(github_release_verify.PublicVerificationError, "malformed"):
                github_release_verify.verify_public_distribution(
                    repository, version, Path("/unneeded-after-checksum-error")
                )
        download.assert_not_called()

    def test_checksum_parser_rejects_duplicate_missing_and_unexpected_entries(self) -> None:
        names = {"FantasyDisk-0.2.4-macos.dmg", "FantasyDisk-0.2.4-windows-setup.exe"}
        mac, windows = sorted(names)
        digest = "a" * 64
        self.assertEqual(
            github_release_verify._checksums(
                f"{digest}  {mac}\n{digest} *{windows}\n", names
            ),
            {mac: digest, windows: digest},
        )
        invalid_payloads = (
            f"{digest}  {mac}\n",
            f"{digest}  {mac}\n{digest}  {mac}\n",
            f"{digest}  {mac}\n{digest}  ../unexpected.exe\n",
            "not-a-checksum\n",
            f"{digest}  {mac}\n\n{digest}  {windows}\n",
        )
        for payload in invalid_payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(github_release_verify.PublicVerificationError):
                    github_release_verify._checksums(payload, names)

    def test_public_verifier_cannot_prune_immutable_releases(self) -> None:
        source = (SCRIPTS / "github_release_verify.py").read_text(encoding="utf-8")
        self.assertNotIn("--prune-previous", source)
        self.assertNotIn('"gh", "release", "delete"', source)


class PublisherRaceAndImmutabilityTests(unittest.TestCase):
    """FAN-1249: race-safe tag ownership and GitHub-enforced immutability.

    Every scenario drives the real publish() command sequence through a mocked
    ``run`` and asserts which external commands were and were not issued.
    """

    REPOSITORY = "FomaBy/FantasyDisk-Releases"
    VERSION = "0.2.3.1"
    TAG = "v0.2.3.1"

    def _publish(self) -> str:
        return github_release_publish.publish(
            self.REPOSITORY, self.VERSION, [], Path("CHANGELOG.md")
        )

    @staticmethod
    def _commands(run_mock) -> list[list[str]]:
        return [list(call.args[0]) for call in run_mock.call_args_list]

    def test_publisher_requires_enforced_immutability_before_any_side_effect(self) -> None:
        cases = (
            (
                "disabled-404",
                _gh(["gh", "api"], 1, "HTTP/2 404 Not Found\n"),
                "does not enforce immutable releases",
            ),
            (
                "enabled-false",
                _gh(
                    ["gh", "api"], 0,
                    'HTTP/2.0 200 OK\n\n{"enabled":false,"enforced_by_owner":false}',
                ),
                "does not enforce immutable releases",
            ),
            (
                "server-error",
                _gh(["gh", "api"], 1, "HTTP/2 503 Service Unavailable\n"),
                "cannot verify immutable release enforcement",
            ),
            (
                "multiple-statuses",
                _gh(["gh", "api"], 0, 'HTTP/2 100 Continue\nHTTP/2 200 OK\n\n{"enabled":true}'),
                "cannot verify immutable release enforcement",
            ),
            (
                "error-exit-despite-200",
                _gh(["gh", "api"], 1, 'HTTP/2 200 OK\n\n{"enabled":true}'),
                "cannot verify immutable release enforcement",
            ),
            (
                "no-body",
                _gh(["gh", "api"], 0, "HTTP/2 200 OK\n"),
                "no response body",
            ),
            (
                "malformed-json",
                _gh(["gh", "api"], 0, "HTTP/2 200 OK\n\n{not-json"),
                "invalid JSON",
            ),
        )
        for label, response, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         response,
                     ]) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error):
                        self._publish()
                # The enforcement gate is the last call: no preflight, claim,
                # create, upload, or edit may follow a failed proof.
                self.assertEqual(len(run_mock.call_args_list), 2)

    def test_racing_tag_after_preflight_blocks_publication_before_create(self) -> None:
        claim_conflict = _gh(["gh", "api"], 1, "", "HTTP 422: Reference already exists")
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 claim_conflict,
             ]) as run_mock:
            with self.assertRaisesRegex(RuntimeError, "cannot atomically claim"):
                self._publish()
        commands = self._commands(run_mock)
        self.assertFalse(any("create" in command for command in commands))
        self.assertFalse(any("edit" in command for command in commands))
        self.assertFalse(any("upload" in command for command in commands))

    def test_claim_response_must_prove_exact_tag_ownership(self) -> None:
        cases = (
            ("invalid-json", "{not-json", "invalid JSON"),
            (
                "foreign-ref",
                json.dumps({
                    "ref": "refs/tags/v9.9.9",
                    "object": {"type": "commit", "sha": CLAIMED_COMMIT},
                }),
                "unexpected reference",
            ),
            (
                "foreign-commit",
                json.dumps({
                    "ref": f"refs/tags/{self.TAG}",
                    "object": {"type": "commit", "sha": FOREIGN_COMMIT},
                }),
                "does not own the expected commit",
            ),
            (
                "non-commit-object",
                json.dumps({
                    "ref": f"refs/tags/{self.TAG}",
                    "object": {"type": "tag", "sha": CLAIMED_COMMIT},
                }),
                "does not own the expected commit",
            ),
        )
        for label, stdout, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         _missing_release(),
                         _absent_tag(),
                         _branch_head(),
                         _gh(["gh", "api"], 0, stdout),
                     ]) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error):
                        self._publish()
                commands = self._commands(run_mock)
                self.assertFalse(any("create" in command for command in commands))
                self.assertFalse(any("edit" in command for command in commands))

    def test_ambiguous_branch_head_blocks_before_tag_claim(self) -> None:
        cases = (
            (
                "foreign-ref",
                {"ref": "refs/heads/other", "object": {"type": "commit", "sha": CLAIMED_COMMIT}},
                "different reference",
            ),
            (
                "non-commit",
                {"ref": "refs/heads/main", "object": {"type": "tag", "sha": CLAIMED_COMMIT}},
                "exact commit",
            ),
            (
                "short-sha",
                {"ref": "refs/heads/main", "object": {"type": "commit", "sha": "abc123"}},
                "exact commit",
            ),
            ("missing-object", {"ref": "refs/heads/main"}, "exact commit"),
        )
        for label, payload, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         _missing_release(),
                         _absent_tag(),
                         _gh(["gh", "api"], 0, json.dumps(payload)),
                     ]) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error):
                        self._publish()
                commands = self._commands(run_mock)
                self.assertFalse(any("POST" in command for command in commands))
                self.assertFalse(any("create" in command for command in commands))

    def test_foreign_tag_after_create_blocks_publication_edit(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "_assert_release_assets") as assets_mock, \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG, FOREIGN_COMMIT),
             ]) as run_mock:
            with self.assertRaisesRegex(
                RuntimeError, "no longer points at the claimed release commit"
            ):
                self._publish()
        assets_mock.assert_not_called()
        commands = self._commands(run_mock)
        self.assertFalse(any("edit" in command for command in commands))

    def test_foreign_tag_after_publication_blocks_latest(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        published = _gh(["gh", "release", "edit"], 0)
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "_assert_release_assets", return_value="https://example.invalid/v0.2.3.1"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 published,
                 _tag_ref(self.TAG, FOREIGN_COMMIT),
             ]) as run_mock:
            with self.assertRaisesRegex(
                RuntimeError, "no longer points at the claimed release commit"
            ):
                self._publish()
        commands = self._commands(run_mock)
        self.assertFalse(any(command[-1] == "--latest" for command in commands))

    def test_non_immutable_public_release_blocks_latest_in_real_sequence(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        published = _gh(["gh", "release", "edit"], 0)
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 _release_view(draft=True, immutable=False),
                 published,
                 _release_view(draft=False, immutable=False),
             ]) as run_mock:
            with self.assertRaisesRegex(RuntimeError, "not GitHub-enforced immutable"):
                self._publish()
        commands = self._commands(run_mock)
        self.assertFalse(any(command[-1] == "--latest" for command in commands))

    def test_public_release_asset_check_requires_github_immutability(self) -> None:
        payload = {
            "url": "https://example.invalid/v0.2.3.1",
            "isDraft": False,
            "isImmutable": False,
            "assets": [],
        }
        with mock.patch.object(
            github_release_publish, "run",
            return_value=_gh(["gh", "release", "view"], 0, json.dumps(payload)),
        ):
            with self.assertRaisesRegex(RuntimeError, "not GitHub-enforced immutable"):
                github_release_publish._assert_release_assets(
                    self.REPOSITORY, self.TAG, [], draft=False
                )
        payload["isImmutable"] = True
        with mock.patch.object(
            github_release_publish, "run",
            return_value=_gh(["gh", "release", "view"], 0, json.dumps(payload)),
        ):
            self.assertEqual(
                github_release_publish._assert_release_assets(
                    self.REPOSITORY, self.TAG, [], draft=False
                ),
                "https://example.invalid/v0.2.3.1",
            )

    def test_unused_tag_happy_path_executes_full_fail_closed_sequence(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        published = _gh(["gh", "release", "edit"], 0)
        url = f"https://github.com/{self.REPOSITORY}/releases/tag/{self.TAG}"
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 _release_view(draft=True, immutable=False, url=url),
                 published,
                 _release_view(draft=False, immutable=True, url=url),
                 _tag_ref(self.TAG),
                 published,
             ]) as run_mock:
            self.assertEqual(self._publish(), url)
        commands = self._commands(run_mock)
        claim_at = next(
            index for index, command in enumerate(commands)
            if "--method" in command and "POST" in command
        )
        create_at = next(
            index for index, command in enumerate(commands)
            if command[:3] == ["gh", "release", "create"]
        )
        publish_at = next(
            index for index, command in enumerate(commands) if "--draft=false" in command
        )
        latest_at = next(
            index for index, command in enumerate(commands) if command[-1] == "--latest"
        )
        self.assertLess(claim_at, create_at)
        self.assertLess(create_at, publish_at)
        self.assertLess(publish_at, latest_at)
        self.assertEqual(latest_at, len(commands) - 1)
        self.assertIn(f"ref=refs/tags/{self.TAG}", commands[claim_at])
        self.assertIn(f"sha={CLAIMED_COMMIT}", commands[claim_at])
        # Release create pins the exact claimed commit, not a drifting branch.
        self.assertIn("--target", commands[create_at])
        self.assertIn(CLAIMED_COMMIT, commands[create_at])

    def test_supported_publisher_path_has_no_destructive_commands(self) -> None:
        source = (SCRIPTS / "github_release_publish.py").read_text(encoding="utf-8")
        for forbidden in (
            '"gh", "release", "delete"',
            "--clobber",
            '"DELETE"',
            "force=true",
            '"--force"',
        ):
            self.assertNotIn(forbidden, source)


class PublicVerifierAssetContractTests(unittest.TestCase):
    """FAN-1257: ambiguous or malformed public API asset lists must fail closed."""

    VERSION = "0.2.4"
    REPOSITORY = "FomaBy/FantasyDisk-Releases"
    TAG = "v0.2.4"

    def _write_release_fixture(self, release: Path) -> tuple[dict[str, bytes], list[dict]]:
        version = self.VERSION
        installer_names = (
            f"FantasyDisk-{version}-macos.dmg",
            f"FantasyDisk-{version}-windows-setup.exe",
        )
        payloads = {
            name: f"public-bytes:{name}".encode("utf-8")
            for name in (
                *installer_names,
                f"CHANGELOG-{version}.md",
                f"fantasydisk_{version.replace('.', '')}_announcement.png",
            )
        }
        manifest = {
            "version": version,
            "release_url": f"https://github.com/{self.REPOSITORY}/releases/tag/{self.TAG}",
            "assets": {
                platform: {
                    "name": name,
                    "url": (
                        f"https://github.com/{self.REPOSITORY}/releases/download/{self.TAG}/{name}"
                    ),
                    "size": len(payloads[name]),
                    "sha256": hashlib.sha256(payloads[name]).hexdigest(),
                }
                for platform, name in zip(("macos", "windows"), installer_names)
            },
        }
        payloads["update-manifest.json"] = json.dumps(manifest).encode("utf-8")
        payloads["SHA256SUMS.txt"] = "".join(
            f"{hashlib.sha256(payloads[name]).hexdigest()}  {name}\n"
            for name in installer_names
        ).encode("utf-8")
        for name, data in payloads.items():
            (release / name).write_bytes(data)
        api_assets = [
            {
                "name": name,
                "browser_download_url": self._canonical_asset_url(name),
            }
            for name in sorted(payloads)
        ]
        return payloads, api_assets

    def _canonical_asset_url(self, name: str) -> str:
        return f"https://github.com/{self.REPOSITORY}/releases/download/{self.TAG}/{name}"

    def _run_verifier(self, release: Path, payloads: dict[str, bytes], api_assets, error=None):
        latest = {
            "tag_name": self.TAG,
            "draft": False,
            "prerelease": False,
            "assets": api_assets,
        }
        manifest_url = (
            f"https://github.com/{self.REPOSITORY}/releases/latest/download/update-manifest.json"
        )

        def fake_request(url: str) -> bytes:
            if url == manifest_url:
                return payloads["update-manifest.json"]
            if url == self._canonical_asset_url("SHA256SUMS.txt"):
                return payloads["SHA256SUMS.txt"]
            raise AssertionError(f"unexpected public request: {url}")

        def fake_download(url: str) -> tuple[int, str]:
            data = payloads[url.rsplit("/", 1)[-1]]
            return len(data), hashlib.sha256(data).hexdigest()

        with mock.patch.object(github_release_verify, "_verify_public_tree"), \
             mock.patch.object(github_release_verify, "_json", return_value=latest), \
             mock.patch.object(
                 github_release_verify, "_request", side_effect=fake_request
             ) as request, \
             mock.patch.object(
                 github_release_verify, "_sha256_download", side_effect=fake_download
             ) as download:
            if error is None:
                report = github_release_verify.verify_public_distribution(
                    self.REPOSITORY, self.VERSION, release
                )
            else:
                report = None
                with self.assertRaisesRegex(
                    github_release_verify.PublicVerificationError, error
                ):
                    github_release_verify.verify_public_distribution(
                        self.REPOSITORY, self.VERSION, release
                    )
        return report, request, download

    def test_full_verifier_accepts_exactly_six_unique_assets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            report, _request, download = self._run_verifier(release, payloads, api_assets)
        self.assertTrue(report["ok"])
        self.assertEqual(report["repository"], self.REPOSITORY)
        self.assertEqual(
            report["assets"]["macos"]["sha256"],
            hashlib.sha256(payloads[f"FantasyDisk-{self.VERSION}-macos.dmg"]).hexdigest(),
        )
        self.assertEqual(
            report["assets"]["windows"]["size"],
            len(payloads[f"FantasyDisk-{self.VERSION}-windows-setup.exe"]),
        )
        self.assertEqual(download.call_count, 6)

    def test_verifier_rejects_duplicate_api_asset_names_before_downloads(self) -> None:
        mac = f"FantasyDisk-{self.VERSION}-macos.dmg"
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            duplicate = {
                "name": mac,
                "browser_download_url": "https://example.invalid/other/location",
            }
            seven_entries = api_assets + [duplicate]
            self.assertEqual(len(seven_entries), 7)
            report, request, download = self._run_verifier(
                release, payloads, seven_entries, error="duplicate asset name"
            )
        self.assertIsNone(report)
        request.assert_not_called()
        download.assert_not_called()

    def test_verifier_rejects_malformed_or_empty_api_asset_entries_before_downloads(self) -> None:
        mac = f"FantasyDisk-{self.VERSION}-macos.dmg"
        url = self._canonical_asset_url(mac)
        cases = (
            ("assets-not-a-list", {"name": mac}, "must be a list"),
            ("entry-not-an-object", mac, "not an object"),
            ("missing-name", {"browser_download_url": url}, "non-empty string"),
            ("empty-name", {"name": "", "browser_download_url": url}, "non-empty string"),
            (
                "whitespace-only-name",
                {"name": "   ", "browser_download_url": url},
                "non-empty string",
            ),
            ("non-string-name", {"name": 7, "browser_download_url": url}, "non-empty string"),
            ("missing-url", {"name": mac}, "non-empty string"),
            ("empty-url", {"name": mac, "browser_download_url": ""}, "non-empty string"),
            (
                "whitespace-only-url",
                {"name": mac, "browser_download_url": "   "},
                "non-empty string",
            ),
            (
                "non-string-url",
                {"name": mac, "browser_download_url": None},
                "non-empty string",
            ),
        )
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            for label, mutation, error in cases:
                with self.subTest(case=label):
                    if label == "assets-not-a-list":
                        mutated = mutation
                    else:
                        mutated = [mutation] + [
                            entry for entry in api_assets if entry["name"] != mac
                        ]
                    report, request, download = self._run_verifier(
                        release, payloads, mutated, error=error
                    )
                    self.assertIsNone(report)
                    request.assert_not_called()
                    download.assert_not_called()

    def test_verifier_rejects_missing_and_unexpected_asset_names_before_downloads(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            without_sums = [
                entry for entry in api_assets if entry["name"] != "SHA256SUMS.txt"
            ]
            unexpected = api_assets + [{
                "name": f"FantasyDisk-{self.VERSION}-linux.AppImage",
                "browser_download_url": "https://example.invalid/assets/linux",
            }]
            for label, mutated, error in (
                ("missing-required", without_sums, "missing required assets"),
                ("unexpected-name", unexpected, "unexpected asset"),
            ):
                with self.subTest(case=label):
                    report, request, download = self._run_verifier(
                        release, payloads, mutated, error=error
                    )
                    self.assertIsNone(report)
                    request.assert_not_called()
                    download.assert_not_called()

    def test_verifier_rejects_whitespace_only_asset_urls_before_any_network_operations(self) -> None:
        # FAN-1261: a browser_download_url of only whitespace is an ambiguous API
        # record and must fail the raw-assets preflight for every required asset,
        # with zero downstream requests or downloads.
        required = {
            f"FantasyDisk-{self.VERSION}-macos.dmg",
            f"FantasyDisk-{self.VERSION}-windows-setup.exe",
            "SHA256SUMS.txt",
            f"CHANGELOG-{self.VERSION}.md",
            f"fantasydisk_{self.VERSION.replace('.', '')}_announcement.png",
            "update-manifest.json",
        }
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            self.assertEqual({entry["name"] for entry in api_assets}, required)
            for target in sorted(required):
                with self.subTest(asset=target):
                    mutated = [
                        {**entry, "browser_download_url": "   "}
                        if entry["name"] == target
                        else dict(entry)
                        for entry in api_assets
                    ]
                    report, request, download = self._run_verifier(
                        release, payloads, mutated, error="non-empty string"
                    )
                    self.assertIsNone(report)
                    request.assert_not_called()
                    download.assert_not_called()

    def test_verifier_rejects_non_canonical_asset_urls_before_downloads(self) -> None:
        # FAN-1261: every asset URL must be the exact canonical HTTPS release
        # download URL for this repository, tag, and asset name.
        mac = f"FantasyDisk-{self.VERSION}-macos.dmg"
        canonical = self._canonical_asset_url(mac)
        bad_urls = (
            canonical.replace("https://", "http://", 1),
            f"https://example.invalid/assets/{mac}",
            f"https://github.com/other/repository/releases/download/{self.TAG}/{mac}",
            f"https://github.com/{self.REPOSITORY}/releases/download/v9.9.9/{mac}",
            self._canonical_asset_url("SHA256SUMS.txt"),
        )
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            for bad_url in bad_urls:
                with self.subTest(url=bad_url):
                    mutated = [
                        {**entry, "browser_download_url": bad_url}
                        if entry["name"] == mac
                        else dict(entry)
                        for entry in api_assets
                    ]
                    report, request, download = self._run_verifier(
                        release, payloads, mutated, error="canonical"
                    )
                    self.assertIsNone(report)
                    request.assert_not_called()
                    download.assert_not_called()

    def test_verifier_rejects_checksum_mismatch_for_installer_bytes(self) -> None:
        mac = f"FantasyDisk-{self.VERSION}-macos.dmg"
        windows = f"FantasyDisk-{self.VERSION}-windows-setup.exe"
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            payloads, api_assets = self._write_release_fixture(release)
            corrupted = (
                f"{'0' * 64}  {mac}\n"
                f"{hashlib.sha256(payloads[windows]).hexdigest()}  {windows}\n"
            ).encode("utf-8")
            payloads["SHA256SUMS.txt"] = corrupted
            (release / "SHA256SUMS.txt").write_bytes(corrupted)
            report, _request, download = self._run_verifier(
                release,
                payloads,
                api_assets,
                error="public installer bytes do not match durable release",
            )
        self.assertIsNone(report)
        download.assert_called()


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
        documents = ReleaseDocumentationConsistencyTests.read_documents()
        self.assertEqual(
            ReleaseDocumentationConsistencyTests.delivery_contract_errors(documents),
            [],
        )


class ReleaseDocumentationConsistencyTests(unittest.TestCase):
    """FAN-1235: release instructions must preserve the hotfix delivery contract."""

    SKILL = Path("skills") / "codex" / "fantasydisk-release-director" / "SKILL.md"
    RELEASE_VERSIONING = Path("docs") / "process" / "release_versioning.md"
    BRANCHING = Path("docs") / "process" / "versioning_and_branching.md"
    TELEGRAM_SETUP = Path("docs") / "release_telegram_setup.md"
    GAME_UPDATES = Path("docs") / "process" / "game_updates.md"
    CURRENT_STATE = Path("docs") / "design" / "current_game_state.md"
    README = Path("README.md")
    AGENTS = Path("AGENTS.md")

    # These are operational examples, not the SemVer/hotfix policy examples that
    # intentionally retain X.Y.Z and X.Y.Z.R terminology.
    OPERATIONAL_PLACEHOLDERS = {
        SKILL: (
            "## [<version>] — YYYY-MM-DD",
            "fantasydisk_<version>_announcement.png",
            "exact release commit as `v<version>`",
            "CHANGELOG-<version>.md",
            "<local_root>/releases/v<version>/",
        ),
        RELEASE_VERSIONING: (
            "тегом v<version>",
            "## [<version>] — дата",
            "releases/v<version>/CHANGELOG-<version>.md",
            "exact tag `v<version>`",
            "FantasyDisk-<version>-macos.dmg",
            "FantasyDisk-<version>-windows-setup.exe",
            "tools/build_release.sh <version>",
            "git worktree add --detach /tmp/... v<version>",
        ),
        TELEGRAM_SETUP: ("--version <version>",),
    }
    OPERATIONAL_XYZ_ONLY = {
        SKILL: (
            "## [X.Y.Z] — YYYY-MM-DD",
            "fantasydisk_XYZ_announcement.png",
            "exact release commit as `vX.Y.Z`",
            "CHANGELOG-X.Y.Z.md",
            "<local_root>/releases/vX.Y.Z/",
        ),
        RELEASE_VERSIONING: (
            "тегом vX.Y.Z",
            "## [X.Y.Z] — дата",
            "releases/vX.Y.Z/",
            "CHANGELOG-X.Y.Z.md",
            "exact tag `vX.Y.Z`",
            "FantasyDisk-X.Y.Z-macos.dmg",
            "FantasyDisk-X.Y.Z-windows-setup.exe",
            "tools/build_release.sh X.Y.Z",
            "git worktree add --detach /tmp/... vX.Y.Z",
        ),
        TELEGRAM_SETUP: ("--version X.Y.Z",),
    }
    DELIVERY_CONTRACTS = {
        GAME_UPDATES: (
            "канонический источник клиентских обновлений — отдельный публичный binary-only репозиторий [FomaBy/FantasyDisk-Releases]",
            "Telegram обязателен для каждого stable release: dry-run, затем отправка poster, DMG, Windows Setup и SHA256SUMS из verified durable path.",
            "После успешной Telegram delivery опубликовать Discord news с Telegram download link и ссылкой на public GitHub latest release.",
        ),
        RELEASE_VERSIONING: (
            "public binary-only repository `FomaBy/FantasyDisk-Releases`",
            "Каждый stable release обязательно отправляется в Telegram (poster, DMG, Windows Setup, SHA256SUMS), после чего Discord публикует Telegram download link и GitHub release URL.",
        ),
        TELEGRAM_SETUP: (
            "Telegram — обязательный канал файловой доставки, а public binary-only GitHub repository `FomaBy/FantasyDisk-Releases` — канонический источник updater manifest и latest downloads.",
            "Telegram получает release poster, macOS DMG, Windows Setup и `SHA256SUMS.txt`; затем Discord публикует player-facing новость с Telegram download link.",
        ),
    }
    MACOS_MAPPING_CONTRACTS = {
        SKILL: (
            "(X+1).Y.(10*Z+R)",
            "MAJOR=0…9998",
            "MINOR=0…99",
            "PATCH=0…9",
            "HOTFIX=0…9",
        ),
        RELEASE_VERSIONING: (
            "(X+1).Y.(10*Z+R)",
            "MAJOR=0…9998",
            "MINOR=0…99",
            "PATCH=0…9",
            "HOTFIX=0…9",
        ),
        GAME_UPDATES: (
            "(X+1).Y.(10*Z+R)",
            "MAJOR=0…9998",
            "MINOR=0…99",
            "PATCH=0…9",
            "HOTFIX=0…9",
            "1.2.30 < 1.2.31 < 1.2.40",
        ),
    }
    ENTRY_POINT_VERSIONING = {
        README: (
            "Текущий опубликованный stable release: `0.2.4`",
            "технический релиз с изменёнными байтами и без новых игровых функций использует `X.Y.Z.R`",
            "tag `v<version>` и опубликованные байты immutable",
        ),
        CURRENT_STATE: (
            "техническое исправление изменённых байтов без нового игрового поведения использует `X.Y.Z.R`",
            "immutable релизы — теги `v<version>`",
            "FAN-1128/FAN-1210 завершён публикацией `0.2.4`",
        ),
        AGENTS: (
            "`main` contains the current published stable release `0.2.4`.",
            "byte-changing technical fixes use `X.Y.Z.R`.",
            "Every `v<version>` tag and its published bytes are immutable.",
            "historical release freeze FAN-1128/FAN-1210 завершён.",
        ),
    }

    @staticmethod
    def normalize(document: str) -> str:
        return " ".join(document.split())

    @classmethod
    def read_documents(cls) -> dict[Path, str]:
        paths = set(cls.OPERATIONAL_PLACEHOLDERS) | set(cls.DELIVERY_CONTRACTS) | set(cls.MACOS_MAPPING_CONTRACTS) | {
            cls.BRANCHING,
            cls.CURRENT_STATE,
        } | set(cls.ENTRY_POINT_VERSIONING)
        return {relative: (ROOT / relative).read_text(encoding="utf-8") for relative in paths}

    @classmethod
    def operational_version_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, placeholders in cls.OPERATIONAL_PLACEHOLDERS.items():
            document = documents[relative]
            for placeholder in placeholders:
                if placeholder not in document:
                    errors.append(f"{relative}: missing operational placeholder {placeholder}")
            for xyz_only in cls.OPERATIONAL_XYZ_ONLY[relative]:
                if xyz_only in document:
                    errors.append(f"{relative}: X.Y.Z-only operational example {xyz_only}")
        return errors

    @classmethod
    def delivery_contract_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.DELIVERY_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if clause not in document:
                    errors.append(f"{relative}: missing delivery contract clause {clause}")
        return errors

    @classmethod
    def macos_mapping_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.MACOS_MAPPING_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if clause not in document:
                    errors.append(f"{relative}: missing canonical macOS mapping clause {clause}")
            if "(X+1).Y.(1000*Z+R)" in document:
                errors.append(f"{relative}: contains stale macOS mapping radix")
        return errors

    @classmethod
    def published_release_lifecycle_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        required = {
            cls.CURRENT_STATE: "Текущий опубликованный stable release: `0.2.4`",
            cls.RELEASE_VERSIONING: "его historical release freeze в рамках FAN-1128/FAN-1210 завершён.",
            cls.BRANCHING: "Release freeze FAN-1128/FAN-1210 завершён публикацией `0.2.4`; новые продуктовые изменения идут в следующую SemVer-версию.",
        }
        forbidden = {
            cls.BRANCHING: (
                "На время FAN-1128 действует release freeze:",
                "новые продуктовые изменения не входят в 0.2.3",
            ),
            cls.RELEASE_VERSIONING: ("`0.2.4` готовится из `dev`",),
        }
        for relative, clause in required.items():
            if clause not in cls.normalize(documents[relative]):
                errors.append(f"{relative}: missing published-release lifecycle clause {clause}")
        for relative, stale_clauses in forbidden.items():
            for clause in stale_clauses:
                if clause in cls.normalize(documents[relative]):
                    errors.append(f"{relative}: stale active/frozen release clause {clause}")
        return errors

    @classmethod
    def entry_point_versioning_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.ENTRY_POINT_VERSIONING.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if cls.normalize(clause) not in document:
                    errors.append(f"{relative}: missing entry-point versioning clause {clause}")
        return errors

    def test_operational_examples_support_both_release_version_shapes(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.operational_version_errors(documents), [])

        mutations = (
            (self.SKILL, "## [<version>] — YYYY-MM-DD", "## [X.Y.Z] — YYYY-MM-DD"),
            (self.RELEASE_VERSIONING, "releases/v<version>/", "releases/vX.Y.Z/"),
            (self.TELEGRAM_SETUP, "--version <version>", "--version X.Y.Z"),
        )
        for relative, expected, xyz_only in mutations:
            with self.subTest(document=str(relative), mutation=xyz_only):
                mutated = dict(documents)
                mutated[relative] = mutated[relative].replace(expected, xyz_only, 1)
                self.assertTrue(
                    any(xyz_only in error for error in self.operational_version_errors(mutated))
                )

    def test_delivery_contract_is_semantic_and_rejects_token_only_mutations(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.delivery_contract_errors(documents), [])

        mutations = (
            (self.GAME_UPDATES, "канонический источник клиентских обновлений", "дополнительный источник клиентских обновлений"),
            (self.RELEASE_VERSIONING, "Каждый stable release обязательно отправляется", "Каждый stable release может отправляться"),
            (self.TELEGRAM_SETUP, "обязательный канал файловой доставки", "дополнительный канал файловой доставки"),
        )
        for relative, expected, replacement in mutations:
            with self.subTest(document=str(relative), mutation=replacement):
                mutated = dict(documents)
                mutated[relative] = mutated[relative].replace(expected, replacement, 1)
                self.assertNotEqual(self.delivery_contract_errors(mutated), [])

    def test_macos_mapping_contract_is_canonical_in_every_release_instruction(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.macos_mapping_errors(documents), [])

        for relative in self.MACOS_MAPPING_CONTRACTS:
            with self.subTest(document=str(relative)):
                mutated = dict(documents)
                mutated[relative] = mutated[relative].replace(
                    "(X+1).Y.(10*Z+R)", "(X+1).Y.(1000*Z+R)", 1
                )
                errors = self.macos_mapping_errors(mutated)
                self.assertTrue(any("canonical macOS mapping" in error for error in errors))
                self.assertTrue(any("stale macOS mapping radix" in error for error in errors))

    def test_published_024_cannot_be_described_as_an_active_frozen_release(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.published_release_lifecycle_errors(documents), [])

        stale = "На время FAN-1128 действует release freeze: новые продуктовые изменения не входят в 0.2.3."
        mutated = dict(documents)
        mutated[self.BRANCHING] = mutated[self.BRANCHING].replace(
            "Release freeze FAN-1128/FAN-1210 завершён публикацией `0.2.4`;\nновые продуктовые изменения идут в следующую SemVer-версию.",
            stale,
            1,
        )
        errors = self.published_release_lifecycle_errors(mutated)
        self.assertTrue(any("published-release lifecycle" in error for error in errors))
        self.assertTrue(any("stale active/frozen" in error for error in errors))

    def test_entry_point_docs_describe_current_hotfix_and_immutable_contract(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.entry_point_versioning_errors(documents), [])

        mutated = dict(documents)
        mutated[self.AGENTS] = mutated[self.AGENTS].replace(
            "`main` contains the current published stable release `0.2.4`.",
            "`main` is the stable `0.1` line.",
            1,
        )
        errors = self.entry_point_versioning_errors(mutated)
        self.assertTrue(any("entry-point versioning" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
