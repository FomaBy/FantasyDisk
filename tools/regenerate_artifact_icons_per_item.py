#!/usr/bin/env python3
"""Per-item artifact icon regeneration for FantasyDisk.

The script draws each canonical ProgressionData.ARTIFACTS item from scratch,
validates it immediately, and only then moves to the next artifact.
"""

from __future__ import annotations

import math
import random
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

import validate_artifact_icons as validator


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "sprites" / "ui" / "icons" / "artifacts"
PROGRESSION_DATA = ROOT / "scripts" / "progression_data.gd"
TASK_FILE = ROOT / "docs" / "tasks" / "codex_design_artifact_icons_per_item_regen_task.md"
SIZE = 256
SCALE = 4
CANVAS = SIZE * SCALE


PALETTES = {
    "iron": ((38, 41, 48), (104, 111, 122), (194, 205, 212), (10, 9, 12)),
    "gold": ((82, 52, 16), (183, 125, 35), (255, 210, 104), (22, 13, 7)),
    "red": ((72, 14, 20), (178, 40, 44), (255, 108, 80), (18, 5, 7)),
    "violet": ((39, 18, 61), (105, 48, 166), (202, 111, 255), (11, 5, 18)),
    "blue": ((21, 45, 62), (57, 133, 169), (155, 235, 255), (5, 12, 18)),
    "green": ((30, 56, 29), (79, 139, 58), (164, 236, 117), (7, 15, 8)),
    "bone": ((78, 66, 48), (162, 143, 103), (236, 218, 166), (17, 13, 9)),
    "leather": ((61, 33, 20), (132, 74, 42), (220, 145, 78), (16, 8, 5)),
}


def parse_artifacts() -> list[dict[str, object]]:
    text = PROGRESSION_DATA.read_text(encoding="utf-8")
    block = text.split("const ARTIFACTS :=", 1)[1].split("const LEVEL_UP_REWARDS", 1)[0]
    artifacts: list[dict[str, object]] = []
    for line in block.splitlines():
        if '"id":' not in line:
            continue
        artifact_id = re.search(r'"id":\s*"([^"]+)"', line)
        title = re.search(r'"title":\s*"([^"]+)"', line)
        description = re.search(r'"description":\s*"([^"]+)"', line)
        tier = re.search(r'"tier":\s*([0-9]+)', line)
        if artifact_id:
            artifacts.append(
                {
                    "id": artifact_id.group(1),
                    "title": title.group(1) if title else artifact_id.group(1),
                    "description": description.group(1) if description else "",
                    "tier": int(tier.group(1)) if tier else 1,
                }
            )
    return artifacts


def sc(v: float) -> int:
    return int(round(v * SCALE))


