#!/usr/bin/env python3
"""Publish verified FantasyDisk bytes to the public binary-only repository."""

from __future__ import annotations

import argparse
import base64
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
        # Upload last: latest/download must never point to incomplete installers.
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
        ["gh", "release", "view", tag, "--repo", repository, "--json", "url,isDraft,assets"]
    )
    try:
        payload = json.loads(release.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("distribution release verification returned invalid JSON") from error
    if not isinstance(payload, dict) or payload.get("isDraft") is not draft:
        state = "draft" if draft else "public"
        raise RuntimeError(f"distribution release is not the expected {state} state")
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


def publish(repository: str, version: str, files: list[Path], changelog: Path) -> str:
    if not is_valid_release_version(version):
        raise RuntimeError("release version must use X.Y.Z or X.Y.Z.R")
    if shutil.which("gh") is None:
        raise RuntimeError("GitHub CLI `gh` не установлен")
    run(["gh", "auth", "status", "--hostname", "github.com"])
    default_branch = assert_safe_public_distribution_repository(repository)
    tag = f"v{version}"
    assert_unclaimed_distribution_release(repository, tag)
    assert_unclaimed_distribution_tag(repository, tag)
    title = f"FantasyDisk v{version}"
    run(
        [
            "gh", "release", "create", tag, "--repo", repository,
            "--target", default_branch, "--draft", "--title", title,
            "--notes-file", os.fspath(changelog),
            *[os.fspath(path) for path in files],
        ]
    )
    _assert_release_assets(repository, tag, files, draft=True)
    run(
        [
            "gh", "release", "edit", tag, "--repo", repository,
            "--title", title, "--notes-file", os.fspath(changelog),
            "--draft=false", "--prerelease=false", "--latest=false",
        ]
    )
    release_url = _assert_release_assets(repository, tag, files, draft=False)
    run(["gh", "release", "edit", tag, "--repo", repository, "--latest"])
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
            print("[dry-run] local verification passed; manifest uploads last; nothing was published.")
            return 0
        print(publish(args.repository, args.version, files, changelog))
    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
