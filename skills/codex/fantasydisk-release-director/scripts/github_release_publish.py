#!/usr/bin/env python3
"""Publish verified FantasyDisk bytes to the public binary-only repository."""

from __future__ import annotations

import argparse
import base64
import fnmatch
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[4] / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import RELEASE_VERSION_RE, is_valid_release_version

DEFAULT_REPOSITORY = "FomaBy/FantasyDisk-Releases"
ALLOWED_DISTRIBUTION_ROOT_PATHS = frozenset({"README.md"})
README_MAX_BYTES = 8 * 1024
README_FORBIDDEN_MARKERS = (
    "project.godot",
    "export_presets.cfg",
    "release_webhook",
    "feedback_webhook",
    "authorization:",
    "github_pat_",
    "ghp_",
    "private key",
    "api_key",
    ".gd",
)
HTTP_STATUS_RE = re.compile(r"(?m)^HTTP/[^\s]+\s+(\d{3})\b")
COMMIT_SHA_RE = re.compile(r"[0-9a-f]{40}")
# GitHub has no atomic publish-with-expected-SHA, so the create-only claim stays
# trustworthy only while the platform itself rejects tag rewrites. Both rule
# types must be guaranteed server-side before the first external side effect.
REQUIRED_TAG_RULE_TYPES = frozenset({"update", "deletion"})
RECONCILIATION_GUIDANCE = (
    "the supported path has no rollback: it never deletes, force-updates, or "
    "reuses a published release or tag. Manually inspect the release and tag on "
    "GitHub, keep any public release non-latest, burn this version number, and "
    "publish the next attempt under the next version"
)


def repo_root() -> Path:
    return Path(os.environ.get("FANTASYDISK_REPO", os.getcwd())).resolve()


def verify_local_release(root: Path, version: str) -> Path:
    helper = Path(__file__).with_name("local_release.py")
    result = subprocess.run(
        [sys.executable, helper, "verify", "--version", version, "--repo-root", root],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        sys.exit("Локальная копия релиза не прошла проверку; GitHub publication запрещена")
    try:
        return Path(json.loads(result.stdout)["local_release"]).resolve()
    except (KeyError, TypeError, json.JSONDecodeError):
        sys.exit("Локальная проверка не вернула путь к проверенным байтам релиза")


def release_files(release_dir: Path, version: str) -> tuple[list[Path], Path]:
    if not is_valid_release_version(version):
        raise RuntimeError("release version must use X.Y.Z or X.Y.Z.R")
    posters = sorted(release_dir.glob("*.png"))
    if len(posters) != 1:
        raise RuntimeError("Ожидался ровно один проверенный PNG release poster")
    changelog = release_dir / f"CHANGELOG-{version}.md"
    ordered = [
        release_dir / f"FantasyDisk-{version}-macos.dmg",
        release_dir / f"FantasyDisk-{version}-windows-setup.exe",
        release_dir / "SHA256SUMS.txt",
        changelog,
        posters[0],
        # The manifest is listed last so its upload starts after the installers,
        # but `gh release create` uploads assets concurrently, so completion
        # order is not guaranteed. The enforced invariant lives in publish():
        # the release stays a draft until every asset, including the manifest,
        # is verified uploaded byte-exact, so latest/download can never expose
        # an incomplete installer set.
        release_dir / "update-manifest.json",
    ]
    missing = [path.name for path in ordered if not path.is_file() or path.is_symlink()]
    if missing:
        raise RuntimeError(f"Проверенный релиз неполон: {', '.join(missing)}")
    manifest = json.loads(ordered[-1].read_text(encoding="utf-8"))
    if manifest.get("version") != version:
        raise RuntimeError("update-manifest.json не совпадает с публикуемой версией")
    return ordered, changelog


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"command failed: {' '.join(command)}\n{detail}")
    return result


def safe_distribution_paths(paths: list[str]) -> list[str]:
    """Return paths that would expose non-metadata content in the public repo."""
    return sorted(set(paths) - ALLOWED_DISTRIBUTION_ROOT_PATHS)


def _api_json(route: str) -> dict:
    result = run(["gh", "api", route])
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"GitHub API returned invalid JSON for {route}") from exc
    if not isinstance(payload, dict):
        raise RuntimeError(f"GitHub API returned an unexpected response for {route}")
    return payload


