#!/usr/bin/env python3
"""Build SCRUM-725 Codex runtime PNGs from the accepted layout contract.

PixelLab source generations are kept next to this script as provenance. The
runtime assets are deterministic cleanup outputs: textless, alpha-clean, and
with ornament confined to the documented 9-slice margin bands.
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[4]
RUNTIME = ROOT / "assets/sprites/ui/frames/codex_pl"
FIT = RUNTIME / "fit"
PREVIEWS = ROOT / "docs/design/previews"
QA = ROOT / "build/qa"

BG_DEEP = (26, 21, 18, 255)
PANEL_FILL = (33, 26, 21, 232)
PANEL_FILL_DARK = (24, 20, 18, 238)
GOLD = (184, 147, 78, 255)
GOLD_HI = (216, 181, 106, 255)
GOLD_DIM = (104, 78, 42, 255)
RUBY = (126, 32, 31, 245)
TRANSPARENT = (0, 0, 0, 0)


ASSETS = [
    ("codex_pl_main_shell.png", (688, 384), 48, True),
    ("codex_pl_nav_panel.png", (384, 688), 48, False),
    ("codex_pl_grid_panel.png", (512, 512), 48, False),
    ("codex_pl_detail_panel.png", (384, 688), 48, False),
    ("codex_pl_entry_card.png", (688, 192), 20, False),
    ("codex_pl_category_button.png", (512, 192), 24, False),
    ("codex_pl_back_button.png", (384, 192), 20, False),
]


def draw_frame(size: tuple[int, int], margin: int, transparent_center: bool) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, TRANSPARENT)
    draw = ImageDraw.Draw(img)
    fill = TRANSPARENT if transparent_center else PANEL_FILL
    outer = (0, 0, w - 1, h - 1)
    inner = (margin, margin, w - margin - 1, h - margin - 1)

    if not transparent_center:
        draw.rectangle(inner, fill=fill)

    # Border bands stay inside the 9-slice margins.
    draw.rectangle((0, 0, w - 1, margin - 1), fill=PANEL_FILL_DARK)
    draw.rectangle((0, h - margin, w - 1, h - 1), fill=PANEL_FILL_DARK)
    draw.rectangle((0, margin, margin - 1, h - margin - 1), fill=PANEL_FILL_DARK)
    draw.rectangle((w - margin, margin, w - 1, h - margin - 1), fill=PANEL_FILL_DARK)

    for inset, color in [(2, GOLD_DIM), (5, GOLD), (margin - 8, GOLD_DIM)]:
        draw.rectangle((inset, inset, w - 1 - inset, h - 1 - inset), outline=color, width=2)
    draw.rectangle(inner, outline=(8, 8, 8, 210), width=3)
    draw.rectangle((margin + 4, margin + 4, w - margin - 5, h - margin - 5), outline=(65, 54, 43, 150), width=1)

    corner = max(12, margin - 8)
    for sx in [0, w - corner]:
        for sy in [0, h - corner]:
            draw.rectangle((sx + 4, sy + 4, sx + corner - 4, sy + corner - 4), outline=GOLD_HI, width=2)
            draw.line((sx + 7, sy + corner // 2, sx + corner - 7, sy + corner // 2), fill=GOLD_DIM, width=1)
            draw.line((sx + corner // 2, sy + 7, sx + corner // 2, sy + corner - 7), fill=GOLD_DIM, width=1)

    # Small rivets and ruby accents, still inside border bands.
    rivet_r = max(2, margin // 14)
    for x, y in [(margin // 2, margin // 2), (w - margin // 2, margin // 2), (margin // 2, h - margin // 2), (w - margin // 2, h - margin // 2)]:
        draw.ellipse((x - rivet_r, y - rivet_r, x + rivet_r, y + rivet_r), fill=GOLD_HI, outline=GOLD_DIM)
    if w > 400 and h > 160:
        cx = w // 2
        draw.polygon([(cx, 10), (cx + 14, 24), (cx, 38), (cx - 14, 24)], fill=RUBY, outline=GOLD_DIM)
    return img


def draw_backdrop() -> Image.Image:
    w, h = 688, 384
    img = Image.new("RGBA", (w, h), BG_DEEP)
    draw = ImageDraw.Draw(img)
    for y in range(0, h, 24):
        shade = 18 + (y // 24) % 3 * 6
        draw.rectangle((0, y, w, min(h, y + 23)), fill=(shade, shade - 3, shade - 5, 255))
    for x in range(0, w, 64):
        draw.line((x, 0, x, h), fill=(38, 31, 27, 140), width=2)
    for y in range(36, h, 48):
        draw.line((0, y, w, y), fill=(44, 35, 29, 150), width=2)

    # Shelves and archive silhouettes.
    for shelf_y in [42, 78, 292]:
        draw.rectangle((34, shelf_y, 244, shelf_y + 10), fill=(71, 48, 31, 230))
        draw.rectangle((444, shelf_y + 8, 650, shelf_y + 18), fill=(65, 45, 30, 220))
        for x in range(44, 230, 13):
            draw.rectangle((x, shelf_y - 22, x + 7, shelf_y), fill=(84, 61, 37, 210))
        for x in range(456, 636, 15):
            draw.rectangle((x, shelf_y - 18, x + 8, shelf_y + 7), fill=(73, 53, 35, 210))

    # Candle glows.
    glow = Image.new("RGBA", (w, h), TRANSPARENT)
    gdraw = ImageDraw.Draw(glow)
    for cx, cy in [(96, 312), (590, 262), (340, 80)]:
        for r, alpha in [(42, 18), (24, 34), (9, 90)]:
            gdraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 174, 77, alpha))
        gdraw.rectangle((cx - 3, cy - 16, cx + 3, cy + 14), fill=(210, 184, 132, 230))
        gdraw.polygon([(cx, cy - 27), (cx + 5, cy - 13), (cx, cy - 6), (cx - 5, cy - 13)], fill=(255, 201, 98, 240))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(2.0)))

    # Vignette keeps panel area readable.
    vignette = Image.new("RGBA", (w, h), TRANSPARENT)
    vdraw = ImageDraw.Draw(vignette)
    for i in range(42):
        alpha = int(i * 3.5)
        vdraw.rectangle((i, i, w - 1 - i, h - 1 - i), outline=(0, 0, 0, alpha), width=1)
    return Image.alpha_composite(img, vignette)


def build_contact(paths: list[tuple[str, Path]]) -> None:
    thumb_w, thumb_h = 344, 220
    sheet = Image.new("RGBA", (thumb_w * 2, (thumb_h + 34) * 4), (18, 16, 14, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, path) in enumerate(paths):
        img = Image.open(path).convert("RGBA")
        canvas = Image.new("RGBA", (thumb_w, thumb_h), (32, 27, 22, 255))
        scale = min((thumb_w - 20) / img.width, (thumb_h - 20) / img.height)
        resized = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.Resampling.NEAREST)
        x = (thumb_w - resized.width) // 2
        y = (thumb_h - resized.height) // 2
        canvas.alpha_composite(resized, (x, y))
        sx = (i % 2) * thumb_w
        sy = (i // 2) * (thumb_h + 34)
        sheet.alpha_composite(canvas, (sx, sy + 24))
        draw.text((sx + 10, sy + 4), f"{name} {img.width}x{img.height}", fill=(232, 214, 168, 255))
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEWS / "codex_redesign_2026_06_runtime_contact.png")


def audit(paths: list[tuple[str, Path]]) -> None:
	lines = ["# SCRUM-725 Codex Runtime Asset Audit", ""]
	for name, path in paths:
		img = Image.open(path).convert("RGBA")
		alpha = img.getchannel("A")
		lines.append(f"- `{path.relative_to(ROOT)}`: {img.width}x{img.height}, alpha_bbox={alpha.getbbox()}, alpha_extrema={alpha.getextrema()}")
	QA.mkdir(parents=True, exist_ok=True)
	(QA / "codex_redesign_asset_audit.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
	(Path(__file__).resolve().parent / "runtime_asset_audit.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    FIT.mkdir(parents=True, exist_ok=True)
    written: list[tuple[str, Path]] = []
    for filename, size, margin, transparent_center in ASSETS:
        img = draw_frame(size, margin, transparent_center)
        for folder in [RUNTIME, FIT]:
            out = folder / filename
            img.save(out)
        written.append((filename, RUNTIME / filename))
    backdrop = draw_backdrop()
    backdrop.save(RUNTIME / "codex_pl_backdrop.png")
    written.append(("codex_pl_backdrop.png", RUNTIME / "codex_pl_backdrop.png"))
    build_contact(written)
    audit(written)


if __name__ == "__main__":
    main()
