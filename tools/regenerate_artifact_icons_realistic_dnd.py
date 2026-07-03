from __future__ import annotations

import math
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "scripts/progression_data_content.gd"
OUT_DIR = ROOT / "assets/sprites/ui/icons/artifacts"
PREVIEW_PATH = ROOT / "assets/sprites/ui/icons/artifact_realistic_dnd_preview.png"

S = 4
CANVAS = 256 * S
CENTER = CANVAS // 2


def _rgba(c: tuple[int, int, int], a: int = 255) -> tuple[int, int, int, int]:
    return c[0], c[1], c[2], a


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _parse_artifacts() -> list[dict[str, str]]:
    text = DATA_PATH.read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS := [", 1)[1].split("\n]", 1)[0]
    artifacts: list[dict[str, str]] = []
    for line in block.splitlines():
        if '{"id":' not in line:
            continue
        item = {}
        for key in ["id", "title", "description"]:
            m = re.search(rf'"{key}"\s*:\s*"([^"]*)"', line)
            item[key] = m.group(1) if m else ""
        m = re.search(r'"tier"\s*:\s*(\d+)', line)
        item["tier"] = m.group(1) if m else "1"
        if item["id"]:
            artifacts.append(item)
    return artifacts


def _canvas() -> Image.Image:
    return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))


def _down(img: Image.Image) -> Image.Image:
    return img.resize((256, 256), Image.Resampling.LANCZOS)


def _save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    icon = _fit_icon(_down(img))
    icon.save(path)


def _fit_icon(icon: Image.Image, padding: int = 18) -> Image.Image:
    icon = icon.convert("RGBA")
    bbox = icon.getchannel("A").getbbox()
    if bbox is None:
        return icon
    crop = icon.crop(bbox)
    max_side = 256 - padding * 2
    scale = min(max_side / crop.size[0], max_side / crop.size[1], 1.0)
    new_size = (max(1, int(crop.size[0] * scale)), max(1, int(crop.size[1] * scale)))
    crop = crop.resize(new_size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    out.alpha_composite(crop, ((256 - new_size[0]) // 2, (256 - new_size[1]) // 2))
    return out


def _soft_shadow(img: Image.Image, alpha: int = 95, blur: int = 18, offset=(0, 18)) -> Image.Image:
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    shadow.putalpha(a.point(lambda v: min(alpha, int(v * 0.45))))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, offset)
    out.alpha_composite(img)
    return out


def _glow_layer(size: tuple[int, int], color: tuple[int, int, int], center: tuple[int, int], radius: int, strength: int) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for r in range(radius, 0, -8):
        a = int(strength * (1 - r / radius) ** 1.6)
        d.ellipse((center[0] - r, center[1] - r, center[0] + r, center[1] + r), fill=_rgba(color, a))
    return layer.filter(ImageFilter.GaussianBlur(8))


def _ellipse_gradient(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], base: tuple[int, int, int], light: tuple[int, int, int], dark: tuple[int, int, int], outline=(24, 20, 18), width=8) -> None:
    x0, y0, x1, y1 = box
    steps = 42
    for i in range(steps, 0, -1):
        t = i / steps
        inset_x = int((x1 - x0) * (1 - t) / 2)
        inset_y = int((y1 - y0) * (1 - t) / 2)
        col = _mix(dark, base, t)
        draw.ellipse((x0 + inset_x, y0 + inset_y, x1 - inset_x, y1 - inset_y), fill=_rgba(col, 255))
    draw.ellipse(box, outline=_rgba(outline, 240), width=width)
    hx = x0 + int((x1 - x0) * 0.34)
    hy = y0 + int((y1 - y0) * 0.28)
    hr = int(min(x1 - x0, y1 - y0) * 0.17)
    draw.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=_rgba(light, 92))