def rgba(color: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return color[0], color[1], color[2], alpha


def palette_for(artifact_id: str, tier: int) -> tuple[tuple[int, int, int], ...]:
    if any(key in artifact_id for key in ("blood", "rage", "heart", "sigil", "pact")):
        return PALETTES["red"]
    if any(key in artifact_id for key in ("void", "dark", "skull", "cursed", "phantom", "split", "echo")):
        return PALETTES["violet"]
    if any(key in artifact_id for key in ("coin", "gold", "crown", "compass", "belt", "charm", "amulet")):
        return PALETTES["gold"]
    if any(key in artifact_id for key in ("glass", "lens", "swift", "quick", "silver")):
        return PALETTES["blue"]
    if any(key in artifact_id for key in ("root", "seed", "thorn", "stone")):
        return PALETTES["green"]
    if any(key in artifact_id for key in ("page", "codex", "manual", "boots", "purse")):
        return PALETTES["leather"]
    if tier >= 3:
        return PALETTES["violet"]
    return PALETTES["iron"]


class IconPainter:
    def __init__(self, artifact_id: str, tier: int) -> None:
        self.artifact_id = artifact_id
        self.tier = tier
        self.rng = random.Random(artifact_id)
        self.base, self.mid, self.light, self.dark = palette_for(artifact_id, tier)
        self.layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.layer, "RGBA")

    def ellipse(self, box: tuple[float, float, float, float], fill, outline=None, width: int = 3) -> None:
        b = tuple(sc(v) for v in box)
        if outline:
            self.draw.ellipse(b, fill=outline, width=sc(width))
            inset = sc(width)
            b2 = (b[0] + inset, b[1] + inset, b[2] - inset, b[3] - inset)
            self.draw.ellipse(b2, fill=fill)
        else:
            self.draw.ellipse(b, fill=fill)

    def rect(self, box: tuple[float, float, float, float], fill, outline=None, width: int = 3, radius: float = 0) -> None:
        b = tuple(sc(v) for v in box)
        if radius:
            self.draw.rounded_rectangle(b, radius=sc(radius), fill=fill, outline=outline, width=sc(width) if outline else 1)
        else:
            self.draw.rectangle(b, fill=fill, outline=outline, width=sc(width) if outline else 1)

    def poly(self, pts: list[tuple[float, float]], fill, outline=None, width: int = 4) -> None:
        p = [(sc(x), sc(y)) for x, y in pts]
        if outline:
            self.draw.line(p + [p[0]], fill=outline, width=sc(width * 2), joint="curve")
        self.draw.polygon(p, fill=fill)
        if outline:
            self.draw.line(p + [p[0]], fill=outline, width=sc(width), joint="curve")

    def line(self, pts: list[tuple[float, float]], fill, width: int = 6) -> None:
        p = [(sc(x), sc(y)) for x, y in pts]
        self.draw.line(p, fill=fill, width=sc(width), joint="curve")

    def add_scratches(self, count: int = 5) -> None:
        for _ in range(count):
            x = self.rng.randint(78, 178)
            y = self.rng.randint(74, 180)
            length = self.rng.randint(12, 32)
            self.line([(x, y), (x + length, y - self.rng.randint(4, 13))], rgba(self.light, 70), 2)
            self.line([(x + 2, y + 3), (x + length + 2, y - self.rng.randint(1, 8) + 3)], rgba(self.dark, 80), 1)

    def glow(self, alpha: Image.Image) -> Image.Image:
        glow_alpha = alpha.filter(ImageFilter.GaussianBlur(sc(8 + self.tier * 2))).point(
            lambda a: min(120, int(a * (0.18 + self.tier * 0.07)))
        )
        glow = Image.new("RGBA", (CANVAS, CANVAS), rgba(self.light, 0))
        glow.putalpha(glow_alpha)
        return glow

    def finish(self) -> Image.Image:
        alpha = self.layer.getchannel("A")
        shadow = Image.new("RGBA", (CANVAS, CANVAS), (5, 3, 8, 0))
        shadow_alpha = alpha.filter(ImageFilter.GaussianBlur(sc(3))).point(lambda a: min(150, int(a * 0.45)))
        shadow.putalpha(ImageChops.offset(shadow_alpha, sc(5), sc(8)))

        outline_alpha = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(sc(3) | 1)), alpha)
        outline = Image.new("RGBA", (CANVAS, CANVAS), (6, 5, 8, 0))
        outline.putalpha(outline_alpha.point(lambda a: min(230, int(a * 1.4))))

        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.alpha_composite(shadow)
        canvas.alpha_composite(self.glow(alpha))
        canvas.alpha_composite(outline)
        canvas.alpha_composite(self.layer)

        # Upper-left painterly light pass clipped by existing alpha.
        light = Image.new("RGBA", (CANVAS, CANVAS), (255, 238, 190, 0))
        light_draw = ImageDraw.Draw(light, "RGBA")
        light_draw.ellipse((sc(42), sc(30), sc(184), sc(154)), fill=(255, 238, 190, 34))
        light.putalpha(ImageChops.multiply(light.getchannel("A"), canvas.getchannel("A")))
        canvas.alpha_composite(light)

        out = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        out = ImageEnhance.Color(out).enhance(1.08)
        out = ImageEnhance.Contrast(out).enhance(1.05)
        return out


