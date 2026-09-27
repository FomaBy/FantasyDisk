# FAN-3977 — 0.3.2 combat freezes from on-demand full-frame loads and oversized frame packs

Developer evidence (Claude Dev Fable, macOS development host, Apple M4 Pro,
Godot 4.7.stable.official, GL Compatibility renderer — `OpenGL API 4.1 Metal`
via ANGLE, vsync on at 120 Hz, window 2560x1440). Candidate branch
`agent/claude-dev-fable/4d9f5d877c89`, base `dev` =
`36340c473772781edafffb61ff1d8cc7caa42024` (= `v0.3.2^{}`). The exact
candidate SHA/tree is recorded on the Multica card.

## What was wrong (FAN-3964 Windows review, reproduced here)

1. Packs of actors the route map did not warm (mini-elites, the in-battle
   `night_stalker`, bosses) were loaded synchronously on the main thread by
   `FullFrameAnimationRegistry._frames_for_path` when the actor spawned:
   several hundred 512x512 textures per pack. On this host `v0.3.2` shows
   12 frames over 100 ms in the 48-enemy fight (longest 497.5 / 610.6 ms,
   1 % low 61-64 FPS); `v0.3.0` shows one 130 ms frame.
2. Every pack was ~260-370 lossless 512x512 RGBA frames (allies 256x256)
   with the actor covering 16-43 % of the canvas: 8,988 MiB of RGBA for
   the 42 packs (41 registry shards + the secret boss), 3.1-4.7 GiB of
   reported texture memory resident during act 1.

## What changed

- **Lossless trim atlases** (`tools/build_full_frame_trim_atlases.py`):
  every frame is trimmed to its alpha bounding box plus 1 transparent
  source pixel, identical frames are shared, trims are packed (max-rects,
  bottom-left, 2 px gutter) into lossless pages of at most 2048x2048, and
  the SpriteFrames `.tres` references an `AtlasTexture` per frame whose
  `margin` restores the original canvas offset and logical size. Animation
  names/order/loop/speed/durations are unchanged; `get_size()` still
  reports the 512/256 canvas, so `enemy.gd` contact fitting, flip rules,
  scale/position and every registry flag are untouched. 8,988 → 1,695 MiB
  RGBA (5.3x); 9,438 per-frame textures → 126 pages. The per-frame PNG
  sources stay in the repository as art provenance (no new art; every
  source SHA-256 is bound in `<pack>_trim_manifest.json`) and are excluded
  from both export presets. `--check` recomputes everything from the
  sources and compares with the committed pages/manifests/`.tres`.
