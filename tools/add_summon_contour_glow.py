"""Add a light WHITE contour glow to every summon/ally sprite so the creatures
read clearly on any arena (user request SCRUM-336).

Approach (in-place, dimensions preserved): from the sprite alpha we build a
soft white halo — dilate the silhouette a few px, blur it, tint pure white at a
restrained peak alpha, and composite it UNDERNEATH the original art. The result
is a gentle rim/halo, not an outline stroke, and never burns the silhouette.

Original PNGs are backed up (once) to docs/design/backups/summon_noglow/ before
the first edit so the pass is reversible and re-runnable (it always re-derives
from the backup, so running twice does not stack the glow). Godot .import
sidecars are intentionally not copied into backup folders because they duplicate
live asset UIDs during --import.

Run from project root:  python3 tools/add_summon_contour_glow.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ALLIES = ROOT / "assets" / "sprites" / "allies"
BACKUP = ROOT / "docs" / "design" / "backups" / "summon_noglow"

# light glow params
DILATE = 3          # px the halo extends past the silhouette
BLUR = 6.0          # softness of the halo
PEAK_ALPHA = 165    # max opacity of the white halo (0-255) — "лёгкое свечение"


def targets() -> list[Path]:
    files: list[Path] = []
    for name in (
        "ally_druid_beast.png",
        "ally_druid_pack_spirit.png",
        "ally_homunculus.png",
        "ally_leadership_echo.png",
        "deploy_raven_totem_field.png",
        "deploy_sound_amp_field.png",
    ):
        p = ALLIES / name
        if p.exists():
            files.append(p)
    files.extend(sorted((ALLIES / "druid_wolf").glob("*.png")))
    return files


def source_for(p: Path) -> Path:
    """Return the no-glow source: back up once, then always read the backup."""
    rel = p.relative_to(ALLIES)
    bak = BACKUP / rel
    if not bak.exists():
        bak.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, bak)
    return bak


def add_glow(src: Path, dst: Path) -> None:
    base = Image.open(src).convert("RGBA")
    alpha = base.split()[3]
    # silhouette -> dilate -> blur -> white halo
    halo_a = alpha.filter(ImageFilter.MaxFilter(DILATE * 2 + 1))
    halo_a = halo_a.filter(ImageFilter.GaussianBlur(BLUR))
    halo_a = halo_a.point(lambda v: int(v * PEAK_ALPHA / 255))
    halo = Image.new("RGBA", base.size, (255, 255, 255, 0))
    halo.putalpha(halo_a)
    # halo under the original art
    out = Image.alpha_composite(halo, base)
    out.save(dst)


def main() -> None:
    n = 0
    for p in targets():
        src = source_for(p)
        add_glow(src, p)
        n += 1
    print(f"contour glow applied to {n} summon sprites (backup: {BACKUP.relative_to(ROOT)})")


if __name__ == "__main__":
    main()