def draw_amulet(p: IconPainter, sharp: bool = False) -> None:
    p.ellipse((88, 28, 168, 86), rgba(p.dark), rgba((8, 6, 8)), 5)
    p.ellipse((101, 39, 155, 76), (0, 0, 0, 0), rgba(p.mid), 6)
    pts = [(128, 72), (181, 112), (166, 190), (128, 224), (89, 190), (75, 112)]
    if sharp:
        pts = [(128, 66), (188, 118), (156, 214), (128, 191), (100, 214), (68, 118)]
    p.poly(pts, rgba(p.mid), rgba((7, 6, 8)), 5)
    p.poly([(128, 96), (154, 124), (144, 164), (128, 181), (112, 164), (102, 124)], rgba(p.base, 245), rgba(p.dark), 3)
    p.line([(106, 130), (150, 122), (132, 169)], rgba(p.light, 155), 3)
    p.add_scratches(4)


def draw_boots(p: IconPainter, ghost: bool = False) -> None:
    fill = rgba(p.mid, 235 if ghost else 255)
    p.rect((72, 66, 119, 177), fill, rgba((7, 5, 6)), 5, 13)
    p.poly([(72, 153), (128, 153), (141, 178), (132, 203), (76, 199), (61, 181)], fill, rgba((7, 5, 6)), 5)
    p.rect((137, 66, 184, 177), fill, rgba((7, 5, 6)), 5, 13)
    p.poly([(137, 153), (196, 153), (207, 181), (191, 200), (137, 203), (125, 178)], fill, rgba((7, 5, 6)), 5)
    p.rect((100, 106, 157, 126), rgba(p.dark), None, 1, 7)
    p.line([(83, 90), (108, 108), (138, 108), (174, 91)], rgba(p.light, 180), 3)
    p.line([(91, 134), (113, 139), (143, 139), (166, 134)], rgba(p.light, 130), 3)


def draw_orb(p: IconPainter, cracked: bool = False) -> None:
    p.rect((91, 176, 165, 207), rgba(p.dark), rgba((7, 5, 8)), 5, 10)
    p.rect((108, 148, 148, 183), rgba(p.mid), rgba((7, 5, 8)), 4, 8)
    p.ellipse((62, 42, 194, 174), rgba(p.mid, 215), rgba((7, 5, 10)), 6)
    p.ellipse((83, 59, 142, 112), rgba(p.light, 120), None)
    p.ellipse((95, 75, 180, 159), rgba(p.base, 80), None)
    if cracked:
        p.line([(128, 53), (118, 92), (137, 115), (123, 155)], rgba((246, 250, 255), 180), 3)
        p.line([(137, 115), (162, 105)], rgba((246, 250, 255), 120), 2)


def draw_lens(p: IconPainter) -> None:
    p.ellipse((57, 40, 181, 164), rgba(p.mid, 220), rgba((8, 6, 7)), 7)
    p.ellipse((78, 60, 160, 143), rgba(p.light, 95), rgba(p.dark), 4)
    p.line([(154, 150), (199, 202)], rgba((9, 7, 8)), 16)
    p.line([(154, 150), (199, 202)], rgba(p.mid), 10)
    p.line([(88, 85), (139, 72)], rgba((245, 255, 255), 130), 3)


def draw_core(p: IconPainter, split: bool = False) -> None:
    sides = 10
    pts = []
    for i in range(sides):
        ang = -math.pi / 2 + i * math.tau / sides
        r = 78 if i % 2 == 0 else 58
        pts.append((128 + math.cos(ang) * r, 126 + math.sin(ang) * r))
    p.poly(pts, rgba(p.mid), rgba((7, 5, 9)), 5)
    p.ellipse((93, 89, 162, 158), rgba(p.light, 150), None)
    p.line([(92, 128), (164, 128)], rgba(p.dark, 190), 5)
    if split:
        p.line([(128, 53), (119, 94), (136, 126), (118, 194)], rgba((250, 245, 255), 190), 4)
    p.add_scratches(3)


