from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]


def rgba(color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    color = color.lstrip("#")
    return (int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16), alpha)


def canvas(size: int) -> Image.Image:
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def draw_poly(draw: ImageDraw.ImageDraw, points: Iterable[tuple[float, float]], fill: str, outline: str = "#241b2b", width: int = 4) -> None:
    pts = list(points)
    draw.polygon(pts, fill=rgba(outline))
    inset = []
    cx = sum(p[0] for p in pts) / max(len(pts), 1)
    cy = sum(p[1] for p in pts) / max(len(pts), 1)
    for x, y in pts:
        inset.append((cx + (x - cx) * 0.92, cy + (y - cy) * 0.92))
    draw.polygon(inset, fill=rgba(fill))


def draw_ellipse(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], fill: str, outline: str = "#241b2b", width: int = 4) -> None:
    draw.ellipse(box, fill=rgba(outline))
    x1, y1, x2, y2 = box
    draw.ellipse((x1 + width, y1 + width, x2 - width, y2 - width), fill=rgba(fill))


def draw_pill(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], fill: str, outline: str = "#241b2b", width: int = 4) -> None:
    draw.rounded_rectangle(box, radius=int(min(box[2] - box[0], box[3] - box[1]) * 0.45), fill=rgba(outline))
    x1, y1, x2, y2 = box
    draw.rounded_rectangle((x1 + width, y1 + width, x2 - width, y2 - width), radius=int(min(x2 - x1, y2 - y1) * 0.38), fill=rgba(fill))


def draw_glow(img: Image.Image, box: tuple[float, float, float, float], color: str, blur: int = 9) -> None:
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(box, fill=rgba(color, 130))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur)))


