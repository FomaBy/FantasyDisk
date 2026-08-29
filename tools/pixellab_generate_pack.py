#!/usr/bin/env python3
"""FAN-2924: blocking PixelLab pack generation CLI (create -> poll -> download -> manifest).

Generalizes the accepted FAN-2550 pattern (tools/fan2550_blast_powder_pixellab.py)
into a reusable tool for actor/object animation packs. The whole generation runs
inside this single process: the tool polls job status in a bounded loop with a
hard wall-clock ceiling and exits non-zero on timeout, API error or an
incomplete pack, so a calling agent never has to "wait and check later".

Auth: env PIXELLAB_BEARER_TOKEN (see tools/pixellab.env.example). The token is
never printed or written to any output file.

FAN-2921: manifest/provenance contract for byte-reproducible packs. Every frame
is decoded with Pillow once (to prove it is a valid image and to fingerprint
its pixels) and the manifest records both the raw encoded-file SHA-256 and the
decoded-pixel SHA-256, plus the Pillow version and builder version that
produced them (`encoder_provenance`). `--check` (`check_pack`) re-validates a
pack against its manifest: an encoded-byte mismatch with matching decoded
pixels and a different recorded Pillow version is a harmless re-encode (WARN,
still exit 0); any decoded-pixel mismatch, or a byte mismatch that the
manifest cannot explain, is real drift (FAIL). Missing/corrupt/unknown
manifest fields always fail closed — they never read as success. These
helpers (`encoder_provenance`, `frame_hashes`, `check_pack`) are reusable by
other pack-building tools; they do not touch any already-accepted pack.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

API = "https://api.pixellab.ai/mcp"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)
TOOL_VERSION = "1.0.0"
EXIT_TIMEOUT = 3
EXIT_API_ERROR = 4
EXIT_INCOMPLETE = 5
EXIT_CHECK_FAILED = 6


def encoder_provenance():
    """Pillow version and builder version that fingerprinted this pack's frames.

    Recorded so `--check` can tell "same pixels, re-encoded by a newer Pillow"
    (harmless) apart from "the pixels actually changed" (real drift).
    """
    return {
        "library": "Pillow",
        "library_version": Image.__version__,
        "builder_version": TOOL_VERSION,
    }


def frame_hashes(path):
    """(encoded_sha256, pixel_sha256) for a PNG file on disk.

    encoded_sha256 hashes the raw file bytes; pixel_sha256 hashes the decoded
    RGBA pixel data, so it stays stable across re-encodes of identical pixels.
    Raises OSError/PIL errors on a missing or corrupt image — callers must
    treat that as a failure, never as a match.
    """
    with open(path, "rb") as fh:
        raw = fh.read()
    encoded_sha256 = hashlib.sha256(raw).hexdigest()
    with Image.open(path) as im:
        pixel_sha256 = hashlib.sha256(im.convert("RGBA").tobytes()).hexdigest()
    return encoded_sha256, pixel_sha256


def check_pack(manifest_path, source_dir, log=print):
    """Re-validate a pack's frames on disk against its manifest.

    Returns True only when every frame's decoded pixels match the manifest and
    every encoded-byte mismatch is explained by a recorded Pillow version
    change. Any real pixel drift, missing file, or manifest that lacks the
    fields this check needs fails closed (returns False) — it never reports
    success on data it cannot verify.
    """
    try:
        with open(manifest_path, "r", encoding="utf-8") as fh:
            manifest = json.load(fh)
    except (OSError, ValueError) as exc:
        log("FAIL: cannot read manifest %s: %s" % (manifest_path, exc))
        return False

    encoder = manifest.get("encoder")
    if not isinstance(encoder, dict) or not encoder.get("library_version"):
        log("FAIL: manifest is missing a valid \"encoder\" block")
        return False
    manifest_pillow_version = encoder["library_version"]

    frames = manifest.get("frames")
    if not isinstance(frames, list) or not frames:
        log("FAIL: manifest has no frames")
        return False

    ok = True
    for frame in frames:
        name = frame.get("file") if isinstance(frame, dict) else None
        stored_encoded = frame.get("encoded_sha256") if isinstance(frame, dict) else None
        stored_pixel = frame.get("pixel_sha256") if isinstance(frame, dict) else None
        if not name or not stored_encoded or not stored_pixel:
            log("FAIL: manifest frame entry is missing file/encoded_sha256/pixel_sha256: %r" % (frame,))
            ok = False
            continue

        path = os.path.join(source_dir, name)
        if not os.path.exists(path):
            log("FAIL: %s: missing on disk" % name)
            ok = False
            continue
        try:
            current_encoded, current_pixel = frame_hashes(path)
        except Exception as exc:  # noqa: BLE001 - any decode failure is a hard fail
            log("FAIL: %s: cannot decode: %s" % (name, exc))
            ok = False
            continue

        if current_encoded == stored_encoded:
            continue
        if current_pixel != stored_pixel:
            log("FAIL: %s: decoded pixels changed (real drift)" % name)
            ok = False
            continue
        current_pillow_version = Image.__version__
        if current_pillow_version != manifest_pillow_version:
            log(
                "WARN: %s: encoded bytes changed but decoded pixels are identical "
                "(Pillow %s -> %s)" % (name, manifest_pillow_version, current_pillow_version)
            )
            continue
        log(
            "FAIL: %s: encoded bytes changed under the same Pillow version %s "
            "(unexplained)" % (name, current_pillow_version)
        )
        ok = False

    if ok:
        log("check passed: %d frames match the manifest" % len(frames))
    return ok


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
    """Parse status, progress, pending jobs and URLs from a text report."""
    info = {}
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("status:"):
            info["status"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("progress:"):
            info["progress"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("pending jobs"):
            info["pending_jobs"] = 1
        elif stripped.startswith("http://") or stripped.startswith("https://"):
            info.setdefault("urls", []).append(stripped)
    return info


def _animation_group_ready(info):
    """True when there is no animation group yet, or every group is terminal.

    The object itself can report status "completed" while an animation job
    just queued on it is still running — the object-level status alone is not
    proof the animation frames exist yet.
    """
    if info.get("pending_jobs"):
        return False
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


def extract_character_frame_urls(info, animation_name, directions):
    """Collect URLs for one completed named animation on a character."""
    raw = info.get("_raw", "")
    lines = raw.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.startswith("  ") and not line.startswith("    ") and " — " in line:
            if line[2:].split(" — ", 1)[0] == animation_name:
                start = index + 1
                break
    if start is None:
        return {}

    rows = {}
    for line in lines[start:]:
        if line.startswith("  ") and not line.startswith("    ") and line.strip():
            break
        match = re.match(r"^    ([a-z-]+): (.+)$", line)
        if not match:
            continue
        direction, url_text = match.groups()
        rows[direction] = re.findall(r"https?://[^,\s]+\.png(?:\?[^,\s]+)?", url_text)
    return {direction: rows.get(direction, []) for direction in directions}


def wait_character(character_id, animation_name, directions, bearer, timeout_s,
                   interval_s, call_fn=call, sleep_fn=time.sleep,
                   clock=time.time, log=print):
    """Poll a character until a named animation has all requested directions."""
    deadline = clock() + timeout_s
    call_id = 100
    while True:
        info = call_fn("get_character", {"character_id": character_id,
                                          "include_preview": False}, bearer, call_id)
        call_id += 1
        if "_raw" in info:
            raw = info["_raw"]
            parsed = _parse_object_text(raw)
            parsed["_raw"] = raw
            info = parsed
        status = info.get("status")
        rows = extract_character_frame_urls(info, animation_name, directions)
        if status == "failed":
            return info
        if status == "completed" and all(rows.get(direction) for direction in directions):
            return info
        log("character=%s status=%s progress=%s animation=%s" %
            (character_id, status, info.get("progress"), animation_name))
        if clock() >= deadline:
            raise TimeoutError(
                "timed out after %ss: character %s has no complete %r animation" %
                (timeout_s, character_id, animation_name))
        sleep_fn(interval_s)


def run_character(args, bearer, started, call_fn=call, download_fn=download,
                  sleep_fn=time.sleep, clock=time.time, log=print):
    """Generate selected directions on an existing PixelLab character."""
    if not args.animation_name:
        raise SystemExit("--animation-name is required with --character-id")
    directions = args.directions or []
    if not directions:
        raise SystemExit("--directions is required with --character-id")

    character_id = args.character_id
    custom_start_frame_url = getattr(args, "custom_start_frame_url", None)
    starting_frame_name = getattr(args, "starting_frame_name", None)
    log("character_id: %s" % character_id)
    animate_params = {
        "character_id": character_id,
        "mode": args.animate_mode,
        "action_description": args.animation_description,
        "animation_name": args.animation_name,
        "directions": directions,
        "frame_count": args.frame_count,
    }
    if custom_start_frame_url:
        animate_params["custom_start_frame_url"] = custom_start_frame_url
    try:
        anim = call_fn("animate_character", animate_params, bearer, 1)
        log("animate job: %s" % json.dumps(anim)[:300])
        info = wait_character(character_id, args.animation_name, directions, bearer,
                               args.timeout, args.poll_interval,
                               call_fn=call_fn, sleep_fn=sleep_fn,
                               clock=clock, log=log)
    except TimeoutError as exc:
        log("ERROR: %s" % exc)
        return EXIT_TIMEOUT
    except ApiError as exc:
        log("ERROR: %s" % exc)
        return EXIT_API_ERROR
    if info.get("status") != "completed":
        log("ERROR: character animation failed: %s" % json.dumps(info)[:400])
        return EXIT_API_ERROR

    rows = extract_character_frame_urls(info, args.animation_name, directions)
    prefix = args.frame_prefix or (args.animation_name + "_")
    frames = []
    starting_frame = None
    try:
        if custom_start_frame_url and starting_frame_name:
            idle_path = os.path.join(args.source_dir, starting_frame_name)
            size = download_fn(custom_start_frame_url, idle_path)
            encoded_sha256, pixel_sha256 = frame_hashes(idle_path)
            starting_frame = {
                "file": starting_frame_name,
                "direction": directions[0],
                "bytes": size,
                "url_kind": "custom_start_frame",
                "encoded_sha256": encoded_sha256,
                "pixel_sha256": pixel_sha256,
            }
        for direction in directions:
            direction_prefix = "%s%s" % (prefix, direction.replace("-", "_"))
            urls = rows.get(direction, [])
            for index, url in enumerate(urls[:args.frame_count]):
                name = "%s_%02d.png" % (direction_prefix, index)
                path = os.path.join(args.source_dir, name)
                size = download_fn(url, path)
                try:
                    encoded_sha256, pixel_sha256 = frame_hashes(path)
                except Exception as exc:  # noqa: BLE001 - corrupt downloads fail closed
                    log("ERROR: %s: downloaded frame is not a decodable image: %s" % (name, exc))
                    return EXIT_INCOMPLETE
                frames.append({
                    "file": name,
                    "direction": direction,
                    "index": index,
                    "bytes": size,
                    "url_kind": "character_direct",
                    "encoded_sha256": encoded_sha256,
                    "pixel_sha256": pixel_sha256,
                })
    except ApiError as exc:
        log("ERROR: %s" % exc)
        return EXIT_API_ERROR

    expected = len(directions) * args.frame_count
    if len(frames) != expected:
        log("ERROR: incomplete pack: downloaded %d frames, expected %d (character %s)" %
            (len(frames), expected, character_id))
        return EXIT_INCOMPLETE

    manifest = {
        "tool": "tools/pixellab_generate_pack.py",
        "tool_version": TOOL_VERSION,
        "generated_at": started,
        "encoder": encoder_provenance(),
        "character": {
            "pixel_lab_character_id": character_id,
            "animate_tool": "animate_character",
            "animate_params": animate_params,
        },
        "frames": frames,
        "frame_count": len(frames),
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
    }
    if starting_frame:
        manifest["starting_frame"] = starting_frame
    with open(args.manifest_out, "w") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    log("wrote %s with %d frames" % (args.manifest_out, len(frames)))
    return 0


def run(args, call_fn=call, download_fn=download, sleep_fn=time.sleep,
        clock=time.time, log=print):
    bearer = os.environ.get("PIXELLAB_BEARER_TOKEN")
    if not bearer:
        raise SystemExit("PIXELLAB_BEARER_TOKEN is not set (tools/pixellab.env.example)")

    os.makedirs(args.source_dir, exist_ok=True)
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    if getattr(args, "character_id", None):
        return run_character(args, bearer, started, call_fn=call_fn,
                             download_fn=download_fn, sleep_fn=sleep_fn,
                             clock=clock, log=log)

    if getattr(args, "object_id", None):
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
            path = os.path.join(args.source_dir, name)
            size = download_fn(url, path)
            try:
                encoded_sha256, pixel_sha256 = frame_hashes(path)
            except Exception as exc:  # noqa: BLE001 - a corrupt download is not a usable frame
                log("ERROR: %s: downloaded frame is not a decodable image: %s" % (name, exc))
                return EXIT_INCOMPLETE
            frames.append({
                "file": name,
                "bytes": size,
                "url_kind": url_kind,
                "encoded_sha256": encoded_sha256,
                "pixel_sha256": pixel_sha256,
            })
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
        "encoder": encoder_provenance(),
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
    parser.add_argument("--animation-description", default=None,
                        help="animation description for animate_object "
                             "(required unless --check is given)")
    parser.add_argument("--check", action="store_true",
                        help="re-validate the frames in --source-dir against "
                             "--manifest-out instead of generating a new pack")
    parser.add_argument("--object-id", default=None,
                        help="reuse an existing PixelLab object id")
    parser.add_argument("--character-id", default=None,
                        help="animate an existing PixelLab character id")
    parser.add_argument("--animation-name", default=None,
                        help="named animation group for --character-id")
    parser.add_argument("--custom-start-frame-url", default=None,
                        help="PixelLab URL for the exact starting pose of a v3 character animation")
    parser.add_argument("--starting-frame-name", default=None,
                        help="source filename for saving --custom-start-frame-url")
    parser.add_argument("--directions", nargs="+", default=None,
                        help="directions for --character-id")
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
    if args.check:
        return 0 if check_pack(args.manifest_out, args.source_dir) else EXIT_CHECK_FAILED
    if not args.character_id and not args.object_id and not args.description:
        parser.error("--description is required unless --object-id or --character-id is given")
    if not args.animation_description:
        parser.error("--animation-description is required unless --check is given")
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
