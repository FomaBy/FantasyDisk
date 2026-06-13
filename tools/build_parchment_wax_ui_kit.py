#!/usr/bin/env python3
"""Historical full-frame SCRUM-147 parchment/wax builder.

Superseded by direct user feedback on 2026-06-13: only buttons should use the
Parchment & Wax Seal reference; panels/cards/HUD/tooltips/shop frames should use
the old interface style. Run `tools/apply_button_only_ui_revert.py` for the
current accepted pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
BUTTON_REF = ROOT / "docs/design/references/ui_dark_fantasy_2026_06/button_parchment_wax_seal.png"
PARCHMENT_SCREEN = ROOT / "docs/design/ui_parchment_kit/ChatGPT Image Jun 13, 2026, 07_06_19 PM (4).png"
PREVIEW_DIR = ROOT / "docs/design/previews"
DARK_DIR = ROOT / "assets/sprites/ui/frames/dark_fantasy"
GLOBAL_DIR = ROOT / "assets/sprites/ui/frames/global"
ESCAPE_DIR = ROOT / "assets/sprites/ui/frames/escape"
SHOP_DIR = ROOT / "assets/sprites/ui/shop"


BUTTON_STATE_BOXES = {
    "idle": (188, 178, 1118, 410),
    "hover": (188, 446, 1118, 678),
    "pressed": (188, 707, 1118, 932),
    "disabled": (188, 957, 1118, 1184),
}


@dataclass(frozen=True)
class SliceMargins:
    left: int
    top: int
    right: int
    bottom: int


def ensure_dirs() -> None:
    for directory in (PREVIEW_DIR, DARK_DIR, GLOBAL_DIR, ESCAPE_DIR, SHOP_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def median(values: list[int]) -> int:
    values.sort()
    return values[len(values) // 2]


def sampled_background(im: Image.Image) -> tuple[int, int, int]:
    rgb = im.convert("RGB")
    w, h = rgb.size
    samples: list[tuple[int, int, int]] = []
    for x in range(0, w, max(1, w // 90)):
        for y in (*range(0, min(14, h), 3), *range(max(0, h - 14), h, 3)):
            samples.append(rgb.getpixel((x, y)))
    for y in range(0, h, max(1, h // 45)):
        for x in (*range(0, min(14, w), 3), *range(max(0, w - 14), w, 3)):
            samples.append(rgb.getpixel((x, y)))
    return tuple(median([sample[channel] for sample in samples]) for channel in range(3))


def matte_dark_reference_bg(im: Image.Image) -> Image.Image:
    """Remove the dark reference sheet background while preserving button shadows."""

    rgb = im.convert("RGB")
    bg = sampled_background(rgb)
    w, h = rgb.size
    mask = Image.new("L", (w, h), 0)
    pixels = rgb.load()
    alpha = mask.load()

    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            mx = max(r, g, b)
            mn = min(r, g, b)
            diff = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            sat = mx - mn
            value = max((diff - 8) * 11, (mx - 26) * 5, (sat - 10) * 4)
            if value <= 0:
                alpha[x, y] = 0
            elif value >= 255:
                alpha[x, y] = 255
            else:
                alpha[x, y] = int(value)

    hard = mask.point(lambda p: 255 if p > 55 else 0)
    hard = hard.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(5))
    soft = mask.filter(ImageFilter.GaussianBlur(1.15))
    combined = ImageChops.lighter(hard, soft)

    out = im.convert("RGBA")
    out.putalpha(combined)
    return out


def nine_slice(src: Image.Image, size: tuple[int, int], src_m: SliceMargins, out_m: SliceMargins) -> Image.Image:
    """Resize a texture using explicit 9-slice margins."""

    src = src.convert("RGBA")
    sw, sh = src.size
    ow, oh = size

    left = min(out_m.left, max(1, ow // 2 - 1))
    right = min(out_m.right, max(1, ow - left - 1))
    top = min(out_m.top, max(1, oh // 2 - 1))
    bottom = min(out_m.bottom, max(1, oh - top - 1))
    out_m = SliceMargins(left, top, right, bottom)

    out = Image.new("RGBA", size, (0, 0, 0, 0))

    x_src = [0, src_m.left, sw - src_m.right, sw]
    y_src = [0, src_m.top, sh - src_m.bottom, sh]
    x_dst = [0, out_m.left, ow - out_m.right, ow]
    y_dst = [0, out_m.top, oh - out_m.bottom, oh]

    for row in range(3):
        for col in range(3):
            box = (x_src[col], y_src[row], x_src[col + 1], y_src[row + 1])
            dst_box = (x_dst[col], y_dst[row], x_dst[col + 1], y_dst[row + 1])
            dw = max(1, dst_box[2] - dst_box[0])
            dh = max(1, dst_box[3] - dst_box[1])
            piece = src.crop(box).resize((dw, dh), Image.Resampling.LANCZOS)
            out.alpha_composite(piece, (dst_box[0], dst_box[1]))
    return out


def fit_on_canvas(src: Image.Image, size: tuple[int, int], scale: float = 1.0) -> Image.Image:
    ow, oh = size
    max_w = max(1, int(ow * scale))
    max_h = max(1, int(oh * scale))
    sw, sh = src.size
    ratio = min(max_w / sw, max_h / sh)
    resized = src.resize((max(1, int(sw * ratio)), max(1, int(sh * ratio))), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(resized, ((ow - resized.width) // 2, (oh - resized.height) // 2))
    return out


def button_output_margins(size: tuple[int, int]) -> SliceMargins:
    w, h = size
    left = min(int(h * 1.18), int(w * 0.38))
    right = min(int(h * 0.92), int(w * 0.31))
    top = max(10, int(h * 0.28))
    bottom = max(10, int(h * 0.28))
    return SliceMargins(left, top, right, bottom)


def build_button_states(button_ref: Image.Image) -> dict[str, Image.Image]:
    states: dict[str, Image.Image] = {}
    for state, box in BUTTON_STATE_BOXES.items():
        crop = button_ref.crop(box)
        states[state] = matte_dark_reference_bg(crop)
    return states


def render_button(states: dict[str, Image.Image], state: str, size: tuple[int, int]) -> Image.Image:
    src = states[state]
    return nine_slice(
        src,
        size,
        SliceMargins(left=255, top=58, right=190, bottom=58),
        button_output_margins(size),
    )


def tile_texture(texture: Image.Image, size: tuple[int, int]) -> Image.Image:
    texture = texture.convert("RGBA")
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    for y in range(0, size[1], texture.height):
        for x in range(0, size[0], texture.width):
            out.alpha_composite(texture, (x, y))
    return out.crop((0, 0, size[0], size[1]))


def tint(im: Image.Image, color: tuple[int, int, int], opacity: int) -> Image.Image:
    overlay = Image.new("RGBA", im.size, (*color, opacity))
    return Image.alpha_composite(im.convert("RGBA"), overlay)


def parchment_texture(button_ref: Image.Image, size: tuple[int, int]) -> Image.Image:
    patch = button_ref.crop((420, 226, 970, 350)).convert("RGBA")
    patch = patch.filter(ImageFilter.GaussianBlur(0.2))
    tex = patch.resize(size, Image.Resampling.BICUBIC)
    detail = button_ref.crop((530, 238, 910, 342)).convert("RGBA")
    detail = detail.resize(size, Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(0.55))
    tex = Image.blend(tex, detail, 0.24)
    tex = ImageEnhance.Contrast(tex).enhance(1.08)
    tex = ImageEnhance.Color(tex).enhance(0.92)
    vignette = Image.new("L", size, 0)
    draw = ImageDraw.Draw(vignette)
    max_inset = max(1, min(42, size[0] // 2 - 1, size[1] // 2 - 1))
    for i in range(max_inset):
        alpha = int(4 + i * 2.8)
        draw.rectangle((i, i, size[0] - 1 - i, size[1] - 1 - i), outline=alpha)
    dark = Image.new("RGBA", size, (50, 24, 10, 0))
    dark.putalpha(vignette.filter(ImageFilter.GaussianBlur(8)))
    return Image.alpha_composite(tex, dark)


def dark_stone_texture(screen_ref: Image.Image, size: tuple[int, int]) -> Image.Image:
    patch = screen_ref.crop((520, 105, 980, 174)).convert("RGBA").filter(ImageFilter.GaussianBlur(1.2))
    tex = tile_texture(patch, size)
    tex = ImageEnhance.Brightness(tex).enhance(0.75)
    tex = ImageEnhance.Contrast(tex).enhance(1.2)
    return tex


def alpha_shadow(size: tuple[int, int], inset: int, radius: int, opacity: int = 160) -> Image.Image:
    w, h = size
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((inset, inset, w - inset - 1, h - inset - 1), radius=radius, fill=opacity)
    mask = mask.filter(ImageFilter.GaussianBlur(max(3, inset // 2)))
    shadow.putalpha(mask)
    return shadow


def crop_rgba(src: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return src.crop(box).convert("RGBA")


def build_panel(
    size: tuple[int, int],
    button_ref: Image.Image,
    screen_ref: Image.Image,
    *,
    heavy: bool = False,
    dark: bool = False,
    hover: bool = False,
) -> Image.Image:
    w, h = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(alpha_shadow(size, inset=max(3, min(w, h) // 34), radius=max(8, min(w, h) // 18)))

    if dark:
        body = dark_stone_texture(screen_ref, (w, h))
    else:
        body = parchment_texture(button_ref, (w, h))
    if hover:
        body = ImageEnhance.Brightness(body).enhance(1.08)
    out.alpha_composite(body)

    draw = ImageDraw.Draw(out)
    edge_dark = (28, 18, 14, 230)
    edge_gold = (170, 103, 40, 210)
    draw.rectangle((2, 2, w - 3, h - 3), outline=edge_dark, width=max(2, min(w, h) // 42))
    draw.rectangle((7, 7, w - 8, h - 8), outline=edge_gold, width=max(1, min(w, h) // 90))
    draw.rectangle((12, 12, w - 13, h - 13), outline=(45, 24, 15, 165), width=1)

    if heavy:
        corner_src = {
            "tl": crop_rgba(screen_ref, (7, 8, 146, 146)),
            "tr": crop_rgba(screen_ref, (1526, 8, 1665, 146)),
            "bl": crop_rgba(screen_ref, (7, 795, 146, 934)),
            "br": crop_rgba(screen_ref, (1526, 795, 1665, 934)),
        }
        corner_size = max(44, min(int(min(w, h) * 0.28), 118))
        for key, img in corner_src.items():
            piece = img.resize((corner_size, corner_size), Image.Resampling.LANCZOS)
            if key == "tl":
                out.alpha_composite(piece, (0, 0))
            elif key == "tr":
                out.alpha_composite(piece, (w - corner_size, 0))
            elif key == "bl":
                out.alpha_composite(piece, (0, h - corner_size))
            else:
                out.alpha_composite(piece, (w - corner_size, h - corner_size))

        top = crop_rgba(screen_ref, (180, 8, 1485, 36)).resize((max(1, w - corner_size * 2), max(12, corner_size // 4)), Image.Resampling.LANCZOS)
        bottom = crop_rgba(screen_ref, (180, 899, 1485, 930)).resize((max(1, w - corner_size * 2), max(12, corner_size // 4)), Image.Resampling.LANCZOS)
        left = crop_rgba(screen_ref, (8, 160, 38, 790)).resize((max(12, corner_size // 4), max(1, h - corner_size * 2)), Image.Resampling.LANCZOS)
        right = crop_rgba(screen_ref, (1630, 160, 1662, 790)).resize((max(12, corner_size // 4), max(1, h - corner_size * 2)), Image.Resampling.LANCZOS)
        out.alpha_composite(top, (corner_size, 0))
        out.alpha_composite(bottom, (corner_size, h - bottom.height))
        out.alpha_composite(left, (0, corner_size))
        out.alpha_composite(right, (w - right.width, corner_size))

        if w >= 220 and h >= 120:
            gem = crop_rgba(screen_ref, (764, 26, 910, 82)).resize((min(138, w // 4), min(62, h // 6)), Image.Resampling.LANCZOS)
            out.alpha_composite(gem, ((w - gem.width) // 2, 0))
    else:
        # Thin real metal hardware from the approved settings screen. Use only
        # clean border/corner regions so no reference text is baked into assets.
        c = max(18, min(int(min(w, h) * 0.18), 54))
        top = crop_rgba(screen_ref, (184, 8, 1486, 34)).resize((max(1, w - c * 2), max(8, c // 3)), Image.Resampling.LANCZOS)
        bottom = crop_rgba(screen_ref, (184, 902, 1486, 930)).resize((max(1, w - c * 2), max(8, c // 3)), Image.Resampling.LANCZOS)
        left = crop_rgba(screen_ref, (8, 156, 36, 788)).resize((max(8, c // 3), max(1, h - c * 2)), Image.Resampling.LANCZOS)
        right = crop_rgba(screen_ref, (1634, 156, 1662, 788)).resize((max(8, c // 3), max(1, h - c * 2)), Image.Resampling.LANCZOS)
        out.alpha_composite(top, (c, 0))
        out.alpha_composite(bottom, (c, h - bottom.height))
        out.alpha_composite(left, (0, c))
        out.alpha_composite(right, (w - right.width, c))
        for src_box, pos in [
            ((7, 8, 146, 146), (0, 0)),
            ((1526, 8, 1665, 146), (w - c, 0)),
            ((7, 795, 146, 934), (0, h - c)),
            ((1526, 795, 1665, 934), (w - c, h - c)),
        ]:
            out.alpha_composite(crop_rgba(screen_ref, src_box).resize((c, c), Image.Resampling.LANCZOS), pos)

    # Real serrated forged-metal brackets from the fixed button reference.
    # Use the right end cap only, so panels get metal/ruby hardware without
    # repeating the wax seal reserved for buttons.
    button_idle = matte_dark_reference_bg(button_ref.crop(BUTTON_STATE_BOXES["idle"]))
    cap = button_idle.crop((700, 16, 930, 216))
    bracket_h = max(22, min(int(min(w, h) * (0.34 if heavy else 0.24)), 96))
    bracket_w = max(38, min(int(bracket_h * 1.55), max(42, w // 3)))
    bracket = cap.resize((bracket_w, bracket_h), Image.Resampling.LANCZOS)
    pieces = [
        (ImageOps.mirror(bracket), (0, 0)),
        (bracket, (w - bracket_w, 0)),
        (ImageOps.flip(ImageOps.mirror(bracket)), (0, h - bracket_h)),
        (ImageOps.flip(bracket), (w - bracket_w, h - bracket_h)),
    ]
    for piece, pos in pieces:
        out.alpha_composite(piece, pos)

    if hover:
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        glow_mask = Image.new("L", size, 0)
        gd = ImageDraw.Draw(glow_mask)
        gd.rounded_rectangle((4, 4, w - 5, h - 5), radius=max(8, min(w, h) // 18), outline=220, width=max(3, min(w, h) // 36))
        glow_mask = glow_mask.filter(ImageFilter.GaussianBlur(4))
        glow.putalpha(glow_mask)
        glow = ImageOps.colorize(glow.getchannel("A"), "#000000", "#ffc45c").convert("RGBA")
        glow.putalpha(glow_mask.point(lambda p: min(120, p)))
        out = Image.alpha_composite(glow, out)

    return out


def build_divider(size: tuple[int, int], screen_ref: Image.Image) -> Image.Image:
    w, h = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    strip = crop_rgba(screen_ref, (514, 74, 1154, 108)).resize((w, h), Image.Resampling.LANCZOS)
    out.alpha_composite(strip)
    return out


def build_swatches(button_ref: Image.Image, screen_ref: Image.Image, size: tuple[int, int]) -> Image.Image:
    w, h = size
    out = build_panel(size, button_ref, screen_ref, heavy=False)
    draw = ImageDraw.Draw(out)
    colors = [
        ((95, 39, 32), (229, 92, 62)),
        ((75, 60, 30), (232, 184, 75)),
        ((31, 67, 48), (102, 205, 122)),
        ((37, 39, 51), (143, 150, 166)),
    ]
    pad = max(12, h // 6)
    box_w = max(30, (w - pad * 5) // 4)
    for i, (dark_c, light_c) in enumerate(colors):
        x = pad + i * (box_w + pad)
        y = pad
        draw.rounded_rectangle((x, y, x + box_w, h - pad), radius=max(5, h // 9), fill=(*dark_c, 230), outline=(*light_c, 240), width=max(2, h // 24))
        draw.line((x + 8, h - pad - 8, x + box_w - 8, y + 8), fill=(*light_c, 120), width=2)
    return out


def build_shop_overlay(size: tuple[int, int], button_ref: Image.Image, states: dict[str, Image.Image]) -> Image.Image:
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    veil = Image.new("RGBA", size, (10, 5, 4, 132))
    out.alpha_composite(veil)
    seal_src = states["idle"].crop((35, 32, 235, 220))
    seal = fit_on_canvas(seal_src, (size[0] // 2, size[1] // 2), 0.92)
    seal = ImageEnhance.Brightness(seal).enhance(0.9)
    out.alpha_composite(seal, ((size[0] - seal.width) // 2, (size[1] - seal.height) // 2))
    return out


def save(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def make_contact_sheet(button_ref: Image.Image, screen_ref: Image.Image, outputs: list[Path]) -> Image.Image:
    font = ImageFont.load_default()
    ref_button = button_ref.crop((188, 150, 1162, 1198)).resize((390, 420), Image.Resampling.LANCZOS).convert("RGBA")
    ref_screen = screen_ref.resize((640, 360), Image.Resampling.LANCZOS)

    thumbs: list[tuple[str, Image.Image]] = [
        ("reference: button_parchment_wax_seal", ref_button),
        ("reference: ui_parchment_kit/settings", ref_screen),
    ]
    for path in outputs:
        im = load_rgba(path)
        canvas = Image.new("RGBA", (220, 150), (22, 18, 15, 255))
        for y in range(canvas.height):
            for x in range(canvas.width):
                c = 30 if ((x // 12 + y // 12) % 2) else 20
                canvas.putpixel((x, y), (c, c, c, 255))
        thumb = fit_on_canvas(im, (210, 116), 0.95)
        canvas.alpha_composite(thumb, (5, 18))
        ImageDraw.Draw(canvas).text((6, 4), path.name[:34], fill=(236, 207, 149), font=font)
        thumbs.append((path.name, canvas))

    width = 1100
    rows = 1 + ((len(thumbs) - 1) // 4)
    height = 470 + rows * 170
    sheet = Image.new("RGBA", (width, height), (18, 13, 10, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "SCRUM-147 accepted-reference rebuild: parchment, wax seal, serrated forged metal", fill=(240, 215, 164), font=font)
    sheet.alpha_composite(ref_button, (18, 42))
    sheet.alpha_composite(ref_screen, (456, 72))
    draw.text((18, 426), "Left: fixed button reference. Right: ui_parchment_kit source. Below: regenerated live/canonical assets.", fill=(201, 172, 115), font=font)

    x, y = 18, 462
    for _, im in thumbs[2:]:
        sheet.alpha_composite(im, (x, y))
        x += 270
        if x + 240 > width:
            x = 18
            y += 170
    return sheet


def validate_pngs(paths: Iterable[Path]) -> None:
    errors: list[str] = []
    for path in paths:
        im = Image.open(path)
        if im.mode != "RGBA":
            errors.append(f"{path}: expected RGBA, got {im.mode}")
        extrema = im.getchannel("A").getextrema()
        if extrema[1] == 0:
            errors.append(f"{path}: empty alpha")
    if errors:
        raise SystemExit("\n".join(errors))


def main() -> None:
    raise SystemExit(
        "Superseded: run tools/apply_button_only_ui_revert.py "
        "(wax-seal buttons only, legacy panels)."
    )
    ensure_dirs()
    button_ref = Image.open(BUTTON_REF).convert("RGBA")
    screen_ref = Image.open(PARCHMENT_SCREEN).convert("RGBA")
    states = build_button_states(button_ref)

    generated: list[Path] = []

    for role in ("primary", "secondary", "danger"):
        for state in ("idle", "hover", "pressed", "disabled"):
            out = render_button(states, state, (384, 96))
            path = DARK_DIR / f"ui_df_button_{role}_{state}.png"
            save(path, out)
            generated.append(path)

    canonical_frames = {
        DARK_DIR / "ui_df_panel_frame.png": build_panel((768, 512), button_ref, screen_ref, heavy=True),
        DARK_DIR / "ui_df_card_frame.png": build_panel((384, 256), button_ref, screen_ref),
        DARK_DIR / "ui_df_level_panel_frame.png": build_panel((640, 384), button_ref, screen_ref, heavy=True),
        DARK_DIR / "ui_df_hud_panel_frame.png": build_panel((512, 128), button_ref, screen_ref, dark=True, heavy=False),
        DARK_DIR / "ui_df_hud_card_frame.png": build_panel((256, 96), button_ref, screen_ref, dark=True, heavy=False),
        DARK_DIR / "ui_df_tooltip_frame.png": build_panel((512, 256), button_ref, screen_ref),
        DARK_DIR / "ui_df_stat_row_frame.png": build_panel((512, 80), button_ref, screen_ref),
        DARK_DIR / "ui_df_stat_chip_frame.png": build_panel((384, 80), button_ref, screen_ref),
        DARK_DIR / "ui_df_shop_frame.png": build_panel((640, 320), button_ref, screen_ref, heavy=True),
        DARK_DIR / "ui_df_section_divider.png": build_divider((640, 24), screen_ref),
        DARK_DIR / "ui_df_stat_value_state_swatches.png": build_swatches(button_ref, screen_ref, (640, 144)),
    }
    for path, im in canonical_frames.items():
        save(path, im)
        generated.append(path)

    live_frames = {
        GLOBAL_DIR / "ui_button_frame.png": render_button(states, "idle", (160, 72)),
        GLOBAL_DIR / "ui_panel_frame.png": build_panel((128, 128), button_ref, screen_ref),
        GLOBAL_DIR / "ui_card_frame.png": build_panel((128, 128), button_ref, screen_ref),
        GLOBAL_DIR / "ui_hud_panel_frame.png": build_panel((128, 96), button_ref, screen_ref, dark=True),
        GLOBAL_DIR / "ui_hud_card_frame.png": build_panel((96, 72), button_ref, screen_ref, dark=True),
        GLOBAL_DIR / "ui_level_panel_frame.png": build_panel((160, 160), button_ref, screen_ref, heavy=True),
        GLOBAL_DIR / "ui_tooltip_frame.png": build_panel((128, 96), button_ref, screen_ref),
        ESCAPE_DIR / "ui_escape_button_frame.png": render_button(states, "idle", (384, 128)),
        ESCAPE_DIR / "ui_escape_panel_frame.png": build_panel((512, 512), button_ref, screen_ref, heavy=True),
        ESCAPE_DIR / "ui_stat_basic_row_frame.png": build_panel((512, 80), button_ref, screen_ref),
        ESCAPE_DIR / "ui_stat_chip_frame.png": build_panel((384, 80), button_ref, screen_ref),
        ESCAPE_DIR / "ui_stat_group_frame.png": build_panel((640, 320), button_ref, screen_ref, heavy=True),
        ESCAPE_DIR / "ui_stat_tooltip_frame.png": build_panel((640, 320), button_ref, screen_ref),
        ESCAPE_DIR / "ui_stat_section_divider.png": build_divider((640, 24), screen_ref),
        ESCAPE_DIR / "ui_stat_value_state_swatches.png": build_swatches(button_ref, screen_ref, (640, 144)),
        SHOP_DIR / "ui_shop_artifact_slot_frame.png": build_panel((256, 256), button_ref, screen_ref),
        SHOP_DIR / "ui_shop_artifact_slot_hover.png": build_panel((256, 256), button_ref, screen_ref, hover=True),
        SHOP_DIR / "ui_shop_price_badge.png": render_button(states, "idle", (256, 96)),
        SHOP_DIR / "ui_shop_tooltip_frame.png": build_panel((640, 320), button_ref, screen_ref),
        SHOP_DIR / "ui_shop_purchased_overlay.png": build_shop_overlay((256, 256), button_ref, states),
    }
    for path, im in live_frames.items():
        save(path, im)
        generated.append(path)

    escape_preview = Image.new("RGBA", (1280, 720), (20, 16, 12, 255))
    bg = screen_ref.resize((1280, 720), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    bg = ImageEnhance.Brightness(bg).enhance(0.42)
    escape_preview.alpha_composite(bg)
    escape_preview.alpha_composite(live_frames[ESCAPE_DIR / "ui_escape_panel_frame.png"], (80, 96))
    escape_preview.alpha_composite(live_frames[ESCAPE_DIR / "ui_stat_group_frame.png"], (590, 104))
    for idx, state in enumerate(("idle", "hover", "pressed", "disabled")):
        btn = render_button(states, state, (330, 86))
        escape_preview.alpha_composite(btn, (120, 130 + idx * 100))
    for idx in range(4):
        row = live_frames[ESCAPE_DIR / "ui_stat_basic_row_frame.png"]
        escape_preview.alpha_composite(row, (620, 150 + idx * 90))
    save(ESCAPE_DIR / "escape_stats_visual_kit_preview.png", escape_preview)
    generated.append(ESCAPE_DIR / "escape_stats_visual_kit_preview.png")

    contact = make_contact_sheet(
        button_ref,
        screen_ref,
        [
            DARK_DIR / "ui_df_button_primary_idle.png",
            DARK_DIR / "ui_df_button_primary_hover.png",
            DARK_DIR / "ui_df_button_primary_pressed.png",
            DARK_DIR / "ui_df_button_primary_disabled.png",
            DARK_DIR / "ui_df_panel_frame.png",
            DARK_DIR / "ui_df_card_frame.png",
            DARK_DIR / "ui_df_tooltip_frame.png",
            GLOBAL_DIR / "ui_button_frame.png",
            ESCAPE_DIR / "ui_escape_panel_frame.png",
            SHOP_DIR / "ui_shop_artifact_slot_frame.png",
            SHOP_DIR / "ui_shop_price_badge.png",
            ESCAPE_DIR / "escape_stats_visual_kit_preview.png",
        ],
    )
    contact_path = PREVIEW_DIR / "ui_parchment_wax_scrum147_reference_match_contact.png"
    save(contact_path, contact)
    generated.append(contact_path)

    validate_pngs(generated)
    print(f"Generated {len(generated)} parchment/wax UI assets")
    for path in generated:
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
