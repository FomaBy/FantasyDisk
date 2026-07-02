#!/usr/bin/env python3
"""SCRUM-820: recolor the skill-tree frame family from warm orange-gold to dark brass.

Art direction (SCRUM-809 audit "волна 4" / SCRUM-806 reopen): the skill-tree screen
carries a warm orange-gold "wooden" family that breaks the accepted course — dark
leather with a thin muted brass line, reference
``assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`` (brass ~hue 30-36,
sat ~0.33-0.42, val ~0.20-0.37).

Method — selective HSV remap of the *frame gold* only:

* Frame gold is isolated from the baked gold TEXT (screen/section titles, path names,
  "ОЧКИ", "КЛАСС") and the semantic EMBLEMS (coins, path emblems) by connectivity:
  the frame rim/bosses/cartouche borders/arrow box/dividers reach the transparent
  margin, while text and emblems are enclosed islands inside the dark body.
  We flood the non-gold "outside" inward from the image border; it stops at the
  closed gold frame loop. Everything gold reachable from that outside is the frame.
* Enclosed gold (text + emblems) is protected by default so it is NEVER recolored.
* A few decorative *ornaments* that happen to be enclosed islands (the main-frame
  bottom diamond, the class-popup header divider) are opted back into the recolor via
  explicit rectangles — they are rims, not text/emblems.

The brass remap is byte-for-byte the same transform as the minimal_metal family
(SCRUM-817, ``recolor_minimal_metal_brass``) so the whole UI reads as one brass line.
Alpha channel and PNG size are never touched, so the ``.import`` sidecars and the
9-slice margins in ``ui_screens.gd`` stay valid.

Usage:
    python3 tools/recolor_skill_tree_brass.py                 # recolor in place
    python3 tools/recolor_skill_tree_brass.py --check         # report only, no writes
    python3 tools/recolor_skill_tree_brass.py --preview-dir docs/design/previews/scrum820
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FAMILY_DIR = ROOT / "assets/sprites/ui/skill_tree"

# The 8 live textures from the task spec (all referenced by ui_screens.gd constants).
DEFAULT_TARGETS = [
    FAMILY_DIR / "ui_frame_skill_tree_class_select.png",
    FAMILY_DIR / "ui_frame_skill_tree_class_popup.png",
    FAMILY_DIR / "ui_btn_skill_points.png",
    FAMILY_DIR / "ui_frame_skill_tree_path_wealth.png",
    FAMILY_DIR / "ui_frame_skill_tree_path_lore.png",
    FAMILY_DIR / "ui_frame_skill_tree_path_might.png",
    FAMILY_DIR / "ui_frame_skill_tree_path_endure.png",
    FAMILY_DIR / "ui_frame_skill_tree_main.png",
]

# --- Frame-gold selector (broad: this family is darker/oranger than minimal_metal) --
SEL_HUE_MIN, SEL_HUE_MAX = 15.0, 70.0  # degrees
SEL_SAT_MIN = 0.30
SEL_VAL_MIN = 0.35

# --- Dark-brass remap (identical to SCRUM-817 minimal_metal family) ------------------
HUE_SHIFT = -3.0
SAT_SCALE = 0.68
VAL_MIN = 0.52
VAL_OUT_LO, VAL_OUT_HI = 0.30, 0.50

# --- Audit bright metric (SCRUM-809): bright orange-gold in the outer 15% edge band --
BR_HUE_MIN, BR_HUE_MAX = 30.0, 68.0
BR_SAT_MIN = 0.42
BR_VAL_MIN = 0.52
EDGE_BAND = 0.15
BRIGHT_LIMIT = 5.0

# Decorative ornaments (enclosed gold islands) to recolor anyway: name -> [(x0,y0,x1,y1)]
# (half-open on the upper bound). Verified by interior-component bbox measurement.
ORNAMENTS = {
    "ui_frame_skill_tree_main": [(610, 652, 669, 707)],        # bottom diamond
    "ui_frame_skill_tree_class_popup": [(66, 104, 493, 112)],  # header divider line
}


def rgb_to_hsv(rgb: np.ndarray):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn
    safe_d = np.where(d == 0.0, 1.0, d)
    h = np.zeros_like(mx)
    m_r = (mx == r) & (d > 0)
    m_g = (mx == g) & (d > 0) & ~m_r
    m_b = (mx == b) & (d > 0) & ~m_r & ~m_g
    h[m_r] = ((g - b)[m_r] / safe_d[m_r]) % 6.0
    h[m_g] = (b - r)[m_g] / safe_d[m_g] + 2.0
    h[m_b] = (r - g)[m_b] / safe_d[m_b] + 4.0
    s = np.where(mx > 0.0, d / np.where(mx == 0.0, 1.0, mx), 0.0)
    return h * 60.0, s, mx


def hsv_to_rgb(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    h6 = (h % 360.0) / 60.0
    i = np.floor(h6).astype(int) % 6
    f = h6 - np.floor(h6)
    p = v * (1.0 - s)
    q = v * (1.0 - s * f)
    t = v * (1.0 - s * (1.0 - f))
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=-1)


def _dilate(m: np.ndarray) -> np.ndarray:
    g = m.copy()
    g[1:, :] |= m[:-1, :]
    g[:-1, :] |= m[1:, :]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    g[1:, 1:] |= m[:-1, :-1]
    g[1:, :-1] |= m[:-1, 1:]
    g[:-1, 1:] |= m[1:, :-1]
    g[:-1, :-1] |= m[1:, 1:]
    return g


def _flood(passable: np.ndarray, seed: np.ndarray) -> np.ndarray:
    res = seed & passable
    frontier = res.copy()
    while frontier.any():
        newf = _dilate(frontier) & passable & ~res
        res |= newf
        frontier = newf
    return res


def gold_mask(arr: np.ndarray) -> np.ndarray:
    rgb = arr[..., :3].astype(np.float64) / 255.0
    alpha = arr[..., 3]
    h, s, v = rgb_to_hsv(rgb)
    return ((alpha > 0) & (h >= SEL_HUE_MIN) & (h <= SEL_HUE_MAX)
            & (s >= SEL_SAT_MIN) & (v >= SEL_VAL_MIN))


def bright_mask(arr: np.ndarray) -> np.ndarray:
    rgb = arr[..., :3].astype(np.float64) / 255.0
    alpha = arr[..., 3]
    h, s, v = rgb_to_hsv(rgb)
    return ((alpha > 0) & (h >= BR_HUE_MIN) & (h <= BR_HUE_MAX)
            & (s >= BR_SAT_MIN) & (v >= BR_VAL_MIN))


def frame_mask(arr: np.ndarray, stem: str):
    """Return (recolor_mask, protect_mask). Frame gold + opted-in ornaments recolor;
    enclosed text/emblems are protected."""
    mask = gold_mask(arr)
    non = ~mask
    seed = np.zeros_like(non)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    outside = _flood(non, seed & non)
    frame = _flood(mask, mask & _dilate(outside))
    recolor = frame.copy()
    for x0, y0, x1, y1 in ORNAMENTS.get(stem, []):
        band = np.zeros_like(mask)
        band[y0:y1, x0:x1] = True
        recolor |= mask & band
    protect = mask & ~recolor
    return recolor, protect


def recolor(arr: np.ndarray, stem: str):
    recolor_m, protect_m = frame_mask(arr, stem)
    count = int(recolor_m.sum())
    if count == 0:
        return arr, 0, int(protect_m.sum())
    out = arr.copy()
    rgb = arr[..., :3].astype(np.float64) / 255.0
    h, s, v = rgb_to_hsv(rgb)
    h2 = h[recolor_m] + HUE_SHIFT
    s2 = np.clip(s[recolor_m] * SAT_SCALE, 0.0, 1.0)
    span = max(1.0 - VAL_MIN, 1e-6)
    v2 = VAL_OUT_LO + (np.clip(v[recolor_m], VAL_MIN, 1.0) - VAL_MIN) / span * (VAL_OUT_HI - VAL_OUT_LO)
    new_rgb = np.clip(np.rint(hsv_to_rgb(h2, s2, v2) * 255.0), 0, 255).astype(np.uint8)
    out[..., :3][recolor_m] = new_rgb
    return out, count, int(protect_m.sum())


def edge_band_bright_share(arr: np.ndarray, exclude: np.ndarray | None = None) -> float:
    height, width = arr.shape[:2]
    bh = max(1, int(round(height * EDGE_BAND)))
    bw = max(1, int(round(width * EDGE_BAND)))
    band = np.zeros((height, width), dtype=bool)
    band[:bh, :] = True
    band[-bh:, :] = True
    band[:, :bw] = True
    band[:, -bw:] = True
    opaque = (arr[..., 3] > 0) & band
    bright = bright_mask(arr) & band
    if exclude is not None:
        bright = bright & ~exclude
    total = int(opaque.sum())
    if total == 0:
        return 0.0
    return 100.0 * int(bright.sum()) / total


def build_preview(before: np.ndarray, after: np.ndarray, path: Path) -> None:
    gap = 24
    height, width = before.shape[:2]
    sheet = np.zeros((height, width * 2 + gap, 4), dtype=np.uint8)
    sheet[..., :3] = 18
    sheet[..., 3] = 255
    for offset, src in ((0, before), (width + gap, after)):
        tile = sheet[:, offset:offset + width, :].astype(np.float64)
        overlay = src.astype(np.float64)
        a = (overlay[..., 3:4]) / 255.0
        tile[..., :3] = overlay[..., :3] * a + tile[..., :3] * (1.0 - a)
        sheet[:, offset:offset + width, :3] = np.clip(np.rint(tile[..., :3]), 0, 255).astype(np.uint8)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--paths", nargs="*", type=Path, default=None)
    parser.add_argument("--check", action="store_true", help="report only, write nothing")
    parser.add_argument("--preview-dir", type=Path, default=None)
    args = parser.parse_args()

    targets = [p if p.is_absolute() else ROOT / p for p in (args.paths or DEFAULT_TARGETS)]
    failures = 0
    for target in targets:
        if not target.is_file():
            print(f"[MISS] {target}")
            failures += 1
            continue
        stem = target.stem
        img = Image.open(target)
        original_size = img.size
        arr = np.asarray(img.convert("RGBA")).copy()
        share_before = edge_band_bright_share(arr)
        new_arr, remapped, protected = recolor(arr, stem)
        _, protect_m = frame_mask(new_arr, stem)
        share_after = edge_band_bright_share(new_arr)
        share_after_frame = edge_band_bright_share(new_arr, exclude=protect_m)
        status = "OK" if share_after_frame < BRIGHT_LIMIT else "FAIL"
        if status == "FAIL":
            failures += 1
        print(f"[{status}] {target.name}: size={original_size[0]}x{original_size[1]} "
              f"recolored={remapped}px protected(text/emblem)={protected}px "
              f"edge-bright {share_before:.1f}% -> {share_after:.1f}% "
              f"(frame-only {share_after_frame:.1f}%, limit <{BRIGHT_LIMIT:.0f}%)")
        if args.check:
            continue
        if not np.array_equal(arr[..., 3], new_arr[..., 3]):
            raise AssertionError(f"alpha channel drifted for {target.name}")
        if args.preview_dir is not None:
            build_preview(arr, new_arr, args.preview_dir / f"{target.stem}_before_after.png")
        if remapped:
            Image.fromarray(new_arr).save(target)
            if Image.open(target).size != original_size:
                raise AssertionError(f"size drifted for {target.name}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
