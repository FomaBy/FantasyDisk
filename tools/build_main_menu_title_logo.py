"""Build the FantasyDisk main-menu title logo.

Output:
- assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png

The visual base is the PixelLab-generated, textless dark-fantasy title crest
recorded in docs/design/references/main_menu_logo_release_fix/. The exact
"Fantasy Disk" lettering is rendered locally so the in-game title remains
readable and typo-free.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "ui" / "menu_title"
ASSET_NAME = "main_menu_title_fantasy_disk.png"
SOURCE_ART = ROOT / "docs" / "design" / "references" / "main_menu_logo_release_fix" / "pixellab_logo_art_source.png"

FONT_TITLE = Path("/System/Library/Fonts/Supplemental/Luminari.ttf")
FONT_BACKUP = Path("/System/Library/Fonts/Supplemental/Copperplate.ttc")
FONT_BACKUP2 = Path("/System/Library/Fonts/Supplemental/Trattatello.ttf")

SCALE = 4
W, H = 960, 360
TITLE_TEXT = "Fantasy Disk"
TITLE_ZONE = (318, 82, 602, 154)


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


def add_text_gradient(base: Image.Image, mask: Image.Image, top: str, mid: str, bottom: str) -> None:
    grad = Image.new("RGBA", base.size, (0, 0, 0, 0))
    pix = grad.load()
    h = grad.height
    top_rgb = rgba(top)
    mid_rgb = rgba(mid)
    bot_rgb = rgba(bottom)
    for y in range(h):
        t = y / max(h - 1, 1)
        if t < 0.46:
            k = t / 0.46
            col = tuple(int(top_rgb[i] * (1 - k) + mid_rgb[i] * k) for i in range(3)) + (255,)
        else:
            k = (t - 0.46) / 0.54
            col = tuple(int(mid_rgb[i] * (1 - k) + bot_rgb[i] * k) for i in range(3)) + (255,)
        for x in range(grad.width):
            pix[x, y] = col
    base.alpha_composite(Image.composite(grad, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))


def fit_font(draw: ImageDraw.ImageDraw, font_path: Path, text: str, zone_w: int, zone_h: int) -> ImageFont.FreeTypeFont:
    font_size = 124 * SCALE
    min_size = 64 * SCALE
    while font_size >= min_size:
        font = ImageFont.truetype(str(font_path), font_size)
        bbox = draw.textbbox((0, 0), text, font=font, stroke_width=0)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        if tw <= zone_w and th <= zone_h:
            return font
        font_size -= 2 * SCALE
    return ImageFont.truetype(str(font_path), min_size)


def draw_title(base: Image.Image) -> None:
    zone = tuple(int(v * SCALE) for v in TITLE_ZONE)
    zx, zy, zw, zh = zone
    text_layer = new_layer()
    draw = ImageDraw.Draw(text_layer)
    font = fit_font(draw, pick_font(), TITLE_TEXT, zw - 36 * SCALE, zh - 8 * SCALE)
    bbox = draw.textbbox((0, 0), TITLE_TEXT, font=font, stroke_width=0)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = int(zx + (zw - tw) * 0.5) - bbox[0]
    y = int(zy + (zh - th) * 0.5) - bbox[1] - 3 * SCALE

    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.text(
        (x, y),
        TITLE_TEXT,
        font=font,
        fill=rgba("#7A36FF", 95),
        stroke_width=9 * SCALE,
        stroke_fill=rgba("#7A36FF", 95),
    )
    text_layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10 * SCALE)))

    shadow = new_layer()
    sd = ImageDraw.Draw(shadow)
    sd.text(
        (x + 7 * SCALE, y + 10 * SCALE),
        TITLE_TEXT,
        font=font,
        fill=rgba("#030106", 235),
        stroke_width=9 * SCALE,
        stroke_fill=rgba("#030106", 235),
    )
    text_layer.alpha_composite(shadow)

    stroke = new_layer()
    st = ImageDraw.Draw(stroke)
    st.text(
        (x, y),
        TITLE_TEXT,
        font=font,
        fill=rgba("#1A0908", 255),
        stroke_width=7 * SCALE,
        stroke_fill=rgba("#1A0908", 255),
    )
    text_layer.alpha_composite(stroke)

    mask = Image.new("L", text_layer.size, 0)
    md = ImageDraw.Draw(mask)
    md.text((x, y), TITLE_TEXT, font=font, fill=255)
    add_text_gradient(text_layer, mask, "#FFF1B8", "#DCA046", "#6E2D18")

    highlight = new_layer()
    hd = ImageDraw.Draw(highlight)
    hd.text((x - 2 * SCALE, y - 4 * SCALE), TITLE_TEXT, font=font, fill=rgba("#FFF8DB", 150))
    highlight.putalpha(Image.composite(highlight.getchannel("A"), Image.new("L", highlight.size, 0), mask))
    text_layer.alpha_composite(highlight.filter(ImageFilter.GaussianBlur(0.5 * SCALE)))

    underline = ImageDraw.Draw(text_layer)
    uy = y + th + 9 * SCALE
    ux0 = int(zx + 28 * SCALE)
    ux1 = int(zx + zw - 28 * SCALE)
    underline.line((ux0, uy, ux1, uy), fill=rgba("#050108", 210), width=4 * SCALE)
    underline.line((ux0 + 10 * SCALE, uy + 5 * SCALE, ux1 - 10 * SCALE, uy + 5 * SCALE), fill=rgba("#D49A3D", 205), width=2 * SCALE)

    base.alpha_composite(text_layer)


def load_pixellab_art() -> Image.Image:
    if not SOURCE_ART.exists():
        raise FileNotFoundError(f"PixelLab source art is missing: {SOURCE_ART}")
    art = Image.open(SOURCE_ART).convert("RGBA")
    art = ImageOps.mirror(art)
    target_h = 340 * SCALE
    target_w = round(art.width * (target_h / art.height))
    art = art.resize((target_w, target_h), Image.Resampling.LANCZOS)
    pix = art.load()
    for y in range(art.height):
        for x in range(art.width):
            r, g, b, a = pix[x, y]
            if 0 < a < 170:
                pix[x, y] = (
                    int(r * 0.58),
                    int(g * 0.48),
                    int(b * 0.62),
                    int(a * 0.72),
                )
    return art


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    logo = new_layer()
    art = load_pixellab_art()
    art_x = 34 * SCALE
    art_y = 8 * SCALE

    shadow_alpha = art.getchannel("A").filter(ImageFilter.GaussianBlur(12 * SCALE))
    shadow = Image.new("RGBA", art.size, rgba("#020106", 255))
    shadow.putalpha(shadow_alpha.point(lambda a: int(a * 0.62)))
    logo.alpha_composite(shadow, (art_x + 7 * SCALE, art_y + 12 * SCALE))

    bloom = Image.new("RGBA", art.size, rgba("#7A36FF", 255))
    bloom.putalpha(art.getchannel("A").filter(ImageFilter.GaussianBlur(18 * SCALE)).point(lambda a: int(a * 0.08)))
    logo.alpha_composite(bloom, (art_x, art_y))
    logo.alpha_composite(art, (art_x, art_y))

    draw_title(logo)

    final = downsample(logo)
    alpha = final.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    if alpha_min != 0:
        raise AssertionError(f"expected transparent background (alpha_min == 0), got {alpha_min}")
    if alpha_max == 0:
        raise AssertionError("logo is fully transparent")

    final.save(OUT / ASSET_NAME)
    print(OUT / ASSET_NAME)
    print(f"size={final.size} mode={final.mode} alpha_min={alpha_min} alpha_max={alpha_max}")


if __name__ == "__main__":
    main()
