"""Canonical, platform-safe FantasyDisk release-version contract."""
from __future__ import annotations

import re


RELEASE_VERSION_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\.(0|[1-9][0-9]*))?$"
)

# The logical version must be representable by every release consumer. These
# limits preserve Godot PackedInt32 safety and Apple-compatible three-component
# CFBundleVersion mapping: (major + 1).minor.(patch * 10 + hotfix).
MAX_MAJOR = 9_998
MAX_MINOR = 99
MAX_PATCH = 9
MAX_HOTFIX = 9
COMPONENT_LIMITS = (MAX_MAJOR, MAX_MINOR, MAX_PATCH, MAX_HOTFIX)


def release_version_parts(version: str) -> tuple[int, int, int, int]:
    """Parse a canonical X.Y.Z or X.Y.Z.R version or raise ValueError."""
    match = RELEASE_VERSION_RE.fullmatch(version)
    if match is None:
        raise ValueError("version must use canonical X.Y.Z or X.Y.Z.R")
    values = tuple(int(component or "0") for component in match.groups())
    for index, (value, maximum) in enumerate(zip(values, COMPONENT_LIMITS)):
        if value > maximum:
            component = ("major", "minor", "patch", "hotfix")[index]
            raise ValueError(f"{component} component must be in 0..{maximum}")
    return values


def release_version_key(version: str) -> tuple[int, int, int, int]:
    """Return the numeric ordering key after enforcing the shared contract."""
    return release_version_parts(version)


def is_valid_release_version(version: str) -> bool:
    try:
        release_version_parts(version)
    except ValueError:
        return False
    return True
