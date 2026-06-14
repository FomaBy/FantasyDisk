#!/usr/bin/env python3
"""Generate SCRUM-356 Hero Select unified frame assets.

Task-specific OpenAI Images wrapper following the fantasydisk-asset-generator
rules without creating extra integration tasks. Runtime integration remains
Back-end scope; this script only creates Design-owned PNGs and metadata.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


MODEL = "gpt-image-2"
ROOT = Path(__file__).resolve().parents[1]
REF_DIR = ROOT / "docs/design/references/hero_select_unified_panel"
ASSET_DIR = ROOT / "assets/sprites/ui/frames/hero_select"
PREVIEW_DIR = ROOT / "docs/design/previews"
QA_DIR = ROOT / "build/qa/scrum356"

UNIFIED_SIZE = (1536, 1024)
BUTTON_SOURCE_SIZE = (1024, 1024)
BUTTON_ASSET_SIZE = (256, 256)

UNIFIED_SOURCE_PATH = REF_DIR / "ui_frame_hero_select_unified_panel_source.png"
UNIFIED_RUNTIME_PATH = ASSET_DIR / "ui_frame_hero_select_unified_panel.png"
ASC_BUTTON_SOURCE_PATH = REF_DIR / "ui_frame_hero_select_asc_button_small_source.png"
ASC_BUTTON_RUNTIME_PATH = ASSET_DIR / "ui_frame_hero_select_asc_button_small.png"
METADATA_PATH = REF_DIR / "scrum356_unified_panel_metadata.json"
PREVIEW_PATH = PREVIEW_DIR / "scrum356_hero_select_unified_panel_content_zones.png"


def require_env() -> None:
    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("OPENAI_API_KEY is not set")


def openai_client():
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise SystemExit("Python package 'openai' is not installed") from exc
    return OpenAI()


def make_edit_input() -> Path:
    """Compose current accepted Hero Select frames as a style/layout reference."""
    REF_DIR.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGB", UNIFIED_SIZE, (0, 255, 0))
    portrait = Image.open(ASSET_DIR / "ui_frame_hero_select_portrait.png").convert("RGBA")
    dossier = Image.open(ASSET_DIR / "ui_frame_hero_select_dossier.png").convert("RGBA")
    portrait.thumbnail((430, 760), Image.Resampling.LANCZOS)
    dossier.thumbnail((760, 760), Image.Resampling.LANCZOS)
    canvas.paste((10, 10, 10), (0, 0, *UNIFIED_SIZE))
    # A muted green field tells the model which areas must remain empty.
    ImageDraw.Draw(canvas).rounded_rectangle((78, 80, 1458, 944), radius=64, fill=(0, 240, 0))
    canvas.paste(portrait, (130, 145), portrait)
    canvas.paste(dossier, (610, 145), dossier)
    path = REF_DIR / "scrum356_edit_input_existing_frames.png"
    canvas.save(path)
    return path


def call_edit(image_path: Path, prompt: str, size: str, quality: str) -> bytes:
    client = openai_client()
    with image_path.open("rb") as image_file:
        result = client.images.edit(
            model=MODEL,
            image=image_file,
            prompt=prompt,
            size=size,
            quality=quality,
            output_format="png",
        )
    if not result.data or not result.data[0].b64_json:
        raise SystemExit("OpenAI Images returned no b64_json")
    return base64.b64decode(result.data[0].b64_json)


def call_generate(prompt: str, size: str, quality: str) -> bytes:
    client = openai_client()
    result = client.images.generate(
        model=MODEL,
        prompt=prompt,
        size=size,
        quality=quality,
        output_format="png",
    )
    if not result.data or not result.data[0].b64_json:
        raise SystemExit("OpenAI Images returned no b64_json")
    return base64.b64decode(result.data[0].b64_json)


def chroma_alpha(im: Image.Image) -> Image.Image:
    """Remove green-screen-like background and preserve ornament edges."""
    rgba = im.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            green_score = g - max(r, b)
            if g > 80 and green_score > 18:
                alpha = 0 if green_score > 45 else max(0, min(255, int(255 - green_score * 8.0)))
                # Decontaminate antialias pixels so no green fringe survives.
                pixels[x, y] = (min(r, 42), min(g, 42), min(b, 42), min(a, alpha))
    return rgba


def clear_rect(im: Image.Image, rect: tuple[int, int, int, int], feather: int = 8) -> None:
    x, y, w, h = rect
    mask = Image.new("L", im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=255)
    if feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
    r, g, b, a = im.split()
    # Strongly clear the content-zone interior; feather leaves a soft transition.
    a = Image.composite(Image.new("L", im.size, 0), a, mask)
    im.putalpha(a)


def build_unified_runtime(source_path: Path) -> Image.Image:
    im = Image.open(source_path)
    if im.size != UNIFIED_SIZE:
        im = im.resize(UNIFIED_SIZE, Image.Resampling.LANCZOS)
    rgba = chroma_alpha(im)

    # Hard safe zones: runtime content may only live in these cleared interiors.
    for rect in [
        (130, 145, 420, 560),   # portrait well
        (610, 145, 786, 500),   # description/text well
        (570, 705, 660, 178),   # ascension + choose controls
    ]:
        clear_rect(rgba, rect, feather=5)
    rgba.save(UNIFIED_RUNTIME_PATH)
    return rgba


def build_button_runtime(source_path: Path) -> Image.Image:
    im = Image.open(source_path)
    if im.size != BUTTON_SOURCE_SIZE:
        im = im.resize(BUTTON_SOURCE_SIZE, Image.Resampling.LANCZOS)
    rgba = chroma_alpha(im)
    # Crop central square and resize for runtime. Keep border, clear sign/content.
    bbox = rgba.getchannel("A").getbbox() or (0, 0, *BUTTON_SOURCE_SIZE)
    crop = rgba.crop(bbox)
    pad = max(crop.size)
    square = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
    square.alpha_composite(crop, ((pad - crop.width) // 2, (pad - crop.height) // 2))
    square = square.resize(BUTTON_ASSET_SIZE, Image.Resampling.LANCZOS)
    clear_rect(square, (76, 74, 104, 106), feather=4)
    square.save(ASC_BUTTON_RUNTIME_PATH)
    return square


def write_metadata() -> None:
    metadata = {
        "task": "SCRUM-356",
        "assets": {
            "unified_panel": {
                "path": UNIFIED_RUNTIME_PATH.relative_to(ROOT).as_posix(),
                "source_path": UNIFIED_SOURCE_PATH.relative_to(ROOT).as_posix(),
                "source_size": list(UNIFIED_SIZE),
                "content_zones": {
                    "portrait": [130, 145, 420, 560],
                    "description": [610, 145, 786, 500],
                    "bottom_controls": [570, 705, 660, 178],
                },
                "outer_safe_margins": [112, 110, 112, 104],
                "runtime_note": "Draw as whole-image TextureRect with proportional scaling; do not 9-slice/stretch one axis.",
            },
            "asc_button_small": {
                "path": ASC_BUTTON_RUNTIME_PATH.relative_to(ROOT).as_posix(),
                "source_path": ASC_BUTTON_SOURCE_PATH.relative_to(ROOT).as_posix(),
                "source_size": list(BUTTON_ASSET_SIZE),
                "content_margins": [76, 74, 76, 76],
                "runtime_note": "Use for both minus and plus; runtime text/sign must be centered inside cleared content zone.",
            },
        },
        "global_rule": "No content may overlap frame ornament; use only the listed content_zones.",
    }
    METADATA_PATH.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def make_preview() -> None:
    panel = Image.open(UNIFIED_RUNTIME_PATH).convert("RGBA")
    preview = Image.new("RGBA", panel.size, (18, 14, 12, 255))
    preview.alpha_composite(panel)
    draw = ImageDraw.Draw(preview)
    zones = {
        "portrait": (130, 145, 420, 560),
        "description": (610, 145, 786, 500),
        "bottom controls": (570, 705, 660, 178),
    }
    for label, (x, y, w, h) in zones.items():
        draw.rounded_rectangle((x, y, x + w, y + h), radius=18, outline=(95, 220, 170, 230), width=4)
        draw.text((x + 12, y + 10), label, fill=(215, 245, 225, 255))
    button = Image.open(ASC_BUTTON_RUNTIME_PATH).convert("RGBA")
    button.thumbnail((92, 92), Image.Resampling.LANCZOS)
    preview.alpha_composite(button, (980, 748))
    preview.alpha_composite(button, (1090, 748))
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW_PATH)


def run(quality: str, skip_api: bool) -> None:
    require_env()
    REF_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)

    edit_input = make_edit_input()
    if not skip_api:
        unified_prompt = """
