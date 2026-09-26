#!/usr/bin/env python3
"""FAN-2551: PixelLab MCP source generation for chemist/acid_flask «Царь-Колба».

Creates a 1-direction top-down colossal cracked flask over an acid lake,
animates the ultimate arc (heavy flask reveal -> pour flood -> bubbling charge
pillars -> slow evaporation), downloads the finished frames, and records every
PixelLab identifier into a reproducible JSON manifest.

The JSON-RPC plumbing is the one already proven by FAN-2550; only the creative
direction, the animation wait and the frame prefix differ. Auth resolves through
the shared smoke helper (AUTH_HEADER, PIXELLAB_BEARER_TOKEN, or
~/.codex/config.toml) and the token is never printed or written to any output.
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fan2550_blast_powder_pixellab import call, download, wait_status
from pixellab_auth_smoke import read_auth_header

OBJECT_DESCRIPTION = (
    "one single colossal cracked dark-glass alchemy flask lying tilted in the "
    "middle of one round pool of glowing acid-green liquid, dark fantasy pixel "
    "art seen straight from above, the flask neck pours one thick acid-green "
    "stream into the pool, pale green foam shoreline, only these two things "
    "exist in the image, one centered object, nothing around it, empty "
    "background, no small bottles, no extra props, no scattered items, no "
    "border decoration, no characters, no text"
)
# Identity lock: v3 drifts the flask into unrelated glassware when the flask
# itself is asked to move, so only the acid is allowed to animate.
ANIMATION_DESCRIPTION = (
    "the cracked flask stays completely still in the same place with exactly "
    "the same shape, size and dark-glass colors in every frame; only the "
    "acid-green liquid moves: the poured stream floods the pool outward in one "
    "broad wave, then tall bubbling acid pillars rise from the pool and burst, "
    "then the pool settles and pale green evaporation smoke drifts up"
)

FRAME_URL_PATTERN = re.compile(r"(https?://\S*?\{i\}\.png)\s*\(i=0\.\.(\d+)\)")


def object_report(object_id, bearer, call_id):
    """get_object as plain text; the MCP endpoint answers this tool in prose."""
    info = call("get_object", {"object_id": object_id, "include_preview": False}, bearer, call_id)
    return info.get("_raw") or json.dumps(info)


def wait_for_animation(object_id, bearer, timeout_s=1800, poll_s=10):
    """Block until an animation frame URL template exists on the object.

    The object's own `status` is `completed` as soon as the base rotation is
    rendered, so FAN-2550's wait_status() returns while the animation is still
    listed under `pending jobs`. Animation readiness is the frame template.
    """
    deadline = time.time() + timeout_s
    call_id = 200
    while time.time() < deadline:
        call_id += 1
        report = object_report(object_id, bearer, call_id)
        match = FRAME_URL_PATTERN.search(report)
        if match:
            return report, match.group(1), int(match.group(2)) + 1
        pending = [line.strip() for line in report.splitlines() if "~" in line and "%" in line]
        print("waiting for animation: %s" % (pending[0] if pending else "no progress line"),
              file=sys.stderr)
        time.sleep(poll_s)
    raise SystemExit("timeout waiting for the animation of object %s" % object_id)


def animation_group_id(report, requested_group):
    """Prefer the group id animate_object returned; fall back to the report."""
    if requested_group:
        return requested_group
    match = re.search(r"^\s*group:\s*(\S+)", report, re.M)
    return match.group(1) if match else ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True,
                        help="directory for raw PixelLab frame PNGs")
    parser.add_argument("--manifest-out", required=True,
                        help="path for the generation manifest JSON")
    parser.add_argument("--object-id", default=None,
                        help="reuse an existing PixelLab object id")
    parser.add_argument("--skip-animate", action="store_true",
                        help="an animate_object job is already running: only wait and download")
    parser.add_argument("--group-id", default=None,
                        help="animation group id of an already requested job")
    # PixelLab caps a 256x256 object at frame_count 8 (it returns frames 0..8).
    parser.add_argument("--frame-count", type=int, default=8)
    args = parser.parse_args()

    auth_header = read_auth_header(Path.home() / ".codex" / "config.toml")
    if not auth_header:
        raise SystemExit("no PixelLab auth (tools/pixellab.env.example)")
    bearer = auth_header.split(" ", 1)[1].strip()

    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    if args.object_id:
        object_id = args.object_id
    else:
        created = call("create_1_direction_object", {
            "description": OBJECT_DESCRIPTION,
            "size": 256,
            "view": "top-down",
        }, bearer, 1)
        object_id = created.get("object_id")
        if not object_id and "_raw" in created:
            for line in created["_raw"].splitlines():
                if line.startswith("id:"):
                    object_id = line.split(":", 1)[1].strip()
        if not object_id:
            raise SystemExit("no object id in create response: %s" % json.dumps(created)[:300])
    print("object_id:", object_id, file=sys.stderr)

    group = args.group_id
    if not args.skip_animate:
        obj = wait_status(object_id, bearer)
        if obj.get("status") != "completed":
            raise SystemExit("object failed: %s" % json.dumps(obj)[:400])
        anim = call("animate_object", {
            "object_id": object_id,
            "mode": "v3",
            "animation_description": ANIMATION_DESCRIPTION,
            "frame_count": args.frame_count,
        }, bearer, 2)
        raw_anim = str(anim.get("_raw", ""))
        print("animate job:", (raw_anim or json.dumps(anim))[:300], file=sys.stderr)
        # animate_object reports rejections as plain text, not as a JSON-RPC error:
        # without this guard the run silently waits on a job that never started.
        if raw_anim.lstrip().startswith("error:"):
            raise SystemExit("animate_object rejected the request: %s" % raw_anim[:300])
        match = re.search(r"^group:\s*(\S+)", raw_anim, re.M)
        group = match.group(1) if match else None

    report, template, frame_total = wait_for_animation(object_id, bearer)

    frames = []
    for index in range(frame_total):
        name = "acid_flask_f%02d.png" % index
        size = download(template.replace("{i}", str(index)),
                        os.path.join(args.source_dir, name))
        frames.append({"file": name, "bytes": size, "url_kind": "template"})
    if not frames:
        raise SystemExit("no animation frame URLs found on the completed object")

    manifest = {
        "issue": "FAN-2551",
        "weapon": "chemist/acid_flask",
        "tool": "PixelLab MCP",
        "generated_at": started,
        "object": {
            "pixel_lab_object_id": object_id,
            "create_tool": "create_1_direction_object",
            "create_params": {
                "description": OBJECT_DESCRIPTION,
                "size": 256,
                "view": "top-down",
            },
            "animate_tool": "animate_object",
            "animate_params": {
                "mode": "v3",
                "animation_description": ANIMATION_DESCRIPTION,
                "frame_count": args.frame_count,
            },
            "pixel_lab_animation_group_id": animation_group_id(report, group),
            "frame_url_template": template,
        },
        "frames": frames,
        "frame_count": len(frames),
        "auth": "AUTH_HEADER / PIXELLAB_BEARER_TOKEN / ~/.codex/config.toml (never committed)",
    }
    with open(args.manifest_out, "w") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print("wrote %s with %d frames" % (args.manifest_out, len(frames)))


if __name__ == "__main__":
    main()