def save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def character_sprite(kind: str, palette: tuple[str, str, str]) -> Image.Image:
    size = 512
    img = canvas(size)
    d = ImageDraw.Draw(img)
    accent, mid, dark = palette
    draw_glow(img, (150, 76, 362, 390), accent, 16)

    if kind == "berserk":
        draw_ellipse(d, (145, 156, 212, 224), "#6b3b45", width=7)
        draw_ellipse(d, (300, 156, 367, 224), "#6b3b45", width=7)
        draw_pill(d, (151, 198, 205, 335), "#d0704d", width=7)
        draw_pill(d, (307, 198, 361, 335), "#d0704d", width=7)
        draw_pill(d, (186, 314, 238, 442), "#623545", width=7)
        draw_pill(d, (274, 314, 326, 442), "#623545", width=7)
        draw_ellipse(d, (158, 143, 354, 371), "#93473e", width=10)
        draw_ellipse(d, (181, 152, 331, 230), "#6b3b45", width=6)
        draw_ellipse(d, (197, 171, 315, 301), "#df8357", width=6)
        draw_poly(d, [(191, 276), (321, 276), (310, 326), (202, 326)], "#5b3440", width=5)
        d.line((205, 284, 308, 314), fill=rgba("#ffc36d"), width=7)
        d.line((306, 284, 205, 314), fill=rgba("#ffc36d"), width=7)
        draw_pill(d, (185, 318, 327, 347), "#3d2532", width=5)
        draw_ellipse(d, (244, 319, 268, 343), "#ffd166", width=3)
        draw_ellipse(d, (190, 56, 322, 180), "#b86f4d", width=9)
        draw_ellipse(d, (203, 48, 309, 117), "#5b3440", width=5)
        draw_ellipse(d, (226, 29, 286, 93), "#5b3440", width=4)
        draw_ellipse(d, (188, 79, 234, 128), "#5b3440", width=4)
        draw_ellipse(d, (278, 79, 324, 128), "#5b3440", width=4)
        d.arc((210, 124, 302, 166), 20, 160, fill=rgba("#f4d0a0"), width=7)
        d.arc((201, 180, 311, 293), 15, 165, fill=rgba("#ffc36d"), width=5)
        d.line((220, 107, 243, 116), fill=rgba("#301820"), width=5)
        d.line((292, 107, 269, 116), fill=rgba("#301820"), width=5)
        draw_ellipse(d, (224, 114, 241, 131), "#301820", width=2)
        draw_ellipse(d, (271, 114, 288, 131), "#301820", width=2)
        d.line((218, 198, 235, 214), fill=rgba("#ffd2a0"), width=3)
    elif kind == "dark_mage":
        draw_ellipse(d, (149, 174, 213, 235), "#32234d", width=6)
        draw_ellipse(d, (299, 174, 363, 235), "#32234d", width=6)
        draw_pill(d, (154, 204, 202, 337), "#5c43af", width=6)
        draw_pill(d, (310, 204, 358, 337), "#5c43af", width=6)
        draw_pill(d, (199, 322, 240, 427), "#1e1932", width=5)
        draw_pill(d, (272, 322, 313, 427), "#1e1932", width=5)
        draw_ellipse(d, (158, 142, 354, 390), "#292446", width=10)
        draw_ellipse(d, (196, 162, 316, 333), "#6146b7", width=5)
        draw_poly(d, [(177, 304), (335, 304), (359, 388), (153, 388)], "#1e1932", width=6)
        d.arc((176, 174, 336, 374), 198, 342, fill=rgba("#c4a6ff"), width=9)
        d.arc((194, 176, 318, 340), 210, 330, fill=rgba("#8f7cff"), width=5)
        draw_ellipse(d, (233, 271, 279, 318), "#9b77ff", width=4)
        d.line((256, 232, 256, 313), fill=rgba("#d9c8ff"), width=4)
        draw_ellipse(d, (187, 58, 325, 186), "#211b38", width=9)
        draw_ellipse(d, (214, 83, 298, 160), "#49356f", width=4)
        draw_ellipse(d, (229, 36, 283, 91), "#211b38", width=4)
        draw_pill(d, (195, 132, 317, 178), "#211b38", width=4)
        d.arc((206, 83, 306, 171), 204, 336, fill=rgba("#8f7cff"), width=5)
        draw_ellipse(d, (223, 113, 241, 131), "#c6a5ff", width=2)
        draw_ellipse(d, (271, 113, 289, 131), "#c6a5ff", width=2)
        draw_ellipse(d, (164, 314, 188, 338), "#c6a5ff", width=3)
        draw_ellipse(d, (324, 314, 348, 338), "#c6a5ff", width=3)
    else:
        draw_ellipse(d, (151, 163, 213, 224), "#204059", width=6)
        draw_ellipse(d, (299, 163, 361, 224), "#204059", width=6)
        draw_pill(d, (154, 194, 205, 335), "#3e7fa2", width=6)
        draw_pill(d, (307, 194, 358, 335), "#3e7fa2", width=6)
        draw_pill(d, (194, 315, 240, 430), "#1f2034", width=5)
        draw_pill(d, (272, 315, 318, 430), "#1f2034", width=5)
        draw_ellipse(d, (164, 145, 348, 359), "#284b64", width=10)
        draw_ellipse(d, (194, 169, 318, 304), "#f1b64e", width=6)
        d.line((200, 183, 312, 318), fill=rgba("#1f2034"), width=8)
        draw_ellipse(d, (245, 262, 273, 292), "#ffd166", width=3)
        draw_ellipse(d, (299, 184, 343, 274), "#ffd166", width=5)
        d.arc((190, 188, 322, 315), 20, 160, fill=rgba("#f6c35c"), width=5)
        draw_ellipse(d, (196, 62, 316, 181), "#946345", width=8)
        draw_ellipse(d, (188, 48, 324, 124), "#1f2034", width=5)
        draw_ellipse(d, (202, 31, 264, 97), "#1f2034", width=4)
        draw_ellipse(d, (250, 32, 316, 100), "#1f2034", width=4)
        draw_pill(d, (194, 91, 318, 131), "#1f2034", width=4)
        draw_pill(d, (211, 107, 301, 130), "#2f314a", width=3)
        d.arc((204, 121, 308, 163), 20, 160, fill=rgba("#f4d38a"), width=6)
        draw_ellipse(d, (219, 112, 235, 128), "#171725", width=2)
        draw_ellipse(d, (277, 112, 293, 128), "#171725", width=2)

    return img


