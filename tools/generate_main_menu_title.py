"""Generate FantasyDisk main-menu title wordmark.

Output:
- assets/sprites/ui/main_menu_title.png

Horizontal wordmark "Fantasy Disk": purple/gold rift-disk emblem on the left,
golden Luminari title text to the right, soft glow, transparent background.
Style mirrors tools/generate_steam_logo.py (the canonical wordmark).

Target: transparent PNG ~720x300, no rectangular background, placed top-left
above the main-menu action block.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "ui"

FONT_TITLE = Path("/System/Library/Fonts/Supplemental/Luminari.ttf")
FONT_BACKUP = Path("/System/Library/Fonts/Supplemental/Copperplate.ttc")
FONT_BACKUP2 = Path("/System/Library/Fonts/Supplemental/Trattatello.ttf")

SCALE = 4
W, H = 720, 300


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    return (
        int(hex_color[0:2], 16),
        int(hex_color[2:4], 16),
        int(hex_color[4:6], 16),
        alpha,
    )


def new_layer() -> Image.Image:
    return Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))


def downsample(img: Image.Image) -> Image.Image:
    return img.resize((W, H), Image.Resampling.LANCZOS)


def pick_font() -> Path:
    if FONT_TITLE.exists():
        return FONT_TITLE
    if FONT_BACKUP.exists():
        return FONT_BACKUP
    return FONT_BACKUP2


def draw_disk(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    # Dark outer bite silhouette + concentric gold/purple rings.
    draw.ellipse((cx - r - 26, cy - r - 26, cx + r + 26, cy + r + 26), fill=rgba("#05040a", 238))
    draw.ellipse((cx - r - 14, cy - r - 14, cx + r + 14, cy + r + 14), fill=rgba("#7d421e", 255))
    draw.ellipse((cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2), fill=rgba("#f0b64a", 255))
    draw.ellipse((cx - r + 16, cy - r + 16, cx + r - 16, cy + r - 16), fill=rgba("#241226", 255))
    draw.ellipse((cx - r + 40, cy - r + 40, cx + r - 40, cy + r - 40), fill=rgba("#b76d2a", 255))
    draw.ellipse((cx - r + 56, cy - r + 56, cx + r - 56, cy + r - 56), fill=rgba("#2a102b", 255))

    # Star blade frame.
    pts_outer = []
    pts_inner = []
    for i in range(16):
        ang = -math.pi / 2 + math.tau * i / 16
        rad = r - 22 if i % 2 == 0 else r * 0.46
        pts_outer.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    draw.polygon(pts_outer, fill=rgba("#d7d0c3", 250))
    for i in range(16):
        ang = -math.pi / 2 + math.tau * i / 16
        rad = r - 50 if i % 2 == 0 else r * 0.36
        pts_inner.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    draw.polygon(pts_inner, fill=rgba("#171018", 255))

    # Rift gem.
    rr = int(r * 0.42)
    draw.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=rgba("#08030d", 255))
    draw.ellipse((cx - rr + 14, cy - rr + 14, cx + rr - 14, cy + rr - 14), fill=rgba("#6120bd", 255))
    draw.ellipse((cx - rr + 36, cy - rr + 36, cx + rr - 36, cy + rr - 36), fill=rgba("#16051f", 255))
    crack = [
        (cx - 16, cy - rr + 22),
        (cx + 22, cy - 44),
        (cx - 3, cy - 6),
        (cx + 38, cy + 32),
        (cx + 6, cy + rr - 20),
    ]
    draw.line(crack, fill=rgba("#f2b8ff", 235), width=8 * SCALE, joint="curve")
    draw.line([(x + 4 * SCALE, y) for x, y in crack], fill=rgba("#9d3bff", 210), width=13 * SCALE, joint="curve")
    draw.ellipse((cx - 18 * SCALE, cy - 18 * SCALE, cx + 18 * SCALE, cy + 18 * SCALE), fill=rgba("#05020a", 245))
    draw.ellipse((cx - 7 * SCALE, cy - 7 * SCALE, cx + 7 * SCALE, cy + 7 * SCALE), fill=rgba("#ffeaff", 255))


def add_text_gradient(base: Image.Image, mask: Image.Image, top: str, mid: str, bottom: str) -> None:
    grad = Image.new("RGBA", base.size, (0, 0, 0, 0))
    pix = grad.load()
    h = grad.height
    top_rgb = rgba(top)
    mid_rgb = rgba(mid)
    bot_rgb = rgba(bottom)
    for y in range(h):
        t = y / max(h - 1, 1)
        if t < 0.48:
            k = t / 0.48
            col = tuple(int(top_rgb[i] * (1 - k) + mid_rgb[i] * k) for i in range(3)) + (255,)
        else:
            k = (t - 0.48) / 0.52
            col = tuple(int(mid_rgb[i] * (1 - k) + bot_rgb[i] * k) for i in range(3)) + (255,)
        for x in range(grad.width):
            pix[x, y] = col
    base.alpha_composite(Image.composite(grad, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))


def draw_title(text_x: int, cy: int) -> Image.Image:
    img = new_layer()
    text = "Fantasy Disk"
    font_path = pick_font()
    # Fit the wordmark into the available width to the right of the emblem.
    avail = (W * SCALE) - text_x - 24 * SCALE
    font_size = 132 * SCALE
    while font_size > 60 * SCALE:
        font = ImageFont.truetype(str(font_path), font_size)
        bbox = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox((0, 0), text, font=font, stroke_width=0)
        if bbox[2] - bbox[0] <= avail:
            break
        font_size -= 3 * SCALE
    font = ImageFont.truetype(str(font_path), font_size)
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), text, font=font, stroke_width=0)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = text_x
    y = int(cy - th / 2) - bbox[1]

    # Deep drop shadow / dark outline for readability over the menu background.
    draw.text((x + 7 * SCALE, y + 11 * SCALE), text, font=font, fill=rgba("#05030a", 230), stroke_width=8 * SCALE, stroke_fill=rgba("#05030a", 230))

    # Soft purple bloom behind the text.
    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.text((x, y), text, font=font, fill=rgba("#8f46ff", 110), stroke_width=8 * SCALE, stroke_fill=rgba("#8f46ff", 110))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8 * SCALE)))

    # Dark brown stroke.
    stroke = new_layer()
    sd = ImageDraw.Draw(stroke)
    sd.text((x, y), text, font=font, fill=rgba("#21110b", 255), stroke_width=7 * SCALE, stroke_fill=rgba("#21110b", 255))
    img.alpha_composite(stroke)

    # Gold gradient fill.
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.text((x, y), text, font=font, fill=255)
    add_text_gradient(img, mask, "#fff5bd", "#d99a35", "#6d2c19")

    # Bevel highlight clipped to the glyphs.
    hi = new_layer()
    hd = ImageDraw.Draw(hi)
    hd.text((x - 2 * SCALE, y - 4 * SCALE), text, font=font, fill=rgba("#fff8da", 150))
    hi.putalpha(Image.composite(hi.getchannel("A"), Image.new("L", img.size, 0), mask))
    img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(0.5 * SCALE)))

    # Underline flourish.
    draw = ImageDraw.Draw(img)
    uy = y + th + 6 * SCALE
    draw.line((x + 6 * SCALE, uy, x + tw - 8 * SCALE, uy), fill=rgba("#27120c", 180), width=4 * SCALE)
    draw.line((x + 12 * SCALE, uy + 5 * SCALE, x + tw - 18 * SCALE, uy + 5 * SCALE), fill=rgba("#d49a3d", 200), width=2 * SCALE)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    logo = new_layer()

    cx = 140 * SCALE
    cy = 150 * SCALE
    r = 108 * SCALE

    # Soft purple/gold bloom behind the transparent logo.
    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.ellipse((cx - r - 30, cy - r - 30, cx + r + 30, cy + r + 30), fill=rgba("#8f46ff", 80))
    gd.ellipse((cx + r, cy - 90 * SCALE, (W - 30) * SCALE, cy + 90 * SCALE), fill=rgba("#f0a940", 40))
    logo.alpha_composite(glow.filter(ImageFilter.GaussianBlur(30 * SCALE)))

    disk_layer = new_layer()
    draw_disk(ImageDraw.Draw(disk_layer), cx, cy, r)
    # Painterly drop shadow for the emblem.
    shadow = disk_layer.copy()
    shadow_alpha = shadow.getchannel("A").filter(ImageFilter.GaussianBlur(12 * SCALE))
    shadow.putalpha(shadow_alpha.point(lambda a: int(a * 0.55)))
    shadow_colored = Image.new("RGBA", shadow.size, rgba("#030209", 255))
    shadow_colored.putalpha(shadow.getchannel("A"))
    logo.alpha_composite(shadow_colored, (8 * SCALE, 14 * SCALE))
    logo.alpha_composite(disk_layer)

    # Title text to the right of the emblem, vertically centered on it.
    text_x = cx + r + 26 * SCALE
    logo.alpha_composite(draw_title(text_x, cy))

    final = downsample(logo)
    final.save(OUT / "main_menu_title.png")
    print(OUT / "main_menu_title.png")
    print(f"size={final.size} mode={final.mode}")


if __name__ == "__main__":
    main()
