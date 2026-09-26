#!/usr/bin/env python3
"""Reject content scoped to a later release from an earlier release build."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path, PurePosixPath


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import is_valid_release_version, release_version_key


MANIFEST_PATH = TOOLS_DIR / "release_scope_manifest.json"
MANIFEST_SCHEMA = 1
ENTRY_KEYS = frozenset({"id", "introduced_in", "path", "project_setting", "note"})
TARGET_KEYS = ("path", "project_setting")


def _entry_errors(index: int, entry: object) -> list[str]:
    if not isinstance(entry, dict):
        return [f"entries[{index}]: must be an object"]
    label = f"entries[{index}]"
    if isinstance(entry.get("id"), str) and entry["id"]:
        label = f"entry {entry['id']!r}"
    errors: list[str] = []
    unknown = sorted(set(entry) - ENTRY_KEYS)
    if unknown:
        errors.append(f"{label}: unknown keys {unknown}")
    if not isinstance(entry.get("id"), str) or not entry["id"]:
        errors.append(f"{label}: id must be a non-empty string")
    introduced_in = entry.get("introduced_in")
    if not isinstance(introduced_in, str) or not is_valid_release_version(introduced_in):
        errors.append(f"{label}: introduced_in must be a canonical release version")
    declared = [key for key in TARGET_KEYS if key in entry]
    if len(declared) != 1:
        errors.append(f"{label}: exactly one of {'/'.join(TARGET_KEYS)} is required")
    path = entry.get("path")
    if "path" in entry:
        if not isinstance(path, str) or not path:
            errors.append(f"{label}: path must be a non-empty string")
        # The manifest addresses the release snapshot only. An absolute path or a
        # `..` segment would probe the build host instead, so it fails closed.
        elif PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
            errors.append(f"{label}: path must be repository-relative without '..'")
    if "project_setting" in entry:
        setting = entry.get("project_setting")
        if not isinstance(setting, str) or not setting:
            errors.append(f"{label}: project_setting must be a non-empty string")
    return errors


def manifest_errors(manifest: object) -> list[str]:
    """Validate the manifest itself, so a typo cannot silently disable the gate."""
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    unknown = sorted(set(manifest) - {"schema", "entries"})
    if unknown:
        errors.append(f"manifest: unknown keys {unknown}")
    if manifest.get("schema") != MANIFEST_SCHEMA:
        errors.append(f"manifest: schema must equal {MANIFEST_SCHEMA}")
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        errors.append("manifest: entries must be a list")
        return errors
    for index, entry in enumerate(entries):
        errors.extend(_entry_errors(index, entry))
    ids = [
        entry["id"]
        for entry in entries
        if isinstance(entry, dict) and isinstance(entry.get("id"), str)
    ]
    duplicates = sorted({item for item in ids if ids.count(item) > 1})
    if duplicates:
        errors.append(f"manifest: duplicate entry ids {duplicates}")
    return errors


def _setting_assigned(project_text: str, key: str) -> bool:
    """Whether project.godot assigns *key*. ConfigFile comments start with `;`."""
    return re.search(rf"(?m)^{re.escape(key)}\s*=", project_text) is not None


def scope_violations(manifest: dict, root: Path, version: str) -> list[str]:
    """Report manifest entries that belong to a release later than *version*."""
    target = release_version_key(version)
    project_path = root / "project.godot"
    project_text = (
        project_path.read_text(encoding="utf-8") if project_path.is_file() else ""
    )
    violations: list[str] = []
    for entry in manifest["entries"]:
        introduced_in = entry["introduced_in"]
        if target >= release_version_key(introduced_in):
            continue
        if "path" in entry:
            if not (root / entry["path"]).exists():
                continue
            present = f"path {entry['path']}"
        else:
            if not _setting_assigned(project_text, entry["project_setting"]):
                continue
            present = f"project.godot setting {entry['project_setting']}"
        violations.append(
            f"{entry['id']}: {present} is scoped to {introduced_in} "
            f"and must not reach the {version} build"
        )
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--root", type=Path, default=TOOLS_DIR.parent)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    args = parser.parse_args()
    try:
        release_version_key(args.version)
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        parser.error(str(error))

    errors = manifest_errors(manifest)
    if errors:
        print(f"ERROR: {args.manifest} нарушает release scope contract:")
        for error in errors:
            print(f"    {error}")
        return 2

    violations = scope_violations(manifest, args.root, args.version)
    if violations:
        print(f"ERROR: сборка {args.version} содержит контент более поздней версии:")
        for violation in violations:
            print(f"    {violation}")
        return 2

    print(f"release scope OK: {args.version}, {len(manifest['entries'])} entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