def draw_book(p: IconPainter, page: bool = False) -> None:
    if page:
        p.poly([(83, 43), (175, 35), (185, 205), (93, 219), (72, 118)], rgba(p.mid), rgba((8, 5, 4)), 5)
        p.line([(101, 73), (162, 68)], rgba(p.dark, 110), 2)
        p.line([(98, 103), (166, 96)], rgba(p.dark, 110), 2)
        p.line([(97, 140), (169, 132)], rgba(p.dark, 110), 2)
        p.poly([(139, 43), (176, 36), (168, 68)], rgba((46, 26, 18), 200), None)
        return
    p.poly([(66, 60), (128, 45), (190, 61), (190, 205), (128, 221), (65, 205)], rgba(p.dark), rgba((8, 5, 4)), 5)
    p.poly([(73, 68), (124, 58), (124, 206), (73, 194)], rgba(p.mid), rgba(p.dark), 3)
    p.poly([(132, 58), (183, 68), (183, 194), (132, 206)], rgba(tuple(max(0, c - 18) for c in p.mid)), rgba(p.dark), 3)
    p.line([(128, 58), (128, 209)], rgba((12, 7, 5)), 4)
    p.ellipse((103, 108, 153, 158), rgba(p.light, 125), rgba(p.dark), 3)


def draw_heart(p: IconPainter, stone: bool = False, leech: bool = False) -> None:
    col = PALETTES["green"][1] if stone else p.mid
    p.ellipse((66, 58, 132, 128), rgba(col), rgba((8, 5, 7)), 5)
    p.ellipse((124, 58, 190, 128), rgba(col), rgba((8, 5, 7)), 5)
    p.poly([(66, 98), (190, 98), (172, 172), (128, 219), (84, 172)], rgba(col), rgba((8, 5, 7)), 5)
    p.line([(98, 94), (128, 82), (156, 101)], rgba(p.light, 135), 3)
    if leech:
        p.line([(86, 159), (128, 188), (170, 159)], rgba((18, 4, 8), 180), 5)
    else:
        p.line([(128, 83), (116, 122), (137, 149), (125, 197)], rgba(p.dark, 130), 3)


def draw_seed_banner(p: IconPainter) -> None:
    p.ellipse((87, 113, 169, 205), rgba(p.mid), rgba((7, 5, 6)), 5)
    p.line([(128, 111), (128, 49)], rgba(p.dark), 9)
    p.poly([(129, 52), (186, 68), (137, 92)], rgba(PALETTES["red"][1]), rgba((8, 5, 5)), 4)
    p.line([(100, 138), (128, 115), (157, 139)], rgba(p.light, 150), 4)


def draw_whetstone(p: IconPainter) -> None:
    p.poly([(52, 139), (153, 58), (200, 105), (99, 200)], rgba(p.mid), rgba((8, 5, 5)), 5)
    p.line([(69, 143), (160, 74)], rgba(p.light, 145), 4)
    p.line([(98, 181), (190, 96)], rgba(p.dark, 140), 4)
    p.rect((82, 157, 154, 177), rgba(PALETTES["red"][1], 200), None, 1, 8)


def draw_compass(p: IconPainter) -> None:
    p.ellipse((53, 43, 203, 193), rgba(p.mid), rgba((7, 5, 7)), 6)
    p.ellipse((76, 66, 180, 170), rgba(p.base), rgba(p.dark), 4)
    p.poly([(128, 74), (144, 127), (128, 180), (112, 127)], rgba(p.light), rgba((9, 6, 8)), 3)
    p.poly([(75, 127), (128, 111), (181, 127), (128, 143)], rgba(PALETTES["red"][1], 220), rgba((9, 6, 8)), 3)
    p.ellipse((115, 114, 141, 140), rgba(p.dark), None)


def draw_root(p: IconPainter, thorn: bool = False) -> None:
    p.line([(128, 42), (126, 85), (136, 128), (116, 178), (126, 221)], rgba((8, 5, 5)), 23)
    p.line([(128, 42), (126, 85), (136, 128), (116, 178), (126, 221)], rgba(p.mid), 15)
    p.line([(125, 128), (78, 101), (61, 67)], rgba((8, 5, 5)), 18)
    p.line([(125, 128), (78, 101), (61, 67)], rgba(p.mid), 10)
    p.line([(130, 134), (181, 116), (202, 84)], rgba((8, 5, 5)), 18)
    p.line([(130, 134), (181, 116), (202, 84)], rgba(p.mid), 10)
    p.line([(121, 174), (81, 213)], rgba((8, 5, 5)), 16)
    p.line([(121, 174), (81, 213)], rgba(p.mid), 8)
    if thorn:
        for x, y in [(93, 111), (153, 124), (113, 169), (130, 83)]:
            p.poly([(x, y), (x + 20, y - 12), (x + 6, y + 12)], rgba(p.light), rgba((6, 5, 5)), 2)


