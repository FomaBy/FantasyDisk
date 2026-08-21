from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "codex" / "fantasydisk-release-director" / "scripts"
BUILD_SCRIPT = ROOT / "tools" / "build_release.sh"
PRESIGN_CHECKPOINT = "PRE-SIGN CHECKPOINT"
CANDIDATE_VERSION = re.search(
    r'(?m)^config/version="([^"]+)"$',
    (ROOT / "project.godot").read_text(encoding="utf-8"),
).group(1)


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
    """FAN-1276 proof quintet: authenticated owner with no other write path."""
    return (
        _publisher_identity(login),
        _user_owned_repository(login),
        _sole_collaborator(login),
        _no_invitations(),
        _no_deploy_keys(),
    )


def _owner_attested_writer_proof(
    *,
    observed_at: datetime | None = None,
    installations: list[dict] | None = None,
) -> dict:
    """A complete, owner-attested inventory fixture for the publish boundary."""
    if observed_at is None:
        observed_at = datetime.now(timezone.utc)
    return {
        "schema_version": 1,
        "source": "github-account-applications-settings",
        "account": PUBLISHER_LOGIN,
        "repository": "FomaBy/FantasyDisk-Releases",
        "observed_at": observed_at.isoformat().replace("+00:00", "Z"),
        "complete": True,
        "installations": installations or [],
    }


