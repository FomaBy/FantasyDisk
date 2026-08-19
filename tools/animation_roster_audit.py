#!/usr/bin/env python3
"""FAN-2518 — recursive roster/frame audit of runtime animation packs.

Replaces the shallow "top-level PNG" pass of sprite_quality_audit.py for actor
packs: this tool walks every runtime actor's SpriteFrames resource recursively
(ext_resource -> PNG -> .import sidecar), inspects each animation frame, and
reports:

  - stray alpha islands / dirty specks (same rule as sprite_quality_audit);
  - crop problems: empty frames, oversized uniform borders, canvas over-crop;
  - pivot drift: opaque-bbox center wandering inside a constant canvas;
  - dimension mismatches inside one animation;
  - missing states/directions per actor kind (via the runtime alias table);
  - loop discontinuities (last->first jump vs neighbour diffs);
  - duplicate or misconfigured animations (speed <= 0, missing import).

It also renders one contact sheet per actor and writes the canonical roster
manifest (data/meta/animation_roster_manifest.json) that the in-game gallery
(tools/animation_gallery.gd) consumes. Audit outputs are report-only; nothing
is auto-fixed.

Usage:
  python3 tools/animation_roster_audit.py            # full audit + sheets
  python3 tools/animation_roster_audit.py --no-sheets
  python3 tools/animation_roster_audit.py --check    # exit 1 on any finding

Outputs: build/animation_audit/{audit_report.json,audit_report.md,
                                contact_sheets/<actor_id>.png}
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "data" / "meta" / "animation_roster_manifest.json"
OUT_DIR = ROOT / "build" / "animation_audit"
SHEET_DIR = OUT_DIR / "contact_sheets"

CH = "assets/sprites/characters"
EN = "assets/sprites/enemies/full_frame"
EL = "assets/sprites/elites/full_frame"
BO = "assets/sprites/bosses/full_frame"
AL = "assets/sprites/allies"

# Canonical live roster (FAN-2518). Sources of truth:
#   heroes          scripts/player.gd _character_resource_sprite_frames
#                   (res://assets/sprites/characters/<id>_spriteframes.tres)
#   enemies/elites  scripts/full_frame_animation_registry.gd FULL_FRAME_SPRITEFRAMES
#   mini-elites     scripts/progression_data_enemies.gd MINI_ELITE_KINDS;
#                   the four tint-only kinds fall back to the base elite pack
#                   of their "behavior" — listed explicitly, never hidden
#   bosses          registry "boss" + scenes/BossSecretAscension.tscn meta path
#   druid summons   registry "ally" ghost_* entries
#   homunculi       scripts/ally_minion.gd homunculus_tank / homunculus_caster;
#                   both play the shared ally homunculus pack
MINI_ELITE_FALLBACK = {
    "mini_siege_rammer": "iron_bastion",
    "mini_swarm_sniper": "shard_marshal",
    "mini_plague_berserker": "plague_prophet",
    "mini_void_phantom": "night_stalker",
}

ROSTER = (
    [{"id": h, "group": "hero", "frames": f"{CH}/{h}_spriteframes.tres", "directional": True}
     for h in [
         "berserk", "soldier", "thief", "elementalist", "sniper", "priest",
         "biologist", "robot", "engineer", "dark_mage", "guitarist",
         "assassin", "ranger", "doctor", "chemist", "knight", "druid",
     ]]
    + [{"id": "rift_cutter", "group": "monster", "frames": f"{EN}/rift_cutter_spriteframes.tres",
        "directional": True}]
    + [{"id": e, "group": "monster", "frames": f"{EN}/{e}_spriteframes.tres"}
       for e in [
           "ash_marksman", "spark_runner", "stone_bruiser",
           "bone_caller", "void_mage", "venom_spitter", "rift_shieldbearer",
           "small_biter", "bone_shaman", "winged_spark",
       ]]
    + [{"id": e, "group": "monster", "frames": f"{EL}/{e}_spriteframes.tres"}
       for e in ["iron_bastion", "night_stalker", "plague_prophet", "shard_marshal"]]
    + [{"id": "mini_scavenger_reaper", "group": "monster", "frames": f"{EL}/mini_scavenger_reaper_spriteframes.tres"},
       {"id": "mini_plague_bellringer", "group": "monster", "frames": f"{EL}/mini_plague_bellringer_spriteframes.tres"},
       {"id": "mini_bone_warden", "group": "monster", "frames": f"{EL}/mini_bone_warden_spriteframes.tres"},
       {"id": "mini_spark_wight", "group": "monster", "frames": f"{EL}/mini_spark_wight_spriteframes.tres"},
       {"id": "mini_rot_hound", "group": "monster", "frames": f"{EL}/mini_rot_hound_spriteframes.tres"},
       {"id": "mini_shadow_devourer", "group": "monster", "frames": f"{EL}/mini_shadow_devourer_spriteframes.tres"}]
    + [{"id": m, "group": "monster",
        "frames": f"{EL}/{MINI_ELITE_FALLBACK[m]}_spriteframes.tres",
        "fallback_of": MINI_ELITE_FALLBACK[m]}
       for m in MINI_ELITE_FALLBACK]
    + [{"id": b, "group": "boss", "frames": f"{BO}/{b}_spriteframes.tres"}
       for b in [
           "rift_warden", "disk_devourer", "bone_archon", "brood_mother",
           "ashen_colossus", "bloodthorn_lion", "secret_ascension_boss",
       ]]
    + [{"id": s, "group": "druid_summon",
        "frames": f"{AL}/ally_druid_ghost_{s.split('_')[-1]}_spriteframes.tres",
        "explicit_horizontal": True}
       for s in ["druid_ghost_wolf", "druid_ghost_bear", "druid_ghost_panther",
                 "druid_ghost_stag", "druid_ghost_lion"]]
    + [{"id": "homunculus_tank", "group": "homunculus",
        "frames": f"{AL}/homunculus_tank_spriteframes.tres",
        "directional": True},
       {"id": "homunculus_caster", "group": "homunculus",
        "frames": f"{AL}/ally_homunculus_spriteframes.tres"}]
)

GROUP_SIZES = {"hero": 17, "monster": 25, "boss": 7, "druid_summon": 5, "homunculus": 2}

# Mirrors FullFrameAnimationRegistry.STATE_ALIASES (first candidate wins).
STATE_ALIASES = {
    "idle": ["idle", "move", "walk"],
    "move": ["move", "walk", "run", "levitate", "idle"],
    "attack": ["attack", "attack_primary", "cast", "shoot", "move"],
    "hit": ["hit", "hurt", "damage", "idle", "move"],
    "death": ["death", "die", "idle", "move"],
}
HERO_DIRECTIONS = ["south", "south_west", "west", "north_west", "north",
                   "north_east", "east", "south_east"]

# --- .tres parsing ---------------------------------------------------------

EXT_RE = re.compile(r'\[ext_resource type="([^"]+)" path="([^"]+)" id="([^"]+)"\]')
ANIM_BLOCK_RE = re.compile(
    r'\{\s*"frames":\s*\[(?P<frames>.*?)\]\s*,\s*"loop":\s*(?P<loop>\w+)\s*,\s*'
    r'"name":\s*&"(?P<name>[^"]+)"\s*,\s*"speed":\s*(?P<speed>[-\d.eE+]+)\s*\}',
    re.S,
)
FRAME_TEX_RE = re.compile(r'"texture":\s*ExtResource\("([^"]+)"\)')


def parse_spriteframes(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    ext = {m.group(3): m.group(2) for m in EXT_RE.finditer(text)}
    animations = []
    seen_names = set()
    for m in ANIM_BLOCK_RE.finditer(text):
        name = m.group("name")
        textures = [ext.get(t, "") for t in FRAME_TEX_RE.findall(m.group("frames"))]
        animations.append({
            "name": name,
            "duplicate": name in seen_names,
            "loop": m.group("loop") == "true",
            "speed": float(m.group("speed")),
            "textures": textures,
        })
        seen_names.add(name)
    return {"ext": ext, "animations": animations}


# --- frame analysis --------------------------------------------------------

def components(img: Image.Image) -> list[dict]:
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    found = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] == 0:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            area = 0
            min_x, min_y, max_x, max_y = sx, sy, sx, sy
            max_alpha = 0
            while stack:
                x, y = stack.pop()
                area += 1
                a = px[x, y][3]
                if a > max_alpha:
                    max_alpha = a
                min_x = min(min_x, x); max_x = max(max_x, x)
                min_y = min(min_y, y); max_y = max(max_y, y)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            found.append({"bbox": (min_x, min_y, max_x, max_y), "area": area, "max_alpha": max_alpha})
    return found


def bbox_gap(a: tuple, b: tuple) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    dx = max(bx1 - ax2, ax1 - bx2, 0)
    dy = max(by1 - ay2, ay1 - by2, 0)
    return (dx * dx + dy * dy) ** 0.5


MAX_ISLAND_AREA = 70
MIN_ISLAND_GAP = 10
MAX_BORDER_SHARE = 0.40   # >40% uniform border on every side = over-cropped canvas
MAX_PIVOT_DRIFT = 25.0    # px of opaque-center wander inside one animation
                           # (attack lunges bob/dash far; only canvas re-centres surface here)
LOOP_WRAP_RATIO = 1.6     # last->first jump vs mean neighbour diff
LOOP_MIN_SIGNAL = 4.0     # mean neighbour diff below this = near-static, skip


def analyze_frame(path: Path) -> dict:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    comps = components(img)
    opaque = [c for c in comps if c["area"] > MAX_ISLAND_AREA]
    notes = []
    if not comps:
        return {"size": (w, h), "empty": True, "notes": ["frame fully transparent"]}
    main = max(opaque or comps, key=lambda c: c["area"])
    for comp in comps:
        if comp["area"] > MAX_ISLAND_AREA:
            continue
        big = [c for c in comps if c["area"] > MAX_ISLAND_AREA] or [main]
        gap = min(bbox_gap(comp["bbox"], b["bbox"]) for b in big)
        if gap >= MIN_ISLAND_GAP:
            notes.append(f"stray island {comp['area']}px at {comp['bbox']} gap {gap:.0f} alpha<={comp['max_alpha']}")
    x1, y1, x2, y2 = main["bbox"]
    border = {"l": x1, "t": y1, "r": w - 1 - x2, "b": h - 1 - y2}
    if min(border.values()) > MAX_BORDER_SHARE * min(w, h):
        notes.append(f"over-cropped canvas: opaque bbox {main['bbox']} in {w}x{h}")
    center = ((x1 + x2) / 2 - w / 2, (y1 + y2) / 2 - h / 2)
    return {"size": (w, h), "empty": False, "bbox": main["bbox"], "center": center,
            "notes": notes, "image": img}


def frame_diff(a: Image.Image, b: Image.Image) -> float:
    if a.size != b.size:
        return 1e9
    pa, pb = a.load(), b.load()
    total = 0
    for y in range(0, a.size[1], 2):
        for x in range(0, a.size[0], 2):
            ra, ga, ba, aa = pa[x, y]
            rb, gb, bb, ab = pb[x, y]
            total += abs(ra - rb) + abs(ga - gb) + abs(ba - bb) + abs(aa - ab)
    return total / ((a.size[0] // 2) * (a.size[1] // 2) or 1)


# --- audit -----------------------------------------------------------------

def audit_animation(actor: dict, anim: dict, entries: dict) -> list[str]:
    tag = f"[{actor['id']}/{anim['name']}]"
    findings = []
    if anim["duplicate"]:
        findings.append(f"{tag} duplicate animation name")
    if anim["speed"] <= 0:
        findings.append(f"{tag} speed={anim['speed']}")
    if not anim["textures"]:
        findings.append(f"{tag} no frames")
        return findings
    frames = []
    for res_path in anim["textures"]:
        rel = res_path.removeprefix("res://")
        entry = entries.get(rel)
        if entry is None:
            findings.append(f"{tag} missing texture {rel}")
            continue
        entry["used"] = True
        frames.append(entry)
    for entry, note in [(e, n) for e in frames for n in e["analysis"]["notes"]]:
        findings.append(f"{tag} {Path(entry['rel']).name}: {note}")
    sizes = {e["analysis"]["size"] for e in frames}
    if len(sizes) > 1:
        findings.append(f"{tag} mixed frame dimensions: {sorted(sizes)}")
    centers = [e["analysis"]["center"] for e in frames if "center" in e["analysis"]]
    if len(centers) > 1:
        drift = max(max(abs(c[0] - d[0]), abs(c[1] - d[1])) for c in centers for d in centers)
        if drift > MAX_PIVOT_DRIFT:
            findings.append(f"{tag} pivot drift {drift:.0f}px (opaque-center wander)")
    if anim["loop"] and len(frames) > 2:
        diffs = [frame_diff(frames[i]["analysis"]["image"], frames[i + 1]["analysis"]["image"])
                 for i in range(len(frames) - 1)]
        wrap = frame_diff(frames[-1]["analysis"]["image"], frames[0]["analysis"]["image"])
        mean_d = sum(diffs) / len(diffs)
        if mean_d > LOOP_MIN_SIGNAL and wrap > LOOP_WRAP_RATIO * mean_d:
            findings.append(f"{tag} loop discontinuity: wrap diff {wrap:.0f} vs mean step {mean_d:.0f}")
    return findings


def expected_state_findings(actor: dict, anim_names: set[str]) -> list[str]:
    findings = []
    tag = f"[{actor['id']}]"

    def has(candidates: list[str]) -> bool:
        return any(c in anim_names for c in candidates)

    for state in ("idle", "move", "attack", "death"):
        if not has(STATE_ALIASES[state]):
            findings.append(f"{tag} missing state '{state}' (no alias of {STATE_ALIASES[state][:3]})")
    if actor.get("explicit_horizontal"):
        for base in ("move", "attack"):
            for side in ("left", "right"):
                if f"{base}_{side}" not in anim_names:
                    findings.append(f"{tag} missing direction '{base}_{side}'")
    if actor.get("directional"):
        for base in ("idle", "move"):
            for direction in HERO_DIRECTIONS:
                if f"{base}_{direction}" not in anim_names and f"walk_{direction}" not in anim_names:
                    findings.append(f"{tag} missing hero direction '{base}_{direction}'")
    return findings


# --- contact sheets --------------------------------------------------------

SHEET_COLS = 12
SHEET_CELL = 96


def render_contact_sheet(actor: dict, entries: dict, parsed: dict, out: Path) -> None:
    anims = [a for a in parsed["animations"] if a["textures"]]
    if not anims:
        return
    rows = len(anims)
    width = SHEET_COLS * SHEET_CELL
    header_h = 28
    row_h = SHEET_CELL + 18
    sheet = Image.new("RGBA", (width, header_h + rows * row_h), (24, 22, 30, 255))
    draw = ImageDraw.Draw(sheet)
    fallback = "fallback→" + actor["fallback_of"] + " " if actor.get("fallback_of") else ""
    draw.text((6, 6), f"{actor['id']} ({actor['group']}) {fallback}", fill=(240, 240, 210, 255))
    for r, anim in enumerate(anims):
        y0 = header_h + r * row_h
        draw.text((6, y0 + 2), f"{anim['name']} x{len(anim['textures'])} {'loop' if anim['loop'] else 'once'}",
                  fill=(150, 200, 160, 255))
        for c, res_path in enumerate(anim["textures"][:SHEET_COLS]):
            entry = entries.get(res_path.removeprefix("res://"))
            if entry is None or entry["analysis"]["empty"]:
                continue
            img = entry["analysis"]["image"]
            img.thumbnail((SHEET_CELL - 6, SHEET_CELL - 6), Image.NEAREST)
            cx = c * SHEET_CELL + (SHEET_CELL - img.size[0]) // 2
            cy = y0 + 16 + (SHEET_CELL - img.size[1]) // 2
            sheet.paste(img, (cx, cy), img)
    out.write_bytes(b"")
    sheet.save(out)


# --- driver ----------------------------------------------------------------

def build_manifest() -> list[dict]:
    manifest = []
    for actor in ROSTER:
        entry = {
            "id": actor["id"],
            "group": actor["group"],
            "frames": "res://" + actor["frames"],
        }
        for key in ("fallback_of", "directional", "explicit_horizontal"):
            if actor.get(key):
                entry[key] = actor[key]
        manifest.append(entry)
    return manifest


def audit_actor(actor: dict, sheets: bool) -> dict:
    rel = actor["frames"]
    path = ROOT / rel
    result = {"id": actor["id"], "group": actor["group"], "frames": "res://" + rel,
              "findings": [], "animations": {}, "frame_count": 0}
    if actor.get("fallback_of"):
        result["fallback_of"] = actor["fallback_of"]
    if not path.exists():
        result["findings"].append(f"[{actor['id']}] SpriteFrames resource missing: {rel}")
        return result
    parsed = parse_spriteframes(path)
    if not parsed["animations"]:
        result["findings"].append(f"[{actor['id']}] no animations in {rel}")
        return result
    result["animations"] = {
        a["name"]: {"frames": len(a["textures"]), "loop": a["loop"], "speed": a["speed"]}
        for a in parsed["animations"]
    }
    result["frame_count"] = sum(len(a["textures"]) for a in parsed["animations"])

    entries = {}
    for res_path in sorted({t for a in parsed["animations"] for t in a["textures"]}):
        file_rel = res_path.removeprefix("res://")
        file_path = ROOT / file_rel
        entry = {"rel": file_rel, "used": False,
                 "analysis": {"empty": True, "notes": ["texture file missing"], "size": (0, 0)}}
        if file_path.exists():
            entry["analysis"] = analyze_frame(file_path)
            if not (file_path.parent / (file_path.name + ".import")).exists():
                entry["analysis"]["notes"].append("missing .import sidecar")
        entries[file_rel] = entry

    for anim in parsed["animations"]:
        result["findings"].extend(audit_animation(actor, anim, entries))
    for entry in entries.values():
        if not entry["used"]:
            result["findings"].append(
                f"[{actor['id']}] orphan texture in pack: {Path(entry['rel']).name}")

    anim_names = {a["name"] for a in parsed["animations"]}
    result["findings"].extend(expected_state_findings(actor, anim_names))

    if sheets:
        out = SHEET_DIR / f"{actor['id']}.png"
        render_contact_sheet(actor, entries, parsed, out)
    return result


def main() -> int:
    make_sheets = "--no-sheets" not in sys.argv
    check = "--check" in sys.argv
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if make_sheets:
        SHEET_DIR.mkdir(parents=True, exist_ok=True)

    ids = [a["id"] for a in ROSTER]
    problems = []
    if len(ids) != 56 or len(set(ids)) != 56:
        problems.append(f"roster must cover exactly 56 unique actor ids, got {len(ids)} ({len(set(ids))} unique)")
    counts: dict[str, int] = {}
    for a in ROSTER:
        counts[a["group"]] = counts.get(a["group"], 0) + 1
    for group, expected in GROUP_SIZES.items():
        if counts.get(group, 0) != expected:
            problems.append(f"group '{group}' must list {expected} actors, got {counts.get(group, 0)}")
    if problems:
        for p in problems:
            print("ROSTER ERROR:", p, file=sys.stderr)
        return 2

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(build_manifest(), indent=2, ensure_ascii=False) + "\n",
                             encoding="utf-8")

    results = [audit_actor(a, make_sheets) for a in ROSTER]
    total_frames = sum(r["frame_count"] for r in results)
    all_findings = [f for r in results for f in r["findings"]]
    report = {
        "issue": "FAN-2518",
        "actor_count": len(results),
        "group_counts": counts,
        "frame_count": total_frames,
        "finding_count": len(all_findings),
        "actors": results,
    }
    (OUT_DIR / "audit_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    lines = [
        "# FAN-2518 recursive animation roster audit", "",
        f"Actors: {len(results)} ({', '.join(f'{k}={v}' for k, v in sorted(counts.items()))})",
        f"Total animation frames inspected: {total_frames}",
        f"Findings: {len(all_findings)}", "",
    ]
    for r in results:
        label = f"{r['id']} ({r['group']})" + (f" fallback→{r['fallback_of']}" if r.get("fallback_of") else "")
        lines.append(f"## {label}")
        lines.append(f"pack: `{r['frames']}` — {r['frame_count']} frames, "
                     f"{len(r['animations'])} animations")
        if r["findings"]:
            lines.extend(f"- {f}" for f in r["findings"])
        lines.append("")
    (OUT_DIR / "audit_report.md").write_text("\n".join(lines), encoding="utf-8")

    print(f"actors={len(results)} groups={counts} frames={total_frames} findings={len(all_findings)}")
    print(f"report: {OUT_DIR / 'audit_report.md'}")
    print(f"manifest: {MANIFEST_PATH}")
    if check and all_findings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
