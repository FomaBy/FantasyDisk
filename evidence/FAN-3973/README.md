# FAN-3973 — 0.3.1 startup regression and non-game files in the export

Developer evidence (Claude Dev Fable, macOS development host, Apple M4 Pro,
Godot 4.7.stable.official, GL Compatibility renderer, vsync 120 Hz).
Candidate branch `agent/claude-dev-fable/cf7075cc54eb`, base `dev` =
`448a0cc12f02eb05bc16becc69fde365021a9a17` (= `v0.3.1^{}`). The exact
candidate SHA/tree is recorded on the Multica card.

## What was wrong

`scripts/full_frame_animation_registry.gd` built its static table at class
load (reached through `enemy.gd`'s `preload` from `scenes/Main.tscn`, i.e.
before the main menu's first frame) and, for every actor shard, ran
`ResourceLoader.load(frames_path) is SpriteFrames` just to check the type.
That loaded all 41 full-frame packs — 8,825 lossless 512x512 frames, about
8.5 GiB of RGBA — and discarded them. Introduced by `060c1f748` (FAN-3680).
The FAN-3964 Windows review measured a 17.4 s median cold start against
5.0 s for 0.3.0.

Both export presets also shipped `evidence/**` (1,233 files, ~294 MiB),
`skills/**/*.json` and the stray root `before_/after_berserk_648p.png`.

## What changed

- Registry-time validation is load-free: the `frames` path must exist and
  carry an extension a SpriteFrames-capable loader serves (`.tres`/`.res`,
  via `ResourceLoader.get_recognized_extensions_for_type`). Script, texture
  and scene paths are still excluded with the FAN-3680 warning.
  `ResourceLoader.exists(path, "SpriteFrames")` was not usable: it answers
  true for anything already in the resource cache regardless of type.
- The strict SpriteFrames type check moved to first use
  (`_frames_for_path`, shared by `sprite_frames_for` and
  `configure_entity_visual`): a wrong-type resource yields null (static
  body fallback), warns once and is remembered per path.
  `tests/full_frame_registry_integrity_test.gd` still type-checks the whole
  catalog (41 entries).
- Bounded background prefetch: the route map (`_show_battle_map`) queues the
  regular enemy pool plus the selectable row's node elite (deterministic per
  node seed) and boss; one threaded request runs at a time; completed packs
  stay resident for the run and are released when the main menu is shown
  (`main_menu.gd`) and on exit (`main.gd` `_release_runtime_texture_refs`,
  which also collects an in-flight request so no threaded load outlives the
  tree). First use of a pack that is still loading blocks only for the
  remainder; an unstarted request runs inline — the pre-existing cost.
- `export_presets.cfg`: both presets exclude `evidence/*`, `skills/*`,
  `before_berserk_648p.png`, `after_berserk_648p.png`. `evidence/.gdignore`
  and `skills/.gdignore` keep the editor from importing those trees.
- Tests: `tests/full_frame_registry_lazy_load_test.gd`,
  `tests/test_export_presets_exclusions.py`.

## AC3 — cold start to first frame (perf checklist M4, P1)

