# FAN-3981 — 0.3.1 release: engine object count (M3) red from resident full-frame packs

Developer evidence (Claude Dev Fable, macOS development host, Apple M4 Pro,
Godot 4.7.stable.official.5b4e0cb0f, GL Compatibility renderer —
`OpenGL API 4.1 Metal` via ANGLE, vsync on at 120 Hz, window 2560x1440).
Candidate branch `agent/claude-dev-fable/22e822a51908`, base `dev` =
`165f14aa0ce5bcbd884e4dfde137283a8010e863` (= `v0.3.1^{}`). The exact
candidate SHA/tree is recorded on the Multica card.

## What was wrong (FAN-3964 fixed-0.3.1 Windows review, reproduced here)

FAN-3977 keeps the encounter roster's full-frame packs resident (23 packs
on the route map / in a regular fight, 14 in elite and boss fights). Each
trim-atlas SpriteFrames held one `AtlasTexture` sub-resource per unique
frame, i.e. 14-428 engine objects per pack (9,122 for the 42 packs), so
`Performance.OBJECT_COUNT` read 7,606 on the route map and 8,643-8,719 in
P2 on the Windows review (checklist target P2 ≤ 5,000 / P3 ≤ 4,000, red
> 6,250 / > 5,000). Reproduced on this host with the same driver:
`v0.3.1` route map 7,708 (23 packs), P2 9,035, P3 7,348; `v0.3.0` (no
residency, 36 smaller packs) 2,634 / 4,335 / 5,276.

## What changed (frame representation; residency policy unchanged)

