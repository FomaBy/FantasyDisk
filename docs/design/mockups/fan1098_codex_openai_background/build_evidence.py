#!/usr/bin/env python3
"""Build FAN-1098 background safe-zone evidence without altering runtime art."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "docs/design/previews/fan1098_codex_openai_background/codex_background_mockup_2560x1440.png"
OVERLAY = ROOT / "docs/design/previews/fan1098_codex_openai_background/codex_background_safe_zones_2560x1440.png"
REPORT = ROOT / "docs/design/previews/fan1098_codex_openai_background/safe_zone_report.json"
DESIGN_SIZE = (1920, 1080)
TARGET_SIZE = (2560, 1440)
SCALE = TARGET_SIZE[0] / DESIGN_SIZE[0]

ZONES = {
    "CodexTitleFrame": (72, 36, 340, 112),
    "CodexCrest": (908, 24, 104, 104),
    "CodexBackButton": (1580, 46, 268, 96),
    "CodexNavPanel": (72, 172, 324, 840),
    "CodexContent": (420, 172, 620, 840),
    "CodexDetailPanel": (1064, 172, 784, 840),
}

COLORS = {
    "CodexTitleFrame": (255, 205, 92, 210),
    "CodexCrest": (184, 128, 255, 220),
    "CodexBackButton": (255, 205, 92, 210),
    "CodexNavPanel": (72, 210, 255, 210),
    "CodexContent": (80, 235, 145, 210),
    "CodexDetailPanel": (255, 126, 126, 210),
}


def scaled_rect(rect: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x, y, width, height = rect
    return tuple(round(value * SCALE) for value in (x, y, x + width, y + height))


def main() -> None:
    base = Image.open(SOURCE).convert("RGB")
    if base.size != TARGET_SIZE:
        raise SystemExit(f"unexpected source size: {base.size}")

    evidence = base.convert("RGBA")
    tint = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(tint, "RGBA")
    font = ImageFont.load_default(size=20)
    stats = {}

    for name, source_rect in ZONES.items():
        rect = scaled_rect(source_rect)
        color = COLORS[name]
        draw.rectangle(rect, fill=(*color[:3], 34), outline=color, width=4)
        draw.text((rect[0] + 10, rect[1] + 8), name, font=font, fill=(255, 255, 255, 235))
        luminance = base.convert("L").crop(rect)
        zone_stat = ImageStat.Stat(luminance)
        stats[name] = {
            "rect_1920x1080": list(source_rect),
            "rect_2560x1440": [rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]],
            "mean_luminance_0_255": round(luminance.resize((1, 1)).getpixel((0, 0)), 2),
            "rms_luminance_0_255": round(zone_stat.rms[0], 2),
        }

    evidence = Image.alpha_composite(evidence, tint).convert("RGB")
    evidence.save(OVERLAY)
    REPORT.write_text(
        json.dumps(
            {
                "issue": "FAN-1098",
                "source": str(SOURCE.relative_to(ROOT)),
                "target_size": list(TARGET_SIZE),
                "design_size": list(DESIGN_SIZE),
                "scale": SCALE,
                "zones": stats,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
