#!/usr/bin/env python3
"""Build the SCRUM-1015 source contact sheet and alpha/crop QA evidence."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
PREVIEWS = ROOT.parents[1] / "previews"
CREATURES = [
    ("druid_ghost_wolf", "PHYSICAL MELEE AOE"),
    ("druid_ghost_bear", "PHYSICAL MELEE AOE"),
    ("druid_ghost_panther", "PHYSICAL MELEE AOE"),
    ("druid_ghost_stag", "MAGICAL RANGED CASTER"),
    ("druid_ghost_lion", "MAGICAL RANGED CASTER"),
]
DIRECTIONS = ("west", "east")


def font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def checker(size: tuple[int, int], cell: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (25, 29, 38, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(38, 44, 58, 255))
    return image


def main() -> int:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (1600, 1040), (8, 11, 20, 255))
    debug = canvas.copy()
    draw = ImageDraw.Draw(canvas)
    debug_draw = ImageDraw.Draw(debug)
    title_font = font(38)
    label_font = font(25)
    small_font = font(19)
    draw.text((42, 24), "DRUID GHOST SUMMONS — PIXELLAB SOURCE CONCEPTS", font=title_font, fill=(199, 244, 255, 255))
    debug_draw.text((42, 24), "ALPHA / GUTTER QA", font=title_font, fill=(255, 220, 120, 255))
    draw.text((680, 78), "WEST / LEFT", font=label_font, fill=(125, 219, 255, 255), anchor="mm")
    draw.text((1260, 78), "EAST / RIGHT", font=label_font, fill=(125, 219, 255, 255), anchor="mm")
    debug_draw.text((680, 78), "WEST / LEFT", font=label_font, fill=(125, 219, 255, 255), anchor="mm")
    debug_draw.text((1260, 78), "EAST / RIGHT", font=label_font, fill=(125, 219, 255, 255), anchor="mm")

    report: dict[str, object] = {"ok": True, "files": []}
    for row, (creature_id, role) in enumerate(CREATURES):
        top = 108 + row * 182
        draw.rounded_rectangle((28, top, 1572, top + 166), radius=18, fill=(16, 24, 38, 255), outline=(58, 121, 151, 255), width=2)
        debug_draw.rounded_rectangle((28, top, 1572, top + 166), radius=18, fill=(16, 24, 38, 255), outline=(116, 96, 52, 255), width=2)
        draw.text((52, top + 45), creature_id, font=label_font, fill=(228, 245, 255, 255))
        draw.text((52, top + 88), role, font=small_font, fill=(120, 207, 237, 255))
        debug_draw.text((52, top + 45), creature_id, font=label_font, fill=(228, 245, 255, 255))
        debug_draw.text((52, top + 88), role, font=small_font, fill=(255, 214, 120, 255))

        baselines: list[int] = []
        for col, direction in enumerate(DIRECTIONS):
            path = ROOT / f"{creature_id}_{direction}.png"
            source = Image.open(path).convert("RGBA")
            alpha = source.getchannel("A")
            bbox = alpha.getbbox()
            corner_alpha = [alpha.getpixel((0, 0)), alpha.getpixel((source.width - 1, 0)), alpha.getpixel((0, source.height - 1)), alpha.getpixel((source.width - 1, source.height - 1))]
            gutter = None
            passed = bbox is not None and max(corner_alpha) == 0 and alpha.getextrema()[0] == 0
            if bbox is not None:
                gutter = [bbox[0], bbox[1], source.width - bbox[2], source.height - bbox[3]]
                passed = passed and min(gutter) >= 2
                baselines.append(bbox[3])
            report["files"].append({"file": path.name, "size": [source.width, source.height], "alpha_extrema": list(alpha.getextrema()), "visible_bbox": list(bbox) if bbox else None, "gutter_ltrb": gutter, "corner_alpha": corner_alpha, "pass": passed})
            report["ok"] = bool(report["ok"]) and passed

            panel_x = 500 + col * 580
            panel = checker((360, 148))
            preview = source.copy()
            preview.thumbnail((320, 138), Image.Resampling.NEAREST)
            px = (panel.width - preview.width) // 2
            py = panel.height - preview.height - 5
            panel.alpha_composite(preview, (px, py))
            canvas.alpha_composite(panel, (panel_x, top + 9))
            debug.alpha_composite(panel, (panel_x, top + 9))
            if bbox is not None:
                scale_x = preview.width / source.width
                scale_y = preview.height / source.height
                bx0 = panel_x + px + round(bbox[0] * scale_x)
                by0 = top + 9 + py + round(bbox[1] * scale_y)
                bx1 = panel_x + px + round(bbox[2] * scale_x)
                by1 = top + 9 + py + round(bbox[3] * scale_y)
                debug_draw.rectangle((bx0, by0, bx1, by1), outline=(255, 91, 180, 255), width=2)
        stable = len(baselines) == 2 and abs(baselines[0] - baselines[1]) <= 5
        report.setdefault("baseline_checks", []).append({"id": creature_id, "visible_bottom_rows": baselines, "delta": abs(baselines[0] - baselines[1]) if len(baselines) == 2 else None, "pass": stable})
        report["ok"] = bool(report["ok"]) and stable

    contact_path = PREVIEWS / "druid_summons_ghost_pack_contact.png"
    debug_path = PREVIEWS / "druid_summons_ghost_pack_alpha_qa.png"
    canvas.convert("RGB").save(contact_path)
    debug.convert("RGB").save(debug_path)
    (ROOT / "qa_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"ok": report["ok"], "contact": str(contact_path), "debug": str(debug_path)}, ensure_ascii=False))
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
