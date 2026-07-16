#!/usr/bin/env python3
"""Verify the public FantasyDisk distribution without GitHub credentials."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_REPOSITORY = "FomaBy/FantasyDisk-Releases"
EXPECTED_ROOT_PATHS = {"README.md"}
README_FORBIDDEN_MARKERS = {
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
}
RELEASE_VERSION_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\.(0|[1-9][0-9]*))?$"
)
USER_AGENT = "FantasyDisk-Public-Release-Verify/1.0"


class PublicVerificationError(RuntimeError):
    """The public release is inaccessible, incomplete, or not byte-identical."""


def _request(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            return response.read()
    except urllib.error.URLError as exc:
        raise PublicVerificationError(f"unauthenticated request failed: {url}") from exc


def _json(url: str) -> dict:
    try:
        payload = json.loads(_request(url).decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise PublicVerificationError(f"invalid public JSON: {url}") from exc
    if not isinstance(payload, dict):
        raise PublicVerificationError(f"unexpected public JSON shape: {url}")
    return payload


def _sha256_download(url: str) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    digest = hashlib.sha256()
    size = 0
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                digest.update(block)
                size += len(block)
    except urllib.error.URLError as exc:
        raise PublicVerificationError(f"unauthenticated asset download failed: {url}") from exc
    return size, digest.hexdigest()


def _checksums(payload: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for line in payload.splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) == 2 and re.fullmatch(r"[0-9a-fA-F]{64}", parts[0]):
            parsed[parts[1].lstrip(" *")] = parts[0].lower()
    return parsed


def _local_digest(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
            size += len(block)
    return size, digest.hexdigest()


def _verify_public_tree(repository: str) -> None:
    api = f"https://api.github.com/repos/{repository}"
    metadata = _json(api)
    if metadata.get("private") is not False or metadata.get("archived") is True:
        raise PublicVerificationError("distribution repository is not public and active")
    branch = str(metadata.get("default_branch", ""))
    tree = _json(f"{api}/git/trees/{branch}?recursive=1")
    paths = {
        str(item.get("path", ""))
        for item in tree.get("tree", [])
        if isinstance(item, dict) and item.get("type") == "blob"
    }
    if paths != EXPECTED_ROOT_PATHS:
        raise PublicVerificationError(
            f"public distribution repository contains non-metadata files: {sorted(paths)}"
        )
    readme = _json(f"{api}/contents/README.md")
    try:
        content = base64.b64decode(str(readme["content"]), validate=False)
    except (KeyError, ValueError) as exc:
        raise PublicVerificationError("public distribution README cannot be decoded") from exc
    lowered = content.decode("utf-8", errors="replace").lower()
    markers = sorted(marker for marker in README_FORBIDDEN_MARKERS if marker in lowered)
    if markers:
        raise PublicVerificationError(
            "public distribution README contains source/secret-like material: " + ", ".join(markers)
        )


def verify_public_distribution(repository: str, version: str, local_release: Path) -> dict:
    if not RELEASE_VERSION_RE.fullmatch(version):
        raise PublicVerificationError("release version must use X.Y.Z or X.Y.Z.R")
    _verify_public_tree(repository)
    tag = f"v{version}"
    api = f"https://api.github.com/repos/{repository}"
    latest = _json(f"{api}/releases/latest")
    if latest.get("tag_name") != tag or latest.get("draft") or latest.get("prerelease"):
        raise PublicVerificationError("latest public release does not match the requested stable version")
    names = {
        f"FantasyDisk-{version}-macos.dmg",
        f"FantasyDisk-{version}-windows-setup.exe",
        "SHA256SUMS.txt",
        f"CHANGELOG-{version}.md",
        f"fantasydisk_{version.replace('.', '')}_announcement.png",
        "update-manifest.json",
    }
    assets = {
        str(asset.get("name", "")): str(asset.get("browser_download_url", ""))
        for asset in latest.get("assets", [])
        if isinstance(asset, dict)
    }
    if set(assets) != names or not all(assets.values()):
        raise PublicVerificationError("public release asset allowlist mismatch")
    manifest_url = f"https://github.com/{repository}/releases/latest/download/update-manifest.json"
    try:
        manifest = json.loads(_request(manifest_url).decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise PublicVerificationError("latest public update manifest is invalid") from exc
    if not isinstance(manifest, dict) or manifest.get("version") != version:
        raise PublicVerificationError("latest public update manifest has the wrong version")
    release_url = f"https://github.com/{repository}/releases/tag/{tag}"
    if manifest.get("release_url") != release_url:
        raise PublicVerificationError("latest public update manifest has an untrusted release URL")
    sums = _checksums(_request(assets["SHA256SUMS.txt"]).decode("utf-8"))
    verified: dict[str, dict[str, int | str]] = {}
    for platform, name in (("macos", f"FantasyDisk-{version}-macos.dmg"), ("windows", f"FantasyDisk-{version}-windows-setup.exe")):
        asset = manifest.get("assets", {}).get(platform)
        expected_url = f"https://github.com/{repository}/releases/download/{tag}/{name}"
        if not isinstance(asset, dict) or asset.get("name") != name or asset.get("url") != expected_url:
            raise PublicVerificationError(f"manifest asset URL is invalid for {platform}")
        remote_size, remote_hash = _sha256_download(str(asset["url"]))
        local_path = local_release / name
        local_size, local_hash = _local_digest(local_path)
        if (
            remote_size != asset.get("size")
            or remote_hash != asset.get("sha256")
            or sums.get(name) != remote_hash
            or (remote_size, remote_hash) != (local_size, local_hash)
        ):
            raise PublicVerificationError(f"public installer bytes do not match durable release: {name}")
        verified[platform] = {"name": name, "size": remote_size, "sha256": remote_hash}
    for name in names - {f"FantasyDisk-{version}-macos.dmg", f"FantasyDisk-{version}-windows-setup.exe"}:
        remote_size, remote_hash = _sha256_download(assets[name])
        local_size, local_hash = _local_digest(local_release / name)
        if (remote_size, remote_hash) != (local_size, local_hash):
            raise PublicVerificationError(f"public metadata bytes do not match durable release: {name}")
    return {
        "ok": True,
        "repository": repository,
        "release_url": release_url,
        "manifest_url": manifest_url,
        "assets": verified,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository", default=DEFAULT_REPOSITORY)
    parser.add_argument("--local-release", required=True, type=Path)
    args = parser.parse_args()
    if not RELEASE_VERSION_RE.fullmatch(args.version):
        parser.error("--version must use X.Y.Z or X.Y.Z.R")
    try:
        report = verify_public_distribution(args.repository, args.version, args.local_release.resolve())
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    except (OSError, PublicVerificationError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
