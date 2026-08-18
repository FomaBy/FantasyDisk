#!/usr/bin/env python3
"""FAN-2924: blocking PixelLab pack generation CLI (create -> poll -> download -> manifest).

Generalizes the accepted FAN-2550 pattern (tools/fan2550_blast_powder_pixellab.py)
into a reusable tool for actor/object animation packs. The whole generation runs
inside this single process: the tool polls job status in a bounded loop with a
hard wall-clock ceiling and exits non-zero on timeout, API error or an
incomplete pack, so a calling agent never has to "wait and check later".

Auth: env PIXELLAB_BEARER_TOKEN (see tools/pixellab.env.example). The token is
never printed or written to any output file.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.pixellab.ai/mcp"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)
TOOL_VERSION = "1.0.0"
EXIT_TIMEOUT = 3
EXIT_API_ERROR = 4
EXIT_INCOMPLETE = 5


class ApiError(Exception):
    """PixelLab API call failed or returned an unusable response."""


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
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
    except urllib.error.URLError as exc:
        raise ApiError("%s: network error: %s" % (tool_name, exc))
    for line in body.splitlines():
        if line.startswith("data:"):
            body = line[5:].strip()
            break
    try:
        result = json.loads(body)
    except ValueError:
        raise ApiError("%s: non-JSON response: %s" % (tool_name, body[:300]))
    if "error" in result:
        raise ApiError("%s: JSON-RPC error: %s" % (tool_name, result["error"]))
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
    try:
        data = urllib.request.urlopen(req, timeout=180).read()
    except urllib.error.URLError as exc:
        raise ApiError("download %s failed: %s" % (url, exc))
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


def _animation_group_ready(info):
    """True when there is no animation group yet, or every group is terminal.

    The object itself can report status "completed" while an animation job
    just queued on it is still running — the object-level status alone is not
    proof the animation frames exist yet.
    """
    animations = info.get("animations")
    if not animations:
        return True
    for anim in animations:
        if not isinstance(anim, dict):
            continue
        group_status = anim.get("status")
        if group_status is not None:
            if group_status not in ("completed", "failed"):
                return False
        elif not anim.get("frames"):
            return False
    return True


def wait_status(object_id, bearer, timeout_s, interval_s, call_fn=call,
                sleep_fn=time.sleep, clock=time.time, log=print):
    """Poll object status in a bounded loop until terminal state or the hard ceiling.

    Returns the terminal info dict; raises TimeoutError when the ceiling is hit
    while the job is still unfinished, ApiError on API failures.
    """
    deadline = clock() + timeout_s
    call_id = 100
    while True:
        info = call_fn("get_object", {"object_id": object_id, "include_preview": False},
                       bearer, call_id)
        call_id += 1
        if "_raw" in info:
            raw_text = info["_raw"]
            info = _parse_object_text(raw_text)
            info["_raw"] = raw_text
        status = info.get("status")
        if status in ("completed", "failed") and _animation_group_ready(info):
            return info
        log("status=%s progress=%s" % (status, info.get("progress")))
        if clock() >= deadline:
            raise TimeoutError(
                "timed out after %ss: object %s still in status %r"
                % (timeout_s, object_id, status))
        sleep_fn(interval_s)


def extract_frame_urls(obj, frame_count):
    """Collect the finished frame URLs from a completed object report."""
    animations = obj.get("animations") or ([{"_raw": obj.get("_raw", "")}] if obj.get("_raw") else [])
    for anim_entry in animations:
        anim_frames = anim_entry.get("frames") or []
        urls = []
        for frame in anim_frames:
            url = frame.get("url") if isinstance(frame, dict) else frame
            if isinstance(url, str) and url.startswith("http"):
                urls.append(url)
        if urls:
            return urls, "direct"
        template = None
        frame_total = 0
        for line in (anim_entry.get("_raw") or "").splitlines():
            line = line.strip()
            if "{i}.png" in line and "http" in line:
                for part in line.split():
                    if part.startswith("http"):
                        template = part
                        break
                if "(i=" in line:
                    frame_total = int(line.split("i=0..")[1].split(")")[0]) + 1
        if template:
            return [template.replace("{i}", str(i)) for i in range(frame_total)], "template"
    return [], "none"


def run(args, call_fn=call, download_fn=download, sleep_fn=time.sleep,
        clock=time.time, log=print):
    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set (tools/pixellab.env.example)")

    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    if args.object_id:
        object_id = args.object_id
    else:
        create_params = {
            "description": args.description,
            "size": args.size,
            "view": args.view,
        }
        try:
            created = call_fn("create_1_direction_object", create_params, bearer, 1)
        except ApiError as exc:
            log("ERROR: %s" % exc)
            return EXIT_API_ERROR
        object_id = created.get("object_id")
        if not object_id and "_raw" in created:
            for line in created["_raw"].splitlines():
                if line.startswith("id:"):
                    object_id = line.split(":", 1)[1].strip()
        if not object_id:
            log("ERROR: no object id in create response: %s" % json.dumps(created)[:300])
            return EXIT_API_ERROR
    log("object_id: %s" % object_id)

    def _wait():
        return wait_status(object_id, bearer, args.timeout, args.poll_interval,
                           call_fn=call_fn, sleep_fn=sleep_fn, clock=clock, log=log)

    try:
        obj = _wait()
    except TimeoutError as exc:
        log("ERROR: %s" % exc)
        return EXIT_TIMEOUT
    except ApiError as exc:
        log("ERROR: %s" % exc)
        return EXIT_API_ERROR
    if obj.get("status") != "completed":
        log("ERROR: object failed: %s" % json.dumps(obj)[:400])
        return EXIT_API_ERROR

    animate_params = {
        "object_id": object_id,
        "mode": args.animate_mode,
        "animation_description": args.animation_description,
        "frame_count": args.frame_count,
    }
    try:
        anim = call_fn("animate_object", animate_params, bearer, 2)
        log("animate job: %s" % json.dumps(anim)[:300])
        obj = _wait()
    except TimeoutError as exc:
        log("ERROR: %s" % exc)
        return EXIT_TIMEOUT
    except ApiError as exc:
        log("ERROR: %s" % exc)
        return EXIT_API_ERROR
    if obj.get("status") != "completed":
        log("ERROR: animation failed: %s" % json.dumps(obj)[:400])
        return EXIT_API_ERROR

    urls, url_kind = extract_frame_urls(obj, args.frame_count)
    if not urls:
        log("ERROR: no animation frame URLs found on the completed object")
        return EXIT_INCOMPLETE

    prefix = args.frame_prefix or (object_id[:8] + "_f")
    frames = []
    try:
        for idx, url in enumerate(urls):
            name = "%s%02d.png" % (prefix, idx)
            size = download_fn(url, os.path.join(args.source_dir, name))
            frames.append({"file": name, "bytes": size, "url_kind": url_kind})
    except ApiError as exc:
        log("ERROR: %s" % exc)
        return EXIT_API_ERROR

    if len(frames) < args.frame_count:
        log("ERROR: incomplete pack: downloaded %d frames, expected %d (object %s)"
            % (len(frames), args.frame_count, object_id))
        return EXIT_INCOMPLETE

    manifest = {
        "tool": "tools/pixellab_generate_pack.py",
        "tool_version": TOOL_VERSION,
        "generated_at": started,
        "object": {
            "pixel_lab_object_id": object_id,
            "create_tool": "create_1_direction_object",
            "create_params": {
                "description": args.description,
                "size": args.size,
                "view": args.view,
            },
            "animate_tool": "animate_object",
            "animate_params": {
                "mode": args.animate_mode,
                "animation_description": args.animation_description,
                "frame_count": args.frame_count,
            },
        },
        "frames": frames,
        "frame_count": len(frames),
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
    }
    with open(args.manifest_out, "w") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    log("wrote %s with %d frames" % (args.manifest_out, len(frames)))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Blocking PixelLab pack generation: create job, poll to "
                    "completion or hard ceiling, download frames, write manifest. "
                    "Exits non-zero on timeout, API error or incomplete pack.")
    parser.add_argument("--source-dir", required=True,
                        help="directory for downloaded frame PNGs")
    parser.add_argument("--manifest-out", required=True,
                        help="path for the provenance manifest JSON")
    parser.add_argument("--description", default=None,
                        help="object description for create_1_direction_object "
                             "(required unless --object-id is given)")
    parser.add_argument("--animation-description", required=True,
                        help="animation description for animate_object")
    parser.add_argument("--object-id", default=None,
                        help="reuse an existing PixelLab object id")
    parser.add_argument("--frame-prefix", default=None,
                        help="frame filename prefix (default: <object_id[:8]>_f)")
    parser.add_argument("--frame-count", type=int, default=16)
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--view", default="top-down")
    parser.add_argument("--animate-mode", default="v3")
    parser.add_argument("--poll-interval", type=float, default=30.0,
                        help="seconds between get_object status polls (default 30)")
    parser.add_argument("--timeout", type=float, default=900.0,
                        help="hard wall-clock ceiling per job in seconds "
                             "(default 900 = 15 minutes)")
    args = parser.parse_args(argv)
    if not args.object_id and not args.description:
        parser.error("--description is required unless --object-id is given")
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