- **Encounter roster residency** (`scripts/full_frame_encounter_roster.gd`):
  the route map warms the *core roster* — all 11 enemy packs, every
  mini-elite kind (any of the 10 can roll in any regular fight) and the
  packs the selected class can summon (derived from its weapon configs) —
  and releases anything else (`retain_only`). `CombatDirector
  ._finalize_combat_start` computes the encounter roster (node elite / act
  boss / secret boss added, mini-elites dropped for elite and boss fights),
  releases unusable packs, and does not spawn anything (no waves, timer or
  win/lose evaluation in `main.gd`) until the roster is *settled* — every
  pack resident, or unloadable (rejected type / failed request: the actor
  keeps its static body); the missing pack loads in the background and the
  start is re-entered from the prefetch tick, never from inside the gate
  call. A pending wait whose registry waiter vanished (`release_prefetched`
  from another Main instance's exit cleanup, seen in the umbrella smoke) is
  re-armed by `main.gd` on the next frame. Packs are still released at the
  main menu.
- **Combat guard** (`FullFrameAnimationRegistry.set_combat_guard`): while a
  fight is active a pack that is not resident is never loaded on the main
  thread — the miss is counted (`synchronous_combat_load_count`), warned
  once per path, queued at the front of the background prefetch, the
  actor keeps its static body/rig and swaps to its `FullFrameBody` when
  the pack lands (`refresh_full_frame_visual` on enemies and allies).
- **Spawn-order fix**: `_maybe_spawn_mini_elite` sets `mini_elite_kind`
  before `add_child`; `enemy.gd` chooses the mini-elite pack by
  registration (`has_usable_pack`) instead of loading it. Before, every
  mini-elite roll requested the base elite pack (~70 MiB) first.
- `BossSceneCatalog` extracted from `combat_director.gd` (line ratchet).
- FAN-3934's 4096x4096 Small Biter slot atlas, its manifest, tool and
  dedicated parity test are superseded by the trim atlas of the same pack.

## AC1 — no synchronous load during combat

`tests/full_frame_combat_residency_test.gd` (headless): the roster covers
every enemy, every mini-elite kind (own pack, base pack fallback), the
class's allies, each of the four node-elite scenes, every registered boss
and the secret boss; `_start_combat` creates Player/HUD synchronously but
does not finalize before the roster is resident; with the guard up it
spawns all 11 enemy scenes, all 10 mini-elite kinds (directly and through
the real `_maybe_spawn_mini_elite`, 80 forced rolls), the Druid's 7 ally
visuals, four elite fights, seven boss fights — `synchronous_combat_load_
count()` stays 0 and every actor plays a resident pack; a deliberately
non-resident pack is not loaded (counter increments, one warning, static
body/rig visible, queued, swapped after the background load); elite/boss
fights drop the mini-elites; `_end_combat` lowers the guard. Mutation
check: with the gate and guard removed from `_finalize_combat_start` the
suite fails with 135 errors.

In the perf runs below the candidate logged no roster-miss warning in any
phase (the first candidate run, before the spawn-order fix, logged one for
`iron_bastion` from a wave-rolled `mini_bone_warden`).

## AC2 — per-pack cost before/after (`pack_load_probe.gd`, windowed)

Cold synchronous `ResourceLoader.load` of each pack on the main thread
(the v0.3.2 first-use cost), the frame it lands in, and the texture memory
it adds. "reported" is `RENDER_TEXTURE_MEM_USED`, which counts 4/3 of the
RGBA bytes for every texture (mip-chain accounting; the same factor applies
to the old per-frame textures). Logs: `perf/pack_load_*.log/json`.

| pack | frames | textures before → after | RGBA MiB before → after | reported texture MiB before → after | sync load ms before → after | frame ms before → after |
|---|---|---|---|---|---|---|
| enemy/ash_marksman | 184 | 184 → 2 | 184 → 30 | 245 → 39 | 144.0 → 18.1 | 160.3 → 33.8 |
| enemy/bone_caller | 184 | 184 → 2 | 184 → 30 | 245 → 40 | 138.3 → 16.7 | 141.7 → 19.9 |
| enemy/bone_shaman | 184 | 184 → 3 | 184 → 33 | 245 → 44 | 141.6 → 17.7 | 154.2 → 22.9 |
| enemy/rift_cutter | 306 | 224 → 2 | 224 → 26 | 299 → 35 | 169.6 → 18.0 | 174.0 → 24.3 |
| enemy/rift_shieldbearer | 184 | 184 → 2 | 184 → 24 | 245 → 32 | 138.5 → 14.9 | 146.6 → 20.7 |
| enemy/small_biter | 184 | 3 → 3 | 184 → 43 | 256 → 57 | 48.6 → 20.8 | 57.7 → 29.1 |
| enemy/spark_runner | 208 | 208 → 2 | 208 → 29 | 277 → 39 | 165.6 → 23.0 | 181.3 → 36.3 |
| enemy/stone_bruiser | 216 | 216 → 2 | 216 → 24 | 288 → 33 | 164.4 → 12.4 | 181.0 → 18.9 |
| enemy/venom_spitter | 184 | 184 → 4 | 184 → 60 | 245 → 80 | 137.5 → 24.7 | 150.9 → 41.9 |
| enemy/void_mage | 184 | 184 → 3 | 184 → 35 | 245 → 46 | 133.7 → 18.9 | 139.0 → 29.4 |
| enemy/winged_spark | 224 | 224 → 4 | 224 → 50 | 299 → 67 | 166.6 → 25.2 | 172.0 → 42.3 |
| elite/iron_bastion | 344 | 344 → 5 | 344 → 65 | 459 → 87 | 246.0 → 31.2 | 251.3 → 46.9 |
| elite/mini_bone_warden | 488 | 296 → 4 | 296 → 49 | 395 → 65 | 220.4 → 28.4 | 223.7 → 32.4 |
| elite/mini_plague_bellringer | 488 | 296 → 3 | 296 → 42 | 395 → 56 | 216.3 → 25.8 | 231.9 → 37.1 |
| elite/mini_plague_berserker | 424 | 264 → 2 | 264 → 25 | 352 → 33 | 189.4 → 17.3 | 203.3 → 24.1 |
| elite/mini_rot_hound | 264 | 264 → 4 | 264 → 57 | 352 → 76 | 185.7 → 25.3 | 199.4 → 39.6 |
| elite/mini_scavenger_reaper | 488 | 296 → 3 | 296 → 46 | 395 → 61 | 210.8 → 26.9 | 216.2 → 40.1 |
| elite/mini_shadow_devourer | 488 | 296 → 4 | 296 → 52 | 395 → 70 | 236.4 → 45.7 | 241.5 → 48.1 |
| elite/mini_siege_rammer | 488 | 296 → 4 | 296 → 54 | 395 → 72 | 216.2 → 31.9 | 231.3 → 45.8 |
| elite/mini_spark_wight | 488 | 296 → 3 | 296 → 40 | 395 → 54 | 214.3 → 24.9 | 228.6 → 29.1 |
| elite/mini_swarm_sniper | 488 | 296 → 3 | 296 → 45 | 395 → 61 | 209.4 → 25.4 | 214.7 → 36.6 |
| elite/mini_void_phantom | 488 | 296 → 3 | 296 → 45 | 395 → 60 | 231.0 → 40.0 | 245.9 → 45.9 |
| elite/night_stalker | 368 | 368 → 6 | 368 → 82 | 491 → 109 | 272.7 → 50.6 | 277.6 → 56.6 |
| elite/plague_prophet | 248 | 248 → 2 | 248 → 29 | 331 → 39 | 166.8 → 15.5 | 180.7 → 22.4 |
| elite/shard_marshal | 504 | 336 → 3 | 336 → 44 | 448 → 59 | 227.8 → 25.2 | 242.3 → 37.9 |
| boss/ashen_colossus | 448 | 304 → 3 | 304 → 42 | 405 → 56 | 238.4 → 51.3 | 246.2 → 54.3 |
| boss/bloodthorn_lion | 448 | 304 → 5 | 304 → 64 | 405 → 85 | 242.2 → 60.2 | 247.3 → 63.8 |
| boss/bone_archon | 448 | 304 → 3 | 304 → 46 | 405 → 61 | 232.2 → 45.9 | 246.2 → 54.4 |
| boss/brood_mother | 448 | 304 → 4 | 304 → 57 | 405 → 76 | 250.8 → 63.4 | 256.7 → 71.6 |
| boss/disk_devourer | 328 | 328 → 5 | 328 → 67 | 437 → 90 | 251.4 → 40.2 | 267.5 → 53.4 |
| boss/rift_warden | 448 | 304 → 3 | 304 → 46 | 405 → 61 | 226.9 → 39.2 | 243.1 → 52.5 |
| ally/druid_beast | 26 | 20 → 1 | 5 → 4 | 7 → 5 | 22.9 → 10.0 | 37.5 → 24.6 |
| ally/druid_ghost_bear | 153 | 104 → 1 | 26 → 13 | 35 → 17 | 57.2 → 11.7 | 61.3 → 17.7 |
| ally/druid_ghost_lion | 153 | 104 → 1 | 26 → 11 | 35 → 15 | 60.6 → 12.0 | 70.8 → 20.5 |
| ally/druid_ghost_panther | 153 | 104 → 1 | 26 → 9 | 35 → 13 | 61.4 → 10.6 | 75.7 → 25.7 |
| ally/druid_ghost_stag | 153 | 104 → 1 | 26 → 15 | 35 → 21 | 60.7 → 13.6 | 65.0 → 18.4 |
| ally/druid_ghost_wolf | 153 | 104 → 1 | 26 → 12 | 35 → 16 | 55.8 → 12.6 | 65.3 → 26.6 |
| ally/druid_pack_spirit | 26 | 20 → 1 | 5 → 3 | 7 → 4 | 24.7 → 9.3 | 27.9 → 20.5 |
| ally/homunculus | 26 | 20 → 1 | 5 → 3 | 7 → 4 | 23.5 → 8.4 | 37.1 → 15.3 |
| ally/homunculus_tank | 206 | 206 → 2 | 206 → 24 | 275 → 31 | 155.5 → 15.9 | 158.8 → 20.6 |
| ally/leadership_echo | 26 | 20 → 1 | 5 → 2 | 7 → 3 | 23.7 → 5.9 | 38.4 → 12.3 |
| boss/secret_ascension_boss | 912 | 432 → 14 | 432 → 215 | 576 → 287 | 421.5 → 138.0 | 429.7 → 147.3 |
| **all 42** | | | 8,988 → 1,695 | 11995 → 2260 | 7001 → 1173 | |


## AC3 — macOS measurements (`perf_driver.gd`, real run path, windowed)

Same script on the `v0.3.0` and `v0.3.2` tag worktrees and the candidate:
new run → route map (8 s window) → click the first battle node → 48
enemies kept alive for 60 s with every mini-elite kind rolled (one per
5 s) → victory → route map → `night_stalker` elite fight (20 s) → act-1
boss `rift_warden` (20 s) → act-2 boss `disk_devourer` (20 s) → main menu.
Per-second FPS from frame counts (perf checklist M1; 1 % low = worst 1 %
of seconds), frames over 50/100 ms, longest frame, peak
`RENDER_TEXTURE_MEM_USED`. Berserk (no summons) and Druid (largest ally
roster: beast, pack spirit, five ghosts). Logs/JSON: `perf/`.

| build (class) | phase | s | avg FPS | 1% low | worst second | frames >50 ms | frames >100 ms | longest frame ms | peak texture MiB |
|---|---|---|---|---|---|---|---|---|---|
| v0.3.0 (berserk) | route_map_first_show | 8 | 120 | 117 | 117 | 0 | 0 | 16.8 | 191 |
| v0.3.0 (berserk) | p2_48_enemies | 60 | 119 | 104 | 104 | 1 | 1 | 130.3 | 302 |
| v0.3.0 (berserk) | route_map_after_p2 | 3 | 114 | 110 | 110 | 1 | 0 | 92.0 | 234 |
| v0.3.0 (berserk) | elite_night_stalker | 20 | 118 | 110 | 110 | 1 | 0 | 90.7 | 344 |
| v0.3.0 (berserk) | route_map_after_elite | 3 | 118 | 116 | 116 | 0 | 0 | 34.4 | 269 |
| v0.3.0 (berserk) | boss_act1_rift_warden | 20 | 117 | 111 | 111 | 1 | 0 | 84.4 | 401 |
| v0.3.0 (berserk) | route_map_after_boss1 | 3 | 118 | 114 | 114 | 0 | 0 | 16.9 | 288 |
| v0.3.0 (berserk) | boss_act2_disk_devourer | 20 | 113 | 108 | 108 | 1 | 0 | 95.9 | 381 |
| v0.3.2 (berserk) | route_map_first_show | 8 | 116 | 96 | 96 | 0 | 0 | 25.1 | 3082 |
| v0.3.2 (berserk) | p2_48_enemies | 60 | 111 | 61 | 61 | 12 | 12 | 497.5 | 4710 |
| v0.3.2 (berserk) | route_map_after_p2 | 3 | 117 | 112 | 112 | 1 | 0 | 90.0 | 3125 |
| v0.3.2 (berserk) | elite_night_stalker | 20 | 118 | 114 | 114 | 0 | 0 | 22.8 | 3707 |
| v0.3.2 (berserk) | route_map_after_elite | 3 | 120 | 118 | 118 | 0 | 0 | 30.7 | 3142 |
| v0.3.2 (berserk) | boss_act1_rift_warden | 20 | 118 | 116 | 116 | 0 | 0 | 22.3 | 3639 |
| v0.3.2 (berserk) | route_map_after_boss1 | 3 | 120 | 119 | 119 | 0 | 0 | 17.3 | 3179 |
| v0.3.2 (berserk) | boss_act2_disk_devourer | 20 | 116 | 113 | 113 | 0 | 0 | 27.3 | 3691 |
| candidate (berserk) | route_map_first_show | 8 | 119 | 115 | 115 | 0 | 0 | 15.3 | 1315 |
| candidate (berserk) | p2_48_enemies | 60 | 119 | 116 | 116 | 0 | 0 | 25.9 | 1407 |
| candidate (berserk) | route_map_after_p2 | 3 | 116 | 107 | 107 | 1 | 0 | 98.0 | 1358 |
| candidate (berserk) | elite_night_stalker | 20 | 118 | 116 | 116 | 0 | 0 | 23.9 | 950 |
| candidate (berserk) | route_map_after_elite | 3 | 119 | 118 | 118 | 0 | 0 | 26.7 | 875 |
| candidate (berserk) | boss_act1_rift_warden | 20 | 118 | 116 | 116 | 0 | 0 | 23.5 | 920 |
| candidate (berserk) | route_map_after_boss1 | 3 | 120 | 118 | 118 | 0 | 0 | 16.7 | 864 |
| candidate (berserk) | boss_act2_disk_devourer | 20 | 116 | 114 | 114 | 0 | 0 | 25.4 | 968 |
| v0.3.2_druid (druid) | route_map_first_show | 8 | 119 | 116 | 116 | 0 | 0 | 21.9 | 3082 |
| v0.3.2_druid (druid) | p2_48_enemies | 60 | 106 | 64 | 64 | 17 | 12 | 610.6 | 4497 |
| v0.3.2_druid (druid) | route_map_after_p2 | 3 | 117 | 110 | 110 | 1 | 0 | 89.7 | 3125 |
| v0.3.2_druid (druid) | elite_night_stalker | 20 | 112 | 107 | 107 | 1 | 0 | 62.1 | 3880 |
| v0.3.2_druid (druid) | route_map_after_elite | 3 | 119 | 116 | 116 | 0 | 0 | 32.3 | 3141 |
| v0.3.2_druid (druid) | boss_act1_rift_warden | 20 | 112 | 107 | 107 | 0 | 0 | 39.6 | 3777 |
| v0.3.2_druid (druid) | route_map_after_boss1 | 3 | 120 | 120 | 120 | 0 | 0 | 14.5 | 3178 |
| v0.3.2_druid (druid) | boss_act2_disk_devourer | 20 | 92 | 79 | 79 | 5 | 0 | 81.6 | 3864 |
| candidate_druid (druid) | route_map_first_show | 8 | 118 | 112 | 112 | 0 | 0 | 22.0 | 1396 |
| candidate_druid (druid) | p2_48_enemies | 60 | 116 | 106 | 106 | 0 | 0 | 31.0 | 1488 |
| candidate_druid (druid) | route_map_after_p2 | 3 | 115 | 108 | 108 | 1 | 0 | 93.7 | 1439 |
| candidate_druid (druid) | elite_night_stalker | 20 | 111 | 101 | 101 | 1 | 0 | 52.1 | 1032 |
| candidate_druid (druid) | route_map_after_elite | 3 | 120 | 118 | 118 | 0 | 0 | 27.0 | 957 |
| candidate_druid (druid) | boss_act1_rift_warden | 20 | 112 | 106 | 106 | 0 | 0 | 29.8 | 1001 |
| candidate_druid (druid) | route_map_after_boss1 | 3 | 120 | 120 | 120 | 0 | 0 | 14.7 | 946 |
| candidate_druid (druid) | boss_act2_disk_devourer | 20 | 91 | 72 | 72 | 9 | 0 | 57.0 | 1049 |


| build (class) | menu texture MiB | act-1 peak texture MiB | menu after run MiB | P2 node click frame ms | P2 roster wait ms | elite roster wait ms |
|---|---|---|---|---|---|---|
| v0.3.0 (berserk) | 28 | 401 | 312 | 446 | 0 | 120 |
| v0.3.2 (berserk) | 28 | 4710 | 312 | 139 | 0 | 269 |
| candidate (berserk) | 28 | 1407 | 310 | 132 | 0 | 157 |
| v0.3.2_druid (druid) | 28 | 4497 | 312 | 465 | 0 | 512 |
| candidate_druid (druid) | 28 | 1488 | 310 | 188 | 0 | 205 |


- (a) P2 48-enemy fight: candidate average 116-119 FPS, 1 % low 106-116
  (target ≥ 60 / ≥ 45), no frame over 50 ms after the fight started
  (longest 25.9 / 31.0 ms); v0.3.2 had 12 frames over 100 ms (longest
  497-611 ms).
- (b) Route-map prefetch window: candidate longest frame 15.3 / 22.0 ms,
  no frame over 50 ms (the whole core roster becomes resident in the
  background; headless the 31 packs take ~0.6 s, `core_roster_load_probe.gd`).
  The single 90-98 ms frame in `route_map_after_p2` is the victory →
  route-map transition and is identical in v0.3.0 (92 ms) and v0.3.2
  (90 ms); the 130-190 ms node-click frame is the arena/Player build and
  is unchanged (FAN-3973 measured 128 ms).
- (c) Peak texture memory through act 1: candidate 1,407 MiB (Berserk) /
  1,488 MiB (Druid) — at most 1.5 GiB, versus 4,710 / 4,497 MiB in v0.3.2;
  at the act-2 boss 968 / 1,049 MiB; released between runs (main menu
  310 MiB in every build). In raw RGBA the Druid core roster is 909 MiB
  (Berserk 842 MiB); the monitor reports 4/3 of that plus the ~190 MiB
  route-map/UI/hero baseline. v0.3.0 (401 MiB) is a different content
  generation: its 36 packs held 944 textures of at most 384x384
  (0.66 GiB RGBA) versus 9,438 frames at 512x512 today, so the 0.3.0
  figure is not reachable without resampling the art, which AC4 forbids.
- (d) M4 cold start (`cold_start/`, `evidence/FAN-3973/measure_cold_start.sh`
  method, 5 launches each): candidate median 4.09 s (4.08-4.24), v0.3.2
  4.09 s (4.08-4.10); one actor SpriteFrames before the first frame in
  both (the `AllyMinion.tscn` dependency, as in FAN-3973). Green band.
- The Druid act-2 boss phase shows a few 50-57 ms frames in the candidate
  (9) and 62-82 ms frames in v0.3.2 (5): Druid summon/VFX cost, not pack
  loads (no roster-miss warning; every pack of that fight is resident).

Windows-specific open risks for the FAN-3964 re-review: texture upload cost
per page on FomaPC/GL (pages are ≤ 16 MiB each, one pack ≤ 6 pages, uploads
spread over the background load; the old path uploaded ~300 MiB per pack)
and the absolute texture-memory baseline of that host's UI/backgrounds (173
MiB at the menu in the review versus ~190 MiB at the route map here).

