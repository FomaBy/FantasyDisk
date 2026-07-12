#!/usr/bin/env python3
"""Normalize PixelLab SCRUM-895 Axe/Hammer frames and build QA evidence."""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "docs/design/references/scrum895_berserk_axe_hammer_vfx"
RUNTIME = ROOT / "assets/sprites/effects/scrum895_berserk"
PREVIEW = ROOT / "docs/design/previews/scrum895_berserk_axe_hammer_pixellab_contact.png"
REPORT = REF / "frame_qa_report.json"
CANVAS = 256
CONTENT = 224
OFFSET = 16
FRAME_COUNT = 8

PACKS = {
    "axe": {
        "raw": REF / "pixellab_raw/axe",
        "clean": REF / "pixellab_alpha_clean/axe",
        "prefix": "axe_cleave",
        "object_id": "d5452069-7d6e-4646-8b9d-379f0c332f17",
        "group_id": "7e9c7287-d8f0-4461-844e-c1e0bfc5e817",
        "animation_id": "b318ca47-840b-49d4-ab74-32be1d0c9c5a",
        "animation": "cleave",
        "fps": 40.0,
    },
    "hammer": {
        "raw": REF / "pixellab_raw/hammer",
        "clean": REF / "pixellab_alpha_clean/hammer",
        "prefix": "hammer_slam",
        "object_id": "b1fed1f3-71b6-47d5-a1eb-e3e4b8db65b5",
        "group_id": "4515832c-5217-444d-a1a4-b25f1090d435",
        "animation_id": "11ced058-204f-48dc-bfcb-c0aee7665917",
        "animation": "slam",
        "fps": 30.0,
    },
}


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sum((a[index] - b[index]) ** 2 for index in range(3)) ** 0.5


