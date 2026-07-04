#!/usr/bin/env python3
"""Import PixelLab west-facing boss animation rows into FantasyDisk SpriteFrames."""

from __future__ import annotations

import argparse
import json
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
FRAME_COUNT = 6


BOSS_SKILLS = {
    "rift_warden": ["skill_gravity_well", "skill_rift_zone"],
    "disk_devourer": ["skill_vampiric_bite", "skill_rift_zone"],
    "bone_archon": ["skill_skull_volley", "skill_bone_prison"],
    "brood_mother": ["skill_brood_spawn", "skill_web_zone"],
    "ashen_colossus": ["skill_molten_slam", "skill_armor_pulse"],
    "bloodthorn_lion": ["skill_spike_ring", "skill_rift_zone"],
}


def parse_state(value: str) -> tuple[str, str]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("--state must be state_name=url_template")
    name, template = value.split("=", 1)
    name = name.strip()
    template = template.strip()
    if not name or not template:
        raise argparse.ArgumentTypeError("--state must include a state name and source")
    return name, template


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.convert("RGBA").getchannel("A").getbbox()


def reference_height(path: Path, fallback: int) -> int:
    if not path.exists():
        return fallback
    with Image.open(path) as image:
        bbox = alpha_bbox(image)
        if bbox is None:
            return fallback
        return max(1, bbox[3] - bbox[1])


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "FantasyDisk-PixelLab-Importer/1.0"})
    with urllib.request.urlopen(request) as response:
        dest.write_bytes(response.read())


def extract_zip_frame(zip_file: zipfile.ZipFile, prefix: str, state: str, index: int, dest: Path) -> None:
    clean_prefix = prefix.rstrip("/") + "/"
    members = sorted(
        name for name in zip_file.namelist()
        if name.startswith(clean_prefix) and name.lower().endswith(".png")
    )
    if state == "move" and len(members) >= FRAME_COUNT + 1:
        members = members[1:FRAME_COUNT + 1]
    else:
        members = members[:FRAME_COUNT]
    if len(members) < FRAME_COUNT:
        raise ValueError(f"{prefix} has {len(members)} png frames, expected at least {FRAME_COUNT}")
    dest.write_bytes(zip_file.read(members[index]))


def normalize_frame(src: Path, dest: Path, target_height: int, bottom_padding: int) -> None:
    image = Image.open(src).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        raise ValueError(f"{src} has no alpha content")
    cropped = image.crop(bbox)
    scale = target_height / max(1, cropped.height)
    width = max(1, round(cropped.width * scale))
    height = max(1, round(cropped.height * scale))
    if width > 512 or height + bottom_padding > 512:
        fit_scale = min(512 / width, (512 - bottom_padding) / height)
        width = max(1, int(width * fit_scale))
        height = max(1, int(height * fit_scale))
    resized = cropped.resize((width, height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    x = (512 - width) // 2
    y = 512 - bottom_padding - height
    canvas.alpha_composite(resized, (x, y))
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)


def animation_block(resource_ids: list[str], name: str, loop: bool, speed: float) -> str:
    frames = []
    for resource_id in resource_ids:
        frames.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id)
    return (
        "{\n"
        '"frames": [%s],\n'
        '"loop": %s,\n'
        '"name": &"%s",\n'
        '"speed": %.1f\n'
        "}"
    ) % (", ".join(frames), "true" if loop else "false", name, speed)


def write_spriteframes(boss_id: str, states: list[str], output_path: Path) -> None:
    frame_dir = output_path.parent / boss_id
    ext_lines: list[str] = []
    resource_ids: dict[Path, str] = {}
    next_id = 1

    def resource_id(path: Path) -> str:
        nonlocal next_id
        if path in resource_ids:
            return resource_ids[path]
        rid = f"{next_id}_{boss_id}"
        next_id += 1
        rel = path.resolve().relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{rid}"]')
        resource_ids[path] = rid
        return rid

    def state_resources(state: str) -> list[str]:
        return [
            resource_id(frame_dir / f"{boss_id}_{state}_{index:02d}.png")
            for index in range(FRAME_COUNT)
        ]

    animations: list[str] = []
    attack_ids = state_resources("attack_primary")
    animations.append(animation_block(attack_ids, "attack", False, 12.0))
    animations.append(animation_block(attack_ids, "attack_primary", False, 12.0))
    animations.append(animation_block(state_resources("death"), "death", False, 10.0))
    animations.append(animation_block(state_resources("move"), "move", True, 9.0))

    for state in states:
        if not state.startswith("skill_"):
            continue
        ids = state_resources(state)
        animations.append(animation_block(ids, state, False, 12.0))
        animations.append(animation_block(ids, f"attack_{state.removeprefix('skill_')}", False, 12.0))

    output_path.write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animations)
        + "\n]\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--boss-id", required=True, choices=sorted(BOSS_SKILLS))
    parser.add_argument("--zip", type=Path, help="PixelLab object download zip; state values become zip prefixes")
    parser.add_argument("--state", action="append", default=[], type=parse_state)
    parser.add_argument("--target-height", type=int)
    parser.add_argument("--bottom-padding", type=int, default=48)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    required_states = ["move", "attack_primary", "death"] + BOSS_SKILLS[args.boss_id]
    templates = dict(args.state)
    missing = [state for state in required_states if state not in templates]
    if missing:
        raise SystemExit(f"Missing --state entries for {', '.join(missing)}")

    frame_dir = ROOT / "assets" / "sprites" / "bosses" / "full_frame" / args.boss_id
    spriteframes_path = frame_dir.parent / f"{args.boss_id}_spriteframes.tres"
    target_height = args.target_height or reference_height(frame_dir / f"{args.boss_id}_move_00.png", 236)

    report = {
        "boss_id": args.boss_id,
        "target_height": target_height,
        "bottom_padding": args.bottom_padding,
        "states": {},
        "spriteframes": str(spriteframes_path.relative_to(ROOT)),
    }

    zip_file = zipfile.ZipFile(args.zip) if args.zip else None
    with tempfile.TemporaryDirectory(prefix=f"{args.boss_id}_pixellab_") as tmp:
        tmp_dir = Path(tmp)
        for state in required_states:
            state_report = []
            for index in range(FRAME_COUNT):
                raw_path = tmp_dir / f"{state}_{index:02d}.png"
                dest = frame_dir / f"{args.boss_id}_{state}_{index:02d}.png"
                if zip_file is not None:
                    extract_zip_frame(zip_file, templates[state], state, index, raw_path)
                else:
                    template = templates[state]
                    if "{i}" not in template:
                        raise SystemExit(f"{state} URL template must include {{i}} when --zip is not used")
                    download(template.format(i=index), raw_path)
                normalize_frame(raw_path, dest, target_height, args.bottom_padding)
                with Image.open(dest) as image:
                    state_report.append({"frame": index, "bbox": alpha_bbox(image)})
            report["states"][state] = state_report
    if zip_file is not None:
        zip_file.close()

    write_spriteframes(args.boss_id, required_states, spriteframes_path)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
