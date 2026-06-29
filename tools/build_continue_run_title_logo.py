"""Generate FantasyDisk "Продолжить забег?" dialog title wordmark.

Output:
- assets/sprites/ui/menu_title/continue_run_title.png

Stylized Cyrillic title text "Продолжить забег?" in the same visual family as
the main-menu wordmark (tools/build_main_menu_title_logo.py): golden gradient
fill (#f0b64a -> #b76d2a), dark-brown stroke (#21110b), deep drop shadow
(#05030a), soft glow, thin golden underline flourish. Transparent background,
no rectangular plate. Luminari (supports Cyrillic) to match the menu logo.

Target: transparent PNG ~760x170, alpha_min == 0 (asserted).
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "ui" / "menu_title"
ASSET_NAME = "continue_run_title.png"

FONT_TITLE = Path("/System/Library/Fonts/Supplemental/Luminari.ttf")
FONT_BACKUP = Path("/System/Library/Fonts/Supplemental/Trattatello.ttf")

SCALE = 4
W, H = 760, 170
TEXT = "Продолжить забег?"


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
    return FONT_BACKUP


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
    font_path = pick_font()
    avail = (W * SCALE) - 56 * SCALE  # horizontal padding so stroke/glow fit
    font_size = 88 * SCALE
    while font_size > 30 * SCALE:
        font = ImageFont.truetype(str(font_path), font_size)
        bbox = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox((0, 0), TEXT, font=font, stroke_width=0)
        if bbox[2] - bbox[0] <= avail:
            break
        font_size -= 2 * SCALE
    font = ImageFont.truetype(str(font_path), font_size)

    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), TEXT, font=font, stroke_width=0)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    cx = W * SCALE // 2
    cy = H * SCALE // 2
    x = int(cx - tw / 2) - bbox[0]
    y = int(cy - th / 2) - bbox[1] - 6 * SCALE  # lift slightly to leave room for underline

    # Deep drop shadow / dark outline for readability over the panel.
    draw.text(
        (x + 5 * SCALE, y + 8 * SCALE), TEXT, font=font,
        fill=rgba("#05030a", 230), stroke_width=6 * SCALE, stroke_fill=rgba("#05030a", 230),
    )

    # Soft warm bloom behind the text.
    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.text((x, y), TEXT, font=font, fill=rgba("#f0a940", 90), stroke_width=6 * SCALE, stroke_fill=rgba("#f0a940", 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(7 * SCALE)))

    # Dark brown stroke.
    stroke = new_layer()
    sd = ImageDraw.Draw(stroke)
    sd.text((x, y), TEXT, font=font, fill=rgba("#21110b", 255), stroke_width=5 * SCALE, stroke_fill=rgba("#21110b", 255))
    img.alpha_composite(stroke)

    # Gold gradient fill.
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.text((x, y), TEXT, font=font, fill=255)
    add_text_gradient(img, mask, "#f6c660", "#f0b64a", "#b76d2a")

    # Bevel highlight clipped to the glyphs.
    hi = new_layer()
    hd = ImageDraw.Draw(hi)
    hd.text((x - 2 * SCALE, y - 3 * SCALE), TEXT, font=font, fill=rgba("#fff3cf", 140))
    hi.putalpha(Image.composite(hi.getchannel("A"), Image.new("L", img.size, 0), mask))
    img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(0.5 * SCALE)))

    # Underline flourish, golden, centered under the text.
    draw = ImageDraw.Draw(img)
    uy = y + th + 10 * SCALE
    ux0 = int(cx - tw / 2) + 6 * SCALE
    ux1 = int(cx + tw / 2) - 6 * SCALE
    draw.line((ux0, uy, ux1, uy), fill=rgba("#27120c", 180), width=4 * SCALE)
    draw.line((ux0 + 8 * SCALE, uy + 5 * SCALE, ux1 - 8 * SCALE, uy + 5 * SCALE), fill=rgba("#d49a3d", 200), width=2 * SCALE)
    return img


def main() -> None:
    check_only = "--check-only" in sys.argv[1:]
    logo = draw_title()
    final = downsample(logo)

    alpha = final.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    assert alpha_min == 0, f"expected transparent background (alpha_min==0), got {alpha_min}"
    assert alpha_max > 0, "image is fully transparent"

    if check_only:
        target = OUT / ASSET_NAME
        ok = target.exists()
        print(f"[check-only] no write. target={target} exists={ok} "
              f"size={final.size} mode={final.mode} alpha_min={alpha_min} alpha_max={alpha_max}")
        sys.exit(0 if ok else 1)

    OUT.mkdir(parents=True, exist_ok=True)
    final.save(OUT / ASSET_NAME)
    print(OUT / ASSET_NAME)
    print(f"size={final.size} mode={final.mode} alpha_min={alpha_min} alpha_max={alpha_max}")


if __name__ == "__main__":
    main()
