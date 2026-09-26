#!/usr/bin/env python3
"""FAN-2544: blocking PixelLab pack fetch for one NAMED animation group.

Reuses the shared helpers in tools/pixellab_generate_pack.py (call, download)
and replaces only their wait and frame-URL steps.

Why both are replaced: tools/fan2541_chakrams_pixellab.py already fixes the
"queued job reads as terminal" bug, but it — like the shared
extract_frame_urls — takes the FIRST frame template in the report. That is
correct only while an object owns exactly one animation group. When an
animation is rejected on quality and re-run, the object owns several, and both
helpers silently re-download the older, rejected group's frames (observed here:
group c6eb0b43 queued, frames of group 908bfb62 returned instead). This script
takes --group-id and downloads exactly that group's frames.

Auth: PIXELLAB_BEARER_TOKEN (see tools/pixellab.env.example). Never printed.
"""
import argparse
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pixellab_generate_pack import (  # noqa: E402  - path set above
    ApiError,
    call,
    download,
)

EXIT_TIMEOUT = 3
EXIT_API_ERROR = 4
EXIT_INCOMPLETE = 5

# "  unknown: https://.../{i}.png  (i=0..8)" inside one group's report block.
FRAME_TEMPLATE_RE = re.compile(r"(https://\S+\{i\}\.png)\s+\(i=0\.\.(\d+)\)")
PENDING_RE = re.compile(r"^pending jobs \((\d+)\)", re.M)


def pending_job_count(raw_text):
    """Number of jobs the text report still lists as pending."""
    match = PENDING_RE.search(raw_text)
    return int(match.group(1)) if match else 0


def frame_template(raw_text, group_id):
    """Return (url_template, frame_count) for one group, or (None, 0).

    The report lists every group as a "[group: <id>]" block, so splitting on
    that marker keeps each template with the group that owns it.
    """
    for block in raw_text.split("[group: ")[1:]:
        if not block.startswith(group_id):
            continue
        match = FRAME_TEMPLATE_RE.search(block)
        if match:
            return match.group(1), int(match.group(2)) + 1
    return None, 0


def wait_for_group(object_id, group_id, bearer, timeout_s, interval_s, log=print):
    """Poll get_object until the named group has frames and no job is pending."""
    deadline = time.time() + timeout_s
    call_id = 300
    while True:
        info = call("get_object", {"object_id": object_id, "include_preview": False},
                    bearer, call_id)
        call_id += 1
        raw_text = info.get("_raw", "")
        template, frame_count = frame_template(raw_text, group_id)
        if template and pending_job_count(raw_text) == 0:
            return template, frame_count
        log("waiting: pending=%d %s" % (
            pending_job_count(raw_text),
            next((l.strip() for l in raw_text.splitlines() if "%" in l and "~" in l), ""),
        ))
        if time.time() >= deadline:
            raise TimeoutError(
                "timed out after %ss: object %s group %s still pending"
                % (timeout_s, object_id, group_id))
        time.sleep(interval_s)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Wait for one named PixelLab animation group, download its "
                    "frames and write the provenance manifest. Blocking; exits "
                    "non-zero on timeout, API error or an incomplete pack.")
    parser.add_argument("--object-id", required=True)
    parser.add_argument("--group-id", required=True,
                        help="animation group id returned by animate_object")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--manifest-out", required=True)
    parser.add_argument("--frame-prefix", default="scarlet_blade_f")
    parser.add_argument("--frame-count", type=int, default=9)
    parser.add_argument("--poll-interval", type=float, default=15.0)
    parser.add_argument("--timeout", type=float, default=900.0)
    args = parser.parse_args(argv)

    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set (tools/pixellab.env.example)")

    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    try:
        template, frame_count = wait_for_group(
            args.object_id, args.group_id, bearer, args.timeout, args.poll_interval)
    except TimeoutError as exc:
        print("ERROR: %s" % exc)
        return EXIT_TIMEOUT
    except ApiError as exc:
        print("ERROR: %s" % exc)
        return EXIT_API_ERROR

    frames = []
    try:
        for idx in range(frame_count):
            name = "%s%02d.png" % (args.frame_prefix, idx)
            size = download(template.replace("{i}", str(idx)),
                            os.path.join(args.source_dir, name))
            frames.append({"file": name, "bytes": size, "url_kind": "template"})
    except ApiError as exc:
        print("ERROR: %s" % exc)
        return EXIT_API_ERROR

    if len(frames) < args.frame_count:
        print("ERROR: incomplete pack: downloaded %d frames, expected %d (group %s)"
              % (len(frames), args.frame_count, args.group_id))
        return EXIT_INCOMPLETE

    manifest = {
        "tool": "tools/fan2544_sword_pixellab.py",
        "generated_at": started,
        "object": {
            "pixel_lab_object_id": args.object_id,
            "pixel_lab_animation_group_id": args.group_id,
            "create_tool": "create_1_direction_object",
            "animate_tool": "animate_object",
        },
        "frame_url_template": template,
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
