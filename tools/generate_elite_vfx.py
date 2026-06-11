"""Generate the elite unique-attack VFX assets.

Design task: design_elite_sprites_upsize_attack_vfx_task.md
Exact file names are consumed by the Back-end integration - do not rename.

Run from the project root:  python3 tools/generate_elite_vfx.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "effects"

OUTLINE = (36, 27, 43)


def canvas(width: int, height: int) -> Image.Image:
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))


def save(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / name)
    print("wrote", name)


def shockwave_ring() -> None:
    """Iron Bastion slam: heavy double ring with cracked chunks (512x512)."""
    size = 512
    img = canvas(size, size)
    rng = random.Random(17)
    c = size / 2.0

    def rough_ring(r_in: float, r_out: float, color: tuple, jitter: float, blur: float) -> None:
        ring = canvas(size, size)
        d = ImageDraw.Draw(ring)
        steps = 96
        outer, inner = [], []
        for i in range(steps):
            ang = math.tau * i / steps
            outer.append((c + math.cos(ang) * (r_out + rng.uniform(-jitter, jitter)),
                          c + math.sin(ang) * (r_out + rng.uniform(-jitter, jitter))))
            inner.append((c + math.cos(ang) * (r_in + rng.uniform(-jitter, jitter)),
                          c + math.sin(ang) * (r_in + rng.uniform(-jitter, jitter))))
        d.polygon(outer, fill=color)
        hole = canvas(size, size)
        ImageDraw.Draw(hole).polygon(inner, fill=(255, 255, 255, 255))
        ring = Image.composite(canvas(size, size), ring, hole.split()[3].point(lambda a: 255 if a > 0 else 0))
        img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(blur)))

    rough_ring(206.0, 244.0, (224, 196, 255, 120), 13.0, 2.5)   # outer dust band
    rough_ring(196.0, 226.0, (255, 255, 255, 200), 8.0, 1.6)    # main white band
    rough_ring(148.0, 168.0, (236, 218, 255, 150), 7.0, 1.8)    # inner echo ring
    # debris chunks flying outward
    for _ in range(26):
        ang = rng.uniform(0.0, math.tau)
        dist = rng.uniform(212.0, 248.0)
        r = rng.uniform(4.0, 11.0)
        x, y = c + math.cos(ang) * dist, c + math.sin(ang) * dist
        d = ImageDraw.Draw(img)
        d.ellipse((x - r - 2, y - r - 2, x + r + 2, y + r + 2), fill=OUTLINE + (140,))
        d.ellipse((x - r, y - r, x + r, y + r), fill=(214, 196, 240, 215))
    save(img, "elite_shockwave_ring.png")


def shadow_trail() -> None:
    """Night Stalker dash: smoky shadow streak fading to the left (256x128)."""
    width, height = 256, 128
    img = canvas(width, height)
    rng = random.Random(31)
    mid = height / 2.0
    blobs = canvas(width, height)
    d = ImageDraw.Draw(blobs)
    for i in range(34):
        t = i / 33.0
        x = 18 + t * (width - 44)
        density = t ** 1.25  # densest at the right (the stalker's position)
        r = rng.uniform(10.0, 26.0) * (0.45 + 0.75 * density)
        y = mid + rng.uniform(-1.0, 1.0) * (10.0 + 16.0 * (1.0 - density))
        alpha = int(40 + 165 * density)
        shade = rng.choice([(38, 22, 58), (52, 30, 78), (26, 16, 40)])
        d.ellipse((x - r, y - r * 0.72, x + r, y + r * 0.72), fill=shade + (alpha,))
    blobs = blobs.filter(ImageFilter.GaussianBlur(3.2))
    img.alpha_composite(blobs)
    # violet energy slivers inside the smoke
    sliv = canvas(width, height)
    sd = ImageDraw.Draw(sliv)
    for _ in range(9):
        x0 = rng.uniform(80, width - 26)
        y0 = mid + rng.uniform(-16, 16)
        ln = rng.uniform(14, 34)
        sd.line((x0, y0, x0 + ln, y0 + rng.uniform(-5, 5)), fill=(168, 92, 255, 150), width=3)
    img.alpha_composite(sliv.filter(ImageFilter.GaussianBlur(1.6)))
    save(img, "elite_shadow_trail.png")


def poison_lob() -> None:
    """Plague Prophet projectile: toxic glob with drips (96x96)."""
    size = 96
    img = canvas(size, size)
    c = size / 2.0
    halo = canvas(size, size)
    ImageDraw.Draw(halo).ellipse((c - 38, c - 38, c + 38, c + 38), fill=(118, 200, 96, 110))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(9)))
    d = ImageDraw.Draw(img)
    d.ellipse((c - 25, c - 23, c + 25, c + 27), fill=OUTLINE + (255,))
    d.ellipse((c - 22, c - 20, c + 22, c + 24), fill=(74, 130, 44, 255))
    d.ellipse((c - 18, c - 16, c + 16, c + 18), fill=(106, 178, 62, 255))
    d.ellipse((c - 11, c - 12, c + 1, c - 1), fill=(170, 230, 120, 255))
    d.ellipse((c - 7, c - 9, c - 2, c - 5), fill=(226, 255, 188, 255))
    # bubbles + drips
    d.ellipse((c + 6, c + 2, c + 13, c + 9), fill=(150, 214, 100, 230))
    d.ellipse((c - 14, c + 6, c - 8, c + 12), fill=(150, 214, 100, 220))
    d.polygon([(c - 4, c + 22), (c + 2, c + 22), (c - 1, c + 33)], fill=(106, 178, 62, 235))
    d.ellipse((c - 3, c + 30, c + 1, c + 35), fill=(140, 208, 92, 235))
    save(img, "elite_poison_lob.png")


def crystal_shard() -> None:
    """Shard Marshal projectile: faceted crystal pointing +X (96x96)."""
    size = 96
    img = canvas(size, size)
    c = size / 2.0
    halo = canvas(size, size)
    ImageDraw.Draw(halo).ellipse((c - 36, c - 26, c + 40, c + 26), fill=(190, 96, 255, 105))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(9)))
    d = ImageDraw.Draw(img)
    tip = (c + 38, c)
    tail_top = (c - 30, c - 13)
    tail_bot = (c - 30, c + 13)
    mid_top = (c + 6, c - 16)
    mid_bot = (c + 6, c + 16)
    body = [tail_top, mid_top, tip, mid_bot, tail_bot]
    d.polygon([(x - 2 if x < c else x + 2, y - 2 if y < c else y + 2) for x, y in body], fill=OUTLINE + (255,))
    d.polygon(body, fill=(132, 58, 196, 255))
    # facets
    d.polygon([tail_top, mid_top, (c + 2, c), (c - 26, c)], fill=(168, 92, 240, 255))
    d.polygon([mid_top, tip, (c + 2, c)], fill=(214, 150, 255, 255))
    d.line((tail_top, (c + 2, c)), fill=(238, 200, 255, 200), width=2)
    d.ellipse((c + 2, c - 8, c + 12, c - 1), fill=(244, 214, 255, 235))
    # small trailing chips
    d.polygon([(c - 38, c - 6), (c - 31, c - 9), (c - 33, c - 2)], fill=(168, 92, 240, 220))
    d.polygon([(c - 40, c + 6), (c - 33, c + 4), (c - 36, c + 11)], fill=(132, 58, 196, 210))
    save(img, "elite_crystal_shard.png")


def telegraph_circle() -> None:
    """Universal attack-zone warning circle, soft edge (512x512)."""
    size = 512
    img = canvas(size, size)
    c = size / 2.0
    # soft danger fill, stronger toward the rim so the ground stays readable
    fill = canvas(size, size)
    fd = ImageDraw.Draw(fill)
    for r, alpha in [(236, 56), (215, 34), (180, 24), (130, 18)]:
        fd.ellipse((c - r, c - r, c + r, c + r), fill=(255, 70, 46, alpha))
    img.alpha_composite(fill.filter(ImageFilter.GaussianBlur(7)))
    # strong rim
    rim = canvas(size, size)
    rd = ImageDraw.Draw(rim)
    rd.ellipse((c - 240, c - 240, c + 240, c + 240), outline=(255, 92, 60, 235), width=12)
    rd.ellipse((c - 226, c - 226, c + 226, c + 226), outline=(255, 176, 120, 170), width=5)
    img.alpha_composite(rim.filter(ImageFilter.GaussianBlur(2.2)))
    # ticks around the rim make rotation/animation readable
    td = ImageDraw.Draw(img)
    for i in range(16):
        ang = math.tau * i / 16.0
        x1 = c + math.cos(ang) * 206
        y1 = c + math.sin(ang) * 206
        x2 = c + math.cos(ang) * 228
        y2 = c + math.sin(ang) * 228
        td.line((x1, y1, x2, y2), fill=(255, 120, 80, 170), width=6)
    save(img, "elite_telegraph_circle.png")


def main() -> None:
    shockwave_ring()
    shadow_trail()
    poison_lob()
    crystal_shard()
    telegraph_circle()


if __name__ == "__main__":
    main()