def draw_coin(p: IconPainter, route: bool = False) -> None:
    p.ellipse((55, 47, 201, 193), rgba(p.mid), rgba((8, 5, 3)), 7)
    p.ellipse((79, 71, 177, 169), rgba(p.base), rgba(p.dark), 4)
    if route:
        p.line([(92, 140), (118, 100), (145, 132), (166, 90)], rgba(p.light), 8)
    else:
        p.poly([(128, 84), (142, 116), (176, 119), (150, 140), (160, 174), (128, 154), (96, 174), (106, 140), (80, 119), (114, 116)], rgba(p.light, 170), None)


def draw_string_or_cable(p: IconPainter, cable: bool = False) -> None:
    width = 16 if cable else 9
    p.line([(75, 75), (119, 42), (178, 68), (187, 131), (143, 188), (82, 168), (75, 75)], rgba((7, 5, 6)), width + 8)
    p.line([(75, 75), (119, 42), (178, 68), (187, 131), (143, 188), (82, 168), (75, 75)], rgba(p.mid), width)
    p.rect((111, 179, 151, 213), rgba(p.dark), rgba((7, 5, 5)), 4, 8)
    p.line([(122, 185), (142, 206)], rgba(p.light, 130), 3)


def draw_totem(p: IconPainter) -> None:
    p.poly([(96, 48), (160, 48), (177, 190), (128, 211), (79, 190)], rgba(p.mid), rgba((7, 5, 5)), 6)
    p.ellipse((99, 74, 157, 129), rgba(p.base), rgba(p.dark), 4)
    p.rect((98, 142, 158, 168), rgba(p.dark), None, 1, 8)
    p.line([(108, 94), (122, 108), (148, 90)], rgba(p.light, 130), 4)


def draw_gloves(p: IconPainter) -> None:
    p.rect((68, 93, 123, 178), rgba(p.mid), rgba((7, 5, 5)), 5, 17)
    p.rect((133, 93, 188, 178), rgba(p.mid), rgba((7, 5, 5)), 5, 17)
    p.rect((104, 139, 152, 160), rgba(p.dark), None, 1, 8)
    for x in (78, 91, 104, 143, 156, 169):
        p.line([(x, 91), (x - 4, 132)], rgba(p.light, 90), 2)


def draw_sigil(p: IconPainter) -> None:
    p.ellipse((51, 48, 205, 202), rgba(p.mid), rgba((7, 5, 7)), 7)
    p.ellipse((78, 75, 178, 175), rgba(p.dark), rgba(p.light, 150), 3)
    p.poly([(128, 79), (172, 155), (84, 155)], rgba(p.light, 120), rgba(p.base), 3)
    p.line([(88, 128), (168, 128)], rgba(p.light, 160), 4)
    p.line([(128, 84), (128, 171)], rgba(p.light, 150), 4)


def draw_ink(p: IconPainter, candle: bool = False) -> None:
    p.rect((88, 91, 168, 205), rgba(p.mid), rgba((7, 5, 8)), 5, 18)
    p.rect((99, 65, 157, 103), rgba(p.dark), rgba((7, 5, 8)), 4, 10)
    if candle:
        p.rect((116, 54, 140, 105), rgba(PALETTES["bone"][2]), rgba((7, 5, 5)), 3, 9)
        p.poly([(128, 32), (142, 58), (128, 70), (114, 58)], rgba(PALETTES["red"][2]), rgba((9, 4, 2)), 3)
    else:
        p.line([(151, 78), (194, 34)], rgba((7, 5, 5)), 13)
        p.line([(151, 78), (194, 34)], rgba(p.light), 7)
    p.ellipse((105, 122, 151, 169), rgba(p.dark, 170), rgba(p.light, 120), 3)


def draw_bell(p: IconPainter) -> None:
    p.ellipse((98, 43, 158, 91), rgba(p.mid), rgba((7, 5, 5)), 5)
    p.poly([(86, 78), (170, 78), (190, 185), (66, 185)], rgba(p.mid), rgba((7, 5, 5)), 6)
    p.ellipse((66, 167, 190, 213), rgba(p.dark), rgba((7, 5, 5)), 5)
    p.ellipse((112, 180, 144, 216), rgba(p.light), rgba((7, 5, 5)), 4)
    p.line([(96, 118), (160, 118)], rgba(p.light, 110), 3)


