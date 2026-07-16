#!/usr/bin/env python3
"""Publish a verified FantasyDisk package as the public GitHub Release."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


DEFAULT_REPOSITORY = "FomaBy/FantasyDisk"
SEMVER_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")


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
        # Upload last: /releases/latest/download/update-manifest.json must never
        # point at a release whose installers have not finished uploading.
        release_dir / "update-manifest.json",
    ]
    missing = [path.name for path in ordered if not path.is_file()]
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


def publish(repository: str, version: str, files: list[Path], changelog: Path) -> str:
    if shutil.which("gh") is None:
        raise RuntimeError("GitHub CLI `gh` не установлен")
    run(["gh", "auth", "status", "--hostname", "github.com"])
    tag = f"v{version}"
    run(["gh", "api", f"repos/{repository}/git/ref/tags/{tag}"])
    view = run(
        ["gh", "release", "view", tag, "--repo", repository, "--json", "url,isDraft"],
        check=False,
    )
    title = f"FantasyDisk v{version}"
    if view.returncode:
        run(
            [
                "gh", "release", "create", tag, "--repo", repository,
                "--verify-tag", "--draft", "--title", title,
                "--notes-file", os.fspath(changelog),
                *[os.fspath(path) for path in files],
            ]
        )
    else:
        # The durable local gate makes --clobber idempotent and prevents an
        # operator from replacing published assets with unverified bytes.
        run(
            [
                "gh", "release", "upload", tag, "--repo", repository,
                "--clobber", *[os.fspath(path) for path in files],
            ]
        )
    run(
        [
            "gh", "release", "edit", tag, "--repo", repository,
            "--title", title, "--notes-file", os.fspath(changelog),
            "--draft=false", "--prerelease=false", "--latest",
        ]
    )
    final = run(["gh", "release", "view", tag, "--repo", repository, "--json", "url"])
    return str(json.loads(final.stdout)["url"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository", default=DEFAULT_REPOSITORY)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not SEMVER_RE.fullmatch(args.version):
        parser.error("--version must be strict SemVer X.Y.Z")
    root = repo_root()
    release_dir = verify_local_release(root, args.version)
    try:
        files, changelog = release_files(release_dir, args.version)
        if args.dry_run:
            print(f"[dry-run] public release: https://github.com/{args.repository}/releases/tag/v{args.version}")
            for path in files:
                print(f"  • {path.name}")
            print("[dry-run] update-manifest.json uploads last; nothing was published.")
            return 0
        print(publish(args.repository, args.version, files, changelog))
    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
