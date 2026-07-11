#!/usr/bin/env python3
"""Build the SCRUM-1061 review contact sheet from accepted PixelLab screens."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/design/mockups/scrum1061_semantic_typography/accepted_frames_contact_sheet.png"
SOURCES = [
    ("SETTINGS / fields + values", ROOT / "docs/design/previews/scrum975_settings_game_tab/settings_game_1920x1080.png"),
    ("CODEX / transformed stage", ROOT / "docs/design/previews/scrum954_codex_runtime/codex_1920x1080.png"),
    ("PAUSE DOSSIER / dense hierarchy", ROOT / "docs/design/previews/atlas_style_pause_menu_2560x1440.png"),
    ("ROUTE MAP / HUD + captions", ROOT / "docs/design/previews/scrum981_gold_menu_shell/pixellab_route_map_gold_shell_reference_688x384.png"),
]
TOKENS = "DISPLAY 32/44/72   TITLE 24/34/54   SECTION 20/24/34   BODY 16/18/24   DESCRIPTION 14/17/22\nACTION 16/23/34   TAB 16/23/28   FIELD 16/20/28   VALUE 16/20/28   TOOLTIP 18/20/24   CAPTION 12/14/18   HUD 14/22/34"


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main() -> None:
    canvas = Image.new("RGB", (1920, 1080), (13, 10, 12))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, 1920, 132), fill=(31, 22, 23), outline=(166, 128, 62), width=3)
    draw.text((40, 22), "SCRUM-1061 — SEMANTIC TYPOGRAPHY ON ACCEPTED PIXELLAB FRAMES", font=font(34), fill=(244, 224, 164))
    draw.multiline_text((40, 72), TOKENS, font=font(16), fill=(226, 226, 222), spacing=6)
    panel_w, panel_h = 920, 420
    positions = [(40, 160), (960, 160), (40, 620), (960, 620)]
    for (label, source), (x, y) in zip(SOURCES, positions):
        draw.rectangle((x, y, x + panel_w, y + panel_h), fill=(7, 7, 9), outline=(117, 89, 48), width=3)
        draw.rectangle((x + 3, y + 3, x + panel_w - 3, y + 44), fill=(36, 27, 25))
        draw.text((x + 18, y + 11), label, font=font(21), fill=(244, 224, 164))
        image = Image.open(source).convert("RGB")
        image.thumbnail((panel_w - 12, panel_h - 56), Image.Resampling.LANCZOS)
        px = x + (panel_w - image.width) // 2
        py = y + 50 + (panel_h - 56 - image.height) // 2
        canvas.paste(image, (px, py))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT, optimize=True)
    print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
