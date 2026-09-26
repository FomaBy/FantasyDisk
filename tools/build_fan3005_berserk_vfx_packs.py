#!/usr/bin/env python3
"""FAN-3005: assemble the nine berserk PixelLab source packs into runtime
assets/sprites/effects/berserk/<weapon>/<effect>/ SpriteFrames.

Copies each pack's downloaded frames (PixelLab returns the requested animated
frames plus one stored reference frame, all kept — same convention as
FAN-2542/fan2542_shadow_daggers_ultimate) from its docs/design/references
source directory into the runtime directory and writes a SpriteFrames .tres
next to them. Godot .import sidecars are generated separately by a headless
`--import` pass, not by this script.
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "docs/design/references/weapon_ultimates/berserk/source"
RUNTIME_ROOT = ROOT / "assets/sprites/effects/berserk"

PACKS = [
    {"weapon": "sword", "effect": "whirlwind", "source": "sword_whirlwind",
     "prefix": "sword_whirlwind_f", "anim": "whirlwind_spin", "loop": True, "speed": 12.0},
    {"weapon": "sword", "effect": "cast_flash", "source": "sword_cast_flash",
     "prefix": "sword_cast_flash_f", "anim": "cast_flash", "loop": False, "speed": 14.0},
    {"weapon": "sword", "effect": "victim_explosion", "source": "sword_victim_explosion",
     "prefix": "sword_victim_explosion_f", "anim": "victim_explosion", "loop": False, "speed": 14.0},
    {"weapon": "axe", "effect": "execution_slash", "source": "axe_execution_slash",
     "prefix": "axe_execution_slash_f", "anim": "execution_slash", "loop": False, "speed": 16.0},
    {"weapon": "axe", "effect": "cast_flash", "source": "axe_cast_flash",
     "prefix": "axe_cast_flash_f", "anim": "cast_flash", "loop": False, "speed": 14.0},
    {"weapon": "axe", "effect": "victim_impact", "source": "axe_victim_impact",
     "prefix": "axe_victim_impact_f", "anim": "victim_impact", "loop": False, "speed": 14.0},
    {"weapon": "hammer", "effect": "rift_shockwave", "source": "hammer_rift_shockwave",
     "prefix": "hammer_rift_shockwave_f", "anim": "rift_shockwave", "loop": False, "speed": 12.0},
    {"weapon": "hammer", "effect": "cast_flash", "source": "hammer_cast_flash",
     "prefix": "hammer_cast_flash_f", "anim": "cast_flash", "loop": False, "speed": 14.0},
    {"weapon": "hammer", "effect": "victim_impact", "source": "hammer_victim_impact",
     "prefix": "hammer_victim_impact_f", "anim": "victim_impact", "loop": False, "speed": 14.0},
]


def build_pack(pack: dict) -> dict:
    source_dir = SOURCE_ROOT / pack["source"]
    frames = sorted(source_dir.glob(pack["prefix"] + "*.png"))
    if not frames:
        raise SystemExit(f"no frames found under {source_dir} with prefix {pack['prefix']}")

    runtime_dir = RUNTIME_ROOT / pack["weapon"] / pack["effect"]
    runtime_dir.mkdir(parents=True, exist_ok=True)
    for old in runtime_dir.glob("*.png"):
        old.unlink()

    copied = []
    for idx, src in enumerate(frames):
        dest_name = f"{pack['effect']}_{idx:02d}.png"
        dest = runtime_dir / dest_name
        shutil.copyfile(src, dest)
        copied.append(dest_name)

    tres_path = runtime_dir / f"{pack['effect']}_spriteframes.tres"
    rel_dir = f"res://assets/sprites/effects/berserk/{pack['weapon']}/{pack['effect']}"
    ext_lines = []
    frame_entries = []
    for idx, name in enumerate(copied):
        res_id = f"{idx + 1}_frame"
        ext_lines.append(f'[ext_resource type="Texture2D" path="{rel_dir}/{name}" id="{res_id}"]')
        frame_entries.append(
            '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % res_id
        )
    load_steps = len(copied) + 1
    body = "\n".join(ext_lines)
    frames_joined = ", ".join(frame_entries)
    loop_str = "true" if pack["loop"] else "false"
    tres = (
        f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]\n\n'
        f'{body}\n\n'
        f'[resource]\n'
        f'animations = [{{\n'
        f'"frames": [{frames_joined}],\n'
        f'"loop": {loop_str},\n'
        f'"name": &"{pack["anim"]}",\n'
        f'"speed": {pack["speed"]}\n'
        f'}}]\n'
    )
    tres_path.write_text(tres, encoding="utf-8")
    return {"weapon": pack["weapon"], "effect": pack["effect"], "frame_count": len(copied),
            "runtime_dir": str(runtime_dir.relative_to(ROOT)),
            "spriteframes": str(tres_path.relative_to(ROOT))}


def main() -> int:
    results = []
    for pack in PACKS:
        source_dir = SOURCE_ROOT / pack["source"]
        if not source_dir.exists():
            print(f"SKIP {pack['weapon']}/{pack['effect']}: source dir missing ({source_dir})")
            continue
        result = build_pack(pack)
        print(f"OK {result['weapon']}/{result['effect']}: {result['frame_count']} frames -> "
              f"{result['spriteframes']}")
        results.append(result)
    print(f"assembled {len(results)}/{len(PACKS)} packs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
