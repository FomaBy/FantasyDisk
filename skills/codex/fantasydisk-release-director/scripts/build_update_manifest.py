#!/usr/bin/env python3
"""Build the signed-installer manifest consumed by FantasyDisk 0.2.2+."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


REPOSITORY = "FomaBy/FantasyDisk-Releases"
SCHEMA_VERSION = 1
FIRST_UPDATER_VERSION = "0.2.2"
RELEASE_VERSION_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\.(0|[1-9][0-9]*))?$"
)


class ManifestError(RuntimeError):
    """The release package cannot produce a trustworthy update manifest."""


def _version_key(version: str) -> tuple[int, int, int, int]:
    if not RELEASE_VERSION_RE.fullmatch(version):
        raise ManifestError(f"version must use X.Y.Z or X.Y.Z.R: {version}")
    parts = [int(part) for part in version.split(".")]
    return tuple(parts + [0] * (4 - len(parts)))  # type: ignore[return-value]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(
    *, version: str, release_dir: Path, minimum_supported_version: str = FIRST_UPDATER_VERSION
) -> dict:
    version_key = _version_key(version)
    minimum_supported_key = _version_key(minimum_supported_version)
    if minimum_supported_key > version_key:
        raise ManifestError("minimum supported version cannot be newer than the release")
    tag = f"v{version}"
    asset_names = {
        "macos": f"FantasyDisk-{version}-macos.dmg",
        "windows": f"FantasyDisk-{version}-windows-setup.exe",
    }
    assets: dict[str, dict] = {}
    for platform_name, asset_name in asset_names.items():
        asset_path = release_dir / asset_name
        if not asset_path.is_file() or asset_path.is_symlink():
            raise ManifestError(f"missing release installer: {asset_path}")
        size = asset_path.stat().st_size
        if size <= 0:
            raise ManifestError(f"empty release installer: {asset_path}")
        assets[platform_name] = {
            "name": asset_name,
            "url": (
                f"https://github.com/{REPOSITORY}/releases/download/{tag}/{asset_name}"
            ),
            "sha256": _sha256(asset_path),
            "size": size,
        }
    return {
        "schema_version": SCHEMA_VERSION,
        "version": version,
        "minimum_supported_version": minimum_supported_version,
        "release_url": f"https://github.com/{REPOSITORY}/releases/tag/{tag}",
        "assets": assets,
    }


def write_manifest(payload: dict, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--release-dir", required=True, type=Path)
    parser.add_argument("--minimum-supported-version", default=FIRST_UPDATER_VERSION)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    release_dir = args.release_dir.resolve()
    output = args.output.resolve() if args.output else release_dir / "update-manifest.json"
    try:
        payload = build_manifest(
            version=args.version,
            release_dir=release_dir,
            minimum_supported_version=args.minimum_supported_version,
        )
        write_manifest(payload, output)
    except (ManifestError, OSError) as exc:
        parser.error(str(exc))
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