- `scripts/full_frame_trim_atlas.gd` (`FullFrameTrimAtlas`, Resource):
  the pack's geometry as plain arrays — one entry per unique frame (page
  index, region on the page, canvas offset of the trim; `ENTRY_STRIDE` 7
  ints) and, per animation, the entry index of every frame. It is carried
  by the SpriteFrames as `metadata/full_frame_trim_atlas`. `attach(sprite)`
  connects the `AnimatedSprite2D.draw` signal and `draw_frame` draws the
  current frame's page region at exactly the destination
  `AtlasTexture.draw_rect_region` produced for the same sprite state
  (`offset`, `centered`, `flip_h`/`flip_v`, the pixel-snap rounding of
  `AnimatedSprite2D`'s draw). `frame_entry` / `frame_canvas_image` /
  `frame_sources` give tests and tools the geometry, the canvas pixels
  and the retained source PNGs of a frame.
- `scripts/full_frame_canvas_texture.gd` (`FullFrameCanvasTexture`,
  Texture2D): ONE instance per pack referenced by every frame. It reports
  the 512x512 (allies 256x256) canvas through `get_size()` and draws
  nothing (`_draw*` are explicit no-ops), so `AnimatedSprite2D` computes
  the same destination rectangle as before and every consumer that
  measures the frame texture (`enemy.gd` contact fitting and ground
  circle, `player_sprite_grounding`, the actor smokes) sees the unchanged
  canvas.
- `tools/build_full_frame_trim_atlases.py` renders the `.tres` in this
  representation (same pages, same manifest, same trim geometry;
  `--check` OK for all 42 packs — `logs/build_trim_atlases_check.log`).
  The 42 `*_spriteframes.tres` are regenerated from the unchanged trim
  manifests: 58,251 lines of `AtlasTexture` sub-resources replaced by one
  canvas + one table per pack. No page PNG, source PNG, manifest, `data/
  animation/**` file or registry config changed. No new art; every source
  frame's SHA-256 stays bound in `<pack>_trim_manifest.json` (FAN-3977).
- `FullFrameAnimationRegistry.configure_entity_visual` attaches the draw
  hook to every body it configures (enemies, mini-elites, elites, bosses,
  allies, the secret boss). `tools/animation_gallery.gd` attaches its own
  sprite. Hero packs (`assets/sprites/characters/**`), VFX flipbooks and
  every non-full-frame visual are untouched (they are not trim-atlas
  packs; `attach` is a no-op on ordinary SpriteFrames).
- Docs: `docs/design/systems/animation.md` records the contract.

Why this and not narrower residency: a resident pack now costs 3-4
engine objects (SpriteFrames + canvas + table; pages are shared
`CompressedTexture2D`s that were already counted), so the 23-pack roster
costs ~100 objects instead of ~5,000 and the FAN-3977 residency policy —
the reason there are no synchronous combat loads — did not have to move.

## AC1 — object count on the real path (macOS, same driver on three builds)

`evidence/FAN-3981/perf_driver.gd` (the FAN-3977 driver plus per-phase
`Performance.OBJECT_COUNT` peak/min/per-second and the resident pack count;
run WINDOWED through `tools/godot_gate.py` in exclusive mode, project run
with the shipping `gl_compatibility` renderer — stated explicitly, not an
exported build): main menu 20 s → new run (Berserk/sword, seed 3977) →
route map (8 s residency window) → click first battle node → P2 60 s with
48 enemies alive and every mini-elite kind rolled → victory → route map →
elite fight `night_stalker` → P3 act-1 boss `rift_warden` 60 s → act-2 boss
`disk_devourer` → main menu. Two boss modes: the FAN-3977 default keeps 48
enemies alive during boss fights as well (`48-enemy top-up`); `boss=natural`
spawns nothing beyond what the combat director and the boss spawn themselves
(the checklist's plain P3 "boss fight"). Reports: `perf/*.json`, tables:
`perf_tables.md`, logs: `logs/perf_*.log`.

| build | boss phases | P1 menu peak | route map peak (packs) | P2 peak (band) | P3 peak (band) | elite peak | act-2 boss peak | menu after run (packs) |
|---|---|---|---|---|---|---|---|---|
| v0.3.0 | 48-enemy top-up | 2,227 | 2,634 (n/a) | 4,335 (green) | 5,276 (red) | 4,376 | 4,561 | 2,388 |
| v0.3.1 (165f14aa) | 48-enemy top-up | 2,271 | 7,708 (23) | 9,035 (red) | 7,348 (red) | 6,499 | 6,479 | 2,514 (0) |
| **candidate** | 48-enemy top-up | 2,234 | 2,732 (23) | **4,065 (green)** | **4,866 (yellow, ≤ 5,000 hard limit)** | 3,894 | 3,989 | 2,500 (0) |
| v0.3.0 | natural spawns | 2,202 | 2,633 (n/a) | 4,273 (green) | 3,354 (green) | 4,399 | 3,524 | 2,386 |
| v0.3.1 (165f14aa) | natural spawns | 2,265 | 7,708 (23) | 9,135 (red) | 5,747 (red) | 6,455 | 5,724 | 2,510 (0) |
| **candidate** | natural spawns | 2,234 | 2,731 (23) | **4,080 (green)** | **3,308 (green)** | 3,902 | 3,390 | 2,487 (0) |

- Hard limits met in both modes: P2 4,065 / 4,080 ≤ 6,250; P3 4,866 /
  3,308 ≤ 5,000. Checklist target met for P2 in both modes and for P3 in
  the plain boss fight (3,308 ≤ 4,000; `v0.3.0` 3,354 in the same run).
- Remaining gap: P3 with the 48-enemy top-up peaks at 4,866, 866 (21.7 %)
  over the 4,000 target — yellow. Cause, with numbers: the 14 resident
  packs cost 14 x 4 = 56 objects (`v0.3.1` → candidate P3 drop 7,348 →
  4,866 = 2,482 ≈ 14 packs x 177 removed `AtlasTexture`s, the same
  scenario on `v0.3.0` peaks at 5,276); everything above ~3,300 in that
  mode is the fight population itself — 48 top-up enemies plus the
  boss's riftling summons and hazards (`alive` 3 → 14 in the natural
  mode vs the 48-enemy top-up), i.e. the pre-existing P3 object budget
  FAN-3934 diagnosed (4,558-4,610 with `rift_warden`, 92 % non-Node
  objects), not full-frame packs. The candidate is at or below the 0.3.0
  scale in every phase (P2 4,065 vs 4,335; P3 4,866 vs 5,276; route map
  2,732 vs 2,634 with 23 packs resident vs none).
- No monotonic growth inside any window (`perf_tables.md` prints every
  per-second series with rise/fall counts, e.g. candidate P2 30 rises /
  29 falls, P3 36 / 23; the P3 series climbs with the alive population in
  every build, `v0.3.0` included). After returning to the main menu the
  count is 2,487-2,500 with 0 resident packs against 2,234 in P1 — the
  same +250 post-run residue as `v0.3.1` (2,510-2,514 vs 2,265-2,271) and
  `v0.3.0` (2,386-2,388 vs 2,202-2,227): the finished run's state, not
  packs.

## AC2 — measured with the shipping renderer against references

Renderer `gl_compatibility` on every run (`driver …: renderer=
gl_compatibility vsync=1 window=(2560, 1440)` in each log). `v0.3.0` =
`fd9fd1a4f`, `v0.3.1` = `165f14aa0` (worktrees `ref-v0.3.0`, `ref-v0.3.1`
next to the candidate, imported with the same Godot; import logs clean —
`logs/export_import_summary.md`). Resident pack counts per phase are in the
tables above and in `perf_tables.md` (`v0.3.0` has no registry counter).
Windows-specific residue for the FAN-3964 re-review is listed at the end.

## AC3 — no FAN-3977 / FAN-3973 regression

- `synchronous_combat_load_count` stays 0: `tests/full_frame_combat_
  residency_test.gd` (headless, `logs/gate_full_frame_combat_residency_
  test.log`) spawns every enemy scene, all 10 mini-elite kinds (directly and
  through the real `_maybe_spawn_mini_elite`), the Druid's 7 summons, the
  four elite fights, seven boss fights including the secret boss path with
  the combat guard up — 0 synchronous loads, the deliberate miss still
  falls back to the static body and swaps later without blocking a frame.
  No miss warning in any perf run log.
- Route-map residency window: candidate 0 frames over 50 ms (longest
  24.9 / 17.7 ms; `v0.3.1` 14.1 / 17.7; `v0.3.0` 17.0 / 16.9).
- P2 after the fight starts: candidate 0 frames over 100 ms (0 over 50 ms;
  longest 25.9 / 26.1 ms), average 119 FPS, 1 % low 115-116 (M1 green);
  `v0.3.1` 0 / 26.1 ms, 119 / 115; `v0.3.0` 11 frames over 50 ms, 5 over
  100 ms, longest 343.3 ms, 1 % low 80. The node-click frame (144-151 ms
  on candidate and `v0.3.1`, 440-445 ms on `v0.3.0`) and the "victory →
  route map" frame (91-97 ms in all three builds) are the arena/Player build
  and the combat teardown, unchanged by this card, as on FAN-3977.
- Texture memory: act-1 peak `RENDER_TEXTURE_MEM_USED` 1,407 MiB on the
  candidate and on `v0.3.1` (same pages; ≤ 1.5 GiB), main menu after the
  run 310-311 MiB in all three builds (released between runs).
- M4 cold start (exported macOS PCK, `--main-pack … --quit-after 2`, three
  runs each — `logs/cold_start.log`): candidate 1.83 / 1.74 / 1.75 s (median
  1.75), `v0.3.1` 1.82 / 1.74 / 1.73 s (median 1.74); green, unchanged.
- The FAN-3977 spawn/residency code paths are not modified; the registry
  change is one `attach` call after `sprite_frames` is assigned.

## AC4 — visual and content compatibility

- `evidence/FAN-3981/representation_probe.gd` (windowed, real renderer):
  for every one of the 42 packs it rebuilds the FAN-3977 representation in
  memory from the trim manifest (one `AtlasTexture` per unique frame over
  the same pages) and captures both through the same `AnimatedSprite2D`
  for EVERY animation and EVERY frame at the registry scale x combat zoom
  1.12, the same flipped, and at a 4K-class 1.51 factor: **38,559 captures,
  maximum per-channel difference 0/255** (byte-identical), and 2-3/255 vs
  the retained source frames on the middle frame of each animation (the
  FAN-3977 GPU interpolation rounding, tolerance 4). Logs:
  `logs/representation_probe_all.log` (19 packs), `logs/representation_
  probe_chunk_0{2..6}.log` (23 packs); table `pack_object_table.md`.
- `tests/full_frame_trim_atlas_parity_test.gd` windowed with `export=`:
  732 captures (6 animations per pack x 3 cases), 0/255 vs the
  `AtlasTexture` representation, 2/255 vs sources; side-by-side
  before/after/diff sheets for all 42 packs in `captures/` (before = the
  FAN-3977 `AtlasTexture` representation, after = shipped table).
- Unchanged by construction: game IDs, saves, 17 classes / 51 ultimates,
  8-direction and flip rules (`full_frame_eight_direction_contract_test`,
  `fan2623_shard_marshal_directional_test`, `secret_boss_animation_pack_
  smoke`, `full_frame_row_scale_invariant_test` pass), `directional_
  fallback_used`, animation names/order/loop/speed/durations (parity test
  B against the manifest), on-screen size and anchor (parity test A:
  `get_size()` is the canvas for every frame; `night_stalker_live_geometry_
  test` measures the same height/feet through the table). `data/animation/
  **` untouched. Non-full-frame (sliced rig / static) visuals untouched.

## AC5 — export stays clean

macOS PCK exports of the candidate and of `v0.3.1` on this host
(`logs/export_import_summary.md`, `EXPORT_EXIT=0`, no error lines): 27,017
vs 27,013 files, the same 280 SpriteFrames entries; the only differences
are the 42 rebuilt `*_spriteframes` binaries (smaller), the touched
scripts (`full_frame_animation_registry.gdc` plus the two new scripts and
their `.uid`), `uid_cache.bin` and `global_script_class_cache.cfg`. FAN-3973
exclusion check on the candidate PCK: 0 offending paths (no docs/tools/
tests/evidence/manifests/source sheets/runtime PNGs). Size 423,834,724 B
(404.2 MiB) vs 424,530,212 B (404.9 MiB) — smaller; the Windows Setup will
not be materially larger than the fixed 0.3.1 (418 MiB). Both PCKs start to
the main menu (600 frames) with an empty stderr (`logs/pck_start_*`); hero
select and combat run in every perf run and in `runtime_smoke_combat_test`
/ `runtime_smoke_boss_elite_test` without missing-resource errors.

## AC6 — repository gates and regression tests

- New/extended tests: `tests/full_frame_trim_atlas_parity_test.gd` — A
  (table geometry, one canvas texture per pack), D (byte-identical to the
  `AtlasTexture` representation, tolerance 0) and **G object budget**
  (loading a pack with its pages cached adds ≤ `FullFrameTrimAtlas.
  RESIDENT_OBJECT_BUDGET` = 24 objects; worst pack 21 including its 14
  pages, most 3-4). `tests/full_frame_combat_residency_test.gd` — **object
  budget per encounter roster**: the 28-pack core roster resident adds 217
  objects (budget 672) and is freed by `release_prefetched`. Consumers of
  frame pixels (`animation_smoke_test`, `night_stalker_live_geometry_test`)
  read through the table.
- `python3 tools/quality_static_guard.py --root .` — passed.
- `python3 tools/build_full_frame_trim_atlases.py --check` — OK (42 packs).
- Focused and affected suites through `tools/godot_gate.py --headless`
  (`logs/gate_*.log`, `logs/gate_batch_summary.txt`): route_map_full_frame_
  prefetch, full_frame_registry_lazy_load / integrity / shard_validation,
  full_frame_eight_direction_contract, animation_smoke, fan2623_shard_
  marshal_directional, secret_boss_animation_pack_smoke, full_frame_row_
  scale_invariant, night_stalker_live_geometry (re-run after the test's
  table read landed: passed, exit 0), asset_reference_integrity, runtime_
  smoke_combat, runtime_smoke_boss_elite, ally_minion_lifecycle, summoner_
  strengthening, feet_anchor_ground_circle, enemy_animation_priority,
  actors/{night_stalker, rift_warden, mini_void_phantom, druid_beast,
  small_biter}_smoke, full_frame_trim_atlas_parity, full_frame_combat_
  residency — all passed. Final headless re-run of the two focused suites
  on the candidate tree: `logs/final_*.log`.

## Per-pack engine object cost (41 registry packs + secret boss)

`pack_object_table.md` (from the probe: objects added while the pack is
held, pages preloaded): before = FAN-3977 `AtlasTexture` per unique frame,
after = trim table. Totals **9,122 → 167** objects for the 42 packs;
per pack 14-428 → 3-4. Examples: `ash_marksman` 185 → 4, `mini_void_
phantom` 296 → 4, `night_stalker` 353 → 4, `rift_warden` 283 → 4,
`secret_ascension_boss` 428 → 4, `druid_ghost_bear` 97 → 4.

## Files

- `perf_driver.gd`, `perf/*.json`, `perf_tables.md`, `perf_table.py`
- `representation_probe.gd`, `probe/chunk_*/representation_probe.json`,
  `pack_object_table.py`, `pack_object_table.md`
- `captures/*_before_after_diff.png` (+ `.json` summaries)
- `logs/` — gate logs, probe/perf/parity logs, `export_import_summary.md`,
  `build_trim_atlases.log`, `build_trim_atlases_check.log`, `cold_start.log`,
  `pck_start_*`; the raw 4-5 MB import/export logs and PCK file lists are
  summarised there and kept outside the repository.

## Open risks for the FAN-3964 Windows re-review

- `Performance.OBJECT_COUNT` is engine-side and platform-independent, so the
  M3 result should transfer; the Windows numbers must still be re-measured
  on FomaPC in the QA's own P2/P3 scenarios (this host's driver keeps 48
  enemies alive in P3 by default, which is heavier than the review's P3).
- Each full-frame frame change now issues one GDScript draw callback
  (`draw_texture_rect_region`) instead of the engine's built-in
  `AtlasTexture` draw. On this host frame times and FPS are unchanged with
  48 actors (M1 119 FPS, longest 26 ms); the per-call cost on the Windows GL
  path has not been measured here.
- Texture memory is unchanged (same pages), so the FAN-3977 Druid margin to
  1.5 GiB on FomaPC remains as recorded on that card.
