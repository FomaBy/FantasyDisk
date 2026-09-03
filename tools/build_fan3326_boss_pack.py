#!/usr/bin/env python3
"""FAN-3326: blocking PixelLab builder for the six-boss 8-direction pack.

The first five bosses are existing PixelLab 8-direction objects whose older
animation groups contain only a west row.  This builder queues only missing
directions (and a new hit group) and polls the objects synchronously.  The
secret boss is an existing PixelLab character; its complete move group is
reused and the combat groups are generated under FAN-3326 names.

The command is deliberately task-owned because the generic pack CLI can
animate one object state, but cannot merge several existing 8-direction object
groups into one deterministic six-actor SpriteFrames resource.  Generation,
polling, downloads, normalization, SpriteFrames emission, and provenance all
finish in this foreground process.

Auth is read from PIXELLAB_BEARER_TOKEN and never written to the repository.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))
from pixellab_generate_pack import ApiError, call, download, frame_hashes  # noqa: E402

ROOT = TOOLS_DIR.parent
CELL_SIZE = 512
BOTTOM_PADDING = 48
DIRECTIONS = [
    "east", "south-east", "south", "south-west",
    "west", "north-west", "north", "north-east",
]
SUFFIXES = [direction.replace("-", "_") for direction in DIRECTIONS]
TOOL_VERSION = "1.0.0"
API_TIMEOUT = 180
MAX_MISSING_GROUPS = 37
MAX_BATCH_GROUPS = 8

OBJECT_IDS = {
    "rift_warden": "ab1c7701-3ee7-4c7c-8842-22a7def87f08",
    "bone_archon": "0335a72f-9905-4a18-ba1e-e91d2a9de9bc",
    "brood_mother": "0f0db439-9b79-4b25-8951-988319c5e821",
    "ashen_colossus": "eb2bfa56-9406-4855-96e6-dc05c9272494",
    "bloodthorn_lion": "1b923d8c-e83e-48a1-970e-4681f63ead0a",
}
SECRET_CHARACTER_ID = "ce24c21f-c2d8-4801-b635-77be0edbcb6c"

CANONICAL_PROVIDER_GROUP_ALIASES = {
    (OBJECT_IDS["ashen_colossus"], "46160bb5-e182-4810-b980-b88e27a090d6"): "hit",
}

# Keep existing object frame counts; idle is the object's completed rotation
# and hit is the one new short reaction group.
OBJECT_STATES = {
    "idle": {"server_state": "__rotations__", "frames": 1, "loop": True},
    "move": {"server_state": "move", "frames": 7, "loop": True},
    "attack": {"server_state": "attack_primary", "frames": 6, "loop": False},
    "hit": {"server_state": "hit", "frames": 6, "loop": False},
    "death": {"server_state": "death", "frames": 6, "loop": False},
}

OBJECT_SKILLS = {
    "rift_warden": ["skill_gravity_well", "skill_rift_zone"],
    "bone_archon": ["skill_skull_volley", "skill_bone_prison"],
    "brood_mother": ["skill_brood_spawn", "skill_web_zone"],
    "ashen_colossus": ["skill_molten_slam", "skill_armor_pulse"],
    "bloodthorn_lion": ["skill_spike_ring", "skill_rift_zone"],
}

TARGET_VISIBLE_HEIGHT = {
    "rift_warden": 236,
    "bone_archon": 228,
    "brood_mother": 216,
    "ashen_colossus": 229,
    "bloodthorn_lion": 236,
    "secret_ascension_boss": 423,
}

OBJECT_PROMPTS = {
    "rift_warden": {
        "move": "floating rift warden advances with slow powerful weight shifts, torn shadow cloak sways, black-hole core pulses, seamless locomotion loop",
        "attack": "casts paired rift bolts from both hands, cloak flares, purple black-hole core pulses, arms recoil after the shot",
        "hit": "briefly recoils from a heavy hit, armor and shadow cloak jolt, black-hole core flickers, then returns to stance",
        "death": "epic boss death: staggers, black-hole core collapses inward, cloak tears into shadow, armor cracks and fades",
        "skill_gravity_well": "summons a purple gravity well, arms raise, vortex expands from the chest, cloak and horns pull toward the singularity",
        "skill_rift_zone": "opens jagged rift fissures, sweeping occult casting gesture, purple void cracks spread beneath the floating warlock knight",
    },
    "bone_archon": {
        "move": "crowned skeletal lich walks with deliberate heavy steps, robes and bone ornaments sway, green soul fire breathes in a seamless loop",
        "attack": "crowned skeletal lich fires a skull volley, bone crown and robes snap with the casting motion, green soul light pulses",
        "hit": "skeletal archon reels from impact, crown and ribcage jolt, soul fire flickers, then settles back into the combat stance",
        "death": "epic lich death: crown breaks, bones collapse into a heap, green soul fire escapes and fades",
        "skill_skull_volley": "launches a spread of spectral skulls, both arms sweep outward, crown and soul fire flare during the cast",
        "skill_bone_prison": "raises a ring of jagged bones from the ground, hands pull upward, green magic coils around the skeleton",
    },
    "brood_mother": {
        "move": "massive armored arachnid advances with weighty leg cycles, abdomen and web glands sway, deliberate readable boss locomotion loop",
        "attack": "massive armored arachnid lunges with a snapping bite, front legs drive forward, egg sac and web glands sway",
        "hit": "brood queen recoils from impact, legs and armored abdomen jolt, web glands twitch, then she regains her stance",
        "death": "epic spider queen death: legs buckle, armored body collapses, egg sac ruptures into fading dark motes",
        "skill_brood_spawn": "raises her abdomen and releases a brood, legs brace wide, egg sac pulses, small eggs drop in a deliberate cast",
        "skill_web_zone": "spins a sticky web zone, front legs sweep in a circle, web glands pulse and strands spread across the ground",
    },
    "ashen_colossus": {
        "move": "cracked obsidian lava giant lumbers with slow powerful weight shifts, ember cracks pulse, shoulders and fists move in a seamless loop",
        "attack": "cracked obsidian lava giant swings a colossal fist, ember cracks brighten, shoulders and molten core follow through",
        "hit": "molten stone colossus absorbs a blow, shoulders and ember cracks jolt, loose ash shakes free, then it steadies",
        "death": "epic lava giant death: staggers, cracks spread, armor breaks apart into embers and an ashen heap",
        "skill_molten_slam": "raises one massive fist and slams the ground, lava cracks flare outward, ash and embers lift on impact",
        "skill_armor_pulse": "molten armor pulse: chest core brightens, plates expand and contract, ember cracks ripple over the giant",
    },
    "bloodthorn_lion": {
        "move": "huge dark-fantasy lion prowls with a strong readable gait, crimson thorn mane sways, claws and black hide move in a seamless loop",
        "attack": "huge dark-fantasy lion pounces, crimson thorn mane whips around the head, claws extend and black hide follows through",
        "hit": "thorn-maned lion recoils from impact, mane and crystal spikes jolt, claws scrape back into a guarded stance",
        "death": "epic thorn lion death: pounce falters, mane wilts, black hide collapses and crimson crystals dim",
        "skill_spike_ring": "roars and drives thorn crystals into a ring around itself, mane flares, blood-red spikes erupt from the ground",
        "skill_rift_zone": "slashes open bleeding fissures in the ground, crimson thorns and dark rift energy spread from the lion's paws",
    },
}

SECRET_STATE_NAMES = {
    "idle": "fan3326_idle",
    "attack": "fan3326_attack",
    "hit": "fan3326_hit",
    "death": "fan3326_death",
    "skill_ring": "fan3326_skill_ring",
    "skill_cone": "fan3326_skill_cone",
    "skill_beam": "fan3326_skill_beam",
    "skill_rupture": "fan3326_skill_rupture",
}
SECRET_STATES = {
    "idle": {"server_state": SECRET_STATE_NAMES["idle"], "frames": 6, "loop": True},
    "move": {"server_state": "move", "frames": 6, "loop": True},
    "attack": {"server_state": SECRET_STATE_NAMES["attack"], "frames": 6, "loop": False},
    "hit": {"server_state": SECRET_STATE_NAMES["hit"], "frames": 6, "loop": False},
    "death": {"server_state": SECRET_STATE_NAMES["death"], "frames": 6, "loop": False},
    "skill_ring": {"server_state": SECRET_STATE_NAMES["skill_ring"], "frames": 6, "loop": False},
    "skill_cone": {"server_state": SECRET_STATE_NAMES["skill_cone"], "frames": 6, "loop": False},
    "skill_beam": {"server_state": SECRET_STATE_NAMES["skill_beam"], "frames": 6, "loop": False},
    "skill_rupture": {"server_state": SECRET_STATE_NAMES["skill_rupture"], "frames": 6, "loop": False},
}
SECRET_PROMPTS = {
    "fan3326_idle": "breathing idle for the secret ascension boss, subtle crown and void aura motion, maintain the exact silhouette and palette",
    "fan3326_attack": "secret ascension boss performs a powerful primary cast, arms open, void crown and aura flare, then recoil into stance",
    "fan3326_hit": "secret ascension boss briefly recoils from a heavy hit, aura flickers and crown jolts, then returns to stance",
    "fan3326_death": "epic secret ascension boss death, aura collapses, crown breaks into motes, body sinks and the void light fades",
    "fan3326_skill_ring": "secret ascension boss casts a circular sector ring, hands draw a circle, violet aura expands, then settles",
    "fan3326_skill_cone": "secret ascension boss casts a directional cone, turns toward the aim, raises one hand and releases a focused void flare",
    "fan3326_skill_beam": "secret ascension boss casts a directional beam, braces, channels a bright void lance, then releases the tension",
    "fan3326_skill_rupture": "secret ascension boss tears open ground fissures, arms pull apart, violet cracks flare and void motes rise",
}

TIMING = {
    "idle": (1.0, True), "move": (9.0, True), "attack": (12.0, False),
    "attack_primary": (12.0, False), "attack_primary_windup": (12.0, False),
    "attack_primary_release": (12.0, False), "hit": (10.0, False),
    "death": (10.0, False),
}


class BuildError(RuntimeError):
    pass


def parse_report(raw: str, asset_id: str | None = None) -> dict[str, Any]:
    """Parse the stable text report emitted by get_object/get_character."""
    result: dict[str, Any] = {"status": None, "animations": {}, "rotations": {}}
    current: dict[str, Any] | None = None
    header = re.compile(
        r"^  (?P<label>.+?)\s+\[group: "
        r"(?P<group_id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]$",
        re.IGNORECASE,
    )
    for line in raw.splitlines():
        stripped = line.strip()
        if stripped.startswith("status:"):
            result["status"] = stripped.split(":", 1)[1].strip()
            continue
        if stripped == "rotations:":
            current = None
            continue
        if line.startswith("  ") and not line.startswith("    "):
            match = header.match(line)
            if match:
                display_label = match.group("label").strip()
                group_id = match.group("group_id").lower()
                name = CANONICAL_PROVIDER_GROUP_ALIASES.get(
                    (asset_id, group_id), display_label.split(" — ", 1)[0]
                )
                inline_frames = re.search(r"(\d+)f\b", line)
                current = {
                    "group_id": group_id,
                    "frame_count": int(inline_frames.group(1)) if inline_frames else None,
                    "directions": {},
                }
                result["animations"][name] = current
                continue
            if stripped and stripped.startswith("directions:"):
                continue
            if stripped.startswith("status:"):
                continue
        if current is None:
            if line.startswith("  ") and not line.startswith("    "):
                match = re.match(r"^  ([a-z-]+): (https?://\S+)$", line)
                if match:
                    result["rotations"][match.group(1)] = match.group(2)
            continue
        frame_count = re.match(r"^    frames: (\d+)$", line)
        if frame_count:
            current["frame_count"] = int(frame_count.group(1))
            continue
        direction = re.match(r"^    ([a-z-]+): (.+)$", line)
        if direction:
            name, blob = direction.groups()
            if name not in DIRECTIONS:
                continue
            urls = re.findall(r"https?://[^,\s]+", blob)
            range_match = re.search(r"\(i=0\.\.(\d+)\)", blob)
            if range_match and len(urls) == 1 and "{i}" in urls[0]:
                urls = [urls[0].replace("{i}", str(index)) for index in range(int(range_match.group(1)) + 1)]
            current["directions"][name] = urls
    return result


def read_auth() -> str:
    token = os.environ.get("PIXELLAB_BEARER_TOKEN", "").strip()
    if token:
        return token
    header = os.environ.get("AUTH_HEADER", "").strip()
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    config_path = Path.home() / ".codex" / "config.toml"
    if config_path.exists():
        text = config_path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r'^\s*AUTH_HEADER\s*=\s*"Bearer\s+([^"\s]+)"\s*$', text, re.MULTILINE | re.IGNORECASE)
        if match:
            return match.group(1)
    # Some local Codex launches expose the MCP secret under this name.  It is
    # accepted only as the final fallback and is never printed or persisted.
    secret = os.environ.get("PIXELLAB_SECRET", "").strip()
    if secret:
        return secret
    raise BuildError("no PixelLab bearer auth found")


def get_report(tool: str, asset_id: str, bearer: str, call_id: int) -> dict[str, Any]:
    response = call(tool, {"%s_id" % ("object" if tool == "get_object" else "character"): asset_id, "include_preview": False}, bearer, call_id)
    raw = response.get("_raw") if isinstance(response, dict) else None
    if not raw:
        raise BuildError("%s returned no text report" % tool)
    return parse_report(raw, asset_id=asset_id)


def expand_urls(urls: list[str], frame_count: int) -> list[str]:
    if len(urls) == 1 and "{i}" in urls[0]:
        return [urls[0].replace("{i}", str(index)) for index in range(frame_count)]
    return urls[:frame_count]


def effective_frame_count(group: dict[str, Any] | None, spec: dict[str, Any]) -> int:
    """Use the canonical state frame count; provider rows may contain surplus frames."""
    return int(spec["frames"])


def request_frame_count(frame_count: int) -> int:
    """PixelLab v3 accepts only an even frame count in 4..16.

    The canonical pack still consumes ``frame_count`` frames per row; the
    provider row simply carries one surplus frame, which ``expand_urls``
    already tolerates.  Before this rounding the server answered an odd
    request with a plain-text error and the builder logged it as
    ``jobs=unreported`` while polling forever (FAN-3854, 2026-09-03).
    """
    return max(4, min(16, frame_count + (frame_count % 2)))


def assert_queued(response: Any, label: str) -> None:
    """The MCP tool reports a rejected request as text, not as a JSON-RPC error."""
    text = response.get("_raw", "") if isinstance(response, dict) else ""
    if text.lstrip().lower().startswith("error"):
        raise BuildError("PixelLab rejected %s: %s" % (label, text.strip()[:200]))


SLOT_WAIT_SECONDS = 1800
SLOT_POLL_SECONDS = 30


def slots_exhausted(response: Any) -> bool:
    """``error: need N slots but only M available (x/20 active)`` — a transient cap, not a rejection."""
    text = response.get("_raw", "") if isinstance(response, dict) else ""
    return text.lstrip().lower().startswith("error") and "slots" in text and "available" in text


def call_when_slots_free(tool: str, params: dict[str, Any], bearer: str, call_id: int, label: str, log=print) -> Any:
    """Submit one animation group, waiting for PixelLab concurrency slots to free up.

    The account has a fixed number of concurrent generation slots; a full pack
    queues far more direction jobs than that, so a burst submission fails
    mid-way.  Waiting here keeps the run synchronous and fail-closed on every
    other error.
    """
    deadline = time.time() + SLOT_WAIT_SECONDS
    while True:
        response = call(tool, params, bearer, call_id)
        if not slots_exhausted(response):
            assert_queued(response, label)
            return response
        if time.time() >= deadline:
            raise BuildError("PixelLab slots did not free up within %ss for %s" % (SLOT_WAIT_SECONDS, label))
        log("slots busy for %s; waiting %ss" % (label, SLOT_POLL_SECONDS))
        time.sleep(SLOT_POLL_SECONDS)


def missing_directions(group: dict[str, Any] | None, spec: dict[str, Any]) -> tuple[int, list[str]]:
    frame_count = effective_frame_count(group, spec)
    if not group:
        return frame_count, list(DIRECTIONS)
    directions = group.get("directions", {})
    missing = [
        direction for direction in DIRECTIONS
        if len(expand_urls(directions.get(direction, []), frame_count)) != frame_count
    ]
    return frame_count, missing


def queue_missing(bearer: str, batch_boss: str | None = None, log=print) -> None:
    call_id = 100
    queued_groups = 0
    group_cap = MAX_BATCH_GROUPS if batch_boss else MAX_MISSING_GROUPS
    for boss_id, object_id in OBJECT_IDS.items():
        if batch_boss and batch_boss != boss_id:
            continue
        report = get_report("get_object", object_id, bearer, call_id)
        call_id += 1
        missing_states = dict(OBJECT_STATES)
        for skill in OBJECT_SKILLS[boss_id]:
            missing_states[skill] = {"server_state": skill, "frames": 6, "loop": False}
        for state, spec in missing_states.items():
            if state == "idle":
                continue
            server_state = spec["server_state"]
            group = report["animations"].get(server_state)
            frame_count, missing = missing_directions(group, spec)
            if not missing:
                continue
            queued_groups += 1
            if queued_groups > group_cap:
                raise BuildError("missing group cap exceeded: %d > %d" % (queued_groups, group_cap))
            # Rows can land while an earlier group waited for slots; re-read the
            # live report so finished directions are never requested twice.
            report = get_report("get_object", object_id, bearer, call_id)
            call_id += 1
            group = report["animations"].get(server_state)
            frame_count, missing = missing_directions(group, spec)
            if not missing:
                queued_groups -= 1
                continue
            params: dict[str, Any] = {
                "object_id": object_id,
                "mode": "v3",
                "directions": missing,
                "frame_count": request_frame_count(frame_count),
                "animation_description": OBJECT_PROMPTS[boss_id][state],
            }
            if group:
                params["animation_group_id"] = group["group_id"]
                if any(direction in group["directions"] for direction in missing):
                    params["replace_existing"] = True
            else:
                params["display_name"] = server_state
            response = call_when_slots_free("animate_object", params, bearer, call_id, "%s/%s" % (boss_id, state), log)
            call_id += 1
            log("queued %s %s: %s %s" % (boss_id, state, ",".join(missing), job_ids(response)))

    if not batch_boss or batch_boss == "secret_ascension_boss":
        report = get_report("get_character", SECRET_CHARACTER_ID, bearer, call_id)
        call_id += 1
        for canonical, spec in SECRET_STATES.items():
            server_state = spec["server_state"]
            group = report["animations"].get(server_state)
            frame_count, missing = missing_directions(group, spec)
            if not missing:
                continue
            queued_groups += 1
            if queued_groups > group_cap:
                raise BuildError("missing group cap exceeded: %d > %d" % (queued_groups, group_cap))
            params = {
                "character_id": SECRET_CHARACTER_ID,
                "mode": "v3",
                "directions": missing,
                "frame_count": request_frame_count(frame_count),
                "animation_name": server_state,
                "action_description": SECRET_PROMPTS[server_state],
            }
            if group:
                params["animation_group_id"] = group["group_id"]
                if any(direction in group["directions"] for direction in missing):
                    params["replace_existing"] = True
            response = call_when_slots_free("animate_character", params, bearer, call_id, "secret_ascension_boss/%s" % canonical, log)
            call_id += 1
            log("queued secret %s: %s %s" % (canonical, ",".join(missing), job_ids(response)))
    if batch_boss and queued_groups == 0:
        raise BuildError("no pending groups remain for batch boss %s" % batch_boss)
    log("queued missing groups: %d/%d" % (queued_groups, group_cap))


def job_ids(response: Any) -> str:
    """Return only UUID-shaped job ids for concise, non-secret provenance logs."""
    text = json.dumps(response, ensure_ascii=False)
    ids = sorted(set(re.findall(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text, re.IGNORECASE)))
    return "jobs=" + (",".join(ids) if ids else "unreported")


def active_job_count(bearer: str, call_id: int) -> int | None:
    """Number of queued/processing PixelLab jobs, or None when the list is unreadable."""
    response = call("list_jobs", {}, bearer, call_id)
    text = response.get("_raw", "") if isinstance(response, dict) else ""
    match = re.match(r"\s*(\d+) jobs", text)
    return int(match.group(1)) if match else None


IDLE_POLLS_BEFORE_FAILURE = 2


def wait_for_pack(bearer: str, timeout: float, interval: float, batch_boss: str | None = None, log=print) -> tuple[dict[str, dict[str, Any]], dict[str, Any] | None]:
    deadline = time.time() + timeout
    call_id = 1000
    idle_polls = 0
    while True:
        objects: dict[str, dict[str, Any]] = {}
        complete = True
        missing_report: list[str] = []
        for boss_id, object_id in OBJECT_IDS.items():
            if batch_boss and batch_boss != boss_id:
                continue
            report = get_report("get_object", object_id, bearer, call_id)
            call_id += 1
            objects[boss_id] = report
            required = dict(OBJECT_STATES)
            for skill in OBJECT_SKILLS[boss_id]:
                required[skill] = {"server_state": skill, "frames": 6}
            if report["status"] == "failed":
                raise BuildError("PixelLab object failed: %s" % boss_id)
            for state, spec in required.items():
                if state == "idle":
                    continue
                group = report["animations"].get(spec["server_state"])
                frame_count = effective_frame_count(group, spec)
                if not group or any(
                    len(expand_urls(group["directions"].get(direction, []), frame_count)) != frame_count
                    for direction in DIRECTIONS
                ):
                    complete = False
                    missing_report.append("%s/%s" % (boss_id, state))

        secret = None
        if not batch_boss or batch_boss == "secret_ascension_boss":
            secret = get_report("get_character", SECRET_CHARACTER_ID, bearer, call_id)
            call_id += 1
            if secret["status"] == "failed":
                raise BuildError("PixelLab character failed: secret_ascension_boss")
            for canonical, spec in SECRET_STATES.items():
                group = secret["animations"].get(spec["server_state"])
                frame_count = effective_frame_count(group, spec)
                if not group or any(
                    len(expand_urls(group["directions"].get(direction, []), frame_count)) != frame_count
                    for direction in DIRECTIONS
                ):
                    complete = False
                    missing_report.append("secret_ascension_boss/%s" % canonical)

        elapsed = int(timeout - max(0.0, deadline - time.time()))
        log("poll t=%ss pending=%s" % (elapsed, ", ".join(missing_report[:12]) or "none"))
        if complete:
            return objects, secret
        if time.time() >= deadline:
            raise TimeoutError("PixelLab pack timed out after %ss: %s" % (timeout, ", ".join(missing_report)))
        # A direction job can fail server-side without touching the object
        # status; the group then never completes.  Fail fast instead of
        # waiting for the timeout: a rerun requeues exactly the missing rows.
        active = active_job_count(bearer, call_id)
        call_id += 1
        idle_polls = idle_polls + 1 if active == 0 else 0
        if idle_polls >= IDLE_POLLS_BEFORE_FAILURE:
            raise BuildError(
                "PixelLab has no active jobs but rows are still missing (a job failed); rerun to requeue: %s"
                % ", ".join(missing_report)
            )
        time.sleep(interval)


def alpha_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def normalize_row(source_paths: list[Path], runtime_paths: list[Path], target_height: int) -> list[dict[str, Any]]:
    max_width = 0
    max_height = 0
    for source_path in source_paths:
        with Image.open(source_path) as image:
            bbox = alpha_bbox(image.convert("RGBA"))
        if bbox is None:
            raise BuildError("%s has no visible pixels" % source_path)
        max_width = max(max_width, bbox[2] - bbox[0])
        max_height = max(max_height, bbox[3] - bbox[1])
    scale = min(target_height / float(max_height), CELL_SIZE / float(max_width))
    reports = []
    for source_path, runtime_path in zip(source_paths, runtime_paths):
        with Image.open(source_path) as opened:
            image = opened.convert("RGBA")
        bbox = alpha_bbox(image)
        if bbox is None:
            raise BuildError("%s has no visible pixels" % source_path)
        width = max(1, round((bbox[2] - bbox[0]) * scale))
        height = max(1, round((bbox[3] - bbox[1]) * scale))
        cropped = image.crop(bbox).resize((width, height), Image.Resampling.NEAREST)
        x = round((CELL_SIZE - width) / 2.0)
        y = CELL_SIZE - BOTTOM_PADDING - height
        if x < 0 or y < 0 or x + width > CELL_SIZE or y + height > CELL_SIZE:
            raise BuildError("%s normalized outside %sx%s canvas" % (source_path, width, height))
        canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(cropped, (x, y))
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(runtime_path, format="PNG")
        reports.append({"source": source_path.name, "runtime": runtime_path.name, "scale": scale, "visible_size": [width, height]})
    return reports


def frame_block(resource_ids: list[str], speed: float, loop: bool, name: str) -> str:
    frames = ",\n".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid for rid in resource_ids)
    return "{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %s\n}" % (frames, "true" if loop else "false", name, speed)


def write_spriteframes(actor_id: str, rows: dict[str, dict[str, list[Path]]]) -> None:
    resource_ids: dict[str, str] = {}
    ext_lines: list[str] = []
    blocks: list[str] = []
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resource_ids:
            return resource_ids[key]
        rid = "%d_%s" % (next_id, actor_id)
        next_id += 1
        rel = path.relative_to(ROOT).as_posix()
        ext_lines.append('[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (rel, rid))
        resource_ids[key] = rid
        return rid

    for state, direction_rows in rows.items():
        speed, loop = TIMING.get(state, (10.0, False))
        for direction in DIRECTIONS:
            paths = direction_rows[direction]
            blocks.append(frame_block([add_resource(path) for path in paths], speed, loop, "%s_%s" % (state, direction.replace("-", "_"))))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(ext_lines) + '\n\n[resource]\nanimations = [\n' + ",\n".join(blocks) + "\n]\n"
    destination = ROOT / ("assets/sprites/bosses/full_frame/%s_spriteframes.tres" % actor_id)
    destination.write_text(text, encoding="utf-8")


def source_path(actor_id: str, state: str, direction: str, index: int) -> Path:
    directory = ROOT / ("assets/sprites/bosses/%s_8dir/pixellab_source" % actor_id) / state
    suffix = direction.replace("-", "_")
    filename = "%s_%s_%s_%02d.png" % (actor_id, state, suffix, index)
    return directory / filename


def runtime_path(actor_id: str, state: str, direction: str, index: int) -> Path:
    directory = ROOT / ("assets/sprites/bosses/%s_8dir/runtime" % actor_id)
    suffix = direction.replace("-", "_")
    filename = "%s_%s_%s_%02d.png" % (actor_id, state, suffix, index)
    return directory / filename


def download_source(actor_id: str, state: str, report_group: dict[str, Any], target_frames: int, source_kind: str, bearer: str, call_id: int, log=print) -> tuple[dict[str, list[Path]], int]:
    rows: dict[str, list[Path]] = {}
    for direction in DIRECTIONS:
        urls = expand_urls(report_group["directions"].get(direction, []), target_frames)
        if len(urls) != target_frames:
            raise BuildError("%s/%s/%s has %d URLs, expected %d" % (actor_id, state, direction, len(urls), target_frames))
        paths = []
        for index, url in enumerate(urls):
            destination = source_path(actor_id, state, direction, index)
            destination.parent.mkdir(parents=True, exist_ok=True)
            download(url, str(destination))
            with Image.open(destination) as image:
                if image.width < 1 or image.height < 1 or alpha_bbox(image.convert("RGBA")) is None:
                    raise BuildError("%s is not a visible transparent PNG" % destination)
            paths.append(destination)
            call_id += 1
        rows[direction] = paths
        log("downloaded %s %s (%d frames)" % (actor_id, state, target_frames))
    return rows, call_id


def write_manifest(manifest: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def build_actor(actor_id: str, source_kind: str, asset_id: str, report: dict[str, Any], state_specs: dict[str, dict[str, Any]], aliases: dict[str, str], bearer: str, call_id: int, log=print) -> tuple[dict[str, Any], int]:
    source_root = ROOT / ("assets/sprites/bosses/%s_8dir/pixellab_source" % actor_id)
    runtime_root = ROOT / ("assets/sprites/bosses/%s_8dir/runtime" % actor_id)
    source_root.mkdir(parents=True, exist_ok=True)
    runtime_root.mkdir(parents=True, exist_ok=True)
    source_rows: dict[str, dict[str, list[Path]]] = {}
    state_records: dict[str, Any] = {}
    for canonical, spec in state_specs.items():
        if spec["server_state"] == "__rotations__":
            group = {"group_id": "rotations", "frame_count": 1, "directions": {direction: [url] for direction, url in report["rotations"].items()}}
        else:
            group = report["animations"].get(spec["server_state"])
            if not group:
                raise BuildError("%s missing PixelLab state %s" % (actor_id, spec["server_state"]))
        target_frames = effective_frame_count(group, spec)
        rows, call_id = download_source(actor_id, canonical, group, target_frames, source_kind, bearer, call_id, log)
        source_rows[canonical] = rows
        state_records[canonical] = {
            "pixel_lab_state": spec["server_state"],
            "pixel_lab_group_id": group["group_id"],
            "frame_count": target_frames,
            "directions": DIRECTIONS,
        }

    runtime_rows: dict[str, dict[str, list[Path]]] = {}
    runtime_records: list[dict[str, Any]] = []
    for canonical, rows in source_rows.items():
        runtime_rows[canonical] = {}
        target_height = TARGET_VISIBLE_HEIGHT[actor_id]
        for direction in DIRECTIONS:
            paths = rows[direction]
            destinations = [runtime_path(actor_id, canonical, direction, index) for index in range(len(paths))]
            reports = normalize_row(paths, destinations, target_height)
            runtime_rows[canonical][direction] = destinations
            state_records[canonical]["runtime_normalization"] = reports
            for source_path_item, runtime_path_item in zip(paths, destinations):
                source_encoded, source_pixels = frame_hashes(source_path_item)
                runtime_encoded, runtime_pixels = frame_hashes(runtime_path_item)
                runtime_records.append({
                    "state": canonical,
                    "direction": direction,
                    "index": len([entry for entry in runtime_records if entry["state"] == canonical and entry["direction"] == direction]),
                    "source_file": str(source_path_item.relative_to(source_root).as_posix()),
                    "runtime_file": str(runtime_path_item.relative_to(runtime_root).as_posix()),
                    "source_encoded_sha256": source_encoded,
                    "source_pixel_sha256": source_pixels,
                    "runtime_encoded_sha256": runtime_encoded,
                    "runtime_pixel_sha256": runtime_pixels,
                })

    # Preserve every state name already consumed by boss presentation code.
    all_rows = dict(runtime_rows)
    for alias, canonical in aliases.items():
        all_rows[alias] = runtime_rows[canonical]
    write_spriteframes(actor_id, all_rows)
    manifest = {
        "issue": "FAN-3326",
        "actor_id": actor_id,
        "tool": "tools/build_fan3326_boss_pack.py",
        "tool_version": TOOL_VERSION,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "pixel_lab": {"kind": source_kind, "asset_id": asset_id},
        "runtime_canvas": [CELL_SIZE, CELL_SIZE],
        "bottom_padding": BOTTOM_PADDING,
        "target_visible_height": TARGET_VISIBLE_HEIGHT[actor_id],
        "directions": DIRECTIONS,
        "states": state_records,
        "aliases": aliases,
        "spriteframes": "res://assets/sprites/bosses/full_frame/%s_spriteframes.tres" % actor_id,
        "frames": runtime_records,
        "auth": "PIXELLAB_BEARER_TOKEN env (never committed)",
        "encoder": {"library": "Pillow", "library_version": Image.__version__, "resampling": "NEAREST"},
    }
    write_manifest(manifest, source_root / "manifest.json")
    return manifest, call_id


def actor_specs() -> list[tuple[str, str, str, dict[str, dict[str, Any]], dict[str, str]]]:
    result = []
    for actor_id, object_id in OBJECT_IDS.items():
        states = dict(OBJECT_STATES)
        for skill in OBJECT_SKILLS[actor_id]:
            states[skill] = {"server_state": skill, "frames": 6, "loop": False}
        aliases = {"attack_primary": "attack"}
        for skill in OBJECT_SKILLS[actor_id]:
            aliases["attack_%s" % skill.removeprefix("skill_")] = skill
        result.append((actor_id, "object", object_id, states, aliases))
    secret_aliases = {
        "attack_primary": "attack", "attack_primary_windup": "attack", "attack_primary_release": "attack",
        "attack_ring": "skill_ring", "attack_cone": "skill_cone", "attack_beam": "skill_beam", "attack_rupture": "skill_rupture",
        "skill_rift_zone": "skill_ring", "attack_rift_zone": "skill_ring", "skill_molten_slam": "attack",
    }
    result.append(("secret_ascension_boss", "character", SECRET_CHARACTER_ID, SECRET_STATES, secret_aliases))
    return result


def read_manifest(path: Path) -> dict[str, Any] | None:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print("FAIL: %s: cannot read manifest (%s)" % (path, exc))
        return None
    if (
        not isinstance(manifest, dict)
        or not isinstance(manifest.get("frames"), list)
        or not manifest["frames"]
        or not isinstance(manifest.get("states"), dict)
        or not manifest["states"]
        or any(not isinstance(frame, dict) for frame in manifest["frames"])
    ):
        print("FAIL: %s: malformed manifest (expected non-empty frames/states)" % path)
        return None
    return manifest


def check_manifest(path: Path) -> bool:
    manifest = read_manifest(path)
    if manifest is None:
        return False
    ok = True
    for frame in manifest["frames"]:
        if not isinstance(frame, dict) or any(
            not isinstance(frame.get(field), str) for field in (
                "state", "direction", "source_file", "runtime_file", "source_encoded_sha256",
                "source_pixel_sha256", "runtime_encoded_sha256", "runtime_pixel_sha256",
            )
        ) or not isinstance(frame.get("index"), int):
            print("FAIL: %s: malformed frame entry" % path)
            ok = False
            continue
        source = path.parent / frame["source_file"]
        actor_id = path.parent.parent.name.removesuffix("_8dir")
        runtime = ROOT / "assets/sprites/bosses" / (actor_id + "_8dir") / "runtime" / frame["runtime_file"]
        if not source.exists() or not runtime.exists():
            print("FAIL: missing %s or %s" % (source, runtime))
            ok = False
            continue
        try:
            source_encoded, source_pixels = frame_hashes(source)
            runtime_encoded, runtime_pixels = frame_hashes(runtime)
        except Exception as exc:  # noqa: BLE001
            print("FAIL: image decode: %s" % exc)
            ok = False
            continue
        for actual, expected, label in [
            (source_encoded, frame["source_encoded_sha256"], "source bytes"),
            (source_pixels, frame["source_pixel_sha256"], "source pixels"),
            (runtime_encoded, frame["runtime_encoded_sha256"], "runtime bytes"),
            (runtime_pixels, frame["runtime_pixel_sha256"], "runtime pixels"),
        ]:
            if actual != expected:
                print("FAIL: %s %s drifted" % (frame["runtime_file"], label))
                ok = False
    print("check %s: %d frames" % ("passed" if ok else "failed", len(manifest.get("frames", []))))
    return ok


def rebuild_manifest(path: Path) -> bool:
    manifest = read_manifest(path)
    if manifest is None:
        return False
    try:
        actor_id = path.parent.parent.name.removesuffix("_8dir")
        runtime_root = ROOT / ("assets/sprites/bosses/%s_8dir/runtime" % actor_id)
        source_root = path.parent
        rows: dict[str, dict[str, list[Path]]] = {}
        for state in manifest["states"]:
            rows[state] = {}
            for direction in DIRECTIONS:
                entries = [
                    entry for entry in manifest["frames"]
                    if entry.get("state") == state and entry.get("direction") == direction
                ]
                entries.sort(key=lambda entry: entry.get("index", -1))
                if not entries or any("runtime_file" not in entry for entry in entries):
                    print("FAIL: %s: missing %s/%s frame entries" % (path, state, direction))
                    return False
                rows[state][direction] = [runtime_root / entry["runtime_file"] for entry in entries]
        all_rows = dict(rows)
        for alias, canonical in manifest.get("aliases", {}).items():
            if canonical not in rows:
                print("FAIL: %s: alias %s references missing state %s" % (path, alias, canonical))
                return False
            all_rows[alias] = rows[canonical]
        write_spriteframes(actor_id, all_rows)
        return check_manifest(path)
    except (AttributeError, KeyError, TypeError, ValueError, OSError) as exc:
        print("FAIL: %s: cannot rebuild manifest (%s)" % (path, exc))
        return False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="FAN-3326 blocking six-boss PixelLab pack builder")
    parser.add_argument("--timeout", type=float, default=900.0)
    parser.add_argument("--poll-interval", type=float, default=30.0)
    parser.add_argument("--resume", action="store_true", help="poll already queued PixelLab jobs without submitting duplicates")
    parser.add_argument("--batch-boss", choices=[*OBJECT_IDS, "secret_ascension_boss"], help="queue and harvest only one boss (max 8 pending groups)")
    parser.add_argument("--check", action="store_true", help="verify all six manifests and runtime bytes offline")
    parser.add_argument("--rebuild", action="store_true", help="rebuild SpriteFrames from tracked source/runtime manifests offline")
    args = parser.parse_args(argv)

    manifests = [ROOT / ("assets/sprites/bosses/%s_8dir/pixellab_source/manifest.json" % actor_id) for actor_id, *_ in actor_specs()]
    if args.check or args.rebuild:
        results = [rebuild_manifest(path) if args.rebuild else check_manifest(path) for path in manifests]
        return 0 if all(results) else 6

    try:
        bearer = read_auth()
        if not args.resume:
            queue_missing(bearer, args.batch_boss)
        object_reports, secret_report = wait_for_pack(bearer, args.timeout, args.poll_interval, args.batch_boss)
        call_id = 5000
        actors = actor_specs()
        if args.batch_boss:
            actors = [actor for actor in actors if actor[0] == args.batch_boss]
        for actor_id, source_kind, asset_id, states, aliases in actors:
            report = secret_report if source_kind == "character" else object_reports[actor_id]
            build_actor(actor_id, source_kind, asset_id, report, states, aliases, bearer, call_id)
            print("built %s" % actor_id)
        if args.batch_boss:
            print("FAN-3326 PixelLab boss batch PASS: %s, eight directions, deterministic runtime emitted" % args.batch_boss)
        else:
            print("FAN-3326 PixelLab boss pack PASS: six actors, eight directions, deterministic runtime emitted")
        return 0
    except TimeoutError as exc:
        print("TIMEOUT: %s" % exc, file=sys.stderr)
        return 3
    except (ApiError, BuildError, OSError) as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
