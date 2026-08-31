#!/usr/bin/env python3
"""Fast, deterministic repository invariants for CI and Windows releases."""
from __future__ import annotations

import argparse
import functools
import re
import subprocess
import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import RELEASE_VERSION_RE, is_valid_release_version
from release_version_mapping import platform_version_mapping, release_assignment_errors


RUNTIME_SUFFIXES = {".gd", ".godot", ".tscn", ".tres", ".cfg"}
RESOURCE_RE = re.compile(r"res://[A-Za-z0-9_./@+\-]+")
FANTASYDISK_PROJECT_NAME = "FantasyDisk"
FANTASYDISK_PLAYER_IDENTITY = ("scenes/Player.tscn", "scripts/player.gd")
PLAYER_IMPORT_PROBE = "tests/import_cache_player_load_test.gd"
PLAYER_IMPORT_PROBE_CONTRACT = (
    "extends SceneTree",
    'preload("res://scenes/Player.tscn")',
    "PlayerScene.instantiate()",
    "player.free()",
)
LEGACY_LINE_CEILINGS = {
    # FAN-3824: монолит разрезан на scripts/ui/screens/**; фасад — не более 500
    # строк. Потолки только ужимаются (tests/test_quality_static_guard.py).
    "scripts/ui_screens.gd": 500,
    # FAN-3840: монолит разрезан на scripts/classes/**; фасад — не более 500 строк.
    "scripts/class_weapon.gd": 500,
    "scripts/player.gd": 4300,
    "scripts/progression_data.gd": 2500,
    "scripts/pause_stats_menu.gd": 2250,
    "scripts/enemy.gd": 1950,
    "scripts/cutout_rig_2d.gd": 1950,
    "scripts/main.gd": 1850,
    "scripts/route_map_screen.gd": 1600,
    "scripts/combat_director.gd": 1500,
    "scripts/meta_progression.gd": 1500,
    "scripts/progression_data_weapons.gd": 1280,
    "scripts/progression_data_characters.gd": 1250,
}
NEW_SCRIPT_LINE_LIMIT = 1200


