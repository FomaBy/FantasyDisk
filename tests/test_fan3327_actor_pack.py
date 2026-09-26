#!/usr/bin/env python3
"""Focused offline integrity checks for the FAN-3327 actor art package."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ACTORS = (
    "druid_ghost_wolf",
    "druid_ghost_bear",
    "druid_ghost_panther",
    "druid_ghost_stag",
    "druid_ghost_lion",
    "homunculus_caster",
)
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_actor(actor: str) -> None:
    actor_dir = ROOT / "assets" / "sprites" / "allies" / actor
    source_dir = actor_dir / "pixellab_source"
    runtime_dir = actor_dir / "runtime"
    manifest = json.loads((source_dir / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["directions"] == list(DIRECTIONS), actor
    assert manifest["states"] == {"idle": 1, "move": 6, "attack": 6}, actor
    assert manifest["no_mirroring"] is True, actor
    assert manifest["runtime"]["geometry"]["canvas"] == [256, 256], actor
    assert manifest["runtime"]["geometry"]["baseline_y"] == 232, actor

    source_pngs = sorted(source_dir.glob("*.png"))
    runtime_pngs = sorted(runtime_dir.glob("*.png"))
    assert len(source_pngs) == 104, (actor, "source", len(source_pngs))
    assert len(runtime_pngs) == 104, (actor, "runtime", len(runtime_pngs))
    assert not list(source_dir.glob("move/**/*.png")), actor
    assert not list(source_dir.glob("attack/**/*.png")), actor
    assert not [path for path in runtime_pngs if "_left_" in path.name or "_right_" in path.name], actor

    source_by_name = {record["file"]: record for record in manifest["source"]}
    runtime_by_name = {record["file"]: record for record in manifest["runtime"]["frames"]}
    assert len(source_by_name) == 104, actor
    assert len(runtime_by_name) == 104, actor
    for path in source_pngs:
        record = source_by_name[path.name]
        assert record["encoded_sha256"] == sha256(path), path
        with Image.open(path) as image:
            assert image.getchannel("A").getbbox() is not None, path
    for path in runtime_pngs:
        record = runtime_by_name[path.name]
        assert record["encoded_sha256"] == sha256(path), path
        with Image.open(path) as image:
            assert image.size == (256, 256), path
            alpha = image.getchannel("A")
            used = alpha.getbbox()
            assert used is not None and used[1] >= 0 and used[3] <= 256, path
            assert record["runtime_bbox"] == list(used), path

    for state, count in (("idle", 1), ("move", 6), ("attack", 6)):
        for direction in DIRECTIONS:
            for index in range(count):
                suffix = "" if state == "idle" else f"_{index:02d}"
                name = f"{actor}_{state}_{direction}{suffix}.png"
                assert (source_dir / name).exists(), name
                assert (runtime_dir / f"{actor}_{state}_{direction}_{index:02d}.png").exists(), name

    for filename, entry in manifest["source_manifests"].items():
        assert entry["frame_count"] == 48, (actor, filename)
        assert sha256(source_dir / filename) == entry["sha256"], (actor, filename)

    spriteframes_name = (
        f"ally_{actor}_spriteframes.tres" if actor.startswith("druid_ghost_") else f"{actor}_spriteframes.tres"
    )
    spriteframes = (ROOT / "assets" / "sprites" / "allies" / spriteframes_name).read_text(encoding="utf-8")
    for state in ("idle", "move", "attack"):
        assert f'"name": &"{state}"' in spriteframes, (actor, state)
        for direction in DIRECTIONS:
            assert f'"name": &"{state}_{direction}"' in spriteframes, (actor, state, direction)
    assert '"name": &"move_left"' in spriteframes and '"name": &"move_right"' in spriteframes, actor
    assert '"name": &"attack_left"' in spriteframes and '"name": &"attack_right"' in spriteframes, actor

    # Every tracked PNG needs a tracked sidecar naming the artifact Godot actually
    # writes: `<name>-<md5(res:// source path)>.ctex`. Any other name is rewritten
    # by the engine on first import, and CI restores the tracked bytes over it, so
    # the texture resolves to a .ctex that never existed (FAN-3740).
    for path in runtime_pngs + [actor_dir / "fan3327_contact_sheet.png"]:
        sidecar = Path(f"{path}.import")
        assert sidecar.is_file(), sidecar
        source = f"res://{path.relative_to(ROOT).as_posix()}"
        artifact = f"res://.godot/imported/{path.name}-{hashlib.md5(source.encode('utf-8')).hexdigest()}.ctex"
        text = sidecar.read_text(encoding="utf-8")
        assert f'source_file="{source}"\n' in text, sidecar
        assert f'path="{artifact}"\n' in text, sidecar
        assert f'dest_files=["{artifact}"]\n' in text, sidecar


def main() -> int:
    for actor in ACTORS:
        check_actor(actor)
    print("FAN-3327 actor pack integrity passed (6 actors, 624 source/runtime frames).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
