#!/usr/bin/env python3
"""FAN-2550: PixelLab MCP source generation for chemist/blast_powder «Философский Взрыв».

Creates a 1-direction top-down alchemical pentagram object, animates the
ultimate arc (ignition -> pentagram -> crystal implosion -> gold transmutation
blast -> fade), downloads the finished frames, and records every PixelLab
identifier into a reproducible JSON manifest.

Auth: env PIXELLAB_BEARER_TOKEN (see tools/pixellab.env.example). The token is
never printed or written to any output file.
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.request

API = "https://api.pixellab.ai/mcp"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)

OBJECT_DESCRIPTION = (
    "dark fantasy pixel art alchemical ritual magic circle seen straight from "
    "above: a glowing pentagram of gold runes with five small round powder "
    "kegs sitting at its points, each keg glowing a different alchemical "
    "color, faint crystal shards rising at the rim, centered composition, "
    "isolated game VFX sprite, no characters, no text"
)
ANIMATION_DESCRIPTION = (
    "the five powder kegs ignite one after another with colored sparks, the "
    "pentagram runes brighten and rotate slightly, then everything is pulled "
    "inward into a tight dark crystal at the center, and finally the crystal "
    "bursts into one big bright gold-white transmutation explosion with "
    "radiating light rays and drifting sparkles that fade out"
)


def call(tool_name, arguments, bearer, call_id):
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": call_id, "method": "tools/call",
         "params": {"name": tool_name, "arguments": arguments}}
    ).encode()
    req = urllib.request.Request(
        API,
        data=payload,
        headers={
            "Authorization": "Bearer " + bearer,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    try:
        body = urllib.request.urlopen(req, timeout=180).read().decode()
    except urllib.error.HTTPError as exc:  # pragma: no cover - network surface
        body = exc.read().decode()
    for line in body.splitlines():
        if line.startswith("data:"):
            body = line[5:].strip()
            break
    result = json.loads(body)
    if "error" in result:
        raise SystemExit("JSON-RPC error from %s: %s" % (tool_name, result["error"]))
    content = result.get("result", {}).get("content", [])
    for item in content:
        if item.get("type") == "text":
            text = item["text"]
            try:
                return json.loads(text)
            except ValueError:
                return {"_raw": text}
    return result.get("result", {})


def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    data = urllib.request.urlopen(req, timeout=180).read()
    with open(path, "wb") as fh:
        fh.write(data)
    return len(data)


def _parse_object_text(text):
    """Parse the get_object text report (status/progress/urls) when it is not JSON."""
    info = {}
    for line in text.splitlines():
        if line.startswith("status:"):
            info["status"] = line.split(":", 1)[1].strip()
        elif line.startswith("progress:"):
            info["progress"] = line.split(":", 1)[1].strip()
        elif line.startswith("http://") or line.startswith("https://"):
            info.setdefault("urls", []).append(line.strip())
    return info


def wait_status(object_id, bearer, terminal=("completed", "failed"), timeout_s=900):
    deadline = time.time() + timeout_s
    call_id = 100
    while time.time() < deadline:
        call_id += 1
        info = call("get_object", {"object_id": object_id, "include_preview": False}, bearer, call_id)
        if "_raw" in info:
            raw_text = info["_raw"]
            info = _parse_object_text(raw_text)
            info["_raw"] = raw_text
        status = info.get("status")
        if status in terminal:
            return info
        print("status=%s progress=%s" % (status, info.get("progress")), file=sys.stderr)
        time.sleep(10)
    raise SystemExit("timeout waiting for object %s" % object_id)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True,
                        help="directory for raw PixelLab frame PNGs")
    parser.add_argument("--manifest-out", required=True,
                        help="path for the generation manifest JSON")
    parser.add_argument("--object-id", default=None,
                        help="reuse an existing PixelLab object id")
    parser.add_argument("--frame-count", type=int, default=16)
    args = parser.parse_args()

    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set (tools/pixellab.env.example)")

    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    if args.object_id:
        object_id = args.object_id
        created = {"result": {"object_id": object_id, "reused": True}}
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

    obj = wait_status(object_id, bearer)
    if obj.get("status") != "completed":
        raise SystemExit("object failed: %s" % json.dumps(obj)[:400])

    anim = call("animate_object", {
        "object_id": object_id,
        "mode": "v3",
        "animation_description": ANIMATION_DESCRIPTION,
        "frame_count": args.frame_count,
    }, bearer, 2)
    print("animate job:", json.dumps(anim)[:300], file=sys.stderr)

    obj = wait_status(object_id, bearer)
    if obj.get("status") != "completed":
        raise SystemExit("animation failed: %s" % json.dumps(obj)[:400])

    animations = obj.get("animations") or ([{"_raw": obj.get("_raw", "")}] if obj.get("_raw") else [])
    if not animations:
        raise SystemExit("no animations in completed object: %s" % json.dumps(obj)[:600])

    frames = []
    template = None
    frame_total = 0
    for anim_entry in animations:
        anim_frames = anim_entry.get("frames") or []
        if anim_frames:
            for idx, frame in enumerate(anim_frames):
                url = frame.get("url") if isinstance(frame, dict) else frame
                if isinstance(url, str) and url.startswith("http"):
                    name = "blast_powder_f%02d.png" % idx
                    path = os.path.join(args.source_dir, name)
                    size = download(url, path)
                    frames.append({"file": name, "bytes": size, "url_kind": "direct"})
            break
        raw = anim_entry.get("_raw") or ""
        for line in raw.splitlines():
            line = line.strip()
            if "{i}.png" in line and "http" in line:
                template = line.split(" ")[0]
                if "(i=" in line:
                    frame_total = int(line.split("i=0..")[1].split(")")[0]) + 1
        if template:
            for idx in range(frame_total):
                url = template.replace("{i}", str(idx))
                name = "blast_powder_f%02d.png" % idx
                path = os.path.join(args.source_dir, name)
                size = download(url, path)
                frames.append({"file": name, "bytes": size, "url_kind": "template"})
            break

    if not frames:
        raise SystemExit("no animation frame URLs found on the completed object")

    manifest = {
        "issue": "FAN-2550",
        "weapon": "chemist/blast_powder",
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
            "animation_group_ids": [a.get("id") or a.get("animation_group_id")
                                    for a in animations],
        },
        "frames": frames,
        "frame_count": len(frames),
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
    }
    with open(args.manifest_out, "w") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print("wrote %s with %d frames" % (args.manifest_out, len(frames)))


if __name__ == "__main__":
    main()