def enemy_sprite(kind: str, palette: tuple[str, str, str], elite: bool = False, boss: bool = False) -> Image.Image:
    size = 256 if boss else 192
    img = canvas(size)
    d = ImageDraw.Draw(img)
    accent, mid, dark = palette
    cx = size / 2
    draw_glow(img, (cx - 58, 16, cx + 58, size - 18), accent, 10 if not boss else 15)

    if boss:
        draw_ellipse(d, (54, 74, 202, 202), dark, width=9)
        draw_ellipse(d, (72, 88, 184, 184), mid, width=6)
        draw_poly(d, [(76, 50), (128, 18), (180, 50), (164, 94), (92, 94)], accent, width=7)
        if "devourer" in kind:
            d.arc((42, 42, 214, 214), 20, 330, fill=rgba("#ff7138"), width=13)
            d.arc((63, 63, 193, 193), 205, 150, fill=rgba("#ffd166"), width=9)
            draw_ellipse(d, (104, 104, 152, 152), "#160f18", width=5)
        else:
            draw_poly(d, [(128, 24), (178, 80), (157, 151), (99, 151), (78, 80)], "#4b3f8f", width=7)
            d.line((128, 55, 128, 174), fill=rgba("#c49cff"), width=8)
            d.arc((62, 84, 194, 202), 190, 350, fill=rgba("#8ecaff"), width=9)
        return img

    if kind in {"runner", "biter", "winged"}:
        draw_ellipse(d, (44, 64, 148, 148), dark, width=6)
        draw_ellipse(d, (57, 44, 135, 102), mid, width=5)
        if kind == "winged":
            draw_poly(d, [(49, 72), (12, 39), (30, 119)], "#6fd6ff", width=5)
            draw_poly(d, [(143, 72), (180, 39), (162, 119)], "#6fd6ff", width=5)
        elif kind == "biter":
            draw_poly(d, [(66, 101), (96, 133), (126, 101), (118, 141), (74, 141)], accent, width=4)
        else:
            draw_poly(d, [(52, 78), (26, 96), (52, 114)], accent, width=4)
            draw_poly(d, [(140, 78), (166, 96), (140, 114)], accent, width=4)
    elif kind in {"bruiser", "shield", "bastion"}:
        draw_poly(d, [(47, 62), (145, 62), (158, 140), (128, 164), (64, 164), (34, 140)], dark, width=7)
        draw_ellipse(d, (60, 29, 132, 90), mid, width=6)
        if kind in {"shield", "bastion"}:
            draw_poly(d, [(94, 57), (145, 81), (137, 146), (94, 168), (51, 146), (43, 81)], accent, width=5)
    elif kind in {"summoner", "shaman", "prophet"}:
        draw_poly(d, [(52, 63), (140, 63), (157, 160), (35, 160)], dark, width=6)
        draw_ellipse(d, (58, 24, 134, 86), mid, width=6)
        d.arc((45, 75, 147, 177), 205, 335, fill=rgba(accent), width=7)
        if kind in {"shaman", "prophet"}:
            d.line((96, 36, 96, 151), fill=rgba("#e7dcff"), width=4)
            draw_ellipse(d, (82, 44, 110, 72), accent, width=3)
    elif kind in {"marksman", "mage", "spitter"}:
        draw_poly(d, [(56, 63), (136, 63), (151, 146), (41, 146)], dark, width=6)
        draw_ellipse(d, (59, 25, 133, 84), mid, width=6)
        if kind == "marksman":
            d.line((56, 103, 136, 76), fill=rgba("#f2c36b"), width=8)
        elif kind == "mage":
            draw_ellipse(d, (73, 82, 119, 128), accent, width=4)
            d.line((96, 54, 96, 151), fill=rgba("#bba8ff"), width=4)
        else:
            draw_ellipse(d, (67, 82, 125, 128), "#75d44d", width=4)
            d.arc((61, 90, 131, 152), 20, 160, fill=rgba("#b5ff66"), width=6)
    else:
        draw_poly(d, [(48, 62), (144, 62), (152, 143), (96, 166), (40, 143)], dark, width=6)
        draw_ellipse(d, (58, 25, 134, 84), mid, width=6)
        draw_poly(d, [(42, 73), (20, 51), (61, 61)], accent, width=4)
        draw_poly(d, [(150, 73), (172, 51), (131, 61)], accent, width=4)

    if elite:
        d.arc((29, 28, 163, 170), 190, 350, fill=rgba(accent, 230), width=6)
        draw_ellipse(d, (78, 16, 114, 50), accent, width=3)

    return img


def part_canvas(width: int, height: int) -> Image.Image:
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))


