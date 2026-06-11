"""Point touch-ups for the dark-fantasy artifact icon set (Codex pass 2).

Final design review fixes, painted over the existing painterly texture
(no regeneration): codex_design_artifact_icons_dark_fantasy_task.md
  - old_codex: panel -> closed book (spine, page block, clasp, cover rune)
  - ink_candle: visible warm flame with glow
  - summoners_bell: dome highlight, clapper, loop handle

Run from the project root:  python3 tools/touchup_artifact_icons.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"

OUTLINE = (34, 26, 38, 255)


def soft_layer(size: tuple[int, int], draw_calls, blur: float = 0.0) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    draw_calls(d)
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer


def fix_old_codex() -> None:
    path = ICONS / "artifact_old_codex.png"
    img = Image.open(path).convert("RGBA")
    # cover bbox of the existing panel art (256x256, panel ~ (52,40)-(204,216))
    x1, y1, x2, y2 = 52, 40, 204, 216

    def spine(d: ImageDraw.ImageDraw) -> None:
        # dark leather spine band on the left with stitch ticks
        d.rectangle((x1, y1, x1 + 34, y2), fill=(58, 40, 34, 210))
        d.rectangle((x1 + 30, y1, x1 + 36, y2), fill=OUTLINE)
        for ty in range(y1 + 16, y2 - 10, 26):
            d.line((x1 + 8, ty, x1 + 24, ty), fill=(120, 92, 70, 220), width=4)

    def pages(d: ImageDraw.ImageDraw) -> None:
        # light page block peeking on the right edge
        d.rectangle((x2 - 16, y1 + 10, x2, y2 - 10), fill=(214, 196, 158, 235))
        for off in (14, 28, 42):
            d.line((x2 - 16, y1 + 10 + off, x2, y1 + 6 + off), fill=(160, 140, 104, 220), width=3)
        d.rectangle((x2 - 17, y1 + 9, x2 + 1, y2 - 9), outline=OUTLINE, width=3)

    def clasp(d: ImageDraw.ImageDraw) -> None:
        cy = (y1 + y2) // 2
        d.rectangle((x2 - 44, cy - 12, x2 + 2, cy + 12), fill=(96, 78, 52, 255))
        d.rectangle((x2 - 44, cy - 12, x2 + 2, cy + 12), outline=OUTLINE, width=3)
        d.ellipse((x2 - 30, cy - 6, x2 - 18, cy + 6), fill=(196, 160, 92, 255))

    def rune(d: ImageDraw.ImageDraw) -> None:
        cx, cy = (x1 + 36 + x2 - 18) // 2, (y1 + y2) // 2
        pts = [(cx, cy - 26), (cx + 18, cy), (cx, cy + 26), (cx - 18, cy)]
        d.polygon(pts, outline=(168, 120, 255, 200), width=5)
        d.line((cx, cy - 26, cx, cy + 26), fill=(168, 120, 255, 150), width=4)

    for layer_fn, blur in ((spine, 0.8), (pages, 0.6), (clasp, 0.6), (rune, 1.0)):
        img.alpha_composite(soft_layer(img.size, layer_fn, blur))
    img.save(path)
    print("old_codex -> closed book")


def fix_ink_candle() -> None:
    path = ICONS / "artifact_ink_candle.png"
    img = Image.open(path).convert("RGBA")
    # the wick column tops out around y=36 at x~128
    cx, top = 128, 36

    def glow(d: ImageDraw.ImageDraw) -> None:
        d.ellipse((cx - 26, top - 34, cx + 26, top + 18), fill=(255, 168, 60, 90))

    def flame(d: ImageDraw.ImageDraw) -> None:
        d.polygon([(cx, top - 28), (cx + 10, top - 6), (cx, top + 8), (cx - 10, top - 6)], fill=(255, 150, 40, 240))
        d.polygon([(cx, top - 20), (cx + 5, top - 4), (cx, top + 4), (cx - 5, top - 4)], fill=(255, 226, 140, 255))

    img.alpha_composite(soft_layer(img.size, glow, 7.0))
    img.alpha_composite(soft_layer(img.size, flame, 0.8))
    img.save(path)
    print("ink_candle -> visible flame")


def fix_summoners_bell() -> None:
    path = ICONS / "artifact_summoners_bell.png"
    img = Image.open(path).convert("RGBA")
    # body widens from y~75, bottom rim narrows to ~y222; handle already exists
    cx, rim_y = 128, 214

    def dome_light(d: ImageDraw.ImageDraw) -> None:
        d.arc((62, 84, 194, 206), 200, 282, fill=(240, 214, 150, 120), width=10)

    def clapper(d: ImageDraw.ImageDraw) -> None:
        d.line((cx, rim_y - 16, cx, rim_y + 4), fill=OUTLINE, width=5)
        d.ellipse((cx - 11, rim_y - 2, cx + 11, rim_y + 20), fill=(96, 78, 52, 255))
        d.ellipse((cx - 11, rim_y - 2, cx + 11, rim_y + 20), outline=OUTLINE, width=3)
        d.ellipse((cx - 6, rim_y + 2, cx - 1, rim_y + 7), fill=(196, 160, 92, 255))

    img.alpha_composite(soft_layer(img.size, dome_light, 2.4))
    img.alpha_composite(soft_layer(img.size, clapper, 0.6))
    img.save(path)
    print("summoners_bell -> handle, dome light, clapper")


if __name__ == "__main__":
    fix_old_codex()
    fix_ink_candle()
    fix_summoners_bell()
