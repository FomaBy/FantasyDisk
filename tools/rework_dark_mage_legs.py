"""Rework the Dark Mage sprite legs into a neutral, animation-friendly stance.

Design task: design_dark_mage_sprite_legs_rework_task.md

The source art has a lunge pose: the viewer-left leg is bent back (short boot),
the right leg steps forward. For a readable walk cycle we rebuild the lower
body: the well-drawn right leg is mirrored into the left position, the old bent
boot is removed, both feet land on one ground line with a clear gap between
the legs, and the coat tail still overlaps the new thigh so the design reads
unchanged.

The original is backed up to build/bg_backup/dark_mage_original.png and the
script always rebuilds from that backup (idempotent).

Run from the project root:  python3 tools/rework_dark_mage_legs.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SPRITE = ROOT / "assets" / "sprites" / "characters" / "dark_mage.png"
BACKUP = ROOT / "build" / "bg_backup" / "dark_mage_original.png"

# Right leg (kept as-is) bounding polygon in source coordinates.
RIGHT_LEG_POLY = [
    (258, 286), (318, 282), (332, 330), (338, 400),
    (340, 468), (330, 494), (294, 500), (278, 478),
    (268, 420), (252, 340),
]
# Erase logic: inside BOOT_ZONE only dark pixels go (the boot leather), so the
# lighter coat tail and the glowing rune survive untouched. BOOT_FORCE_ZONE
# (boot body with its bright gem) and the GAP_STRIP are erased unconditionally.
BOOT_ZONE = [(84, 318), (208, 314), (208, 424), (84, 424)]
BOOT_FORCE_ZONE = [(148, 334), (208, 328), (208, 424), (148, 424)]
GAP_STRIP = [(228, 330), (250, 330), (250, 500), (228, 500)]
# Leftover bright boot-trim slivers below the coat tip (anti-aliased into the
# coat, so the island sweep keeps them) - erased explicitly.
TRIM_SLIVERS = [(96, 316), (162, 316), (162, 358), (96, 358)]
DARK_SUM_THRESHOLD = 150
# Mirrored right leg lands here: offset applied after horizontal flip.
BODY_CENTER_X = 240
LEFT_FOOT_RAISE = 6  # left foot slightly higher for top-down depth



def polygon_mask(size: tuple[int, int], polygon: list[tuple[int, int]], blur: float) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(blur))


def _remove_small_islands(img: Image.Image, window: tuple[int, int, int, int], max_area: int) -> None:
    x1, y1, x2, y2 = window
    px = img.load()
    visited = set()
    for sy in range(y1, y2):
        for sx in range(x1, x2):
            if (sx, sy) in visited or px[sx, sy][3] == 0:
                continue
            stack = [(sx, sy)]
            component = []
            escaped = False
            while stack:
                x, y = stack.pop()
                if (x, y) in visited:
                    continue
                visited.add((x, y))
                if not (x1 <= x < x2 and y1 <= y < y2):
                    escaped = True  # connected to art outside the window
                    continue
                if px[x, y][3] == 0:
                    continue
                component.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    stack.append((x + dx, y + dy))
            if not escaped and len(component) <= max_area:
                for x, y in component:
                    px[x, y] = (0, 0, 0, 0)


def main() -> None:
    BACKUP.parent.mkdir(parents=True, exist_ok=True)
    if not BACKUP.exists():
        shutil.copy(SPRITE, BACKUP)
    src = Image.open(BACKUP).convert("RGBA")
    result = src.copy()

    # 1. Erase the old bent boot (dark pixels only inside BOOT_ZONE, so coat
    #    and rune survive), the boot gem zone and the leg gap strip.
    clear = Image.new("RGBA", src.size, (0, 0, 0, 0))
    zone_mask = polygon_mask(src.size, BOOT_ZONE, 0.0).point(lambda a: 255 if a > 90 else 0)
    px = src.load()
    zpx = zone_mask.load()
    for y in range(314, 425):
        for x in range(84, 209):
            if zpx[x, y] == 0:
                continue
            r, g, b, a = px[x, y]
            if a > 0 and (r + g + b) >= DARK_SUM_THRESHOLD:
                zpx[x, y] = 0
    dark_mask = zone_mask.filter(ImageFilter.MaxFilter(3))
    result = Image.composite(clear, result, dark_mask)
    for poly in [BOOT_FORCE_ZONE, GAP_STRIP, TRIM_SLIVERS]:
        erase_mask = polygon_mask(src.size, poly, 1.5)
        result = Image.composite(clear, result, erase_mask.point(lambda a: 255 if a > 90 else 0))

    # 2. Cut the right leg with a soft mask and mirror it into the left slot.
    leg_mask = polygon_mask(src.size, RIGHT_LEG_POLY, 2.0)
    leg = Image.new("RGBA", src.size, (0, 0, 0, 0))
    leg.paste(src, (0, 0), leg_mask)
    xs = [p[0] for p in RIGHT_LEG_POLY]
    left_edge, right_edge = min(xs), max(xs)
    leg_flipped = leg.transpose(Image.FLIP_LEFT_RIGHT)
    # After a full-image flip the leg sits at mirrored x around the image
    # center; shift so it mirrors around the body center instead.
    image_mirror_center = src.width / 2.0
    current_center = src.width - (left_edge + right_edge) / 2.0
    target_center = 2.0 * BODY_CENTER_X - (left_edge + right_edge) / 2.0
    dx = int(round(target_center - current_center))
    dy = -LEFT_FOOT_RAISE
    shifted = Image.new("RGBA", src.size, (0, 0, 0, 0))
    shifted.paste(leg_flipped, (dx, dy), leg_flipped)

    # 3. New left leg goes UNDER the existing body pixels: keep result on top
    #    wherever it is opaque, so the coat/panel naturally overlaps the thigh.
    base = shifted.copy()
    base.alpha_composite(result)
    # ...but the freshly erased boot region must show the new leg, and the
    # boot/shin area should not be covered by semi-transparent leftovers.
    result = base

    # 4. Sweep tiny leftover islands (bright boot-trim specks) in the surgery
    #    window; big elements like the floating rune survive the size filter.
    _remove_small_islands(result, window=(80, 300, 200, 420), max_area=150)

    result.save(SPRITE)
    print(f"dark_mage legs reworked -> {SPRITE} ({result.size[0]}x{result.size[1]})")


if __name__ == "__main__":
    main()
