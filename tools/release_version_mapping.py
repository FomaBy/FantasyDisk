#!/usr/bin/env python3
"""Map canonical FantasyDisk release versions to platform metadata."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import re


RELEASE_VERSION_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\.(0|[1-9][0-9]*))?$"
)
HOTFIX_RADIX = 1000


@dataclass(frozen=True)
class PlatformVersionMapping:
    logical_version: str
    macos_short_version: str
    macos_build_version: str
    windows_product_version: str
    windows_file_version: str


def platform_version_mapping(version: str) -> PlatformVersionMapping:
    """Return the platform-valid metadata mapping for a logical release version.

    macOS exposes only three numeric components.  The logical fourth component
    is packed into the build patch component, while the user-visible macOS
    version remains the three-component product version.
    """
    match = RELEASE_VERSION_RE.fullmatch(version)
    if match is None:
        raise ValueError("version must use canonical X.Y.Z or X.Y.Z.R")

    major, minor, patch = (int(component) for component in match.group(1, 2, 3))
    hotfix = int(match.group(4) or "0")
    if hotfix >= HOTFIX_RADIX:
        raise ValueError(f"hotfix component must be in 0..{HOTFIX_RADIX - 1} for macOS mapping")

    macos_short_version = f"{major}.{minor}.{patch}"
    macos_build_version = f"{major}.{minor}.{patch * HOTFIX_RADIX + hotfix}"
    windows_file_version = version if match.group(4) is not None else f"{version}.0"
    return PlatformVersionMapping(
        logical_version=version,
        macos_short_version=macos_short_version,
        macos_build_version=macos_build_version,
        windows_product_version=version,
        windows_file_version=windows_file_version,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    try:
        mapping = platform_version_mapping(args.version)
    except ValueError as error:
        parser.error(str(error))
    print(
        "\t".join(
            (
                mapping.macos_short_version,
                mapping.macos_build_version,
                mapping.windows_product_version,
                mapping.windows_file_version,
            )
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
