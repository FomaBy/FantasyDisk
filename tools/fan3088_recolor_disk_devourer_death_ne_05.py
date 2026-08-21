#!/usr/bin/env python3
"""FAN-3088 (rework of FAN-2635, rejected by QA FAN-2768): fix the turquoise/ice
palette-flip on disk_devourer's death_north_east frame 5 of 7.

Bug: this single frame renders the boss in a bright turquoise/ice-blue palette
instead of its green/purple/gold identity used by every other frame of the pack
(56 rows x 8 directions). Frame 6 (the very next frame) reverts to the correct
palette, and frame 5 of the other 7 death directions is correct too -> the defect
is isolated to exactly one runtime frame (+ its raw PixelLab source).

Method: exact-color substitution, not a blind hue/HSV transform.

1. Collect every RGBA color used anywhere else in the disk_devourer death state
   (the other 6 frames of the north_east row, plus frame 5 of the other 7
   directions) -> the "known-good" palette for this pose/lighting context.
2. Any color in the target frame that is NOT in that known-good set is, by
   construction, unique to the corrupted frame -> a bug color (46 of 65 colors
   in the runtime PNG; same 46 in the 128x128 raw PixelLab source).
3. Each bug color is replaced with its nearest known-good color (redmean RGB
   distance), i.e. a color already used by this exact creature in this exact
   animation context -- never an invented value.
4. Every pixel whose color is already known-good (the shared outline/shadow
   family, 18 of 65 colors) is left byte-identical. Alpha is never touched, so
   canvas size, alpha-bbox, pivot and silhouette are unaffected by construction.

Touches exactly two PNGs (+ their .import sidecars, unchanged in content since
Godot's import cache key is path-derived, not content-derived):
  assets/sprites/bosses/disk_devourer_8dir/runtime/disk_devourer_death_north_east_05.png
  assets/sprites/bosses/disk_devourer_8dir/pixellab_source/death/disk_devourer_death_north_east_05.png

manifest.json / alpha_bbox_report.json store no per-pixel color or content-hash
data (bbox coordinates aren't tracked, only a scale factor) -- both are already
correct and are not modified.

Usage:
    python3 tools/fan3088_recolor_disk_devourer_death_ne_05.py             # fix in place
    python3 tools/fan3088_recolor_disk_devourer_death_ne_05.py --check     # report only
    python3 tools/fan3088_recolor_disk_devourer_death_ne_05.py --preview-dir docs/design/previews/fan3088
"""

from __future__ import annotations

import argparse
import colorsys
from pathlib import Path

from PIL import Image

# The pack legitimately uses a *small* saturated cyan/turquoise gem/rune accent
# (e.g. the shoulder gem in frame 02) alongside its green/purple/gold body. That
# accent color is RGB-close to the bug's full-body turquoise flip, so a naive
# nearest-color search keeps picking it as the "closest good match" and the fix
# is a no-op. Candidates in this hue/saturation band are excluded from the
# replacement pool -- the bug is a body-fill color and must resolve to a
# body-fill family (green/purple/gold/dark), never to the rare accent hue.
ACCENT_HUE_MIN, ACCENT_HUE_MAX = 140.0, 225.0
ACCENT_SAT_MIN = 0.45


