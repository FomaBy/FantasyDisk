#!/usr/bin/env python3
"""Build SCRUM-337 runtime VFX PNGs from generated source sheets.

The source sheets are generated through the FantasyDisk asset-generator skill.
This script only performs deterministic crop, chroma cleanup, resizing, and
preview assembly so the accepted runtime paths keep their existing filenames
and canvas sizes.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "docs/design/references/attack_vfx_realistic_dark_fantasy"
PREVIEW_DIR = ROOT / "docs/design/previews"
QA_DIR = ROOT / "build/qa/scrum337"


@dataclass(frozen=True)
class Plate:
    source: str
    cell: int
    path: str
    size: tuple[int, int]
    placement: str = "center"
    fill: float = 0.86


GENERIC = [
    ("slash_arc.png", (256, 256), "slash", 0.96),
    ("impact_ring.png", (256, 256), "center", 0.96),
    ("impact_flash.png", (128, 128), "center", 0.92),
    ("beam_strip.png", (256, 64), "beam", 1.00),
    ("sound_wave.png", (192, 192), "sound_wave", 0.96),
    ("void_orb.png", (96, 96), "center", 0.92),
    ("music_note.png", (64, 64), "center", 0.90),
    ("dust_puff_0.png", (128, 128), "center", 0.90),
    ("hazard_zone.png", (256, 256), "center", 0.96),
    ("poison_pool.png", (256, 256), "center", 0.96),
    ("spark_pool.png", (256, 256), "center", 0.96),
    ("briar_pool.png", (256, 256), "center", 0.96),
    ("enemy_projectile_magic_64.png", (64, 64), "center", 0.88),
    ("player_projectile_spark_64.png", (64, 64), "center", 0.88),
    ("elite_crystal_shard.png", (96, 96), "center", 0.92),
    ("elite_poison_lob.png", (96, 96), "center", 0.92),
]

BOSS_ELITE = [
    ("boss_ash_ember_zone.png", (512, 512), "center", 0.98),
    ("boss_bone_prison_zone.png", (512, 512), "center", 0.98),
    ("boss_brood_web_zone.png", (512, 512), "center", 0.98),
    ("boss_gravity_well_zone.png", (512, 512), "center", 0.98),
    ("boss_molten_armor_pulse.png", (512, 512), "center", 0.98),
    ("boss_rift_zone.png", (512, 512), "center", 0.98),
    ("boss_vampiric_bite_zone.png", (512, 512), "center", 0.98),
    ("enemy_command_aura_pulse.png", (512, 512), "center", 0.98),
    ("enemy_reflect_thorns_aura.png", (512, 512), "center", 0.98),
    ("enemy_shadow_blink_mark.png", (512, 512), "center", 0.92),
    ("enemy_shard_fan_burst.png", (512, 512), "center", 0.96),
    ("enemy_shield_block_front.png", (256, 256), "center", 0.94),
    ("enemy_summon_portal.png", (512, 512), "center", 0.98),
    ("elite_shockwave_ring.png", (512, 512), "center", 0.98),
    ("elite_telegraph_circle.png", (512, 512), "center", 0.98),
    ("elite_shadow_trail.png", (256, 128), "center", 0.96),
]

WEAPONS_1 = [
    "acid_flask", "axe", "bass_guitar", "biologist_sample_injector",
    "biologist_spore_lens", "biologist_symbiote_seed", "blast_powder",
    "bone_saw", "briar_staff", "chakrams", "cursed_skull", "dark_book",
    "dark_wand", "electric_guitar", "elementalist_meteor_core",
    "elementalist_orb_ring",
]

WEAPONS_2 = [
    "elementalist_prism_focus", "engineer_pressure_mines",
    "engineer_repair_drone", "engineer_sentry_wrench", "hammer",
    "holy_flail", "homunculus_vial", "hunter_trap", "long_spear",
    "moon_crossbow", "plague_syringe", "priest_censer", "priest_chime",
    "priest_reliquary", "raven_totem", "restore_potion",
]

WEAPONS_3 = [
    "robot_hydraulic_press", "robot_magnetic_anchor", "robot_reactor_core",
    "shadow_daggers", "sniper_deadeye_rifle", "sniper_shatter_rounds",
    "sniper_spotter_scope", "soldier_bayonet", "soldier_grenade",
    "soldier_rifle", "sound_amp", "storm_longbow", "summon_amulet",
    "sword", "thief_coin_pouch", "thief_shadow_cloak",
]

WEAPONS_4 = ["thief_smoke_bomb", "tower_shield", "venom_wire"]


def _plates() -> list[Plate]:
    plates: list[Plate] = []
    for index, (name, size, placement, fill) in enumerate(GENERIC):
        folder = "projectiles" if name.endswith("_64.png") else "effects"
        plates.append(Plate("generic_core_sheet.png", index, f"assets/sprites/{folder}/{name}", size, placement, fill))
    for index, (name, size, placement, fill) in enumerate(BOSS_ELITE):
        plates.append(Plate("boss_elite_sheet.png", index, f"assets/sprites/effects/{name}", size, placement, fill))
    for sheet_name, weapons in [
        ("weapon_signatures_sheet_1.png", WEAPONS_1),
        ("weapon_signatures_sheet_2.png", WEAPONS_2),
        ("weapon_signatures_sheet_3.png", WEAPONS_3),
        ("weapon_signatures_sheet_4.png", WEAPONS_4),
    ]:
        for index, weapon in enumerate(weapons):
            plates.append(Plate(sheet_name, index, f"assets/sprites/effects/vfx_weapon_{weapon}.png", (256, 256), "center", 0.90))
    # Additional dust puffs reuse the same generated dust source with small
    # rotations so HammerSlam keeps visual variety without adding extra sources.
    plates.append(Plate("generic_core_sheet.png", 7, "assets/sprites/effects/dust_puff_1.png", (128, 128), "center", 0.88))
    plates.append(Plate("generic_core_sheet.png", 7, "assets/sprites/effects/dust_puff_2.png", (128, 128), "center", 0.86))
    return plates


def _cell(sheet: Image.Image, index: int, cols: int = 4, rows: int = 4) -> Image.Image:
    width, height = sheet.size
    col = index % cols
    row = index // cols
    cell_w = width // cols
    cell_h = height // rows
    inset = max(8, min(cell_w, cell_h) // 28)
    box = (
        col * cell_w + inset,
        row * cell_h + inset,
        (col + 1) * cell_w - inset,
        (row + 1) * cell_h - inset,
    )
    return sheet.crop(box).convert("RGBA")


def _chroma_to_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            dist = ((r - 255) ** 2 + g ** 2 + (b - 255) ** 2) ** 0.5
            chroma_alpha = max(0.0, min(255.0, (dist - 40.0) / 95.0 * 255.0))
            new_alpha = int(min(float(a), chroma_alpha))
            if new_alpha < 2:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, new_alpha)
    return image


def _trim(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda px: 255 if px > 8 else 0).getbbox()
    if bbox is None:
        return image
    pad = 10
    box = (
        max(0, bbox[0] - pad),
        max(0, bbox[1] - pad),
        min(image.width, bbox[2] + pad),
        min(image.height, bbox[3] + pad),
    )
    return image.crop(box)


def _fit(image: Image.Image, size: tuple[int, int], placement: str, fill: float) -> Image.Image:
    target_w, target_h = size
    image = _trim(image)
    if image.width <= 0 or image.height <= 0:
        return Image.new("RGBA", size, (0, 0, 0, 0))

    if placement == "beam":
        ratio = min(target_w / image.width, target_h / image.height) * 1.10
        new_size = (max(1, int(image.width * ratio)), max(1, int(image.height * ratio)))
    else:
        ratio = min((target_w * fill) / image.width, (target_h * fill) / image.height)
        new_size = (max(1, int(image.width * ratio)), max(1, int(image.height * ratio)))

    image = image.resize(new_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if placement == "slash":
        x = int(target_w * 0.46 - image.width * 0.40)
        y = (target_h - image.height) // 2
    elif placement == "sound_wave":
        x = int(target_w * 0.36 - image.width * 0.22)
        y = (target_h - image.height) // 2
    elif placement == "beam":
        x = (target_w - image.width) // 2
        y = (target_h - image.height) // 2
    else:
        x = (target_w - image.width) // 2
        y = (target_h - image.height) // 2
    canvas.alpha_composite(image, (x, y))
    return canvas


def _variant(image: Image.Image, path: str) -> Image.Image:
    if path.endswith("dust_puff_1.png"):
        return image.rotate(16, resample=Image.Resampling.BICUBIC)
    if path.endswith("dust_puff_2.png"):
        return image.rotate(-19, resample=Image.Resampling.BICUBIC).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return image


def build_assets() -> list[dict]:
    sheets: dict[str, Image.Image] = {}
    for source in sorted({plate.source for plate in _plates()}):
        path = SOURCE_DIR / source
        if not path.exists():
            raise FileNotFoundError(f"missing generated source sheet: {path}")
        sheets[source] = Image.open(path).convert("RGBA")

    results: list[dict] = []
    for plate in _plates():
        cell = _cell(sheets[plate.source], plate.cell)
        cleaned = _chroma_to_alpha(cell)
        fitted = _fit(cleaned, plate.size, plate.placement, plate.fill)
        fitted = _variant(fitted, plate.path)
        out_path = ROOT / plate.path
        out_path.parent.mkdir(parents=True, exist_ok=True)
        fitted.save(out_path)
        results.append({
            "path": plate.path,
            "size": list(plate.size),
            "source": plate.source,
            "cell": plate.cell,
            "placement": plate.placement,
        })
    return results


def _checker(size: tuple[int, int], block: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (35, 32, 35, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            if (x // block + y // block) % 2 == 0:
                draw.rectangle((x, y, x + block - 1, y + block - 1), fill=(54, 48, 52, 255))
    return image


def make_contact(paths: Iterable[str], output: Path, columns: int, cell: tuple[int, int], title: str) -> None:
    paths = list(paths)
    rows = (len(paths) + columns - 1) // columns
    label_h = 28
    sheet = Image.new("RGBA", (columns * cell[0], rows * (cell[1] + label_h) + 36), (20, 18, 20, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((12, 10), title, fill=(230, 220, 196, 255), font=font)
    for index, rel in enumerate(paths):
        x = (index % columns) * cell[0]
        y = 36 + (index // columns) * (cell[1] + label_h)
        bg = _checker(cell)
        asset = Image.open(ROOT / rel).convert("RGBA")
        scale = min((cell[0] - 28) / asset.width, (cell[1] - 28) / asset.height)
        resized = asset.resize((max(1, int(asset.width * scale)), max(1, int(asset.height * scale))), Image.Resampling.LANCZOS)
        bg.alpha_composite(resized, ((cell[0] - resized.width) // 2, (cell[1] - resized.height) // 2))
        sheet.alpha_composite(bg, (x, y))
        draw.rectangle((x, y, x + cell[0] - 1, y + cell[1] - 1), outline=(82, 70, 58, 255))
        label = Path(rel).stem.replace("vfx_weapon_", "")
        draw.text((x + 6, y + cell[1] + 7), label[:34], fill=(225, 218, 202, 255), font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output)


def main() -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    results = build_assets()
    (SOURCE_DIR / "scrum337_runtime_manifest.json").write_text(
        json.dumps({"task": "SCRUM-337", "asset_count": len(results), "assets": results}, indent=2),
        encoding="utf-8",
    )
    effects = [item["path"] for item in results if item["path"].startswith("assets/sprites/effects/")]
    weapons = [p for p in effects if Path(p).name.startswith("vfx_weapon_")]
    non_weapons = [p for p in effects if p not in weapons]
    projectiles = [item["path"] for item in results if item["path"].startswith("assets/sprites/projectiles/")]
    make_contact(non_weapons + projectiles, PREVIEW_DIR / "scrum337_attack_vfx_core_contact.png", 8, (128, 128), "SCRUM-337 core, projectile, elite and boss VFX")
    make_contact(weapons, PREVIEW_DIR / "scrum337_attack_vfx_weapon_contact.png", 9, (112, 112), "SCRUM-337 weapon signature VFX")
    print(f"built {len(results)} runtime VFX assets")


if __name__ == "__main__":
    main()
