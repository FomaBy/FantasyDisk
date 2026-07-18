from __future__ import annotations

import hashlib
import importlib.util
import json
import re
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


def _ruleset_list(entries: list[dict] | None = None):
    if entries is None:
        entries = [
            {"id": 42, "name": "release-tags", "target": "tag", "enforcement": "active"}
        ]
    return _gh(["gh", "api"], 0, json.dumps(entries))


_MISSING_RULESET_ID = object()


def _ruleset_detail(
    *,
    ruleset_id: object = 42,
    include: tuple[str, ...] = ("refs/tags/v*",),
    exclude: tuple[str, ...] = (),
    rules: tuple[str, ...] = ("update", "deletion"),
    bypass: tuple[dict, ...] = (),
    target: str = "tag",
    enforcement: str = "active",
):
    payload = {
        "target": target,
        "enforcement": enforcement,
        "bypass_actors": list(bypass),
        "conditions": {"ref_name": {"include": list(include), "exclude": list(exclude)}},
        "rules": [{"type": rule} for rule in rules],
    }
    if ruleset_id is not _MISSING_RULESET_ID:
        payload["id"] = ruleset_id
    return _gh(
        ["gh", "api"], 0,
        json.dumps(payload),
    )


# FAN-1271 sentinel: the detail response omits bypass_actors entirely, as
# GitHub does for callers without write access to the ruleset.
_HIDDEN_BYPASS_ACTORS = object()


def _ruleset_detail_with_bypass_shape(bypass_actors: object):
    """FAN-1271 fixture: covering tag ruleset with a raw bypass_actors shape."""
    payload = {
        "id": 42,
        "target": "tag",
        "enforcement": "active",
        "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}},
        "rules": [{"type": "update"}, {"type": "deletion"}],
    }
    if bypass_actors is not _HIDDEN_BYPASS_ACTORS:
        payload["bypass_actors"] = bypass_actors
    return _gh(["gh", "api"], 0, json.dumps(payload))


def _tag_protection_ok():
    """FAN-1265 preflight pair: tag ruleset listing plus a covering detail."""
    return (_ruleset_list(), _ruleset_detail())


def _tag_probe(tag: str, sha: str = CLAIMED_COMMIT):
    """FAN-1272 fixture: best-effort --include tag re-read with HTTP status."""
    body = json.dumps({"ref": f"refs/tags/{tag}", "object": {"type": "commit", "sha": sha}})
    return _gh(["gh", "api"], 0, f"HTTP/2 200 OK\n\n{body}")


def _latest_release(tag_name: str):
    """FAN-1272 fixture: repos/<repo>/releases/latest payload."""
    return _gh(["gh", "api"], 0, json.dumps({"tag_name": tag_name}))


# FAN-1276 fixtures: the sole-writer boundary the publisher proves before the
# first external side effect and re-proves immediately before the public edit.
PUBLISHER_LOGIN = "FomaBy"


def _publisher_identity(login: str = PUBLISHER_LOGIN):
    return _gh(["gh", "api"], 0, json.dumps({"login": login}))


def _user_owned_repository(login: str = PUBLISHER_LOGIN, owner_type: str = "User"):
    return _gh(
        ["gh", "api"], 0, json.dumps({"owner": {"login": login, "type": owner_type}})
    )


def _sole_collaborator(login: str = PUBLISHER_LOGIN):
    return _gh(["gh", "api"], 0, json.dumps([{"login": login}]))


def _no_invitations():
    return _gh(["gh", "api"], 0, "[]")


def _no_deploy_keys():
    return _gh(["gh", "api"], 0, "[]")


def _no_installations():
    return _gh(["gh", "api"], 0, json.dumps({"total_count": 0, "installations": []}))


def _sole_write_access_ok(login: str = PUBLISHER_LOGIN):
    """FAN-1276 proof sextet: authenticated owner with no other write path."""
    return (
        _publisher_identity(login),
        _user_owned_repository(login),
        _sole_collaborator(login),
        _no_invitations(),
        _no_deploy_keys(),
        _no_installations(),
    )


