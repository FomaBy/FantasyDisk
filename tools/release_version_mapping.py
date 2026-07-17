#!/usr/bin/env python3
"""Map canonical FantasyDisk release versions to platform metadata."""
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from release_version_contract import RELEASE_VERSION_RE, release_version_parts


HOTFIX_RADIX = 10
PRESET_HEADER_RE = re.compile(r"^\[preset\.(\d+)\]$")


@dataclass(frozen=True)
class PlatformVersionMapping:
    logical_version: str
    macos_short_version: str
    macos_build_version: str
    windows_product_version: str
    windows_file_version: str


def _sections(text: str) -> dict[str, list[str]]:
    """Return raw Godot config sections without normalizing duplicate lines."""
    sections: dict[str, list[str]] = {}
    current = ""
    for line in text.splitlines():
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, [])
            continue
        if current:
            sections[current].append(line)
    return sections


def _exact_assignment_errors(
    section: list[str], key: str, expected: str, label: str
) -> list[str]:
    assignments = [line for line in section if line.startswith(f"{key}=")]
    if len(assignments) != 1:
        return [f"{label}: {key} must have exactly one assignment"]
    if assignments[0] != f'{key}="{expected}"':
        return [f"{label}: {key} must equal {expected!r}"]
    return []


def _managed_assignment_locations(
    sections: dict[str, list[str]], keys: tuple[str, ...]
) -> dict[str, list[tuple[str, str]]]:
    """Find every managed assignment, including nonexact look-alike keys."""
    locations = {key: [] for key in keys}
    for section_name, lines in sections.items():
        for line in lines:
            if "=" not in line or line.lstrip().startswith("#"):
                continue
            left_hand_side = line.split("=", 1)[0]
            for key in keys:
                if key in left_hand_side:
                    locations[key].append((section_name, line))
    return locations


def release_assignment_errors(
    project_text: str, export_text: str, version: str, mapping: PlatformVersionMapping
) -> list[str]:
    """Validate exact, unique version fields in their intended Godot sections."""
    errors: list[str] = []
    project_sections = _sections(project_text)
    application = project_sections.get("application", [])
    errors.extend(
        _exact_assignment_errors(
            application, "config/version", version, "project.godot [application]"
        )
    )
    project_locations = _managed_assignment_locations(
        project_sections, ("config/version",)
    )
    expected_project_location = ("application", f'config/version="{version}"')
    if project_locations["config/version"] != [expected_project_location]:
        errors.append(
            "project.godot: config/version must have exactly one exact assignment "
            "in [application]"
        )

    export_sections = _sections(export_text)
    platform_fields = {
        "macOS": {
            "application/short_version": mapping.macos_short_version,
            "application/version": mapping.macos_build_version,
        },
        "Windows Desktop": {
            "application/product_version": mapping.windows_product_version,
            "application/file_version": mapping.windows_file_version,
        },
    }
    expected_locations: dict[str, tuple[str, str, str]] = {}
    for platform, fields in platform_fields.items():
        preset_sections = [
            name
            for name, lines in export_sections.items()
            if PRESET_HEADER_RE.fullmatch(f"[{name}]")
            and lines.count(f'platform="{platform}"') == 1
        ]
        label = f"export_presets.cfg {platform} preset"
        if len(preset_sections) != 1:
            errors.append(f"{label}: expected exactly one preset")
            continue
        preset = preset_sections[0]
        options = export_sections.get(f"{preset}.options")
        if options is None:
            errors.append(f"{label}: options section is missing")
            continue
        for key, expected in fields.items():
            errors.extend(_exact_assignment_errors(options, key, expected, label))
            expected_locations[key] = (
                f"{preset}.options",
                f'{key}="{expected}"',
                platform,
            )

    # Version fields are global release identity, not preset-local conveniences.
    # A correct assignment in the owner preset must not conceal a duplicate or
    # conflicting copy in another platform's options (or any other section).
    locations = _managed_assignment_locations(
        export_sections, tuple(expected_locations)
    )
    for key, (
        expected_section,
        expected_line,
        platform,
    ) in expected_locations.items():
        if locations[key] != [(expected_section, expected_line)]:
            errors.append(
                f"export_presets.cfg: {key} must have exactly one exact assignment "
                f"in {platform} preset options"
            )
    return errors


def validate_release_assignments(
    project_path: Path, export_path: Path, version: str, mapping: PlatformVersionMapping
) -> None:
    errors = release_assignment_errors(
        project_path.read_text(encoding="utf-8"),
        export_path.read_text(encoding="utf-8"),
        version,
        mapping,
    )
    if errors:
        raise ValueError("; ".join(errors))


def platform_version_mapping(version: str) -> PlatformVersionMapping:
    """Return the platform-valid metadata mapping for a logical release version.

    macOS exposes only three numeric components.  The logical fourth component
    is packed into the build patch component, while the user-visible macOS
    version remains the three-component product version.
    """
    major, minor, patch, hotfix = release_version_parts(version)

    macos_short_version = f"{major}.{minor}.{patch}"
    # CFBundleVersion retains three numeric components. The first component is
    # positive and the third stays within two digits, as required by the
    # compatibility policy based on Apple's Info.plist guidance.
    macos_build_version = f"{major + 1}.{minor}.{patch * HOTFIX_RADIX + hotfix}"
    windows_file_version = version if version.count(".") == 3 else f"{version}.0"
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
    parser.add_argument("--project", type=Path)
    parser.add_argument("--export-presets", type=Path)
    args = parser.parse_args()
    if bool(args.project) != bool(args.export_presets):
        parser.error("--project and --export-presets must be used together")
    try:
        mapping = platform_version_mapping(args.version)
        if args.project and args.export_presets:
            validate_release_assignments(
                args.project, args.export_presets, args.version, mapping
            )
    except (OSError, ValueError) as error:
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