def _owner_attested_writer_proofs() -> tuple[dict, dict]:
    first = datetime.now(timezone.utc) - timedelta(seconds=1)
    return (
        _owner_attested_writer_proof(observed_at=first),
        _owner_attested_writer_proof(observed_at=first + timedelta(seconds=1)),
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


class OwnerAttestedWriterInventoryTests(unittest.TestCase):
    """FAN-2829: one App token cannot prove the account-wide App inventory."""

    REPOSITORY = "FomaBy/FantasyDisk-Releases"

    def test_requires_two_fresh_distinct_complete_owner_proofs(self) -> None:
        first, second = _owner_attested_writer_proofs()
        github_release_publish.assert_owner_attested_writer_inventory(
            self.REPOSITORY, PUBLISHER_LOGIN, first, second
        )

    def test_rejects_replayed_proof_before_any_github_call(self) -> None:
        proof = _owner_attested_writer_proof()
        with mock.patch.object(github_release_publish, "run") as run_mock:
            with self.assertRaisesRegex(RuntimeError, "fresh second owner attestation"):
                github_release_publish.assert_owner_attested_writer_inventory(
                    self.REPOSITORY, PUBLISHER_LOGIN, proof, proof
                )
        run_mock.assert_not_called()

    def test_rejects_app_writer_and_account_or_repository_mismatch(self) -> None:
        first, second = _owner_attested_writer_proofs()
        writer = {
            "id": 7,
            "app_slug": "ci-bot",
            "repository_selection": "all",
            "permissions": {"contents": "write"},
        }
        cases = (
            ("writer", dict(second, installations=[writer]), "can reach the distribution repository"),
            ("account", dict(second, account="Mallory"), "account does not match"),
            ("repository", dict(second, repository="FomaBy/Other"), "repository does not match"),
            ("incomplete", dict(second, complete=False), "not marked complete"),
        )
        for label, bad_second, message in cases:
            with self.subTest(case=label):
                with self.assertRaisesRegex(RuntimeError, message):
                    github_release_publish.assert_owner_attested_writer_inventory(
                        self.REPOSITORY, PUBLISHER_LOGIN, first, bad_second
                    )

    def test_rejects_malformed_or_partial_selected_repository_inventory(self) -> None:
        first, second = _owner_attested_writer_proofs()
        selected_writer = {
            "id": 7,
            "app_slug": "ci-bot",
            "repository_selection": "selected",
            "permissions": {"administration": "write"},
            "repositories": {"total_count": 1, "repositories": [{"full_name": self.REPOSITORY}]},
        }
        cases = (
            (dict(selected_writer, repositories={"total_count": 2, "repositories": []}), "incomplete"),
            (dict(selected_writer, repositories={"total_count": True, "repositories": []}), "incomplete"),
            (
                dict(
                    selected_writer,
                    repositories={"total_count": 1, "repositories": [{"full_name": ""}]},
                ),
                "unreadable",
            ),
            (
                dict(
                    selected_writer,
                    repositories={
                        "total_count": 2,
                        "repositories": [
                            {"full_name": "FomaBy/Other"},
                            {"full_name": "fomaby/other"},
                        ],
                    },
                ),
                "incomplete",
            ),
            (dict(selected_writer, repository_selection="unknown"), "unknown App repository selection"),
            (dict(selected_writer, id=True), "App inventory is malformed"),
            (dict(selected_writer, permissions=None), "App inventory is malformed"),
            (selected_writer, "can reach the distribution repository"),
        )
        for installation, message in cases:
            with self.subTest(case=message):
                with self.assertRaisesRegex(RuntimeError, message):
                    github_release_publish.assert_owner_attested_writer_inventory(
                        self.REPOSITORY,
                        PUBLISHER_LOGIN,
                        first,
                        dict(second, installations=[installation]),
                    )

    def test_rejects_unknown_or_partial_selection_even_for_read_only_apps(self) -> None:
        first, second = _owner_attested_writer_proofs()
        read_only = {
            "id": 7,
            "app_slug": "viewer",
            "permissions": {"contents": "read"},
        }
        cases = (
            (dict(read_only, repository_selection="unknown"), "unknown App repository selection"),
            (
                dict(
                    read_only,
                    repository_selection="selected",
                    repositories={"total_count": 2, "repositories": []},
                ),
                "incomplete",
            ),
        )
        for installation, message in cases:
            with self.subTest(installation=installation):
                with self.assertRaisesRegex(RuntimeError, message):
                    github_release_publish.assert_owner_attested_writer_inventory(
                        self.REPOSITORY,
                        PUBLISHER_LOGIN,
                        first,
                        dict(second, installations=[installation]),
                    )

    def test_gho_403_fails_closed_without_echoing_a_token(self) -> None:
        token = "gho_this_must_not_appear"
        with mock.patch.object(
            github_release_publish.subprocess,
            "run",
            return_value=_gh(["gh", "api", "user"], 1, "", f"HTTP 403 {token}"),
        ):
            with self.assertRaisesRegex(RuntimeError, "command failed") as caught:
                github_release_publish.run(["gh", "api", "user"])
        self.assertNotIn(token, str(caught.exception))
        self.assertIn("[REDACTED]", str(caught.exception))

    def test_check_false_result_redacts_stdout_and_stderr(self) -> None:
        token = "ghr_this_must_not_appear"
        with mock.patch.object(
            github_release_publish.subprocess,
            "run",
            return_value=_gh(["gh", "release", "edit"], 1, token, token),
        ):
            result = github_release_publish.run(["gh", "release", "edit"], check=False)
        self.assertNotIn(token, result.stdout)
        self.assertNotIn(token, result.stderr)
        self.assertIn("[REDACTED]", result.stdout)
        self.assertIn("[REDACTED]", result.stderr)

    def test_dry_run_needs_no_attestations_and_never_calls_publish(self) -> None:
        with mock.patch.object(sys, "argv", ["github_release_publish.py", "--version", "0.2.3", "--dry-run"]), \
             mock.patch.object(github_release_publish, "verify_local_release", return_value=Path("release")), \
             mock.patch.object(github_release_publish, "release_files", return_value=([], Path("notes"))), \
             mock.patch.object(github_release_publish, "publish") as publish_mock:
            with mock.patch("builtins.print"):
                self.assertEqual(github_release_publish.main(), 0)
        publish_mock.assert_not_called()

    def test_release_instructions_include_two_proofs_template_and_cleanup(self) -> None:
        skill = (ROOT / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        for required in (
            "mktemp -d",
            "writer-proof-first.json",
            "writer-proof-second.json",
            "--writer-inventory-proof",
            '"schema_version": 1',
            '"complete": true',
            "rm -rf \"$PROOF_DIR\"",
        ):
            with self.subTest(required=required):
                self.assertIn(required, skill)
        for relative in (
            Path("docs") / "process" / "release_versioning.md",
            Path("docs") / "process" / "game_updates.md",
        ):
            with self.subTest(document=str(relative)):
                self.assertIn("--writer-inventory-proof", (ROOT / relative).read_text(encoding="utf-8"))


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
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
                "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
            self.REPOSITORY, self.VERSION, [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
            self.REPOSITORY, self.VERSION, [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
            self.REPOSITORY, self.VERSION, [], Path("CHANGELOG.md"), *_owner_attested_writer_proofs()
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
            self.REPOSITORY, self.VERSION, [self.asset], self.changelog, *_owner_attested_writer_proofs()
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

    def test_second_app_inventory_is_observed_only_after_draft_verification(self) -> None:
        first, second = _owner_attested_writer_proofs()
        late_writer = dict(
            second,
            installations=[{
                "id": 7,
                "app_slug": "late-writer",
                "repository_selection": "all",
                "permissions": {"contents": "write"},
            }],
        )
        state, fake_run = self._stateful_github()
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=fake_run), \
             mock.patch.object(github_release_publish, "load_owner_attested_writer_proof") as load_mock:
            def post_draft_observation(_path):
                self.assertEqual(state["draft_views"], 1)
                return dict(
                    late_writer,
                    observed_at=datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                )

            load_mock.side_effect = post_draft_observation
            with self.assertRaisesRegex(RuntimeError, "late-writer holds contents write"):
                github_release_publish.publish(
                    self.REPOSITORY, self.VERSION, [self.asset], self.changelog,
                    first, "second-proof.json",
                )
        self.assertEqual(load_mock.call_count, 1)
        self.assertEqual(state["release"], "draft")
        self.assertFalse(any("--draft=false" in command for command in state["commands"]))

    def test_precreated_second_inventory_cannot_publish_the_draft(self) -> None:
        first, second = _owner_attested_writer_proofs()
        state, fake_run = self._stateful_github()
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=fake_run), \
             mock.patch.object(github_release_publish, "load_owner_attested_writer_proof", return_value=second):
            with self.assertRaisesRegex(RuntimeError, "fresh second owner attestation"):
                github_release_publish.publish(
                    self.REPOSITORY, self.VERSION, [self.asset], self.changelog,
                    first, "precreated-second-proof.json",
                )
        self.assertEqual(state["release"], "draft")
        self.assertFalse(any("--draft=false" in command for command in state["commands"]))

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

    def test_replayed_proofs_block_production_publish_before_any_write(self) -> None:
        proof = _owner_attested_writer_proof()
        state, fake_run = self._stateful_github()
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", side_effect=fake_run):
            with self.assertRaisesRegex(RuntimeError, "fresh second owner attestation"):
                github_release_publish.publish(
                    self.REPOSITORY, self.VERSION, [self.asset], self.changelog, proof, proof
                )
        self.assertEqual(_classify_publisher_commands(state["commands"])["write_commands"], [])

    @unittest.skip("FAN-2829 superseded App-token inventory fixtures with owner-attested proofs")
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

    @unittest.skip("FAN-2829 superseded App-token inventory fixtures with owner-attested proofs")
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

    @unittest.skip("FAN-2829 superseded App-token inventory fixtures with owner-attested proofs")
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


class MacosChannelLabelingTests(unittest.TestCase):
    """FAN-1121/FAN-2307: current and fallback channels stay truthful."""

    # Every canonical release document a release agent may follow. FAN-1123
    # extended coverage beyond game_updates.md after current_game_state.md and
    # release_versioning.md kept mandating signed-only delivery.
    ACTIVE_RELEASE_DOCS = (
        Path("docs") / "process" / "game_updates.md",
        Path("docs") / "design" / "current_game_state.md",
        Path("docs") / "process" / "release_versioning.md",
    )

    def test_client_labels_signed_macos_channel_truthfully(self) -> None:
        manager = (ROOT / "scripts" / "update_manager.gd").read_text(encoding="utf-8")
        self.assertIn('const MACOS_UPDATE_CHANNEL := "signed"', manager)
        # The inactive FAN-1121 fallback remains available to an explicitly
        # relabelled unsigned tag and must retain its truthful notice.
        self.assertIn("без подписи Apple Developer ID", manager)
        self.assertIn("Конфиденциальность и безопасность", manager)
        self.assertIn("«Всё равно открыть» (Open Anyway)", manager)

        dialog = (ROOT / "scripts" / "ui" / "update_dialog.gd").read_text(encoding="utf-8")
        self.assertIn("MACOS_UNSIGNED_NOTICE", dialog)
        self.assertIn("macos_update_is_unsigned", dialog)

    def test_release_docs_name_signed_as_current_and_preserve_unsigned_fallback(self) -> None:
        docs = (ROOT / "docs" / "process" / "game_updates.md").read_text(encoding="utf-8")
        self.assertIn("Текущий macOS-канал — **signed**", docs)
        self.assertIn("FANTASYDISK_MACOS_CHANNEL=signed", docs)
        self.assertIn("FANTASYDISK_MACOS_CHANNEL=unsigned", docs)
        self.assertIn("Всё равно открыть", docs)
        skill = (
            ROOT / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md"
        ).read_text(encoding="utf-8")
        self.assertIn("The current production channel is `signed`", skill)
        self.assertIn("FAN-1121", skill)

    def test_every_active_release_doc_describes_both_channels(self) -> None:
        # Every canonical release document must present the explicit channels,
        # name signed as current, and retain FAN-1121 as non-current fallback.
        for relative in self.ACTIVE_RELEASE_DOCS:
            with self.subTest(doc=str(relative)):
                doc = (ROOT / relative).read_text(encoding="utf-8")
                self.assertIn("FANTASYDISK_MACOS_CHANNEL", doc)
                self.assertIn("signed", doc)
                self.assertIn("unsigned", doc)
                self.assertIn("FAN-1121", doc)
                self.assertNotIn("Текущий macOS-канал — **unsigned**", doc)
                self.assertNotIn("Текущий выбранный канал — `unsigned`", doc)

    def test_snapshot_and_versioning_docs_supersede_fan1121_current_selection(self) -> None:
        state = (ROOT / "docs" / "design" / "current_game_state.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("FAN-1094 делает macOS installer fail-closed", state)
        self.assertIn("`signed` — текущий выбранный production-канал", state)
        self.assertIn("FAN-1121", state)

        versioning = (ROOT / "docs" / "process" / "release_versioning.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Текущий выбранный канал — `signed`", versioning)
        self.assertIn("Канал `unsigned`", versioning)

    def test_first_signed_release_requires_independent_exact_tag_native_evidence(self) -> None:
        documents = "\n".join(
            (ROOT / relative).read_text(encoding="utf-8")
            for relative in (
                *self.ACTIVE_RELEASE_DOCS,
                Path("skills")
                / "codex"
                / "fantasydisk-release-director"
                / "SKILL.md",
            )
        )
        for required in (
            "FAN-2207",
            "DMG SHA",
            "Accepted",
            "codesign",
            "stapler",
            "spctl",
            "Safari",
            "/Applications",
            "App Translocation",
            "first launch",
            "relaunch ×2",
            "remediation observation window",
            "FAN-1231",
        ):
            with self.subTest(requirement=required):
                self.assertIn(required, documents)
        self.assertIn("signed durability is not proven", documents)

    def test_signed_release_preflight_covers_apple_expiry_without_hardcoding(self) -> None:
        for relative in (
            Path("docs") / "process" / "release_versioning.md",
            Path("skills") / "codex" / "fantasydisk-release-director" / "SKILL.md",
        ):
            with self.subTest(doc=str(relative)):
                document = (ROOT / relative).read_text(encoding="utf-8")
                normalized = " ".join(document.split())
                self.assertIn("actual expiry date", normalized)
                self.assertIn("renewal reminder", normalized)
                self.assertIn("identity/notary authentication", normalized)

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


class CandidateReleaseBuildContractTests(unittest.TestCase):
    """FAN-2422: exact-SHA QA must happen before the immutable release tag."""

    def test_candidate_build_is_pinned_and_carries_prebuild_provenance(self) -> None:
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        for option in (
            "--candidate-repository",
            "--candidate-ref",
            "--candidate-sha",
        ):
            with self.subTest(option=option):
                self.assertIn(option, script)
        self.assertIn("git ls-remote --refs", script)
        self.assertIn("candidate remote ref does not resolve to the pinned SHA", script)
        self.assertIn('worktree add --detach "${WORKTREE_DIR}" "${SOURCE_COMMIT}"', script)
        self.assertIn("CANDIDATE_PROVENANCE.json", script)
        self.assertLess(
            script.index("CANDIDATE_PROVENANCE.json"),
            script.index('run_godot --headless --import'),
        )
        self.assertIn("--candidate-tree \"${SOURCE_TREE}\"", script)

    def test_candidate_manifest_has_no_tag_fallback_and_keeps_complete_inventory(self) -> None:
        source = (SCRIPTS / "local_release.py").read_text(encoding="utf-8")
        self.assertIn('manifest["candidate"] = {', source)
        self.assertIn('"package_inventory": package_inventory', source)
        self.assertIn("candidate manifest must not contain tag provenance", source)
        self.assertIn("candidate provenance does not match", source)
        self.assertIn("require_tag_match=args.action == \"verify\"", source)

    def test_release_docs_describe_candidate_then_tag_without_repacking(self) -> None:
        documents = {
            relative: (ROOT / relative).read_text(encoding="utf-8")
            for relative in (
                Path("docs") / "process" / "release_versioning.md",
                Path("skills") / "codex" / "fantasydisk-release-director" / "SKILL.md",
            )
        }
        for relative, document in documents.items():
            with self.subTest(document=str(relative)):
                self.assertIn("candidate", document.lower())
                self.assertIn("exact-SHA QA", document)
                self.assertIn("без перепаковки", document)


class CandidatePreSignVerificationTests(unittest.TestCase):
    """FAN-2426: QA proves a pinned candidate imports and exports without credentials."""

    # Inputs the build reads for real before the checkpoint.
    COPIED_INPUTS = (
        "CHANGELOG.md",
        "export_presets.cfg",
        "project.godot",
        "scripts/update_manager.gd",
        "tools/build_release.sh",
        "tools/release_notes_visual_claims_guard.py",
        "tools/release_scope_guard.py",
        "tools/release_scope_manifest.json",
        "tools/release_version_contract.py",
        "tools/release_version_mapping.py",
    )
    # Inputs the build only requires to exist; every consumer of them runs after
    # the pre-sign checkpoint, so an empty file proves the build stops earlier.
    PLACEHOLDER_INPUTS = (
        "assets/icon.ico",
        "docs/design/references/fan1094_macos_installer/pixellab_arrow.png",
        "tools/create_macos_dmg.sh",
        "tools/scan_release_secrets.py",
        "tools/windows_installer.nsi",
        "skills/codex/fantasydisk-release-director/scripts/build_update_manifest.py",
        "skills/codex/fantasydisk-release-director/scripts/local_release.py",
    )
    # Test double for the build's only Godot entry point: it satisfies the
    # headless import and produces the exported bundle the checkpoint reports.
    GODOT_GATE_STUB = '''#!/usr/bin/env python3
"""Headless Godot stand-in for pre-sign verification tests."""
import pathlib
import sys
import zipfile

argv = sys.argv[1:]
if "--export-release" in argv:
    output = pathlib.Path(argv[-1])
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w") as archive:
        archive.writestr("FantasyDisk.app/Contents/Info.plist", "<plist/>\\n")
'''

    def candidate_repository(self, tmp: str) -> tuple[Path, str]:
        repo = Path(tmp) / "candidate"
        for relative in self.COPIED_INPUTS:
            target = repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / relative, target)
        for relative in self.PLACEHOLDER_INPUTS:
            target = repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"")
        (repo / "tools" / "godot_gate.py").write_text(self.GODOT_GATE_STUB, encoding="utf-8")
        subprocess.run(
            ["git", "init", "-b", "candidate", str(repo)], check=True, capture_output=True
        )
        self._git(repo, "add", "-A")
        self._git(repo, "commit", "-m", "candidate fixture")
        return repo, self._git(repo, "rev-parse", "HEAD").stdout.strip()

    def _git(self, repo: Path, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [
                "git",
                "-C",
                str(repo),
                "-c",
                "user.email=presign@example.invalid",
                "-c",
                "user.name=Pre-sign Fixture",
                *args,
            ],
            check=True,
            capture_output=True,
            encoding="utf-8",
        )

    def build(
        self, repo: Path, *args: str, channel: str = "", credentials: bool = False
    ) -> subprocess.CompletedProcess:
        environment = {
            key: value
            for key, value in os.environ.items()
            if key
            not in (
                "FANTASYDISK_MACOS_CHANNEL",
                "MACOS_SIGN_IDENTITY",
                "MACOS_NOTARY_PROFILE",
            )
        }
        if channel:
            environment["FANTASYDISK_MACOS_CHANNEL"] = channel
        if credentials:
            environment["MACOS_SIGN_IDENTITY"] = "Developer ID Application: Test (TESTONLY)"
            environment["MACOS_NOTARY_PROFILE"] = "test-only-profile"
        return subprocess.run(
            ["bash", str(repo / "tools" / "build_release.sh"), *args],
            cwd=repo,
            check=False,
            capture_output=True,
            encoding="utf-8",
            env=environment,
        )

    def presign_args(self, repo: Path, sha: str) -> list[str]:
        return [
            CANDIDATE_VERSION,
            "--candidate-repository",
            str(repo),
            "--candidate-ref",
            "refs/heads/candidate",
            "--candidate-sha",
            sha,
            "--candidate-presign-verify",
        ]

    @unittest.skipUnless(sys.platform == "darwin", "macOS export materialization needs ditto")
    def test_presign_reaches_post_export_checkpoint_without_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, sha = self.candidate_repository(tmp)
            result = self.build(repo, *self.presign_args(repo, sha))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Импорт ресурсов", result.stdout)
            self.assertIn('--export-release "macOS"', BUILD_SCRIPT.read_text(encoding="utf-8"))
            self.assertIn("Экспорт macOS", result.stdout)
            # The run may not announce a signing step it never performs.
            self.assertNotIn("подпись будет", result.stdout)
            self.assertIn(PRESIGN_CHECKPOINT, result.stdout)
            self.assertIn("FantasyDisk.app", result.stdout)
            self.assertIn("disposable output удалён", result.stdout)
            # No signing, packaging or publication step may have executed.
            for forbidden in (
                "codesign",
                "notarytool",
                "stapler",
                "spctl",
                "makensis",
                "hdiutil",
                "SHA256SUMS.txt",
                "update-manifest.json",
            ):
                with self.subTest(step=forbidden):
                    self.assertNotIn(forbidden, result.stdout)
            self.assertEqual(self._git(repo, "tag").stdout, "")
            self.assertEqual(
                self._git(repo, "worktree", "list").stdout.strip().count("\n"), 0
            )
            for disposable in ("build", "releases"):
                with self.subTest(path=disposable):
                    self.assertFalse((repo / disposable).exists())

    @unittest.skipIf(os.name == "nt", "Bash execution remains a POSIX/macOS gate")
    def test_presign_is_candidate_only_and_rejects_incomplete_invocations(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, sha = self.candidate_repository(tmp)
            cases = (
                (
                    "tag/final-release path",
                    [CANDIDATE_VERSION, "--candidate-presign-verify"],
                    "candidate-only and cannot run the tag/final-release path",
                ),
                (
                    "incomplete candidate pin",
                    [
                        CANDIDATE_VERSION,
                        "--candidate-repository",
                        str(repo),
                        "--candidate-presign-verify",
                    ],
                    "candidate mode requires --candidate-repository, --candidate-ref, and --candidate-sha together",
                ),
                (
                    "unexpected argument",
                    [*self.presign_args(repo, sha), "--publish"],
                    "unknown argument: --publish",
                ),
            )
            for name, args, expected in cases:
                with self.subTest(case=name):
                    result = self.build(repo, *args)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn(expected, result.stdout)
                    self.assertNotIn("Worktree из", result.stdout)

    @unittest.skipIf(os.name == "nt", "Bash execution remains a POSIX/macOS gate")
    def test_presign_rejects_a_missing_or_moved_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, sha = self.candidate_repository(tmp)
            moved = [
                argument if argument != sha else FOREIGN_COMMIT
                for argument in self.presign_args(repo, sha)
            ]
            absent = [
                argument if argument != "refs/heads/candidate" else "refs/heads/absent"
                for argument in self.presign_args(repo, sha)
            ]
            cases = (
                ("moved candidate", moved, "does not resolve to the pinned SHA"),
                ("missing candidate ref", absent, "cannot be resolved exactly"),
            )
            for name, args, expected in cases:
                with self.subTest(case=name):
                    result = self.build(repo, *args)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn(expected, result.stdout)
                    self.assertNotIn("Worktree из", result.stdout)

    @unittest.skipIf(os.name == "nt", "Bash execution remains a POSIX/macOS gate")
    def test_presign_does_not_weaken_the_normal_channel_gates(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, sha = self.candidate_repository(tmp)
            pinned = self.presign_args(repo, sha)[:-1]
            cases = (
                (
                    "normal signed build still requires Developer ID",
                    pinned,
                    {},
                    "MACOS_SIGN_IDENTITY is required",
                ),
                (
                    "normal signed build still requires an installed Developer ID",
                    pinned,
                    {"credentials": True},
                    "is not an installed Developer ID Application identity",
                ),
                (
                    "unsigned refuses to run with credentials present",
                    pinned,
                    {"channel": "unsigned", "credentials": True},
                    "unsigned channel refuses to run",
                ),
                (
                    "pre-sign obeys the same unsigned fail-closed rule",
                    self.presign_args(repo, sha),
                    {"channel": "unsigned", "credentials": True},
                    "unsigned channel refuses to run",
                ),
                (
                    "pre-sign cannot mislabel the client channel",
                    self.presign_args(repo, sha),
                    {"channel": "unsigned"},
                    "клиент тега помечает macOS-канал",
                ),
            )
            for name, args, environment, expected in cases:
                with self.subTest(case=name):
                    result = self.build(repo, *args, **environment)
                    self.assertEqual(result.returncode, 2, result.stdout)
                    self.assertIn(expected, result.stdout)
                    self.assertNotIn(PRESIGN_CHECKPOINT, result.stdout)

    def test_presign_checkpoint_precedes_every_packaging_and_publication_step(self) -> None:
        script = BUILD_SCRIPT.read_text(encoding="utf-8")
        checkpoint_at = script.index(PRESIGN_CHECKPOINT)
        # Credential-free admission belongs to pre-sign only; the signing path
        # keeps both mandatory credential gates.
        presign_branch_at = script.index('elif [[ "${PRESIGN_MODE}" -eq 1 ]]')
        for credential_gate in (
            "MACOS_SIGN_IDENTITY is required",
            "MACOS_NOTARY_PROFILE is required",
        ):
            with self.subTest(gate=credential_gate):
                self.assertLess(presign_branch_at, script.index(credential_gate))
        self.assertLess(script.index('--export-release "macOS"'), checkpoint_at)
        self.assertLess(checkpoint_at, script.index('rm -rf "${WORKTREE_DIR}/build"'))
        self.assertLess(script.index('rm -rf "${WORKTREE_DIR}/build"'), script.index("exit 0"))
        for step in (
            "codesign --force",
            'bash "${WORKTREE_DIR}/tools/create_macos_dmg.sh"',
            'submit_notary_artifact "${MAC_DMG}"',
            "makensis -DVERSION=",
            "shasum -a 256",
            "build_update_manifest.py",
            'python3 "${WORKTREE_DIR}/skills/codex/fantasydisk-release-director/scripts/local_release.py"',
        ):
            with self.subTest(step=step):
                self.assertLess(checkpoint_at, script.rindex(step))


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
        README: (
            "FANTASYDISK_MACOS_CHANNEL=unsigned tools/build_release.sh <version>",
            "FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh <version>",
            "tools/build_release.sh <version>",
        ),
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
        README: (
            "FANTASYDISK_MACOS_CHANNEL=unsigned tools/build_release.sh X.Y.Z",
            "FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh X.Y.Z",
            "tools/build_release.sh X.Y.Z",
        ),
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
        README: (
            "Проверенный пакет публикуется только в public binary-only repository `FomaBy/FantasyDisk-Releases` через bundled `github_release_publish.py`;",
            "Каждый stable release дополнительно доставляется в Telegram (poster, DMG, Windows Setup и SHA256SUMS), а Discord сообщает Telegram download link.",
        ),
        SKILL: (
            "Publish only to `FomaBy/FantasyDisk-Releases`, a public binary-only repository.",
            "Telegram delivery is mandatory and contains the poster, DMG, Windows Setup and SHA256SUMS.",
            "the public GitHub release used by the updater",
        ),
        CURRENT_STATE: (
            "updater получает manifest и installers из отдельного public binary-only `FomaBy/FantasyDisk-Releases`.",
            "Telegram снова доставляет игрокам poster, DMG, Windows Setup и SHA256SUMS; Discord публикует Telegram link.",
        ),
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
            "Telegram bypass (EN)",
            r"(?:\b(?:skip\w*|omit\w*|avoid\w*|bypass\w*)\s+(?:the\s+)?Telegram"
            r"(?:\s+(?:delivery|channel|files?))?\b|"
            r"\bTelegram(?:\s+(?:delivery|channel|files?))?\s+"
            r"(?:is|remains|becomes|should|must|can|may)\s+(?:be\s+)?"
            r"(?:skip\w*|omit\w*|avoid\w*|bypass\w*)\b|"
            r"\b(?:do\s+not|don't)\s+(?:send|deliver|publish|upload|distribute)\b"
            r"[^.!?;]{0,80}\b(?:via|through|to)\s+Telegram\b|"
            r"\b(?:do\s+not|don't)\s+(?:send|deliver|publish|upload|distribute)\b"
            r"\s+(?:the\s+)?Telegram\s+(?:delivery|channel|files?)\b)",
        ),
        (
            "Telegram bypass (RU)",
            r"(?:\b(?:пропуска\w*|пропуст\w*|обход\w*)\s+"
            r"(?:доставк\w*|файл\w*|канал\w*)[^.!?;]{0,60}\bTelegram\b|"
            r"\bTelegram\s+(?:доставк\w*|файл\w*|канал\w*)\s+"
            r"(?:можно\s+|нужно\s+|следует\s+)?(?:пропуска\w*|пропуст\w*|игнор\w*)\b|"
            r"\bне\s+(?:отправля\w*|доставля\w*|публику\w*|загружа\w*)\b"
            r"[^.!?;]{0,80}\b(?:в|через|на)\s+Telegram\b|"
            r"\bне\s+(?:отправля\w*|доставля\w*|публику\w*|загружа\w*)\b"
            r"\s+(?:файл\w*|доставк\w*|канал\w*)\s+Telegram\b)",
        ),
        (
            "Telegram optional (EN)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?))?\s+"
            r"(?:is|remains|becomes)\s+(?:an?\s+)?optional\b",
        ),
        (
            "Telegram backup (EN)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?))?\s+"
            r"(?:is|remains|becomes)\s+(?:only\s+)?(?:a\s+)?backup\b",
        ),
        (
            "Telegram not required (EN)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?))?\s+"
            r"(?:is|remains|becomes)\s+not\s+"
            r"(?:required|necessary|needed|mandatory)\b",
        ),
        (
            "Telegram optional (RU)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?|доставк\w*|канал\w*))?\s*"
            r"(?:—|:|явля\w+\s+)?\s*необязател\w*\b",
        ),
        (
            "Telegram backup (RU)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?|доставк\w*|канал\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*резервн\w*\b",
        ),
        (
            "Telegram not required (RU)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?|доставк\w*|канал\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*не\s+(?:требу\w*|нужн?\w*|обязател\w*)\b|"
            r"\bTelegram(?:\s+(?:delivery|channel|files?|доставк\w*|канал\w*))?\s*"
            r"не\s+явля\w+\s+обязател\w*\b|"
            r"\bдоставк\w*\s+(?:в|через)\s+Telegram\s+"
            r"не\s+(?:требу\w*|нужн?\w*|обязател\w*)\b",
        ),
        (
            "Telegram fallback (EN)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?))?\s+"
            r"(?:is|remains|becomes)\s+(?:only\s+)?(?:a\s+)?fallback\b",
        ),
        (
            "Telegram secondary (EN)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?))?\s+"
            r"(?:is|remains|becomes)\s+(?:only\s+)?(?:a\s+)?secondary\b",
        ),
        (
            "Telegram fallback (RU)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?|доставк\w*|канал\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*запасн\w*\b",
        ),
        (
            "Telegram secondary (RU)",
            r"\bTelegram(?:\s+(?:delivery|channel|files?|доставк\w*|канал\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*(?:только\s+)?вторичн\w*\b",
        ),
        (
            "GitHub secondary (EN)",
            r"\bGitHub(?:\s+(?:repository|repo|source))?\s+"
            r"(?:is|remains|becomes)\s+(?:a\s+)?secondary\b",
        ),
        (
            "GitHub fallback (EN)",
            r"\bGitHub(?:\s+(?:repository|repo|source))?\s+"
            r"(?:is|remains|becomes)\s+(?:only\s+)?(?:a\s+)?fallback\b",
        ),
        (
            "GitHub secondary (RU)",
            r"\bGitHub(?:\s+(?:repository|repo|source|репозитор\w*|источник\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*вторичн\w*\b",
        ),
        (
            "GitHub fallback (RU)",
            r"\bGitHub(?:\s+(?:repository|repo|source|репозитор\w*|источник\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*резервн\w*\b",
        ),
        (
            "GitHub optional (EN)",
            r"\bGitHub(?:\s+(?:repository|repo|source))?\s+"
            r"(?:is|remains|becomes)\s+(?:only\s+)?(?:an?\s+)?optional\b",
        ),
        (
            "GitHub backup (EN)",
            r"\bGitHub(?:\s+(?:repository|repo|source))?\s+"
            r"(?:is|remains|becomes)\s+(?:only\s+)?(?:a\s+)?backup\b",
        ),
        (
            "GitHub not required (EN)",
            r"\bGitHub(?:\s+(?:repository|repo|source|publication))?\s+"
            r"(?:is|remains|becomes)\s+not\s+"
            r"(?:required|necessary|needed|mandatory)\b",
        ),
        (
            "GitHub optional (RU)",
            r"\bGitHub(?:\s+(?:repository|repo|source|репозитор\w*|источник\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*необязател\w*\b",
        ),
        (
            "GitHub backup (RU)",
            r"\bGitHub(?:\s+(?:repository|repo|source|репозитор\w*|источник\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*запасн\w*\b",
        ),
        (
            "GitHub not required (RU)",
            r"\bGitHub(?:\s+(?:repository|repo|source|репозитор\w*|источник\w*))?\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*не\s+(?:требу\w*|нужн?\w*|обязател\w*)\b|"
            r"\bGitHub(?:\s+(?:repository|repo|source|репозитор\w*|источник\w*))?\s*"
            r"не\s+явля\w+\s+обязател\w*\b",
        ),
        (
            "Updater source backup (EN)",
            r"\bFomaBy/FantasyDisk-Releases\b\s+"
            r"(?:is|remains|becomes|serves\s+as|acts\s+as)\s+"
            r"(?:only\s+|merely\s+|just\s+)?(?:a\s+)?backup\b",
        ),
        (
            "Updater source secondary (EN)",
            r"\bFomaBy/FantasyDisk-Releases\b\s+"
            r"(?:is|remains|becomes|serves\s+as|acts\s+as)\s+"
            r"(?:only\s+|merely\s+|just\s+)?(?:a\s+)?(?:secondary\b|"
            r"(?:not\s+|no\s+longer\s+)(?:the\s+)?(?:primary|main|canonical)\s+"
            r"(?:updater\s+)?source\b)",
        ),
        (
            "Updater source fallback (EN)",
            r"\bFomaBy/FantasyDisk-Releases\b\s+"
            r"(?:is|remains|becomes|serves\s+as|acts\s+as)\s+"
            r"(?:only\s+|merely\s+|just\s+)?(?:a\s+)?fallback\b",
        ),
        (
            "Updater source backup (RU)",
            r"\bFomaBy/FantasyDisk-Releases\b\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*(?:только\s+|лишь\s+)?резервн\w*\b",
        ),
        (
            "Updater source secondary (RU)",
            r"\bFomaBy/FantasyDisk-Releases\b\s*"
            r"(?:(?:—|:|это\s+|явля\w+\s+)?\s*(?:только\s+|лишь\s+)?"
            r"вторичн\w*\b|"
            r"(?:(?:не\s+(?:явля\w+|счита\w+|оста\w+))|"
            r"(?:(?:явля\w+|счита\w+|оста\w+)\s+не))\s+"
            r"(?:основн\w*|главн\w*|каноническ\w*)\s+"
            r"источник\w*(?:\s+обновлен\w*)?\b)",
        ),
        (
            "Updater source fallback (RU)",
            r"\bFomaBy/FantasyDisk-Releases\b\s*"
            r"(?:—|:|это\s+|явля\w+\s+)?\s*(?:только\s+|лишь\s+)?"
            r"(?:запасн\w*|fallback)\b",
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
        README: (
            "Для обоих форм tag `v<version>` и опубликованные байты immutable; повторная доставка не меняет их.",
        ),
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
            "published item may be deleted (EN)",
            r"\b(?:existing\s+published|published|immutable)\s+"
            r"(?:version|tag|release|bytes?|assets?)\b[^.!?]{0,60}"
            r"\b(?:may|can)\s+(?:be\s+)?(?:deleted?|removed?)\b",
        ),
        (
            "published item may be overwritten (EN)",
            r"\b(?:existing\s+published|published|immutable)\s+"
            r"(?:version|tag|release|bytes?|assets?)\b[^.!?]{0,60}"
            r"\b(?:may|can)\s+(?:be\s+)?(?:overwritten?|clobbered?)\b",
        ),
        (
            "published item may be replaced (EN)",
            r"\b(?:existing\s+published|published|immutable)\s+"
            r"(?:version|tag|release|bytes?|assets?)\b[^.!?]{0,60}"
            r"\b(?:may|can)\s+(?:be\s+)?replaced?\b",
        ),
        (
            "published item may be reused (EN)",
            r"\b(?:existing\s+published|published|immutable)\s+"
            r"(?:version|tag|release|bytes?|assets?)\b[^.!?]{0,60}"
            r"\b(?:may|can)\s+be\s+reused?\b",
        ),
        (
            "опубликованный объект можно удалить (RU)",
            r"\b(?:существующ\w*\s+)?опубликован\w*\s+"
            r"(?:верси\w*|тег\w*|релиз\w*|байт\w*|файл\w*|артефакт\w*)\b"
            r"[^.!?]{0,60}\b(?:можно|разреш\w*|допуска\w*)\b"
            r"[^.!?]{0,30}\b(?:удал\w*|убра\w*)\b",
        ),
        (
            "опубликованный объект можно перезаписать (RU)",
            r"\b(?:существующ\w*\s+)?опубликован\w*\s+"
            r"(?:верси\w*|тег\w*|релиз\w*|байт\w*|файл\w*|артефакт\w*)\b"
            r"[^.!?]{0,60}\b(?:можно|разреш\w*|допуска\w*)\b"
            r"[^.!?]{0,30}\bперезапис\w*\b",
        ),
        (
            "опубликованный объект можно заменить (RU)",
            r"\b(?:существующ\w*\s+)?опубликован\w*\s+"
            r"(?:верси\w*|тег\w*|релиз\w*|байт\w*|файл\w*|артефакт\w*)\b"
            r"[^.!?]{0,60}\b(?:можно|разреш\w*|допуска\w*)\b"
            r"[^.!?]{0,30}\bзамен\w*\b",
        ),
        (
            "опубликованный объект можно переиспользовать (RU)",
            r"\b(?:существующ\w*\s+)?опубликован\w*\s+"
            r"(?:верси\w*|тег\w*|релиз\w*|байт\w*|файл\w*|артефакт\w*)\b"
            r"[^.!?]{0,60}\b(?:можно|разреш\w*|допуска\w*)\b"
            r"[^.!?]{0,30}\bпереиспольз\w*\b",
        ),
    )
    LIFECYCLE_DOCUMENTS = (CURRENT_STATE, RELEASE_VERSIONING, BRANCHING)
    LIFECYCLE_CONTRADICTION_PATTERNS = (
        (
            "published 0.2.4 freeze remains active (EN)",
            r"\brelease\s+freeze\b\s+(?:for|of|on)\s+0\.2\.4\b\s+"
            r"(?:is\s+(?:still\s+)?|remains\s+|stays\s+|continues\s+to\s+be\s+)"
            r"(?:active|ongoing|frozen|in\s+force)\b",
        ),
        (
            "published 0.2.4 freeze remains active (EN, version-first)",
            r"\b0\.2\.4\b\s+(?:release\s+)?freeze\b\s+"
            r"(?:is\s+(?:still\s+)?|remains\s+|stays\s+|continues\s+to\s+be\s+)"
            r"(?:active|ongoing|frozen|in\s+force)\b",
        ),
        (
            "published 0.2.4 remains active or frozen (EN)",
            r"\b(?:published\s+)?0\.2\.4\b\s+"
            r"(?:remains\s+|stays\s+|is\s+(?:still\s+)?|continues\s+to\s+be\s+)"
            r"(?:active|ongoing|frozen|in\s+force)\b",
        ),
        (
            "опубликованная 0.2.4 всё ещё заморожена (RU)",
            r"\b(?:замороз\w*|freeze)\b\s+(?:релиз\w*\s+)?0\.2\.4\b\s+"
            r"(?:всё\s+ещё\s+|по-прежнему\s+)?"
            r"(?:актив\w*|действу\w*|продолжа\w*|заморож\w*)\b",
        ),
        (
            "заморозка 0.2.4 продолжает действовать (RU)",
            r"\b(?:для|на)\s+0\.2\.4\b\s+"
            r"(?:по-прежнему\s+|всё\s+ещё\s+)?"
            r"(?:действу\w*|актив\w*|заморож\w*)\b",
        ),
        (
            "опубликованная 0.2.4 остаётся активной или замороженной (RU)",
            r"\b(?:опубликован\w*\s+)?(?:релиз\w*\s+)?0\.2\.4\b\s+"
            r"(?:оста\w+\s+|всё\s+ещё\s+|по-прежнему\s+)"
            r"(?:актив\w*|действу\w*|заморож\w*)\b",
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
            "`dev` is the integration branch",
            "`main` and published tags are immutable release history.",
            "Follow `docs/process/versioning_and_branching.md`",
        ),
    }

    @staticmethod
    def normalize(document: str) -> str:
        return " ".join(document.split())

    _NEGATION_PATTERN = re.compile(
        r"(?:\bdo\s+not\b|\bdon't\b|\b(?:not|never|no)\b|"
        r"\b(?:не|нельзя|никогда)\b)",
        flags=re.IGNORECASE,
    )
    # Scope is established from Markdown structure and local syntax.  A
    # demonstrative list-complement additionally needs a positively proven,
    # bounded semantic role: surface syntax cannot distinguish an organising
    # command from an inverse governor such as ``discourage``.  The inventories
    # below are signed grammatical operators: deontic auxiliaries,
    # safe list-complement roles, negative-control roles that reverse or obscure
    # complement polarity, assertion roles outside the supported list frame,
    # and passive prohibition predicates.
    _DEONTIC_AUXILIARIES = frozenset({
        "should", "must", "ought", "shall", "следует", "нужно", "надо",
        "стоит", "требуется", "необходимо", "надлежит", "полагается",
        "придётся", "придется", "приходится",
    })
    # Each class contains only roles for which negating the governor
    # unambiguously prohibits the embedded list item.  The longer stems
    # deliberately normalize ordinary EN/RU inflections; short English ``do``
    # forms stay exact so an unrelated word such as ``document`` cannot gain
    # admission by prefix.
    _SAFE_LIST_COMPLEMENT_GOVERNOR_ROLE_FORMS = {
        "action_execution": frozenset({
            "do", "does", "did", "doing", "use", "uses", "used", "using",
        }),
        "function_words": frozenset({"be", "been", "being", "out"}),
    }
    _SAFE_LIST_COMPLEMENT_GOVERNOR_ROLE_STEMS = {
        "action_execution": (
            "carry", "complet", "perform", "выполня", "дела", "осуществля",
        ),
        "planning_or_initiation": (
            "commenc", "organiz", "organis", "plan", "schedul", "start",
            "начина", "организ", "планир", "приступ",
        ),
        "directive_issuance": ("issu", "отдава"),
        "permission_withholding": ("permit", "разреш"),
        "tool_application": ("appl", "использ", "примен"),
    }
    # Negative-control roles form a deny-list, not an admission vocabulary.
    # They either invert a negated governor (``do not refuse/avoid/veto X``)
    # or leave the truth of X opaque (``do not debate/doubt X``).  Extending
    # this bounded polarity class cannot make a new positive fixture pass.
    _NEGATIVE_CONTROL_GOVERNOR_STEMS = (
        "avoid", "block", "debate", "defer", "delay", "deny", "disput",
        "doubt", "fail", "forget", "ignor", "obstruct", "oppos", "postpon",
        "prevent", "question", "refus", "reject", "veto",
        "блокир", "возраж", "забыв", "запамят", "игнор", "избег", "меша",
        "обсужда", "оспар", "отверга", "отказыва", "откладыва", "отклон",
        "отсроч", "препятств", "предотвращ", "сомнева",
    )
    _ASSERTION_GOVERNOR_STEMS = (
        "assert", "claim", "declar", "report", "state",
        "заяв", "объяв", "сообщ", "счит", "утвержд",
    )
    _POSTFIX_PROHIBITION_STEMS = (
        "forbid", "prohibit", "disallow", "ban", "bar", "impermiss",
        "unlawful", "illegal", "запрещ", "воспрещ", "недопуст",
        "незакон", "неразреш",
    )
    _ENGLISH_PREPOSITION = (
        r"(?:about|above|across|after|against|along|among|around|as|at|before|"
        r"behind|below|beneath|beside|between|beyond|by|despite|during|except|"
        r"for|from|in|inside|into|near|of|off|on|onto|out|outside|over|past|"
        r"notwithstanding|per|regarding|since|through|throughout|to|toward|under|until|upon|via|"
        r"with|within|without)"
    )
    _RUSSIAN_PREPOSITION = (
        r"(?:без|в|во|вокруг|для|до|за|из|из-за|к|как|между|на|над|о|об|обо|"
        r"от|перед|по|под|после|при|про|с|со|согласно|среди|через|вопреки)"
    )
    _ENGLISH_FUNCTION_ASIDES = frozenset({
        "however", "nevertheless", "nonetheless", "of course", "in fact",
    })
    _RUSSIAN_FUNCTION_ASIDES = frozenset({
        "однако", "всё же", "все же", "по сути", "в частности",
    })
    _RUSSIAN_FINITE_VERB_ENDING = re.compile(
        r"(?:йте|ите|ешь|ете|ют|ут|ат|ят|ал|ала|ало|али)$",
        flags=re.IGNORECASE,
    )

    @classmethod
    @lru_cache(maxsize=32)
    def _markdown_scan_units(cls, document: str) -> tuple[str, ...]:
        """Return prose/table cells that can be checked without cross-talk.

        Markdown hardens the scan before linguistic analysis: unescaped table
        pipes end a cell, while pipes inside inline code remain ordinary text.
        A normal Markdown line wrap is a space, not a clause boundary; a later
        verb still has to pass the local-negation model below.  Fenced code is
        intentionally excluded because it is an example, not a directive.
        """
        units: list[str] = []
        buffer: list[str] = []
        inline_delimiter: int | None = None
        fenced_code = False

        def flush() -> None:
            text = "".join(buffer).strip()
            if text:
                units.append(text)
            buffer.clear()

        for raw_line in document.splitlines(keepends=True):
            if raw_line.lstrip().startswith(("```", "~~~")):
                flush()
                inline_delimiter = None
                fenced_code = not fenced_code
                continue
            if fenced_code:
                continue
            if not raw_line.strip():
                flush()
                continue
            escaped = False
            position = 0
            while position < len(raw_line):
                character = raw_line[position]
                # Backslashes escape a delimiter only before a code span opens.
                # Within a CommonMark code span they are literal text, so a
                # following same-length backtick run still closes that span.
                if character == "`" and (inline_delimiter is not None or not escaped):
                    run_end = position
                    while run_end < len(raw_line) and raw_line[run_end] == "`":
                        run_end += 1
                    delimiter = run_end - position
                    if inline_delimiter is None:
                        inline_delimiter = delimiter
                    elif inline_delimiter == delimiter:
                        inline_delimiter = None
                    buffer.append(raw_line[position:run_end])
                    position = run_end
                    escaped = False
                    continue
                if character == "|" and inline_delimiter is None and not escaped:
                    flush()
                elif character in ".!?;" and inline_delimiter is None:
                    buffer.append(character)
                    flush()
                elif character == "\n":
                    buffer.append(" ")
                else:
                    buffer.append(character)
                escaped = (
                    inline_delimiter is None
                    and character == "\\"
                    and not escaped
                )
                position += 1
        flush()
        return tuple(units)

    @classmethod
    def _is_transparent_aside(cls, aside: str) -> bool:
        """Recognise a bounded non-predicative comma aside in EN or RU."""
        normalized = " ".join(aside.casefold().split())
        if not normalized or len(re.findall(r"\w+", normalized, flags=re.UNICODE)) > 5:
            return False
        if normalized in cls._ENGLISH_FUNCTION_ASIDES or normalized in cls._RUSSIAN_FUNCTION_ASIDES:
            return True
        if re.fullmatch(r"to\s+(?:be\s+)?[\w'-]+(?:\s+[\w'-]+){0,2}", normalized):
            return True
        if re.fullmatch(r"(?:[\w'-]+ly\s+)?[\w'-]+ing", normalized):
            return True
        if re.fullmatch(
            rf"(?:even\s+)?{cls._ENGLISH_PREPOSITION}\s+[\w'-]+(?:\s+[\w'-]+){{0,2}}",
            normalized,
        ):
            return True
        if re.fullmatch(r"even\s+[\w'-]+ly", normalized):
            return True

        russian_tokens = re.findall(r"[а-яё-]+", normalized, flags=re.IGNORECASE)
        if not russian_tokens:
            return False
        if any(cls._RUSSIAN_FINITE_VERB_ENDING.search(token) for token in russian_tokens):
            return False
        return bool(
            re.fullmatch(r"(?:[а-яё-]+\s+){0,3}(?:говоря|временно|срочно|ясно)", normalized)
            or re.fullmatch(
                rf"(?:даже\s+)?{cls._RUSSIAN_PREPOSITION}\s+[а-яё-]+(?:\s+[а-яё-]+){{0,2}}",
                normalized,
            )
        )

    @classmethod
    def _starts_with_role(cls, word: str, stems: tuple[str, ...]) -> bool:
        return any(word.startswith(stem) for stem in stems)

    @classmethod
    def _is_safe_list_complement_governor(cls, words: list[str]) -> bool:
        """Require every governor token to prove a bounded safe role."""
        safe_forms = frozenset().union(*cls._SAFE_LIST_COMPLEMENT_GOVERNOR_ROLE_FORMS.values())
        safe_stems = tuple(
            stem
            for stems in cls._SAFE_LIST_COMPLEMENT_GOVERNOR_ROLE_STEMS.values()
            for stem in stems
        )
        return bool(words) and all(
            word in safe_forms or cls._starts_with_role(word, safe_stems)
            for word in words
        )

    @classmethod
    def _is_structural_list_complement(cls, head: str) -> bool:
        """Recognise a demonstrative list complement with a safe governor.

        The frame establishes attachment, while the governor must belong to a
        bounded safe role class.  Unknown, inverse and opaque governors remain
        fail-closed even when they fit the same local syntax.
        """
        normalized = " ".join(head.casefold().split())
        if not normalized or "," in normalized:
            return False
        if re.search(r"\b(?:but|however|instead|yet|а|зато|но|однако)\b", normalized):
            return False

        frame = re.search(
            r"(?:\b(?:the\s+)?(?:following|below|this|that|these|those)"
            r"(?:\s+(?:action|command|directive|instruction|item|procedure|step)s?)?"
            r"|(?:\bк\s+)?\b(?:следующ[а-яё-]*|нижеследующ[а-яё-]*)"
            r"(?:\s+[а-яё-]+){0,2})\s*$",
            normalized,
            flags=re.IGNORECASE,
        )
        if not frame:
            return False
        governor = normalized[: frame.start()].strip()
        governor_words = re.findall(r"[\w'-]+", governor, flags=re.UNICODE)
        if not governor_words or cls._NEGATION_PATTERN.search(governor):
            return False
        return cls._is_safe_list_complement_governor(governor_words)

    @staticmethod
    def _is_exact_inline_code_span(text: str) -> bool:
        """Prove that ``text`` is one matching Markdown code span."""
        opener = re.match(r"(`+)(?!`)", text)
        if not opener:
            return False
        delimiter_length = len(opener.group(1))
        content_start = opener.end()
        position = content_start
        while position < len(text):
            if text[position] != "`":
                position += 1
                continue
            run_end = position
            while run_end < len(text) and text[run_end] == "`":
                run_end += 1
            run_length = run_end - position
            if run_length == delimiter_length:
                return bool(text[content_start:position].strip()) and run_end == len(text)
            if run_length > delimiter_length:
                return False
            position = run_end
        return False

    @classmethod
    def _is_safe_inline_code_purpose_bridge(cls, bridge: str) -> bool:
        """Require one safe governor, one code object and a direct purpose marker.

        This deliberately proves the entire bridge rather than treating a safe
        first token as permission to ignore later exception or contrast prose.
        Unknown content outside the code span therefore remains fail-closed.
        """
        normalized = " ".join(bridge.split())
        purpose = re.search(r"(?:\bto\b|\bчтобы\b)\s*$", normalized, flags=re.IGNORECASE)
        if not purpose:
            return False
        object_bridge = normalized[: purpose.start()].rstrip()
        if object_bridge.endswith(","):
            object_bridge = object_bridge[:-1].rstrip()
        code_start = object_bridge.find("`")
        backslash_count = len(object_bridge[:code_start]) - len(
            object_bridge[:code_start].rstrip("\\")
        )
        if code_start <= 0 or backslash_count % 2:
            return False
        governor_words = re.findall(
            r"[\w'-]+", object_bridge[:code_start].casefold(), flags=re.UNICODE
        )
        code_span = object_bridge[code_start:]
        return (
            bool(governor_words)
            and cls._is_safe_list_complement_governor(governor_words)
            and cls._is_exact_inline_code_span(code_span)
        )

    @classmethod
    def _is_effective_negation_bridge(cls, bridge: str) -> bool:
        """Return whether two negators share one local attachment path."""
        gap = " ".join(bridge.split())
        while gap:
            first, separator, remainder = gap.partition(" ")
            modal = first.rstrip(",").casefold()
            if modal in cls._DEONTIC_AUXILIARIES or modal.startswith("должн"):
                gap = remainder.lstrip() if separator else ""
                if first.endswith(",") and gap:
                    gap = "," + gap
                continue
            if gap.startswith(","):
                aside_end = gap.find(",", 1)
                if aside_end == -1 or not cls._is_transparent_aside(gap[1:aside_end]):
                    return False
                gap = gap[aside_end + 1 :].lstrip()
                continue
            break

        if not gap:
            return True
        if re.fullmatch(
            r"under\s+(?:any|no|all)\s+[\w'-]+(?:\s+[\w'-]+){0,3}",
            gap,
            flags=re.IGNORECASE,
        ):
            return True
        if re.fullmatch(
            r"при\s+[^,]{1,80}(?:обстоятельств\w*|услов\w*)[^,]{0,40}",
            gap,
            flags=re.IGNORECASE,
        ):
            return True

        words = re.findall(r"[\w'-]+", gap.casefold(), flags=re.UNICODE)
        polarity_modifiers = {
            "actually", "again", "also", "always", "ever", "explicitly",
            "intentionally", "just", "merely", "necessarily", "really",
            "simply", "still", "yet", "вновь", "всё", "все", "действительно",
            "ещё", "еще", "намеренно", "опять", "по-прежнему", "просто",
            "снова", "также", "явно", "же",
        }
        if words and len(words) <= 5 and all(
            word in polarity_modifiers or word.endswith("ly")
            for word in words
        ):
            return True
        if words and len(words) <= 4:
            negative_roles = cls._NEGATIVE_CONTROL_GOVERNOR_STEMS + cls._POSTFIX_PROHIBITION_STEMS
            if cls._starts_with_role(words[0], negative_roles) and all(
                word in {"be", "been", "being", "быть", "to", "чтобы"}
                for word in words[1:]
            ):
                return True
        return False

    @classmethod
    def _postfix_prohibits_match(cls, unit: str, match: re.Match[str]) -> bool:
        """Recognise a passive prohibition immediately following a predicate."""
        # This is an immediate predicate check, not a document-wide search.
        # Keeping the window bounded also prevents a long Markdown paragraph
        # from turning each candidate into a repeated full-tail tokenization.
        tail = unit[match.end() : match.end() + 160]
        words = re.findall(r"[\w'-]+", tail.casefold(), flags=re.UNICODE)
        if not words:
            return False
        while words and words[0] in {"is", "are", "was", "were", "be", "being", "been", "это"}:
            words.pop(0)
        if len(words) >= 2 and words[0] in {"not", "не"} and words[1].startswith(("allow", "permit", "разреш", "позвол")):
            return True
        return bool(words) and words[0].startswith(cls._POSTFIX_PROHIBITION_STEMS)

    @classmethod
    def _negation_protects_match(cls, prefix: str, left_context: str) -> bool:
        """Return whether the closest preceding negation prohibits this match."""
        gap = " ".join(prefix.split())
        while gap:
            first, separator, remainder = gap.partition(" ")
            modal = first.rstrip(",").casefold()
            if modal in cls._DEONTIC_AUXILIARIES or modal.startswith("должн"):
                gap = remainder.lstrip() if separator else ""
                if first.endswith(",") and gap:
                    gap = "," + gap
                continue
            if gap.startswith(","):
                aside_end = gap.find(",", 1)
                if aside_end == -1 or not cls._is_transparent_aside(gap[1:aside_end]):
                    return False
                gap = gap[aside_end + 1 :].lstrip()
                continue
            break

        if not gap:
            return True
        if re.fullmatch(r"under\s+(?:any|no|all)\s+[\w'-]+(?:\s+[\w'-]+){0,3}", gap, flags=re.IGNORECASE):
            return True
        if re.fullmatch(r"при\s+[^,]{1,80}(?:обстоятельств\w*|услов\w*)[^,]{0,40}", gap, flags=re.IGNORECASE):
            return True

        complement = re.fullmatch(r"(?P<head>.+?)\s*[:—–]\s*", gap)
        if complement:
            return cls._is_structural_list_complement(complement.group("head"))

        # A purpose infinitive/``чтобы`` is structurally attached when the
        # negated action has an explicit inline-code object.  Copular predicates
        # (``it is not illegal to …``) and unframed opaque governors
        # (``do not forget to …``) remain fail-closed.
        if re.search(r"(?:\bto|\bчтобы)\s*$", gap, flags=re.IGNORECASE):
            if re.search(r"\b(?:is|are|was|were|be|being|been)\s*$", left_context, flags=re.IGNORECASE):
                return False
            return cls._is_safe_inline_code_purpose_bridge(gap)
        words = re.findall(r"[\w'-]+", gap.casefold(), flags=re.UNICODE)
        return bool(
            len(words) == 1
            and cls._starts_with_role(words[0], cls._ASSERTION_GOVERNOR_STEMS)
        )

    @classmethod
    def _has_unnegated_match(cls, document, pattern: str) -> bool:
        """Return whether a contradiction appears outside a local negation.

        Every candidate is evaluated inside one Markdown scan unit.  The
        nearest preceding negation may protect it only through a direct,
        structurally recognised attachment; all other governors, nested
        polarity and table-cell crossings remain visible as contradictions.
        """
        units = cls._markdown_scan_units(document) if isinstance(document, str) else document
        for unit in units:
            for match in re.finditer(pattern, unit, flags=re.IGNORECASE):
                if cls._postfix_prohibits_match(unit, match):
                    continue
                negations = tuple(cls._NEGATION_PATTERN.finditer(unit[: match.start()]))
                protecting_index = next(
                    (
                        index
                        for index in range(len(negations) - 1, -1, -1)
                        if cls._negation_protects_match(
                            unit[negations[index].end() : match.start()],
                            unit[: negations[index].start()],
                        )
                    ),
                    None,
                )
                if protecting_index is not None and not any(
                    cls._is_effective_negation_bridge(
                        unit[earlier.end() : negations[protecting_index].start()]
                    )
                    for earlier in negations[:protecting_index]
                ):
                    continue
                return True
        return False

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
                if re.search(rf"{re.escape(xyz_only)}(?![.\d])", document):
                    errors.append(f"{relative}: X.Y.Z-only operational example {xyz_only}")
        return errors

    @classmethod
    @lru_cache(maxsize=64)
    def _delivery_document_errors(cls, relative: Path, raw_document: str) -> tuple[str, ...]:
        """Evaluate one immutable document once per exact Markdown content."""
        errors: list[str] = []
        document = cls.normalize(raw_document)
        units = cls._markdown_scan_units(raw_document)
        for clause in cls.DELIVERY_CONTRACTS[relative]:
            if clause not in document:
                errors.append(f"{relative}: missing delivery contract clause {clause}")
        for label, pattern in cls.DELIVERY_CONTRADICTION_PATTERNS:
            if cls._has_unnegated_match(units, pattern):
                errors.append(f"{relative}: contradictory delivery clause ({label})")
        return tuple(errors)

    @classmethod
    def delivery_contract_errors(cls, documents: dict[Path, str]) -> list[str]:
        return [
            error
            for relative in cls.DELIVERY_CONTRACTS
            for error in cls._delivery_document_errors(relative, documents[relative])
        ]

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
        for relative in cls.LIFECYCLE_DOCUMENTS:
            document = cls.normalize(documents[relative])
            for label, pattern in cls.LIFECYCLE_CONTRADICTION_PATTERNS:
                if re.search(pattern, document, flags=re.IGNORECASE):
                    errors.append(
                        f"{relative}: contradictory published-release lifecycle clause ({label})"
                    )
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

        for relative, xyz_only_values in self.OPERATIONAL_XYZ_ONLY.items():
            for xyz_only in xyz_only_values:
                with self.subTest(document=str(relative), mutation=xyz_only):
                    mutated = dict(documents)
                    mutated[relative] += f"\nLegacy command: {xyz_only}\n"
                    errors = self.operational_version_errors(mutated)
                    self.assertIn(
                        f"{relative}: X.Y.Z-only operational example {xyz_only}",
                        errors,
                    )

    def test_operational_guard_accepts_hotfix_commands_without_truncating_version(self) -> None:
        documents = self.read_documents()
        for relative in self.OPERATIONAL_XYZ_ONLY:
            with self.subTest(document=str(relative)):
                mutated = dict(documents)
                mutated[relative] += "\nValid hotfix command: tools/build_release.sh X.Y.Z.R\n"
                self.assertEqual(self.operational_version_errors(mutated), [])

    def test_delivery_contract_is_semantic_and_rejects_token_only_mutations(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.delivery_contract_errors(documents), [])

        mutations = (
            ("Skip Telegram delivery.", "Telegram bypass (EN)"),
            ("Telegram delivery should be skipped.", "Telegram bypass (EN)"),
            ("Do not send release files through Telegram.", "Telegram bypass (EN)"),
            ("Пропускать доставку в Telegram.", "Telegram bypass (RU)"),
            ("Не отправлять файлы в Telegram.", "Telegram bypass (RU)"),
            ("Telegram delivery is optional.", "Telegram optional (EN)"),
            ("Telegram is only a backup delivery channel.", "Telegram backup (EN)"),
            ("Telegram delivery is not required.", "Telegram not required (EN)"),
            ("Telegram необязателен.", "Telegram optional (RU)"),
            ("Telegram — резервный канал.", "Telegram backup (RU)"),
            ("Telegram не требуется.", "Telegram not required (RU)"),
            ("Telegram не является обязательным.", "Telegram not required (RU)"),
            ("Telegram is a fallback channel.", "Telegram fallback (EN)"),
            ("Telegram is a secondary channel.", "Telegram secondary (EN)"),
            ("Telegram is only a secondary channel.", "Telegram secondary (EN)"),
            ("Telegram — запасной канал.", "Telegram fallback (RU)"),
            ("Telegram — вторичный канал.", "Telegram secondary (RU)"),
            ("Telegram — только вторичный канал.", "Telegram secondary (RU)"),
            ("GitHub is a secondary source.", "GitHub secondary (EN)"),
            ("GitHub is a fallback source.", "GitHub fallback (EN)"),
            ("GitHub — вторичный источник.", "GitHub secondary (RU)"),
            ("GitHub — резервный источник.", "GitHub fallback (RU)"),
            ("GitHub is optional.", "GitHub optional (EN)"),
            ("GitHub is only optional.", "GitHub optional (EN)"),
            ("GitHub is a backup source.", "GitHub backup (EN)"),
            ("GitHub is not required.", "GitHub not required (EN)"),
            ("GitHub publication is not required.", "GitHub not required (EN)"),
            ("GitHub — необязательный источник.", "GitHub optional (RU)"),
            ("GitHub — запасной источник.", "GitHub backup (RU)"),
            ("GitHub не требуется.", "GitHub not required (RU)"),
            (
                "FomaBy/FantasyDisk-Releases is only a backup.",
                "Updater source backup (EN)",
            ),
            (
                "FomaBy/FantasyDisk-Releases is a secondary source.",
                "Updater source secondary (EN)",
            ),
            (
                "FomaBy/FantasyDisk-Releases is a fallback source.",
                "Updater source fallback (EN)",
            ),
            (
                "FomaBy/FantasyDisk-Releases — резервный источник.",
                "Updater source backup (RU)",
            ),
            (
                "FomaBy/FantasyDisk-Releases — вторичный источник.",
                "Updater source secondary (RU)",
            ),
            (
                "FomaBy/FantasyDisk-Releases — запасной источник.",
                "Updater source fallback (RU)",
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for contradiction, expected_label in mutations:
                with self.subTest(document=str(relative), mutation=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += f"\nContradiction: {contradiction}\n"
                    errors = self.delivery_contract_errors(mutated)
                    self.assertIn(f"({expected_label})", "\n".join(errors), errors)

        combined_mutations = (
            (
                "Telegram is only a backup delivery channel; GitHub is a fallback source.",
                ("Telegram backup (EN)", "GitHub fallback (EN)"),
            ),
            (
                "Telegram is a secondary channel; GitHub is optional.",
                ("Telegram secondary (EN)", "GitHub optional (EN)"),
            ),
            (
                "Telegram is only a secondary channel; GitHub publication is not required.",
                ("Telegram secondary (EN)", "GitHub not required (EN)"),
            ),
            (
                "Telegram — вторичный канал; GitHub — необязательный источник.",
                ("Telegram secondary (RU)", "GitHub optional (RU)"),
            ),
            (
                "Skip Telegram delivery; FomaBy/FantasyDisk-Releases is only a backup.",
                ("Telegram bypass (EN)", "Updater source backup (EN)"),
            ),
        )
        for contradiction, expected_labels in combined_mutations:
            for relative in self.DELIVERY_CONTRACTS:
                with self.subTest(document=str(relative), mutation=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += f"\nContradiction: {contradiction}\n"
                    errors = self.delivery_contract_errors(mutated)
                    joined_errors = "\n".join(errors)
                    for expected_label in expected_labels:
                        self.assertIn(f"({expected_label})", joined_errors, errors)

    def test_delivery_guard_accepts_canonical_negations(self) -> None:
        documents = self.read_documents()
        safe_negations = (
            (
                "EN",
                "Do not skip Telegram delivery; Telegram is not optional; "
                "Telegram is not a backup, fallback, or secondary channel; "
                "GitHub is not optional, a backup, secondary, or a fallback; "
                "FomaBy/FantasyDisk-Releases is not a backup, secondary, or fallback source; "
                "GitHub is required.",
            ),
            (
                "RU",
                "Не пропускать доставку в Telegram; Telegram не является необязательным, "
                "резервным, запасным или вторичным каналом; "
                "GitHub не является необязательным, резервным, запасным, вторичным или fallback-источником; "
                "FomaBy/FantasyDisk-Releases не является резервным, запасным, вторичным или fallback-источником; "
                "GitHub обязателен.",
            ),
            (
                "EN strengthened",
                "Telegram is not only a secondary channel; GitHub publication is required; "
                "GitHub publication is not optional.",
            ),
            (
                "RU strengthened",
                "Telegram — не только вторичный канал; GitHub publication is required; "
                "GitHub publication is not optional.",
            ),
        )
        for language, safe_negation in safe_negations:
            for relative in self.DELIVERY_CONTRACTS:
                with self.subTest(document=str(relative), language=language):
                    mutated = dict(documents)
                    mutated[relative] += f"\nSafe control ({language}): {safe_negation}\n"
                    self.assertEqual(self.delivery_contract_errors(mutated), [])

    def test_delivery_guard_accepts_required_bilingual_local_prohibitions(self) -> None:
        documents = self.read_documents()
        safe_controls = (
            "Do not, however, skip Telegram delivery.",
            "Не, однако, пропускать доставку в Telegram.",
            "Do not carry out the following: skip Telegram delivery.",
            "Не следует делать следующее: пропускать доставку в Telegram.",
        )
        for relative in self.DELIVERY_CONTRACTS:
            for control in safe_controls:
                with self.subTest(document=str(relative), control=control):
                    mutated = dict(documents)
                    mutated[relative] += f"\nRequired safe control: {control}\n"
                    self.assertEqual(self.delivery_contract_errors(mutated), [])

    def test_delivery_guard_rejects_required_negative_predicates_exactly(self) -> None:
        documents = self.read_documents()
        dangerous_controls = (
            (
                "Telegram delivery is not mandatory.",
                "Telegram not required (EN)",
            ),
            (
                "Доставка в Telegram не обязательна.",
                "Telegram not required (RU)",
            ),
            ("GitHub is not mandatory.", "GitHub not required (EN)"),
            ("GitHub не обязателен.", "GitHub not required (RU)"),
            (
                "FomaBy/FantasyDisk-Releases is not the primary updater source.",
                "Updater source secondary (EN)",
            ),
            (
                "FomaBy/FantasyDisk-Releases не является основным источником обновлений.",
                "Updater source secondary (RU)",
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for control, expected_label in dangerous_controls:
                with self.subTest(document=str(relative), control=control):
                    mutated = dict(documents)
                    mutated[relative] += f"\nRequired dangerous control: {control}\n"
                    self.assertEqual(
                        self.delivery_contract_errors(mutated),
                        [f"{relative}: contradictory delivery clause ({expected_label})"],
                    )

    def test_delivery_guard_generalizes_parentheticals_complements_and_boundaries(self) -> None:
        documents = self.read_documents()
        adversarial_cases = (
            (
                "safe alternate parenthetical EN",
                "Do not, nevertheless, omit the Telegram channel.",
                (),
            ),
            (
                "safe alternate parenthetical RU",
                "Не, всё же, пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe alternate complement EN",
                "Never perform the following: omit Telegram delivery.",
                (),
            ),
            (
                "safe alternate complement RU",
                "Нельзя выполнять следующее: пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe permission complement EN",
                "Do not permit the following: skip Telegram delivery.",
                (),
            ),
            (
                "safe permission complement RU",
                "Не разрешайте следующее: пропускать доставку в Telegram.",
                (),
            ),
            (
                "dangerous inverse complement EN",
                "Do not forbid the following: skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous inverse complement RU",
                "Не запрещайте следующее: пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous non-adjunct parenthetical EN",
                "Do not, skip validation, skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous non-adjunct parenthetical RU",
                "Не, пропустите проверку, пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous adverb-shaped command EN",
                "Do not, comply, skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous adverb-shaped command RU",
                "Не, пропустите, пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous true contrast EN",
                "Do not pause, nevertheless skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous true contrast RU",
                "Не ждать, всё же пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous newline EN",
                "Never pause\nOmit Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous newline RU",
                "Нельзя ждать\nПропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous alternate updater predicate EN",
                "FomaBy/FantasyDisk-Releases is no longer the canonical updater source.",
                ("Updater source secondary (EN)",),
            ),
            (
                "dangerous alternate updater predicate RU copula order",
                "FomaBy/FantasyDisk-Releases является не главным источником обновлений.",
                ("Updater source secondary (RU)",),
            ),
            (
                "dangerous alternate updater predicate RU copula",
                "FomaBy/FantasyDisk-Releases не считается основным источником обновлений.",
                ("Updater source secondary (RU)",),
            ),
        )
        for name, statement, expected_labels in adversarial_cases:
            for relative in self.DELIVERY_CONTRACTS:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nAdversarial control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_binds_negation_to_the_local_clause(self) -> None:
        documents = self.read_documents()
        comma_prefixed_contradictions = (
            ("Do not wait, skip Telegram delivery.", "Telegram bypass (EN)"),
            ("Не ждать, пропускать доставку в Telegram.", "Telegram bypass (RU)"),
            (
                "Do not delay, FomaBy/FantasyDisk-Releases is a backup source.",
                "Updater source backup (EN)",
            ),
            (
                "Do not delay, FomaBy/FantasyDisk-Releases is a secondary source.",
                "Updater source secondary (EN)",
            ),
            (
                "Do not delay, FomaBy/FantasyDisk-Releases is a fallback source.",
                "Updater source fallback (EN)",
            ),
            (
                "Не ждать, FomaBy/FantasyDisk-Releases — резервный источник.",
                "Updater source backup (RU)",
            ),
            (
                "Не ждать, FomaBy/FantasyDisk-Releases — вторичный источник.",
                "Updater source secondary (RU)",
            ),
            (
                "Не ждать, FomaBy/FantasyDisk-Releases — запасной источник.",
                "Updater source fallback (RU)",
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for contradiction, expected_label in comma_prefixed_contradictions:
                with self.subTest(document=str(relative), contradiction=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += f"\nComma-prefix contradiction: {contradiction}\n"
                    self.assertEqual(
                        self.delivery_contract_errors(mutated),
                        [f"{relative}: contradictory delivery clause ({expected_label})"],
                    )

        locally_negated_controls = (
            "Do not skip Telegram delivery.",
            "Не пропускать доставку в Telegram.",
            "FomaBy/FantasyDisk-Releases is not a backup source.",
            "FomaBy/FantasyDisk-Releases is not a secondary source.",
            "FomaBy/FantasyDisk-Releases is not a fallback source.",
            "FomaBy/FantasyDisk-Releases не является резервным источником.",
            "FomaBy/FantasyDisk-Releases не является вторичным источником.",
            "FomaBy/FantasyDisk-Releases не является запасным источником.",
            "Do not wait, do not skip Telegram delivery.",
            "Не ждать, не пропускать доставку в Telegram.",
            "Do not delay, FomaBy/FantasyDisk-Releases is not a backup source.",
            "Do not delay, FomaBy/FantasyDisk-Releases is not a secondary source.",
            "Do not delay, FomaBy/FantasyDisk-Releases is not a fallback source.",
            "Не ждать, FomaBy/FantasyDisk-Releases не является резервным источником.",
            "Не ждать, FomaBy/FantasyDisk-Releases не является вторичным источником.",
            "Не ждать, FomaBy/FantasyDisk-Releases не является запасным источником.",
        )
        for relative in self.DELIVERY_CONTRACTS:
            for control in locally_negated_controls:
                with self.subTest(document=str(relative), control=control):
                    mutated = dict(documents)
                    mutated[relative] += f"\nLocal-negation control: {control}\n"
                    self.assertEqual(self.delivery_contract_errors(mutated), [])

    def test_delivery_guard_handles_bilingual_boundary_matrix(self) -> None:
        documents = self.read_documents()
        boundary_cases = (
            (
                "safe parenthetical EN",
                "Do not, even temporarily, skip Telegram delivery.",
                (),
            ),
            (
                "safe complement colon EN",
                "Do not do the following: skip Telegram delivery.",
                (),
            ),
            (
                "safe complement dash EN",
                "Do not do this — skip Telegram delivery.",
                (),
            ),
            ("safe contraction EN", "Don't skip Telegram delivery.", ()),
            (
                "safe long modifier EN",
                "Do not under any circumstances whatsoever skip Telegram delivery.",
                (),
            ),
            ("safe prohibition RU", "Нельзя пропускать доставку в Telegram.", ()),
            (
                "safe parenthetical RU",
                "Не, даже временно, пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe complement colon RU",
                "Не делайте следующее: пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe long modifier RU",
                "Не при каких обстоятельствах и ни при каких условиях пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe parenthetical updater source",
                "Do not, even temporarily, claim FomaBy/FantasyDisk-Releases is a backup source.",
                (),
            ),
            (
                "dangerous newline EN",
                "Do not wait\nSkip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous contrast EN",
                "Do not delay but skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "dangerous newline RU",
                "Не ждать\nПропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous contrast RU",
                "Не ждать, но пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "dangerous newline updater source",
                "Do not wait\nFomaBy/FantasyDisk-Releases is a backup source.",
                ("Updater source backup (EN)",),
            ),
        )
        for name, statement, expected_labels in boundary_cases:
            for relative in self.DELIVERY_CONTRACTS:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nBoundary matrix control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_scopes_novel_negation_forms(self) -> None:
        """FAN-1518: bounded scope must generalise beyond fixture lexemes.

        Every control below uses discourse markers, complement governors and
        prohibition inverters that are absent from the checked-in fixture
        tables, plus inverse/double negation and a Markdown table-cell
        boundary in each language.  They exercise the grammatical categories,
        not spelling variants of a lexical list, so a fixture-shaped guard
        would regress on them.
        """
        documents = self.read_documents()
        novel_scope_cases = (
            # Discourse-marker asides never listed in the fixtures.
            ("discourse marker EN", "Do not, of course, skip Telegram delivery.", ()),
            ("discourse marker RU", "Не, по сути, пропускать доставку в Telegram.", ()),
            # A deontic modal carries the negation across a non-leading aside.
            (
                "modal-scoped discourse RU",
                "Не нужно, в частности, пропускать доставку в Telegram.",
                (),
            ),
            # Complement governors never listed in the fixtures.
            (
                "complement governor EN",
                "Do not complete the following: skip Telegram delivery.",
                (),
            ),
            (
                "complement governor RU",
                "Не осуществляйте следующее: пропускать доставку в Telegram.",
                (),
            ),
            # Inverse negation: a prohibition governor flips the polarity.
            (
                "inverse negation EN",
                "Do not disallow skipping Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "inverse negation RU",
                "Не воспрещайте пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            # Double negation: ``not prohibited`` / ``не запрещено`` license it.
            (
                "double negation EN",
                "It is not prohibited to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "double negation RU",
                "Не запрещено обходить доставку Telegram.",
                ("Telegram bypass (RU)",),
            ),
            # Markdown table-cell boundary: the negation is in another cell.
            (
                "markdown cell boundary EN",
                "| Do not delay | Skip Telegram delivery. |",
                ("Telegram bypass (EN)",),
            ),
            (
                "markdown cell boundary RU",
                "| Не медлить | Пропускать доставку в Telegram. |",
                ("Telegram bypass (RU)",),
            ),
        )
        for name, statement, expected_labels in novel_scope_cases:
            for relative in self.DELIVERY_CONTRACTS:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nNovel scope control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_models_markdown_units_and_signed_governors(self) -> None:
        """FAN-1521: exact EN/RU polarity and Markdown controls.

        These controls use different phrasing from the signed-operator
        inventories above.  They prove that scope comes from local syntax and
        Markdown units: a soft wrap is not a clause break, a table cell is,
        and an unknown governor must not turn an unsafe predicate into a safe
        one merely because it follows a negator.
        """
        documents = self.read_documents()
        cases = (
            (
                "non-finite EN aside",
                "Do not, to make this plain, skip Telegram delivery.",
                (),
            ),
            (
                "non-finite RU aside",
                "Не следует, без лишних сомнений, пропускать доставку в Telegram.",
                (),
            ),
            ("soft-wrap EN", "Do not\nskip Telegram delivery.", ()),
            ("soft-wrap RU", "Не следует\nпропускать доставку в Telegram.", ()),
            (
                "inline-code EN",
                "Do not use `dry-run | release` to skip Telegram delivery.",
                (),
            ),
            (
                "inline-code RU",
                "Не используйте `dry-run | release`, чтобы пропускать доставку в Telegram.",
                (),
            ),
            (
                "RU table cells never join into a contradiction",
                "| Пропускайте доставку | в Telegram |",
                (),
            ),
            (
                "unknown EN complement fails closed",
                "Do not debate the following: skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "unknown RU complement fails closed",
                "Не обсуждайте следующее: пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "unknown EN purpose governor fails closed",
                "Do not forget to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "unknown RU purpose governor fails closed",
                "Не забывайте пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "EN predicate-shaped comma span",
                "Do not, revise documentation, skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "RU predicate-shaped comma span",
                "Не, проверьте документы, пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "EN table cell boundary",
                "| Do not wait | Skip Telegram delivery |",
                ("Telegram bypass (EN)",),
            ),
            (
                "positive permission predicate EN",
                "Skipping Telegram delivery is permitted.",
                ("Telegram bypass (EN)",),
            ),
            (
                "positive permission predicate RU",
                "Пропускать доставку в Telegram разрешено.",
                ("Telegram bypass (RU)",),
            ),
        )
        for name, statement, expected_labels in cases:
            for relative in self.DELIVERY_CONTRACTS:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1521 control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_accepts_structural_local_prohibition_matrix(self) -> None:
        """FAN-1524: semantic controls remain independent of guard internals."""
        documents = self.read_documents()
        safe_cases = (
            ("positive complement EN", "Do not start the following: skip Telegram delivery."),
            ("positive complement RU", "Не начинайте следующее: пропускать доставку в Telegram."),
            (
                "double-delimiter inline code EN",
                "Do not use ``dry-run | release`` to skip Telegram delivery.",
            ),
            (
                "double-delimiter inline code RU",
                "Не используйте ``dry-run | release``, чтобы пропускать доставку в Telegram.",
            ),
            ("prepositional aside EN", "Do not, after validation, skip Telegram delivery."),
            (
                "prepositional aside RU",
                "Не следует, после проверки, пропускать доставку в Telegram.",
            ),
            ("aspectual complement EN", "Do not commence the following: skip Telegram delivery."),
            (
                "aspectual complement RU",
                "Не приступайте к следующему: пропускать доставку в Telegram.",
            ),
            (
                "incidental inner negation EN",
                "Do not, with no exceptions, skip Telegram delivery.",
            ),
            (
                "directive complement EN",
                "Do not issue the following instruction: skip Telegram delivery.",
            ),
            (
                "directive complement RU",
                "Не отдавайте следующую команду: пропускать доставку в Telegram.",
            ),
            (
                "prepositional paraphrase EN",
                "Do not, as a precaution, skip Telegram delivery.",
            ),
            (
                "prepositional paraphrase RU",
                "Не, согласно правилу, пропускать доставку в Telegram.",
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for name, statement in safe_cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1524 safe control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, (), errors)

    def test_delivery_guard_fan1528_exact_reproductions(self) -> None:
        """FAN-1528: the four QA reproductions stay exact in all six docs."""
        documents = self.read_documents()
        cases = (
            (
                "open-vocabulary frame EN",
                "Do not organize the following: skip Telegram delivery.",
                (),
            ),
            (
                "open-vocabulary frame RU",
                "Не организуйте следующее: пропускать доставку в Telegram.",
                (),
            ),
            (
                "adjacent double negation EN",
                "Do not not skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "adjacent double negation RU",
                "Не не пропускайте доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for name, statement, expected_labels in cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1528 reproduction: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_fan1531_requires_proven_safe_governor_roles(self) -> None:
        """FAN-1531: list and purpose governors default closed until proven safe."""
        documents = self.read_documents()
        cases = (
            (
                "safe base role EN",
                "Do not organize the following action: skip Telegram delivery.",
                (),
            ),
            (
                "safe inflected role EN",
                "The team must not be organizing the following action: skip Telegram delivery.",
                (),
            ),
            (
                "safe base role RU",
                "Не организуйте следующее действие: пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe inflected role RU",
                "Вы не организовывали следующее действие: пропускать доставку в Telegram.",
                (),
            ),
            (
                "inverse list governor EN",
                "Do not discourage the following action: skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "inverse list governor EN with unseen role",
                "Do not hinder the following action: skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "opaque list governor EN",
                "Do not catalogue the following action: skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "inverse list governor RU",
                "Не отговаривайте от следующего действия: пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "inverse list governor RU with unseen role",
                "Не удерживайте от следующего действия: пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "opaque list governor RU",
                "Не осуждайте следующее действие: пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "opaque inline-code purpose governor EN",
                "Do not describe `dry-run | release` to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "opaque inline-code purpose governor RU",
                "Не описывайте `dry-run | release`, чтобы пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for name, statement, expected_labels in cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1531 role control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_fan1534_proves_whole_inline_code_purpose_bridge(self) -> None:
        """FAN-1534: inline-code purpose admission rejects bridge exceptions."""
        documents = self.read_documents()
        cases = (
            (
                "exception bridge EN",
                "Do not use `dry-run | release` except to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "exception bridge EN unseen",
                "Do not use `dry-run | release` other than to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "contrast bridge EN unseen",
                "Do not use `dry-run | release` but only to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "exception bridge RU",
                "Не используйте `dry-run | release`, кроме как чтобы пропустить доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "exception bridge RU unseen",
                "Не используйте `dry-run | release`, за исключением того чтобы пропустить доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "contrast bridge RU unseen",
                "Не используйте `dry-run | release`, но только чтобы пропустить доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "safe single delimiter EN",
                "Do not use `dry-run | release` to skip Telegram delivery.",
                (),
            ),
            (
                "safe double delimiter EN",
                "Do not use ``dry-run | release`` to skip Telegram delivery.",
                (),
            ),
            (
                "safe single delimiter RU",
                "Не используйте `dry-run | release`, чтобы пропускать доставку в Telegram.",
                (),
            ),
            (
                "safe double delimiter RU",
                "Не используйте ``dry-run | release``, чтобы пропускать доставку в Telegram.",
                (),
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for name, statement, expected_labels in cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1534 bridge control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_fan1528_independent_structural_matrix(self) -> None:
        """FAN-1528: structural controls are independent of disclosed verbs."""
        documents = self.read_documents()
        cases = (
            (
                "framed governor EN",
                "Do not schedule the following action: skip Telegram delivery.",
                (),
            ),
            (
                "framed governor RU",
                "Не планируйте следующее действие: пропускать доставку в Telegram.",
                (),
            ),
            (
                "same unframed governor EN",
                "Do not schedule skipping Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "same unframed governor RU",
                "Не планируйте пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "inverse framed governor EN",
                "Do not veto the following action: skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "inverse framed governor RU",
                "Не блокируйте следующее действие: пропускать доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "adjacent double EN",
                "Do not not omit Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "adjacent double RU",
                "Не не обходите доставку Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "aside-separated double EN",
                "Do not, even during a hotfix, not omit Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "aside-separated double RU",
                "Не, даже при хотфиксе, не обходите доставку Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "unseen prepositional aside EN",
                "Do not, notwithstanding prior advice, omit Telegram delivery.",
                (),
            ),
            (
                "unseen prepositional aside RU",
                "Не следует, вопреки прежнему совету, обходить доставку Telegram.",
                (),
            ),
            (
                "single-backtick EN",
                "Do not apply `audit | ship` to omit Telegram delivery.",
                (),
            ),
            (
                "single-backtick RU",
                "Не применяйте `audit | ship`, чтобы обходить доставку Telegram.",
                (),
            ),
            (
                "double-backtick EN",
                "Do not apply ``audit ` | ship`` to omit Telegram delivery.",
                (),
            ),
            (
                "double-backtick RU",
                "Не применяйте ``audit ` | ship``, чтобы обходить доставку Telegram.",
                (),
            ),
            (
                "triple-backtick EN",
                "Do not apply ```audit `` | ship``` to omit Telegram delivery.",
                (),
            ),
            (
                "triple-backtick RU",
                "Не применяйте ```audit `` | ship```, чтобы обходить доставку Telegram.",
                (),
            ),
            (
                "true table boundary EN",
                "| Do not defer | Omit Telegram delivery. |",
                ("Telegram bypass (EN)",),
            ),
            (
                "true table boundary RU",
                "| Не откладывать | Обходить доставку Telegram. |",
                ("Telegram bypass (RU)",),
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for name, statement, expected_labels in cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1528 structural control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

    def test_delivery_guard_matches_inline_code_delimiter_runs(self) -> None:
        """A code span closes only on the same-length delimiter run."""
        documents = self.read_documents()
        safe_cases = (
            ("single delimiter", "Do not use `dry-run | release` to skip Telegram delivery."),
            ("double delimiter", "Do not use ``dry-run | release`` to skip Telegram delivery."),
            (
                "triple delimiter with shorter internal run",
                "Do not use ```dry-run ` | release``` to skip Telegram delivery.",
            ),
        )
        for relative in self.DELIVERY_CONTRACTS:
            for name, statement in safe_cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1524 code control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, (), errors)

        for relative in self.DELIVERY_CONTRACTS:
            with self.subTest(document=str(relative), case="unescaped table boundary"):
                mutated = dict(documents)
                mutated[relative] += "\n| Do not wait | Skip Telegram delivery. |\n"
                self.assertEqual(
                    self.delivery_contract_errors(mutated),
                    [f"{relative}: contradictory delivery clause (Telegram bypass (EN))"],
                )

    def test_delivery_guard_treats_backslash_as_literal_inside_inline_code(self) -> None:
        """FAN-1536: an escaped-looking closer still closes Markdown code."""
        documents = self.read_documents()
        dangerous_cases = (
            (
                "exception bridge EN",
                r"Do not use `safe\` except ` to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "contrast bridge EN",
                r"Do not use `safe\` but only ` to skip Telegram delivery.",
                ("Telegram bypass (EN)",),
            ),
            (
                "exception bridge RU",
                r"Не используйте `safe\` кроме как ` чтобы пропустить доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
            (
                "contrast bridge RU",
                r"Не используйте `safe\` но только ` чтобы пропустить доставку в Telegram.",
                ("Telegram bypass (RU)",),
            ),
        )
        safe_cases = (
            (
                "literal backslash before closer EN",
                r"Do not use `safe\` to skip Telegram delivery.",
            ),
            (
                "literal backslash before closer RU",
                r"Не используйте `safe\`, чтобы пропускать доставку в Telegram.",
            ),
        )

        for relative in self.DELIVERY_CONTRACTS:
            for name, statement, expected_labels in dangerous_cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1536 delimiter control: {statement}\n"
                    errors = self.delivery_contract_errors(mutated)
                    labels = tuple(
                        error.split("contradictory delivery clause (", 1)[1][:-1]
                        for error in errors
                        if "contradictory delivery clause (" in error
                    )
                    self.assertEqual(labels, expected_labels, errors)

            for name, statement in safe_cases:
                with self.subTest(document=str(relative), case=name):
                    mutated = dict(documents)
                    mutated[relative] += f"\nFAN-1536 delimiter control: {statement}\n"
                    self.assertEqual(self.delivery_contract_errors(mutated), [])

        malformed_bridges = (
            r"use `safe\` except ` to",
            "use `safe to",
            "use ``safe` to",
            "use `safe`` to",
            r"use \`safe` to",
        )
        for bridge in malformed_bridges:
            with self.subTest(bridge=bridge):
                self.assertFalse(self._is_safe_inline_code_purpose_bridge(bridge))
        self.assertTrue(self._is_safe_inline_code_purpose_bridge(r"use \\`safe` to"))

    def test_four_required_qa_mutations_are_rejected_individually(self) -> None:
        documents = self.read_documents()
        required_mutations = (
            (
                self.SKILL,
                "Telegram is only a backup delivery channel; GitHub is a fallback source.",
                self.delivery_contract_errors,
                ("Telegram backup (EN)", "GitHub fallback (EN)"),
            ),
            (
                self.BRANCHING,
                "release freeze for 0.2.4 remains active.",
                self.published_release_lifecycle_errors,
                ("published 0.2.4 freeze remains active (EN)",),
            ),
            (
                self.RELEASE_VERSIONING,
                "an existing published release may be replaced in place.",
                self.immutable_release_errors,
                ("published item may be replaced (EN)",),
            ),
            (
                self.README,
                "tools/build_release.sh X.Y.Z",
                self.operational_version_errors,
                ("README.md: X.Y.Z-only operational example tools/build_release.sh X.Y.Z",),
            ),
        )
        for relative, contradiction, helper, expected_labels in required_mutations:
            with self.subTest(document=str(relative), mutation=contradiction):
                mutated = dict(documents)
                mutated[relative] += f"\nRequired QA mutation: {contradiction}\n"
                errors = helper(mutated)
                for expected_label in expected_labels:
                    if expected_label.startswith(str(relative)):
                        self.assertIn(expected_label, errors)
                    else:
                        self.assertIn(expected_label, "\n".join(errors), errors)

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

        mutations = (
            ("published version may be deleted", "published item may be deleted (EN)"),
            ("published tag may be overwritten", "published item may be overwritten (EN)"),
            ("existing published release may be replaced in place", "published item may be replaced (EN)"),
            ("published bytes may be reused", "published item may be reused (EN)"),
            ("опубликованную версию можно удалить", "опубликованный объект можно удалить (RU)"),
            ("опубликованный тег можно перезаписать", "опубликованный объект можно перезаписать (RU)"),
            ("опубликованный релиз можно заменить", "опубликованный объект можно заменить (RU)"),
            ("опубликованные байты можно переиспользовать", "опубликованный объект можно переиспользовать (RU)"),
        )
        for relative in self.IMMUTABILITY_CONTRACTS:
            for contradiction, expected_label in mutations:
                with self.subTest(document=str(relative), mutation=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += f"\nContradiction: {contradiction}.\n"
                    errors = self.immutable_release_errors(mutated)
                    self.assertIn(f"({expected_label})", "\n".join(errors), errors)

    def test_immutable_guard_accepts_negated_and_repeat_delivery_controls(self) -> None:
        documents = self.read_documents()
        safe_controls = (
            "Published version, tag, release and bytes are immutable and may not be "
            "deleted, overwritten, replaced or reused.",
            "Опубликованные версия, тег, релиз и байты immutable: их нельзя удалить, "
            "перезаписать, заменить или переиспользовать.",
        )
        for relative in self.IMMUTABILITY_CONTRACTS:
            for safe_control in safe_controls:
                with self.subTest(document=str(relative), control=safe_control):
                    mutated = dict(documents)
                    mutated[relative] += f"\nSafe control: {safe_control}\n"
                    self.assertEqual(self.immutable_release_errors(mutated), [])

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

    def test_published_024_lifecycle_guard_rejects_english_and_russian_equivalents(self) -> None:
        documents = self.read_documents()
        mutations = (
            (
                "release freeze for 0.2.4 remains active.",
                "published 0.2.4 freeze remains active (EN)",
            ),
            (
                "the 0.2.4 release freeze is still in force.",
                "published 0.2.4 freeze remains active (EN, version-first)",
            ),
            (
                "published 0.2.4 remains frozen.",
                "published 0.2.4 remains active or frozen (EN)",
            ),
            (
                "заморозка релиза 0.2.4 всё ещё активна.",
                "опубликованная 0.2.4 всё ещё заморожена (RU)",
            ),
            (
                "для 0.2.4 по-прежнему действует freeze.",
                "заморозка 0.2.4 продолжает действовать (RU)",
            ),
            (
                "релиз 0.2.4 всё ещё заморожен.",
                "опубликованная 0.2.4 остаётся активной или замороженной (RU)",
            ),
        )
        for relative in self.LIFECYCLE_DOCUMENTS:
            for contradiction, expected_label in mutations:
                with self.subTest(document=str(relative), mutation=contradiction):
                    mutated = dict(documents)
                    mutated[relative] += f"\nContradiction: {contradiction}\n"
                    errors = self.published_release_lifecycle_errors(mutated)
                    self.assertIn(expected_label, "\n".join(errors), errors)

    def test_published_024_lifecycle_guard_accepts_completed_freeze_negations(self) -> None:
        documents = self.read_documents()
        safe_controls = (
            "The release freeze for 0.2.4 is no longer active; it is historical and complete.",
            "Для 0.2.4 заморозка больше не действует: публикация завершена.",
        )
        for relative in self.LIFECYCLE_DOCUMENTS:
            for safe_control in safe_controls:
                with self.subTest(document=str(relative), control=safe_control):
                    mutated = dict(documents)
                    mutated[relative] += f"\nSafe control: {safe_control}\n"
                    self.assertEqual(self.published_release_lifecycle_errors(mutated), [])

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
            "published tags are immutable",
            "published tags may be rewritten",
            1,
        )
        errors = self.entry_point_versioning_errors(mutated)
        self.assertTrue(any("entry-point versioning" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