Create one single unified Hero Select portrait plus description UI frame for a dark fantasy Dungeons & Dragons game.
Use the provided two existing frames only as style reference, but merge them into one wide horizontal frame.
Thin ornate border, dark aged steel and blackened leather, subtle antique gold bevels, tiny red dragon-eye gems, realistic painterly material.
One continuous outer frame, not two separate panels. Include a subtle internal divider between left portrait area and right description area, and a bottom control band.
The center content areas must be empty and clean, shown as pure flat chroma green (#00FF00) so they can be cut to transparent.
Outside the frame must also be pure flat chroma green (#00FF00). No text, no icons, no character, no labels, no watermark.
No heavy chunky border: keep all ornament thin, elegant, sharp, and readable.
"""
        UNIFIED_SOURCE_PATH.write_bytes(call_edit(edit_input, unified_prompt, "1536x1024", quality))

        button_prompt = """
Create one compact square ascension stepper button frame for a dark fantasy Dungeons & Dragons game UI.
Single button only, centered, no plus sign, no minus sign, no text, no icon, no watermark.
Thin dark steel border, antique gold edge, small red gemstone accents, realistic painterly material, matches FantasyDisk hero select UI.
The button center must be empty pure flat chroma green (#00FF00) for runtime plus/minus text. Outside the button is pure flat chroma green (#00FF00).
Transparent-ready, clean silhouette, no yellow hover glow.
"""
        ASC_BUTTON_SOURCE_PATH.write_bytes(call_generate(button_prompt, "1024x1024", quality))

    build_unified_runtime(UNIFIED_SOURCE_PATH)
    build_button_runtime(ASC_BUTTON_SOURCE_PATH)
    write_metadata()
    make_preview()
    print(UNIFIED_RUNTIME_PATH.relative_to(ROOT))
    print(ASC_BUTTON_RUNTIME_PATH.relative_to(ROOT))
    print(METADATA_PATH.relative_to(ROOT))
    print(PREVIEW_PATH.relative_to(ROOT))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quality", default="high", choices=["low", "medium", "high", "auto"])
    parser.add_argument("--skip-api", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run(args.quality, args.skip_api)
