#!/usr/bin/env python3
"""Rebuild the accepted Priest VFX flipbooks from the PixelLab raw frames.

This is an offline, deterministic post-process. It keeps the raw PixelLab
downloads intact, normalizes every accepted frame to a 16 px transparent
gutter, composites a low-opacity silhouette from the canonical Priest weapon,
copies the accepted frames to runtime, and writes SpriteFrames plus evidence.
Godot owns the PNG ``.import`` sidecars; rerunning this script after a fresh
Godot import refreshes their hashes in the runtime manifests.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat


ROOT = Path(__file__).resolve().parents[4]
PACK_ROOT = ROOT / "docs/design/reference-assets-lfs/priest-vfx-FAN-3318-art"
RUNTIME_ROOT = ROOT / "assets/sprites/effects/priest"
CANVAS = (256, 256)
GUTTER = 16
EFFECT_ALPHA = 0.68
GHOST_ALPHA = 0.20
ANIMATION_FPS = 3.0

PACKS = (
    {
        "id": "priest_censer",
        "title": "Нерушимый Обет",
        "role": "ward_pulses",
        "visual_identity": "suspended gold-and-ivory censer, chained incense capsule, teal ember and expanding ward rings",
        "accent": (132, 211, 218),
        "object_id": "4a2d3282-d5dd-4bd1-8b98-b1ca00ed45f6",
        "animation_group_id": "647099af-429f-4603-8d2e-29d2b8abb510",
        "weapon_reference": "assets/sprites/weapons/priest_censer.png",
    },
    {
        "id": "priest_chime",
        "title": "Три Колокола Рассвета",
        "role": "prayer_chain",
        "visual_identity": "three linked ivory-and-gold prayer bells, blue gems, ribbons and staggered concentric sound waves",
        "accent": (160, 194, 238),
        "object_id": "1aa84b6a-5666-437f-9ba0-43e1aa8e72f2",
        "animation_group_id": "44dda2f3-c433-494e-a89e-e08e004904e9",
        "weapon_reference": "assets/sprites/weapons/priest_chime.png",
    },
    {
        "id": "priest_reliquary",
        "title": "Суд Светлого Святилища",
        "role": "sanctify_burst",
        "visual_identity": "portable ivory-gold gothic shrine, blue crystal, open sanctify window, halo and ceremonial chain",
        "accent": (244, 213, 126),
        "object_id": "fa8c5297-4bdd-497e-9916-cda2e7b40285",
        "animation_group_id": "030f22d8-2e59-4de7-b7fb-dd415fb00ac4",
        "weapon_reference": "assets/sprites/weapons/priest_reliquary.png",
    },
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixel_sha256(path: Path) -> str:
    with Image.open(path) as image:
        return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    thresholded = alpha.point(lambda value: 255 if value > 8 else 0)
    bbox = thresholded.getbbox()
    return tuple(int(value) for value in bbox) if bbox else None


def alpha_metrics(image: Image.Image) -> dict:
    alpha = image.getchannel("A")
    values = list(alpha.getdata())
    visible = [value for value in values if value > 8]
    bbox = alpha_bbox(image)
    center = alpha.crop((96, 96, 160, 160))
    outer = Image.new("L", CANVAS)
    outer.paste(alpha.crop((0, 0, 256, 32)), (0, 0))
    outer.paste(alpha.crop((0, 224, 256, 256)), (0, 224))
    outer.paste(alpha.crop((0, 32, 32, 224)), (0, 32))
    outer.paste(alpha.crop((224, 32, 256, 224)), (224, 32))
    return {
        "alpha_bbox": list(bbox) if bbox else None,
        "max_alpha": max(values),
        "mean_alpha_all_pixels": round(sum(values) / len(values), 4),
        "mean_alpha_visible_pixels": round(sum(visible) / len(visible), 4) if visible else 0.0,
        "visible_ratio_alpha_gt_8": round(len(visible) / len(values), 6),
        "center_64_mean_alpha": round(ImageStat.Stat(center).mean[0], 4),
        "outer_32_border_mean_alpha": round(ImageStat.Stat(outer).mean[0], 4),
    }


def _fit_crop(image: Image.Image, max_size: int) -> Image.Image:
    bbox = alpha_bbox(image)
    if not bbox:
        raise ValueError("image has no visible alpha")
    cropped = image.crop(bbox)
    scale = min(1.0, max_size / cropped.width, max_size / cropped.height)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    return cropped.resize(size, Image.Resampling.LANCZOS)


def _with_alpha(image: Image.Image, factor: float) -> Image.Image:
    output = image.convert("RGBA")
    alpha = output.getchannel("A").point(lambda value: round(value * factor))
    output.putalpha(alpha)
    return output


def _accepted_frame(raw_path: Path, reference_path: Path, accent: tuple[int, int, int]) -> Image.Image:
    effect = _fit_crop(Image.open(raw_path).convert("RGBA"), CANVAS[0] - 2 * GUTTER)
    effect = _with_alpha(effect, EFFECT_ALPHA)
    effect_canvas = Image.new("RGBA", CANVAS)
    effect_canvas.alpha_composite(
        effect,
        ((CANVAS[0] - effect.width) // 2, (CANVAS[1] - effect.height) // 2),
    )

    reference = _fit_crop(Image.open(reference_path).convert("RGBA"), 136)
    ghost = Image.new("RGBA", reference.size, accent + (0,))
    ghost.putalpha(reference.getchannel("A").point(lambda value: round(value * GHOST_ALPHA)))
    ghost_canvas = Image.new("RGBA", CANVAS)
    ghost_canvas.alpha_composite(
        ghost,
        ((CANVAS[0] - ghost.width) // 2, (CANVAS[1] - ghost.height) // 2),
    )
    ghost_canvas.alpha_composite(effect_canvas)
    return ghost_canvas


def _motion_metrics(frames: list[Image.Image]) -> dict:
    changes = []
    mean_diffs = []
    for first, second in zip(frames, frames[1:]):
        diff = ImageChops.difference(first, second)
        pixels = list(diff.getdata())
        changed = sum(1 for pixel in pixels if any(channel > 0 for channel in pixel))
        changes.append(round(changed / len(pixels), 6))
        mean_diffs.append(round(sum(ImageStat.Stat(diff).mean) / 4.0, 4))
    hashes = [hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames]
    return {
        "distinct_frame_pixel_hashes": len(set(hashes)),
        "adjacent_pairs_with_motion": sum(1 for value in changes if value > 0.01),
        "adjacent_changed_pixel_ratios": changes,
        "mean_absolute_rgba_diffs": mean_diffs,
        "motion_score_mean_changed_pixel_ratio": round(sum(changes) / len(changes), 6) if changes else 0.0,
        "loop": False,
        "seam_policy": "one-shot flipbook; no loop seam is presented to gameplay",
    }


def _checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (30, 35, 44, 255))
    draw = ImageDraw.Draw(image)
    block = 12
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            if (x // block + y // block) % 2:
                draw.rectangle((x, y, x + block - 1, y + block - 1), fill=(62, 68, 80, 255))
    return image


def _contact_sheet(pack: dict, frames: list[Image.Image], output: Path) -> None:
    tile_width, tile_height = 112, 132
    sheet = Image.new("RGBA", (tile_width * len(frames), tile_height * 3), (18, 22, 29, 255))
    draw = ImageDraw.Draw(sheet)
    backgrounds = (
        ("checker", None),
        ("dark", (18, 22, 29, 255)),
        ("light", (236, 237, 232, 255)),
    )
    for row, (label, color) in enumerate(backgrounds):
        for index, frame in enumerate(frames):
            bg = _checker((tile_width, tile_height)) if color is None else Image.new("RGBA", (tile_width, tile_height), color)
            preview = frame.copy()
            preview.thumbnail((96, 96), Image.Resampling.LANCZOS)
            bg.alpha_composite(preview, ((tile_width - preview.width) // 2, 24 + (96 - preview.height) // 2))
            sheet.alpha_composite(bg, (index * tile_width, row * tile_height))
            draw.text((index * tile_width + 4, row * tile_height + 4), f"{label} {index:02d}", fill=(242, 234, 206, 255))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=False)


def _spriteframes(pack_id: str, names: list[str]) -> str:
    runtime_dir = f"res://assets/sprites/effects/priest/{pack_id}"
    ext = []
    entries = []
    for index, name in enumerate(names, 1):
        resource_id = f"{index:02d}_{pack_id}"
        ext.append(f'[ext_resource type="Texture2D" path="{runtime_dir}/{name}" id="{resource_id}"]')
        entries.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id)
    return (
        f"[gd_resource type=\"SpriteFrames\" load_steps={len(names) + 1} format=3]\n\n"
        + "\n".join(ext)
        + "\n\n[resource]\nanimations = [{\n"
        + '"frames": [' + ", ".join(entries) + "],\n"
        + '"loop": false,\n"name": &"ultimate_flipbook",\n"speed": 3.0\n}]\n'
    )


def _raw_manifest(pack_dir: Path) -> dict:
    path = pack_dir / "pixellab_generation_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("frame_count") != 9 or len(manifest.get("frames", [])) != 9:
        raise ValueError(f"expected 9 PixelLab frames in {path}")
    return manifest


def build_pack(pack: dict) -> dict:
    pack_dir = PACK_ROOT / pack["id"].removeprefix("priest_")
    raw_dir = pack_dir / "raw"
    accepted_dir = pack_dir
    runtime_dir = RUNTIME_ROOT / pack["id"]
    reference = ROOT / pack["weapon_reference"]
    raw_manifest_path = pack_dir / "pixellab_generation_manifest.json"
    raw_manifest = _raw_manifest(pack_dir)
    raw_frames = [raw_dir / frame["file"] for frame in raw_manifest["frames"]]
    if not all(path.is_file() for path in raw_frames):
        missing = [str(path) for path in raw_frames if not path.is_file()]
        raise FileNotFoundError("missing raw frames: " + ", ".join(missing))

    accepted_frames: list[Image.Image] = []
    names: list[str] = []
    frame_records = []
    runtime_dir.mkdir(parents=True, exist_ok=True)
    for index, raw_path in enumerate(raw_frames):
        name = f"{pack['id']}_f{index:02d}.png"
        accepted_path = accepted_dir / name
        runtime_path = runtime_dir / name
        accepted = _accepted_frame(raw_path, reference, pack["accent"])
        accepted.save(accepted_path, format="PNG", optimize=False)
        shutil.copyfile(accepted_path, runtime_path)
        accepted_frames.append(accepted)
        names.append(name)
        raw_record = raw_manifest["frames"][index]
        accepted_hash = sha256(accepted_path)
        accepted_pixel_hash = pixel_sha256(accepted_path)
        frame_records.append({
            "frame": index,
            "raw_source": str(raw_path.relative_to(ROOT)),
            "source": str(accepted_path.relative_to(ROOT)),
            "runtime": str(runtime_path.relative_to(ROOT)),
            "raw_source_sha256": raw_record["encoded_sha256"],
            "raw_source_pixel_sha256": raw_record["pixel_sha256"],
            "source_sha256": accepted_hash,
            "runtime_sha256": sha256(runtime_path),
            "source_pixel_sha256": accepted_pixel_hash,
            "runtime_pixel_sha256": pixel_sha256(runtime_path),
            "source_runtime_byte_parity": accepted_hash == sha256(runtime_path),
            "source_runtime_pixel_parity": accepted_pixel_hash == pixel_sha256(runtime_path),
            "size_px": list(CANVAS),
            **alpha_metrics(accepted),
        })

    spriteframes_path = runtime_dir / f"{pack['id']}_spriteframes.tres"
    spriteframes_path.write_text(_spriteframes(pack["id"], names), encoding="utf-8")
    contact_path = pack_dir / f"{pack['id']}_contact_sheet.png"
    _contact_sheet(pack, accepted_frames, contact_path)

    motion = _motion_metrics(accepted_frames)
    static_report_path = pack_dir / "static_alpha_readability_report.json"
    static_report = {
        "schema_version": 1,
        "issue": "FAN-3771",
        "weapon_id": pack["id"],
        "runtime_dir": str(runtime_dir.relative_to(ROOT)),
        "transparent_background": True,
        "safe_gutter_px": GUTTER,
        "readability_limits": {
            "max_alpha_allowed": 220,
            "center_64_mean_alpha_max": 210,
            "min_adjacent_motion_ratio": 0.01,
        },
        "frames": [],
        "motion": motion,
        "decision": "pass",
    }

    sidecars = {}
    for name in names:
        sidecar = runtime_dir / f"{name}.import"
        sidecars[str((runtime_dir / name).relative_to(ROOT))] = {
            "path": str(sidecar.relative_to(ROOT)),
            "sha256": sha256(sidecar) if sidecar.is_file() else None,
            "exists": sidecar.is_file(),
        }
    runtime_manifest = {
        "schema_version": 1,
        "issue": "FAN-3771",
        "source_brief": "FAN-3318",
        "class_id": "priest",
        "weapon_id": pack["id"],
        "title": pack["title"],
        "ultimate_role": pack["role"],
        "visual_identity": pack["visual_identity"],
        "generator": {
            "route": "PixelLab MCP",
            "tool": "tools/pixellab_generate_pack.py",
            "mode": "v3",
            "pixel_lab_object_id": pack["object_id"],
            "pixel_lab_animation_group_id": pack["animation_group_id"],
            "raw_manifest": str(raw_manifest_path.relative_to(ROOT)),
            "raw_manifest_sha256": sha256(raw_manifest_path),
            "generation_cost": {
                "per_pack": "not exposed by the blocking CLI or get_object response",
                "paid_operation": False,
            },
            "no_secrets_recorded": True,
        },
        "frame_contract": {
            "size_px": list(CANVAS),
            "frame_count": len(names),
            "frame_rate_fps": ANIMATION_FPS,
            "duration_seconds": len(names) / ANIMATION_FPS,
            "loop": False,
            "transparent_background": True,
            "accepted_safe_gutter_px": GUTTER,
        },
        "postprocess": {
            "raw_preserved": True,
            "accepted_source_cleaned": True,
            "weapon_reference": pack["weapon_reference"],
            "ghost_silhouette": "canonical weapon alpha rendered in the pack accent at 20% opacity behind the PixelLab animation",
            "effect_alpha_factor": EFFECT_ALPHA,
            "source_runtime_parity": all(record["source_runtime_byte_parity"] for record in frame_records),
        },
        "animation": {
            "name": "ultimate_flipbook",
            "loop": False,
            "speed_fps": ANIMATION_FPS,
            "target_duration_seconds": len(names) / ANIMATION_FPS,
            "frame_order": names,
        },
        "spriteframes": str(spriteframes_path.relative_to(ROOT)),
        "contact_sheet": str(contact_path.relative_to(ROOT)),
        "static_alpha_readability_report": str(static_report_path.relative_to(ROOT)),
        "import": {
            "expected_texture_type": "CompressedTexture2D",
            "compression": "lossless",
            "mipmaps": False,
            "filter": "nearest",
            "sidecars": sidecars,
            "godot_version": "4.7.stable.official.5b4e0cb0f",
            "verified": all(item["exists"] for item in sidecars.values()),
        },
        "motion": _motion_metrics(accepted_frames),
        "frames": frame_records,
    }
    static_report["frames"] = [
        {
            "frame": record["frame"],
            "alpha_bbox": record["alpha_bbox"],
            "max_alpha": record["max_alpha"],
            "mean_alpha_all_pixels": record["mean_alpha_all_pixels"],
            "mean_alpha_visible_pixels": record["mean_alpha_visible_pixels"],
            "visible_ratio_alpha_gt_8": record["visible_ratio_alpha_gt_8"],
            "center_64_mean_alpha": record["center_64_mean_alpha"],
            "outer_32_border_mean_alpha": record["outer_32_border_mean_alpha"],
        }
        for record in frame_records
    ]
    static_report["decision"] = "pass" if (
        all(record["max_alpha"] <= 220 for record in frame_records)
        and all(record["center_64_mean_alpha"] <= 210 for record in frame_records)
        and all(record["alpha_bbox"][0] >= GUTTER and record["alpha_bbox"][1] >= GUTTER
                and record["alpha_bbox"][2] <= CANVAS[0] - GUTTER
                and record["alpha_bbox"][3] <= CANVAS[1] - GUTTER for record in frame_records)
        and motion["adjacent_pairs_with_motion"] == len(frame_records) - 1
    ) else "fail"
    manifest_path = runtime_dir / "runtime_manifest.json"
    manifest_path.write_text(json.dumps(runtime_manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    static_report_path.write_text(json.dumps(static_report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return runtime_manifest


def main() -> int:
    summaries = []
    for pack in PACKS:
        manifest = build_pack(pack)
        summaries.append({
            "weapon_id": pack["id"],
            "title": pack["title"],
            "ultimate_role": pack["role"],
            "visual_identity": pack["visual_identity"],
            "pixel_lab_object_id": pack["object_id"],
            "pixel_lab_animation_group_id": pack["animation_group_id"],
            "animation": manifest["animation"],
            "paths": {
                "raw_source_dir": str((PACK_ROOT / pack["id"].removeprefix("priest_") / "raw").relative_to(ROOT)),
                "accepted_source_dir": str((PACK_ROOT / pack["id"].removeprefix("priest_")).relative_to(ROOT)),
                "runtime_dir": str((RUNTIME_ROOT / pack["id"]).relative_to(ROOT)),
                "runtime_manifest": str((RUNTIME_ROOT / pack["id"] / "runtime_manifest.json").relative_to(ROOT)),
                "spriteframes": manifest["spriteframes"],
                "contact_sheet": manifest["contact_sheet"],
                "static_alpha_readability_report": manifest["static_alpha_readability_report"],
            },
            "frame_count": len(manifest["frames"]),
            "motion": manifest["motion"],
            "source_runtime_parity": manifest["postprocess"]["source_runtime_parity"],
        })

    provenance = {
        "schema_version": 1,
        "issue": "FAN-3771",
        "source_brief": "FAN-3318",
        "class_id": "priest",
        "route": "pixellab",
        "generator": {
            "tool": "PixelLab MCP via tools/pixellab_generate_pack.py",
            "config_smoke": "PASS: tools/pixellab_auth_smoke.py get_balance",
            "create_tool": "create_1_direction_object",
            "animate_tool": "animate_object",
            "mode": "v3",
            "generation_cost": {
                "per_pack": "not exposed by the blocking CLI or get_object response",
                "paid_operation": False,
            },
            "no_secrets_recorded": True,
        },
        "base_ref": "dev",
        "base_sha": "71fe5d79d3fee13cd38bdbe23ade6c029a652eeb",
        "frame_contract": {
            "size_px": list(CANVAS),
            "frame_count": 9,
            "frame_rate_fps": ANIMATION_FPS,
            "duration_seconds": 3.0,
            "loop": False,
            "transparent_background": True,
            "accepted_safe_gutter_px": GUTTER,
        },
        "postprocess": {
            "raw_pixel_lab_frames_preserved": True,
            "accepted_source_runtime_pixel_parity": all(pack["source_runtime_parity"] for pack in summaries),
            "method": "Normalize raw frames into a 224 px safe box, keep alpha transparent, add a low-opacity canonical weapon silhouette behind the effect, copy accepted PNGs byte-for-byte to runtime.",
            "rebuild_command": "python3 docs/design/reference-assets-lfs/priest-vfx-FAN-3318-art/rebuild_runtime_pack.py",
        },
        "packs": summaries,
        "scope_guard": {
            "allowed_paths": [
                "docs/design/reference-assets-lfs/priest-vfx-FAN-3318-art/**",
                "assets/sprites/effects/priest/**",
            ],
            "gameplay_changed": False,
            "scenes_changed": False,
            "shared_runtime_changed": False,
            "balance_changed": False,
        },
    }
    (PACK_ROOT / "provenance_manifest.json").write_text(
        json.dumps(provenance, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print("Rebuilt Priest VFX packs: %s" % ", ".join(pack["id"] for pack in PACKS))
    for summary in summaries:
        print("  %s: %d frames, motion=%.4f, parity=%s" % (
            summary["weapon_id"],
            summary["frame_count"],
            summary["motion"]["motion_score_mean_changed_pixel_ratio"],
            summary["source_runtime_parity"],
        ))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
