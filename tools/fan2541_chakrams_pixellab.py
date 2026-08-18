#!/usr/bin/env python3
"""FAN-2541: blocking PixelLab pack fetch for the assassin/chakrams ultimate.

Reuses the shared helpers in tools/pixellab_generate_pack.py (call, download,
extract_frame_urls) and replaces only their wait step.

Why the wait is replaced: PixelLab answers get_object for this object as a plain
text report, and tools/pixellab_generate_pack._parse_object_text keeps only
status/progress/urls from it. The queued animate job lives in the report's
"pending jobs" section and the frames in its "animations" section, so neither
reaches _animation_group_ready(); the object's own "status: completed" then
looks terminal while the animation is still at 12%, and the download step finds
no frame URLs (observed here: exit 5 on group b8cddfa4). This script waits on
the animation itself - frames listed and no job still pending - before
downloading.

Auth: PIXELLAB_BEARER_TOKEN (see tools/pixellab.env.example). Never printed.
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pixellab_generate_pack import (  # noqa: E402  - path set above
    ApiError,
    call,
    download,
    extract_frame_urls,
)

EXIT_TIMEOUT = 3
EXIT_API_ERROR = 4
EXIT_INCOMPLETE = 5


def pending_job_count(raw_text):
    """Number of jobs the text report still lists as pending."""
    for line in raw_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("pending jobs"):
            digits = "".join(ch for ch in stripped if ch.isdigit())
            return int(digits) if digits else 0
    return 0


def animations_ready(raw_text):
    """True once the report lists animation frames and no job is still pending.

    Keyed on the frame URL template rather than the "animations" header, because
    that header is written both as "animations: none" and as
    "animations (1 groups):" - and the template is exactly what the download
    step needs to exist.
    """
    if pending_job_count(raw_text) > 0:
        return False
    return any("{i}.png" in line for line in raw_text.splitlines())


def wait_for_animation(object_id, bearer, timeout_s, interval_s, log=print):
    """Poll get_object until its animation frames exist or the ceiling is hit."""
    deadline = time.time() + timeout_s
    call_id = 200
    while True:
        info = call("get_object", {"object_id": object_id, "include_preview": False},
                    bearer, call_id)
        call_id += 1
        raw_text = info.get("_raw", "")
        if raw_text and animations_ready(raw_text):
            return info
        log("waiting: pending=%d %s" % (
            pending_job_count(raw_text),
            next((l.strip() for l in raw_text.splitlines() if "%" in l and "~" in l), ""),
        ))
        if time.time() >= deadline:
            raise TimeoutError(
                "timed out after %ss: object %s animation still pending"
                % (timeout_s, object_id))
        time.sleep(interval_s)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Wait for an already queued PixelLab animation job, download "
                    "its frames and write the provenance manifest. Blocking; "
                    "exits non-zero on timeout, API error or an incomplete pack.")
    parser.add_argument("--object-id", required=True)
    parser.add_argument("--group-id", required=True,
                        help="animation group id returned by animate_object")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--manifest-out", required=True)
    parser.add_argument("--frame-prefix", default="chakram_moon_f")
    parser.add_argument("--frame-count", type=int, default=9)
    parser.add_argument("--poll-interval", type=float, default=15.0)
    parser.add_argument("--timeout", type=float, default=540.0)
    args = parser.parse_args(argv)

    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set (tools/pixellab.env.example)")

    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    try:
        obj = wait_for_animation(args.object_id, bearer, args.timeout, args.poll_interval)
    except TimeoutError as exc:
        print("ERROR: %s" % exc)
        return EXIT_TIMEOUT
    except ApiError as exc:
        print("ERROR: %s" % exc)
        return EXIT_API_ERROR

    urls, url_kind = extract_frame_urls(obj, args.frame_count)
    if not urls:
        print("ERROR: no animation frame URLs on the completed object")
        return EXIT_INCOMPLETE

    frames = []
    try:
        for idx, url in enumerate(urls):
            name = "%s%02d.png" % (args.frame_prefix, idx)
            size = download(url, os.path.join(args.source_dir, name))
            frames.append({"file": name, "bytes": size, "url_kind": url_kind})
    except ApiError as exc:
        print("ERROR: %s" % exc)
        return EXIT_API_ERROR

    if len(frames) < args.frame_count:
        print("ERROR: incomplete pack: downloaded %d frames, expected %d (object %s)"
              % (len(frames), args.frame_count, args.object_id))
        return EXIT_INCOMPLETE

    manifest = {
        "tool": "tools/fan2541_chakrams_pixellab.py",
        "generated_at": started,
        "object": {
            "pixel_lab_object_id": args.object_id,
            "pixel_lab_animation_group_id": args.group_id,
            "create_tool": "create_1_direction_object",
            "animate_tool": "animate_object",
        },
        "frames": frames,
        "frame_count": len(frames),
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
    }
    with open(args.manifest_out, "w") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print("wrote %s with %d frames" % (args.manifest_out, len(frames)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
