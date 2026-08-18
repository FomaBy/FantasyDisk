# Weapon ultimate presentation bridge

## Scope

This bridge supplies a versioned, weapon-keyed presentation manifest for all
51 ready weapon ultimate profiles. It does not change combat mechanics or
enable generic player-body attack animations; the live adapter instantiates the
selected weapon-owned scene separately from normal attacks.

`docs/design/systems/weapon_ultimates_contract.md` remains the immutable source
for the existing profile, presentation, animation, VFX, SFX, and Cast lifecycle
IDs. This package derives from those IDs and must not rename them.

## Manifest contract

`WeaponUltimatePresentationManifest.catalog_for_registry()` creates one entry
per exact `(class_id, weapon_id)` profile. Each entry uses
`key = { weapon_id, action = ultimate }`, retains the registry presentation IDs,
and has these required event phases:

1. `windup`
2. `release`
3. `active` or `impact` (exactly one)
4. `recovery`
5. `cancel`

The event phase IDs are references to the immutable Cast lifecycle: release
uses `execute`, recovery uses `recover`, and cancel uses `cleanup`. Thus the
presentation naming introduces no parallel or renamed cast lifecycle.

The manifest also carries per-channel animation/VFX/SFX IDs, source and runtime
paths, normalized pivot, monotonic phase timing, and `headless_fallback = no_op`.
Its source and runtime path is the accepted class-local scene for the exact
class/weapon pair; a generic `vfx_weapon_<weapon_id>.png` bootstrap is not a
valid substitute. Class-local animation work provides those data paths for the
ready profile.

`WeaponUltimatePresentationSchema` fails closed for a missing resource,
duplicate presentation/animation/VFX/SFX ID, placeholder reuse, invalid source
or runtime path, and invalid pivot or timing. It validates the full 51-entry
catalog against the registry rather than accepting a class fallback. The v2
envelope, presence and identity requirements below fail closed the same way,
ratcheted by `PRESENTATION_V2_MIGRATION_ALLOWLIST`.

## Presentation envelope v2 (FAN-2944 §1)

Timing values are cumulative beat timestamps on one timeline, so every v2
range below is a beat difference. For each `(class_id, weapon_id)` pair that
has left the migration allowlist:

- total presentation (`cancel - windup`) is `2.5–4.0 s`;
- the windup cast ceremony (`release - windup`) is `0.6–1.0 s`;
- the release burst plus the `active`/`impact` window (`recovery - release`)
  covers at least `1.2 s`;
- recovery is visible: `cancel - recovery` is strictly greater than zero.

The envelope is enforced twice on the same numbers:
`WeaponUltimatePresentationSchema.v2_envelope_errors()` inside catalog and
manifest validation, and the shared timing distinctness test on the class
timing declarations. The `10.0 s` schema timeline ceiling stays the absolute
bound for v1 and v2 alike.

Pairwise per-class distinctness is preserved unchanged by v2: every weapon
pair still differs by at least `0.1` seconds in both total length (`cancel`)
and active window (`recovery - active`), for allowlisted and migrated pairs
alike.

## Two independent clocks

`2.5–4.0 s` is the PRESENTATION envelope: how long the cast ceremony, effect
and recovery stay on screen. It does not shorten and must never be asserted
against the `control_save` gameplay window (`>= 4.0 s` in
`weapon_ultimate_balance.md`). A `control_save` ultimate keeps its gameplay
effect (slow, shield, zone) active for `>= 4.0 s` while its presentation
timeline may already have finished; the two clocks are independent and no
harness may compare one against the other.

## Full-screen presence and weight (FAN-2944 §3.1)

A migrated pair declares a `presence` block in its class-local
`manifest.json` weapon record; the bridge passes it through and the schema
fails closed exactly like the pivot/timing checks on a missing or
out-of-range declaration:

- `fullscreen_footprint: true` — the VFX footprint spans the arena/viewport
  (delivered translucently; the opaque-coverage and HUD-band caps below stay
  binding);
