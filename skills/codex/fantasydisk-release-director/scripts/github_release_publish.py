#!/usr/bin/env python3
"""Publish verified FantasyDisk bytes to the public binary-only repository."""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


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
RELEASE_VERSION_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\.(0|[1-9][0-9]*))?$"
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
    if not RELEASE_VERSION_RE.fullmatch(version):
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


def _assert_release_assets(repository: str, tag: str, expected: list[Path]) -> str:
    release = run(
        ["gh", "release", "view", tag, "--repo", repository, "--json", "url,isDraft,assets"]
    )
    payload = json.loads(release.stdout)
    if payload.get("isDraft"):
        raise RuntimeError("public distribution release is still draft")
    names = {
        str(asset.get("name", ""))
        for asset in payload.get("assets", [])
        if isinstance(asset, dict)
    }
    expected_names = {path.name for path in expected}
    if names != expected_names:
        raise RuntimeError(
            "public distribution release asset allowlist mismatch: "
            f"expected {sorted(expected_names)}, got {sorted(names)}"
        )
    return str(payload["url"])


def publish(repository: str, version: str, files: list[Path], changelog: Path) -> str:
    if not RELEASE_VERSION_RE.fullmatch(version):
        raise RuntimeError("release version must use X.Y.Z or X.Y.Z.R")
    if shutil.which("gh") is None:
        raise RuntimeError("GitHub CLI `gh` не установлен")
    run(["gh", "auth", "status", "--hostname", "github.com"])
    default_branch = assert_safe_public_distribution_repository(repository)
    tag = f"v{version}"
    view = run(
        ["gh", "release", "view", tag, "--repo", repository, "--json", "url,isDraft"],
        check=False,
    )
    if not view.returncode:
        raise RuntimeError(
            f"distribution release {tag} already exists; never overwrite a published public release"
        )
    title = f"FantasyDisk v{version}"
    run(
        [
            "gh", "release", "create", tag, "--repo", repository,
            "--target", default_branch, "--draft", "--title", title,
            "--notes-file", os.fspath(changelog),
            *[os.fspath(path) for path in files],
        ]
    )
    run(
        [
            "gh", "release", "edit", tag, "--repo", repository,
            "--title", title, "--notes-file", os.fspath(changelog),
            "--draft=false", "--prerelease=false", "--latest",
        ]
    )
    return _assert_release_assets(repository, tag, files)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository", default=DEFAULT_REPOSITORY)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not RELEASE_VERSION_RE.fullmatch(args.version):
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
