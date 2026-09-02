#!/usr/bin/env python3
"""Offline integrity gate for the FAN-3771 Priest VFX packs."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[4]
PACK_ROOT = ROOT / "docs/design/reference-assets-lfs/priest-vfx-FAN-3318-art"
RUNTIME_ROOT = ROOT / "assets/sprites/effects/priest"
PACK_IDS = ("priest_censer", "priest_chime", "priest_reliquary")
EXPECTED_SIZE = (256, 256)
EXPECTED_FRAMES = 9
SAFE_GUTTER = 16


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        fail(f"cannot parse {path}: {exc}")
    if not isinstance(value, dict):
        fail(f"expected object JSON: {path}")
    return value


def pixel_hash(path: Path) -> str:
    with Image.open(path) as image:
        return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def check_pack(pack_id: str) -> tuple[int, float]:
    short_id = pack_id.removeprefix("priest_")
    source_dir = PACK_ROOT / short_id
    raw_dir = source_dir / "raw"
    runtime_dir = RUNTIME_ROOT / pack_id
    raw_manifest = load_json(source_dir / "pixellab_generation_manifest.json")
    runtime_manifest = load_json(runtime_dir / "runtime_manifest.json")
    report = load_json(source_dir / "static_alpha_readability_report.json")

    if raw_manifest.get("frame_count") != EXPECTED_FRAMES or len(raw_manifest.get("frames", [])) != EXPECTED_FRAMES:
        fail(f"{pack_id}: raw PixelLab manifest must contain 9 frames")
    if runtime_manifest.get("frame_contract", {}).get("frame_count") != EXPECTED_FRAMES:
        fail(f"{pack_id}: runtime frame contract must contain 9 frames")
    if runtime_manifest.get("import", {}).get("verified") is not True:
        fail(f"{pack_id}: Godot import evidence is not verified")
    if report.get("decision") != "pass":
        fail(f"{pack_id}: static readability report is not PASS")

    names = [f"{pack_id}_f{index:02d}.png" for index in range(EXPECTED_FRAMES)]
    hashes = []
    motion = runtime_manifest.get("motion", {})
    if motion.get("distinct_frame_pixel_hashes") != EXPECTED_FRAMES:
        fail(f"{pack_id}: frames are not all distinct")
    if motion.get("adjacent_pairs_with_motion") != EXPECTED_FRAMES - 1:
        fail(f"{pack_id}: adjacent motion evidence is incomplete")

    for index, name in enumerate(names):
        raw = raw_dir / name
        source = source_dir / name
        runtime = runtime_dir / name
        sidecar = runtime_dir / f"{name}.import"
        for path in (raw, source, runtime, sidecar):
            if not path.is_file():
                fail(f"{pack_id}: missing {path}")
        if source.read_bytes() != runtime.read_bytes():
            fail(f"{pack_id}: source/runtime byte parity failed for frame {index}")
        with Image.open(source) as image:
            if image.size != EXPECTED_SIZE or image.mode != "RGBA":
                fail(f"{pack_id}: frame {index} is not 256x256 RGBA")
            alpha = image.getchannel("A")
            bbox = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
            if not bbox or bbox[0] < SAFE_GUTTER or bbox[1] < SAFE_GUTTER or bbox[2] > 256 - SAFE_GUTTER or bbox[3] > 256 - SAFE_GUTTER:
                fail(f"{pack_id}: frame {index} violates the 16 px safe gutter: {bbox}")
            if max(alpha.getdata()) > 220:
                fail(f"{pack_id}: frame {index} is too opaque")
            if any(alpha.getpixel(point) != 0 for point in ((0, 0), (255, 0), (0, 255), (255, 255))):
                fail(f"{pack_id}: frame {index} has opaque corner pixels")
        sidecar_text = sidecar.read_text(encoding="utf-8")
        if 'type="CompressedTexture2D"' not in sidecar_text or f'source_file="res://assets/sprites/effects/priest/{pack_id}/{name}"' not in sidecar_text:
            fail(f"{pack_id}: invalid Godot sidecar for frame {index}")
        hashes.append(pixel_hash(source))

    spriteframes = (runtime_dir / f"{pack_id}_spriteframes.tres").read_text(encoding="utf-8")
    if '"loop": false' not in spriteframes or '"name": &"ultimate_flipbook"' not in spriteframes or '"speed": 3.0' not in spriteframes:
        fail(f"{pack_id}: SpriteFrames animation contract is incomplete")
    if any(spriteframes.count(name) != 1 for name in names):
        fail(f"{pack_id}: SpriteFrames frame order is incomplete or duplicated")
    if not (source_dir / f"{pack_id}_contact_sheet.png").is_file():
        fail(f"{pack_id}: contact sheet is missing")

    ratios = [float(value) for value in motion.get("adjacent_changed_pixel_ratios", [])]
    return len(hashes), sum(ratios) / len(ratios)


def main() -> int:
    provenance = load_json(PACK_ROOT / "provenance_manifest.json")
    if provenance.get("issue") != "FAN-3771" or provenance.get("base_sha") != "71fe5d79d3fee13cd38bdbe23ade6c029a652eeb":
        fail("root provenance does not pin FAN-3771 and the requested dev base")
    if tuple(pack.get("weapon_id") for pack in provenance.get("packs", [])) != PACK_IDS:
        fail("root provenance does not contain exactly the three Priest weapon IDs")
    for pack_id in PACK_IDS:
        count, motion = check_pack(pack_id)
        print(f"PASS {pack_id}: {count} frames, mean adjacent changed-pixel ratio {motion:.4f}")
    print("Priest VFX pack integrity passed: 3 packs, 27 frames, source/runtime parity, import sidecars, SpriteFrames and safe gutters.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