- `backdrop: "darken" | "flash"` — full-screen backdrop treatment;
- `camera_shake: true`;
- `hitstop_ms` — `80–150` on the first impact;
- `time_scale_dip` — optional; when declared, `0.3–0.5`x at the windup peak;
- `sfx_ducking: true` — other SFX duck during release.

Hitstop, camera shake, time-scale dip and SFX ducking are node-free runtime
effects: they declare weight, not extra visual nodes.

## Identity (FAN-2944 §3.1)

A migrated pair also declares an `identity` block; each field fails closed
when missing, placeholder-like, or reused where reuse is forbidden:

- `cast_pose_id` — the hero-specific cast pose. One class may share it across
  its weapon trio; a second class reusing it fails closed;
- `weapon_silhouette_asset` — an existing `res://` asset whose weapon
  silhouette is the visual core of the effect. A generic burst asset reused
  across two different `(class_id, weapon_id)` keys fails closed
  (`presentation.v2.generic_burst`);
- `class_palette_id` — the class palette the effect resolves its colors from.

## PRESENTATION_V2_MIGRATION_ALLOWLIST

Turning the v2 ranges on without a ratchet would make `dev` red for every
already-merged v1 package until all 51 are reworked, so the v2 contract ships
behind `WeaponUltimatePresentationSchema.PRESENTATION_V2_MIGRATION_ALLOWLIST`,
a ratchet with the same rules as `ContactSheetBeatsContract.MIGRATION_ALLOWLIST`
and the timing test's `PARITY_EXEMPTIONS`:

- it is seeded with every `(class_id, weapon_id)` pair shipped under v1 and
  only ever shrinks; its target state is empty;
- an entry for a pair that already satisfies the full v2 contract fails as
  stale;
- an entry naming no registry pair, or stating no reason, fails;
- a pair outside the allowlist is asserted against the full v2 contract and
  fails closed.

Each animation or rework card removes its own entry when its pair reaches v2.
Stale-entry detection runs in catalog scope (tests) only, so the runtime
single-manifest path never rejects a live activation over the ratchet itself.

## Per-effect budget for a full-screen 2.5–4.0 s effect

Re-derived for the v2 scale from the enforced constants in
`UltimateVisualDirectionContract` and the orphan/budget history in this area
(FAN-2350, FAN-2359, FAN-2431/FAN-2452):

- **Visual nodes** — *machine-gated, declaration and actual count*: the
  per-activation ceiling stays `32` drawn nodes (`MAX_VISUAL_NODES_CEILING`),
  with declared `max_visual_nodes <= crowd_cap <= 32`. The live roster peaks at
  26 drawn nodes; the v2 backdrop treatment and first-impact flash consume at
  most 2 of the 6 headroom nodes as screen-space layers, and the
  weapon-silhouette core replaces the v1 core nodes rather than adding to them.
  A longer envelope raises on-screen time, not concurrency, so the ceiling does
  not grow. The declaration is validated by
  `UltimateVisualDirectionContract._check_budget()`; the actual drawn count is
  rejected live by `WeaponUltimatePresentationRuntime._within_declared_budget()`
  and asserted on the instantiated scene by
  `weapon_ultimate_presentation_budget_test.gd`.
- **Materials** — *machine-gated for every pair outside
  `PRESENTATION_V2_MIGRATION_ALLOWLIST`, declaration and actual count*: at most
  `16` unique materials/shaders per activation
  (`MAX_UNIQUE_MATERIALS_CEILING`), of which at most `2` may cover the full
  viewport (`MAX_FULLSCREEN_MATERIALS_CEILING`, the backdrop darken/flash
  layers). This bounds 2K fill-rate and batch count over the longer
  `2.5–4.0 s` window; nodes share materials rather than instancing per node. A
  migrated pair declares `max_unique_materials` and `max_fullscreen_materials`
  in its manifest `performance` block and in its scene metadata; a missing,
  non-positive or above-ceiling number fails closed, and so does a full-screen
  count larger than the unique count it is drawn from. The actual counts are
  measured off the instantiated scene by
  `UltimateVisualDirectionContract.material_counts()` and asserted against the
  declared budget. A pair still inside the allowlist is v1 and owes no material
  declaration, so the rule binds exactly when a rework card takes its pair out
  of the ratchet — one shrinking list, not two.