def tracked_files(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


@functools.cache
def _head_blob(root: Path, relative: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"HEAD:{relative}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"git show HEAD:{relative} failed: {detail or 'no error output'}"
        )
    return result.stdout


def _tracked_text(root: Path, relative: str, *, errors: str = "strict") -> str:
    path = root / relative
    if path.is_file():
        return path.read_text(encoding="utf-8", errors=errors)
    return _head_blob(root.resolve(), relative).decode("utf-8", errors=errors)


def _index_has_path(root: Path, relative: str) -> bool:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--error-unmatch", "--", relative],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def _quoted_value(text: str, key: str) -> str:
    match = re.search(rf"(?m)^{re.escape(key)}=\"([^\"]*)\"$", text)
    return match.group(1) if match else ""


def _windows_block(export_text: str) -> str:
    marker = 'name="Windows Desktop"'
    marker_at = export_text.find(marker)
    if marker_at < 0:
        return ""
    start = export_text.rfind("\n[preset.", 0, marker_at)
    start = 0 if start < 0 else start + 1
    next_match = re.search(r"(?m)^\[preset\.\d+\]$", export_text[marker_at + len(marker):])
    if next_match is None:
        return export_text[start:]
    end = marker_at + len(marker) + next_match.start()
    return export_text[start:end]


def case_and_resource_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    exact = set(tracked)
    folded: dict[str, list[str]] = {}
    for path in tracked:
        folded.setdefault(path.casefold(), []).append(path)
    for variants in folded.values():
        if len(variants) > 1:
            errors.append("case-insensitive tracked-path collision: " + ", ".join(variants))

    for source in tracked:
        path = root / source
        if path.suffix not in RUNTIME_SUFFIXES:
            continue
        try:
            text = _tracked_text(root, source)
        except UnicodeDecodeError:
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            for match in RESOURCE_RE.finditer(line):
                resource = match.group(0).rstrip(".,;:)]}\"'")
                relative = resource.removeprefix("res://")
                if relative in exact or relative.startswith(".godot/"):
                    continue
                variants = folded.get(relative.casefold(), [])
                if variants:
                    errors.append(
                        f"{source}:{line_number}: resource case mismatch: "
                        f"{resource} (tracked as {variants[0]})"
                    )
    return errors


def version_and_windows_errors(root: Path) -> list[str]:
    errors: list[str] = []
    project = (root / "project.godot").read_text(encoding="utf-8")
    exports = (root / "export_presets.cfg").read_text(encoding="utf-8")
    windows = _windows_block(exports)
    version = _quoted_value(project, "config/version")
    if not version:
        errors.append("project.godot: config/version is missing")
    elif not is_valid_release_version(version):
        errors.append("project.godot: config/version must use the canonical bounded X.Y.Z or X.Y.Z.R contract")
    mapping = None
    if is_valid_release_version(version):
        try:
            mapping = platform_version_mapping(version)
        except ValueError as error:
            errors.append(f"project.godot: config/version {error}")
    if mapping is not None:
        errors.extend(release_assignment_errors(project, exports, version, mapping))

    required_project = [
        'config/features=PackedStringArray("4.7")',
        'renderer/rendering_method="gl_compatibility"',
        'renderer/rendering_method.mobile="gl_compatibility"',
    ]
    for line in required_project:
        if line not in project:
            errors.append(f"project.godot: required Windows-safe setting missing: {line}")

    required_windows = [
        'platform="Windows Desktop"',
        'binary_format/embed_pck=true',
        'binary_format/architecture="x86_64"',
        'texture_format/s3tc_bptc=true',
        'texture_format/etc2_astc=false',
        'application/export_angle=0',
        'application/export_d3d12=0',
    ]
    if not windows:
        errors.append("export_presets.cfg: Windows Desktop preset is missing")
    else:
        for line in required_windows:
            if line not in windows:
                errors.append(f"Windows Desktop preset: required setting missing: {line}")
        exclude = _quoted_value(windows, "exclude_filter")
        for fragment in (".godot/*", "feedback_webhook.cfg", "docs/*", "tools/*", "tests/*"):
            if fragment not in exclude:
                errors.append(f"Windows Desktop preset: exclude_filter must contain {fragment}")
    return errors


def architecture_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    for relative in tracked:
        if not relative.startswith("scripts/") or not relative.endswith(".gd"):
            continue
        line_count = len(_tracked_text(root, relative).splitlines())
        ceiling = LEGACY_LINE_CEILINGS.get(relative, NEW_SCRIPT_LINE_LIMIT)
        if line_count > ceiling:
            errors.append(
                f"{relative}: {line_count} lines exceeds ratchet {ceiling}; "
                "extract a focused module instead of growing the monolith"
            )
    return errors


def script_uid_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    tracked_paths = {Path(relative) for relative in tracked}
    ignored_directories = {
        path.parent for path in tracked_paths if path.name == ".gdignore"
    }
    for relative in tracked:
        path = Path(relative)
        is_ignored = any(parent in ignored_directories for parent in path.parents)
        if path.suffix != ".gd" or is_ignored:
            continue
        sidecar = Path(f"{path}.uid")
        if sidecar not in tracked_paths:
            errors.append(f"{path}: missing committed .uid sidecar")
    return errors


def player_import_probe_errors(root: Path, tracked: list[str]) -> list[str]:
    """Require the real Player import probe only in the full FantasyDisk tree."""
    if "project.godot" not in tracked:
        return []
    try:
        project = _tracked_text(root, "project.godot")
    except (OSError, RuntimeError, UnicodeDecodeError):
        return []
    if _quoted_value(project, "config/name") != FANTASYDISK_PROJECT_NAME:
        return []
    if not all(path in tracked for path in FANTASYDISK_PLAYER_IDENTITY):
        return []

    errors: list[str] = []
    if not _index_has_path(root, PLAYER_IMPORT_PROBE):
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required FantasyDisk Player import probe must be tracked"
        )
    probe = root / PLAYER_IMPORT_PROBE
    if not probe.is_file() or probe.is_symlink():
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required FantasyDisk Player import probe is missing"
        )
        return errors
    try:
        source = probe.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required Player import probe contract is unreadable"
        )
        return errors
    missing = [fragment for fragment in PLAYER_IMPORT_PROBE_CONTRACT if fragment not in source]
    if missing:
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required Player import probe contract is incomplete: "
            + ", ".join(missing)
        )
    return errors


def credential_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    forbidden_marker = "BUILTIN_WEBHOOK_" + "B64"
    for relative in tracked:
        if not relative.endswith((".gd", ".py", ".sh")):
            continue
        text = _tracked_text(root, relative, errors="ignore")
        if forbidden_marker in text:
            errors.append(f"{relative}: reversible built-in webhook credential is forbidden")
    return errors


def collect_errors(root: Path) -> list[str]:
    tracked = tracked_files(root)
    return (
        case_and_resource_errors(root, tracked)
        + version_and_windows_errors(root)
        + architecture_errors(root, tracked)
        + script_uid_errors(root, tracked)
        + player_import_probe_errors(root, tracked)
        + credential_errors(root, tracked)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    errors = collect_errors(root)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"Static quality guard failed: {len(errors)} error(s).", file=sys.stderr)
        return 1
    print("Static quality guard passed (case/version/Windows/architecture/sidecars/credentials).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
