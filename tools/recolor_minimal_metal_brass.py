#!/usr/bin/env python3
"""SCRUM-817: recolor the minimal_metal frame family rim from bright yellow to dark brass.

Art direction (SCRUM-806 reopen / SCRUM-809 audit): instead of bright yellow rims —
dark leather with a thin muted brass line, reference
``assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`` (brass line there:
hue ~30-36 deg, sat ~0.33-0.42, val ~0.20-0.37).

Method: selective HSV remap of *yellow* pixels only (audit bright-metric mask:
hue 30-68 deg, sat >= 0.42, val >= 0.52, alpha > 0). Everything else — the charcoal
body, shadows, alpha channel — is left byte-identical. PNG size is never changed,
so the .import sidecars and the 9-slice margins in ``ui_theme_paths.gd`` stay valid.

Source rim palette (same two colors across the whole family):
    #E4AA34 (228,170, 52) main line   -> ~#745D37 (116, 93, 55) dark brass
    #F5C460 (245,196, 96) highlight   -> ~#7B6848 (123,104, 72) muted brass glint

Usage:
    python3 tools/recolor_minimal_metal_brass.py             # recolor family in place
    python3 tools/recolor_minimal_metal_brass.py --check     # report only, no writes
    python3 tools/recolor_minimal_metal_brass.py --preview-dir docs/design/previews/scrum817
    python3 tools/recolor_minimal_metal_brass.py --paths a.png b.png   # custom targets
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FAMILY_DIR = ROOT / "assets/sprites/ui/frames/minimal_metal"

# The 5 live textures from the task spec + the dead hud_strip kept palette-consistent.
DEFAULT_TARGETS = [
    FAMILY_DIR / "ui_frame_minimal_metal_card.png",
    FAMILY_DIR / "ui_frame_minimal_metal_panel.png",
    FAMILY_DIR / "ui_frame_minimal_metal_field.png",
    FAMILY_DIR / "ui_frame_minimal_metal_tooltip.png",
    FAMILY_DIR / "ui_frame_minimal_metal_modal.png",
    FAMILY_DIR / "ui_frame_minimal_metal_hud_strip.png",
]

# --- Yellow-rim selector (audit SCRUM-809 bright-metric) ---------------------
HUE_MIN, HUE_MAX = 30.0, 68.0  # degrees
SAT_MIN = 0.42
VAL_MIN = 0.52

# --- Dark-brass remap ---------------------------------------------------------
HUE_SHIFT = -3.0          # 40 deg -> 37 deg, slightly browner (toward ref ~30-36)
SAT_SCALE = 0.68          # 0.77 -> 0.52 main, 0.61 -> 0.41 highlight
VAL_OUT_LO, VAL_OUT_HI = 0.30, 0.50  # remap [VAL_MIN..1.0] -> [0.30..0.50]
# Resulting vals (0.46/0.48) sit under the bright-metric floor of 0.52, inside the
# audit's "dark golden-brown, val ~0.3-0.45..0.5" reference band.

EDGE_BAND = 0.15          # audit edge band: outer 15% of each side
BRIGHT_LIMIT = 5.0        # acceptance: bright share of the edge band < 5%


def rgb_to_hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Vectorized RGB[0..1] -> (hue deg, sat, val)."""
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
    """Vectorized (hue deg, sat, val) -> RGB[0..1]."""
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


def yellow_mask(arr: np.ndarray) -> np.ndarray:
    """Bright-yellow rim mask on an RGBA uint8 array (audit metric)."""
    rgb = arr[..., :3].astype(np.float64) / 255.0
    alpha = arr[..., 3]
    h, s, v = rgb_to_hsv(rgb)
    return (alpha > 0) & (h >= HUE_MIN) & (h <= HUE_MAX) & (s >= SAT_MIN) & (v >= VAL_MIN)


def recolor(arr: np.ndarray) -> tuple[np.ndarray, int]:
    """Return (new RGBA array, number of remapped pixels). Alpha untouched."""
    mask = yellow_mask(arr)
    count = int(mask.sum())
    if count == 0:
        return arr, 0
    out = arr.copy()
    rgb = arr[..., :3].astype(np.float64) / 255.0
    h, s, v = rgb_to_hsv(rgb)
    h2 = h[mask] + HUE_SHIFT
    s2 = np.clip(s[mask] * SAT_SCALE, 0.0, 1.0)
    span = max(1.0 - VAL_MIN, 1e-6)
    v2 = VAL_OUT_LO + (np.clip(v[mask], VAL_MIN, 1.0) - VAL_MIN) / span * (VAL_OUT_HI - VAL_OUT_LO)
    new_rgb = np.clip(np.rint(hsv_to_rgb(h2, s2, v2) * 255.0), 0, 255).astype(np.uint8)
    out[..., :3][mask] = new_rgb
    return out, count


def edge_band_bright_share(arr: np.ndarray) -> float:
    """Audit metric: % of bright-yellow pixels among opaque pixels of the edge band."""
    height, width = arr.shape[:2]
    bh = max(1, int(round(height * EDGE_BAND)))
    bw = max(1, int(round(width * EDGE_BAND)))
    band = np.zeros((height, width), dtype=bool)
    band[:bh, :] = True
    band[-bh:, :] = True
    band[:, :bw] = True
    band[:, -bw:] = True
    opaque = (arr[..., 3] > 0) & band
    bright = yellow_mask(arr) & band
    total = int(opaque.sum())
    if total == 0:
        return 0.0
    return 100.0 * int(bright.sum()) / total


def build_preview(before: np.ndarray, after: np.ndarray, path: Path) -> None:
    """Side-by-side before|after sheet on a neutral dark backdrop."""
    gap = 24
    height, width = before.shape[:2]
    sheet = np.zeros((height, width * 2 + gap, 4), dtype=np.uint8)
    sheet[..., :3] = 18  # near-black backdrop so the rim is judged against game-like bg
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
    parser.add_argument("--paths", nargs="*", type=Path, default=None,
                        help="explicit PNG targets (default: the minimal_metal family)")
    parser.add_argument("--check", action="store_true",
                        help="report masks/edge-band shares only, write nothing")
    parser.add_argument("--preview-dir", type=Path, default=None,
                        help="write side-by-side before/after previews here")
    args = parser.parse_args()

    targets = [p if p.is_absolute() else ROOT / p for p in (args.paths or DEFAULT_TARGETS)]
    failures = 0
    for target in targets:
        if not target.is_file():
            print(f"[MISS] {target}")
            failures += 1
            continue
        img = Image.open(target)
        original_size = img.size
        arr = np.asarray(img.convert("RGBA")).copy()
        share_before = edge_band_bright_share(arr)
        new_arr, remapped = recolor(arr)
        share_after = edge_band_bright_share(new_arr)
        status = "OK" if share_after < BRIGHT_LIMIT else "FAIL"
        if status == "FAIL":
            failures += 1
        print(f"[{status}] {target.name}: size={original_size[0]}x{original_size[1]} "
              f"remapped={remapped}px edge-bright {share_before:.1f}% -> {share_after:.1f}% "
              f"(limit <{BRIGHT_LIMIT:.0f}%)")
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
