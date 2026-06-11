"""Sprite quality audit: find (and optionally fix) edge artifacts.

Design task: design_sprite_quality_audit_cleanup_task.md

Checks every active sprite PNG for:
  - stray alpha islands: tiny connected components far from the main art
    (the "лишний кусок текстуры" class of bugs);
  - dirty semi-transparent specks (very low alpha, saturated color);
  - white/black halo fringes on silhouette edges (reported only).

Usage:
  python3 tools/sprite_quality_audit.py            # report only
  python3 tools/sprite_quality_audit.py --fix      # remove stray islands/specks

Stray island rule (conservative): area <= MAX_AREA px AND bbox separated from
the nearest big component by >= MIN_GAP px. Big secondary components (floating
spell orbs, runes, detached design elements) are never touched.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

SCAN_DIRS = [
    "assets/sprites/characters",
    "assets/sprites/characters/cutout",
    "assets/sprites/enemies",
    "assets/sprites/enemies/cutout",
    "assets/sprites/elites",
    "assets/sprites/elites/cutout",
    "assets/sprites/bosses",
    "assets/sprites/bosses/cutout",
    "assets/sprites/weapons",
    "assets/sprites/projectiles",
    "assets/sprites/effects",
    "assets/sprites/map_icons",
    "assets/sprites/ui/icons/stats",
    "assets/sprites/ui/icons/derived",
    "assets/sprites/ui/hud",
]

MAX_AREA = 70          # px: islands this small are junk candidates
# UI icons legitimately use detached sparkles/particles - report only there.
ISLAND_REPORT_ONLY = ("ui/icons", "ui/hud", "map_icons", "effects")
MIN_GAP = 10           # px: minimal distance from a big component
SPECK_ALPHA = 24       # alpha below this with color = dirty speck
HALO_DELTA = 70        # edge pixel much brighter than inner neighbor = halo


def components(img: Image.Image) -> list[dict]:
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    found = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] == 0:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            pixels = []
            min_x, min_y, max_x, max_y = sx, sy, sx, sy
            while stack:
                x, y = stack.pop()
                pixels.append((x, y))
                min_x = min(min_x, x); max_x = max(max_x, x)
                min_y = min(min_y, y); max_y = max(max_y, y)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            found.append({"pixels": pixels, "bbox": (min_x, min_y, max_x, max_y), "area": len(pixels)})
    return found


def bbox_gap(a: tuple, b: tuple) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    dx = max(bx1 - ax2, ax1 - bx2, 0)
    dy = max(by1 - ay2, ay1 - by2, 0)
    return (dx * dx + dy * dy) ** 0.5


def audit_file(path: Path, fix: bool) -> list[str]:
    img = Image.open(path).convert("RGBA")
    px = img.load()
    notes = []
    comps = components(img)
    if not comps:
        return notes
    big = [c for c in comps if c["area"] > MAX_AREA]
    changed = False

    for comp in comps:
        if comp["area"] > MAX_AREA:
            continue
        gap = min((bbox_gap(comp["bbox"], b["bbox"]) for b in big), default=999.0)
        if gap < MIN_GAP:
            continue
        # mostly-transparent specks die even when slightly bigger
        max_alpha = max(px[x, y][3] for x, y in comp["pixels"])
        notes.append(f"stray island {comp['area']}px at {comp['bbox']} gap {gap:.0f} alpha<={max_alpha}")
        island_fix_allowed = not any(fragment in str(path) for fragment in ISLAND_REPORT_ONLY)
        # visible islands (alpha > 60) need eyes; auto-remove only near-invisible ones elsewhere
        if fix and island_fix_allowed and max_alpha <= 60:
            for x, y in comp["pixels"]:
                px[x, y] = (0, 0, 0, 0)
            changed = True

    # dirty barely-visible specks anywhere
    speck_count = 0
    for comp in comps:
        if comp["area"] > 12:
            continue
        max_alpha = max(px[x, y][3] for x, y in comp["pixels"])
        if 0 < max_alpha <= SPECK_ALPHA:
            speck_count += comp["area"]
            if fix:
                for x, y in comp["pixels"]:
                    px[x, y] = (0, 0, 0, 0)
                changed = True
    if speck_count:
        notes.append(f"dirty specks: {speck_count}px of alpha<={SPECK_ALPHA}")

    # halo check: edge pixels that are near-white while inner art is dark
    halo = 0
    w, h = img.size
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r, g, b, a = px[x, y]
            if a == 0 or a > 130:
                continue
            if min(r, g, b) > 225:
                halo += 1
    if halo > 40:
        notes.append(f"possible white halo fringe: {halo}px semi-transparent near-white")

    if fix and changed:
        img.save(path)
        notes.append("FIXED")
    return notes


def main() -> None:
    fix = "--fix" in sys.argv
    total_flagged = 0
    for rel in SCAN_DIRS:
        directory = ROOT / rel
        if not directory.exists():
            continue
        for path in sorted(directory.glob("*.png")):
            notes = audit_file(path, fix)
            if notes:
                total_flagged += 1
                print(f"{path.relative_to(ROOT)}")
                for note in notes:
                    print(f"    {note}")
    print(f"\nflagged files: {total_flagged} (mode: {'fix' if fix else 'report'})")


if __name__ == "__main__":
    main()