def _classify_publisher_commands(
    commands: list[list[str]],
) -> dict[str, list[list[str]]]:
    """Classify every command shape that can modify the distribution release."""
    write_commands: list[list[str]] = []
    release_write_subcommands = {"create", "upload", "edit", "delete"}
    read_only_http_methods = {"GET", "HEAD", "OPTIONS"}
    for command in commands:
        if command[:2] == ["gh", "api"]:
            method = "GET"
            if "--method" in command:
                method_at = command.index("--method") + 1
                if method_at < len(command):
                    method = command[method_at].upper()
            if method not in read_only_http_methods:
                write_commands.append(command)
        elif (
            command[:2] == ["gh", "release"]
            and len(command) > 2
            and command[2] in release_write_subcommands
        ):
            write_commands.append(command)
    return {"write_commands": write_commands}


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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(tag),
                 created,
                 _tag_ref(tag),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
            asset = Path(temporary) / "zero-byte-fixture.dmg"
            asset.write_bytes(b"")
            expected_digest = f"sha256:{hashlib.sha256(asset.read_bytes()).hexdigest()}"
            payload = {
                "url": "https://example.invalid/v0.2.4",
                "isDraft": True,
                "assets": [{
                    "name": asset.name,
                    "state": "uploaded",
                    "size": 0,
                    "digest": expected_digest,
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
            for malformed_size in (
                True,
                False,
                0.0,
                None,
                "0",
                -1,
                1,
            ):
                with self.subTest(size=repr(malformed_size)):
                    malformed_payload = dict(
                        payload,
                        assets=[dict(payload["assets"][0], size=malformed_size)],
                    )
                    completed = subprocess.CompletedProcess(
                        ["gh", "release", "view"],
                        0,
                        stdout=json.dumps(malformed_payload),
                        stderr="",
                    )
                    with mock.patch.object(
                        github_release_publish, "run", return_value=completed
                    ):
                        with self.assertRaisesRegex(
                            RuntimeError, "asset verification failed"
                        ) as error:
                            github_release_publish._assert_release_assets(
                                "FomaBy/FantasyDisk-Releases",
                                "v0.2.4",
                                [asset],
                                draft=True,
                            )
                    message = str(error.exception)
                    self.assertNotIn(json.dumps(malformed_size), message)
                    self.assertNotIn(str(asset), message)
                    self.assertNotIn(expected_digest, message)
                    self.assertNotIn(json.dumps(malformed_payload), message)
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
                         *_tag_protection_ok(),
                         *_sole_write_access_ok(),
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
                         *_tag_protection_ok(),
                         *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 _release_view(draft=True, immutable=False),
                 *_sole_write_access_ok(),
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
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 _release_view(draft=True, immutable=False, url=url),
                 *_sole_write_access_ok(),
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
        # Release create pins the exact claimed commit, not a drifting branch,
        # and refuses to implicitly recreate a deleted claimed tag.
        self.assertIn("--target", commands[create_at])
        self.assertIn(CLAIMED_COMMIT, commands[create_at])
        self.assertIn("--verify-tag", commands[create_at])
        # The tag ruleset boundary is proven before the first side effect.
        ruleset_at = next(
            index for index, command in enumerate(commands)
            if command[:2] == ["gh", "api"] and "rulesets" in command[-1]
        )
        self.assertLess(ruleset_at, claim_at)
        # A final identity check runs after draft verification, immediately
        # before the release becomes public.
        draft_view_at = next(
            index for index, command in enumerate(commands)
            if command[:3] == ["gh", "release", "view"]
        )
        identity_checks = [
            index for index, command in enumerate(commands)
            if command[:2] == ["gh", "api"]
            and command[-1].endswith(f"git/ref/tags/{self.TAG}")
        ]
        self.assertTrue(
            any(draft_view_at < index < publish_at for index in identity_checks)
        )
        # FAN-1276: the sole-writer boundary is proven before the first side
        # effect and re-proven after draft verification, and the draft assets
        # are re-verified again immediately before the public edit.
        ownership_checks = [
            index for index, command in enumerate(commands)
            if command[:2] == ["gh", "api"] and command[-1] == "user"
        ]
        self.assertTrue(any(index < claim_at for index in ownership_checks))
        self.assertTrue(
            any(draft_view_at < index < publish_at for index in ownership_checks)
        )
        draft_views = [
            index for index, command in enumerate(commands)
            if command[:3] == ["gh", "release", "view"] and index < publish_at
        ]
        self.assertEqual(len(draft_views), 2)
        # The byte-exact re-verification is the last read before the edit.
        last_ownership_check = max(
            index for index in ownership_checks if index < publish_at
        )
        self.assertLess(last_ownership_check, draft_views[-1])

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


class PublisherClaimContinuityTests(unittest.TestCase):
    """FAN-1265: the atomically claimed tag stays provably ours end-to-end.

    Every scenario drives the real publish() command sequence through a mocked
    ``run`` and asserts that no impermissible public state can be produced —
    not merely that ``--latest`` is withheld.
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

    def test_tag_ruleset_pattern_matching_is_tag_scoped(self) -> None:
        matches = github_release_publish._tag_ruleset_pattern_matches
        self.assertTrue(matches("~ALL", self.TAG))
        self.assertTrue(matches("refs/tags/v*", self.TAG))
        self.assertTrue(matches(f"refs/tags/{self.TAG}", self.TAG))
        self.assertTrue(matches("v*", self.TAG))
        self.assertFalse(matches("refs/heads/*", self.TAG))
        self.assertFalse(matches("refs/tags/release-*", self.TAG))
        self.assertFalse(matches("w*", self.TAG))

    def test_missing_or_insufficient_tag_ruleset_blocks_before_any_side_effect(self) -> None:
        bypass_actor = {"actor_id": 1, "actor_type": "Team", "bypass_mode": "always"}
        cases = (
            ("no-rulesets", [_ruleset_list([])], "does not protect release tag"),
            (
                "inactive-ruleset",
                [_ruleset_list([
                    {"id": 42, "target": "tag", "enforcement": "evaluate"}
                ])],
                "does not protect release tag",
            ),
            (
                "branch-ruleset-only",
                [_ruleset_list([
                    {"id": 42, "target": "branch", "enforcement": "active"}
                ])],
                "does not protect release tag",
            ),
            (
                "bypass-actors-void-the-guarantee",
                [_ruleset_list(), _ruleset_detail(bypass=(bypass_actor,))],
                "does not protect release tag",
            ),
            (
                "missing-deletion-rule",
                [_ruleset_list(), _ruleset_detail(rules=("update",))],
                "does not protect release tag v0.2.3.1 against deletion",
            ),
            (
                "missing-update-rule",
                [_ruleset_list(), _ruleset_detail(rules=("deletion",))],
                "does not protect release tag v0.2.3.1 against update",
            ),
            (
                "pattern-does-not-cover-tag",
                [_ruleset_list(), _ruleset_detail(include=("refs/tags/release-*",))],
                "does not protect release tag",
            ),
            (
                "tag-excluded",
                [_ruleset_list(), _ruleset_detail(exclude=("refs/tags/v0.2.3.*",))],
                "does not protect release tag",
            ),
            (
                "listing-unavailable",
                [_gh(["gh", "api"], 1, "", "HTTP 503")],
                "cannot verify tag protection rulesets",
            ),
            (
                "listing-malformed",
                [_gh(["gh", "api"], 0, "{not-json")],
                "invalid JSON",
            ),
            (
                "summary-bool-id",
                [_ruleset_list([{"id": True, "target": "tag", "enforcement": "active"}])],
                "summary returned malformed ID",
            ),
            (
                "summary-missing-id",
                [_ruleset_list([{"target": "tag", "enforcement": "active"}])],
                "summary returned malformed ID",
            ),
            (
                "summary-non-integer-id",
                [_ruleset_list([{"id": "42", "target": "tag", "enforcement": "active"}])],
                "summary returned malformed ID",
            ),
            (
                "summary-null-id",
                [_ruleset_list([{"id": None, "target": "tag", "enforcement": "active"}])],
                "summary returned malformed ID",
            ),
            (
                "summary-float-id",
                [_ruleset_list([{"id": 42.0, "target": "tag", "enforcement": "active"}])],
                "summary returned malformed ID",
            ),
            (
                "detail-bool-id",
                [_ruleset_list(), _ruleset_detail(ruleset_id=True)],
                "detail returned malformed ID",
            ),
            (
                "detail-missing-id",
                [_ruleset_list(), _ruleset_detail(ruleset_id=_MISSING_RULESET_ID)],
                "detail returned malformed ID",
            ),
            (
                "detail-non-integer-id",
                [_ruleset_list(), _ruleset_detail(ruleset_id="42")],
                "detail returned malformed ID",
            ),
            (
                "detail-null-id",
                [_ruleset_list(), _ruleset_detail(ruleset_id=None)],
                "detail returned malformed ID",
            ),
            (
                "detail-float-id",
                [_ruleset_list(), _ruleset_detail(ruleset_id=42.0)],
                "detail returned malformed ID",
            ),
            (
                "detail-mismatched-id",
                [_ruleset_list(), _ruleset_detail(ruleset_id=999)],
                "detail ID does not match summary ID",
            ),
        )
        for label, responses, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         *responses,
                     ]) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error):
                        self._publish()
                commands = self._commands(run_mock)
                self.assertFalse(any("POST" in command for command in commands))
                self.assertFalse(any("create" in command for command in commands))
                self.assertFalse(
                    any("upload" in part.lower() for command in commands for part in command)
                )
                self.assertFalse(any("edit" in command for command in commands))

    def test_unknown_or_malformed_bypass_visibility_blocks_before_any_side_effect(self) -> None:
        """FAN-1271: only an explicit empty bypass_actors list proves no bypass.

        GitHub returns bypass_actors only to callers with write access to the
        ruleset, so a hidden field means unknown visibility and any non-list
        shape breaks the documented contract. Both must stop the publisher
        before the tag claim, release creation, and release edit.
        """
        cases = (
            (
                "hidden-without-ruleset-write-access",
                _HIDDEN_BYPASS_ACTORS,
                "does not disclose bypass actors",
            ),
            ("null", None, "malformed bypass actors"),
            ("empty-object", {}, "malformed bypass actors"),
            (
                "non-empty-object",
                {"actor_id": 1, "actor_type": "Team", "bypass_mode": "always"},
                "malformed bypass actors",
            ),
            ("empty-string", "", "malformed bypass actors"),
            ("non-empty-string", "none", "malformed bypass actors"),
            ("false", False, "malformed bypass actors"),
            ("zero", 0, "malformed bypass actors"),
        )
        for label, shape, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         _ruleset_list(),
                         _ruleset_detail_with_bypass_shape(shape),
                     ]) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error):
                        self._publish()
                commands = self._commands(run_mock)
                self.assertFalse(any("POST" in command for command in commands))
                self.assertFalse(any("create" in command for command in commands))
                self.assertFalse(any("edit" in command for command in commands))

    def test_deleted_claimed_tag_aborts_draft_creation_without_recreation(self) -> None:
        create_abort = _gh(
            ["gh", "release", "create"], 1, "",
            "tag v0.2.3.1 doesn't exist in FomaBy/FantasyDisk-Releases and --verify-tag is set",
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 create_abort,
                 # FAN-1272 best-effort re-read: no release view, no public
                 # release on the tag, and the claimed tag itself is gone.
                 _gh(["gh", "release", "view"], 1, "", "release not found"),
                 _missing_release(),
                 _missing_release(),
             ]) as run_mock:
            with self.assertRaisesRegex(RuntimeError, "verify-tag") as caught:
                self._publish()
        message = str(caught.exception)
        self.assertIn("draft release creation failed", message)
        self.assertIn(f"no public release exists on tag {self.TAG}", message)
        self.assertIn(f"the claimed tag {self.TAG} no longer exists", message)
        commands = self._commands(run_mock)
        creates = [
            command for command in commands
            if command[:3] == ["gh", "release", "create"]
        ]
        self.assertEqual(len(creates), 1)
        self.assertIn("--verify-tag", creates[0])
        # Exactly one atomic claim: the deleted tag is never recreated.
        claims = [
            command for command in commands
            if "--method" in command and "POST" in command
        ]
        self.assertEqual(len(claims), 1)
        self.assertFalse(any("edit" in command for command in commands))
        self.assertFalse(any("--draft=false" in command for command in commands))

    def test_tag_mutation_after_draft_verification_blocks_public_edit(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "_assert_release_assets", return_value="https://example.invalid/v0.2.3.1"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 *_sole_write_access_ok(),
                 _tag_ref(self.TAG, FOREIGN_COMMIT),
             ]) as run_mock:
            with self.assertRaisesRegex(
                RuntimeError, "no longer points at the claimed release commit"
            ):
                self._publish()
        commands = self._commands(run_mock)
        # The mutated tag is caught before the release ever becomes public.
        self.assertFalse(any("--draft=false" in command for command in commands))
        self.assertFalse(any("edit" in command for command in commands))

    def test_ambiguous_public_edit_failure_reports_possible_public_state(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        edit_lost = _gh(["gh", "release", "edit"], 1, "", "timeout awaiting response")
        cases = (
            (
                "now-public",
                [
                    _gh(
                        ["gh", "release", "view"], 0,
                        json.dumps({"isDraft": False, "isImmutable": True}),
                    ),
                    _latest_release("v0.0.9"),
                ],
                "currently PUBLIC",
            ),
            (
                "now-public-latest-unreadable",
                [
                    _gh(
                        ["gh", "release", "view"], 0,
                        json.dumps({"isDraft": False, "isImmutable": True}),
                    ),
                    _gh(["gh", "api"], 1, "", "HTTP 500"),
                ],
                "may be marked latest",
            ),
            (
                "still-draft",
                [
                    _gh(
                        ["gh", "release", "view"], 0,
                        json.dumps({"isDraft": True, "isImmutable": False}),
                    ),
                ],
                "still an unpublished draft",
            ),
            (
                "state-unreadable",
                [
                    _gh(["gh", "release", "view"], 1, "", "HTTP 500"),
                    _gh(["gh", "api"], 1, "HTTP/2 503 Service Unavailable\n"),
                ],
                "could not be read",
            ),
        )
        for label, state_reads, state_text in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "_assert_release_assets", return_value="https://example.invalid/v0.2.3.1"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         *_tag_protection_ok(),
                         *_sole_write_access_ok(),
                         _missing_release(),
                         _absent_tag(),
                         _branch_head(),
                         _tag_ref(self.TAG),
                         created,
                         _tag_ref(self.TAG),
                         *_sole_write_access_ok(),
                         _tag_ref(self.TAG),
                         edit_lost,
                         *state_reads,
                     ]) as run_mock:
                    with self.assertRaisesRegex(
                        RuntimeError, "applied-but-response-lost"
                    ) as caught:
                        self._publish()
                message = str(caught.exception)
                self.assertIn(state_text, message)
                # FAN-1272: an observed public state is reported with the
                # best-effort latest marker, never as an unproven "non-latest".
                self.assertNotIn("PUBLIC and non-latest", message)
                self.assertIn("no rollback", message)
                commands = self._commands(run_mock)
                self.assertFalse(
                    any(command[-1] == "--latest" for command in commands)
                )

    def test_post_public_failures_report_truthful_public_state(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        published = _gh(["gh", "release", "edit"], 0)
        cases = (
            (
                "foreign-after-public",
                [
                    _release_view(draft=False, immutable=True),
                    _tag_ref(self.TAG, FOREIGN_COMMIT),
                ],
                "no longer points at the claimed release commit",
            ),
            (
                "non-immutable-public",
                [_release_view(draft=False, immutable=False)],
                "not GitHub-enforced immutable",
            ),
        )
        for label, post_public, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         *_tag_protection_ok(),
                         *_sole_write_access_ok(),
                         _missing_release(),
                         _absent_tag(),
                         _branch_head(),
                         _tag_ref(self.TAG),
                         created,
                         _tag_ref(self.TAG),
                         _release_view(draft=True, immutable=False),
                         *_sole_write_access_ok(),
                         _tag_ref(self.TAG),
                         _release_view(draft=True, immutable=False),
                         published,
                         *post_public,
                     ]) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error) as caught:
                        self._publish()
                message = str(caught.exception)
                # No false "at most a draft remains" promise: the error admits
                # the release is already public and cannot be rolled back.
                self.assertIn("public reconciliation required", message)
                self.assertIn("no rollback", message)
                commands = self._commands(run_mock)
                self.assertFalse(
                    any(command[-1] == "--latest" for command in commands)
                )

    def test_latest_marking_failure_reports_safe_manual_retry(self) -> None:
        created = _gh(["gh", "release", "create"], 0)
        published = _gh(["gh", "release", "edit"], 0)
        latest_failed = _gh(["gh", "release", "edit"], 1, "", "HTTP 502")
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 created,
                 _tag_ref(self.TAG),
                 _release_view(draft=True, immutable=False),
                 *_sole_write_access_ok(),
                 _tag_ref(self.TAG),
                 _release_view(draft=True, immutable=False),
                 published,
                 _release_view(draft=False, immutable=True),
                 _tag_ref(self.TAG),
                 latest_failed,
             ]):
            with self.assertRaisesRegex(
                RuntimeError, "already public, verified, and immutable"
            ):
                self._publish()


class PublisherCreateRaceRecoveryTests(unittest.TestCase):
    """FAN-1272: a create error after the tag claim re-reads real GitHub state.

    Between the atomic tag claim and `gh release create --draft` a concurrent
    publisher can create a public — even latest — release on the claimed tag.
    Every scenario drives the real publish() command sequence through a mocked
    ``run``: the create-error handler must best-effort re-read the release and
    tag state, admit an observed public/latest release, never promise a
    draft-only leftover without proof, and never delete, edit, overwrite, or
    reuse anything.
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

    def test_racing_release_create_error_reports_observed_state(self) -> None:
        create_conflict = _gh(
            ["gh", "release", "create"], 1, "",
            "HTTP 422: Validation Failed (already_exists)",
        )
        unreadable = _gh(["gh", "api"], 1, "HTTP/2 503 Service Unavailable\n")
        cases = (
            (
                "racing-public-latest",
                [
                    _release_view(draft=False, immutable=True),
                    _latest_release(self.TAG),
                    _tag_probe(self.TAG),
                ],
                (
                    f"release {self.TAG} is currently PUBLIC and is marked latest",
                    f"the claimed tag {self.TAG} still points at the claimed commit",
                ),
            ),
            (
                "racing-public-non-latest",
                [
                    _release_view(draft=False, immutable=True),
                    _latest_release("v9.9.9"),
                    _tag_probe(self.TAG),
                ],
                (f"release {self.TAG} is currently PUBLIC and is not marked latest",),
            ),
            (
                "racing-public-latest-marker-unreadable",
                [
                    _release_view(draft=False, immutable=True),
                    _gh(["gh", "api"], 1, "", "HTTP 500"),
                    _tag_probe(self.TAG),
                ],
                ("may be marked latest (the latest marker could not be read)",),
            ),
            (
                "foreign-draft-remains",
                [
                    _release_view(draft=True, immutable=False),
                    _tag_probe(self.TAG),
                ],
                (f"release {self.TAG} is currently still an unpublished draft",),
            ),
            (
                "state-unreadable-admits-public-latest",
                [unreadable, unreadable, unreadable],
                (
                    f"the current state of release {self.TAG} could not be read",
                    "already public and marked latest",
                    f"the current state of the claimed tag {self.TAG} could not be read",
                ),
            ),
            (
                "proven-no-public-release",
                [
                    _gh(["gh", "release", "view"], 1, "", "release not found"),
                    _missing_release(),
                    _tag_probe(self.TAG),
                ],
                (f"no public release exists on tag {self.TAG}",),
            ),
            (
                "racing-tag-mutation",
                [
                    _release_view(draft=False, immutable=True),
                    _latest_release(self.TAG),
                    _tag_probe(self.TAG, FOREIGN_COMMIT),
                ],
                (f"the claimed tag {self.TAG} no longer points at the claimed commit",),
            ),
        )
        for label, state_reads, expected_fragments in cases:
            with self.subTest(case=label):
                with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
                     mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
                     mock.patch.object(github_release_publish, "run", side_effect=[
                         _auth_ok(),
                         _immutability_enforced(),
                         *_tag_protection_ok(),
                         *_sole_write_access_ok(),
                         _missing_release(),
                         _absent_tag(),
                         _branch_head(),
                         _tag_ref(self.TAG),
                         create_conflict,
                         *state_reads,
                     ]) as run_mock:
                    with self.assertRaisesRegex(
                        RuntimeError, "draft release creation failed"
                    ) as caught:
                        self._publish()
                message = str(caught.exception)
                self.assertIn("Best-effort re-read:", message)
                for fragment in expected_fragments:
                    self.assertIn(fragment, message)
                # No false success and no false draft-only/rollback promise.
                self.assertNotIn("at most the claimed bare tag", message)
                self.assertIn("a draft-only leftover is not guaranteed", message)
                self.assertIn("no rollback", message)
                commands = self._commands(run_mock)
                creates = [
                    command for command in commands
                    if command[:3] == ["gh", "release", "create"]
                ]
                claims = [
                    command for command in commands
                    if "--method" in command and "POST" in command
                ]
                self.assertEqual(len(creates), 1)
                self.assertEqual(len(claims), 1)
                # Recovery observes only: no edit/delete/clobber/force, no
                # publication, and no second claim or create.
                self.assertFalse(
                    any(command[:3] == ["gh", "release", "edit"] for command in commands)
                )
                self.assertFalse(any("--draft=false" in command for command in commands))
                self.assertFalse(any(command[-1] == "--latest" for command in commands))
                self.assertFalse(
                    any("delete" in part.lower() for command in commands for part in command)
                )
                self.assertFalse(
                    any("--clobber" in part for command in commands for part in command)
                )
                # The release and tag state re-reads run after the failed create.
                create_at = commands.index(creates[0])
                view_reads = [
                    index for index, command in enumerate(commands)
                    if command[:3] == ["gh", "release", "view"]
                ]
                self.assertTrue(any(index > create_at for index in view_reads))
                tag_reads = [
                    index for index, command in enumerate(commands)
                    if command[:2] == ["gh", "api"]
                    and command[-1].endswith(f"git/ref/tags/{self.TAG}")
                ]
                self.assertTrue(any(index > create_at for index in tag_reads))

    def test_racing_public_latest_create_error_forbids_demotion(self) -> None:
        # FAN-1277: when the re-read sees a foreign racing public release marked
        # latest, the error must forbid delete/edit/demote/reuse and must NOT
        # advise making any public release non-latest — demoting a foreign
        # latest release is exactly the unsafe edit the runtime warns against.
        create_conflict = _gh(
            ["gh", "release", "create"], 1, "",
            "HTTP 422: Validation Failed (already_exists)",
        )
        state_reads = [
            _release_view(draft=False, immutable=True),
            _latest_release(self.TAG),
            _tag_probe(self.TAG),
        ]
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 *_tag_protection_ok(),
                 *_sole_write_access_ok(),
                 _missing_release(),
                 _absent_tag(),
                 _branch_head(),
                 _tag_ref(self.TAG),
                 create_conflict,
                 *state_reads,
             ]):
            with self.assertRaisesRegex(
                RuntimeError, "draft release creation failed"
            ) as caught:
                self._publish()
        message = str(caught.exception)
        self.assertIn(
            f"release {self.TAG} is currently PUBLIC and is marked latest", message
        )
        self.assertIn("demote", message)
        self.assertNotRegex(
            message, r"(?:keep|make|mark|demote|hold)\b[^.]{0,40}non-latest"
        )


class PublisherDraftAssetRaceTests(unittest.TestCase):
    """FAN-1276: verified draft bytes cannot be swapped before the public edit.

    GitHub keeps every draft release asset writable for any account with
    contents write access until the release goes public and offers no
    publish-with-expected-bytes precondition. These scenarios drive the real
    publish() command sequence through a stateful mock GitHub: the publisher
    must prove a sole-writer boundary before the first external side effect,
    re-prove it after draft verification, re-verify every asset byte-exact
    immediately before the public edit, and refuse the edit when any proof
    fails — a concurrent swap must burn the attempt while the release is
    still an unpublished draft, never after it became public and immutable.
    """

    REPOSITORY = "FomaBy/FantasyDisk-Releases"
    VERSION = "0.2.3.1"
    TAG = "v0.2.3.1"

    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.asset = Path(temporary.name) / f"FantasyDisk-{self.VERSION}-macos.dmg"
        self.asset.write_bytes(b"verified-installer-bytes")
        self.changelog = Path(temporary.name) / f"CHANGELOG-{self.VERSION}.md"
        self.changelog.write_text("release notes", encoding="utf-8")
        self.clean_digest = (
            f"sha256:{hashlib.sha256(self.asset.read_bytes()).hexdigest()}"
        )
        self.url = f"https://github.com/{self.REPOSITORY}/releases/tag/{self.TAG}"

    def _publish(self) -> str:
        return github_release_publish.publish(
            self.REPOSITORY, self.VERSION, [self.asset], self.changelog
        )

    def _stateful_github(
        self,
        *,
        mutate_asset_after_clean_verification: bool = False,
        grant_writer_after_clean_verification: bool = False,
    ):
        """Stateful production-sequence mock: one GitHub, mutated mid-flight."""
        state = {
            "collaborators": [{"login": PUBLISHER_LOGIN}],
            "digest": self.clean_digest,
            "release": None,
            "draft_views": 0,
            "latest": False,
            "commands": [],
        }

        def fake_run(command, *, check=True):
            state["commands"].append(list(command))
            if command[:2] == ["gh", "auth"]:
                return _gh(command, 0)
            if command[:3] == ["gh", "release", "create"]:
                state["release"] = "draft"
                return _gh(command, 0)
            if command[:3] == ["gh", "release", "view"]:
                payload = {
                    "url": self.url,
                    "isDraft": state["release"] == "draft",
                    "isImmutable": state["release"] == "public",
                    "assets": [{
                        "name": self.asset.name,
                        "state": "uploaded",
                        "size": self.asset.stat().st_size,
                        "digest": state["digest"],
                    }],
                }
                response = _gh(command, 0, json.dumps(payload))
                if state["release"] == "draft":
                    state["draft_views"] += 1
                    if state["draft_views"] == 1:
                        # The concurrent authorized writer strikes in exactly
                        # the FAN-1275 window: after the last clean draft
                        # verification and before the public edit.
                        if mutate_asset_after_clean_verification:
                            state["digest"] = "sha256:" + "f" * 64
                        if grant_writer_after_clean_verification:
                            state["collaborators"].append({"login": "mallory"})
                return response
            if command[:3] == ["gh", "release", "edit"]:
                if "--draft=false" in command:
                    state["release"] = "public"
                    return _gh(command, 0)
                if command[-1] == "--latest":
                    state["latest"] = True
                    return _gh(command, 0)
                return _gh(command, 1, "", "unexpected edit")
            self.assertEqual(command[:2], ["gh", "api"])
            if "--method" in command and "POST" in command:
                return _gh(command, 0, json.dumps({
                    "ref": f"refs/tags/{self.TAG}",
                    "object": {"type": "commit", "sha": CLAIMED_COMMIT},
                }))
            route = command[-1]
            if route == "user":
                return _gh(command, 0, json.dumps({"login": PUBLISHER_LOGIN}))
            if route == f"repos/{self.REPOSITORY}":
                return _gh(command, 0, json.dumps(
                    {"owner": {"login": PUBLISHER_LOGIN, "type": "User"}}
                ))
            if "/collaborators" in route:
                return _gh(command, 0, json.dumps(state["collaborators"]))
            if "/invitations" in route:
                return _gh(command, 0, "[]")
            if "/keys" in route:
                return _gh(command, 0, "[]")
            if "user/installations" in route:
                return _gh(
                    command, 0, json.dumps({"total_count": 0, "installations": []})
                )
            if "immutable-releases" in route:
                return _immutability_enforced()
            if "rulesets?" in route:
                return _ruleset_list()
            if "rulesets/" in route:
                return _ruleset_detail()
            if f"releases/tags/{self.TAG}" in route:
                return _missing_release()
            if f"git/matching-refs/tags/{self.TAG}" in route:
                return _absent_tag()
            if route.endswith("git/ref/heads/main"):
                return _branch_head()
            if route.endswith(f"git/ref/tags/{self.TAG}"):
                return _tag_ref(self.TAG)
            raise AssertionError(f"unexpected gh command: {command}")

        return state, fake_run

    def test_asset_mutation_after_clean_draft_verification_blocks_public_edit(
        self,
    ) -> None:
        state, fake_run = self._stateful_github(
            mutate_asset_after_clean_verification=True
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=fake_run):
            with self.assertRaisesRegex(
                RuntimeError, "changed after the last clean verification"
            ) as caught:
                self._publish()
        message = str(caught.exception)
        self.assertIn("asset verification failed", message)
        self.assertIn("the public edit was refused", message)
        self.assertIn("no rollback", message)
        # The mutation happened after a clean verification and was still
        # caught by the byte-exact re-verification before the edit: the
        # release never left the draft state and no destructive command ran.
        self.assertEqual(state["draft_views"], 2)
        self.assertEqual(state["release"], "draft")
        self.assertFalse(state["latest"])
        commands = state["commands"]
        self.assertFalse(any("--draft=false" in command for command in commands))
        self.assertFalse(
            any(command[:3] == ["gh", "release", "edit"] for command in commands)
        )
        self.assertFalse(
            any("delete" in part.lower() for command in commands for part in command)
        )

    def test_malformed_draft_asset_metadata_blocks_real_publish(self) -> None:
        for malformed_size in (
            False,
            True,
            0.0,
            None,
            "0",
            -1,
            self.asset.stat().st_size + 1,
        ):
            with self.subTest(size=repr(malformed_size)):
                state, fake_run = self._stateful_github()
                raw_response = {}

                def malformed_run(command, *, check=True):
                    response = fake_run(command, check=check)
                    if command[:3] == ["gh", "release", "view"]:
                        payload = json.loads(response.stdout)
                        payload["assets"][0]["size"] = malformed_size
                        raw_response["body"] = json.dumps(payload)
                        return _gh(command, 0, raw_response["body"])
                    return response

                with mock.patch.object(
                    github_release_publish.shutil, "which", return_value="gh"
                ), mock.patch.object(
                    github_release_publish,
                    "assert_safe_public_distribution_repository",
                    return_value="main",
                ), mock.patch.object(
                    github_release_publish, "run", side_effect=malformed_run
                ):
                    with self.assertRaisesRegex(
                        RuntimeError, "asset verification failed"
                    ) as caught:
                        self._publish()

                message = str(caught.exception)
                self.assertNotIn(json.dumps(malformed_size), message)
                self.assertNotIn(str(self.asset), message)
                self.assertNotIn(self.clean_digest, message)
                self.assertNotIn(raw_response["body"], message)
                self.assertEqual(state["draft_views"], 1)
                self.assertEqual(state["release"], "draft")
                self.assertFalse(state["latest"])
                commands = state["commands"]
                self.assertFalse(any("--draft=false" in command for command in commands))
                self.assertFalse(any(command[-1] == "--latest" for command in commands))
                self.assertFalse(
                    any(command[:3] == ["gh", "release", "edit"] for command in commands)
                )
                self.assertFalse(
                    any("delete" in part.lower() for command in commands for part in command)
                )

    def test_writer_granted_after_clean_draft_verification_blocks_public_edit(
        self,
    ) -> None:
        state, fake_run = self._stateful_github(
            grant_writer_after_clean_verification=True
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=fake_run):
            with self.assertRaisesRegex(
                RuntimeError, "remove every other collaborator"
            ):
                self._publish()
        # The sole-writer re-proof caught the mid-flight grant before the
        # final asset read: the bytes could no longer be trusted frozen.
        self.assertEqual(state["release"], "draft")
        self.assertFalse(state["latest"])
        commands = state["commands"]
        self.assertFalse(any("--draft=false" in command for command in commands))
        self.assertFalse(
            any(command[:3] == ["gh", "release", "edit"] for command in commands)
        )

    def test_stateful_happy_path_publishes_only_reverified_bytes(self) -> None:
        state, fake_run = self._stateful_github()
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=fake_run):
            self.assertEqual(self._publish(), self.url)
        self.assertEqual(state["release"], "public")
        self.assertTrue(state["latest"])
        self.assertEqual(state["draft_views"], 2)
        commands = state["commands"]
        ownership_checks = [
            index for index, command in enumerate(commands)
            if command[:2] == ["gh", "api"] and command[-1] == "user"
        ]
        claim_at = next(
            index for index, command in enumerate(commands)
            if "--method" in command and "POST" in command
        )
        create_at = next(
            index for index, command in enumerate(commands)
            if command[:3] == ["gh", "release", "create"]
        )
        views = [
            index for index, command in enumerate(commands)
            if command[:3] == ["gh", "release", "view"]
        ]
        publish_at = next(
            index for index, command in enumerate(commands)
            if "--draft=false" in command
        )
        latest_at = next(
            index for index, command in enumerate(commands)
            if command[-1] == "--latest"
        )
        # claim → draft → verified draft → re-proof → re-verify → public
        # non-latest → latest, with the byte re-read as the last pre-edit read.
        self.assertEqual(len(ownership_checks), 2)
        self.assertLess(ownership_checks[0], claim_at)
        self.assertLess(claim_at, create_at)
        self.assertLess(create_at, views[0])
        self.assertLess(views[0], ownership_checks[1])
        self.assertLess(ownership_checks[1], views[1])
        self.assertLess(views[1], publish_at)
        self.assertEqual(publish_at, views[1] + 1)
        self.assertIn("--latest=false", commands[publish_at])
        self.assertIn("--prerelease=false", commands[publish_at])
        self.assertLess(publish_at, latest_at)
        self.assertEqual(latest_at, len(commands) - 1)

    def test_foreign_writer_blocks_before_any_side_effect(self) -> None:
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=[
                 _auth_ok(),
                 _immutability_enforced(),
                 *_tag_protection_ok(),
                 _publisher_identity(),
                 _user_owned_repository(),
                 _gh(["gh", "api"], 0, json.dumps(
                     [{"login": PUBLISHER_LOGIN}, {"login": "mallory"}]
                 )),
             ]) as run_mock:
            with self.assertRaisesRegex(
                RuntimeError, "remove every other collaborator"
            ):
                self._publish()
        commands = [list(call.args[0]) for call in run_mock.call_args_list]
        self.assertFalse(any("POST" in command for command in commands))
        self.assertFalse(any("create" in command for command in commands))
        self.assertFalse(any("edit" in command for command in commands))

    def test_sole_writer_boundary_fails_closed_on_unprovable_state(self) -> None:
        identity = (_publisher_identity(), _user_owned_repository())
        no_writers = (*identity, _sole_collaborator(), _no_invitations())
        write_app = {
            "id": 7,
            "app_slug": "ci-bot",
            "repository_selection": "all",
            "permissions": {"contents": "write"},
        }
        cases = (
            (
                "anonymous-viewer",
                [_gh(["gh", "api"], 0, "{}")],
                "cannot identify the authenticated publisher",
            ),
            (
                "foreign-owner",
                [_publisher_identity(), _user_owned_repository("SomeoneElse")],
                "owned by the authenticated publisher",
            ),
            (
                "organization-owner",
                [
                    _publisher_identity(),
                    _user_owned_repository(PUBLISHER_LOGIN, "Organization"),
                ],
                "owned by the authenticated publisher",
            ),
            (
                "unprovable-collaborator-page",
                [
                    *identity,
                    _gh(["gh", "api"], 0, json.dumps(
                        [{"login": PUBLISHER_LOGIN}] * 100
                    )),
                ],
                "provably complete writer inventory",
            ),
            (
                "malformed-collaborator",
                [*identity, _gh(["gh", "api"], 0, json.dumps([{"id": 1}]))],
                "collaborators are unreadable",
            ),
            (
                "pending-invitation",
                [
                    *identity,
                    _sole_collaborator(),
                    _gh(["gh", "api"], 0, json.dumps(
                        [{"id": 5, "permissions": "read"}]
                    )),
                ],
                "pending collaboration invitations",
            ),
            (
                "writable-deploy-key",
                [
                    *no_writers,
                    _gh(["gh", "api"], 0, json.dumps(
                        [{"id": 1, "read_only": False}]
                    )),
                ],
                "not provably read-only",
            ),
            (
                "malformed-deploy-key",
                [*no_writers, _gh(["gh", "api"], 0, json.dumps([{"id": 1}]))],
                "not provably read-only",
            ),
            (
                "write-app-all-repositories",
                [
                    *no_writers,
                    _no_deploy_keys(),
                    _gh(["gh", "api"], 0, json.dumps(
                        {"total_count": 1, "installations": [write_app]}
                    )),
                ],
                "can reach the distribution repository",
            ),
            (
                "write-app-covering-selected-repository",
                [
                    *no_writers,
                    _no_deploy_keys(),
                    _gh(["gh", "api"], 0, json.dumps({
                        "total_count": 1,
                        "installations": [
                            dict(write_app, repository_selection="selected")
                        ],
                    })),
                    _gh(["gh", "api"], 0, json.dumps({
                        "total_count": 1,
                        "repositories": [
                            {"full_name": self.REPOSITORY.upper()}
                        ],
                    })),
                ],
                "can reach the distribution repository",
            ),
            *[
                (
                    f"malformed-installation-id-{label}",
                    [
                        *no_writers,
                        _no_deploy_keys(),
                        _gh(["gh", "api"], 0, json.dumps({
                            "total_count": 1,
                            "installations": [dict(write_app, id=installation_id)],
                        })),
                    ],
                    "GitHub App installations are unreadable",
                )
                for label, installation_id in (
                    ("true", True),
                    ("false", False),
                    ("null", None),
                    ("string", "7"),
                    ("float", 7.0),
                    ("zero", 0),
                    ("negative", -7),
                )
            ],
            (
                "unprovable-installation-count",
                [
                    *no_writers,
                    _no_deploy_keys(),
                    _gh(["gh", "api"], 0, json.dumps(
                        {"total_count": 2, "installations": [write_app]}
                    )),
                ],
                "provably complete writer inventory",
            ),
            (
                "unreadable-installations",
                [
                    *no_writers,
                    _no_deploy_keys(),
                    _gh(["gh", "api"], 1, "", "HTTP 500"),
                ],
                "invalid JSON for user/installations",
            ),
        )
        for label, responses, error in cases:
            with self.subTest(case=label):
                with mock.patch.object(
                    github_release_publish, "run", side_effect=responses
                ):
                    with self.assertRaisesRegex(RuntimeError, error):
                        github_release_publish.assert_sole_publisher_write_access(
                            self.REPOSITORY
                        )

    def test_malformed_app_inventory_blocks_production_sequence_before_any_write(
        self,
    ) -> None:
        write_app = {
            "id": 7,
            "app_slug": "ci-bot",
            "repository_selection": "all",
            "permissions": {"contents": "write"},
        }
        selected_write_app = dict(write_app, repository_selection="selected")
        no_writers = [
            _publisher_identity(),
            _user_owned_repository(),
            _sole_collaborator(),
            _no_invitations(),
            _no_deploy_keys(),
        ]
        installation_cases = (
            (
                "boolean-true",
                {"total_count": True, "installations": [write_app]},
                "GitHub App installations are unreadable",
            ),
            (
                "boolean-false",
                {"total_count": False, "installations": []},
                "GitHub App installations are unreadable",
            ),
            (
                "null",
                {"total_count": None, "installations": []},
                "GitHub App installations are unreadable",
            ),
            (
                "string",
                {"total_count": "1", "installations": [write_app]},
                "GitHub App installations are unreadable",
            ),
            (
                "float",
                {"total_count": 1.0, "installations": [write_app]},
                "GitHub App installations are unreadable",
            ),
            *[
                (
                    f"id-{label}",
                    {
                        "total_count": 1,
                        "installations": [dict(write_app, id=installation_id)],
                    },
                    "GitHub App installations are unreadable",
                )
                for label, installation_id in (
                    ("true", True),
                    ("false", False),
                    ("null", None),
                    ("string", "7"),
                    ("float", 7.0),
                    ("zero", 0),
                    ("negative", -7),
                )
            ],
            (
                "mismatched-count",
                {"total_count": 2, "installations": [write_app]},
                "provably complete writer inventory",
            ),
            (
                "full-page-count",
                {"total_count": 100, "installations": [write_app] * 100},
                "provably complete writer inventory",
            ),
        )
        selected_repository_cases = (
            (
                "boolean-true",
                {"total_count": True, "repositories": [{"full_name": "FomaBy/Other"}]},
                "GitHub App installation repositories are unreadable",
            ),
            (
                "boolean-false",
                {"total_count": False, "repositories": []},
                "GitHub App installation repositories are unreadable",
            ),
            (
                "null",
                {"total_count": None, "repositories": []},
                "GitHub App installation repositories are unreadable",
            ),
            (
                "string",
                {"total_count": "1", "repositories": [{"full_name": "FomaBy/Other"}]},
                "GitHub App installation repositories are unreadable",
            ),
            (
                "float",
                {"total_count": 1.0, "repositories": [{"full_name": "FomaBy/Other"}]},
                "GitHub App installation repositories are unreadable",
            ),
            (
                "mismatched-count",
                {"total_count": 2, "repositories": [{"full_name": "FomaBy/Other"}]},
                "provably complete writer inventory",
            ),
            (
                "full-page-count",
                {
                    "total_count": 100,
                    "repositories": [{"full_name": "FomaBy/Other"}] * 100,
                },
                "provably complete writer inventory",
            ),
        )
        cases = [
            (f"installations-{label}", payload, error, None)
            for label, payload, error in installation_cases
        ] + [
            (f"selected-repositories-{label}", payload, error, selected_write_app)
            for label, payload, error in selected_repository_cases
        ]
        for label, malformed_payload, error, selected_app in cases:
            with self.subTest(case=label):
                responses = [
                    _auth_ok(),
                    _immutability_enforced(),
                    *_tag_protection_ok(),
                    *no_writers,
                ]
                if selected_app is None:
                    responses.append(_gh(["gh", "api"], 0, json.dumps(malformed_payload)))
                else:
                    responses.extend([
                        _gh(
                            ["gh", "api"],
                            0,
                            json.dumps({
                                "total_count": 1,
                                "installations": [selected_app],
                            }),
                        ),
                        _gh(["gh", "api"], 0, json.dumps(malformed_payload)),
                    ])
                with mock.patch.object(
                    github_release_publish.shutil, "which", return_value="gh"
                ), mock.patch.object(
                    github_release_publish,
                    "assert_safe_public_distribution_repository",
                    return_value="main",
                ), mock.patch.object(
                    github_release_publish, "run", side_effect=responses
                ) as run_mock:
                    with self.assertRaisesRegex(RuntimeError, error):
                        self._publish()
                commands = [list(call.args[0]) for call in run_mock.call_args_list]
                write_commands = _classify_publisher_commands(commands)["write_commands"]
                self.assertEqual(write_commands, [], label)

    def test_sole_writer_boundary_accepts_only_provably_harmless_grants(
        self,
    ) -> None:
        responses = [
            _publisher_identity(),
            _user_owned_repository(),
            _sole_collaborator(),
            _no_invitations(),
            _gh(["gh", "api"], 0, json.dumps([{"id": 1, "read_only": True}])),
            _gh(["gh", "api"], 0, json.dumps({
                "total_count": 2,
                "installations": [
                    {
                        "id": 7,
                        "app_slug": "notifier",
                        "repository_selection": "all",
                        "permissions": {"metadata": "read", "contents": "read"},
                    },
                    {
                        "id": 9,
                        "app_slug": "builder",
                        "repository_selection": "selected",
                        "permissions": {"contents": "write"},
                    },
                ],
            })),
            _gh(["gh", "api"], 0, json.dumps({
                "total_count": 1,
                "repositories": [{"full_name": "FomaBy/OtherProject"}],
            })),
        ]
        with mock.patch.object(github_release_publish, "run", side_effect=responses):
            github_release_publish.assert_sole_publisher_write_access(
                self.REPOSITORY
            )


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

    def test_unsigned_channel_requires_codesign_integrity_but_not_apple_trust(self) -> None:
        # FAN-1283 regression: unsigned still receives an ad-hoc seal and must
        # pass codesign integrity verification; only Apple trust checks differ.
        versioning = (ROOT / "docs" / "process" / "release_versioning.md").read_text(
            encoding="utf-8"
        )
        unsigned_start = versioning.index("- Канал `unsigned`")
        versioning_unsigned = versioning[
            unsigned_start : versioning.index("- Для ОБОИХ каналов", unsigned_start)
        ]
        versioning_unsigned_normalized = re.sub(r"\s+", " ", versioning_unsigned)
        self.assertIn("codesign --verify --deep --strict", versioning_unsigned_normalized)
        self.assertIn("локальную ad-hoc seal", versioning_unsigned_normalized)
        self.assertIn("Developer ID signing, notarization", versioning_unsigned_normalized)
        self.assertIn(
            "`stapler` и `spctl` в этом канале не выполняются",
            versioning_unsigned_normalized,
        )

        skill = (
            ROOT / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md"
        ).read_text(encoding="utf-8")
        unsigned_start = skill.index("- `unsigned` —")
        skill_unsigned = skill[
            unsigned_start : skill.index("### macOS signing order", unsigned_start)
        ]
        self.assertIn("codesign --verify --deep --strict", skill_unsigned)
        self.assertIn("Developer ID signing, notarization", skill_unsigned)
        self.assertIn("stapling, and `spctl` are skipped", skill_unsigned)

        verification = skill[skill.index("- on macOS,") :]
        self.assertIn("codesign`\n  integrity verification in both channels", verification)
        self.assertIn("unsigned channel skips only those", verification)
        self.assertNotIn("unsigned channel skips exactly those three", verification)

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
    DELIVERY_CONTRADICTION_PATTERNS = (
        (
            "Telegram is optional",
            r"(?:\bTelegram\b.{0,120}\b(?:optional|необязатель\w*)\b|"
            r"\b(?:optional|необязатель\w*)\b.{0,120}\bTelegram\b)",
        ),
        (
            "GitHub is secondary",
            r"(?:\bGitHub\b.{0,120}\b(?:secondary|вторич\w*)\b|"
            r"\b(?:secondary|вторич\w*)\b.{0,120}\bGitHub\b)",
        ),
    )
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
    MACOS_CODESIGN_DOCUMENTS = (SKILL, RELEASE_VERSIONING)
    MACOS_CODESIGN_CONTRADICTION_PATTERNS = (
        (
            "unsigned skips codesign integrity verification",
            r"\bunsigned\b[^.!?]{0,220}"
            r"(?:skip\w*|omit\w*|not\s+(?:run|required|verified)|"
            r"does\s+not\s+(?:run|require|verify)|пропуска\w*|"
            r"не\s+(?:выполня\w*|треб\w*|проверя\w*))[^.!?]{0,48}"
            r"`?codesign\b",
        ),
        (
            "codesign is signed-only",
            r"`?codesign\b[^.!?]{0,180}"
            r"(?:signed[- ]only|only\s+(?:for\s+)?signed|"
            r"только\s+(?:для\s+)?(?:`?signed|подпис\w*)|только\s+signed)",
        ),
        (
            "signed-only rule excludes unsigned codesign",
            r"(?:signed[- ]only|только\s+(?:для\s+)?(?:`?signed|подпис\w*))"
            r"[^.!?]{0,120}`?codesign\b",
        ),
    )
    EARLY_CODESIGN_LIES = {
        SKILL: (
            "- on macOS, the old cross-channel rule says `codesign` is only for signed; "
            "unsigned skips `codesign`, stapler, and `spctl`.",
            "- on macOS,",
        ),
        RELEASE_VERSIONING: (
            "    Старое правило для обоих каналов: `codesign` выполняется только для "
            "signed; unsigned пропускает codesign, stapler и spctl.",
            "    - на macOS",
        ),
    }
    TRUTHFUL_CODESIGN_NEGATIVE_CONTROLS = {
        SKILL: (
            "- on macOS, unsigned still runs `codesign --verify --deep --strict` "
            "for integrity and skips only Apple trust steps.",
            "- on macOS,",
        ),
        RELEASE_VERSIONING: (
            "    Для unsigned `codesign --verify --deep --strict` остаётся обязательной "
            "проверкой целостности, а пропускаются только Apple trust steps.",
            "    - на macOS",
        ),
    }
    STALE_MACOS_MAPPING_PATTERN = (
        r"(?:X|\(X\s*\+\s*1\))\s*\.\s*Y\s*\.\s*"
        r"\(\s*1000\s*\*\s*Z\s*\+\s*R\s*\)"
    )
    IMMUTABILITY_CONTRACTS = {
        SKILL: (
            "There is no delete/clobber/force path:",
            "instead of being reused.",
        ),
        RELEASE_VERSIONING: (
            "Delete/clobber/force путей нет:",
            "блокирует публикацию без reuse/edit.",
        ),
        GAME_UPDATES: (
            "Публикатор и verifier не удаляют старые distribution releases/tags.",
            "нельзя заменять файлы или manifest под прежним номером.",
        ),
    }
    IMMUTABILITY_CONTRADICTION_PATTERNS = (
        (
            "published release may be deleted, overwritten, or reused",
            r"\b(?:existing|published|immutable)\s+(?:tag|release|version)\b"
            r".{0,120}\b(?:may|can|allowed)\b.{0,120}"
            r"\b(?:delete\w*|overwrite\w*|reuse\w*)\b",
        ),
        (
            "опубликованную версию можно удалить, перезаписать или повторно использовать",
            r"\b(?:опубликован\w*|immutable)\s+(?:верси\w*|релиз\w*|tag)\b"
            r".{0,120}\b(?:можно|разреш\w*|допуска\w*)\b.{0,120}"
            r"\b(?:удал\w*|перезапис\w*|переиспольз\w*)\b",
        ),
    )
    # FAN-1272: recovery docs must distinguish the truthful failure states and
    # never derive manifest safety from concurrent upload completion order.
    RECOVERY_CONTRACTS = {
        SKILL: (
            "**Failed draft create.**",
            "**Ambiguous create.**",
            "**Foreign/racing public release.**",
            "**Successful public non-latest.**",
            "**Latest-only failure.**",
            "it never promises a draft-only state without that proof",
            "Never delete, edit, demote, or reuse the foreign release or tag",
            "This is the one state that does not burn the version",
            "the ruleset endpoint itself is proven before the claim and is not re-read after publication",
            # FAN-1277: applied-but-response-lost is ambiguous until re-read and
            # is never equated with a public non-latest release, and a
            # foreign/racing public latest release is never demoted.
            "does not by itself prove a successful public non-latest release",
            "never mark it latest, edit, demote, delete, or reuse it",
            "handle it like a foreign/racing public latest and never demote it",
        ),
        RELEASE_VERSIONING: (
            "failed draft create",
            "ambiguous create",
            "foreign/racing public release",
            "successful public non-latest",
            "latest-only failure",
            "не обещает draft-only state без доказательства",
            "сам ruleset endpoint повторно не читается",
            "единственное состояние без сжигания версии",
            # FAN-1277: the applied-but-response-lost re-read is separate from the
            # public non-latest state, and the racing public latest release keeps
            # its latest marker untouched.
            "сам по себе не доказывает successful public non-latest",
            "его метку latest не трогают",
            "никогда не понижать",
        ),
    }
    MANIFEST_INVARIANT_CONTRACTS = {
        SKILL: ("completion order is not the safety mechanism",),
        RELEASE_VERSIONING: ("порядок завершения не гарантирован",),
        GAME_UPDATES: (
            "порядок завершения ничего не гарантирует",
            "release остаётся draft, пока весь allowlisted package, включая manifest, не проверен byte-exact (имя, размер, SHA-256)",
        ),
    }
    MANIFEST_ORDER_CONTRADICTION_PATTERNS = (
        (
            "manifest safety derived from upload completion order",
            r"(?:загружа\w+\s+последним|uploaded\s+last|uploads\s+last|upload\s+last"
            r"|завершает\s+загрузку\s+последним|final\s+asset\s+to\s+upload)[,]?\s*"
            r"(?:поэтому|значит|\bso\b|which\s+(?:means|guarantees)|therefore)\b",
        ),
        # FAN-1277: catch equivalent completion-order wordings that attribute
        # latest safety to the manifest merely being uploaded last/final,
        # instead of to byte-exact draft verification.
        (
            "manifest-last position claimed to make latest safe",
            r"(?:manifest|манифест)[^.]{0,50}(?:\blast\b|final\s+asset\s+to\s+upload"
            r"|последн\w+)[^.]{0,50}(?:\bsafe\b|never\s+(?:exposes|shows)"
            r"|безопас\w+|гарантир\w+\s+(?:latest|безопас))",
        ),
    )
    # FAN-1277: reject append-only contradictions that invert the safe action
    # for each of the five truthful recovery states, not only exact canonical
    # tokens. Each pattern targets an affirmative dangerous instruction so the
    # canonical negations ("never demote", "не доказывает") stay green.
    RECOVERY_STATE_CONTRADICTION_PATTERNS = (
        (
            "failed draft create leftover reused instead of burned",
            r"(?:\breuse\b|переиспольз\w+|\boverwrite\b|перезапис\w+|force-?updat\w+)\s+"
            r"(?:the\s+|это\s+|наш\s+|захвач\w+\s+|claimed\s+|leftover\s+|остав\w+\s+)*"
            r"(?:tag|тег|draft|черновик|release|релиз)",
        ),
        (
            "ambiguous/failed create claimed to be a guaranteed draft-only state",
            r"(?:ambiguous\s+create|failed\s+draft\s+create|неоднозначн\w+)"
            r"[^.]{0,60}(?:guaranteed|гарантир\w+|\balways\b|всегда|только)"
            r"[^.]{0,40}(?:draft|черновик)",
        ),
        (
            "foreign/public release advised to be demoted to non-latest",
            r"(?:demote\w*|понизить|понижать|\bmake\b|\bkeep\b|\bmark\b|сделать"
            r"|держать|снять|перевести|переводить)\s+[^.]{0,25}\bnon-latest\b",
        ),
        (
            "applied-but-response-lost claimed to prove a public non-latest release",
            r"(?:applied-but-response-lost|потерянн\w+\s+ответ)"
            r"[^.]{0,40}(?:означает|это|proves(?:\s+a)?|гарантирует)\s+public",
        ),
        (
            "latest-only failure claimed to burn the version or require recreation",
            r"latest-only\s+failure[^.]{0,60}(?:burn\w*\s+the\s+version|\brecreat\w+"
            r"|пересозда\w+|сжига\w+\s+(?:номер|верси)|тоже\s+сжига\w+)",
        ),
    )
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
        paths = set(cls.OPERATIONAL_PLACEHOLDERS) | set(cls.DELIVERY_CONTRACTS) | set(cls.MACOS_MAPPING_CONTRACTS) | set(cls.IMMUTABILITY_CONTRACTS) | {
            cls.BRANCHING,
            cls.CURRENT_STATE,
        } | set(cls.ENTRY_POINT_VERSIONING) | set(cls.RECOVERY_CONTRACTS) | set(cls.MANIFEST_INVARIANT_CONTRACTS)
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
            for label, pattern in cls.DELIVERY_CONTRADICTION_PATTERNS:
                if re.search(pattern, document, flags=re.IGNORECASE):
                    errors.append(f"{relative}: contradictory delivery clause ({label})")
        return errors

    @classmethod
    def macos_mapping_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.MACOS_MAPPING_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if clause not in document:
                    errors.append(f"{relative}: missing canonical macOS mapping clause {clause}")
            if re.search(cls.STALE_MACOS_MAPPING_PATTERN, document):
                errors.append(f"{relative}: contains stale macOS mapping radix")
        return errors

    @classmethod
    def macos_codesign_contract_errors(cls, documents: dict[Path, str]) -> list[str]:
        """Reject unsigned codesign exclusions anywhere in either canonical doc.

        The cross-channel gate and the detailed unsigned subsection are both
        active instructions.  Scan each complete document so a stale early
        statement cannot hide behind a later truthful paragraph.
        """
        errors: list[str] = []
        for relative in cls.MACOS_CODESIGN_DOCUMENTS:
            document = cls.normalize(documents[relative])
            if "codesign --verify --deep --strict" not in document:
                errors.append(f"{relative}: missing codesign integrity contract")
            if "unsigned" not in document.lower():
                errors.append(f"{relative}: missing unsigned channel contract")
            for label, pattern in cls.MACOS_CODESIGN_CONTRADICTION_PATTERNS:
                if re.search(pattern, document, flags=re.IGNORECASE):
                    errors.append(
                        f"{relative}: contradictory macOS codesign clause ({label})"
                    )
        return errors

    @classmethod
    def immutable_release_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.IMMUTABILITY_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if cls.normalize(clause) not in document:
                    errors.append(f"{relative}: missing immutable-release clause {clause}")
            for label, pattern in cls.IMMUTABILITY_CONTRADICTION_PATTERNS:
                if re.search(pattern, document, flags=re.IGNORECASE):
                    errors.append(f"{relative}: contradictory immutable-release clause ({label})")
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
    def release_recovery_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.RECOVERY_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if cls.normalize(clause) not in document:
                    errors.append(f"{relative}: missing release recovery clause {clause}")
            for label, pattern in cls.RECOVERY_STATE_CONTRADICTION_PATTERNS:
                if re.search(pattern, document, flags=re.IGNORECASE):
                    errors.append(
                        f"{relative}: contradictory recovery state clause ({label})"
                    )
        for relative, clauses in cls.MANIFEST_INVARIANT_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if cls.normalize(clause) not in document:
                    errors.append(f"{relative}: missing manifest invariant clause {clause}")
            for label, pattern in cls.MANIFEST_ORDER_CONTRADICTION_PATTERNS:
                if re.search(pattern, document, flags=re.IGNORECASE):
                    errors.append(
                        f"{relative}: contradictory manifest invariant clause ({label})"
                    )
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

        contradiction = "\nContradiction: Telegram is optional; GitHub is secondary.\n"
        for relative in self.DELIVERY_CONTRACTS:
            with self.subTest(document=str(relative), mutation=contradiction):
                mutated = dict(documents)
                mutated[relative] += contradiction
                errors = self.delivery_contract_errors(mutated)
                self.assertTrue(any("contradictory delivery clause" in error for error in errors))

    def test_macos_mapping_contract_is_canonical_in_every_release_instruction(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.macos_mapping_errors(documents), [])

        for relative in self.MACOS_MAPPING_CONTRACTS:
            with self.subTest(document=str(relative)):
                mutated = dict(documents)
                mutated[relative] += "\nLegacy mapping: X.Y.(1000*Z+R).\n"
                errors = self.macos_mapping_errors(mutated)
                self.assertTrue(any("stale macOS mapping radix" in error for error in errors))

    def test_codesign_guard_rejects_early_unsigned_lie_in_each_canonical_doc(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.macos_codesign_contract_errors(documents), [])

        for relative, (lie, anchor) in self.EARLY_CODESIGN_LIES.items():
            with self.subTest(document=str(relative)):
                mutated = dict(documents)
                self.assertIn(anchor, mutated[relative])
                mutated[relative] = mutated[relative].replace(
                    anchor, f"{lie}\n{anchor}", 1
                )
                errors = self.macos_codesign_contract_errors(mutated)
                self.assertTrue(
                    any("contradictory macOS codesign clause" in error for error in errors),
                    errors,
                )

    def test_codesign_guard_accepts_unsigned_trust_only_negative_control(self) -> None:
        documents = self.read_documents()

        for relative, (truthful_clause, anchor) in (
            self.TRUTHFUL_CODESIGN_NEGATIVE_CONTROLS.items()
        ):
            with self.subTest(document=str(relative)):
                mutated = dict(documents)
                self.assertIn(anchor, mutated[relative])
                mutated[relative] = mutated[relative].replace(
                    anchor, f"{truthful_clause}\n{anchor}", 1
                )
                self.assertEqual(self.macos_codesign_contract_errors(mutated), [])

    def test_immutable_release_contract_rejects_append_only_overwrite_permission(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.immutable_release_errors(documents), [])

        contradiction = (
            "\nContradiction: an existing published version may be deleted, "
            "overwritten, or reused.\n"
        )
        for relative in self.IMMUTABILITY_CONTRACTS:
            with self.subTest(document=str(relative), mutation=contradiction):
                mutated = dict(documents)
                mutated[relative] += contradiction
                errors = self.immutable_release_errors(mutated)
                self.assertTrue(
                    any("contradictory immutable-release clause" in error for error in errors)
                )

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

    def test_release_recovery_docs_distinguish_truthful_failure_states(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.release_recovery_errors(documents), [])

        # Semantic mutations, not just token removals, must be detected.
        mutations = (
            (
                self.SKILL,
                "This is the one state that does not burn the version",
                "Like every failure this burns the version",
            ),
            (
                self.RELEASE_VERSIONING,
                "единственное состояние без",
                "состояние, которое тоже требует",
            ),
            (
                self.GAME_UPDATES,
                "завершения ничего не гарантирует",
                "завершения гарантирует безопасность",
            ),
        )
        for relative, expected, replacement in mutations:
            with self.subTest(document=str(relative), mutation=replacement):
                mutated = dict(documents)
                self.assertIn(expected, mutated[relative])
                mutated[relative] = mutated[relative].replace(expected, replacement, 1)
                self.assertTrue(
                    any(
                        str(relative) in error
                        for error in self.release_recovery_errors(mutated)
                    )
                )

        # Re-deriving manifest safety from upload completion order must fail
        # in every canonical release document.
        contradiction = "\nМанифест загружают последним, поэтому latest безопасен.\n"
        for relative in self.MANIFEST_INVARIANT_CONTRACTS:
            with self.subTest(document=str(relative), mutation=contradiction):
                mutated = dict(documents)
                mutated[relative] += contradiction
                errors = self.release_recovery_errors(mutated)
                self.assertTrue(
                    any("contradictory manifest invariant" in error for error in errors)
                )

    def test_recovery_guard_rejects_state_and_manifest_contradictions(self) -> None:
        # FAN-1277: the semantic guard must reject an append-only contradiction
        # for EACH of the five truthful recovery states and for equivalent
        # manifest-order wordings — not only the exact canonical phrase. The
        # earlier guard was false-green: it passed contradictory recovery-state
        # inserts and paraphrased manifest-order claims.
        documents = self.read_documents()
        self.assertEqual(self.release_recovery_errors(documents), [])

        recovery_state_contradictions = (
            # Failed draft create: reuse the claimed tag instead of burning it.
            "\nFailed draft create всегда оставляет только draft, поэтому можно "
            "переиспользовать захваченный tag.\n",
            # Ambiguous create: treat the unread state as a guaranteed draft.
            "\nAmbiguous create гарантированно оставляет draft-only leftover, "
            "публиковать можно поверх.\n",
            # Foreign/racing public latest: demote the foreign release.
            "\nЧужой racing public latest release можно понизить до non-latest, "
            "чтобы наш стал latest.\n",
            # The exact FAN-1277 runtime inversion: keep any public release
            # non-latest, regardless of ownership.
            "\nManually inspect the release and keep any public release "
            "non-latest.\n",
            # Applied-but-response-lost: claim it proves a public non-latest state.
            "\nApplied-but-response-lost означает public non-latest, поэтому "
            "reconciliation не нужна.\n",
            # Latest-only failure: claim it also burns the version and recreate.
            "\nLatest-only failure тоже сжигает номер версии, release нужно "
            "пересоздать.\n",
        )
        for relative in self.RECOVERY_CONTRACTS:
            for contradiction in recovery_state_contradictions:
                with self.subTest(document=str(relative), mutation=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += contradiction
                    errors = self.release_recovery_errors(mutated)
                    self.assertTrue(
                        any(
                            "contradictory recovery state clause" in error
                            for error in errors
                        ),
                        msg=f"{relative} guard missed: {contradiction!r}",
                    )

        manifest_order_equivalents = (
            "\nМанифест завершает загрузку последним, значит latest безопасен.\n",
            "\nBecause the manifest is the final asset to upload, latest never "
            "exposes a partial set.\n",
        )
        for relative in self.MANIFEST_INVARIANT_CONTRACTS:
            for contradiction in manifest_order_equivalents:
                with self.subTest(document=str(relative), mutation=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += contradiction
                    errors = self.release_recovery_errors(mutated)
                    self.assertTrue(
                        any(
                            "contradictory manifest invariant" in error
                            for error in errors
                        ),
                        msg=f"{relative} guard missed: {contradiction!r}",
                    )

    def test_reconciliation_guidance_never_advises_demotion(self) -> None:
        # FAN-1277: the shared recovery guidance must never tell the operator to
        # make/keep any public release non-latest (that would demote a foreign
        # or racing latest release), and must explicitly forbid demotion.
        guidance = github_release_publish.RECONCILIATION_GUIDANCE
        self.assertNotRegex(
            guidance,
            r"(?:keep|make|mark|demote|hold)\b[^.]{0,40}non-latest",
        )
        self.assertRegex(guidance, r"demote")
        self.assertIn("no rollback", guidance)

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