Method (same as the FAN-3964 review): `Godot --path <project> --print-fps
--verbose --quit-after 600`, every output line timestamped with wall time
(`measure_cold_start.sh`), first `Project FPS` line minus 1 s = first-frame
estimate, five launches per build back to back (warm OS file cache, like the
review's repeated launches). `v0.3.0`/`v0.3.1` are detached worktrees at the
tags with the same import cache. Logs: `cold_start/`, summary:
`python3 analyze_cold_start.py cold_start`.

| build | runs | median first frame (s) | min | max | actor SpriteFrames loaded before first frame |
|---|---|---|---|---|---|
| v0.3.0 | 5 | 3.08 | 3.07 | 4.10 | 1 |
| v0.3.1 (= dev base) | 5 | 8.09 | 8.09 | 11.07 | 42 |
| candidate | 5 | 3.08 | 3.07 | 4.07 | 1 |

`main.gd` finishes loading at ~1.5 s in v0.3.0 and the candidate versus
~5.7 s in v0.3.1. The candidate is in the green band (≤ 5 s) on the
development host; the red threshold is > 8 s.

The one pack loaded before the first frame in all three builds is
`assets/sprites/allies/ally_druid_wolf_spriteframes.tres` (21 textures): it
is an `ext_resource` of `scenes/AllyMinion.tscn`, a scene dependency, not a
registry load. It is identical in v0.3.0 and outside this card's scope.

## AC2 — first-spawn cost before/after (macOS, windowed, real renderer)

`first_spawn_probe.gd`: phase A times `sprite_frames_for` with an empty
cache — the synchronous path `configure_entity_visual` takes at first spawn
in v0.3.0/v0.3.1 and the unchanged fallback in the candidate. Phase B queues
the enemy pool + `iron_bastion` + `rift_warden` through the prefetch, drains
it while sampling main-thread frame deltas, then times the same actors.
Logs: `first_spawn/`.

| actor | frames | v0.3.1 first use (ms) | candidate first use, no prefetch (ms) | candidate after prefetch (ms) |
|---|---|---|---|---|
| enemy/small_biter | 184 | 38.9 | 47.5 | 0.013 |
| enemy/rift_cutter | 306 | 94.7 | 94.8 | 0.008 |
| enemy/ash_marksman | 184 | 76.3 | 74.1 | 0.007 |
| elite/iron_bastion | 344 | 137.1 | 136.8 | 0.004 |
| boss/rift_warden | 448 | 135.2 | 142.8 | 0.004 |

The synchronous path is unchanged (same numbers within noise); the
prefetched path removes the stall entirely. Prefetch of 13 packs on the
route map: 805 ms over 68 frames, frame delta mean 11.8 ms, p95 21.2 ms,
max 31.6 ms (vsync frame = 8.3 ms). With two requests in flight the same
prefetch took ~550 ms but texture uploads bunched into 93–99 ms frames, so
`MAX_PREFETCH_IN_FLIGHT` is 1.

Memory: the 13 resident packs hold ~3.7 GiB of texture memory
(`RENDER_TEXTURE_MEM_USED`); static memory stays at ~64 MiB. A fight that
spawns all enemy kinds already loads the same packs today; the difference
is that they now stay resident from the first route map until the main menu
instead of being dropped and re-loaded (with the stalls above) every fight.
Whole-catalog residency was ruled out (8.5 GiB).

Still lazy (first use pays the synchronous cost as before): random
mini-elites, class summons (`ally` packs, ~80 frames each) and the secret
boss (metadata path, not registry).

## AC4 — export contents

`python3 tools/godot_gate.py --headless --path . --export-pack "macOS"
build/fan3973/FantasyDisk-macos.pck` and the same for `"Windows Desktop"`.
Both packs are byte-identical (SHA-256
`5b282513f4cf66fb33de7d7c27be5076d38fbfeea5e652ff6155dee9d4b8ab53`,
431,674,756 bytes). Listing (`export/`, from the pack header with
`list_pck_paths.py` and from inside Godot with `list_pack_res.gd`, identical
results; the Windows pack's file table is byte-identical to the macOS one, so
only the macOS listings are stored): 45,648 files, 405.6 MiB payload;
top-level `.godot`, `assets`,
`scripts`, `data`, `scenes` and root `icon.svg`, `icon.svg.import`,
`project.binary` only. Paths under `evidence/`, `skills/`, `docs/`,
`tools/`, `tests/`, `references/`, `source_docs/`, `build/`, `releases/`
and the two root textures: 0. The FAN-3964 PCK had 47,137 files.

`exported_pack_probe.gd` ran the macOS pack windowed (`--main-pack`):
main menu → hero select → route map (11 packs prefetched) → one normal
combat for 900 frames. 7 enemy kinds spawned, all 7 with a live full-frame
body, no error, missing-resource or script diagnostics in the log
(`export/exported_pack_probe.log`).

## AC1/AC5 — contracts and tests

Focused suites (all pass; `python3 tools/godot_gate.py --headless --path .
--script res://tests/<suite>.gd`): `full_frame_registry_lazy_load_test`,
`full_frame_registry_shard_validation_test`,
`full_frame_registry_integrity_test`,
`full_frame_eight_direction_contract_test`, `animation_smoke_test`,
`scrum1079_route_map_horizontal_test`, `scrum981_route_map_gold_shell_test`.
`python3 -m unittest tests.test_export_presets_exclusions`: 5 tests OK.

Game IDs, saves, `data/classes` / `data/ultimates`, the shards under
`data/animation/**` and the direction/flip/scale contract are untouched
(diff touches only the registry loader/prefetch, the route map hook, the
main menu/exit release, the presets and tests).

## AC6 — repository gates

- `python3 tools/quality_static_guard.py --changed-ref origin/dev`: passed
  (first run failed the ownership guard because the candidate spans
  `core` and `ui/main_menu`; the commit message now carries the
  `cross-domain: FAN-3973 …` declaration — see the card comment).
- `python3 tools/quality_gate.py --static-only --changed-ref origin/dev`:
  all 16 static checks pass except that first ownership-guard failure
  (`gate/gate_static_summary.txt`, `gate/gate_static.json`); the guard
  re-run after the declaration passes.
- `python3 tools/quality_gate.py --profile changed --changed-ref origin/dev
  --skip-static smoke_test full_frame route_ main_menu gamepad_menu`:
  85 Godot suites selected, 85 PASS (`gate/gate_godot_touched_summary.txt`,
  `gate/gate_godot_touched.json`) — every `tests/actors/*_smoke_test`, the
  registry suites, `runtime_smoke_test`, the route-map and main-menu
  suites. The unfiltered `changed` profile falls back to all 558 suites
  because `evidence/.gdignore` is not a path the selector knows; the filter
  set above is the touched-area selection.

## Files

- `measure_cold_start.sh`, `analyze_cold_start.py`, `cold_start/` — AC3.
- `first_spawn_probe.gd`, `first_spawn/` — AC2.
- `list_pck_paths.py`, `list_pack_res.gd`, `exported_pack_probe.gd`,
  `export/` — AC4.
- `gate/` — AC6 reports.