## AC4 — visual and content compatibility

- `tests/full_frame_trim_atlas_parity_test.gd`: for all 42 packs every atlas
  entry is byte-identical to the retained source PNG at its margin offset,
  every frame is an `AtlasTexture` with the manifest region/margin and the
  original canvas size, animation names/loop/speed/frame counts/durations
  match, negative fixtures (shifted region, wrong margin) fail, page imports
  are lossless without mipmaps, cold reload is orphan-free. Windowed
  (`-- export=<dir>`): 732 captures (6 animations x 3 cases per pack:
  registry scale x 1.12 combat zoom, the same flipped, and x 1.51) of the
  trimmed pack versus a reference SpriteFrames built from the retained
  source textures — maximum per-channel difference 2/255 on anti-aliased
  edge texels (GPU texture-coordinate rounding over a different quad/page
  size), tolerance 4/255. Side-by-side captures (before | after | diff in
  magenta) for every pack: `captures/<pack>_<animation>_before_after_diff.png`
  with `<pack>_<animation>.json` (differing pixels, max difference).
- Game IDs, saves, classes/ultimates, `explicit_eight_directions` /
  `explicit_horizontal_directions`, `directional_fallback_used`, flip rules,
  registry `scale`/`position`: untouched (`data/animation/**` unchanged;
  `full_frame_eight_direction_contract_test`, `fan2623_shard_marshal_
  directional_test`, `night_stalker_live_geometry_test` — adapted to read the
  canvas through the margin — `secret_boss_animation_pack_smoke`,
  `full_frame_row_scale_invariant_test` pass).
