#!/usr/bin/env python3
"""Generate SCRUM-352 full-frame animation sheet source PNGs.

This is a task-specific wrapper around the FantasyDisk asset-generator standard:
OpenAI Images API, transparent PNG outputs, deterministic project paths, and no
runtime integration. It intentionally does not create extra task files.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


MODEL = "gpt-image-2"
OUTPUT_SIZE = "1536x1024"
FRAME_SIZE = 256
FRAME_COLUMNS = 6
FRAME_ROWS = 4


@dataclass(frozen=True)
class EntitySpec:
    entity_id: str
    kind: str
    title: str
    source_path: str
    visual_note: str
    rows: tuple[str, str, str, str]

    @property
    def asset_folder(self) -> str:
        return {
            "enemy": "assets/sprites/enemies/full_frame",
            "elite": "assets/sprites/elites/full_frame",
            "boss": "assets/sprites/bosses/full_frame",
        }[self.kind]


STANDARD_ROWS = ("move", "attack_primary", "hit_react", "death")


ENTITIES: tuple[EntitySpec, ...] = (
    EntitySpec("rift_cutter", "enemy", "Rift Cutter", "assets/sprites/enemies/enemy_melee.png", "scarred melee raider with curved blades and rift scars", STANDARD_ROWS),
    EntitySpec("ash_marksman", "enemy", "Ash Marksman", "assets/sprites/enemies/enemy_ranged.png", "ashy ranged crossbow monster, hunched shooter silhouette", STANDARD_ROWS),
    EntitySpec("spark_runner", "enemy", "Spark Runner", "assets/sprites/enemies/enemy_suicide_runner.png", "fast electric beast with tail and low sprint posture", STANDARD_ROWS),
    EntitySpec("stone_bruiser", "enemy", "Stone Bruiser", "assets/sprites/enemies/enemy_bruiser_slow.png", "large slow rocky brawler, heavy fists and grounded steps", STANDARD_ROWS),
    EntitySpec("bone_caller", "enemy", "Bone Caller", "assets/sprites/enemies/enemy_summoner.png", "bone summoner cultist with staff and skull charms", STANDARD_ROWS),
    EntitySpec("void_mage", "enemy", "Void Mage", "assets/sprites/enemies/enemy_void_mage.png", "floating hooded void caster with purple magic", STANDARD_ROWS),
    EntitySpec("venom_spitter", "enemy", "Venom Spitter", "assets/sprites/enemies/enemy_venom_spitter.png", "toxic crawling spitter with swollen venom throat", STANDARD_ROWS),
    EntitySpec("rift_shieldbearer", "enemy", "Rift Shieldbearer", "assets/sprites/enemies/enemy_rift_shieldbearer.png", "frontline shield monster with cracked rift shield", STANDARD_ROWS),
    EntitySpec("small_biter", "enemy", "Small Biter", "assets/sprites/enemies/enemy_small_biter.png", "small vicious biting crawler, fast low silhouette", STANDARD_ROWS),
    EntitySpec("bone_shaman", "enemy", "Bone Shaman", "assets/sprites/enemies/enemy_bone_shaman.png", "advanced bone shaman with raised ritual staff", STANDARD_ROWS),
    EntitySpec("winged_spark", "enemy", "Winged Spark", "assets/sprites/enemies/enemy_winged_spark.png", "small flying electric imp with flapping wings and tucked legs", ("move", "attack_primary", "hover_flap", "death")),
    EntitySpec("iron_bastion", "elite", "Iron Bastion", "assets/sprites/elites/iron_bastion.png", "armored shield elite, jagged iron plates, brutal tank silhouette", ("move", "attack_primary", "skill_shield_block", "skill_slam_wave")),
    EntitySpec("night_stalker", "elite", "Night Stalker", "assets/sprites/elites/night_stalker.png", "shadow assassin elite with long claws and smoky cloak", ("move", "attack_primary", "skill_shadow_strike", "skill_phase_dash")),
    EntitySpec("plague_prophet", "elite", "Plague Prophet", "assets/sprites/elites/plague_prophet.png", "plague priest elite with bells, fumes, and sick green magic", ("move", "attack_primary", "skill_poison_volley", "skill_plague_aura")),
    EntitySpec("shard_marshal", "elite", "Shard Marshal", "assets/sprites/elites/shard_marshal.png", "crystalline commander elite, shard fan caster, command posture", ("move", "attack_primary", "skill_shard_fan", "skill_command_pulse")),
    EntitySpec("mini_scavenger_reaper", "elite", "Mini Scavenger Reaper", "assets/sprites/elites/mini_scavenger_reaper.png", "small reaper scavenger with hooked scythe, nimble elite silhouette", ("move", "attack_primary", "skill_reaping_dash", "skill_bleed_finish")),
    EntitySpec("mini_plague_bellringer", "elite", "Mini Plague Bellringer", "assets/sprites/elites/mini_plague_bellringer.png", "small plague bellringer with heavy bell and miasma", ("move", "attack_primary", "skill_bell_toll", "skill_poison_pool")),
    EntitySpec("mini_bone_warden", "elite", "Mini Bone Warden", "assets/sprites/elites/mini_bone_warden.png", "compact bone tank warden with shield and rib armor", ("move", "attack_primary", "skill_bone_guard", "skill_slam_wave")),
    EntitySpec("mini_spark_wight", "elite", "Mini Spark Wight", "assets/sprites/elites/mini_spark_wight.png", "small spark wight caster, blue static and jagged crystal sparks", ("move", "attack_primary", "skill_spark_fan", "skill_static_field")),
    EntitySpec("mini_rot_hound", "elite", "Mini Rot Hound", "assets/sprites/elites/mini_rot_hound.png", "rotting hound beast, fast quadruped lunge silhouette", ("move", "attack_primary", "skill_rot_lunge", "skill_bleed_howl")),
    EntitySpec("mini_shadow_devourer", "elite", "Mini Shadow Devourer", "assets/sprites/elites/mini_shadow_devourer.png", "shadow devourer beast with black smoke jaws and purple glow", ("move", "attack_primary", "skill_shadow_blink", "skill_devour_bite")),
    EntitySpec("rift_warden", "boss", "Rift Warden", "assets/sprites/bosses/boss_rift_warden.png", "massive rift armored boss with vortex core and floating void fragments", ("move", "attack_primary", "skill_gravity_well", "skill_rift_zone")),
    EntitySpec("disk_devourer", "boss", "Disk Devourer", "assets/sprites/bosses/boss_disk_devourer.png", "huge many-eyed maw boss, tentacles, circular teeth and purple core", ("move", "attack_primary", "skill_vampiric_bite", "skill_rift_zone")),
    EntitySpec("bone_archon", "boss", "Bone Archon", "assets/sprites/bosses/boss_bone_archon.png", "necromancer bone archon boss, skull crown and bone magic", ("move", "attack_primary", "skill_skull_volley", "skill_bone_prison")),
    EntitySpec("brood_mother", "boss", "Brood Mother", "assets/sprites/bosses/boss_brood_mother.png", "spider brood queen boss, web glands, many legs, egg sac silhouette", ("move", "attack_primary", "skill_brood_spawn", "skill_web_zone")),
    EntitySpec("ashen_colossus", "boss", "Ashen Colossus", "assets/sprites/bosses/boss_ashen_colossus.png", "giant molten stone colossus boss, ember cracks and heavy fists", ("move", "attack_primary", "skill_molten_slam", "skill_armor_pulse")),
)


def project_root() -> Path:
    root = Path(__file__).resolve().parents[1]
    if not (root / "project.godot").exists():
        raise SystemExit("run from FantasyDisk checkout")
    return root


def encode_prompt(spec: EntitySpec) -> str:
    row_list = "\n".join(
        f"row {index + 1}: {name}, exactly {FRAME_COLUMNS} frames left to right"
        for index, name in enumerate(spec.rows)
    )
    if spec.kind == "enemy":
        scale_note = "standard enemy scale, compact readable game silhouette"
    elif spec.kind == "elite":
        scale_note = "larger elite scale, imposing but still fits one 256x256 cell"
    else:
        scale_note = "boss scale compressed to fit one 256x256 cell, huge silhouette but no crop"
    return f"""
