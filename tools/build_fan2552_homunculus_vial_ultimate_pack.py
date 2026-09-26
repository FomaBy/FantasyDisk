#!/usr/bin/env python3
"""Build the FAN-2552 chemist/homunculus_vial ultimate avatar animation pack.

Downloads the 9-frame PixelLab `animate_image` stomp cycle (index 0 is the
accepted `ally_homunculus.png` source frame unchanged), validates every frame
against the ultimate-animation alpha contract, removes sub-speck orphan alpha
clusters, and writes the runtime frames plus a reproducible manifest under
`assets/sprites/effects/ultimates/chemist/homunculus_vial/`.

Alpha contract per frame:
- exactly 256x256 RGBA with a fully transparent 1px canvas rim (no crop);
- no background matte plate: a plate fills its alpha bbox almost solidly, an
  organic sprite never does, so the bbox fill ratio must stay under
  MATTE_PLATE_FILL_RATIO (the frames run 0.4-0.6);
- one dominant alpha component; orphan clusters under SPECK_MAX_PX are removed
  and reported, larger detached clusters are the flame embers the motion needs;
- the horizontal centre stays within PIVOT_TOLERANCE_PX of the source frame,
  so pivot and identity cannot drift (vertical bbox motion is the stomp
  itself: the wisp tail lifts on the raise and the body compresses on impact).

Usage:
    python3 tools/build_fan2552_homunculus_vial_ultimate_pack.py            # download + build
    python3 tools/build_fan2552_homunculus_vial_ultimate_pack.py --check   # re-validate committed frames
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets/sprites/effects/ultimates/chemist/homunculus_vial"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"

JOB_ID = "331684be-2ee9-43cd-8eb6-842051201a17"
SEED = 2552
FRAME_COUNT = 9
DOWNLOAD_URL = "https://api.pixellab.ai/mcp/images/%s/download?index=%d"
USER_AGENT = "FantasyDisk-FAN2552/1.0"
ACTION_PROMPT = (
    "towering alchemical golem raises both flaming fists high overhead, slams "
    "them down in one heavy ground stomp, its round glass body compresses with "
    "the impact, then it rises back up tall to its original stance"
)
SOURCE_SPRITE = "assets/sprites/allies/ally_homunculus.png"

CANVAS = 256
ALPHA_VISIBLE = 8
SPECK_MAX_PX = 12
PIVOT_TOLERANCE_PX = 10
MATTE_PLATE_FILL_RATIO = 0.92


def _components(im: Image.Image) -> list[list[tuple[int, int]]]:
    px = im.load()
    width, height = im.size
    seen = [[False] * height for _ in range(width)]
    found: list[list[tuple[int, int]]] = []
    for x in range(width):
        for y in range(height):
            if px[x, y][3] > ALPHA_VISIBLE and not seen[x][y]:
                queue = deque([(x, y)])
                seen[x][y] = True
                pixels = []
                while queue:
                    cx, cy = queue.popleft()
                    pixels.append((cx, cy))
                    for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                        if 0 <= nx < width and 0 <= ny < height and not seen[nx][ny] and px[nx, ny][3] > ALPHA_VISIBLE:
                            seen[nx][ny] = True
                            queue.append((nx, ny))
                found.append(pixels)
    return found


def _validate_and_clean(im: Image.Image, index: int, errors: list[str]) -> tuple[Image.Image, dict]:
    if im.size != (CANVAS, CANVAS):
        errors.append("frame %d is %dx%d, expected %dx%d" % (index, im.size[0], im.size[1], CANVAS, CANVAS))
        return im, {}
    im = im.convert("RGBA")
    px = im.load()
    rim = sum(1 for x in range(CANVAS) for y in (0, CANVAS - 1) if px[x, y][3] > ALPHA_VISIBLE)
    rim += sum(1 for y in range(CANVAS) for x in (0, CANVAS - 1) if px[x, y][3] > ALPHA_VISIBLE)
    if rim:
        errors.append("frame %d touches the canvas rim on %d pixels (crop)" % (index, rim))

    components = sorted(_components(im), key=len, reverse=True)
    if not components:
        errors.append("frame %d has no visible alpha" % index)
        return im, {}
    removed = 0
    for component in components[1:]:
        if len(component) < SPECK_MAX_PX:
            for x, y in component:
                px[x, y] = (0, 0, 0, 0)
            removed += len(component)

    bbox = im.getchannel("A").point(lambda v: 255 if v > ALPHA_VISIBLE else 0).getbbox()
    visible = sum(len(component) for component in components if len(component) >= SPECK_MAX_PX)
    fill_ratio = visible / float(max((bbox[2] - bbox[0]) * (bbox[3] - bbox[1]), 1))
    if fill_ratio > MATTE_PLATE_FILL_RATIO:
        errors.append("frame %d fills %.2f of its alpha bbox: background matte plate" % (index, fill_ratio))
    report = {
        "alpha_bbox": list(bbox),
        "bbox_fill_ratio": round(fill_ratio, 3),
        "main_component_px": len(components[0]),
        "speck_px_removed": removed,
    }
    return im, report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="re-validate the committed frames instead of downloading")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    errors: list[str] = []
    frames: list[dict] = []
    baseline_bbox: list[int] | None = None

    for index in range(FRAME_COUNT):
        name = "avatar_stomp_%02d.png" % index
        path = OUTPUT_DIR / name
        if args.check:
            if not path.exists():
                errors.append("missing committed frame %s" % name)
                continue
            im = Image.open(path).convert("RGBA")
        else:
            request = urllib.request.Request(DOWNLOAD_URL % (JOB_ID, index), headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=120) as response:
                path.write_bytes(response.read())
            im = Image.open(path).convert("RGBA")
        im, report = _validate_and_clean(im, index, errors)
        if not report:
            continue
        if args.check and report["speck_px_removed"]:
            errors.append("frame %d still carries %d orphan speck pixels" % (index, report["speck_px_removed"]))
        if not args.check:
            im.save(path)
        if baseline_bbox is None:
            baseline_bbox = report["alpha_bbox"]
        else:
            bbox = report["alpha_bbox"]
            centre_drift = abs((bbox[0] + bbox[2]) - (baseline_bbox[0] + baseline_bbox[2])) / 2.0
            if centre_drift > PIVOT_TOLERANCE_PX:
                errors.append("frame %d horizontal centre drifts %.1fpx" % (index, centre_drift))
        frames.append({"file": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), **report})

    if errors:
        for error in errors:
            print("FAIL: %s" % error, file=sys.stderr)
        return 1

    manifest = {
        "issue": "FAN-2552",
        "ultimate_key": "chemist/homunculus_vial",
        "generator": "PixelLab MCP animate_image",
        "job_id": JOB_ID,
        "seed": SEED,
        "action_prompt": ACTION_PROMPT,
        "identity_source": SOURCE_SPRITE,
        "canvas": [CANVAS, CANVAS],
        "frame_0_note": "index 0 is the accepted identity source frame returned unchanged by the job",
        "alpha_contract": {
            "visible_alpha_threshold": ALPHA_VISIBLE,
            "speck_max_px": SPECK_MAX_PX,
            "pivot_tolerance_px": PIVOT_TOLERANCE_PX,
        },
        "frames": frames,
    }
    if not args.check:
        MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print("wrote %d frames + manifest to %s" % (len(frames), OUTPUT_DIR.relative_to(ROOT)))
    else:
        committed = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        stored = {frame["file"]: frame["sha256"] for frame in committed.get("frames", [])}
        current = {frame["file"]: frame["sha256"] for frame in frames}
        if stored != current:
            print("FAIL: committed manifest hashes do not match the frames on disk", file=sys.stderr)
            return 1
        print("check passed: %d frames match the committed manifest" % len(frames))
    return 0


if __name__ == "__main__":
    sys.exit(main())
