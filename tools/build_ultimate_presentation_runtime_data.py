#!/usr/bin/env python3
"""FAN-3985: derive the exported weapon-ultimate presentation data.

The class reference manifests under ``docs/design/references/weapon_ultimates/
<class>/manifest.json`` stay the single authored source for every weapon
ultimate presentation record.  ``docs/*`` is excluded from both export presets,
so the runtime bridge (``WeaponUltimatePresentationManifest``) reads only the
derived ``data/ultimates/presentation/<class>.json`` documents this tool
writes.  They carry exactly the record fields the runtime consumes and nothing
else — no evidence, provenance, contract or prose.

The derived files are committed so the editor and the exported build run the
same code path.  ``tests/test_ultimate_presentation_runtime_data.py`` fails
whenever a committed file differs from a fresh regeneration, so the runtime
copy can never silently drift from the authored manifest.

Usage:
    python3 tools/build_ultimate_presentation_runtime_data.py          # write
    python3 tools/build_ultimate_presentation_runtime_data.py --check  # verify
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT / "docs" / "design" / "references" / "weapon_ultimates"
RUNTIME_ROOT = ROOT / "data" / "ultimates" / "presentation"
GENERATOR = "tools/build_ultimate_presentation_runtime_data.py"
SCHEMA_VERSION = 1

# Weapon-record fields WeaponUltimatePresentationManifest.class_weapon_record
# reads.  Optional blocks are copied verbatim only when the authored record
# declares them, so a v1 record keeps its exact shape.
REQUIRED_WEAPON_FIELDS = ("weapon_id", "scene_path", "timing_seconds", "performance")
OPTIONAL_WEAPON_FIELDS = ("pivot", "presence", "identity", "quality")


class RuntimeDataError(RuntimeError):
    """A reference manifest cannot produce a valid runtime document."""


def reference_manifest_paths(reference_root: Path = REFERENCE_ROOT) -> list[Path]:
    return sorted(reference_root.glob("*/manifest.json"))


def runtime_document_path(class_id: str, runtime_root: Path = RUNTIME_ROOT) -> Path:
    return runtime_root / f"{class_id}.json"


def build_document(manifest: dict, manifest_path: Path, project_root: Path = ROOT) -> dict:
    """The runtime document for one authored class manifest."""
    relative = manifest_path.resolve().relative_to(project_root.resolve()).as_posix()
    class_id = manifest.get("class_id")
    if not isinstance(class_id, str) or not class_id:
        raise RuntimeDataError(f"{relative}: class_id must be a non-empty string")
    expected_class = manifest_path.parent.name
    if class_id != expected_class:
        raise RuntimeDataError(f"{relative}: class_id {class_id!r} does not match directory {expected_class!r}")
    weapons = manifest.get("weapons")
    if not isinstance(weapons, list) or not weapons:
        raise RuntimeDataError(f"{relative}: weapons must be a non-empty list")
    records: list[dict] = []
    seen: set[str] = set()
    for index, weapon in enumerate(weapons):
        description = f"{relative}: weapons[{index}]"
        if not isinstance(weapon, dict):
            raise RuntimeDataError(f"{description} must be an object")
        for field in REQUIRED_WEAPON_FIELDS:
            if field not in weapon:
                raise RuntimeDataError(f"{description} is missing {field!r}")
        weapon_id = weapon["weapon_id"]
        if not isinstance(weapon_id, str) or not weapon_id:
            raise RuntimeDataError(f"{description}.weapon_id must be a non-empty string")
        if weapon_id in seen:
            raise RuntimeDataError(f"{description}.weapon_id {weapon_id!r} is declared twice")
        seen.add(weapon_id)
        scene_path = weapon["scene_path"]
        if not isinstance(scene_path, str) or not scene_path:
            raise RuntimeDataError(f"{description}.scene_path must be a non-empty string")
        scene_relative = scene_path.removeprefix("res://")
        if scene_relative.startswith("/") or ".." in Path(scene_relative).parts:
            raise RuntimeDataError(f"{description}.scene_path must stay within the project: {scene_path!r}")
        if not (project_root / scene_relative).is_file():
            raise RuntimeDataError(f"{description}.scene_path does not exist: {scene_path!r}")
        record: dict = {}
        for field in REQUIRED_WEAPON_FIELDS + OPTIONAL_WEAPON_FIELDS:
            if field in weapon:
                record[field] = json.loads(json.dumps(weapon[field]))
        record["scene_path"] = f"res://{scene_relative}"
        records.append(record)
    return {
        "schema_version": SCHEMA_VERSION,
        "class_id": class_id,
        "generated_from": relative,
        "generator": GENERATOR,
        "weapons": records,
    }


def render(document: dict) -> str:
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def build_all(reference_root: Path = REFERENCE_ROOT, project_root: Path = ROOT) -> dict[str, str]:
    """``class_id`` → rendered runtime document, for every authored manifest."""
    rendered: dict[str, str] = {}
    for manifest_path in reference_manifest_paths(reference_root):
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise RuntimeDataError(f"cannot read {manifest_path}: {exc}") from exc
        if not isinstance(manifest, dict):
            raise RuntimeDataError(f"{manifest_path}: manifest must be a JSON object")
        document = build_document(manifest, manifest_path, project_root)
        rendered[document["class_id"]] = render(document)
    if not rendered:
        raise RuntimeDataError(f"no class manifests under {reference_root}")
    return rendered


def _display(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def stale_documents(
    rendered: dict[str, str], runtime_root: Path = RUNTIME_ROOT
) -> list[str]:
    """Human-readable differences between *rendered* and the committed files."""
    problems: list[str] = []
    for class_id, text in rendered.items():
        path = runtime_document_path(class_id, runtime_root)
        if not path.is_file():
            problems.append(f"missing runtime document: {_display(path)}")
        elif path.read_text(encoding="utf-8") != text:
            problems.append(f"stale runtime document: {_display(path)}")
    if runtime_root.is_dir():
        for path in sorted(runtime_root.glob("*.json")):
            if path.stem not in rendered:
                problems.append(f"orphan runtime document without a class manifest: {_display(path)}")
    return problems


def write_all(rendered: dict[str, str], runtime_root: Path = RUNTIME_ROOT) -> list[Path]:
    runtime_root.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for class_id, text in rendered.items():
        path = runtime_document_path(class_id, runtime_root)
        if not path.is_file() or path.read_text(encoding="utf-8") != text:
            path.write_text(text, encoding="utf-8")
            written.append(path)
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="fail when a committed runtime document is missing or stale")
    args = parser.parse_args(argv)
    try:
        rendered = build_all()
    except RuntimeDataError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    if args.check:
        problems = stale_documents(rendered)
        for problem in problems:
            print(problem, file=sys.stderr)
        if problems:
            print(f"run: python3 {GENERATOR}", file=sys.stderr)
            return 1
        print(f"{len(rendered)} runtime presentation documents are up to date")
        return 0
    written = write_all(rendered)
    for path in written:
        print(f"wrote {_display(path)}")
    print(f"{len(rendered)} runtime presentation documents, {len(written)} updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