def assert_safe_public_distribution_repository(repository: str) -> str:
    """Prove the distribution repository is public and has no source/secrets."""
    metadata = _api_json(f"repos/{repository}")
    if metadata.get("private") is not False or metadata.get("archived") is True:
        raise RuntimeError("distribution repository must be a non-archived public repository")
    default_branch = str(metadata.get("default_branch", ""))
    if not default_branch:
        raise RuntimeError("distribution repository has no bootstrap branch")
    tree = _api_json(f"repos/{repository}/git/trees/{default_branch}?recursive=1")
    paths = [
        str(item.get("path", ""))
        for item in tree.get("tree", [])
        if isinstance(item, dict) and item.get("type") == "blob"
    ]
    unsafe_paths = safe_distribution_paths(paths)
    if unsafe_paths or set(paths) != ALLOWED_DISTRIBUTION_ROOT_PATHS:
        rendered = ", ".join(unsafe_paths or sorted(paths))
        raise RuntimeError(
            "public distribution repository may contain only README.md before publication; "
            f"found: {rendered or 'no README.md'}"
        )
    readme = _api_json(f"repos/{repository}/contents/README.md")
    try:
        content = base64.b64decode(str(readme["content"]), validate=False)
    except (KeyError, ValueError) as exc:
        raise RuntimeError("cannot read public distribution README") from exc
    if len(content) > README_MAX_BYTES:
        raise RuntimeError("public distribution README is too large for minimal metadata")
    lowered = content.decode("utf-8", errors="replace").lower()
    markers = [marker for marker in README_FORBIDDEN_MARKERS if marker in lowered]
    if markers:
        raise RuntimeError(
            "public distribution README contains source/secret-like material: "
            + ", ".join(markers)
        )
    return default_branch


def assert_immutable_release_enforcement(repository: str) -> None:
    """Prove GitHub-enforced release immutability before any external side effect."""
    result = run(
        ["gh", "api", "--include", f"repos/{repository}/immutable-releases"],
        check=False,
    )
    combined = f"{result.stdout}\n{result.stderr}"
    statuses = HTTP_STATUS_RE.findall(combined)
    if len(statuses) != 1:
        raise RuntimeError(
            "cannot verify immutable release enforcement for the distribution repository"
        )
    status = int(statuses[0])
    if status == 404 and result.returncode:
        raise RuntimeError(
            "distribution repository does not enforce immutable releases; "
            "enable immutable releases before publication"
        )
    if status != 200 or result.returncode:
        raise RuntimeError(
            "cannot verify immutable release enforcement for the distribution repository"
        )
    body_start = result.stdout.find("{")
    if body_start < 0:
        raise RuntimeError("immutable release enforcement check returned no response body")
    try:
        payload = json.loads(result.stdout[body_start:])
    except json.JSONDecodeError as error:
        raise RuntimeError(
            "immutable release enforcement check returned invalid JSON"
        ) from error
    if not isinstance(payload, dict) or payload.get("enabled") is not True:
        raise RuntimeError(
            "distribution repository does not enforce immutable releases; "
            "enable immutable releases before publication"
        )


def _tag_ruleset_pattern_matches(pattern: str, tag: str) -> bool:
    if pattern == "~ALL":
        return True
    if pattern.startswith("refs/tags/"):
        return fnmatch.fnmatchcase(f"refs/tags/{tag}", pattern)
    if pattern.startswith("refs/"):
        return False
    return fnmatch.fnmatchcase(tag, pattern)


def _tag_ruleset_patterns(ref_name: object, key: str) -> list[str]:
    if not isinstance(ref_name, dict):
        raise RuntimeError("tag protection ruleset returned malformed conditions")
    patterns = ref_name.get(key, [])
    if not isinstance(patterns, list) or any(
        not isinstance(pattern, str) for pattern in patterns
    ):
        raise RuntimeError("tag protection ruleset returned malformed conditions")
    return patterns


