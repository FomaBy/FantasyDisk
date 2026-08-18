#!/usr/bin/env python3
"""FAN-2565: PixelLab MCP animation source for engineer/engineer_sentry_wrench «Гнездо Часовых».

Creates one tall sentry pylon object, animates the deploy -> fire -> fold arc,
downloads the finished frames and records every PixelLab identifier into a
reproducible provenance manifest.

The pylon is generated in the `sidescroller` view, the only one of the two
views `create_1_direction_object` accepts that keeps a tall narrow silhouette:
the class formation places these as upright billboard props, exactly like the
forged 49x112 pylon they replace, and a `top-down` pylon collapses into a round
plate that no longer reads apart from the pressure-mine dome.

The API helpers come from the accepted blocking CLI
(`tools/pixellab_generate_pack.py`, FAN-2924); this script only adds the two
behaviours the sentry pack needed and the shared tool does not have yet:

* `animate_object` leaves the object in status `completed` while the new job is
  still queued, so waiting on status alone returns before a single frame
  exists. This waits until the object reports no pending jobs and a real
  animation group.
* the completed report prints frame templates as `<direction>: <url>`, so the
  URL is the first `http` token on the line, not the first token.

Auth: env PIXELLAB_BEARER_TOKEN (see tools/pixellab.env.example). The token is
never printed or written to any output file.

Reproduce (one blocking command, ~10 minutes):

    python3 tools/fan2565_sentry_wrench_pixellab.py \\
      --source-dir docs/design/references/weapon_ultimates/engineer/source/pixellab_sentry_wrench \\
      --manifest-out docs/design/references/weapon_ultimates/engineer/provenance_manifest_sentry_wrench.json
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_generate_pack import call, download  # noqa: E402

OBJECT_DESCRIPTION = (
    "dark fantasy pixel art engineer sentry turret pylon seen from the side: "
    "exactly one single tall narrow vertical tower, at least twice as tall as "
    "it is wide, standing on a small square footplate no wider than the tower "
    "itself, a compact hexagonal turret head with two short gun barrels at the "
    "very top, pale mint and teal painted metal with warm copper trim and one "
    "small glowing cyan lens, upright and centered with clear empty margin on "
    "all four sides, isolated game sprite on a fully transparent background, "
    "only one tower and nothing else, no round platform, no circular base "
    "disc, no ground, no shadow, no characters, no text, no extra machines"
)
ANIMATION_DESCRIPTION = (
    "the same single tall sentry tower stays centered and upright and keeps "
    "its identity in every frame, it never becomes a different machine and "
    "nothing else enters the frame: it starts as a low folded stack of armor "
    "plates, then telescopes straight upward into the full tall tower, the "
    "hexagonal head at the top unfolds and the two barrels swing out and lock "
    "forward, the barrels flash and recoil while firing twice, then the head "
    "folds back down and the tower telescopes back down into the low folded "
    "stack venting one small puff of steam"
)


def report(object_id, bearer, call_id):
    """Fetch the object report as raw text."""
    info = call("get_object", {"object_id": object_id, "include_preview": False}, bearer, call_id)
    return info.get("_raw", json.dumps(info))


def is_busy(raw):
    """True while any job is still running.

    A creating object reports `status: creating` + `job_status: pending`; a
    finished one that is being animated keeps `status: completed` and adds a
    `pending jobs (n)` section, so both shapes have to be recognised.
    """
    if "pending jobs" in raw or "job_status: pending" in raw:
        return True
    for line in raw.splitlines():
        if line.startswith("status:"):
            return line.split(":", 1)[1].strip() != "completed"
    return False


def wait_idle(object_id, bearer, timeout_s, interval_s, want_animation):
    """Block until the object has no running job, and optionally a real animation group."""
    deadline = time.time() + timeout_s
    call_id = 100
    while True:
        call_id += 1
        raw = report(object_id, bearer, call_id)
        animated = "animations: none" not in raw and "{i}.png" in raw
        if not is_busy(raw) and (animated or not want_animation):
            return raw
        progress = [line.strip() for line in raw.splitlines() if "%" in line and "~" in line]
        print("waiting: %s" % (progress[0] if progress else "queued"), file=sys.stderr)
        if time.time() >= deadline:
            raise SystemExit("timeout after %ss: object %s still working" % (timeout_s, object_id))
        time.sleep(interval_s)


def frame_urls(raw):
    """Frame template URLs from a completed report line `<direction>: <url> (i=0..N)`."""
    for line in raw.splitlines():
        if "{i}.png" not in line:
            continue
        for token in line.split():
            if token.startswith("http"):
                total = int(line.split("i=0..")[1].split(")")[0]) + 1
                return [token.replace("{i}", str(index)) for index in range(total)]
    return []


def rotation_url(raw):
    for line in raw.splitlines():
        for token in line.split():
            if token.startswith("http") and token.endswith("rotations/unknown.png"):
                return token
    return None


def animation_group_id(raw):
    for line in raw.splitlines():
        if "[group:" in line:
            return line.split("[group:", 1)[1].split("]", 1)[0].strip()
    return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--manifest-out", required=True)
    parser.add_argument("--object-id", default=None, help="reuse an existing object instead of creating one")
    parser.add_argument("--frame-count", type=int, default=8, help="v3 requires an even 4..16")
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--view", default="sidescroller")
    parser.add_argument("--skip-animate", action="store_true",
                        help="only wait for and download an animation that was already requested")
    parser.add_argument("--poll-interval", type=float, default=15.0)
    parser.add_argument("--timeout", type=float, default=900.0)
    args = parser.parse_args()

    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set (tools/pixellab.env.example)")
    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    object_id = args.object_id
    if not object_id:
        created = call("create_1_direction_object", {
            "description": OBJECT_DESCRIPTION,
            "size": args.size,
            "view": args.view,
        }, bearer, 1)
        object_id = created.get("object_id")
        if not object_id:
            for line in created.get("_raw", "").splitlines():
                if line.startswith("id:"):
                    object_id = line.split(":", 1)[1].strip()
        if not object_id:
            raise SystemExit("no object id in create response: %s" % json.dumps(created)[:300])
    print("object_id: %s" % object_id, file=sys.stderr)
    wait_idle(object_id, bearer, args.timeout, args.poll_interval, want_animation=False)

    if not args.skip_animate:
        call("animate_object", {
            "object_id": object_id,
            "mode": "v3",
            "animation_description": ANIMATION_DESCRIPTION,
            "frame_count": args.frame_count,
        }, bearer, 2)
    raw = wait_idle(object_id, bearer, args.timeout, args.poll_interval, want_animation=True)

    urls = frame_urls(raw)
    if not urls:
        raise SystemExit("no animation frame URLs on the completed object %s" % object_id)
    frames = []
    for index, url in enumerate(urls):
        name = "sentry_pylon_f%02d.png" % index
        frames.append({"file": name, "bytes": download(url, os.path.join(args.source_dir, name))})
    base = rotation_url(raw)
    if base:
        download(base, os.path.join(args.source_dir, "base_rotation.png"))

    manifest = {
        "issue": "FAN-2565",
        "weapon": "engineer/engineer_sentry_wrench",
        "tool": "PixelLab MCP via tools/fan2565_sentry_wrench_pixellab.py",
        "generated_at": started,
        "object": {
            "pixel_lab_object_id": object_id,
            "pixel_lab_animation_group_id": animation_group_id(raw),
            "create_tool": "create_1_direction_object",
            "create_params": {
                "description": OBJECT_DESCRIPTION,
                "size": args.size,
                "view": args.view,
            },
            "animate_tool": "animate_object",
            "animate_params": {
                "mode": "v3",
                "animation_description": ANIMATION_DESCRIPTION,
                "frame_count": args.frame_count,
            },
        },
        "frames": frames,
        "frame_count": len(frames),
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
    }
    with open(args.manifest_out, "w") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print("wrote %s with %d frames" % (args.manifest_out, len(frames)))


if __name__ == "__main__":
    main()