- **Allocations** — *review-gated*: one `PackedScene` instantiation per
  activation, performed before gameplay activation; zero node or material
  allocations during `release`/`active`/`recovery`; every animation/VFX/SFX
  handle is released at `finish` (`cancel`, `death`, `node_end`) with zero
  orphan handles. Only the handle release is machine-proven, and on timeline
  fixtures; the per-phase allocation counts are not asserted.
- **Readability** — *declaration machine-gated, rendered result review-gated*:
  opaque coverage of one activation stays `<= 0.35` of the viewport
  (`MAX_VIEWPORT_COVERAGE_RATIO`) and the HUD bands stay clear, so full-screen
  presence is delivered by the translucent backdrop plus an arena-wide but
  non-opaque footprint. `_check_quality()` range-checks the declared
  `max_viewport_coverage_ratio` and requires `hud_bands_clear`; nothing measures
  the coverage a frame actually renders, so the contact sheets stay the
  evidence for it.

### What "covers the full viewport" means to the material gate

A material counts as full-screen when it is carried by a `CanvasItem` under a
`CanvasLayer` inside the activation scene: screen space is the one
full-viewport property readable off an instantiated scene without rendering it,
because such a layer draws in viewport coordinates whatever the camera does. A
v2 backdrop or first-impact flash therefore has to be authored as a
`CanvasLayer` child, which is what makes it a screen-space layer in the first
place.

The rule is deliberately narrow. It over-counts a small screen-space overlay —
strict in the fail-closed direction — and it cannot see a world-space node
scaled over the viewport, a material created during `begin()`, or a shader that
only becomes full-screen at runtime. Those remain review-gated: the counted
surface is the authored tree's canvas materials plus `GPUParticles2D` process
materials, nothing else.

Reduced-motion and photosensitivity remain mandatory and are satisfiable at
the v2 scale: the reduced-motion substitute keeps its phase timing (so the
envelope holds), replaces camera shake and the time-scale dip with static
treatments, and renders `backdrop: "flash"` as a one-shot; flashes stay under
the WCAG 2.3.1 `3 Hz` threshold and a repeating flash may not exceed `0.25`
viewport coverage. A `darken` backdrop plus silhouette core meets every cap.

Pairwise timing distinctness within a class is part of this presentation
contract (v2 keeps it unchanged, see above). The shared
`weapon_ultimate_timing_distinctness_test.gd` puts every class directory in one
named bucket: `checked` when it reads `weapons[].timing_seconds` or an existing
`scenes/vfx/ultimates/<class>/*.timeline.json` `manifest.timing`; `skipped` only
when neither source declares timing; or `uncovered` when a declared source
cannot be read. `uncovered` is fail-closed and fails the test with the class and
reason, so no presentation package can disappear silently from this invariant.
Class-local packages may keep additional, stricter checks.

Manifest timing is only trusted when a second authoritative in-repo source
agrees with it field by field. The test resolves that source per class in a
fixed order: the `*.timeline.json` set first, otherwise the class-local
`scenes/vfx/ultimates/<class>/<class>_ultimate_presentation_pack.gd` `WEAPONS`
map, whose per-weapon `timing` block carries the same five phase seconds. A
class that ships neither is not silently accepted; it must hold an explicit
entry in the test's `PARITY_EXEMPTIONS` map stating why, and every run prints
the parity-covered weapon count together with the exempt classes and reasons.