def assert_release_tag_protection(repository: str, tag: str) -> None:
    """Prove GitHub keeps the claimed tag frozen until immutable publication.

    The refs API claim is atomic, but publication is not: between the last
    pre-public identity check and `gh release edit --draft=false` a mutated tag
    would become a public release on a foreign commit, and immutable releases
    forbid rollback. Only a server-side tag ruleset closes that window, so
    require an active tag ruleset without bypass actors whose rules block both
    update and deletion of this exact release tag before any external side
    effect.
    """
    listing = run(
        ["gh", "api", f"repos/{repository}/rulesets?per_page=100"], check=False
    )
    if listing.returncode:
        raise RuntimeError(
            "cannot verify tag protection rulesets for the distribution repository"
        )
    try:
        summaries = json.loads(listing.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            "tag protection ruleset listing returned invalid JSON"
        ) from error
    if not isinstance(summaries, list):
        raise RuntimeError(
            "tag protection ruleset listing returned an invalid response shape"
        )
    guaranteed_rule_types: set[str] = set()
    for summary in summaries:
        if not isinstance(summary, dict) or not isinstance(summary.get("id"), int):
            raise RuntimeError(
                "tag protection ruleset listing returned malformed entries"
            )
        if summary.get("target") != "tag" or summary.get("enforcement") != "active":
            continue
        detail = _api_json(f"repos/{repository}/rulesets/{summary['id']}")
        if detail.get("target") != "tag" or detail.get("enforcement") != "active":
            continue
        # Any bypass actor voids the server-side guarantee for this ruleset.
        if detail.get("bypass_actors"):
            continue
        conditions = detail.get("conditions")
        if not isinstance(conditions, dict):
            raise RuntimeError("tag protection ruleset returned malformed conditions")
        ref_name = conditions.get("ref_name")
        include = _tag_ruleset_patterns(ref_name, "include")
        exclude = _tag_ruleset_patterns(ref_name, "exclude")
        if any(_tag_ruleset_pattern_matches(pattern, tag) for pattern in exclude):
            continue
        if not any(_tag_ruleset_pattern_matches(pattern, tag) for pattern in include):
            continue
        rules = detail.get("rules")
        if not isinstance(rules, list):
            raise RuntimeError("tag protection ruleset returned malformed rules")
        for rule in rules:
            if not isinstance(rule, dict) or not isinstance(rule.get("type"), str):
                raise RuntimeError("tag protection ruleset returned malformed rules")
            guaranteed_rule_types.add(rule["type"])
    missing = REQUIRED_TAG_RULE_TYPES - guaranteed_rule_types
    if missing:
        raise RuntimeError(
            f"distribution repository does not protect release tag {tag} against "
            f"{', '.join(sorted(missing))}; enable an active tag ruleset without "
            "bypass actors that blocks tag update and deletion before publication"
        )


def resolve_release_target_commit(repository: str, branch: str) -> str:
    """Return the exact commit the immutable release tag must own."""
    payload = _api_json(f"repos/{repository}/git/ref/heads/{branch}")
    if payload.get("ref") != f"refs/heads/{branch}":
        raise RuntimeError("distribution branch lookup returned a different reference")
    target = payload.get("object")
    if (
        not isinstance(target, dict)
        or target.get("type") != "commit"
        or not isinstance(target.get("sha"), str)
        or not COMMIT_SHA_RE.fullmatch(target["sha"])
    ):
        raise RuntimeError("distribution branch does not resolve to an exact commit")
    return target["sha"]


def claim_distribution_tag(repository: str, tag: str, commit_sha: str) -> None:
    """Atomically create the release tag; any conflict or ambiguity fails closed.

    The refs API is create-only: it fails when the reference already exists, so a
    tag that appeared between preflight and this claim blocks publication instead
    of being silently reused. The supported path never deletes, force-updates, or
    reuses an existing tag; a failed claim burns the version number.
    """
    result = run(
        [
            "gh", "api", "--method", "POST", f"repos/{repository}/git/refs",
            "-f", f"ref=refs/tags/{tag}", "-f", f"sha={commit_sha}",
        ],
        check=False,
    )
    if result.returncode:
        raise RuntimeError(
            f"cannot atomically claim distribution tag {tag}; "
            "a concurrent tag/release or an API failure blocks publication"
        )
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("distribution tag claim returned invalid JSON") from error
    if not isinstance(payload, dict) or payload.get("ref") != f"refs/tags/{tag}":
        raise RuntimeError("distribution tag claim returned an unexpected reference")
    claimed = payload.get("object")
    if (
        not isinstance(claimed, dict)
        or claimed.get("type") != "commit"
        or claimed.get("sha") != commit_sha
    ):
        raise RuntimeError("distribution tag claim does not own the expected commit")


