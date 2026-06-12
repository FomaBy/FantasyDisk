"""Slice polished full-art sprites into cutout rig parts.

Reads the hand-tuned part boxes below, cuts each limb out of the source art,
erases the limb pixels from the torso (with naive inpainting of interior
holes), and emits:
  - assets/sprites/<group>/cutout/<entity>_<part>.png
  - scripts/sliced_rig_manifest.gd  (data consumed by cutout_rig_2d.gd)
  - build/rig_debug/cut_<entity>.png  (original | reassembled | exploded)

Run from the project root:  python3 tools/slice_rig_cutouts.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

# Part keys define behaviour in cutout_rig_2d.gd:
#   arm_l / arm_r   - swing while walking, attack/cast gestures
#   leg_l / leg_r   - stride while walking
#   wing_l / wing_r - flap (flying rigs)
#   weapon          - held item assembly (crossbow): recoil on shoot
#   shield          - held shield: sway/block
#   tail            - idle wag
#   vortex          - continuous swirl (boss)
# erase: "full" (default), "none", ("below", y) or explicit rect (x1,y1,x2,y2).
# base_facing: which way the source art looks (+1 right, -1 left). Player art
# looks right; all enemy/elite/boss art looks left, so the rig mirrors it when
# the mob moves right. Override per entity with "base_facing" if needed.

CONFIG = {
    "assassin": {
        "source": "assets/sprites/characters/assassin.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 489,
        "socket": (368, 295),
        "parts": {
            "arm_l": {"crop": (55, 190, 172, 332), "pivot": (115, 208), "z": 1, "erase": (0, 190, 145, 332)},
            "arm_r": {"crop": (332, 198, 452, 368), "pivot": (385, 216), "z": 1, "erase": (358, 198, 452, 368)},
            "leg_l": {"crop": (115, 322, 228, 495), "pivot": (165, 340), "z": -1, "erase": ("below", 352)},
            "leg_r": {"crop": (278, 328, 408, 498), "pivot": (340, 348), "z": -1, "erase": ("below", 362)},
        },
    },
    "ranger": {
        "source": "assets/sprites/characters/ranger.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 477,
        "socket": (322, 298),
        "parts": {
            "arm_l": {"crop": (58, 182, 188, 335), "pivot": (125, 200), "z": 1, "erase": (0, 182, 158, 335)},
            "arm_r": {"crop": (315, 188, 438, 368), "pivot": (365, 206), "z": 1, "erase": (340, 188, 438, 368)},
            "leg_l": {"crop": (105, 312, 228, 482), "pivot": (162, 328), "z": -1, "erase": ("below", 342)},
            "leg_r": {"crop": (275, 318, 408, 482), "pivot": (338, 336), "z": -1, "erase": ("below", 350)},
        },
    },
    "doctor": {
        "source": "assets/sprites/characters/doctor.png",
        "group": "characters",
        "style": "robed_walker",
        "attack_part": "arm_l",
        "foot_y": 472,
        "socket": (118, 228),
        "parts": {
            "arm_l": {"crop": (56, 145, 195, 298), "pivot": (182, 165), "z": 1, "erase": (0, 145, 165, 298)},
            "arm_r": {"crop": (315, 168, 442, 338), "pivot": (335, 186), "z": 1, "erase": (332, 168, 442, 338)},
            "leg_l": {"crop": (136, 275, 240, 478), "pivot": (188, 295), "z": -1, "erase": ("below", 352)},
            "leg_r": {"crop": (248, 280, 352, 480), "pivot": (300, 300), "z": -1, "erase": ("below", 358)},
        },
    },
    "chemist": {
        "source": "assets/sprites/characters/chemist.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 489,
        "socket": (378, 288),
        "parts": {
            "arm_l": {"crop": (52, 175, 182, 338), "pivot": (112, 194), "z": 1, "erase": (0, 175, 152, 338)},
            "arm_r": {"crop": (328, 165, 455, 352), "pivot": (378, 185), "z": 1, "erase": (352, 165, 455, 352)},
            "leg_l": {"crop": (116, 322, 234, 495), "pivot": (172, 340), "z": -1, "erase": ("below", 352)},
            "leg_r": {"crop": (272, 328, 408, 498), "pivot": (336, 348), "z": -1, "erase": ("below", 360)},
        },
    },
    "knight": {
        "source": "assets/sprites/characters/knight.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 489,
        "socket": (355, 245),
        "parts": {
            "arm_l": {"crop": (50, 175, 192, 372), "pivot": (118, 195), "z": 1, "erase": (0, 175, 158, 372)},
            "arm_r": {"crop": (322, 165, 448, 418), "pivot": (365, 185), "z": 1, "erase": (345, 165, 448, 372)},
            "leg_l": {"crop": (108, 335, 230, 498), "pivot": (165, 352), "z": -1, "erase": ("below", 366)},
            "leg_r": {"crop": (270, 330, 405, 498), "pivot": (335, 348), "z": -1, "erase": ("below", 362)},
        },
    },
    "druid": {
        "source": "assets/sprites/characters/druid.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 489,
        "socket": (332, 302),
        "parts": {
            "arm_l": {"crop": (58, 185, 182, 348), "pivot": (120, 205), "z": 1, "erase": (0, 185, 152, 348)},
            "arm_r": {"crop": (318, 188, 448, 372), "pivot": (370, 208), "z": 1, "erase": (344, 188, 448, 372)},
            "leg_l": {"crop": (112, 332, 238, 498), "pivot": (172, 350), "z": -1, "erase": ("below", 365)},
            "leg_r": {"crop": (275, 335, 412, 502), "pivot": (340, 355), "z": -1, "erase": ("below", 370)},
        },
    },
    "berserk": {
        "source": "assets/sprites/characters/berserk_unarmed.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 492,
        "socket": (388, 312),
        "parts": {
            "arm_l": {"crop": (60, 190, 165, 315), "pivot": (118, 205), "z": 1, "erase": (0, 190, 148, 315)},
            "arm_r": {"crop": (338, 200, 442, 372), "pivot": (388, 218), "z": 1, "erase": (362, 200, 442, 372)},
            "leg_l": {"crop": (100, 318, 205, 498), "pivot": (152, 335), "z": -1, "erase": ("below", 348)},
            "leg_r": {"crop": (278, 328, 402, 502), "pivot": (338, 348), "z": -1, "erase": ("below", 360)},
        },
    },
    "dark_mage": {
        "source": "assets/sprites/characters/dark_mage.png",
        "group": "characters",
        "style": "robed_walker",
        "attack_part": "arm_l",
        "foot_y": 495,
        "socket": (104, 224),
        "parts": {
            "arm_l": {"crop": (58, 138, 196, 270), "pivot": (188, 158), "z": 1, "erase": (0, 138, 162, 270)},
            "arm_r": {"crop": (328, 168, 442, 332), "pivot": (348, 186), "z": 1, "erase": (344, 168, 442, 332)},
            "leg_l": {"crop": (136, 274, 232, 500), "pivot": (184, 296), "z": -1, "erase": ("below", 352)},
            "leg_r": {"crop": (248, 278, 346, 504), "pivot": (298, 300), "z": -1, "erase": ("below", 356)},
        },
    },
    "guitarist": {
        "source": "assets/sprites/characters/guitarist.png",
        "group": "characters",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 460,
        "socket": (348, 330),
        "parts": {
            "arm_l": {"crop": (85, 160, 180, 340), "pivot": (140, 178), "z": 1, "erase": (0, 160, 132, 340)},
            "arm_r": {"crop": (298, 158, 388, 352), "pivot": (325, 176), "z": 1, "erase": (330, 158, 388, 300)},
            "leg_l": {"crop": (112, 268, 222, 452), "pivot": (168, 285), "z": -1, "erase": ("below", 304)},
            "leg_r": {"crop": (266, 268, 368, 472), "pivot": (312, 286), "z": -1, "erase": ("below", 304)},
        },
    },
    "rift_cutter": {
        "source": "assets/sprites/enemies/enemy_melee.png",
        "group": "enemies",
        "style": "humanoid",
        "attack_part": "arm_r",
        "foot_y": 174,
        "socket": (158, 150),
        "parts": {
            "arm_l": {"crop": (2, 80, 78, 168), "pivot": (56, 88), "z": 1, "erase": (0, 80, 54, 168)},
            "arm_r": {"crop": (118, 92, 192, 190), "pivot": (138, 100), "z": 1, "erase": (140, 92, 192, 190)},
            "leg_l": {"crop": (42, 116, 100, 178), "pivot": (70, 126), "z": -1, "erase": ("below", 136)},
            "leg_r": {"crop": (90, 122, 142, 184), "pivot": (112, 132), "z": -1, "erase": ("below", 142)},
        },
    },
    "ash_marksman": {
        "source": "assets/sprites/enemies/enemy_ranged.png",
        "group": "enemies",
        "style": "humanoid",
        "attack_part": "weapon",
        "foot_y": 182,
        "socket": (92, 108),
        "parts": {
            "weapon": {"crop": (2, 76, 134, 166), "pivot": (92, 108), "z": 2, "erase": (0, 76, 58, 166)},
            "leg_l": {"crop": (54, 136, 98, 172), "pivot": (74, 142), "z": -1, "erase": ("below", 150)},
            "leg_r": {"crop": (104, 138, 158, 190), "pivot": (124, 146), "z": -1, "erase": ("below", 154)},
        },
    },
    "spark_runner": {
        "source": "assets/sprites/enemies/enemy_suicide_runner.png",
        "group": "enemies",
        "style": "beast",
        "attack_part": "arm_r",
        "foot_y": 150,
        "socket": (112, 140),
        "parts": {
            "arm_l": {"crop": (2, 88, 44, 140), "pivot": (28, 96), "z": 1, "erase": (0, 88, 24, 140)},
            "arm_r": {"crop": (98, 110, 142, 154), "pivot": (112, 114), "z": 1, "erase": ("below", 132)},
            "leg_l": {"crop": (36, 118, 70, 154), "pivot": (52, 124), "z": -1, "erase": ("below", 130)},
            "tail": {"crop": (82, 36, 122, 86), "pivot": (96, 84), "z": -1},
        },
    },
    "stone_bruiser": {
        "source": "assets/sprites/enemies/enemy_bruiser_slow.png",
        "group": "enemies",
        "style": "heavy",
        "attack_part": "arm_r",
        "foot_y": 186,
        "socket": (150, 160),
        "parts": {
            "arm_l": {"crop": (0, 84, 48, 180), "pivot": (28, 94), "z": 1, "erase": (0, 84, 34, 180)},
            "arm_r": {"crop": (108, 74, 192, 192), "pivot": (148, 90), "z": 1, "erase": (134, 74, 192, 192)},
            "leg_l": {"crop": (34, 138, 94, 192), "pivot": (62, 148), "z": -1, "erase": ("below", 158)},
            "leg_r": {"crop": (88, 140, 132, 192), "pivot": (108, 150), "z": -1, "erase": ("below", 160)},
        },
    },
    "bone_caller": {
        "source": "assets/sprites/enemies/enemy_summoner.png",
        "group": "enemies",
        "style": "robed",
        "attack_part": "arm_l",
        "foot_y": 180,
        "socket": (30, 56),
        "parts": {
            "arm_l": {"crop": (0, 30, 66, 146), "pivot": (58, 72), "z": 1, "erase": (0, 30, 56, 146)},
            "arm_r": {"crop": (116, 86, 166, 138), "pivot": (126, 92), "z": 1, "erase": "none"},
        },
    },
    "void_mage": {
        "source": "assets/sprites/enemies/enemy_void_mage.png",
        "group": "enemies",
        "style": "floating_robed",
        "attack_part": "arm_r",
        "foot_y": 176,
        "socket": (158, 104),
        "parts": {
            "arm_l": {"crop": (10, 74, 58, 120), "pivot": (54, 84), "z": 1, "erase": (0, 74, 46, 120)},
            "arm_r": {"crop": (126, 82, 182, 126), "pivot": (132, 88), "z": 1, "erase": (144, 82, 182, 126)},
        },
    },
    "venom_spitter": {
        "source": "assets/sprites/enemies/enemy_venom_spitter.png",
        "group": "enemies",
        "style": "blob",
        "attack_part": "",
        "foot_y": 178,
        "socket": (60, 110),
        "parts": {
            "leg_l": {"crop": (2, 118, 78, 166), "pivot": (58, 126), "z": 1, "erase": ("below", 132)},
            "leg_r": {"crop": (78, 138, 138, 186), "pivot": (102, 144), "z": 1, "erase": ("below", 150)},
        },
    },
    "rift_shieldbearer": {
        "source": "assets/sprites/enemies/enemy_rift_shieldbearer.png",
        "group": "enemies",
        "style": "guard",
        "attack_part": "shield",
        "foot_y": 178,
        "socket": (40, 110),
        "parts": {
            "shield": {"crop": (96, 72, 178, 166), "pivot": (120, 112), "z": 2, "erase": (120, 72, 178, 166)},
            "arm_l": {"crop": (14, 84, 58, 136), "pivot": (46, 92), "z": 1, "erase": (0, 84, 50, 136)},
            "leg_l": {"crop": (32, 116, 84, 174), "pivot": (58, 126), "z": -1, "erase": ("below", 140)},
            "leg_r": {"crop": (102, 148, 146, 184), "pivot": (122, 154), "z": -1, "erase": ("below", 160)},
        },
    },
    "small_biter": {
        "source": "assets/sprites/enemies/enemy_small_biter.png",
        "group": "enemies",
        "style": "beast",
        "attack_part": "arm_l",
        "foot_y": 162,
        "socket": (60, 140),
        "parts": {
            "arm_l": {"crop": (10, 118, 78, 166), "pivot": (68, 124), "z": 1, "erase": ("below", 134)},
            "arm_r": {"crop": (98, 116, 142, 174), "pivot": (114, 120), "z": 1, "erase": ("below", 126)},
            "leg_r": {"crop": (138, 74, 192, 144), "pivot": (152, 84), "z": -1, "erase": (156, 74, 192, 144)},
        },
    },
    "bone_shaman": {
        "source": "assets/sprites/enemies/enemy_bone_shaman.png",
        "group": "enemies",
        "style": "robed",
        "attack_part": "arm_r",
        "foot_y": 182,
        "socket": (148, 104),
        "parts": {
            "arm_l": {"crop": (0, 56, 54, 108), "pivot": (50, 80), "z": 1},
            "arm_r": {"crop": (128, 18, 186, 180), "pivot": (148, 104), "z": 2, "erase": (128, 18, 186, 96)},
        },
    },
    "winged_spark": {
        "source": "assets/sprites/enemies/enemy_winged_spark.png",
        "group": "enemies",
        "style": "flyer",
        "attack_part": "arm_r",
        "foot_y": 168,
        "socket": (150, 140),
        "parts": {
            "wing_l": {"crop": (6, 26, 98, 102), "pivot": (94, 82), "z": -2, "erase": (0, 26, 82, 102)},
            "wing_r": {"crop": (146, 42, 192, 120), "pivot": (152, 92), "z": -2, "erase": (162, 42, 192, 120)},
            "arm_l": {"crop": (46, 98, 86, 152), "pivot": (68, 104), "z": 1, "erase": "none"},
            "arm_r": {"crop": (134, 116, 176, 160), "pivot": (144, 120), "z": 1, "erase": "none"},
            "leg_l": {"crop": (66, 136, 94, 170), "pivot": (78, 140), "z": -1, "erase": ("below", 152)},
            "leg_r": {"crop": (90, 140, 116, 174), "pivot": (100, 144), "z": -1, "erase": ("below", 156)},
        },
    },
    "iron_bastion": {
        "source": "assets/sprites/elites/iron_bastion.png",
        "group": "elites",
        "coord_scale": 512.0 / 192.0,
        "style": "heavy",
        "attack_part": "arm_r",
        "foot_y": 180,
        "socket": (150, 120),
        "parts": {
            "shield": {"crop": (0, 48, 68, 176), "pivot": (62, 104), "z": 2, "erase": (0, 48, 40, 176)},
            "arm_r": {"crop": (124, 60, 192, 174), "pivot": (142, 72), "z": 1, "erase": (150, 60, 192, 174)},
            "leg_r": {"crop": (98, 106, 154, 184), "pivot": (124, 116), "z": -1, "erase": ("below", 132)},
        },
    },
    "night_stalker": {
        "source": "assets/sprites/elites/night_stalker.png",
        "group": "elites",
        "coord_scale": 512.0 / 192.0,
        "style": "stalker",
        "attack_part": "arm_r",
        "foot_y": 178,
        "socket": (140, 130),
        "parts": {
            "arm_l": {"crop": (0, 48, 64, 116), "pivot": (60, 88), "z": 1, "erase": (0, 48, 56, 92)},
            "arm_r": {"crop": (114, 72, 176, 156), "pivot": (128, 82), "z": 1, "erase": (136, 72, 176, 156)},
            "leg_l": {"crop": (50, 124, 100, 184), "pivot": (74, 132), "z": -1, "erase": ("below", 142)},
            "leg_r": {"crop": (92, 132, 134, 174), "pivot": (110, 138), "z": -1, "erase": ("below", 148)},
        },
    },
    "plague_prophet": {
        "source": "assets/sprites/elites/plague_prophet.png",
        "group": "elites",
        "coord_scale": 512.0 / 192.0,
        "style": "robed",
        "attack_part": "arm_l",
        "foot_y": 182,
        "socket": (34, 98),
        "parts": {
            "arm_l": {"crop": (0, 8, 52, 134), "pivot": (44, 96), "z": 2, "erase": (0, 8, 52, 84)},
            "arm_r": {"crop": (126, 54, 182, 112), "pivot": (132, 76), "z": 1, "erase": (142, 54, 182, 112)},
        },
    },
    "shard_marshal": {
        "source": "assets/sprites/elites/shard_marshal.png",
        "group": "elites",
        "coord_scale": 512.0 / 192.0,
        "style": "heavy",
        "attack_part": "arm_l",
        "foot_y": 186,
        "socket": (52, 96),
        "parts": {
            "arm_l": {"crop": (0, 22, 74, 118), "pivot": (58, 92), "z": 2, "erase": (0, 22, 68, 118)},
            "arm_r": {"crop": (132, 54, 190, 120), "pivot": (142, 68), "z": 1, "erase": (152, 54, 190, 120)},
            "leg_l": {"crop": (46, 146, 102, 192), "pivot": (74, 154), "z": -1, "erase": ("below", 162)},
            "leg_r": {"crop": (102, 150, 158, 192), "pivot": (128, 158), "z": -1, "erase": ("below", 166)},
        },
    },
    "rift_warden": {
        "source": "assets/sprites/bosses/boss_rift_warden.png",
        "group": "bosses",
        "coord_scale": 2.0,
        "style": "colossus",
        "attack_part": "arm_r",
        "foot_y": 240,
        "socket": (196, 120),
        "parts": {
            "arm_l": {"crop": (8, 80, 80, 144), "pivot": (62, 94), "z": 1, "erase": (0, 80, 58, 144)},
            "arm_r": {"crop": (176, 80, 250, 148), "pivot": (196, 94), "z": 1, "erase": (200, 80, 250, 148)},
            "vortex": {"crop": (68, 128, 188, 252), "pivot": (128, 190), "z": -1, "erase": (76, 170, 180, 248)},
        },
    },
    "disk_devourer": {
        "source": "assets/sprites/bosses/boss_disk_devourer.png",
        "group": "bosses",
        "coord_scale": 2.0,
        "style": "blob",
        "attack_part": "",
        "foot_y": 236,
        "socket": (128, 128),
        "parts": {},
    },
}


def erase_region(part: dict) -> tuple[int, int, int, int] | None:
    crop = part["crop"]
    erase = part.get("erase", "full")
    if erase == "none":
        return None
    if erase == "full":
        return crop
    if isinstance(erase, tuple) and erase[0] == "below":
        return (crop[0], int(erase[1]), crop[2], crop[3])
    return tuple(erase)


def inpaint(img: Image.Image, mask: list[list[bool]]) -> None:
    """Fill erased interior pixels from surrounding opaque pixels."""
    w, h = img.size
    px = img.load()
    radius = 60

    def opaque(x: int, y: int) -> bool:
        if x < 0 or y < 0 or x >= w or y >= h:
            return False
        return not mask[y][x] and px[x, y][3] > 40

    def ray_hits(x: int, y: int, dx: int, dy: int) -> bool:
        for step in range(1, radius):
            nx, ny = x + dx * step, y + dy * step
            if nx < 0 or ny < 0 or nx >= w or ny >= h:
                return False
            if mask[ny][nx]:
                continue
            return px[nx, ny][3] > 40
        return False

    interior = set()
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            horizontal = ray_hits(x, y, 1, 0) and ray_hits(x, y, -1, 0)
            vertical = ray_hits(x, y, 0, 1) and ray_hits(x, y, 0, -1)
            if horizontal or vertical:
                interior.add((x, y))

    filled = {}
    frontier = set()
    for x, y in interior:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if opaque(x + dx, y + dy):
                frontier.add((x, y))
                break
    for _ in range(96):
        if not frontier:
            break
        new_frontier = set()
        for x, y in frontier:
            acc = [0, 0, 0]
            count = 0
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) in filled:
                    c = filled[(nx, ny)]
                elif opaque(nx, ny):
                    c = px[nx, ny]
                else:
                    continue
                acc[0] += c[0]
                acc[1] += c[1]
                acc[2] += c[2]
                count += 1
            if count == 0:
                continue
            filled[(x, y)] = (acc[0] // count, acc[1] // count, acc[2] // count, 255)
        for x, y in filled:
            interior.discard((x, y))
        for x, y in interior:
            if (x, y) in filled:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) in filled:
                    new_frontier.add((x, y))
                    break
        frontier = new_frontier

    for (x, y), color in filled.items():
        px[x, y] = color

    if filled:
        blur = img.filter(ImageFilter.GaussianBlur(2))
        bpx = blur.load()
        for (x, y) in filled:
            px[x, y] = bpx[x, y]


def scaled_cfg(cfg: dict) -> dict:
    """Apply cfg['coord_scale'] to every pixel coordinate in the part config.

    Lets a config stay authored in the original art resolution while the
    source file itself has been upsized (e.g. elites 192 -> 256).
    """
    k = float(cfg.get("coord_scale", 1.0))
    if k == 1.0:
        return cfg
    out = dict(cfg)
    out["foot_y"] = round(cfg["foot_y"] * k)
    out["socket"] = (round(cfg["socket"][0] * k), round(cfg["socket"][1] * k))
    parts = {}
    for part_name, part in cfg["parts"].items():
        scaled = dict(part)
        scaled["crop"] = tuple(round(v * k) for v in part["crop"])
        scaled["pivot"] = (round(part["pivot"][0] * k), round(part["pivot"][1] * k))
        erase = part.get("erase", "full")
        if isinstance(erase, tuple) and erase and erase[0] == "below":
            scaled["erase"] = ("below", round(erase[1] * k))
        elif isinstance(erase, tuple):
            scaled["erase"] = tuple(round(v * k) for v in erase)
        parts[part_name] = scaled
    out["parts"] = parts
    return out


def _alpha_components(img: Image.Image, min_area: int = 8) -> list[list[tuple[int, int]]]:
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    out = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] == 0:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            comp = []
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(comp) >= min_area:
                out.append(comp)
    return out


def fix_detached_fragments(name: str, cfg: dict, out_dir: Path) -> None:
    """Remove stray neighbor-art fragments from limb pieces.

    A limb crop can catch a slice of the body next to it. Any connected
    component other than the dominant one is moved back to the torso layer:
    pixels already present in the torso are simply deleted from the limb,
    missing ones are restored into the torso first. Rest pose stays
    pixel-identical; the fragment no longer rides the limb during swings.
    """
    torso_path = out_dir / f"{name}_torso.png"
    torso = Image.open(torso_path).convert("RGBA")
    tpx = torso.load()
    torso_changed = False
    for part_name, part in cfg["parts"].items():
        piece_path = out_dir / f"{name}_{part_name}.png"
        piece = Image.open(piece_path).convert("RGBA")
        comps = _alpha_components(piece)
        if len(comps) < 2:
            continue
        ox, oy = part["crop"][0], part["crop"][1]
        ppx = piece.load()

        def non_duplicated(comp: list) -> int:
            count = 0
            for x, y in comp:
                if tpx[ox + x, oy + y][3] == 0:
                    count += 1
            return count

        dominant = max(comps, key=non_duplicated)
        moved = 0
        for comp in comps:
            if comp is dominant:
                continue
            for x, y in comp:
                if tpx[ox + x, oy + y][3] == 0:
                    tpx[ox + x, oy + y] = ppx[x, y]
                    torso_changed = True
                ppx[x, y] = (0, 0, 0, 0)
            moved += len(comp)
        if moved:
            piece.save(piece_path)
            print(f"  {name}_{part_name}: moved {moved}px of stray fragments to torso")
    if torso_changed:
        torso.save(torso_path)


def slice_entity(name: str, cfg: dict) -> dict:
    cfg = scaled_cfg(cfg)
    src = Image.open(ROOT / cfg["source"]).convert("RGBA")
    w, h = src.size
    out_dir = ROOT / "assets" / "sprites" / cfg["group"] / "cutout"
    out_dir.mkdir(parents=True, exist_ok=True)

    torso = src.copy()
    tpx = torso.load()
    mask = [[False] * w for _ in range(h)]
    manifest_parts = {}

    for part_name, part in cfg["parts"].items():
        x1, y1, x2, y2 = part["crop"]
        piece = src.crop((x1, y1, x2, y2))
        piece.save(out_dir / f"{name}_{part_name}.png")
        manifest_parts[part_name] = {
            "pos": (x1, y1),
            "pivot": part["pivot"],
            "z": part["z"],
        }
        region = erase_region(part)
        if region is not None:
            ex1, ey1, ex2, ey2 = region
            for y in range(max(ey1, 0), min(ey2, h)):
                for x in range(max(ex1, 0), min(ex2, w)):
                    if tpx[x, y][3] > 0:
                        tpx[x, y] = (0, 0, 0, 0)
                        mask[y][x] = True

    inpaint(torso, mask)
    torso.save(out_dir / f"{name}_torso.png")
    manifest_parts["torso"] = {"pos": (0, 0), "pivot": (w / 2, h / 2), "z": 0}

    fix_detached_fragments(name, cfg, out_dir)
    _debug_sheet(name, src, cfg, out_dir)
    return manifest_parts


def _debug_sheet(name: str, src: Image.Image, cfg: dict, out_dir: Path) -> None:
    w, h = src.size
    sheet = Image.new("RGBA", (w * 3, h), (250, 250, 252, 255))
    sheet.alpha_composite(src, (0, 0))

    layers = [("torso", {"pos": (0, 0), "z": 0})]
    for part_name, part in cfg["parts"].items():
        layers.append((part_name, {"pos": part["crop"][:2], "z": part["z"]}))
    layers.sort(key=lambda item: item[1]["z"])

    for panel, explode in ((1, 0.0), (2, 0.22)):
        for part_name, info in layers:
            piece = Image.open(out_dir / f"{name}_{part_name}.png")
            px_, py_ = info["pos"]
            cx = px_ + piece.width / 2 - w / 2
            cy = py_ + piece.height / 2 - h / 2
            ox = int(px_ + cx * explode) + panel * w
            oy = int(py_ + cy * explode)
            sheet.alpha_composite(piece, (ox, oy))
    sheet.convert("RGB").save(ROOT / "build" / "rig_debug" / f"cut_{name}.png")


def write_manifest(all_parts: dict) -> None:
    lines = [
        "## Generated by tools/slice_rig_cutouts.py - do not edit by hand.",
        "## Cutout rig data: polished art sliced into animated body parts.",
        "extends RefCounted",
        "",
        "const DATA := {",
    ]
    for name, cfg in CONFIG.items():
        cfg = scaled_cfg(cfg)
        parts = all_parts[name]
        src = Image.open(ROOT / cfg["source"])
        w, h = src.size
        lines.append(f'\t"{name}": {{')
        lines.append(f'\t\t"source": "res://{cfg["source"]}",')
        lines.append(f'\t\t"size": Vector2({w}.0, {h}.0),')
        base_facing = cfg.get("base_facing", 1.0 if cfg["group"] == "characters" else -1.0)
        lines.append(f'\t\t"style": "{cfg["style"]}",')
        lines.append(f'\t\t"attack_part": "{cfg["attack_part"]}",')
        lines.append(f'\t\t"base_facing": {float(base_facing)},')
        lines.append(f'\t\t"foot_y": {float(cfg["foot_y"])},')
        lines.append(f'\t\t"socket": Vector2({float(cfg["socket"][0])}, {float(cfg["socket"][1])}),')
        lines.append('\t\t"parts": {')
        for part_name, part in parts.items():
            tex = f"res://assets/sprites/{cfg['group']}/cutout/{name}_{part_name}.png"
            pos = part["pos"]
            pivot = part["pivot"]
            lines.append(
                f'\t\t\t"{part_name}": {{"texture": preload("{tex}"), '
                f'"pos": Vector2({float(pos[0])}, {float(pos[1])}), '
                f'"pivot": Vector2({float(pivot[0])}, {float(pivot[1])}), '
                f'"z": {part["z"]}}},'
            )
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    (ROOT / "scripts" / "sliced_rig_manifest.gd").write_text("\n".join(lines) + "\n")


def main() -> None:
    (ROOT / "build" / "rig_debug").mkdir(parents=True, exist_ok=True)
    all_parts = {}
    for name, cfg in CONFIG.items():
        all_parts[name] = slice_entity(name, cfg)
        print(f"sliced {name}: {len(cfg['parts'])} parts")
    write_manifest(all_parts)
    print("manifest written")


if __name__ == "__main__":
    main()