`PARITY_EXEMPTIONS` is a ratchet with the same rules as
`ContactSheetBeatsContract.MIGRATION_ALLOWLIST`: it only shrinks, an entry for a
class that has since gained a timeline or a presentation pack fails as stale, an
entry naming no class package or stating no reason fails, and a class outside it
without a second source fails closed. Adding a timeline or a presentation pack
to an exempt class is therefore the only way to raise parity coverage, and doing
so forces its exemption out of the map.

## Contact-sheet beat evidence

A contact sheet is evidence of the stated impact language, not an illustration.
Every weapon that has left the migration allowlist declares at least one
frame-local beat for each of `release`, `active`, and `recovery`; each frame
records its numeric capture time and its own non-empty `required_nodes` list.
Nodes therefore belong to the specific visible frame, never to one flat package
list. Capture labels must use measured text width and fit their frame bounds.

`ContactSheetBeatsContract` is the one shared declaration surface and
`weapon_ultimate_contact_sheet_beats_test.gd` auto-discovers every class/weapon
from the immutable profile registry. `MIGRATION_ALLOWLIST` contains the
unconverted classes; it only shrinks and its target state is empty. A class
outside it fails closed on a missing phase or frame-local node requirement, and
a complete declaration left inside it fails as a stale ratchet entry.

## Per-victim impact (FAN-3008)

The activation scene owns the caster-side spectacle; the hit itself is read on
each victim. `UltimateVictimImpactPlayer`
(`scripts/ultimates/presentation/victim_impact_player.gd`) is the one service
every ultimate scene uses for that, so a retrofit card wires three lines and
nothing else:

```gdscript
var impacts := UltimateVictimImpactPlayer.new()
add_child(impacts)                                   # freed with the scene
impacts.play(impact_frames, hit_enemies, cast_position)
```

- `play(frames: SpriteFrames, victims: Array, cast_position: Vector2) -> Dictionary`
  schedules one burst per victim and returns the plan (`stagger_frames`,
  `degraded`, `burst_seconds`, node counters) for activation diagnostics.
  `frames` is the class impact pack; art ships it, this service never
  substitutes a placeholder.
- The node ticks itself in `_process`; a headless fixture calls
  `advance(delta)` instead. `finish()` releases every burst and frees the pool.
  `snapshot()` returns the same diagnostic Dictionary at any time.
- Each victim gets the **existing** white flash: the service calls the enemy's
  own `_show_hit_flash()`, gated by its own `_combat_feedback_enabled()`. It
  draws no flash of its own and never skips one — the flash fires before the
  burst node is even acquired, so pool pressure and degradation cannot take it
  away. Both names are asserted by the budget test. A public wrapper on
  `Enemy` would be the nicer entry point, but `scripts/enemy.gd` sits exactly on
  its shrink-only line ratchet, so it belongs to the card that splits that file.

**Ripple.** Victims are sorted by distance from the cast point and split into at
most 8 distance waves; consecutive waves are staggered by 3-8 frames
(`RIPPLE_BUDGET_FRAMES / (waves - 1)`, clamped), so the impact reads as one wave
leaving the hero and a large crowd never stretches the ultimate.

**Budget.** Impact sprites are victim-side feedback in the same contour as the
enemy hit flash, not part of the activation's declared `max_visual_nodes`. Their
ceiling is the pool: a map-wide ultimate creates at most `POOL_CAP` nodes at any
crowd size, and reuses them for the rest. Both constants are measured, not
chosen — the sweep is reprinted by
`tests/ultimates/presentation/weapon_ultimate_presentation_budget_test.gd` on
every run (60 fps steps, victims placed farthest-first):

| victims | created nodes | peak concurrent bursts | stagger | degraded |
| --- | --- | --- | --- | --- |
| 1 | 1 | 1 | 3 | no |
| 8 | 5 | 5 | 6 | no |
| 24 | 15 | 15 | 6 | no |
| 38 | 24 | 24 | 6 | no |
| 48 (`max_active_cap`) | 24 | 24 | 6 | yes |