def assert_owned_distribution_tag(repository: str, tag: str, commit_sha: str) -> None:
    """Fail closed unless the exact tag still points at our claimed commit."""
    payload = _api_json(f"repos/{repository}/git/ref/tags/{tag}")
    if payload.get("ref") != f"refs/tags/{tag}":
        raise RuntimeError(
            f"distribution tag {tag} identity check returned a different reference"
        )
    target = payload.get("object")
    if (
        not isinstance(target, dict)
        or target.get("type") != "commit"
        or target.get("sha") != commit_sha
    ):
        raise RuntimeError(
            f"distribution tag {tag} no longer points at the claimed release commit; "
            "never reuse or edit a foreign tag"
        )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _assert_release_assets(
    repository: str, tag: str, expected: list[Path], *, draft: bool
) -> str:
    release = run(
        [
            "gh", "release", "view", tag, "--repo", repository,
            "--json", "url,isDraft,isImmutable,assets",
        ]
    )
    try:
        payload = json.loads(release.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("distribution release verification returned invalid JSON") from error
    if not isinstance(payload, dict) or payload.get("isDraft") is not draft:
        state = "draft" if draft else "public"
        raise RuntimeError(f"distribution release is not the expected {state} state")
    if not draft and payload.get("isImmutable") is not True:
        raise RuntimeError(
            "published distribution release is not GitHub-enforced immutable"
        )
    assets = payload.get("assets")
    if not isinstance(assets, list):
        raise RuntimeError("distribution release assets have an invalid response shape")
    expected_by_name = {path.name: path for path in expected}
    if len(expected_by_name) != len(expected):
        raise RuntimeError("release asset input names must be unique")
    actual_by_name: dict[str, dict] = {}
    for asset in assets:
        if not isinstance(asset, dict) or not isinstance(asset.get("name"), str):
            raise RuntimeError("distribution release contains a malformed asset")
        name = asset["name"]
        if name in actual_by_name:
            raise RuntimeError(f"distribution release contains duplicate asset {name}")
        actual_by_name[name] = asset
    if set(actual_by_name) != set(expected_by_name):
        raise RuntimeError(
            "public distribution release asset allowlist mismatch: "
            f"expected {sorted(expected_by_name)}, got {sorted(actual_by_name)}"
        )
    for name, path in expected_by_name.items():
        asset = actual_by_name[name]
        if (
            asset.get("state") != "uploaded"
            or asset.get("size") != path.stat().st_size
            or asset.get("digest") != f"sha256:{_sha256(path)}"
        ):
            raise RuntimeError(f"distribution release asset verification failed: {name}")
    url = payload.get("url")
    if not isinstance(url, str) or not url:
        raise RuntimeError("distribution release has no URL")
    return url


def assert_unclaimed_distribution_release(repository: str, tag: str) -> None:
    """Continue only after the release-tag API proves that no release exists."""
    result = run(
        ["gh", "api", "--include", f"repos/{repository}/releases/tags/{tag}"],
        check=False,
    )
    statuses = HTTP_STATUS_RE.findall(f"{result.stdout}\n{result.stderr}")
    if len(statuses) != 1:
        raise RuntimeError(
            f"cannot verify whether distribution release {tag} already exists"
        )
    status = int(statuses[0])
    if status == 404 and result.returncode:
        return
    if status == 200 and not result.returncode:
        raise RuntimeError(
            f"distribution release {tag} already exists; never overwrite a published public release"
        )
    raise RuntimeError(f"cannot verify whether distribution release {tag} already exists")


def assert_unclaimed_distribution_tag(repository: str, tag: str) -> None:
    """Fail closed unless the exact immutable distribution tag is absent."""
    result = run(
        ["gh", "api", f"repos/{repository}/git/matching-refs/tags/{tag}"],
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"cannot verify whether distribution tag {tag} already exists")
    try:
        refs = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("distribution tag preflight returned invalid JSON") from error
    if not isinstance(refs, list):
        raise RuntimeError("distribution tag preflight returned an invalid response shape")
    expected_ref = f"refs/tags/{tag}"
    for ref in refs:
        if not isinstance(ref, dict) or not isinstance(ref.get("ref"), str):
            raise RuntimeError("distribution tag preflight returned malformed references")
        if ref["ref"] == expected_ref:
            raise RuntimeError(
                f"distribution tag {tag} already exists; never reuse an immutable public tag"
            )


def _describe_public_release_state(repository: str, tag: str) -> str:
    """Best-effort state read for a truthful post-failure reconciliation report."""
    view = run(
        [
            "gh", "release", "view", tag, "--repo", repository,
            "--json", "isDraft,isImmutable",
        ],
        check=False,
    )
    if not view.returncode:
        try:
            payload = json.loads(view.stdout)
        except json.JSONDecodeError:
            payload = None
        if isinstance(payload, dict) and isinstance(payload.get("isDraft"), bool):
            if payload["isDraft"]:
                return f"release {tag} is currently still an unpublished draft"
            return f"release {tag} is currently PUBLIC and non-latest"
    return (
        f"the current state of release {tag} could not be read; it may be an "
        "unpublished draft or already public"
    )


def publish(repository: str, version: str, files: list[Path], changelog: Path) -> str:
    if not is_valid_release_version(version):
        raise RuntimeError("release version must use X.Y.Z or X.Y.Z.R")
    if shutil.which("gh") is None:
        raise RuntimeError("GitHub CLI `gh` не установлен")
    run(["gh", "auth", "status", "--hostname", "github.com"])
    default_branch = assert_safe_public_distribution_repository(repository)
    assert_immutable_release_enforcement(repository)
    tag = f"v{version}"
    assert_release_tag_protection(repository, tag)
    assert_unclaimed_distribution_release(repository, tag)
    assert_unclaimed_distribution_tag(repository, tag)
    release_commit = resolve_release_target_commit(repository, default_branch)
    # First external side effect: the atomic create-only claim. A tag that
    # appeared after preflight fails the claim before create/upload/edit.
    claim_distribution_tag(repository, tag, release_commit)
    title = f"FantasyDisk v{version}"
    created = run(
        [
            "gh", "release", "create", tag, "--repo", repository,
            "--target", release_commit, "--verify-tag", "--draft",
            "--title", title, "--notes-file", os.fspath(changelog),
            *[os.fspath(path) for path in files],
        ],
        check=False,
    )
    if created.returncode:
        detail = (created.stderr or created.stdout).strip()
        raise RuntimeError(
            f"draft release creation failed after the atomic tag claim: {detail}\n"
            "--verify-tag forbids implicitly recreating a deleted claimed tag "
            f"{tag}; at most the claimed bare tag and an unpublished draft with "
            f"partial assets can remain, and {RECONCILIATION_GUIDANCE}"
        )
    assert_owned_distribution_tag(repository, tag, release_commit)
    _assert_release_assets(repository, tag, files, draft=True)
    # Last pre-public identity check: from here to the public edit only the
    # server-side tag ruleset proven before the claim keeps the tag frozen.
    assert_owned_distribution_tag(repository, tag, release_commit)
    published = run(
        [
            "gh", "release", "edit", tag, "--repo", repository,
            "--title", title, "--notes-file", os.fspath(changelog),
            "--draft=false", "--prerelease=false", "--latest=false",
        ],
        check=False,
    )
    if published.returncode:
        detail = (published.stderr or published.stdout).strip()
        state = _describe_public_release_state(repository, tag)
        raise RuntimeError(
            f"public release edit returned an error but may still have been "
            f"applied server-side (applied-but-response-lost): {detail}\n"
            f"{state}; {RECONCILIATION_GUIDANCE}"
        )
    try:
        release_url = _assert_release_assets(repository, tag, files, draft=False)
        assert_owned_distribution_tag(repository, tag, release_commit)
    except RuntimeError as error:
        raise RuntimeError(
            f"{error}\npublic reconciliation required: release {tag} was already "
            f"made public before this verification failed and will stay public "
            f"and non-latest; {RECONCILIATION_GUIDANCE}"
        ) from error
    marked_latest = run(
        ["gh", "release", "edit", tag, "--repo", repository, "--latest"],
        check=False,
    )
    if marked_latest.returncode:
        detail = (marked_latest.stderr or marked_latest.stdout).strip()
        raise RuntimeError(
            f"failed to mark the verified public release {tag} as latest: {detail}\n"
            f"the release is already public, verified, and immutable; after "
            f"confirming the release page, rerun `gh release edit {tag} --repo "
            f"{repository} --latest` manually instead of recreating anything"
        )
    return release_url


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository", default=DEFAULT_REPOSITORY)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not is_valid_release_version(args.version):
        parser.error("--version must use X.Y.Z or X.Y.Z.R")
    root = repo_root()
    release_dir = verify_local_release(root, args.version)
    try:
        files, changelog = release_files(release_dir, args.version)
        if args.dry_run:
            print(f"[dry-run] public release: https://github.com/{args.repository}/releases/tag/v{args.version}")
            for path in files:
                print(f"  • {path.name}")
            print(
                "[dry-run] local verification passed; the release goes public only "
                "after every draft asset, including the manifest, verifies "
                "byte-exact; nothing was published."
            )
            return 0
        print(publish(args.repository, args.version, files, changelog))
    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