def body_part(size: tuple[int, int], palette: tuple[str, str, str], shape: str = "humanoid", detail: str = "") -> Image.Image:
    img = part_canvas(*size)
    d = ImageDraw.Draw(img)
    accent, mid, dark = palette
    w, h = size
    if "berserk" in detail:
        draw_ellipse(d, (w * 0.03, h * 0.07, w * 0.97, h * 0.97), "#5b3440", width=7)
        draw_ellipse(d, (w * 0.12, h * 0.10, w * 0.88, h * 0.42), "#6b3b45", width=4)
        draw_ellipse(d, (w * 0.18, h * 0.17, w * 0.82, h * 0.72), "#df8357", width=4)
        draw_poly(d, [(w * 0.18, h * 0.57), (w * 0.82, h * 0.57), (w * 0.77, h * 0.78), (w * 0.23, h * 0.78)], "#402633", width=4)
        d.line((w * 0.28, h * 0.58, w * 0.74, h * 0.72), fill=rgba("#ffc36d"), width=5)
        d.line((w * 0.72, h * 0.58, w * 0.26, h * 0.72), fill=rgba("#ffc36d"), width=5)
        d.arc((w * 0.19, h * 0.16, w * 0.81, h * 0.83), 25, 155, fill=rgba("#ffc36d"), width=5)
        draw_pill(d, (w * 0.15, h * 0.76, w * 0.85, h * 0.91), "#30202c", width=4)
        draw_ellipse(d, (w * 0.42, h * 0.76, w * 0.58, h * 0.90), "#ffd166", width=3)
    elif "dark_mage" in detail:
        draw_ellipse(d, (w * 0.05, h * 0.05, w * 0.95, h * 0.99), "#211b38", width=7)
        draw_ellipse(d, (w * 0.24, h * 0.11, w * 0.76, h * 0.74), "#6146b7", width=4)
        draw_poly(d, [(w * 0.18, h * 0.68), (w * 0.82, h * 0.68), (w * 0.96, h * 0.97), (w * 0.04, h * 0.97)], "#1b172e", width=4)
        d.arc((w * 0.07, h * 0.17, w * 0.93, h * 0.97), 205, 335, fill=rgba("#c4a6ff"), width=6)
        d.arc((w * 0.18, h * 0.19, w * 0.82, h * 0.82), 205, 335, fill=rgba(accent), width=4)
        d.line((w * 0.50, h * 0.18, w * 0.50, h * 0.76), fill=rgba("#d9c8ff"), width=4)
        draw_ellipse(d, (w * 0.39, h * 0.52, w * 0.61, h * 0.70), accent, width=3)
    elif "guitarist" in detail:
        draw_ellipse(d, (w * 0.07, h * 0.07, w * 0.93, h * 0.92), "#20213a", width=7)
        draw_ellipse(d, (w * 0.21, h * 0.15, w * 0.79, h * 0.72), "#284b64", width=4)
        draw_ellipse(d, (w * 0.29, h * 0.19, w * 0.71, h * 0.62), "#f1b64e", width=4)
        d.line((w * 0.26, h * 0.14, w * 0.74, h * 0.77), fill=rgba("#151827"), width=6)
        d.line((w * 0.29, h * 0.15, w * 0.77, h * 0.76), fill=rgba("#ffd166"), width=3)
        draw_ellipse(d, (w * 0.45, h * 0.51, w * 0.59, h * 0.65), "#ffd166", width=2)
        draw_ellipse(d, (w * 0.71, h * 0.20, w * 0.98, h * 0.58), "#ffd166", width=3)
        d.arc((w * 0.18, h * 0.30, w * 0.82, h * 0.82), 28, 154, fill=rgba("#f6c35c"), width=4)
    elif shape == "boss_disk":
        draw_ellipse(d, (8, 6, w - 8, h - 6), dark, width=7)
        draw_ellipse(d, (25, 21, w - 25, h - 21), mid, width=5)
        d.arc((12, 10, w - 12, h - 10), 18, 330, fill=rgba(accent), width=9)
    elif shape == "boss_warden":
        draw_poly(d, [(w * 0.50, 6), (w - 18, h * 0.28), (w * 0.77, h - 10), (w * 0.23, h - 10), (18, h * 0.28)], dark, width=7)
        d.line((w * 0.50, 20, w * 0.50, h - 20), fill=rgba(accent), width=7)
        d.arc((18, h * 0.30, w - 18, h - 8), 190, 350, fill=rgba("#8ecaff"), width=7)
    elif "shield" in detail or "bastion" in detail:
        draw_poly(d, [(w * 0.50, 6), (w - 10, h * 0.22), (w - 16, h * 0.74), (w * 0.50, h - 6), (16, h * 0.74), (10, h * 0.22)], dark, width=6)
        draw_poly(d, [(w * 0.50, 15), (w - 24, h * 0.32), (w - 28, h * 0.68), (w * 0.50, h - 22), (28, h * 0.68), (24, h * 0.32)], accent, width=3)
    elif "runner" in detail or "biter" in detail or "stalker" in detail:
        draw_ellipse(d, (10, h * 0.20, w - 10, h - 8), dark, width=5)
        draw_poly(d, [(12, h * 0.46), (w * 0.08, h * 0.30), (w * 0.30, h * 0.34)], accent, width=3)
        draw_poly(d, [(w - 12, h * 0.46), (w * 0.92, h * 0.30), (w * 0.70, h * 0.34)], accent, width=3)
    elif "mage" in detail or "caller" in detail or "shaman" in detail or "prophet" in detail:
        draw_poly(d, [(w * 0.22, h * 0.12), (w * 0.78, h * 0.12), (w - 8, h - 8), (8, h - 8)], dark, width=5)
        d.line((w * 0.50, h * 0.22, w * 0.50, h - 18), fill=rgba(accent), width=5)
    else:
        draw_poly(d, [(w * 0.17, h * 0.12), (w * 0.83, h * 0.12), (w - 10, h * 0.72), (w * 0.50, h - 6), (10, h * 0.72)], dark, width=5)
        draw_poly(d, [(w * 0.32, h * 0.20), (w * 0.68, h * 0.20), (w * 0.62, h * 0.62), (w * 0.38, h * 0.62)], mid, width=3)
    return img