def draw_buckle(p: IconPainter) -> None:
    p.rect((48, 75, 208, 180), rgba(p.mid), rgba((7, 5, 5)), 7, 30)
    p.rect((82, 103, 174, 153), (0, 0, 0, 0), rgba(p.dark), 8, 18)
    p.line([(87, 128), (175, 128)], rgba(p.light, 170), 6)
    p.poly([(121, 68), (144, 68), (132, 94)], rgba(PALETTES["red"][1]), None)


def draw_shield(p: IconPainter) -> None:
    p.poly([(128, 38), (190, 70), (177, 174), (128, 222), (79, 174), (66, 70)], rgba(p.mid), rgba((7, 5, 5)), 6)
    p.poly([(128, 60), (166, 83), (156, 162), (128, 190), (100, 162), (90, 83)], rgba(p.base), rgba(p.dark), 3)
    p.line([(98, 82), (153, 127), (124, 188)], rgba(p.dark, 180), 4)


def draw_blade(p: IconPainter, glass: bool = False) -> None:
    fill = rgba(p.mid, 195 if glass else 255)
    p.poly([(70, 190), (139, 39), (184, 63), (116, 208)], fill, rgba((7, 5, 6)), 6)
    p.line([(138, 54), (119, 189)], rgba(p.light, 145), 3)
    p.rect((77, 184, 129, 213), rgba(PALETTES["leather"][1]), rgba((7, 5, 5)), 4, 7)
    if not glass:
        for x, y in [(128, 83), (119, 117), (108, 150)]:
            p.poly([(x, y), (x + 21, y + 4), (x + 2, y + 16)], rgba(p.dark), None)


def draw_grip(p: IconPainter) -> None:
    p.rect((93, 47, 163, 208), rgba(PALETTES["leather"][1]), rgba((7, 5, 5)), 6, 19)
    for y in range(72, 184, 24):
        p.line([(98, y), (158, y + 28)], rgba(p.light, 125), 5)
        p.line([(98, y + 14), (158, y + 42)], rgba(p.dark, 135), 4)
    p.rect((78, 37, 178, 70), rgba(p.mid), rgba((7, 5, 5)), 5, 10)
    p.rect((82, 197, 174, 224), rgba(p.mid), rgba((7, 5, 5)), 5, 10)


def draw_belt(p: IconPainter) -> None:
    p.line([(54, 135), (89, 84), (153, 68), (202, 104), (190, 164), (131, 192), (74, 174), (54, 135)], rgba((7, 5, 5)), 28)
    p.line([(54, 135), (89, 84), (153, 68), (202, 104), (190, 164), (131, 192), (74, 174), (54, 135)], rgba(PALETTES["leather"][1]), 20)
    p.rect((103, 101, 158, 151), rgba(p.mid), rgba((7, 5, 5)), 5, 10)
    p.rect((119, 113, 146, 139), (0, 0, 0, 0), rgba(p.dark), 4, 6)


def draw_crystal(p: IconPainter, burning: bool = False) -> None:
    top = 43 if burning else 32
    bottom = 211 if burning else 226
    side_y = 193 if burning else 203
    p.poly([(128, top), (174, 88), (156, side_y), (128, bottom), (100, side_y), (82, 88)], rgba(p.mid), rgba((7, 5, 9)), 6)
    p.poly([(128, top), (128, bottom), (100, side_y), (82, 88)], rgba(p.base, 190), None)
    p.line([(128, top + 10), (156, side_y - 6)], rgba(p.light, 135), 3)
    if burning:
        p.poly([(111, 60), (128, 34), (146, 61), (136, 86), (120, 85)], rgba(PALETTES["red"][2], 190), rgba((8, 4, 2)), 3)