def _gem(draw: ImageDraw.ImageDraw, center: tuple[int, int], r: int, color: tuple[int, int, int], outline=(28, 20, 18)) -> None:
    x, y = center
    pts = [(x, y - r), (x + int(r * 0.75), y), (x, y + r), (x - int(r * 0.75), y)]
    draw.polygon(pts, fill=_rgba(_mix(color, (255, 255, 255), 0.16), 255), outline=_rgba(outline, 240))
    draw.polygon([(x, y - r), (x + int(r * 0.75), y), (x, y)], fill=_rgba(_mix(color, (255, 255, 255), 0.42), 210))
    draw.line((x - int(r * 0.55), y, x + int(r * 0.55), y), fill=_rgba(_mix(color, (255, 255, 255), 0.55), 180), width=max(2, r // 8))


def _rune_marks(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, color: tuple[int, int, int], count: int = 8) -> None:
    for i in range(count):
        a = math.tau * i / count - math.pi / 2
        x = cx + int(math.cos(a) * radius)
        y = cy + int(math.sin(a) * radius)
        dx = int(math.cos(a + math.pi / 2) * 12 * S)
        dy = int(math.sin(a + math.pi / 2) * 12 * S)
        draw.line((x - dx, y - dy, x + dx, y + dy), fill=_rgba(color, 170), width=3 * S)


def _rotate_object(obj: Image.Image, deg: float) -> Image.Image:
    return obj.rotate(deg, resample=Image.Resampling.BICUBIC, expand=False)


def draw_amulet(item: dict, palette: dict, motif: str = "gem") -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    metal = palette["metal"]
    glow = palette["glow"]
    d.arc((300, 120, 724, 530), 202, 338, fill=_rgba(_mix(metal, (255, 220, 150), 0.2), 255), width=18 * S)
    d.arc((332, 160, 692, 490), 202, 338, fill=(38, 28, 20, 220), width=5 * S)
    if motif == "fang":
        d.polygon([(CENTER, 300), (620, 450), (535, 760), (470, 760), (404, 450)], fill=_rgba((210, 198, 172), 255), outline=(34, 24, 18, 255))
        d.line((CENTER, 335, 502, 720), fill=(130, 116, 91, 180), width=5 * S)
        _gem(d, (CENTER, 420), 28 * S, glow)
    elif motif == "heart":
        d.ellipse((352, 300, 520, 500), fill=_rgba((116, 18, 28), 255), outline=(40, 10, 12, 255), width=8 * S)
        d.ellipse((504, 300, 672, 500), fill=_rgba((116, 18, 28), 255), outline=(40, 10, 12, 255), width=8 * S)
        d.polygon([(340, 410), (684, 410), (512, 720)], fill=_rgba((116, 18, 28), 255), outline=(40, 10, 12, 255))
        d.line((420, 390, 512, 685, 620, 388), fill=(220, 76, 84, 130), width=7 * S)
    elif motif == "seed":
        d.ellipse((360, 300, 664, 680), fill=_rgba((70, 95, 46), 255), outline=(26, 34, 20, 255), width=8 * S)
        d.polygon([(512, 245), (590, 360), (512, 465), (435, 360)], fill=_rgba((160, 128, 65), 255), outline=(38, 28, 14, 255))
        d.line((512, 275, 512, 435), fill=_rgba(glow, 160), width=8 * S)
    else:
        d.ellipse((344, 260, 680, 720), fill=_rgba((34, 30, 28), 255), outline=_rgba(metal, 255), width=16 * S)
        d.ellipse((402, 318, 622, 638), fill=(12, 12, 14, 255), outline=_rgba(_mix(metal, (255, 236, 180), 0.4), 255), width=8 * S)
        _gem(d, (CENTER, 478), 92 * S, glow)
        _rune_marks(d, CENTER, 478, 145 * S, glow, 10)
    return _soft_shadow(img)


def draw_boots(item: dict, palette: dict, spectral: bool = False) -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    leather = palette.get("leather", (84, 48, 28))
    glow = palette["glow"]
    for ox in (-100, 95):
        d.polygon([(CENTER + ox - 55, 230), (CENTER + ox + 58, 230), (CENTER + ox + 42, 620), (CENTER + ox - 82, 620)],
                  fill=_rgba(_mix(leather, (20, 20, 24), 0.18), 250), outline=(30, 18, 12, 255))
        d.polygon([(CENTER + ox - 82, 590), (CENTER + ox + 70, 575), (CENTER + ox + 128, 650), (CENTER + ox + 5, 705), (CENTER + ox - 92, 660)],
                  fill=_rgba(leather, 255), outline=(28, 18, 12, 255))
        d.rectangle((CENTER + ox - 72, 315, CENTER + ox + 54, 358), fill=_rgba(palette["metal"], 235), outline=(38, 28, 18, 230))
        d.line((CENTER + ox - 45, 250, CENTER + ox + 38, 585), fill=_rgba(_mix(leather, (255, 214, 150), 0.22), 140), width=7 * S)
        _gem(d, (CENTER + ox - 4, 338), 14 * S, glow)
    if spectral:
        img.alpha_composite(_glow_layer(img.size, glow, (CENTER, 520), 250, 75))
    return _soft_shadow(img)


def draw_book(item: dict, palette: dict, ash: bool = False, page: bool = False) -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    glow = palette["glow"]
    if page:
        d.polygon([(340, 190), (690, 245), (640, 760), (302, 694)], fill=(190, 175, 135, 255), outline=(48, 34, 22, 255))
        for i in range(7):
            y = 300 + i * 54
            d.line((372, y, 608, y + 24), fill=(84, 58, 40, 110), width=3 * S)
        d.line((330, 205, 672, 742), fill=_rgba(glow, 160), width=6 * S)
        if ash:
            d.polygon([(590, 250), (690, 245), (640, 760), (560, 708)], fill=(55, 50, 46, 190))
    else:
        cover = (54, 42, 32) if not ash else (48, 48, 46)
        d.rounded_rectangle((298, 205, 725, 760), radius=22 * S, fill=_rgba(cover, 255), outline=(25, 18, 13, 255), width=10 * S)
        d.rectangle((312, 230, 368, 740), fill=(30, 22, 18, 255))
        d.rounded_rectangle((392, 285, 640, 590), radius=20 * S, outline=_rgba(palette["metal"], 230), width=10 * S)
        d.line((430, 655, 620, 655), fill=(165, 145, 112, 180), width=8 * S)
        _gem(d, (516, 438), 58 * S, glow)
        for i in range(5):
            d.line((406, 625 + i * 22, 686, 642 + i * 20), fill=(220, 205, 165, 105), width=3 * S)
    return _soft_shadow(img)


def draw_orb_or_core(item: dict, palette: dict, cracked: bool = False, compass: bool = False) -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    glow = palette["glow"]
    if compass:
        d.ellipse((250, 250, 774, 774), fill=(34, 28, 23, 255), outline=_rgba(palette["metal"], 255), width=18 * S)
        d.ellipse((330, 330, 694, 694), fill=(18, 22, 28, 255), outline=(190, 162, 92, 255), width=8 * S)
        for a in range(0, 360, 45):
            r1, r2 = 95 * S, 176 * S
            x1 = CENTER + math.cos(math.radians(a)) * r1
            y1 = CENTER + math.sin(math.radians(a)) * r1
            x2 = CENTER + math.cos(math.radians(a)) * r2
            y2 = CENTER + math.sin(math.radians(a)) * r2
            d.line((x1, y1, x2, y2), fill=_rgba(glow, 145), width=3 * S)
        d.polygon([(CENTER, 342), (548, 512), (CENTER, 682), (476, 512)], fill=_rgba((205, 56, 50), 230), outline=(35, 24, 18, 255))
    else:
        img.alpha_composite(_glow_layer(img.size, glow, (CENTER, CENTER), 250 * S // 4, 70))
        _ellipse_gradient(d, (286, 286, 738, 738), _mix(glow, (40, 44, 54), 0.35), _mix(glow, (255, 255, 255), 0.65), (18, 18, 24), (20, 20, 26), 9 * S)
        d.ellipse((370, 372, 654, 656), outline=_rgba(_mix(glow, (255, 255, 255), 0.35), 170), width=5 * S)
        if cracked:
            for pts in [[(512, 305), (480, 435), (536, 524), (502, 720)], [(620, 390), (555, 470), (642, 600)]]:
                d.line(pts, fill=(20, 16, 18, 200), width=5 * S)
                d.line(pts, fill=_rgba((255, 120, 82), 160), width=2 * S)
    return _soft_shadow(img)


def draw_coin_or_buckle(item: dict, palette: dict, buckle: bool = False, purse: bool = False) -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    if purse:
        d.polygon([(318, 330), (706, 330), (770, 720), (250, 720)], fill=(70, 42, 25, 255), outline=(30, 18, 10, 255))
        d.ellipse((300, 230, 724, 450), fill=(98, 58, 32, 255), outline=(34, 20, 12, 255), width=8 * S)
        d.line((340, 345, 684, 345), fill=_rgba(palette["metal"], 230), width=12 * S)
        _gem(d, (512, 470), 38 * S, palette["glow"])
    elif buckle:
        d.rounded_rectangle((240, 350, 784, 650), radius=35 * S, fill=(50, 38, 30, 255), outline=_rgba(palette["metal"], 255), width=16 * S)
        d.rounded_rectangle((330, 405, 694, 595), radius=20 * S, outline=(185, 142, 72, 230), width=7 * S)
        _gem(d, (CENTER, CENTER), 62 * S, palette["glow"])
    else:
        _ellipse_gradient(d, (275, 275, 749, 749), palette["metal"], (255, 236, 150), (82, 54, 20), (42, 28, 12), 10 * S)
        d.ellipse((372, 372, 652, 652), outline=(118, 78, 28, 200), width=8 * S)
        for a in range(0, 360, 30):
            x = CENTER + int(math.cos(math.radians(a)) * 176 * S / 4)
            y = CENTER + int(math.sin(math.radians(a)) * 176 * S / 4)
            d.ellipse((x - 9 * S, y - 9 * S, x + 9 * S, y + 9 * S), fill=(88, 58, 24, 165))
    return _soft_shadow(img)


def draw_blade_or_weapon_part(item: dict, palette: dict, kind: str = "blade") -> Image.Image:
    obj = _canvas()
    d = ImageDraw.Draw(obj)
    metal = palette["metal"]
    glow = palette["glow"]
    if kind == "whetstone":
        d.rounded_rectangle((380, 270, 635, 740), radius=28 * S, fill=(116, 45, 38, 255), outline=(38, 22, 18, 255), width=8 * S)
        d.line((410, 318, 604, 690), fill=(210, 96, 80, 150), width=8 * S)
        d.line((376, 246, 640, 766), fill=_rgba(glow, 100), width=4 * S)
    elif kind == "grip":
        d.rounded_rectangle((430, 230, 595, 730), radius=42 * S, fill=(78, 50, 32, 255), outline=(30, 18, 12, 255), width=8 * S)
        for y in range(285, 680, 72):
            d.rectangle((404, y, 620, y + 34), fill=_rgba(metal, 245), outline=(32, 24, 18, 230))
        _gem(d, (512, 470), 30 * S, glow)
    elif kind == "pick":
        pts = [(512, 210), (610, 512), (512, 815), (414, 512)]
        d.polygon(pts, fill=_rgba((46, 34, 56), 255), outline=(18, 13, 20, 255))
        d.polygon([(512, 260), (572, 512), (512, 765), (452, 512)], fill=_rgba(glow, 170))
    elif kind == "string":
        d.arc((250, 210, 775, 780), 212, 506, fill=_rgba(metal, 255), width=12 * S)
        d.arc((310, 270, 715, 720), 212, 506, fill=_rgba(glow, 160), width=5 * S)
        for x, y in [(330, 640), (690, 640)]:
            d.ellipse((x - 28, y - 28, x + 28, y + 28), fill=_rgba(metal, 255), outline=(30, 22, 14, 255), width=5 * S)
    else:
        jag = kind == "jagged"
        pts = [(512, 160), (585, 560), (512, 810), (438, 560)]
        if jag:
            pts = [(512, 150), (590, 420), (550, 455), (602, 540), (512, 820), (430, 548), (474, 505), (420, 424)]
        d.polygon(pts, fill=_rgba(_mix(metal, (210, 220, 230), 0.38), 255), outline=(26, 25, 25, 255))
        d.line((512, 190, 512, 760), fill=(255, 255, 255, 115), width=5 * S)
        _gem(d, (512, 585), 24 * S, glow)
    return _soft_shadow(_rotate_object(obj, -28 if kind not in ["pick", "string"] else 0))


def draw_shield_or_gloves(item: dict, palette: dict, kind: str = "shield") -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    metal = palette["metal"]
    glow = palette["glow"]
    if kind == "gloves":
        for ox in (-100, 100):
            d.rounded_rectangle((CENTER + ox - 82, 310, CENTER + ox + 76, 650), radius=28 * S, fill=(72, 45, 30, 255), outline=(28, 18, 12, 255), width=8 * S)
            for i in range(4):
                x = CENTER + ox - 72 + i * 39
                d.rounded_rectangle((x, 220, x + 32, 382), radius=15 * S, fill=(86, 52, 34, 255), outline=(28, 18, 12, 220), width=4 * S)
            d.rectangle((CENTER + ox - 84, 520, CENTER + ox + 80, 575), fill=_rgba(metal, 225), outline=(35, 25, 18, 220))
        d.line((400, 610, 624, 610), fill=_rgba(metal, 150), width=10 * S)
    else:
        d.polygon([(512, 185), (744, 295), (702, 660), (512, 828), (322, 660), (280, 295)],
                  fill=_rgba(_mix(metal, (30, 34, 40), 0.45), 255), outline=(22, 18, 15, 255))
        d.polygon([(512, 250), (650, 330), (620, 620), (512, 720), (404, 620), (374, 330)],
                  outline=_rgba((210, 170, 88), 220), fill=(0, 0, 0, 0))
        if "cracked" in item["id"]:
            d.line((440, 260, 538, 462, 490, 730), fill=(18, 15, 14, 230), width=7 * S)
            d.line((442, 260, 538, 462, 490, 730), fill=_rgba(glow, 120), width=3 * S)
        _gem(d, (512, 460), 38 * S, glow)
    return _soft_shadow(img)


def draw_bell_totem_amp(item: dict, palette: dict, kind: str = "bell") -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    metal = palette["metal"]
    glow = palette["glow"]
    if kind == "amp":
        d.rounded_rectangle((280, 310, 744, 720), radius=30 * S, fill=(38, 32, 30, 255), outline=_rgba(metal, 255), width=12 * S)
        d.rounded_rectangle((350, 380, 674, 645), radius=18 * S, fill=(12, 12, 14, 255), outline=(110, 84, 50, 230), width=6 * S)
        for r in [135, 80, 35]:
            d.ellipse((512 - r, 512 - r, 512 + r, 512 + r), outline=_rgba(glow, 120), width=5 * S)
    elif kind == "totem":
        d.polygon([(512, 180), (650, 330), (612, 760), (412, 760), (374, 330)], fill=(65, 54, 42, 255), outline=(24, 18, 12, 255))
        d.ellipse((430, 280, 594, 450), fill=(188, 174, 140, 255), outline=(42, 32, 24, 255), width=6 * S)
        d.ellipse((466, 338, 486, 360), fill=(10, 10, 12, 255))
        d.ellipse((538, 338, 558, 360), fill=(10, 10, 12, 255))
        _gem(d, (512, 575), 36 * S, glow)
    else:
        d.polygon([(512, 165), (668, 620), (356, 620)], fill=_rgba(metal, 255), outline=(34, 24, 14, 255))
        d.ellipse((330, 560, 694, 725), fill=_rgba(_mix(metal, (255, 218, 120), 0.2), 255), outline=(34, 24, 14, 255), width=8 * S)
        d.ellipse((470, 682, 554, 766), fill=_rgba(glow, 230), outline=(28, 22, 18, 220), width=4 * S)
        d.arc((418, 210, 606, 410), 205, 335, fill=(36, 24, 14, 220), width=6 * S)
    return _soft_shadow(img)


def draw_flask_candle_ink(item: dict, palette: dict, kind: str = "flask") -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    glow = palette["glow"]
    if kind == "candle":
        d.rounded_rectangle((430, 280, 594, 730), radius=35 * S, fill=(42, 36, 46, 255), outline=(22, 18, 20, 255), width=7 * S)
        d.ellipse((420, 260, 604, 340), fill=(58, 50, 60, 255), outline=(22, 18, 20, 255), width=6 * S)
        d.polygon([(512, 145), (565, 270), (512, 330), (460, 270)], fill=_rgba(glow, 220), outline=(42, 20, 12, 210))
    elif kind == "ink":
        d.rounded_rectangle((380, 330, 644, 720), radius=42 * S, fill=(30, 24, 42, 255), outline=(18, 12, 20, 255), width=8 * S)
        d.rectangle((430, 240, 594, 370), fill=_rgba(palette["metal"], 230), outline=(30, 22, 16, 255))
        d.ellipse((410, 500, 614, 680), fill=_rgba(glow, 110))
        _gem(d, (512, 575), 46 * S, glow)
    else:
        d.rounded_rectangle((430, 210, 594, 385), radius=25 * S, fill=(190, 210, 214, 100), outline=(220, 240, 245, 180), width=5 * S)
        d.ellipse((330, 330, 694, 760), fill=(165, 235, 210, 58), outline=(215, 240, 238, 180), width=7 * S)
        d.pieslice((350, 430, 674, 790), 0, 180, fill=_rgba(glow, 150))
        d.line((390, 410, 612, 720), fill=(255, 255, 255, 90), width=6 * S)
    return _soft_shadow(img)


def draw_crown(item: dict, palette: dict, blood: bool = False) -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    metal = (145, 18, 20) if blood else palette["metal"]
    pts = [(235, 620), (285, 270), (392, 540), (512, 210), (632, 540), (740, 270), (790, 620)]
    d.polygon(pts, fill=_rgba(metal, 255), outline=(30, 18, 14, 255))
    d.arc((235, 470, 790, 760), 0, 180, fill=_rgba(_mix(metal, (255, 218, 120), 0.18), 255), width=45 * S)
    d.line((282, 620, 744, 620), fill=(40, 22, 18, 200), width=10 * S)
    _gem(d, (512, 470), 56 * S, palette["glow"])
    for x, y in [(285, 280), (392, 535), (632, 535), (740, 280)]:
        _gem(d, (x, y), 20 * S, palette["glow"])
    return _soft_shadow(img)


def _palette(item: dict) -> dict:
    aid = item["id"]
    tier = int(item.get("tier", "1"))
    glow = (84, 210, 255)
    if any(k in aid for k in ["blood", "rage", "heart", "leech"]):
        glow = (235, 38, 48)
    elif any(k in aid for k in ["void", "dark", "phantom", "echo", "split"]):
        glow = (150, 72, 255)
    elif any(k in aid for k in ["root", "thorn", "seed", "fox"]):
        glow = (96, 210, 104)
    elif any(k in aid for k in ["ember", "burning", "ash", "candle"]):
        glow = (255, 118, 38)
    elif any(k in aid for k in ["coin", "golden", "captain", "banner"]):
        glow = (255, 205, 78)
    return {
        "metal": (172 + tier * 12, 126 + tier * 8, 58 + tier * 6),
        "leather": (96, 58, 34),
        "glow": glow,
    }


def _kind(item: dict) -> str:
    aid = item["id"]
    title = item["title"].lower()
    if "boots" in aid or "step" in aid:
        return "boots"
    if "codex" in aid or "manual" in aid:
        return "book"
    if "page" in aid:
        return "page"
    if "orb" in aid or "core" in aid or "crystal" in aid or "shard" in aid:
        return "orb"
    if "compass" in aid or "route_mark" in aid:
        return "compass"
    if "coin" in aid:
        return "coin"
    if "buckle" in aid:
        return "buckle"
    if "purse" in aid:
        return "purse"
    if "gloves" in aid:
        return "gloves"
    if "shield" in aid:
        return "shield"
    if "bell" in aid:
        return "bell"
    if "totem" in aid:
        return "totem"
    if "amp" in aid:
        return "amp"
    if "crown" in aid:
        return "crown"
    if "heart" in aid:
        return "heart_amulet"
    if "fang" in aid:
        return "fang"
    if "ink" in aid:
        return "ink"
    if "candle" in aid:
        return "candle"
    if "whetstone" in aid:
        return "whetstone"
    if "blade" in aid or "edge" in aid:
        return "blade"
    if "grip" in aid:
        return "grip"
    if "pick" in aid:
        return "pick"
    if "string" in aid or "cable" in aid or "quickstring" in aid:
        return "string"
    if "belt" in aid:
        return "belt"
    if "root" in aid:
        return "root"
    if "seed" in aid:
        return "seed"
    if "pact" in aid or "sigil" in aid or "talisman" in aid or "amulet" in aid or "charm" in aid or "lens" in aid:
        return "amulet"
    return "amulet"


def draw_root_or_belt(item: dict, palette: dict, kind: str) -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    glow = palette["glow"]
    if kind == "belt":
        d.rounded_rectangle((180, 420, 844, 600), radius=42 * S, fill=(78, 44, 26, 255), outline=(26, 16, 10, 255), width=7 * S)
        for x in range(245, 780, 86):
            d.ellipse((x - 14, 496 - 14, x + 14, 496 + 14), fill=_rgba(palette["metal"], 230), outline=(32, 24, 15, 230))
        d.rounded_rectangle((410, 360, 614, 660), radius=24 * S, fill=_rgba(palette["metal"], 255), outline=(32, 24, 14, 255), width=8 * S)
        _gem(d, (512, 512), 42 * S, glow)
    else:
        for i in range(7):
            x0 = 512 + int(math.cos(i) * 20)
            y0 = 230 + i * 64
            x1 = 350 + (i % 3) * 95
            y1 = 780 - i * 20
            d.line((x0, y0, x1, y1), fill=(74, 50, 30, 255), width=(18 - i) * S)
            d.line((x0, y0, x1, y1), fill=(132, 92, 52, 160), width=max(2, (7 - i)) * S)
        _gem(d, (512, 420), 42 * S, glow)
    return _soft_shadow(img)


def draw_item(item: dict) -> Image.Image:
    p = _palette(item)
    kind = _kind(item)
    aid = item["id"]
    if kind == "boots":
        return draw_boots(item, p, spectral=("phantom" in aid))
    if kind == "book":
        return draw_book(item, p)
    if kind == "page":
        return draw_book(item, p, ash=("ash" in aid), page=True)
    if kind == "orb":
        return draw_orb_or_core(item, p, cracked=("shard" in aid or "split" in aid))
    if kind == "compass":
        return draw_orb_or_core(item, p, compass=True)
    if kind == "coin":
        return draw_coin_or_buckle(item, p)
    if kind == "buckle":
        return draw_coin_or_buckle(item, p, buckle=True)
    if kind == "purse":
        return draw_coin_or_buckle(item, p, purse=True)
    if kind == "gloves":
        return draw_shield_or_gloves(item, p, "gloves")
    if kind == "shield":
        return draw_shield_or_gloves(item, p, "shield")
    if kind in ["bell", "totem", "amp"]:
        return draw_bell_totem_amp(item, p, kind)
    if kind == "crown":
        return draw_crown(item, p, blood=("blood" in aid or "cursed" in aid))
    if kind == "heart_amulet":
        return draw_amulet(item, p, "heart")
    if kind == "fang":
        return draw_amulet(item, p, "fang")
    if kind == "ink":
        return draw_flask_candle_ink(item, p, "ink")
    if kind == "candle":
        return draw_flask_candle_ink(item, p, "candle")
    if kind == "whetstone":
        return draw_blade_or_weapon_part(item, p, "whetstone")
    if kind == "blade":
        return draw_blade_or_weapon_part(item, p, "jagged" if "jagged" in aid else "blade")
    if kind == "grip":
        return draw_blade_or_weapon_part(item, p, "grip")
    if kind == "pick":
        return draw_blade_or_weapon_part(item, p, "pick")
    if kind == "string":
        return draw_blade_or_weapon_part(item, p, "string")
    if kind == "belt":
        return draw_root_or_belt(item, p, "belt")
    if kind == "root":
        return draw_root_or_belt(item, p, "root")
    if kind == "seed":
        return draw_amulet(item, p, "seed")
    return draw_amulet(item, p, "gem")


def _trim_and_validate(path: Path) -> tuple[bool, str]:
    im = Image.open(path).convert("RGBA")
    if im.size != (256, 256):
        return False, f"bad size {im.size}"
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return False, "empty alpha"
    if min(bbox[0], bbox[1], 255 - bbox[2], 255 - bbox[3]) < 2:
        return False, f"bbox too close {bbox}"
    corners = [alpha.getpixel((0, 0)), alpha.getpixel((255, 0)), alpha.getpixel((0, 255)), alpha.getpixel((255, 255))]
    if max(corners) != 0:
        return False, f"opaque corner {corners}"
    return True, "ok"


def make_preview(artifacts: list[dict[str, str]]) -> None:
    cols = 6
    cell_w = 312
    cell_h = 354
    rows = math.ceil(len(artifacts) / cols)
    out = Image.new("RGBA", (cols * cell_w, rows * cell_h), (24, 20, 18, 255))
    d = ImageDraw.Draw(out)
    for idx, item in enumerate(artifacts):
        x = (idx % cols) * cell_w
        y = (idx // cols) * cell_h
        icon = Image.open(OUT_DIR / f"artifact_{item['id']}.png").convert("RGBA")
        out.alpha_composite(icon, (x + 28, y + 14))
        small = icon.resize((40, 40), Image.Resampling.LANCZOS)
        out.alpha_composite(small, (x + 226, y + 222))
        d.rectangle((x + 20, y + 10, x + 284, y + 284), outline=(90, 68, 34, 255), width=2)
        d.rectangle((x + 218, y + 214, x + 270, y + 266), outline=(160, 128, 58, 255), width=1)
        label = item["id"][:28]
        d.text((x + 24, y + 292), label, fill=(230, 210, 160, 255))
        d.text((x + 24, y + 316), f"tier {item.get('tier','1')}  40px preview", fill=(150, 140, 120, 255))
    out.save(PREVIEW_PATH)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    artifacts = _parse_artifacts()
    if not artifacts:
        raise SystemExit("No artifacts parsed")
    failures = []
    for item in artifacts:
        img = draw_item(item)
        path = OUT_DIR / f"artifact_{item['id']}.png"
        _save(img, path)
        ok, msg = _trim_and_validate(path)
        if not ok:
            failures.append((item["id"], msg))
    make_preview(artifacts)
    print(f"generated={len(artifacts)} preview={PREVIEW_PATH}")
    if failures:
        print("failures:", failures)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
