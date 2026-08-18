#!/usr/bin/env python3
"""FAN-3052: point-fix flickering move frames for void_mage west/north-west/south-east.

QA (FAN-2750) rejected the FAN-2614 candidate because the pink item held by
void_mage appears inconsistently across the 6 frames of the move animation on
these three direction rows (present in some frames, absent in others). This
regenerates ONLY those 18 raw source frames (already re-animated on the
PixelLab character via animate_character, reusing the existing move animation
group so the other 5 directions/other states are untouched), re-normalizes
them with the exact FAN-2614 pipeline (tools/build_fan2614_void_mage_pack.py),
and overwrites the matching 18 runtime PNGs in place. The .tres and the other
7 animation states are not touched.
"""
from __future__ import annotations

import json
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ID = "void_mage"
SOURCE_DIR = ROOT / "assets/sprites/enemies/pixellab/void_mage"
RUNTIME_DIR = ROOT / "assets/sprites/enemies/full_frame/void_mage_8dir"
CELL_SIZE = 512
TARGET_VISIBLE_HEIGHT = 245
BOTTOM_PADDING = 32
USER_AGENT = "FantasyDisk-FAN3052/1.0"

# direction -> filename suffix -> frame URLs (from animate_character, group 43e52595)
FRAME_URLS = {
    "west": [
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/146d6a5e-96e3-4945-b028-52212cf3f9d1/west/0.png?t=1787092979378",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/146d6a5e-96e3-4945-b028-52212cf3f9d1/west/1.png?t=1787092979378",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/146d6a5e-96e3-4945-b028-52212cf3f9d1/west/2.png?t=1787092979378",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/146d6a5e-96e3-4945-b028-52212cf3f9d1/west/3.png?t=1787092979378",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/146d6a5e-96e3-4945-b028-52212cf3f9d1/west/4.png?t=1787092979378",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/146d6a5e-96e3-4945-b028-52212cf3f9d1/west/5.png?t=1787092979378",
    ],
    "north_west": [
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/87195359-8cf5-40ba-afd5-a32d8f60c7f8/north-west/0.png?t=1787093041888",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/87195359-8cf5-40ba-afd5-a32d8f60c7f8/north-west/1.png?t=1787093041888",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/87195359-8cf5-40ba-afd5-a32d8f60c7f8/north-west/2.png?t=1787093041888",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/87195359-8cf5-40ba-afd5-a32d8f60c7f8/north-west/3.png?t=1787093041888",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/87195359-8cf5-40ba-afd5-a32d8f60c7f8/north-west/4.png?t=1787093041888",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/87195359-8cf5-40ba-afd5-a32d8f60c7f8/north-west/5.png?t=1787093041888",
    ],
    "south_east": [
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/8af2fd41-80d9-4a83-a97f-4a1f6226ad2e/south-east/0.png?t=1787097132525",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/8af2fd41-80d9-4a83-a97f-4a1f6226ad2e/south-east/1.png?t=1787097132525",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/8af2fd41-80d9-4a83-a97f-4a1f6226ad2e/south-east/2.png?t=1787097132525",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/8af2fd41-80d9-4a83-a97f-4a1f6226ad2e/south-east/3.png?t=1787097132525",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/8af2fd41-80d9-4a83-a97f-4a1f6226ad2e/south-east/4.png?t=1787097132525",
        "https://backblaze.pixellab.ai/file/pixellab-characters/7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/63c8426e-dd29-48b7-b2d7-00dad7f592c3/animations/8af2fd41-80d9-4a83-a97f-4a1f6226ad2e/south-east/5.png?t=1787097132525",
    ],
}


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(response.read())


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def normalize_frame(source_path: Path, dest_path: Path) -> dict:
    image = Image.open(source_path).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError(f"{source_path} has no visible alpha")
    bbox_width = bbox[2] - bbox[0]
    bbox_height = bbox[3] - bbox[1]
    height_scale = TARGET_VISIBLE_HEIGHT / float(bbox_height)
    width_scale = CELL_SIZE / float(bbox_width)
    scale = min(height_scale, width_scale)
    scaled_size = (max(1, round(bbox_width * scale)), max(1, round(bbox_height * scale)))
    resized = image.crop(bbox).resize(scaled_size, Image.Resampling.NEAREST)
    paste_x = round((CELL_SIZE - scaled_size[0]) / 2.0)
    paste_y = CELL_SIZE - BOTTOM_PADDING - scaled_size[1]
    if paste_x < 0 or paste_y < 0 or paste_x + scaled_size[0] > CELL_SIZE or paste_y + scaled_size[1] > CELL_SIZE:
        raise RuntimeError(f"{source_path} normalized outside canvas ({scaled_size})")
    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest_path)
    runtime_bbox = alpha_bbox(canvas)
    return {
        "source": source_path.name,
        "runtime": dest_path.name,
        "source_size": list(image.size),
        "source_alpha_bbox": list(bbox),
        "source_alpha_bbox_size": [bbox_width, bbox_height],
        "scale": scale,
        "resized_visible_size": list(scaled_size),
        "runtime_alpha_bbox": list(runtime_bbox) if runtime_bbox else None,
    }


def main() -> int:
    alpha_report_path = SOURCE_DIR / "alpha_bbox_report.json"
    alpha_report = json.loads(alpha_report_path.read_text(encoding="utf-8"))

    for suffix, urls in FRAME_URLS.items():
        reports = []
        for index, url in enumerate(urls):
            src = SOURCE_DIR / f"{CHARACTER_ID}_move_{suffix}_{index:02d}.png"
            dest = RUNTIME_DIR / f"{CHARACTER_ID}_move_{suffix}_{index:02d}.png"
            download(url, src)
            reports.append(normalize_frame(src, dest))
        alpha_report[f"move_{suffix}"] = reports
        print(f"fixed move_{suffix}: {len(reports)} frames")

    alpha_report_path.write_text(json.dumps(alpha_report, indent=2), encoding="utf-8")

    manifest_path = SOURCE_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.setdefault("notes", "")
    manifest["notes"] += (
        " FAN-3052: re-animated move west/north-west/south-east (walking-6-frames, "
        "same animation group) to fix inconsistent pink-item visibility across "
        "frames within a direction row; other directions/states untouched."
    )
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"updated {manifest_path}")
    print(f"updated {alpha_report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