Create a production full-frame transparent sprite sheet for FantasyDisk.
Use the provided reference image only as the canonical silhouette/style guide for {spec.title} ({spec.entity_id}): {spec.visual_note}.

Output requirements:
- exact layout: 6 columns x 4 rows, 24 total animation frames, one creature per frame.
- canvas is transparent, no background, no floor shadow, no text, no labels, no UI frame, no watermark.
- every cell is a full character frame, centered in its cell with stable bottom-center foot/pivot alignment.
- no crop: leave safe transparent padding around head, weapons, wings, tentacles, projectiles, and effects.
- Dungeons & Dragons / dark fantasy painterly game sprite style matching the current FantasyDisk monsters.
- preserve the same creature identity across all frames; do not invent a new monster between cells.
- facing slightly left/front-left in every frame; animator will mirror horizontally in runtime.
- {scale_note}.

Animation rows:
{row_list}

Motion notes:
- movement row must loop naturally with at least 5 distinct poses.
- attack rows must read as anticipation, active impact/cast/bite, follow-through, recovery.
- skill rows should show only body/weapon/magic pose energy attached to the creature, not detached UI telegraphs.
"""


def entity_by_id(ids: Iterable[str]) -> list[EntitySpec]:
    table = {spec.entity_id: spec for spec in ENTITIES}
    selected = []
    for entity_id in ids:
        if entity_id not in table:
            raise SystemExit(f"unknown entity id: {entity_id}")
        selected.append(table[entity_id])
    return selected


def write_manifest(root: Path, generated: list[dict]) -> None:
    manifest_path = root / "docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    current = {
        "task": "SCRUM-352",
        "model": MODEL,
        "output_size": OUTPUT_SIZE,
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "columns": FRAME_COLUMNS,
        "rows": FRAME_ROWS,
        "source_faces_left": True,
        "pivot": "bottom-center of each 256x256 cell",
        "generated": generated,
    }
    manifest_path.write_text(json.dumps(current, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def call_openai_edit(root: Path, spec: EntitySpec, quality: str) -> bytes:
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise SystemExit("Python package 'openai' is not installed") from exc
    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("OPENAI_API_KEY is not set")
    client = OpenAI()
    source = root / spec.source_path
    with source.open("rb") as image_file:
        result = client.images.edit(
            model=MODEL,
            image=image_file,
            prompt=encode_prompt(spec),
            size=OUTPUT_SIZE,
            quality=quality,
            output_format="png",
        )
    if not result.data or not result.data[0].b64_json:
        raise SystemExit(f"OpenAI image edit returned no data for {spec.entity_id}")
    return base64.b64decode(result.data[0].b64_json)


def ensure_rgba_and_sheet_size(path: Path) -> dict:
    im = Image.open(path).convert("RGBA")
    if im.size != (FRAME_COLUMNS * FRAME_SIZE, FRAME_ROWS * FRAME_SIZE):
        im = im.resize((FRAME_COLUMNS * FRAME_SIZE, FRAME_ROWS * FRAME_SIZE), Image.Resampling.LANCZOS)
    pixels = im.load()
    width, height = im.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # gpt-image-2 often paints a checkerboard or green-screen illusion
            # instead of real alpha. Treat bright neutral/green background as
            # transparent while preserving dark sprite silhouettes and VFX.
            neutral = max(r, g, b) > 205 and (max(r, g, b) - min(r, g, b)) < 30
            soft_neutral = max(r, g, b) > 185 and (max(r, g, b) - min(r, g, b)) < 24
            green = g > 85 and (g - max(r, b)) > 18
            if neutral or green:
                pixels[x, y] = (r, g, b, 0)
            elif soft_neutral:
                pixels[x, y] = (r, g, b, min(a, 72))
    im.save(path)
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    return {
        "size": list(im.size),
        "mode": "RGBA",
        "alpha_bbox": list(bbox) if bbox else None,
        "has_transparency": alpha.getextrema()[0] < 255,
    }


def make_preview(root: Path, generated: list[dict]) -> None:
    if not generated:
        return
    thumbs = []
    for item in generated:
        sheet = Image.open(root / item["asset_path"]).convert("RGBA")
        first = sheet.crop((0, 0, FRAME_SIZE, FRAME_SIZE))
        first.thumbnail((128, 128), Image.Resampling.LANCZOS)
        thumbs.append((item["entity_id"], first))
    cols = 6
    tile_w, tile_h = 190, 170
    rows = (len(thumbs) + cols - 1) // cols
    out = Image.new("RGBA", (cols * tile_w, rows * tile_h), (22, 17, 15, 255))
    draw = ImageDraw.Draw(out)
    for index, (entity_id, thumb) in enumerate(thumbs):
        x = (index % cols) * tile_w
        y = (index // cols) * tile_h
        out.alpha_composite(thumb, (x + (tile_w - thumb.width) // 2, y + 12))
        draw.text((x + 8, y + 140), entity_id, fill=(235, 222, 200, 255))
    preview = root / "docs/design/previews/scrum352_full_frame_sheets_preview.png"
    preview.parent.mkdir(parents=True, exist_ok=True)
    out.save(preview)


def generate(specs: list[EntitySpec], quality: str, overwrite: bool) -> int:
    root = project_root()
    generated: list[dict] = []
    for index, spec in enumerate(specs, start=1):
        refs_dir = root / "docs/design/references/scrum352_full_frame_sheets/raw"
        refs_dir.mkdir(parents=True, exist_ok=True)
        raw_path = refs_dir / f"{spec.entity_id}_full_frame_sheet_raw.png"
        asset_dir = root / spec.asset_folder
        asset_dir.mkdir(parents=True, exist_ok=True)
        asset_path = asset_dir / f"{spec.entity_id}_full_frame_sheet.png"
        if asset_path.exists() and not overwrite:
            print(f"[{index}/{len(specs)}] skip existing {asset_path.relative_to(root)}")
        else:
            print(f"[{index}/{len(specs)}] generating {spec.entity_id} ({spec.kind})")
            image_bytes = call_openai_edit(root, spec, quality)
            raw_path.write_bytes(image_bytes)
            asset_path.write_bytes(image_bytes)
        qa = ensure_rgba_and_sheet_size(asset_path)
        generated.append({
            "entity_id": spec.entity_id,
            "kind": spec.kind,
            "title": spec.title,
            "source_path": spec.source_path,
            "reference_path": raw_path.relative_to(root).as_posix(),
            "asset_path": asset_path.relative_to(root).as_posix(),
            "rows": list(spec.rows),
            "frame_count_per_row": FRAME_COLUMNS,
            "qa": qa,
        })
        write_manifest(root, generated)
        make_preview(root, generated)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SCRUM-352 full-frame enemy/elite/boss sheets.")
    parser.add_argument("--ids", nargs="*", help="Optional entity ids. Defaults to all SCRUM-352 entities.")
    parser.add_argument("--quality", default="high", choices=["low", "medium", "high", "auto"])
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--list", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.list:
        for spec in ENTITIES:
            print(f"{spec.entity_id}\t{spec.kind}\t{spec.source_path}")
        return 0
    specs = entity_by_id(args.ids) if args.ids else list(ENTITIES)
    return generate(specs, args.quality, args.overwrite)


if __name__ == "__main__":
    raise SystemExit(main())