def alpha_clean(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    corners = [pixels[0, 0][:3], pixels[255, 0][:3], pixels[0, 255][:3], pixels[255, 255][:3]]
    background = tuple(round(sum(c[channel] for c in corners) / 4) for channel in range(3))
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()
    for x in range(CANVAS): queue.extend(((x, 0), (x, CANVAS - 1)))
    for y in range(1, CANVAS - 1): queue.extend(((0, y), (CANVAS - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in visited: continue
        visited.add((x, y))
        if distance(pixels[x, y][:3], background) > 38.0: continue
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        if x: queue.append((x - 1, y))
        if x + 1 < CANVAS: queue.append((x + 1, y))
        if y: queue.append((x, y - 1))
        if y + 1 < CANVAS: queue.append((x, y + 1))
    for y in range(CANVAS):
        for x in range(CANVAS):
            r, g, b, alpha = pixels[x, y]
            if alpha: pixels[x, y] = (r, g, b, min(alpha, 205))
    return image


def normalize(clean: Image.Image) -> Image.Image:
    inset = clean.resize((CONTENT, CONTENT), Image.Resampling.NEAREST)
    result = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    result.alpha_composite(inset, (OFFSET, OFFSET))
    return result


def metrics(image: Image.Image) -> dict:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    values = list(alpha.getdata())
    gutters = [bbox[0], bbox[1], CANVAS - bbox[2], CANVAS - bbox[3]] if bbox else None
    edges = sum(alpha.getpixel((x, y)) > 8 for x in range(CANVAS) for y in (0, 255))
    edges += sum(alpha.getpixel((x, y)) > 8 for y in range(1, 255) for x in (0, 255))
    return {
        "size": [image.width, image.height],
        "mode": image.mode,
        "alpha_bbox_gt_8": list(bbox) if bbox else None,
        "gutters_px": gutters,
        "minimum_gutter_px": min(gutters) if gutters else None,
        "edge_visible_pixels": edges,
        "visible_pixels_alpha_gt_8": sum(value > 8 for value in values),
        "visible_ratio_alpha_gt_8": round(sum(value > 8 for value in values) / len(values), 4),
        "max_alpha": max(values),
    }


def write_spriteframes(pack: dict) -> None:
    prefix = pack["prefix"]
    path = RUNTIME / ("%s_spriteframes.tres" % prefix)
    lines = ['[gd_resource type="SpriteFrames" load_steps=9 format=3]', ""]
    for index in range(FRAME_COUNT):
        lines.append('[ext_resource type="Texture2D" path="res://assets/sprites/effects/scrum895_berserk/%s_%02d.png" id="%d_frame"]' % (prefix, index, index + 1))
    lines.extend(["", "[resource]", "animations = [{", '"frames": ['])
    for index in range(FRAME_COUNT):
        suffix = "," if index + 1 < FRAME_COUNT else ""
        lines.extend(["{", '"duration": 1.0,', '"texture": ExtResource("%d_frame")' % (index + 1), "}%s" % suffix])
    lines.extend(['],', '"loop": false,', '"name": &"%s",' % pack["animation"], '"speed": %.3f' % pack["fps"], '}])'])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_contact(all_frames: dict[str, list[Image.Image]]) -> None:
    canvas = Image.new("RGB", (1280, 1320), (14, 12, 18))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 16), "SCRUM-895  PixelLab Berserk weapon motion: Axe cleave + Hammer slam", fill=(238, 211, 164))
    draw.text((24, 38), "8 frames each / 256 RGBA / stable center pivot / >=16px runtime gutter", fill=(174, 197, 218))
    for pack_index, name in enumerate(("axe", "hammer")):
        base_y = 72 + pack_index * 620
        draw.text((24, base_y - 20), "AXE — broad cleave" if name == "axe" else "HAMMER — overhead impact (frame 5)", fill=(255, 170, 88) if name == "axe" else (208, 180, 255))
        for index, frame in enumerate(all_frames[name]):
            x = 128 + (index % 4) * 256
            y = base_y + (index // 4) * 290
            cell = Image.new("RGBA", (256, 256), (34, 30, 40, 255)); cell.alpha_composite(frame)
            canvas.paste(cell.convert("RGB"), (x, y))
            label = "frame %d" % index
            if name == "hammer" and index == 5: label += "  IMPACT"
            draw.text((x + 8, y + 260), label, fill=(255, 207, 110) if "IMPACT" in label else (225, 220, 211))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(PREVIEW)


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    report = {"issue": "SCRUM-895", "pixel_lab_only": True, "openai_images_used": False, "packs": {}, "decision": "pass"}
    all_frames: dict[str, list[Image.Image]] = {}
    for name, pack in PACKS.items():
        pack["clean"].mkdir(parents=True, exist_ok=True)
        rows = []; frames = []
        for index in range(FRAME_COUNT):
            raw_path = pack["raw"] / ("%s_%02d.png" % (pack["prefix"], index))
            raw = Image.open(raw_path).convert("RGBA")
            if raw.size != (CANVAS, CANVAS): raise SystemExit("Bad PixelLab size: %s" % raw_path)
            clean = alpha_clean(raw)
            clean_path = pack["clean"] / raw_path.name; clean.save(clean_path)
            runtime = normalize(clean)
            runtime_path = RUNTIME / raw_path.name; runtime.save(runtime_path)
            row_metrics = metrics(runtime)
            if not row_metrics["alpha_bbox_gt_8"] or row_metrics["minimum_gutter_px"] < 16 or row_metrics["edge_visible_pixels"]:
                raise SystemExit("%s frame %d failed alpha/gutter: %s" % (name, index, row_metrics))
            rows.append({"index": index, "raw_path": str(raw_path.relative_to(ROOT)), "clean_path": str(clean_path.relative_to(ROOT)), "runtime_path": str(runtime_path.relative_to(ROOT)), "runtime_metrics": row_metrics, "sha256": hashlib.sha256(runtime_path.read_bytes()).hexdigest()})
            frames.append(runtime)
        write_spriteframes(pack)
        report["packs"][name] = {"object_id": pack["object_id"], "animation_group_id": pack["group_id"], "animation_id": pack["animation_id"], "frame_count": FRAME_COUNT, "pivot": [128, 128], "runtime_safe_gutter_px": 16, "frames": rows}
        all_frames[name] = frames
    build_contact(all_frames)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("SCRUM-895 built Axe/Hammer PixelLab frames; report=%s" % REPORT.relative_to(ROOT))
    print("contact=%s" % PREVIEW.relative_to(ROOT))


if __name__ == "__main__":
    main()