def draw_skull(p: IconPainter) -> None:
    p.ellipse((74, 49, 182, 153), rgba(PALETTES["bone"][1]), rgba((7, 5, 5)), 6)
    p.rect((93, 128, 163, 197), rgba(PALETTES["bone"][1]), rgba((7, 5, 5)), 5, 12)
    p.ellipse((94, 88, 121, 117), rgba((10, 6, 8)), None)
    p.ellipse((135, 88, 162, 117), rgba((10, 6, 8)), None)
    p.poly([(128, 115), (139, 142), (117, 142)], rgba((13, 8, 7)), None)
    p.ellipse((70, 166, 186, 217), (0, 0, 0, 0), rgba(p.mid), 8)


def draw_pick(p: IconPainter, broken: bool = False) -> None:
    pts = [(128, 40), (188, 88), (168, 176), (128, 220), (88, 176), (68, 88)]
    if broken:
        pts = [(128, 40), (188, 88), (152, 129), (169, 176), (128, 220), (88, 176), (103, 130), (68, 88)]
    p.poly(pts, rgba(p.mid), rgba((7, 5, 5)), 6)
    p.ellipse((102, 92, 154, 144), rgba(p.dark, 140), rgba(p.light, 100), 3)
    if broken:
        p.line([(103, 130), (152, 129)], rgba((245, 230, 210), 160), 4)


def draw_amp(p: IconPainter) -> None:
    p.rect((51, 61, 205, 201), rgba(p.mid), rgba((7, 5, 5)), 6, 16)
    p.rect((70, 80, 186, 182), rgba(p.dark), None, 1, 8)
    for cx, cy in ((105, 130), (151, 130)):
        p.ellipse((cx - 25, cy - 25, cx + 25, cy + 25), rgba((18, 15, 18)), rgba(p.light, 110), 3)
        p.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), rgba(p.mid), None)
    p.line([(72, 91), (183, 91)], rgba(p.light, 130), 3)


def draw_crown(p: IconPainter) -> None:
    p.poly([(52, 170), (71, 70), (105, 134), (128, 51), (151, 134), (185, 70), (204, 170)], rgba(p.mid), rgba((7, 5, 5)), 6)
    p.rect((63, 156, 193, 205), rgba(p.mid), rgba((7, 5, 5)), 6, 12)
    for x, y in [(71, 70), (128, 51), (185, 70)]:
        p.ellipse((x - 9, y - 9, x + 9, y + 9), rgba(PALETTES["violet"][2]), rgba((7, 5, 5)), 2)
    p.line([(83, 174), (174, 174)], rgba(p.light, 150), 3)


def draw_purse(p: IconPainter) -> None:
    p.rect((89, 47, 167, 91), rgba(PALETTES["leather"][2]), rgba((7, 5, 5)), 5, 14)
    p.ellipse((65, 72, 191, 213), rgba(p.mid), rgba((7, 5, 5)), 6)
    p.line([(84, 93), (172, 93)], rgba(p.dark), 8)
    p.ellipse((105, 121, 151, 166), rgba(PALETTES["gold"][2], 170), rgba((7, 5, 5)), 3)


def draw_scroll_pact(p: IconPainter, thorns: bool = False) -> None:
    p.poly([(76, 50), (174, 41), (188, 198), (89, 215)], rgba(PALETTES["bone"][1]), rgba((7, 5, 5)), 5)
    p.line([(94, 83), (161, 77)], rgba(p.dark, 120), 2)
    p.line([(96, 119), (166, 112)], rgba(p.dark, 120), 2)
    p.ellipse((105, 145, 153, 194), rgba(p.mid), rgba((7, 5, 5)), 4)
    if thorns:
        p.line([(73, 192), (106, 160), (151, 148), (190, 113)], rgba(PALETTES["green"][1]), 7)
        for x, y in [(104, 160), (151, 148), (181, 122)]:
            p.poly([(x, y), (x + 14, y - 18), (x + 4, y + 8)], rgba(PALETTES["green"][2]), None)


def draw_fang(p: IconPainter) -> None:
    p.ellipse((95, 38, 161, 82), rgba(PALETTES["leather"][1]), rgba((7, 5, 5)), 5)
    p.poly([(98, 69), (159, 66), (145, 203), (121, 225), (105, 178)], rgba(PALETTES["bone"][2]), rgba((7, 5, 5)), 6)
    p.line([(132, 75), (123, 190)], rgba(p.light, 140), 3)


