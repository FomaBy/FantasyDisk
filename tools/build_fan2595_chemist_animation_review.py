#!/usr/bin/env python3
"""Audit and render the FAN-2595 Chemist directional animation evidence.

The audit is read-only. It checks the PixelLab source pack, normalized runtime
frames, SpriteFrames wiring, and the canonical portrait path before writing a
machine-readable report and review sheets.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import re
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CHARACTER = "chemist"
DIRECTIONS = (
    "south",
    "south-east",
    "east",
    "north-east",
    "north",
    "north-west",
    "west",
    "south-west",
)
OPPOSITE_PAIRS = (("east", "west"), ("north-east", "north-west"), ("south-east", "south-west"))
REGENERATED_DIRECTIONS = frozenset(("east", "north-east", "north-west", "west"))
SOURCE_SIZE = (252, 252)
RUNTIME_SIZE = (512, 512)
RUNTIME_VISIBLE_HEIGHT = 245
RUNTIME_FOOTLINE_BOTTOM = 508
MAX_SOURCE_AREA_RATIO = 1.18
CROP = (160, 245, 352, 512)
BACKGROUND = (30, 30, 36, 255)

SOURCE_REL = Path("assets/sprites/characters/pixellab/chemist")
RUNTIME_REL = Path("assets/sprites/characters/full_frame/chemist_pixellab")
SPRITEFRAMES_REL = Path("assets/sprites/characters/chemist_spriteframes.tres")
PROGRESSION_REL = Path("scripts/progression_data_characters.gd")
ALPHA_REPORT_REL = SOURCE_REL / "alpha_bbox_report.json"


def _source_names(direction: str) -> list[str]:
    return [f"chemist_idle_{direction}.png"] + [
        f"chemist_move_{direction}_{index:02d}.png" for index in range(6)
    ]


def _runtime_names(direction: str) -> list[str]:
    return _source_names(direction)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _image_metrics(path: Path) -> dict:
    encoded = path.read_bytes()
    with Image.open(path) as opened:
        original_mode = opened.mode
        image = opened.convert("RGBA")
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()
        histogram = alpha.histogram()
        return {
            "size": list(image.size),
            "mode": original_mode,
            "alpha_extrema": list(alpha.getextrema()),
            "alpha_bbox": list(bbox) if bbox else None,
            "alpha_area": sum(histogram[1:]),
            "encoded_sha256": _sha256(encoded),
            "pixel_sha256": _sha256(image.tobytes()),
        }


def _expected_paths(kind: str, directory: Path) -> dict[str, Path]:
    return {
        name: directory / name
        for direction in DIRECTIONS
        for name in (_source_names(direction) if kind == "source" else _runtime_names(direction))
    }


def _check_images(
    paths: dict[str, Path],
    expected_size: tuple[int, int],
    errors: list[str],
    runtime: bool,
) -> dict[str, dict]:
    metrics: dict[str, dict] = {}
    for name, path in paths.items():
        if not path.is_file():
            errors.append(f"missing {('runtime' if runtime else 'source')} frame: {path}")
            continue
        try:
            current = _image_metrics(path)
        except Exception as exc:  # pragma: no cover - only malformed external assets reach this branch.
            errors.append(f"cannot read frame {path}: {exc}")
            continue
        metrics[name] = current
        if current["size"] != list(expected_size):
            errors.append(f"{name}: expected {expected_size}, got {tuple(current['size'])}")
        if current["mode"] != "RGBA":
            errors.append(f"{name}: expected RGBA, got {current['mode']}")
        if current["alpha_extrema"] != [0, 255]:
            errors.append(f"{name}: expected transparent/opaque alpha extrema, got {current['alpha_extrema']}")
        bbox = current["alpha_bbox"]
        if bbox is None:
            errors.append(f"{name}: empty alpha")
            continue
        if bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= expected_size[0] or bbox[3] >= expected_size[1]:
            errors.append(f"{name}: alpha touches the canvas edge: {bbox}")
        if runtime:
            if bbox[3] != RUNTIME_FOOTLINE_BOTTOM:
                errors.append(f"{name}: expected footline bottom {RUNTIME_FOOTLINE_BOTTOM}, got {bbox[3]}")
            if bbox[3] - bbox[1] != RUNTIME_VISIBLE_HEIGHT:
                errors.append(f"{name}: expected visible height {RUNTIME_VISIBLE_HEIGHT}, got {bbox[3] - bbox[1]}")
            center = (bbox[0] + bbox[2] - 1) / 2.0
            if not 250.0 <= center <= 262.0:
                errors.append(f"{name}: runtime center drifted to x={center:.1f}")
    return metrics


def _mirror_equal(left: Path, right: Path) -> bool:
    with Image.open(left) as left_opened, Image.open(right) as right_opened:
        left_pixels = left_opened.convert("RGBA").tobytes()
        right_pixels = right_opened.convert("RGBA").transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()
    return left_pixels == right_pixels


def _directional_mirrors(
    source_dir: Path,
    runtime_dir: Path,
    errors: list[str],
) -> list[dict]:
    mirrors: list[dict] = []
    for layer, directory in (("source", source_dir), ("runtime", runtime_dir)):
        for left_direction, right_direction in OPPOSITE_PAIRS:
            for index in range(6):
                left_name = f"chemist_move_{left_direction}_{index:02d}.png"
                right_name = f"chemist_move_{right_direction}_{index:02d}.png"
                left_path, right_path = directory / left_name, directory / right_name
                if not left_path.is_file() or not right_path.is_file():
                    continue
                if _mirror_equal(left_path, right_path):
                    mirrors.append(
                        {
                            "layer": layer,
                            "source": left_name,
                            "mirror": right_name,
                            "directions": [left_direction, right_direction],
                            "frame": index,
                        }
                    )
    if mirrors:
        errors.append(f"found {len(mirrors)} byte-identical directional mirror pair(s)")
    return mirrors


def _idle_duplicates(source_dir: Path) -> list[dict]:
    duplicates: list[dict] = []
    for left_direction, right_direction in itertools.combinations(DIRECTIONS, 2):
        left_name = f"chemist_idle_{left_direction}.png"
        right_name = f"chemist_idle_{right_direction}.png"
        left_path, right_path = source_dir / left_name, source_dir / right_name
        if not left_path.is_file() or not right_path.is_file():
            continue
        with Image.open(left_path) as left_opened, Image.open(right_path) as right_opened:
            left_image = left_opened.convert("RGBA")
            right_image = right_opened.convert("RGBA")
            exact = left_image.tobytes() == right_image.tobytes()
            mirrored = left_image.tobytes() == right_image.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()
        if exact or mirrored:
            duplicates.append({"left": left_name, "right": right_name, "kind": "mirror" if mirrored else "exact"})
    return duplicates


def _parse_spriteframes(path: Path) -> dict[str, dict]:
    text = path.read_text(encoding="utf-8")
    resources = {
        resource_id: resource_path
        for resource_path, resource_id in re.findall(
            r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text
        )
    }
    pattern = re.compile(
        r'"frames": \[(?P<frames>.*?)\],\s*"loop": (?P<loop>true|false),\s*"name": &"(?P<name>[^"]+)"',
        re.DOTALL,
    )
    animations: dict[str, dict] = {}
    for match in pattern.finditer(text):
        resource_ids = re.findall(r'ExtResource\("([^"]+)"\)', match.group("frames"))
        animations[match.group("name")] = {
            "frames": [resources.get(resource_id, f"<missing:{resource_id}>") for resource_id in resource_ids],
            "loop": match.group("loop") == "true",
        }
    return animations


def _spriteframes_audit(root: Path, errors: list[str]) -> dict:
    path = root / SPRITEFRAMES_REL
    if not path.is_file():
        errors.append(f"missing SpriteFrames: {path}")
        return {"animation_count": 0, "animation_names": [], "body_attack_animations": []}
    try:
        animations = _parse_spriteframes(path)
    except Exception as exc:  # pragma: no cover - only malformed external resources reach this branch.
        errors.append(f"cannot parse SpriteFrames: {exc}")
        return {"animation_count": 0, "animation_names": [], "body_attack_animations": []}

    expected_names = ["idle", "move", "walk"] + [
        f"{kind}_{direction.replace('-', '_')}"
        for kind in ("idle", "move", "walk")
        for direction in DIRECTIONS
    ]
    actual_names = list(animations)
    missing_names = sorted(set(expected_names) - set(actual_names))
    unexpected_names = sorted(set(actual_names) - set(expected_names))
    if missing_names:
        errors.append(f"SpriteFrames missing animations: {missing_names}")
    if unexpected_names:
        errors.append(f"SpriteFrames has unexpected animations: {unexpected_names}")

    for name in expected_names:
        if name not in animations:
            continue
        expected_count = 1 if name == "idle" or name.startswith("idle_") else 6
        if len(animations[name]["frames"]) != expected_count:
            errors.append(f"{name}: expected {expected_count} frame(s), got {len(animations[name]['frames'])}")

    for direction in DIRECTIONS:
        suffix = direction.replace("-", "_")
        move = animations.get(f"move_{suffix}", {}).get("frames", [])
        walk = animations.get(f"walk_{suffix}", {}).get("frames", [])
        if move != walk:
            errors.append(f"walk_{suffix} is not the same runtime row as move_{suffix}")
        expected_move = [
            f"res://assets/sprites/characters/full_frame/chemist_pixellab/chemist_move_{direction}_{index:02d}.png"
            for index in range(6)
        ]
        if move != expected_move:
            errors.append(f"move_{suffix} does not point to its direction's runtime frames")

    body_attack_animations = sorted(name for name in actual_names if "attack" in name)
    if body_attack_animations:
        errors.append(f"body SpriteFrames unexpectedly contain attack rows: {body_attack_animations}")
    return {
        "animation_count": len(animations),
        "animation_names": actual_names,
        "body_attack_animations": body_attack_animations,
        "frame_counts": {name: len(animation["frames"]) for name, animation in animations.items()},
        "walk_aliases_move": all(
            animations.get(f"move_{direction.replace('-', '_')}", {}).get("frames", [])
            == animations.get(f"walk_{direction.replace('-', '_')}", {}).get("frames", [])
            for direction in DIRECTIONS
        ),
    }


def _manifest_audit(root: Path, source_metrics: dict[str, dict], errors: list[str]) -> dict:
    path = root / SOURCE_REL / "manifest.json"
    if not path.is_file():
        errors.append(f"missing manifest: {path}")
        return {}
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - only malformed external manifests reach this branch.
        errors.append(f"cannot parse manifest: {exc}")
        return {}

    if manifest.get("source") != "PixelLab MCP":
        errors.append("manifest source is not PixelLab MCP")
    if manifest.get("pixellab_character_id") != "c7fe44d3-1f15-45a1-b762-b2862833b151":
        errors.append("manifest points at an unexpected PixelLab character")
    regeneration = manifest.get("fan3324_regeneration", {})
    if regeneration.get("source") != "PixelLab MCP animate_character":
        errors.append("manifest is missing FAN-3324 PixelLab regeneration provenance")
    if set(regeneration.get("directions", [])) != REGENERATED_DIRECTIONS:
        errors.append("manifest regeneration directions do not match the four replacement rows")
    if regeneration.get("frame_count_per_direction") != 6:
        errors.append("manifest regeneration does not contain six frames per direction")

    inventory = regeneration.get("frame_inventory", {})
    inventory_mismatches = []
    for name, expected in sorted(inventory.items()):
        actual = source_metrics.get(name)
        if actual is None:
            continue
        if actual["encoded_sha256"] != expected.get("encoded_sha256") or actual["pixel_sha256"] != expected.get("pixel_sha256"):
            inventory_mismatches.append(name)
    if inventory_mismatches:
        errors.append(f"manifest frame inventory mismatch: {inventory_mismatches}")

    def flatten(value: object) -> list[str]:
        if isinstance(value, dict):
            result: list[str] = []
            for child in value.values():
                result.extend(flatten(child))
            return result
        if isinstance(value, list):
            result = []
            for child in value:
                result.extend(flatten(child))
            return result
        return [value] if isinstance(value, str) else []

    source_files = manifest.get("source_files", {})
    flattened = flatten(source_files)
    manifest_names = {Path(value).name for value in flattened}
    expected_names = {name for direction in DIRECTIONS for name in _source_names(direction)}
    if manifest_names != expected_names:
        errors.append("manifest source_files does not cover exactly the 56 source frames")
    return {
        "pixellab_character_id": manifest.get("pixellab_character_id"),
        "source": manifest.get("source"),
        "regenerated_directions": sorted(REGENERATED_DIRECTIONS),
        "untouched_directions": [direction for direction in DIRECTIONS if direction not in REGENERATED_DIRECTIONS],
        "frame_count_per_direction": regeneration.get("frame_count_per_direction"),
        "inventory_frame_count": len(inventory),
    }


def _alpha_report_audit(root: Path, runtime_metrics: dict[str, dict], errors: list[str]) -> dict:
    path = root / ALPHA_REPORT_REL
    if not path.is_file():
        errors.append(f"missing alpha report: {path}")
        return {}
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - only malformed external reports reach this branch.
        errors.append(f"cannot parse alpha report: {exc}")
        return {}
    if report.get("runtime_canvas") != list(RUNTIME_SIZE):
        errors.append(f"alpha report runtime canvas is {report.get('runtime_canvas')}")
    if report.get("target_visible_height") != RUNTIME_VISIBLE_HEIGHT or report.get("bottom_padding") != 4:
        errors.append("alpha report normalization contract changed")
    entries = {entry.get("runtime"): entry for entry in report.get("frames", [])}
    if len(entries) != 56:
        errors.append(f"alpha report covers {len(entries)} runtime frames, expected 56")
    mismatches = []
    for name, metrics in runtime_metrics.items():
        expected = entries.get(name, {})
        if expected.get("runtime_alpha_bbox") != metrics.get("alpha_bbox"):
            mismatches.append(name)
    if mismatches:
        errors.append(f"alpha report bbox mismatch: {mismatches}")
    return {
        "frame_count": len(entries),
        "runtime_canvas": report.get("runtime_canvas"),
        "target_visible_height": report.get("target_visible_height"),
        "bottom_padding": report.get("bottom_padding"),
    }


def audit_pack(root: Path) -> dict:
    errors: list[str] = []
    source_paths = _expected_paths("source", root / SOURCE_REL)
    runtime_paths = _expected_paths("runtime", root / RUNTIME_REL)
    source_metrics = _check_images(source_paths, SOURCE_SIZE, errors, runtime=False)
    runtime_metrics = _check_images(runtime_paths, RUNTIME_SIZE, errors, runtime=True)

    source_ratios = {}
    for direction in DIRECTIONS:
        areas = [source_metrics[name]["alpha_area"] for name in _source_names(direction) if name.startswith("chemist_move_") and name in source_metrics]
        if len(areas) != 6:
            continue
        ratio = max(areas) / min(areas)
        source_ratios[direction] = round(ratio, 6)
        if ratio > MAX_SOURCE_AREA_RATIO:
            errors.append(f"{direction}: source alpha-area ratio {ratio:.6f} exceeds {MAX_SOURCE_AREA_RATIO:.2f}")

    mirror_pairs = _directional_mirrors(root / SOURCE_REL, root / RUNTIME_REL, errors)
    idle_duplicates = _idle_duplicates(root / SOURCE_REL)
    if idle_duplicates:
        errors.append(f"found {len(idle_duplicates)} duplicate idle identity pair(s)")
    spriteframes = _spriteframes_audit(root, errors)
    manifest = _manifest_audit(root, source_metrics, errors)
    alpha_report = _alpha_report_audit(root, runtime_metrics, errors)

    progression_path = root / PROGRESSION_REL
    progression_text = progression_path.read_text(encoding="utf-8") if progression_path.is_file() else ""
    progression_match = re.search(
        r'"chemist":\s*\{\s*"id":\s*"chemist".*?"sprite_path":\s*"([^"]+)"',
        progression_text,
        flags=re.DOTALL,
    )
    portrait_path = progression_match.group(1) if progression_match else None
    expected_portrait = "res://assets/sprites/characters/full_frame/chemist_pixellab/chemist_idle_south.png"
    if portrait_path != expected_portrait:
        errors.append(f"Chemist portrait path is {portrait_path!r}, expected {expected_portrait!r}")

    frame_records = []
    for direction in DIRECTIONS:
        for name in _source_names(direction):
            frame_records.append(
                {
                    "direction": direction,
                    "kind": "idle" if "_idle_" in name else "move",
                    "name": name,
                    "source": source_metrics.get(name),
                    "runtime": runtime_metrics.get(name),
                }
            )

    return {
        "tool": "tools/build_fan2595_chemist_animation_review.py",
        "character_id": CHARACTER,
        "verdict": "PASS" if not errors else "FAIL",
        "errors": errors,
        "direction_count": len(DIRECTIONS),
        "directions": list(DIRECTIONS),
        "source_frame_count": len(source_paths),
        "runtime_frame_count": len(runtime_paths),
        "source_contract": {
            "size": list(SOURCE_SIZE),
            "mode": "RGBA",
            "alpha_area_ratio_by_direction": source_ratios,
            "max_alpha_area_ratio": max(source_ratios.values(), default=None),
        },
        "runtime_contract": {
            "size": list(RUNTIME_SIZE),
            "visible_height": RUNTIME_VISIBLE_HEIGHT,
            "footline_bottom": RUNTIME_FOOTLINE_BOTTOM,
            "alpha_bbox_bottoms": sorted(
                {metrics["alpha_bbox"][3] for metrics in runtime_metrics.values() if metrics["alpha_bbox"]}
            ),
            "alpha_bbox_heights": sorted(
                {
                    metrics["alpha_bbox"][3] - metrics["alpha_bbox"][1]
                    for metrics in runtime_metrics.values()
                    if metrics["alpha_bbox"]
                }
            ),
            "x_center_range": [
                min((metrics["alpha_bbox"][0] + metrics["alpha_bbox"][2] - 1) / 2.0 for metrics in runtime_metrics.values()),
                max((metrics["alpha_bbox"][0] + metrics["alpha_bbox"][2] - 1) / 2.0 for metrics in runtime_metrics.values()),
            ] if runtime_metrics and all(metrics["alpha_bbox"] for metrics in runtime_metrics.values()) else [],
        },
        "mirror_pair_count": len(mirror_pairs),
        "mirror_pairs": mirror_pairs,
        "idle_duplicate_count": len(idle_duplicates),
        "idle_duplicates": idle_duplicates,
        "manifest": manifest,
        "alpha_report": alpha_report,
        "spriteframes": spriteframes,
        "portrait_path": portrait_path,
        "frames": frame_records,
    }


def _cell(path: Path) -> Image.Image:
    with Image.open(path) as opened:
        return opened.convert("RGBA").crop(CROP)


def _row(paths: list[Path], scale: int = 1) -> Image.Image:
    width = CROP[2] - CROP[0]
    height = CROP[3] - CROP[1]
    result = Image.new("RGBA", (width * len(paths), height), BACKGROUND)
    for index, path in enumerate(paths):
        result.alpha_composite(_cell(path), (index * width, 0))
    if scale != 1:
        result = result.resize((result.width * scale, result.height * scale), Image.Resampling.NEAREST)
    return result


def build_previews(root: Path, output_dir: Path) -> list[Path]:
    runtime_dir = root / RUNTIME_REL
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = [
        [runtime_dir / name for name in _runtime_names(direction)]
        for direction in DIRECTIONS
    ]
    width = CROP[2] - CROP[0]
    height = CROP[3] - CROP[1]
    contact = Image.new("RGBA", (width * 7, height * len(rows)), BACKGROUND)
    for row_index, paths in enumerate(rows):
        contact.alpha_composite(_row(paths), (0, row_index * height))
    outputs = [output_dir / "fan2595_chemist_8dir_contact.png"]
    contact.save(outputs[0])
    for direction, paths in zip(DIRECTIONS, rows):
        output = output_dir / f"fan2595_chemist_row_{direction.replace('-', '_')}.png"
        _row(paths, scale=2).save(output)
        outputs.append(output)
    return outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="FantasyDisk repository root")
    parser.add_argument("--output-dir", type=Path, default=None, help="directory for review sheets")
    parser.add_argument("--report", type=Path, default=None, help="JSON audit report path")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    output_dir = (args.output_dir or root / "docs/design/previews").resolve()
    report_path = (args.report or output_dir / "fan2595_chemist_animation_audit.json").resolve()
    report = audit_pack(root)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"audit: {report['verdict']} ({report['direction_count']} directions, {report['source_frame_count']} source frames, {report['runtime_frame_count']} runtime frames)")
    print(f"report: {report_path}")
    if report["verdict"] == "PASS":
        for output in build_previews(root, output_dir):
            print(f"preview: {output}")
        return 0
    for error in report["errors"]:
        print(f"error: {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