def head_part(size: tuple[int, int], palette: tuple[str, str, str], detail: str = "") -> Image.Image:
    img = part_canvas(*size)
    d = ImageDraw.Draw(img)
    accent, mid, dark = palette
    w, h = size
    if "berserk" in detail:
        draw_ellipse(d, (8, 10, w - 8, h - 8), mid, width=6)
        draw_ellipse(d, (w * 0.20, 0, w * 0.80, h * 0.50), dark, width=4)
        draw_ellipse(d, (w * 0.36, -6, w * 0.64, h * 0.32), dark, width=3)
        draw_ellipse(d, (w * 0.10, h * 0.30, w * 0.34, h * 0.58), dark, width=3)
        draw_ellipse(d, (w * 0.66, h * 0.30, w * 0.90, h * 0.58), dark, width=3)
        d.line((w * 0.25, h * 0.42, w * 0.43, h * 0.48), fill=rgba("#301820"), width=max(3, w // 26))
        d.line((w * 0.75, h * 0.42, w * 0.57, h * 0.48), fill=rgba("#301820"), width=max(3, w // 26))
        d.arc((w * 0.28, h * 0.53, w * 0.72, h * 0.84), 20, 160, fill=rgba("#f4d0a0"), width=max(3, w // 18))
        draw_ellipse(d, (w * 0.32, h * 0.43, w * 0.42, h * 0.54), "#301820", width=1)
        draw_ellipse(d, (w * 0.58, h * 0.43, w * 0.68, h * 0.54), "#301820", width=1)
        d.line((w * 0.30, h * 0.67, w * 0.38, h * 0.75), fill=rgba("#ffd2a0"), width=2)
    elif "dark_mage" in detail:
        draw_ellipse(d, (8, 8, w - 8, h - 6), dark, width=6)
        draw_ellipse(d, (w * 0.24, h * 0.17, w * 0.76, h * 0.78), mid, width=3)
        draw_ellipse(d, (w * 0.40, -3, w * 0.60, h * 0.22), dark, width=2)
        draw_pill(d, (w * 0.18, h * 0.58, w * 0.82, h * 0.94), dark, width=2)
        d.arc((w * 0.20, h * 0.12, w * 0.80, h * 0.72), 205, 335, fill=rgba("#8f7cff"), width=max(3, w // 26))
        draw_ellipse(d, (w * 0.36, h * 0.44, w * 0.45, h * 0.56), accent, width=1)
        draw_ellipse(d, (w * 0.55, h * 0.44, w * 0.64, h * 0.56), accent, width=1)
        draw_ellipse(d, (w * 0.39, h * 0.80, w * 0.61, h * 0.98), accent, width=2)
    elif "guitarist" in detail:
        draw_ellipse(d, (9, 10, w - 9, h - 8), mid, width=6)
        draw_ellipse(d, (w * 0.08, -2, w * 0.92, h * 0.48), dark, width=4)
        draw_ellipse(d, (w * 0.16, h * 0.02, w * 0.52, h * 0.42), dark, width=3)
        draw_ellipse(d, (w * 0.48, h * 0.02, w * 0.88, h * 0.42), dark, width=3)
        draw_pill(d, (w * 0.16, h * 0.35, w * 0.84, h * 0.56), dark, width=2)
        draw_pill(d, (w * 0.25, h * 0.42, w * 0.75, h * 0.57), "#2f314a", width=2)
        draw_ellipse(d, (w * 0.31, h * 0.46, w * 0.41, h * 0.57), "#151827", width=1)
        draw_ellipse(d, (w * 0.59, h * 0.46, w * 0.69, h * 0.57), "#151827", width=1)
        d.arc((w * 0.25, h * 0.54, w * 0.75, h * 0.82), 20, 160, fill=rgba("#f4d38a"), width=max(3, w // 18))
    else:
        draw_ellipse(d, (8, 8, w - 8, h - 8), mid, width=5)
    if ("mage" in detail and "dark_mage" not in detail) or "shaman" in detail or "prophet" in detail:
        draw_poly(d, [(w * 0.10, h * 0.48), (w * 0.50, 2), (w * 0.90, h * 0.48), (w * 0.78, h - 12), (w * 0.22, h - 12)], dark, width=4)
        draw_ellipse(d, (w * 0.38, h * 0.42, w * 0.45, h * 0.52), accent, width=1)
        draw_ellipse(d, (w * 0.55, h * 0.42, w * 0.62, h * 0.52), accent, width=1)
    elif "disk" in detail:
        draw_ellipse(d, (w * 0.30, h * 0.25, w * 0.70, h * 0.68), dark, width=3)
    elif not any(token in detail for token in ["berserk", "dark_mage", "guitarist"]):
        draw_ellipse(d, (w * 0.34, h * 0.42, w * 0.44, h * 0.54), dark, width=1)
        draw_ellipse(d, (w * 0.56, h * 0.42, w * 0.66, h * 0.54), dark, width=1)
        d.arc((w * 0.28, h * 0.44, w * 0.72, h * 0.80), 20, 160, fill=rgba(accent), width=max(2, w // 20))
    return img


def limb_part(size: tuple[int, int], color: str, accent: str, kind: str = "arm", detail: str = "") -> Image.Image:
    img = part_canvas(*size)
    d = ImageDraw.Draw(img)
    w, h = size
    draw_pill(d, (w * 0.10, 2, w * 0.90, h - 10), color, width=3)
    if "berserk" in detail and kind == "arm":
        draw_ellipse(d, (w * -0.05, 0, w * 1.05, h * 0.32), "#6b3b45", width=2)
        draw_pill(d, (w * 0.02, h * 0.55, w * 0.98, h * 0.82), "#4b2937", width=2)
        d.line((w * 0.25, h * 0.60, w * 0.75, h * 0.76), fill=rgba("#ffc36d"), width=2)
    elif "dark_mage" in detail and kind == "arm":
        draw_pill(d, (w * 0.02, h * 0.50, w * 0.98, h * 0.82), "#211b38", width=2)
        draw_ellipse(d, (w * 0.15, h * 0.68, w * 0.85, h * 0.92), accent, width=2)
    elif "guitarist" in detail and kind == "arm":
        draw_pill(d, (w * 0.02, h * 0.50, w * 0.98, h * 0.80), "#1f2034", width=2)
        d.line((w * 0.24, h * 0.14, w * 0.76, h * 0.14), fill=rgba("#ffd166"), width=2)
    if kind == "leg":
        if "berserk" in detail:
            draw_pill(d, (w * 0.02, h * 0.58, w * 0.98, h - 8), "#3d2532", width=2)
        elif "dark_mage" in detail:
            draw_pill(d, (w * 0.05, h * 0.18, w * 0.95, h - 8), "#1b172e", width=2)
        elif "guitarist" in detail:
            draw_pill(d, (w * 0.05, h * 0.56, w * 0.95, h - 8), "#151827", width=2)
        draw_ellipse(d, (w * 0.10, h - 20, w * 0.90, h - 2), accent, width=3)
    else:
        draw_ellipse(d, (w * 0.16, h - 18, w * 0.84, h - 2), accent, width=3)
    return img


def wing_part(size: tuple[int, int], palette: tuple[str, str, str], side: str) -> Image.Image:
    img = part_canvas(*size)
    d = ImageDraw.Draw(img)
    accent, mid, dark = palette
    w, h = size
    if side == "l":
        points = [(w - 4, h * 0.20), (6, 4), (18, h - 8), (w * 0.72, h * 0.72)]
    else:
        points = [(4, h * 0.20), (w - 6, 4), (w - 18, h - 8), (w * 0.28, h * 0.72)]
    draw_poly(d, points, accent, outline=dark, width=4)
    d.line((w * 0.50, h * 0.18, w * 0.50, h * 0.82), fill=rgba(mid), width=3)
    return img


def secondary_part(size: tuple[int, int], palette: tuple[str, str, str], detail: str = "") -> Image.Image:
    img = part_canvas(*size)
    d = ImageDraw.Draw(img)
    accent, _mid, dark = palette
    w, h = size
    if "dark_mage" in detail:
        d.arc((4, h * 0.06, w - 4, h - 4), 190, 350, fill=rgba("#c4a6ff"), width=max(5, w // 10))
        d.arc((w * 0.16, h * 0.16, w * 0.84, h - 7), 205, 335, fill=rgba(accent), width=max(3, w // 16))
        draw_poly(d, [(w * 0.20, h * 0.30), (w * 0.50, h * 0.02), (w * 0.80, h * 0.30), (w * 0.66, h * 0.48), (w * 0.34, h * 0.48)], dark, width=2)
        draw_ellipse(d, (w * 0.44, h * 0.38, w * 0.56, h * 0.54), "#d9c8ff", width=1)
    elif "guitarist" in detail:
        d.arc((4, h * 0.18, w - 4, h - 8), 205, 335, fill=rgba("#f6c35c"), width=max(5, w // 11))
        draw_ellipse(d, (w * 0.64, h * 0.08, w * 0.88, h * 0.42), "#ffd166", width=2)
        d.line((w * 0.20, h * 0.30, w * 0.72, h * 0.68), fill=rgba(dark), width=max(3, w // 17))
        draw_ellipse(d, (w * 0.42, h * 0.46, w * 0.56, h * 0.64), "#ffd166", width=1)
    elif "disk" in detail:
        d.arc((4, 4, w - 4, h - 4), 20, 330, fill=rgba(accent), width=max(4, w // 9))
    elif "warden" in detail:
        d.arc((4, h * 0.10, w - 4, h - 4), 190, 350, fill=rgba("#8ecaff"), width=max(4, w // 10))
    else:
        d.arc((4, h * 0.18, w - 4, h - 4), 205, 335, fill=rgba(accent), width=max(3, w // 14))
        draw_ellipse(d, (w * 0.42, 2, w * 0.58, h * 0.18), dark, width=2)
    return img


def save_rig_parts(base_dir: str, entity_id: str, palette: tuple[str, str, str], tier: str = "enemy", detail: str = "") -> None:
    if tier == "character":
        body_size, head_size, limb_size = (160, 210), (144, 120), (28, 80)
    elif tier == "boss":
        body_size, head_size, limb_size = (148, 128), (104, 74), (34, 68)
    else:
        body_size, head_size, limb_size = (96, 96), (80, 58), (18, 48)
    accent, mid, dark = palette
    body_shape = "boss_disk" if "devourer" in detail else "boss_warden" if "warden" in detail else "humanoid"
    save(body_part(body_size, palette, body_shape, detail), f"{base_dir}/rig_parts/{entity_id}_body.png")
    save(head_part(head_size, palette, detail), f"{base_dir}/rig_parts/{entity_id}_head.png")
    save(limb_part(limb_size, mid, accent, "arm", detail), f"{base_dir}/rig_parts/{entity_id}_arm_l.png")
    save(limb_part(limb_size, mid, accent, "arm", detail), f"{base_dir}/rig_parts/{entity_id}_arm_r.png")
    save(limb_part(limb_size, dark, mid, "leg", detail), f"{base_dir}/rig_parts/{entity_id}_leg_l.png")
    save(limb_part(limb_size, dark, mid, "leg", detail), f"{base_dir}/rig_parts/{entity_id}_leg_r.png")
    if "winged" in detail:
        save(wing_part((58, 72), palette, "l"), f"{base_dir}/rig_parts/{entity_id}_wing_l.png")
        save(wing_part((58, 72), palette, "r"), f"{base_dir}/rig_parts/{entity_id}_wing_r.png")
    if tier in {"elite", "boss"} or any(token in detail for token in ["mage", "shaman", "caller", "prophet", "guitarist"]):
        save(secondary_part((96 if tier != "boss" else 144, 72 if tier != "boss" else 112), palette, detail), f"{base_dir}/rig_parts/{entity_id}_secondary.png")


def berserk_walk_sheet() -> Image.Image:
    frame = 384
    sheet = Image.new("RGBA", (frame * 6, frame * 2), (0, 0, 0, 0))
    base = character_sprite("berserk", ("#ff9c5f", "#b75a45", "#5b3440")).resize((384, 384), Image.Resampling.LANCZOS)
    for i in range(2):
        f = base.copy()
        sheet.alpha_composite(f, (i * frame, 0))
    for i in range(6):
        f = base.copy()
        dx = int((i % 3 - 1) * 5)
        dy = -abs((i % 3) - 1) * 3
        f = f.transform(f.size, Image.Transform.AFFINE, (1, 0.02 * ((i % 2) * 2 - 1), dx, 0, 1, dy), resample=Image.Resampling.BICUBIC)
        sheet.alpha_composite(f, (i * frame, frame))
    return sheet


def main() -> None:
    character_specs = {
        "berserk": ("berserk", ("#ff9c5f", "#b75a45", "#5b3440")),
        "dark_mage": ("dark_mage", ("#9b77ff", "#5840a8", "#211b38")),
        "guitarist": ("guitarist", ("#ffd166", "#3e7696", "#20213a")),
    }
    save(character_sprite("berserk", ("#ff9c5f", "#b75a45", "#5b3440")), "assets/sprites/characters/berserk_unarmed.png")
    save(character_sprite("dark_mage", ("#9b77ff", "#5840a8", "#211b38")), "assets/sprites/characters/dark_mage.png")
    save(character_sprite("guitarist", ("#ffd166", "#3e7696", "#20213a")), "assets/sprites/characters/guitarist.png")
    save(berserk_walk_sheet(), "assets/sprites/characters/berserk_walk_sheet_v2.png")
    for entity_id, (_kind, palette) in character_specs.items():
        save_rig_parts("assets/sprites/characters", entity_id, palette, "character", entity_id)

    enemy_specs = {
        "enemy_melee.png": ("rift_cutter", "cutter", ("#ff5a4f", "#9a4a3f", "#513137")),
        "enemy_ranged.png": ("ash_marksman", "marksman", ("#f2b861", "#665f66", "#353844")),
        "enemy_suicide_runner.png": ("spark_runner", "runner", ("#ffd34d", "#cb5a3d", "#4b2c36")),
        "enemy_bruiser_slow.png": ("stone_bruiser", "bruiser", ("#9aa3ad", "#646b72", "#3f424a")),
        "enemy_summoner.png": ("bone_caller", "summoner", ("#b68cff", "#614a86", "#2b2340")),
        "enemy_void_mage.png": ("void_mage", "mage", ("#8f7cff", "#45356f", "#1d1a32")),
        "enemy_venom_spitter.png": ("venom_spitter", "spitter", ("#92e85d", "#566c44", "#28352c")),
        "enemy_rift_shieldbearer.png": ("rift_shieldbearer", "shield", ("#8ed4ff", "#596a7d", "#2f3947")),
        "enemy_small_biter.png": ("small_biter", "biter", ("#ffb14a", "#89473a", "#35242a")),
        "enemy_bone_shaman.png": ("bone_shaman", "shaman", ("#d8c8ff", "#665781", "#2e283b")),
        "enemy_winged_spark.png": ("winged_spark", "winged", ("#74d6ff", "#f5bd42", "#2b4058")),
    }
    for filename, (entity_id, kind, palette) in enemy_specs.items():
        save(enemy_sprite(kind, palette), f"assets/sprites/enemies/{filename}")
        save_rig_parts("assets/sprites/enemies", entity_id, palette, "enemy", kind)

    elite_specs = {
        "iron_bastion.png": ("iron_bastion", "bastion", ("#9be3ff", "#627182", "#303641")),
        "night_stalker.png": ("night_stalker", "runner", ("#ff6dcb", "#4d315d", "#1d182a")),
        "plague_prophet.png": ("plague_prophet", "prophet", ("#a8ff5f", "#556f42", "#222d27")),
        "shard_marshal.png": ("shard_marshal", "shaman", ("#ffd166", "#6d577a", "#2f2638")),
    }
    for filename, (entity_id, kind, palette) in elite_specs.items():
        save(enemy_sprite(kind, palette, elite=True), f"assets/sprites/elites/{filename}")
        save_rig_parts("assets/sprites/elites", entity_id, palette, "elite", kind)

    boss_specs = {
        "boss_rift_warden.png": ("rift_warden", "rift_warden", ("#b9a0ff", "#4b3f8f", "#211b35")),
        "boss_disk_devourer.png": ("disk_devourer", "devourer", ("#ff7138", "#823b43", "#251720")),
    }
    for filename, (entity_id, kind, palette) in boss_specs.items():
        save(enemy_sprite(kind, palette, boss=True), f"assets/sprites/bosses/{filename}")
        save_rig_parts("assets/sprites/bosses", entity_id, palette, "boss", kind)


if __name__ == "__main__":
    main()