DRAW_MAP = {
    "warrior_charm": lambda p: draw_amulet(p),
    "fox_boots": lambda p: draw_boots(p),
    "glass_orb": lambda p: draw_orb(p),
    "hawk_lens": draw_lens,
    "ember_core": lambda p: draw_core(p),
    "old_codex": lambda p: draw_book(p),
    "stone_heart": lambda p: draw_heart(p, stone=True),
    "banner_seed": draw_seed_banner,
    "red_whetstone": draw_whetstone,
    "star_compass": draw_compass,
    "living_root": lambda p: draw_root(p),
    "captains_coin": lambda p: draw_coin(p),
    "quickstring": lambda p: draw_string_or_cable(p),
    "heavy_totem": draw_totem,
    "splinter_gloves": draw_gloves,
    "wide_sigil": draw_sigil,
    "swift_ink": lambda p: draw_ink(p),
    "summoners_bell": draw_bell,
    "blood_sigil": draw_sigil,
    "void_ink": lambda p: draw_ink(p),
    "echo_pick": lambda p: draw_pick(p),
    "sturdy_amulet": lambda p: draw_amulet(p),
    "fast_boots": lambda p: draw_boots(p),
    "magnetic_buckle": draw_buckle,
    "silver_coin": lambda p: draw_coin(p),
    "survival_manual": lambda p: draw_book(p),
    "cracked_shield": draw_shield,
    "sharp_talisman": lambda p: draw_amulet(p, sharp=True),
    "jagged_blade": lambda p: draw_blade(p),
    "heavy_grip": draw_grip,
    "war_belt": draw_belt,
    "warriors_rage": lambda p: draw_heart(p),
    "dark_crystal": lambda p: draw_crystal(p),
    "ash_page": lambda p: draw_book(p, page=True),
    "skull_resonator": draw_skull,
    "ink_candle": lambda p: draw_ink(p, candle=True),
    "copper_string": lambda p: draw_string_or_cable(p),
    "broken_pick": lambda p: draw_pick(p, broken=True),
    "loud_amp": draw_amp,
    "bass_cable": lambda p: draw_string_or_cable(p, cable=True),
    "cursed_crown": draw_crown,
    "fragile_heart": lambda p: draw_heart(p),
    "greedy_purse": draw_purse,
    "burning_shard": lambda p: draw_crystal(p, burning=True),
    "golden_route_mark": lambda p: draw_coin(p, route=True),
    "glass_edge": lambda p: draw_blade(p, glass=True),
    "echo_core": lambda p: draw_core(p),
    "split_core": lambda p: draw_core(p, split=True),
    "blood_pact": lambda p: draw_scroll_pact(p),
    "leech_heart": lambda p: draw_heart(p, leech=True),
    "thorn_pact": lambda p: draw_scroll_pact(p, thorns=True),
    "phantom_step": lambda p: draw_boots(p, ghost=True),
    "leech_fang": draw_fang,
}


def regenerate_one(artifact: dict[str, object]) -> Path:
    artifact_id = str(artifact["id"])
    tier = int(artifact.get("tier", 1))
    painter = IconPainter(artifact_id, tier)
    draw_func = DRAW_MAP.get(artifact_id, lambda p: draw_amulet(p))
    draw_func(painter)
    icon = painter.finish()
    path = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
    icon.save(path)
    errors = validator.validate_icon(path)
    if errors:
        raise RuntimeError(f"{artifact_id}: {'; '.join(errors)}")
    return path


def append_progress(count: int, total: int) -> None:
    line = f"Прогресс: обработано {count}/{total}."
    current = TASK_FILE.read_text(encoding="utf-8")
    if line in current:
        return
    with TASK_FILE.open("a", encoding="utf-8") as f:
        f.write(f"\n{line}\n")


def main() -> int:
    artifacts = parse_artifacts()
    total = len(artifacts)
    print(f"Regenerating {total} artifact icons")
    completed = 0
    for artifact in artifacts:
        path = regenerate_one(artifact)
        completed += 1
        print(f"{completed:02d}/{total} {path.name}")
        if completed % 10 == 0:
            append_progress(completed, total)
    validator.build_preview([str(a["id"]) for a in artifacts])
    print(f"Wrote {validator.PREVIEW_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
