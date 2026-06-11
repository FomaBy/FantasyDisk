"""Upsize the four elite sprites from 192x192 to 256x256 in place.

High-quality Lanczos resample + unsharp mask keeps the painted detail crisp,
then a subtle palette-matched status aura makes elites read as "expensive"
versus regular mobs. Design task: design_elite_sprites_upsize_attack_vfx_task.md

Run from the project root:  python3 tools/upsize_elite_sprites.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

# Aura color per elite: matches each elite's signature palette accent.
ELITES = {
    "iron_bastion": (168, 92, 255),     # фиолетовые трещины брони
    "night_stalker": (150, 84, 235),    # фиолетовые глаза/перья
    "plague_prophet": (118, 200, 96),   # ядовито-зеленый
    "shard_marshal": (190, 96, 255),    # кристальный фиолет
}

TARGET = 256


def alpha_mask(img: Image.Image) -> Image.Image:
    return img.split()[3]


def build_aura(img: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    """Soft outer glow hugging the silhouette."""
    mask = alpha_mask(img).point(lambda a: 255 if a > 30 else 0)
    grown = mask.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(6))
    aura = Image.new("RGBA", img.size, color + (0,))
    aura.putalpha(grown.point(lambda a: int(a * 0.32)))
    return aura


def main() -> None:
    for name, accent in ELITES.items():
        path = ROOT / "assets" / "sprites" / "elites" / f"{name}.png"
        src = Image.open(path).convert("RGBA")
        if src.size == (TARGET, TARGET):
            print(f"{name}: already {TARGET}")
            continue
        big = src.resize((TARGET, TARGET), Image.LANCZOS)
        # Unsharp mask brings back painted edge crispness after the resample.
        sharp = big.filter(ImageFilter.UnsharpMask(radius=2, percent=88, threshold=2))
        # Keep alpha from the plain resize (unsharp can ring on the alpha edge).
        sharp.putalpha(alpha_mask(big))

        result = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
        result.alpha_composite(build_aura(sharp, accent))
        result.alpha_composite(sharp)
        result.save(path)
        print(f"{name}: {src.size} -> {result.size} with aura")


if __name__ == "__main__":
    main()