- `POOL_CAP = 24` — the measured peak of the reduced variant at the largest
  scenario crowd (48 = `main.gd` `WAVE_SETTINGS.max_active_cap`), which stays
  inside the 32-node crowd ceiling one activation may already draw.
- `DEGRADE_VICTIM_THRESHOLD = 38` — measured: 38 victims still peak at 24
  full-size bursts, 39 peak at 25 and would force the pool to cut a live burst
  short. Above the threshold the reduced variant runs (0.60 scale, 0.30 s
  instead of 0.45 s, i.e. fewer frames at the same rate), which brings the peak
  back to 24 at 48 victims. The pool therefore recycles nothing anywhere in the
  scenario range.

Only the scheduling half is machine-measured; GPU fill-rate of the shipped
impact packs stays review-gated, like the rest of the rendered result.

**Area telegraphs are flavour, not the read.** Because the hit now reads on the
victim, a blinking area rectangle may no longer be how an ultimate shows its
reach. `UltimateVisualDirectionContract.scene_telegraph_violations()` walks an
instantiated activation and fails closed when an area rectangle (a world-space
`Line2D`/`Polygon2D` rectangle, `ColorRect`/`ReferenceRect`, or a node in the
`ultimate_area_telegraph` group) is the only drawn effect
(`telegraph.only_read`), is more than half the drawn nodes
(`telegraph.dominant`), or alternates visibility three or more times in one
animation (`telegraph.blink`). A single fade in and out beside real effects is
two alternations and stays allowed.

## Timeline lifecycle and integration boundary

`WeaponUltimatePresentationTimeline` gives adapters a small testable lifecycle:

- `begin()` owns only the supplied animation, VFX, and audio handles;
- `set_paused(true)` freezes elapsed timeline time and event emission;
- `finish("cancel")`, `finish("death")`, and `finish("node_end")` release every
  supplied handle.

The class deliberately does not create nodes or modify shared pools. In a
headless run, the adapter constructs it with headless mode and receives the
deterministic `headless_no_op` result without attaching a handle.

The live-runtime adapter creates this timeline for a ready selected weapon,
forwards pause, and invokes `finish` on cancel, owner death, and node teardown.
It rejects a missing exact scene or a visual-node count beyond the declared
per-effect cap before gameplay activation. That adapter owns the actual
animation/VFX/audio handles and live-combat orphan-handle verification; this
contract proves the obligation on fixture handles without changing shared VFX
pooling.

## Focused verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation_contract_validator_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/weapon_ultimate_timing_distinctness_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/weapon_ultimate_contact_sheet_beats_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/weapon_ultimate_presentation_budget_test.gd
```

The budget test additionally owns the per-victim impact contract: it prints the
pool/degradation sweep above, asserts the flash fires once per victim in every
mode, and proves the area-telegraph gate goes red on a scene whose blinking
frame is the read.

The first test verifies all 51 immutable presentation IDs, the migration
allowlist integrity, and the fixture cleanup, pause, and headless obligations.
The mutation suite separately proves missing/duplicate phases, missing assets,
duplicate IDs, placeholder reuse, invalid paths, pivots, and timing fail
closed, and carries one negative control per v2 assertion (envelope, presence,
identity, ratchet) so every new check is proven able to go red.

Every class-local presentation package must machine-check the measured title
and panel-label rectangles against their sheet or panel bounds at 648p, 720p,
1080p, and 2K before its contact-sheet evidence is accepted. The shared
`tests/ultimates/presentation/contact_sheet_text_fit.gd` helper keeps capture
layout and the focused-test oracle on the same fallback-font measurements.
This geometric check cannot detect renderer-only divergence such as a
capture-side `Label` offset or a different fallback font, so a windowed pixel
review remains mandatory after any theme, font, or renderer change.