- Provenance: no new art; pages are derived from the committed per-frame
  PNGs, whose SHA-256 are recorded per pack in `*_trim_manifest.json`;
  `python3 tools/build_full_frame_trim_atlases.py --check` → `TRIM ATLAS
  CHECK OK (42 packs)`.

## AC5 — export

`python3 tools/godot_gate.py --headless --path . --export-pack "macOS"
build/fan3977_macos.pck`, listed with `evidence/FAN-3973/list_pck_paths.py`
(forbidden paths: 0): candidate PCK 424,530,004 bytes, payload 401.4 MiB,
27,013 files; the same export of the `v0.3.2` worktree: 431,674,964 bytes,
payload 405.6 MiB, 45,648 files. The retained per-frame sources, their
`.import` sidecars and the trim manifests are excluded (both presets); the
FAN-3973 exclusions are intact. No missing-resource error in any candidate
run log (menu, route map, hero setup, combat: `perf/candidate*.log`).

## AC6 — repository gates (commands and results)

- `python3 tools/quality_static_guard.py` → passed.
- `python3 tools/build_full_frame_trim_atlases.py --check` → OK (42 packs).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/<suite>.gd`
  passed for: `full_frame_trim_atlas_parity_test`,
  `full_frame_combat_residency_test`, `route_map_full_frame_prefetch_test`,
  `full_frame_registry_lazy_load_test`, `full_frame_registry_integrity_test`,
  `full_frame_registry_shard_validation_test`,
  `full_frame_eight_direction_contract_test`, `animation_smoke_test`,
  `fan2623_shard_marshal_directional_test`, `secret_boss_animation_pack_smoke`,
  `full_frame_row_scale_invariant_test`, `night_stalker_live_geometry_test`,
  `asset_reference_integrity_test`, `runtime_smoke_combat_test`,
  `runtime_smoke_boss_elite_test`, `runtime_smoke_ui_test`,
  `runtime_smoke_triggered_artifacts_test`, `dev_console_smoke_test`,
  `dev_console_win_flow_test`, `duplicate_player_spawn_regression_test`,
  `route_elite_invariant_test`, `route_chest_artifact_test`,
  `two_act_run_progression_scrum1058_test`, `gamepad_combat_actions_test`,
  `gamepad_inrun_ui_test`, `gamepad_full_flow_smoke_test`,
  `scrum926_priest_prayer_choice_test`, `scrum926_priest_prayer_capture_test`,
  `ui_no_overlap_matrix_test`, `scrum983_escape_dossier_test`,
  `attribute_ui_matrix_fan1927_test`, `ultimates/canonical_ultimate_text_test`,
  `encounters/beat_marked_target_runtime_test`,
  `ultimates/presentation/dark_mage_accessibility_modes_test`,
  `ally_minion_lifecycle_test`, `actors/mini_void_phantom_smoke_test`,
  `actors/night_stalker_smoke_test`, `actors/rift_warden_smoke_test`.
- `python3 tools/typography_inventory.py` regenerated
  `docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json`
  (three `combat_director.gd` line numbers shifted by the extraction); the
  Druid ghost actor smokes (`tests/animation_smoke_test.gd`
  `_assert_druid_ghost_pack`) read the frame's source identity through the
  trim manifest instead of the texture path and the canvas size through
  the margin.
- Test adaptation: suites that start a fight and then inspect spawned actors
  now `await CombatStartSupport.await_finalized(main)`
  (`tests/support/combat_start_support.gd`), because spawns wait for the
  encounter roster; the helper returns immediately for the Priest prayer
  flow and for non-pending starts.
- `python3 tools/quality_gate.py --profile changed --changed-ref origin/dev`
  (560 Godot suites selected; the certification/timeline suites need the
  Git LFS reference assets hydrated — `git lfs pull
  --include="docs/design/reference-assets-lfs/**"` — they are pointers in a
  fresh Multica checkout): result recorded on the Multica card with the
  candidate SHA. The FAN-3942 ultimate certification capture packages
  (`assassin`, `doctor`, `druid`; `tests/ultimates/presentation/
  *_certification_capture_test.gd`) bind the whole tree at their capture
  commit and report "source is stale: post-capture runtime/tooling change"
  for any later non-evidence change — they pass on base `dev` and fail on
  this candidate because of its `scripts/**` and ally `.tres` changes, as
  they would for any runtime change; re-capture belongs to the
  certification owner (release chain), not to this card. No file under
  `tests/ultimates/**` is changed by this candidate, so the changed
  profile does not select them; the note is for the full profile.
  The umbrella `runtime_smoke_test` and `runtime_smoke_ui_test`
  print one engine `ERROR: Parameter "t" is null.` line that is not a
  suite failure and is unrelated to this change.

## Files

- `perf_driver.gd`, `pack_load_probe.gd`, `core_roster_load_probe.gd`,
  `texture_composition_probe.gd` — the probes above.
- `perf/` — driver and probe logs/JSON for v0.3.0, v0.3.2 (Berserk and
  Druid), candidate (Berserk and Druid).
- `cold_start/` — five timestamped launches per build.
- `captures/` — before/after/diff renders per pack.