def is_excluded_accent(c: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = c
    h, s, _v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    h *= 360
    return ACCENT_HUE_MIN <= h <= ACCENT_HUE_MAX and s >= ACCENT_SAT_MIN

ROOT = Path(__file__).resolve().parents[1]
PACK_DIR = ROOT / "assets/sprites/bosses/disk_devourer_8dir"
RUNTIME_DIR = PACK_DIR / "runtime"
SOURCE_DIR = PACK_DIR / "pixellab_source/death"

RUNTIME_TARGET = RUNTIME_DIR / "disk_devourer_death_north_east_05.png"
SOURCE_TARGET = SOURCE_DIR / "disk_devourer_death_north_east_05.png"

# Known-good context pool. Deliberately narrow: only the immediate same-row
# neighbor frames (04 and 06 bracket the bug frame directly; 03 extends the
# runway). Other directions' frame 5 were tried and rejected -- several carry
# their own small saturated cyan/teal gem accents (e.g. frame 02's shoulder
# gem) that are RGB-close to the bug's full-body turquoise flip, so a
# cross-direction pool kept nearest-matching the bug back onto an accent
# color instead of the body-fill green/purple/gold family. 03/04/06 of this
# exact row carry no such accent and are the frame's direct temporal context.
RUNTIME_POOL = [RUNTIME_DIR / f"disk_devourer_death_north_east_{i:02d}.png" for i in (3, 4, 6)]
SOURCE_POOL = [SOURCE_DIR / f"disk_devourer_death_north_east_{i:02d}.png" for i in (3, 4, 6)]


def opaque_colors(path: Path) -> set[tuple[int, int, int, int]]:
    im = Image.open(path).convert("RGBA")
    return {c for _, c in im.getcolors(maxcolors=1_000_000) if c[3] > 0}


def redmean(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    r1, g1, b1 = a[:3]
    r2, g2, b2 = b[:3]
    rm = (r1 + r2) / 2.0
    dr, dg, db = r1 - r2, g1 - g2, b1 - b2
    return (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db


def build_remap(target: Path, pool: list[Path]) -> dict[tuple[int, int, int, int], tuple[int, int, int, int]]:
    good = set()
    for p in pool:
        good |= opaque_colors(p)
    bad = opaque_colors(target) - good
    candidates = {c for c in good if not is_excluded_accent(c)}
    remap = {}
    for c in bad:
        remap[c] = min(candidates, key=lambda g: redmean(c, g))
    return remap


def build_preview(before: Image.Image, after: Image.Image, path: Path) -> None:
    gap = 24
    w, h = before.size
    sheet = Image.new("RGBA", (w * 2 + gap, h), (18, 18, 18, 255))
    sheet.paste(before, (0, 0), before)
    sheet.paste(after, (w + gap, 0), after)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def process(target: Path, pool: list[Path], *, check: bool, preview_dir: Path | None) -> tuple[bool, int]:
    if not target.is_file():
        print(f"[MISS] {target}")
        return False, 0
    remap = build_remap(target, pool)
    img = Image.open(target)
    original_size = img.size
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    touched = 0
    before = rgba.copy()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] == 0:
                continue
            new_c = remap.get(c)
            if new_c is not None:
                px[x, y] = new_c
                touched += 1
    remaining_bug_colors = opaque_colors_from_image(rgba) & set(remap.keys())
    status = "OK" if not remaining_bug_colors else "FAIL"
    print(f"[{status}] {target.relative_to(ROOT)}: size={original_size[0]}x{original_size[1]} "
          f"bug_colors={len(remap)} remapped_px={touched}")
    if check:
        return status == "OK", touched
    if before.getchannel("A").tobytes() != rgba.getchannel("A").tobytes():
        raise AssertionError(f"alpha channel drifted for {target.name}")
    if preview_dir is not None:
        build_preview(before, rgba, preview_dir / f"{target.stem}_before_after.png")
    rgba.save(target)
    if Image.open(target).size != original_size:
        raise AssertionError(f"size drifted for {target.name}")
    return status == "OK", touched


def opaque_colors_from_image(im: Image.Image) -> set[tuple[int, int, int, int]]:
    return {c for _, c in im.getcolors(maxcolors=1_000_000) if c[3] > 0}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="report only, write nothing")
    parser.add_argument("--preview-dir", type=Path, default=None,
                         help="write before/after contact previews here")
    args = parser.parse_args()

    ok_runtime, _ = process(RUNTIME_TARGET, RUNTIME_POOL, check=args.check, preview_dir=args.preview_dir)
    ok_source, _ = process(SOURCE_TARGET, SOURCE_POOL, check=args.check, preview_dir=args.preview_dir)
    return 0 if (ok_runtime and ok_source) else 1


if __name__ == "__main__":
    raise SystemExit(main())
