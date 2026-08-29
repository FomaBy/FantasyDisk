#!/usr/bin/env python3
"""Build the FAN-3327 six-actor directional animation pack.

The PixelLab CLI owns animation generation and writes the per-animation
provenance manifests.  This small, deterministic builder owns the local
import contract: it fetches the authored idle rotations once, normalizes all
source frames onto the same 256px canvas, writes SpriteFrames, manifests and
actor-local contact sheets, and can rebuild those outputs without network
access.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from pixellab_generate_pack import frame_hashes  # noqa: E402


BUILDER_VERSION = "1.0.0"
GODOT_UID_ALPHABET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
CANVAS_SIZE = 256
BASELINE_Y = 232
MAX_VISIBLE_WIDTH = 224
MAX_VISIBLE_HEIGHT = 208
DIRECTIONS = (
    "east",
    "south_east",
    "south",
    "south_west",
    "west",
    "north_west",
    "north",
    "north_east",
)
PIXELLAB_DIRECTIONS = {
    "east": "east",
    "south_east": "south-east",
    "south": "south",
    "south_west": "south-west",
    "west": "west",
    "north_west": "north-west",
    "north": "north",
    "north_east": "north-east",
}
STATES = ("idle", "move", "attack")
FRAME_COUNTS = {"idle": 1, "move": 6, "attack": 6}


ACTORS = {
    "druid_ghost_wolf": {
        "pixel_lab_character_id": "8d09581d-4107-4aa2-b2d5-1d660fc378fa",
        "legacy_pixel_lab_character_id": "8d473df8-9bc2-481c-ad58-b69cfecc5d33",
        "art_identity": "translucent cyan spectral ghost wolf",
    },
    "druid_ghost_bear": {
        "pixel_lab_character_id": "8096ecfe-74bb-4427-83fe-8e8e9e03d508",
        "legacy_pixel_lab_character_id": "6805608a-b64a-471c-a1d9-9601a3062e2f",
        "art_identity": "translucent cyan spectral ghost bear",
    },
    "druid_ghost_panther": {
        "pixel_lab_character_id": "97a1369c-cfd7-498b-b13f-478544015da1",
        "legacy_pixel_lab_character_id": "b2d06d20-aabb-48e2-9d8a-5053daa03e8e",
        "art_identity": "translucent cyan spectral ghost panther",
    },
    "druid_ghost_stag": {
        "pixel_lab_character_id": "559591a8-a113-40f0-b534-e0a3bdc9cc57",
        "legacy_pixel_lab_character_id": "f17948e2-8e1d-44f2-93f1-8f8593ae01fe",
        "art_identity": "translucent cyan spectral ghost stag",
    },
    "druid_ghost_lion": {
        "pixel_lab_character_id": "b957b9ed-62b9-49ec-a244-89aec51acc0b",
        "legacy_pixel_lab_character_id": "48d76788-eeba-4a9f-a36f-bd40a8f42e07",
        "art_identity": "translucent pale-blue spectral ghost lion",
    },
    "homunculus_caster": {
        "pixel_lab_character_id": "141b0023-8e08-4814-8a98-c270fd22d1c0",
        "reference_source": "assets/sprites/allies/homunculus_caster_south.png",
        "art_identity": "small emerald-green spectral alchemical homunculus caster",
    },
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def ensure_import_sidecar(path: Path) -> None:
    """Write the deterministic tracked texture import record for a runtime PNG."""
    source = f"res://{path.relative_to(ROOT).as_posix()}"
    uid_seed = int(
        hashlib.sha256(f"{path.relative_to(ROOT).as_posix()}:{sha256_bytes(path.read_bytes())}".encode("utf-8")).hexdigest()[:16],
        16,
    ) or 1
    uid_chars = []
    for _ in range(13):
        uid_chars.append(GODOT_UID_ALPHABET[uid_seed & 31])
        uid_seed >>= 5
    uid = "".join(reversed(uid_chars))
    # Godot derives the imported artifact name from the MD5 of the res:// source
    # path (repository-wide convention). A different name makes the engine rewrite
    # the sidecar on first import; CI then restores the tracked bytes and the
    # texture resolves to a .ctex that was never written (FAN-3740).
    imported = f"res://.godot/imported/{path.name}-{hashlib.md5(source.encode('utf-8')).hexdigest()}.ctex"
    Path(f"{path}.import").write_text(
        "[remap]\n"
        "importer=\"texture\"\n"
        "type=\"CompressedTexture2D\"\n"
        f"uid=\"uid://{uid}\"\n"
        f"path=\"{imported}\"\n"
        "metadata={\n\"vram_texture\": false\n}\n\n"
        "[deps]\n"
        f"source_file=\"{source}\"\n"
        f"dest_files=[\"{imported}\"]\n\n"
        "[params]\n"
        "compress/mode=0\n"
        "compress/high_quality=false\n"
        "compress/lossy_quality=0.7\n"
        "compress/uastc_level=0\n"
        "compress/rdo_quality_loss=0.0\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=false\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        "roughness/src_normal=\"\"\n"
        "process/channel_remap/red=0\n"
        "process/channel_remap/green=1\n"
        "process/channel_remap/blue=2\n"
        "process/channel_remap/alpha=3\n"
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/normal_map_invert_y=false\n"
        "process/hdr_as_srgb=false\n"
        "process/hdr_clamp_exposure=1\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n",
        encoding="utf-8",
    )


def auth_header() -> str:
    token = os.environ.get("PIXELLAB_BEARER_TOKEN", "")
    return "Bearer " + token if token else ""


def fetch_idle(actor: str, config: dict, source_dir: Path) -> None:
    """Download the generated character state and retain only its rotations."""
    character_id = config["pixel_lab_character_id"]
    request = urllib.request.Request(
        f"https://api.pixellab.ai/mcp/characters/{character_id}/download",
        headers={"Authorization": auth_header(), "User-Agent": "FantasyDisk FAN-3327 builder"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        archive = response.read()
    with zipfile.ZipFile(io.BytesIO(archive)) as pack:
        names = pack.namelist()
        for direction in DIRECTIONS:
            pixel_direction = PIXELLAB_DIRECTIONS[direction]
            suffixes = (
                f"/rotations/{pixel_direction}.png",
                f"/rotation/{pixel_direction}.png",
                f"/{pixel_direction}.png",
            )
            member = next((name for name in names if name.endswith(suffixes)), None)
            if member is None:
                raise RuntimeError(
                    f"{actor}: download archive has no {pixel_direction} rotation"
                )
            data = pack.read(member)
            with Image.open(io.BytesIO(data)) as image:
                image.verify()
            (source_dir / f"{actor}_idle_{direction}.png").write_bytes(data)


def source_path(actor: str, state: str, direction: str, index: int | None = None) -> Path:
    suffix = f"_{index:02d}" if index is not None else ""
    return ROOT / "assets" / "sprites" / "allies" / actor / "pixellab_source" / f"{actor}_{state}_{direction}{suffix}.png"


def load_source(actor: str, state: str, direction: str, index: int | None = None) -> Image.Image:
    path = source_path(actor, state, direction, index)
    if not path.exists():
        raise RuntimeError(f"missing source frame: {path.relative_to(ROOT)}")
    image = Image.open(path).convert("RGBA")
    if image.getbbox() is None or image.getchannel("A").getbbox() is None:
        raise RuntimeError(f"fully transparent source frame: {path.relative_to(ROOT)}")
    return image


def bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    result = alpha.getbbox()
    if result is None:
        raise RuntimeError("fully transparent image")
    return result


def normalize_frames(actor: str, runtime_dir: Path) -> tuple[list[dict], dict]:
    """Normalize all source frames with one actor-wide scale and pivot."""
    source_frames = []
    max_width = 0
    max_height = 0
    for state in STATES:
        for direction in DIRECTIONS:
            for index in range(FRAME_COUNTS[state]):
                image = load_source(actor, state, direction, index if state != "idle" else None)
                left, top, right, bottom = bbox(image)
                width, height = right - left, bottom - top
                max_width = max(max_width, width)
                max_height = max(max_height, height)
                source_frames.append((state, direction, index, image, (left, top, right, bottom)))

    scale = min(MAX_VISIBLE_WIDTH / max_width, MAX_VISIBLE_HEIGHT / max_height)
    if scale <= 0:
        raise RuntimeError(f"{actor}: invalid normalization scale")

    for old in runtime_dir.iterdir() if runtime_dir.exists() else ():
        if old.is_file() and (old.suffix in {".png", ".import"} or old.name.endswith(".png.import")):
            old.unlink()
    runtime_dir.mkdir(parents=True, exist_ok=True)

    runtime_records = []
    geometry = {
        "canvas": [CANVAS_SIZE, CANVAS_SIZE],
        "baseline_y": BASELINE_Y,
        "max_source_bbox": [max_width, max_height],
        "scale": round(scale, 8),
        "max_visible": [MAX_VISIBLE_WIDTH, MAX_VISIBLE_HEIGHT],
    }
    for state, direction, index, image, source_bbox in source_frames:
        left, top, right, bottom = source_bbox
        cropped = image.crop(source_bbox)
        new_size = (
            max(1, round(cropped.width * scale)),
            max(1, round(cropped.height * scale)),
        )
        resized = cropped.resize(new_size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
        x = (CANVAS_SIZE - resized.width) // 2
        y = BASELINE_Y - resized.height
        if x < 0 or y < 0 or x + resized.width > CANVAS_SIZE or y + resized.height > CANVAS_SIZE:
            raise RuntimeError(f"{actor}: normalized frame would clip: {state}/{direction}/{index}")
        canvas.alpha_composite(resized, (x, y))
        filename = f"{actor}_{state}_{direction}_{index:02d}.png"
        output = runtime_dir / filename
        canvas.save(output, format="PNG", optimize=False)
        ensure_import_sidecar(output)
        encoded_sha, pixel_sha = frame_hashes(str(output))
        runtime_records.append(
            {
                "file": filename,
                "state": state,
                "direction": direction,
                "index": index,
                "source_bbox": [left, top, right, bottom],
                "runtime_bbox": [x, y, x + resized.width, y + resized.height],
                "encoded_sha256": encoded_sha,
                "pixel_sha256": pixel_sha,
            }
        )
    return runtime_records, geometry


def source_records(actor: str) -> list[dict]:
    records = []
    for state in STATES:
        for direction in DIRECTIONS:
            for index in range(FRAME_COUNTS[state]):
                path = source_path(actor, state, direction, index if state != "idle" else None)
                encoded_sha, pixel_sha = frame_hashes(str(path))
                with Image.open(path) as image:
                    image_size = list(image.size)
                records.append(
                    {
                        "file": str(path.relative_to(ROOT / "assets" / "sprites" / "allies" / actor / "pixellab_source")),
                        "state": state,
                        "direction": direction,
                        "index": index,
                        "size": image_size,
                        "encoded_sha256": encoded_sha,
                        "pixel_sha256": pixel_sha,
                    }
                )
    return records


def ext_id(index: int) -> str:
    return f"tex_{index:03d}"


def write_spriteframes(actor: str, runtime_dir: Path, output_path: Path) -> None:
    entries = []
    texture_paths: dict[str, str] = {}
    index = 1
    for state in STATES:
        for direction in DIRECTIONS:
            for frame_index in range(FRAME_COUNTS[state]):
                filename = f"{actor}_{state}_{direction}_{frame_index:02d}.png"
                texture_paths[f"{state}_{direction}_{frame_index}"] = ext_id(index)
                entries.append(
                    (ext_id(index), f"res://assets/sprites/allies/{actor}/runtime/{filename}")
                )
                index += 1

    lines = ["[gd_resource type=\"SpriteFrames\" format=3]", ""]
    for resource_id, path in entries:
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{resource_id}"]')
    lines.extend(["", "[resource]", "animations = ["])

    def add_animation(name: str, state: str, direction: str) -> None:
        lines.extend(["{", '"frames": ['])
        for frame_index in range(FRAME_COUNTS[state]):
            resource_id = texture_paths[f"{state}_{direction}_{frame_index}"]
            comma = "," if frame_index < FRAME_COUNTS[state] - 1 else ""
            lines.extend([
                "{",
                '"duration": 1.0,',
                f'"texture": ExtResource("{resource_id}")',
                f"}}{comma}",
            ])
        lines.extend([
            "],",
            f'"loop": {str(state in {"idle", "move"}).lower()},',
            f'"name": &"{name}",',
            f'"speed": {12.0 if state == "attack" else 10.0}',
            "},",
        ])

    # Generic rows retain the existing gameplay state names.  Directional rows
    # are authored, never mirrored; left/right aliases keep old callers safe.
    add_animation("idle", "idle", "south")
    add_animation("move", "move", "south")
    add_animation("attack", "attack", "south")
    add_animation("walk", "move", "south")
    for state in STATES:
        for direction in DIRECTIONS:
            add_animation(f"{state}_{direction}", state, direction)
    for state in ("move", "attack"):
        add_animation(f"{state}_left", state, "west")
        add_animation(f"{state}_right", state, "east")
    # The caster's legacy pair uses attack_primary; it remains the same
    # one-shot authored cast without introducing gameplay changes.
    add_animation("attack_primary", "attack", "south")
    lines[-1] = "}"  # remove the final animation comma
    lines.append("]")
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_contact_sheet(actor: str, runtime_dir: Path, output_path: Path) -> None:
    sheet = Image.new("RGBA", (CANVAS_SIZE * len(DIRECTIONS), CANVAS_SIZE * 3), (16, 20, 28, 255))
    for row, state in enumerate(STATES):
        for col, direction in enumerate(DIRECTIONS):
            frame = runtime_dir / f"{actor}_{state}_{direction}_00.png"
            with Image.open(frame) as image:
                sheet.alpha_composite(image.convert("RGBA"), (col * CANVAS_SIZE, row * CANVAS_SIZE))
    sheet.save(output_path, format="PNG", optimize=False)
    # The contact sheet is a tracked PNG, so it needs its tracked sidecar too;
    # otherwise Godot writes an untracked one and the quality gate stops on a
    # dirty worktree (FAN-3740).
    ensure_import_sidecar(output_path)


def build_actor(actor: str, fetch: bool) -> None:
    config = ACTORS[actor]
    actor_dir = ROOT / "assets" / "sprites" / "allies" / actor
    source_dir = actor_dir / "pixellab_source"
    runtime_dir = actor_dir / "runtime"
    source_dir.mkdir(parents=True, exist_ok=True)
    if fetch:
        if not auth_header():
            raise RuntimeError("PIXELLAB_BEARER_TOKEN is required with --fetch-idle")
        fetch_idle(actor, config, source_dir)

    # Remove only the previous legacy source subfolders owned by this actor.
    for legacy_dir in (source_dir / "move", source_dir / "attack"):
        if legacy_dir.is_dir():
            shutil.rmtree(legacy_dir)

    runtime_records, geometry = normalize_frames(actor, runtime_dir)
    sources = source_records(actor)
    manifests = {}
    for state in ("move", "attack"):
        path = source_dir / f"{state}_manifest.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("frame_count") != 48:
            raise RuntimeError(f"{actor}: {path.name} is not a complete 8x6 pack")
        manifests[path.name] = {
            "sha256": sha256_bytes(path.read_bytes()),
            "frame_count": data["frame_count"],
            "pixel_lab_character_id": data["character"]["pixel_lab_character_id"],
        }

    manifest = {
        "schema": "fantasydisk.fan3327.actor_pack.v1",
        "builder": {"path": "tools/build_fan3327_actor_pack.py", "version": BUILDER_VERSION},
        "actor": actor,
        "pixel_lab": config,
        "directions": list(DIRECTIONS),
        "states": {state: FRAME_COUNTS[state] for state in STATES},
        "source_manifests": manifests,
        "source": sources,
        "runtime": {"directory": "runtime", "frames": runtime_records, "geometry": geometry},
        "spriteframes": f"ally_{actor}_spriteframes.tres" if actor.startswith("druid_ghost_") else f"{actor}_spriteframes.tres",
        "no_mirroring": True,
    }
    manifest_path = source_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")

    spriteframes_name = f"ally_{actor}_spriteframes.tres" if actor.startswith("druid_ghost_") else f"{actor}_spriteframes.tres"
    write_spriteframes(actor, runtime_dir, ROOT / "assets" / "sprites" / "allies" / spriteframes_name)
    write_contact_sheet(actor, runtime_dir, actor_dir / "fan3327_contact_sheet.png")
    print(f"built {actor}: {len(sources)} source frames, {len(runtime_records)} runtime frames")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch-idle", action="store_true", help="download PixelLab authored idle rotations")
    parser.add_argument("--actor", action="append", choices=sorted(ACTORS), help="build only this actor (repeatable)")
    args = parser.parse_args()
    actors = args.actor or list(ACTORS)
    for actor in actors:
        build_actor(actor, args.fetch_idle)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
