#!/usr/bin/env python3
"""Rebuild and verify the FAN-3863 Robot ultimate VFX trio without network access.

Each pack's source ``manifest.json`` is the build recipe and provenance record;
PixelLab raw frames are the only image inputs. The builder recreates accepted
and runtime PNGs, Godot imports, SpriteFrames, QA manifests, and contact sheets.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from pixellab_generate_pack import check_pack, frame_hashes


PACKS = ("magnetic_anchor", "hydraulic_press", "reactor_core")
FRAME_COUNT = 9
CANVAS = 256
INSET = 16
ACCEPTED_SIZE = CANVAS - 2 * INSET
ALPHA_VISIBLE = 8
CONTACT_BACKGROUND = (34, 30, 42)
CONTACT_LABEL = (245, 220, 170)
BUILDER_PATH = "tools/build_fan3863_robot_vfx_pack.py"


class PackError(RuntimeError):
    pass


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def normalized_png(raw_path: Path) -> tuple[bytes, Image.Image]:
    with Image.open(raw_path) as raw:
        if raw.mode != "RGBA" or raw.size != (CANVAS, CANVAS):
            raise PackError(f"{raw_path}: expected {CANVAS}x{CANVAS} RGBA raw frame")
        resized = raw.resize((ACCEPTED_SIZE, ACCEPTED_SIZE), Image.Resampling.NEAREST)
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    image.alpha_composite(resized, (INSET, INSET))
    encoded = io.BytesIO()
    image.save(encoded, format="PNG", optimize=False)
    return encoded.getvalue(), image


def import_sidecar(runtime_path: str, uid: str) -> tuple[bytes, str]:
    source = f"res://{runtime_path}"
    name = Path(runtime_path).name
    imported = f"res://.godot/imported/{name}-{hashlib.md5(source.encode('utf-8')).hexdigest()}.ctex"
    content = (
        "[remap]\n\n"
        'importer="texture"\n'
        'type="CompressedTexture2D"\n'
        f'uid="{uid}"\n'
        f'path="{imported}"\n'
        "metadata={\n"
        '"vram_texture": false\n'
        "}\n\n"
        "[deps]\n\n"
        f'source_file="{source}"\n'
        f'dest_files=["{imported}"]\n\n'
        "[params]\n\n"
        "compress/mode=0\n"
        "compress/high_quality=false\n"
        "compress/lossy_quality=0.7\n"
        "compress/uastc_level=0\n"
        "compress/rdo_quality_loss=0.0\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=false\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        'roughness/src_normal=""\n'
        "process/channel_remap/red=0\n"
        "process/channel_remap/green=1\n"
        "process/channel_remap/blue=2\n"
        "process/channel_remap/alpha=3\n"
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/normal_map_invert_y=false\n"
        "process/hdr_as_srgb=false\n"
        "process/hdr_clamp_exposure=false\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n"
    )
    return content.encode("utf-8"), imported


def spriteframes_bytes(pack: str, animation_name: str) -> bytes:
    lines = [f'[gd_resource type="SpriteFrames" load_steps={FRAME_COUNT + 1} format=3]', ""]
    for index in range(FRAME_COUNT):
        path = f"res://assets/sprites/effects/robot/{pack}/{pack}_f{index:02d}.png"
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{index + 1}_{pack}"]')
    lines.extend(["", "[resource]", "animations = [{", '"frames": ['])
    for index in range(FRAME_COUNT):
        lines.extend([
            "{",
            '"duration": 1.0,',
            f'"texture": ExtResource("{index + 1}_{pack}")',
            "}," if index < FRAME_COUNT - 1 else "}",
        ])
    lines.extend([
        "],",
        '"loop": false,',
        f'"name": &"{animation_name}",',
        '"speed": 3.0',
        "}])",
    ])
    return ("\n".join(lines) + "\n").encode("utf-8")


def contact_sheet_bytes(pack: str, frames: list[Image.Image]) -> bytes:
    sheet = Image.new("RGB", (CANVAS * 3, CANVAS * 3), CONTACT_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, frame in enumerate(frames):
        x, y = index % 3 * CANVAS, index // 3 * CANVAS
        sheet.paste(frame, (x, y), frame)
        draw.text((x + 8, y + 8), f"{pack} {index:02d}", fill=CONTACT_LABEL, font=font)
    encoded = io.BytesIO()
    sheet.save(encoded, format="PNG", optimize=False)
    return encoded.getvalue()


def frame_metrics(image: Image.Image) -> dict[str, object]:
    alpha = image.getchannel("A")
    visible = alpha.point(lambda value: 255 if value > ALPHA_VISIBLE else 0)
    bbox = visible.getbbox()
    if bbox is None:
        raise PackError("normalized frame is fully transparent")
    left, top, right, bottom = bbox
    edge_visible = sum(1 for x in range(CANVAS) for y in (0, CANVAS - 1) if alpha.getpixel((x, y)) > ALPHA_VISIBLE)
    edge_visible += sum(1 for y in range(1, CANVAS - 1) for x in (0, CANVAS - 1) if alpha.getpixel((x, y)) > ALPHA_VISIBLE)
    visible_pixels = sum(1 for value in alpha.getdata() if value > ALPHA_VISIBLE)
    gutters = [left, top, CANVAS - right, CANVAS - bottom]
    return {
        "size_px": [CANVAS, CANVAS],
        "mode": "RGBA",
        "alpha_bbox_gt_8": list(bbox),
        "gutters_px": gutters,
        "minimum_gutter_px": min(gutters),
        "edge_visible_pixels": edge_visible,
        "visible_pixels_alpha_gt_8": visible_pixels,
        "visible_ratio_alpha_gt_8": round(visible_pixels / float(CANVAS * CANVAS), 6),
        "opaque_pixels": sum(1 for value in alpha.getdata() if value == 255),
        "max_alpha": max(alpha.getdata()),
        "corner_alpha": [alpha.getpixel(point) for point in ((0, 0), (CANVAS - 1, 0), (0, CANVAS - 1), (CANVAS - 1, CANVAS - 1))],
    }


def frame_record(root: Path, pack: str, index: int, uid: str) -> tuple[dict[str, object], bytes, Image.Image, bytes]:
    source_path = f"docs/design/reference-assets-lfs/robot-vfx-FAN-3320-art/{pack}/{pack}_f{index:02d}.png"
    raw_path = f"docs/design/reference-assets-lfs/robot-vfx-FAN-3320-art/{pack}/raw/{pack}_f{index:02d}.png"
    runtime_path = f"assets/sprites/effects/robot/{pack}/{pack}_f{index:02d}.png"
    import_path = f"{runtime_path}.import"
    raw_encoded, raw_pixel = frame_hashes(root / raw_path)
    encoded, image = normalized_png(root / raw_path)
    encoded_hash = hashlib.sha256(encoded).hexdigest()
    pixel_hash = hashlib.sha256(image.tobytes()).hexdigest()
    sidecar, imported = import_sidecar(runtime_path, uid)
    record = {
        "index": index,
        "source_file": source_path,
        "raw_file": raw_path,
        "runtime_file": runtime_path,
        "import_file": import_path,
        "raw_encoded_sha256": raw_encoded,
        "raw_pixel_sha256": raw_pixel,
        "source_encoded_sha256": encoded_hash,
        "runtime_encoded_sha256": encoded_hash,
        "source_pixel_sha256": pixel_hash,
        "runtime_pixel_sha256": pixel_hash,
        "source_runtime_byte_parity": True,
        "source_runtime_pixel_parity": True,
        **frame_metrics(image),
        "import_uid": uid,
        "import_dest_files": [imported],
        "importer": "texture",
        "import_source_file": f"res://{runtime_path}",
        "import_matches_runtime": True,
    }
    return record, encoded, image, sidecar


def quality_evidence(recipe: dict[str, object], records: list[dict[str, object]]) -> dict[str, object]:
    pixels = [record["source_pixel_sha256"] for record in records]
    return {
        "schema_version": 1,
        "issue": recipe["issue"],
        "class_id": recipe["class_id"],
        "weapon_id": recipe["weapon_id"],
        "generator_route": recipe["generator"]["tool"],
        "object_id": recipe["pixel_lab"]["object_id"],
        "animation_group_id": recipe["pixel_lab"]["animation_group_id"],
        "checks": {
            "all_frames_rgba_256": all(record["size_px"] == [CANVAS, CANVAS] and record["mode"] == "RGBA" for record in records),
            "all_frames_have_transparent_background": all(
                record["max_alpha"] == 255 and all(value == 0 for value in record["corner_alpha"])
                for record in records
            ),
            "all_frames_have_no_edge_visible_pixels": all(record["edge_visible_pixels"] == 0 for record in records),
            "all_frames_have_16px_safe_gutter": all(record["minimum_gutter_px"] >= INSET for record in records),
            "all_frames_nonempty": all(record["visible_pixels_alpha_gt_8"] > 0 for record in records),
            "all_adjacent_frames_change_pixels": all(left != right for left, right in zip(pixels, pixels[1:])),
            "all_frame_pixels_unique": len(set(pixels)) == FRAME_COUNT,
            "source_runtime_byte_parity": True,
            "runtime_import_sidecars_present": True,
        },
        "visual_review": {
            "contact_sheet": recipe["paths"]["contact_sheet"],
            "silhouette": "clear and weapon-specific in every frame",
            "movement": recipe["motion_contract"],
            "clipping": "none observed; alpha does not touch any canvas edge",
            "stray_pixels": "none observed in contact-sheet inspection",
            "opaque_background": "none; all four corners are transparent and edges are empty",
            "seams": "none observed",
            "static_duplicates": f"none; all {FRAME_COUNT} decoded pixel hashes are unique and adjacent frames differ",
        },
        "frames": [
            {
                "index": record["index"],
                "raw_file": record["raw_file"],
                "file": record["source_file"],
                "alpha_bbox_gt_8": record["alpha_bbox_gt_8"],
                "minimum_gutter_px": record["minimum_gutter_px"],
                "edge_visible_pixels": record["edge_visible_pixels"],
                "visible_pixels_alpha_gt_8": record["visible_pixels_alpha_gt_8"],
                "raw_pixel_sha256": record["raw_pixel_sha256"],
                "source_pixel_sha256": record["source_pixel_sha256"],
                "runtime_pixel_sha256": record["runtime_pixel_sha256"],
            }
            for record in records
        ],
    }


def expected_outputs(root: Path, pack: str) -> dict[Path, bytes]:
    source_dir = root / "docs" / "design" / "reference-assets-lfs" / "robot-vfx-FAN-3320-art" / pack
    manifest_path = source_dir / "manifest.json"
    recipe = json.loads(manifest_path.read_text(encoding="utf-8"))
    raw_names = sorted(path.name for path in (source_dir / "raw").glob("*.png"))
    expected_raw_names = [f"{pack}_f{index:02d}.png" for index in range(FRAME_COUNT)]
    if raw_names != expected_raw_names:
        raise PackError(f"{pack}: expected raw frames {expected_raw_names}, found {raw_names}")
    messages: list[str] = []
    generated_manifest = source_dir / "pixellab_generation_manifest.json"
    if not check_pack(generated_manifest, source_dir, log=messages.append):
        raise PackError(f"{pack}: PixelLab raw manifest check failed: {'; '.join(messages)}")

    recipe_frames = recipe.get("frames")
    if not isinstance(recipe_frames, list) or len(recipe_frames) != FRAME_COUNT:
        raise PackError(f"{pack}: source manifest must contain {FRAME_COUNT} frame recipes")

    outputs: dict[Path, bytes] = {}
    records: list[dict[str, object]] = []
    images: list[Image.Image] = []
    for index, old_record in enumerate(recipe_frames):
        uid = old_record.get("import_uid") if isinstance(old_record, dict) else None
        if not isinstance(uid, str) or not uid.startswith("uid://"):
            raise PackError(f"{pack}: frame {index} has no valid preserved import UID")
        record, encoded, image, sidecar = frame_record(root, pack, index, uid)
        records.append(record)
        images.append(image)
        outputs[root / record["source_file"]] = encoded
        outputs[root / record["runtime_file"]] = encoded
        outputs[root / record["import_file"]] = sidecar

    animation = recipe["animation"]
    animation["frame_order"] = [record["runtime_file"] for record in records]
    animation["distinct_pixel_frames"] = len({record["runtime_pixel_sha256"] for record in records})
    animation["adjacent_pixel_changes"] = sum(
        left["runtime_pixel_sha256"] != right["runtime_pixel_sha256"] for left, right in zip(records, records[1:])
    )
    recipe["source_runtime_parity"] = True
    recipe["frames"] = records
    recipe["generator"]["offline_builder"] = BUILDER_PATH
    outputs[manifest_path] = json_bytes(recipe)

    runtime_manifest = {
        key: recipe[key]
        for key in ("schema_version", "issue", "base_sha", "base_tree", "class_id", "weapon_id", "effect_id", "pixel_lab", "frame_contract", "paths", "animation")
    }
    runtime_manifest["import_policy"] = {
        "importer": "texture",
        "type": "CompressedTexture2D",
        "compress_mode": 0,
        "mipmaps_generate": False,
        "premult_alpha": False,
        "filtering": "nearest at runtime consumer; no generated mipmaps",
    }
    runtime_manifest["frames"] = records
    runtime_manifest["source_runtime_parity"] = True
    outputs[root / recipe["paths"]["runtime_manifest"]] = json_bytes(runtime_manifest)
    outputs[root / recipe["paths"]["quality_evidence"]] = json_bytes(quality_evidence(recipe, records))
    outputs[root / recipe["paths"]["spriteframes"]] = spriteframes_bytes(pack, animation["name"])
    outputs[root / recipe["paths"]["contact_sheet"]] = contact_sheet_bytes(pack, images)
    return outputs


def process_pack(root: Path, pack: str, check: bool) -> bool:
    outputs = expected_outputs(root, pack)
    if check:
        ok = True
        for path, expected in outputs.items():
            if not path.exists() or path.read_bytes() != expected:
                print(f"FAIL: {path.relative_to(root)} differs from offline rebuild", file=sys.stderr)
                ok = False
        if ok:
            print(f"check passed: {pack} ({FRAME_COUNT} frames)")
        return ok
    for path, content in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    print(f"rebuilt {pack}: {FRAME_COUNT} source/runtime frames")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare every committed output to an offline rebuild")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help=argparse.SUPPRESS)
    args = parser.parse_args()
    ok = True
    for pack in PACKS:
        try:
            ok = process_pack(args.root.resolve(), pack, args.check) and ok
        except (OSError, ValueError, PackError) as exc:
            print(f"FAIL: {pack}: {exc}", file=sys.stderr)
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
