"""Generate painted-style attack VFX textures.

Produces tintable (white/gray) and pre-colored effect sprites that match the
dark-fantasy cartoon art direction: strong dark outlines, volumetric falloff,
chunky painted edges. Consumed by scripts/attack_vfx.gd.

Run from the project root:  python3 tools/generate_attack_vfx.py
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


def slash_arc() -> None:
    """Crescent slash: hot leading edge, feathered trail. White = tintable."""
    size = 256
    img = canvas(size, size)
    rng = random.Random(7)
    center = (40.0, size / 2.0)
    sweep_start = -0.95
    sweep_end = 0.95
    layers = [
        (118.0, 196.0, 235, 18),   # bright core band
        (102.0, 208.0, 150, 30),   # mid band
        (86.0, 216.0, 80, 44),     # outer glow band
    ]
    for inner_r, outer_r, alpha, jitter in layers:
        band = canvas(size, size)
        d = ImageDraw.Draw(band)
        steps = 64
        points_outer = []
        points_inner = []
        for i in range(steps + 1):
            t = i / steps
            ang = sweep_start + (sweep_end - sweep_start) * t
            fade = math.sin(t * math.pi) ** 0.65
            r_out = outer_r * (0.55 + 0.45 * fade) + rng.uniform(-jitter * 0.2, jitter * 0.2)
            # taper the band to sharp points at both ends of the sweep
            taper = math.sin(t * math.pi) ** 0.35
            r_in = r_out - (r_out - inner_r * (0.72 + 0.28 * fade)) * taper
            points_outer.append((center[0] + math.cos(ang) * r_out, center[1] + math.sin(ang) * r_out))
            points_inner.append((center[0] + math.cos(ang) * r_in, center[1] + math.sin(ang) * r_in))
        d.polygon(points_outer + points_inner[::-1], fill=(255, 255, 255, alpha))
        band = band.filter(ImageFilter.GaussianBlur(2.2))
        img.alpha_composite(band)
    # hot edge along the outer rim
    edge = canvas(size, size)
    d = ImageDraw.Draw(edge)
    steps = 64
    pts = []
    for i in range(steps + 1):
        t = i / steps
        ang = sweep_start + (sweep_end - sweep_start) * t
        fade = math.sin(t * math.pi) ** 0.65
        r = 206.0 * (0.55 + 0.45 * fade)
        pts.append((center[0] + math.cos(ang) * r, center[1] + math.sin(ang) * r))
    d.line(pts, fill=(255, 255, 255, 235), width=7)
    edge = edge.filter(ImageFilter.GaussianBlur(1.2))
    img.alpha_composite(edge)
    save(img, "slash_arc.png")


def impact_ring() -> None:
    """Chunky shockwave ring, white = tintable."""
    size = 256
    img = canvas(size, size)
    rng = random.Random(11)
    c = size / 2.0
    ring = canvas(size, size)
    d = ImageDraw.Draw(ring)
    steps = 72
    outer = []
    inner = []
    for i in range(steps):
        ang = math.tau * i / steps
        r_out = 116.0 + rng.uniform(-7.0, 7.0)
        r_in = 86.0 + rng.uniform(-6.0, 6.0)
        outer.append((c + math.cos(ang) * r_out, c + math.sin(ang) * r_out))
        inner.append((c + math.cos(ang) * r_in, c + math.sin(ang) * r_in))
    d.polygon(outer, fill=(255, 255, 255, 130))
    hole = canvas(size, size)
    hd = ImageDraw.Draw(hole)
    hd.polygon(inner, fill=(255, 255, 255, 255))
    ring = Image.composite(canvas(size, size), ring, hole.split()[3].point(lambda a: 255 if a > 0 else 0))
    ring = ring.filter(ImageFilter.GaussianBlur(1.6))
    img.alpha_composite(ring)
    # bright rim
    rim = canvas(size, size)
    rd = ImageDraw.Draw(rim)
    rd.ellipse((c - 104, c - 104, c + 104, c + 104), outline=(255, 255, 255, 225), width=9)
    rim = rim.filter(ImageFilter.GaussianBlur(2.4))
    img.alpha_composite(rim)
    save(img, "impact_ring.png")


def dust_puff() -> None:
    """Cartoon dust cloud, pre-colored sandy gray with soft outline."""
    size = 128
    rng = random.Random(23)
    for variant in range(3):
        img = canvas(size, size)
        blobs = []
        for _ in range(9):
            r = rng.uniform(16, 30)
            x = rng.uniform(34, size - 34)
            y = rng.uniform(44, size - 38)
            blobs.append((x, y, r))
        # outline pass
        outline = canvas(size, size)
        od = ImageDraw.Draw(outline)
        for x, y, r in blobs:
            od.ellipse((x - r - 4, y - r - 4, x + r + 4, y + r + 4), fill=OUTLINE + (170,))
        outline = outline.filter(ImageFilter.GaussianBlur(1.4))
        img.alpha_composite(outline)
        # body pass
        body = canvas(size, size)
        bd = ImageDraw.Draw(body)
        for x, y, r in blobs:
            bd.ellipse((x - r, y - r, x + r, y + r), fill=(168, 152, 128, 235))
        body = body.filter(ImageFilter.GaussianBlur(1.0))
        img.alpha_composite(body)
        # top light
        light = canvas(size, size)
        ld = ImageDraw.Draw(light)
        for x, y, r in blobs:
            ld.ellipse((x - r * 0.7, y - r - 2, x + r * 0.7, y + r * 0.1), fill=(214, 200, 176, 190))
        light = light.filter(ImageFilter.GaussianBlur(2.6))
        img.alpha_composite(light)
        save(img, f"dust_puff_{variant}.png")
        rng.seed(23 + variant * 31 + 7)


def void_orb() -> None:
    """Dark mage projectile: void sphere with magenta rim and glow halo."""
    size = 96
    img = canvas(size, size)
    c = size / 2.0
    halo = canvas(size, size)
    hd = ImageDraw.Draw(halo)
    hd.ellipse((c - 40, c - 40, c + 40, c + 40), fill=(168, 92, 255, 110))
    halo = halo.filter(ImageFilter.GaussianBlur(9))
    img.alpha_composite(halo)
    d = ImageDraw.Draw(img)
    d.ellipse((c - 26, c - 26, c + 26, c + 26), fill=OUTLINE + (255,))
    d.ellipse((c - 23, c - 23, c + 23, c + 23), fill=(96, 38, 160, 255))
    d.ellipse((c - 19, c - 19, c + 19, c + 19), fill=(58, 18, 96, 255))
    d.ellipse((c - 12, c - 14, c + 4, c + 2), fill=(140, 70, 220, 255))
    d.ellipse((c - 7, c - 10, c - 1, c - 4), fill=(220, 170, 255, 255))
    # swirl crescent
    d.arc((c - 16, c - 16, c + 16, c + 16), start=300, end=80, fill=(196, 120, 255, 230), width=4)
    save(img, "void_orb.png")


def beam_strip() -> None:
    """Horizontal beam, white = tintable; bright core + soft sheath."""
    width, height = 256, 64
    img = canvas(width, height)
    mid = height / 2.0
    sheath = canvas(width, height)
    sd = ImageDraw.Draw(sheath)
    sd.rounded_rectangle((4, mid - 20, width - 4, mid + 20), radius=20, fill=(255, 255, 255, 135))
    sheath = sheath.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(sheath)
    core = canvas(width, height)
    cd = ImageDraw.Draw(core)
    cd.rounded_rectangle((8, mid - 7, width - 8, mid + 7), radius=7, fill=(255, 255, 255, 235))
    core = core.filter(ImageFilter.GaussianBlur(1.4))
    img.alpha_composite(core)
    # energy ripples
    rip = canvas(width, height)
    rd = ImageDraw.Draw(rip)
    rng = random.Random(5)
    for _ in range(7):
        x = rng.uniform(20, width - 30)
        r = rng.uniform(6, 13)
        rd.ellipse((x - r, mid - r, x + r, mid + r), outline=(255, 255, 255, 150), width=3)
    rip = rip.filter(ImageFilter.GaussianBlur(1.2))
    img.alpha_composite(rip)
    save(img, "beam_strip.png")


def sound_wave() -> None:
    """Three expanding painted arcs ')))' opening to +X. White = tintable."""
    size = 192
    img = canvas(size, size)
    center = (26.0, size / 2.0)
    for idx, (radius, width, alpha) in enumerate([(52, 13, 245), (96, 16, 195), (142, 19, 140)]):
        arc = canvas(size, size)
        d = ImageDraw.Draw(arc)
        box = (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius)
        d.arc(box, start=-52, end=52, fill=(255, 255, 255, alpha), width=width)
        arc = arc.filter(ImageFilter.GaussianBlur(1.5 + idx * 0.6))
        img.alpha_composite(arc)
    save(img, "sound_wave.png")


def impact_flash() -> None:
    """Star flash, white = tintable."""
    size = 128
    img = canvas(size, size)
    c = size / 2.0
    flash = canvas(size, size)
    d = ImageDraw.Draw(flash)
    for spikes, length, alpha in [(4, 56.0, 230), (8, 34.0, 160)]:
        for i in range(spikes):
            ang = math.tau * i / spikes + (0.0 if spikes == 4 else math.pi / 8)
            tip = (c + math.cos(ang) * length, c + math.sin(ang) * length)
            side = 7.0
            left = (c + math.cos(ang + math.pi / 2) * side, c + math.sin(ang + math.pi / 2) * side)
            right = (c + math.cos(ang - math.pi / 2) * side, c + math.sin(ang - math.pi / 2) * side)
            d.polygon([left, tip, right], fill=(255, 255, 255, alpha))
    flash = flash.filter(ImageFilter.GaussianBlur(1.5))
    img.alpha_composite(flash)
    d2 = ImageDraw.Draw(img)
    d2.ellipse((c - 13, c - 13, c + 13, c + 13), fill=(255, 255, 255, 250))
    save(img, "impact_flash.png")


def music_note() -> None:
    """Golden music note with dark outline (guitarist flavor)."""
    size = 64
    img = canvas(size, size)
    d = ImageDraw.Draw(img)

    def note_pass(offset: float, color: tuple) -> None:
        head = (18 - offset, 44 - offset, 34 + offset, 56 + offset)
        d.ellipse(head, fill=color)
        d.rounded_rectangle((30 - offset, 12 - offset, 35 + offset, 50), radius=2, fill=color)
        d.polygon([(30 - offset, 12 - offset), (48 + offset, 18), (48 + offset, 30 + offset), (30 - offset, 24)], fill=color)

    note_pass(2.5, OUTLINE + (255,))
    note_pass(0.0, (255, 198, 64, 255))
    d.ellipse((21, 46, 28, 51), fill=(255, 236, 170, 255))
    save(img, "music_note.png")


def main() -> None:
    slash_arc()
    impact_ring()
    dust_puff()
    void_orb()
    beam_strip()
    sound_wave()
    impact_flash()
    music_note()


if __name__ == "__main__":
    main()
