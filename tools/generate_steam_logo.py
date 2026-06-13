"""Generate FantasyDisk Steam library logo art.

Output:
- assets/marketing/steam/fantasydisk_steam_library_logo.png
- assets/marketing/steam/fantasydisk_steam_library_logo_preview.png

Steam library logo target: transparent PNG, 1280x720, no extra text.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "marketing" / "steam"

FONT_TITLE = Path("/System/Library/Fonts/Supplemental/Luminari.ttf")
FONT_BACKUP = Path("/System/Library/Fonts/Supplemental/Copperplate.ttc")

SCALE = 3
W, H = 1280, 720


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


def draw_disk(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    # Dark outer bite silhouette.
    draw.ellipse((cx - r - 34, cy - r - 34, cx + r + 34, cy + r + 34), fill=rgba("#05040a", 238))
    draw.ellipse((cx - r - 18, cy - r - 18, cx + r + 18, cy + r + 18), fill=rgba("#7d421e", 255))
    draw.ellipse((cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2), fill=rgba("#f0b64a", 255))
    draw.ellipse((cx - r + 22, cy - r + 22, cx + r - 22, cy + r - 22), fill=rgba("#241226", 255))
    draw.ellipse((cx - r + 54, cy - r + 54, cx + r - 54, cy + r - 54), fill=rgba("#b76d2a", 255))
    draw.ellipse((cx - r + 76, cy - r + 76, cx + r - 76, cy + r - 76), fill=rgba("#2a102b", 255))

    # Star blade frame.
    pts_outer = []
    pts_inner = []
    for i in range(16):
        ang = -math.pi / 2 + math.tau * i / 16
        rad = r - 30 if i % 2 == 0 else r * 0.46
        pts_outer.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    draw.polygon(pts_outer, fill=rgba("#d7d0c3", 250))
    for i in range(16):
        ang = -math.pi / 2 + math.tau * i / 16
        rad = r - 68 if i % 2 == 0 else r * 0.36
        pts_inner.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    draw.polygon(pts_inner, fill=rgba("#171018", 255))

    # Rift gem.
    rr = int(r * 0.42)
    draw.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=rgba("#08030d", 255))
    draw.ellipse((cx - rr + 18, cy - rr + 18, cx + rr - 18, cy + rr - 18), fill=rgba("#6120bd", 255))
    draw.ellipse((cx - rr + 48, cy - rr + 48, cx + rr - 48, cy + rr - 48), fill=rgba("#16051f", 255))
    crack = [
        (cx - 20, cy - rr + 30),
        (cx + 30, cy - 60),
        (cx - 4, cy - 8),
        (cx + 50, cy + 44),
        (cx + 8, cy + rr - 28),
    ]
    draw.line(crack, fill=rgba("#f2b8ff", 235), width=11 * SCALE, joint="curve")
    draw.line([(x + 6 * SCALE, y) for x, y in crack], fill=rgba("#9d3bff", 210), width=18 * SCALE, joint="curve")
    draw.ellipse((cx - 24 * SCALE, cy - 24 * SCALE, cx + 24 * SCALE, cy + 24 * SCALE), fill=rgba("#05020a", 245))
    draw.ellipse((cx - 9 * SCALE, cy - 9 * SCALE, cx + 9 * SCALE, cy + 9 * SCALE), fill=rgba("#ffeaff", 255))


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


def draw_title() -> Image.Image:
    img = new_layer()
    text = "FantasyDisk"
    font_path = FONT_TITLE if FONT_TITLE.exists() else FONT_BACKUP
    font_size = 170 * SCALE
    while font_size > 80 * SCALE:
        font = ImageFont.truetype(str(font_path), font_size)
        bbox = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox((0, 0), text, font=font, stroke_width=0)
        if bbox[2] - bbox[0] <= 800 * SCALE:
            break
        font_size -= 4 * SCALE
    font = ImageFont.truetype(str(font_path), font_size)
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), text, font=font, stroke_width=0)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = 390 * SCALE
    y = int((H * SCALE - th) * 0.46) - bbox[1]

    # Large readable fantasy outline.
    draw.text((x + 10 * SCALE, y + 16 * SCALE), text, font=font, fill=rgba("#05030a", 230), stroke_width=10 * SCALE, stroke_fill=rgba("#05030a", 230))
    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.text((x, y), text, font=font, fill=rgba("#8f46ff", 115), stroke_width=10 * SCALE, stroke_fill=rgba("#8f46ff", 115))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10 * SCALE)))

    # Stroke mask and fill mask.
    stroke = new_layer()
    sd = ImageDraw.Draw(stroke)
    sd.text((x, y), text, font=font, fill=rgba("#21110b", 255), stroke_width=9 * SCALE, stroke_fill=rgba("#21110b", 255))
    img.alpha_composite(stroke)

    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.text((x, y), text, font=font, fill=255)
    add_text_gradient(img, mask, "#fff5bd", "#d99a35", "#6d2c19")

    # Bevel highlights and cuts.
    hi = new_layer()
    hd = ImageDraw.Draw(hi)
    hd.text((x - 2 * SCALE, y - 5 * SCALE), text, font=font, fill=rgba("#fff8da", 145))
    hi.putalpha(Image.composite(hi.getchannel("A"), Image.new("L", img.size, 0), mask))
    img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(0.5 * SCALE)))
    draw = ImageDraw.Draw(img)
    draw.line((x + 18 * SCALE, y + th * 0.86, x + tw - 26 * SCALE, y + th * 0.86), fill=rgba("#27120c", 180), width=5 * SCALE)
    draw.line((x + 24 * SCALE, y + th * 0.91, x + tw - 42 * SCALE, y + th * 0.91), fill=rgba("#d49a3d", 200), width=2 * SCALE)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    logo = new_layer()

    # Soft purple/gold bloom behind the transparent logo.
    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.ellipse((70 * SCALE, 185 * SCALE, 470 * SCALE, 585 * SCALE), fill=rgba("#8f46ff", 76))
    gd.ellipse((300 * SCALE, 190 * SCALE, 1160 * SCALE, 570 * SCALE), fill=rgba("#f0a940", 40))
    logo.alpha_composite(glow.filter(ImageFilter.GaussianBlur(38 * SCALE)))

    disk_layer = new_layer()
    draw_disk(ImageDraw.Draw(disk_layer), 270 * SCALE, 360 * SCALE, 165 * SCALE)
    # Painterly drop shadow for the emblem.
    shadow = disk_layer.copy()
    shadow_alpha = shadow.getchannel("A").filter(ImageFilter.GaussianBlur(16 * SCALE))
    shadow.putalpha(shadow_alpha.point(lambda a: int(a * 0.55)))
    shadow_colored = Image.new("RGBA", shadow.size, rgba("#030209", 255))
    shadow_colored.putalpha(shadow.getchannel("A"))
    logo.alpha_composite(shadow_colored, (10 * SCALE, 18 * SCALE))
    logo.alpha_composite(disk_layer)

    logo.alpha_composite(draw_title())

    final = downsample(logo)
    final.save(OUT / "fantasydisk_steam_library_logo.png")

    # Preview on a dark fantasy backdrop so transparent edges are visible.
    preview = Image.new("RGBA", (W, H), rgba("#140f1a", 255))
    pd = ImageDraw.Draw(preview)
    for i in range(0, W, 80):
        pd.line((i, 0, i - 220, H), fill=rgba("#24162f", 120), width=2)
    preview.alpha_composite(final)
    preview.save(OUT / "fantasydisk_steam_library_logo_preview.png")
    print(OUT / "fantasydisk_steam_library_logo.png")
    print(OUT / "fantasydisk_steam_library_logo_preview.png")


if __name__ == "__main__":
    main()
