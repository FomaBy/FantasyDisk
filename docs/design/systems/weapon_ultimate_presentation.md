# Weapon ultimate presentation bridge

## Scope

This bridge supplies a versioned, weapon-keyed presentation manifest for all
51 ready weapon ultimate profiles. It does not change combat mechanics or
enable generic player-body attack animations; the live adapter instantiates the
selected weapon-owned scene separately from normal attacks.

`docs/design/systems/weapon_ultimates_contract.md` remains the immutable source
for the existing profile, presentation, animation, VFX, SFX, and Cast lifecycle
IDs. This package derives from those IDs and must not rename them.

## Combat VFX art standard (v1.2, owner mandate 2026-08-18)

Companion to Ultimate Direction v2 (FAN-2944); mandate history and retrofit
plan live on FAN-3002. v1 banned primitives, v1.1 added per-victim impact,
v1.2 made PixelLab the only production route and extended scope to basic
attacks. The sections below are the current, merged text.

### No naked primitives in combat presentation

`ColorRect`, `Polygon2D`, untextured `Line2D` and flat `draw_*` calls
(`draw_circle`, `draw_rect`, `draw_polygon`, `draw_line`, `draw_arc`) are
banned as VISIBLE combat effects. The ban covers both authored `.tscn` nodes
and nodes constructed from GDScript at runtime. Masks and shader inputs under
a texture are allowed; a `Line2D` carrying a texture is a textured stroke, not
a naked primitive.

The rule is machine-enforced by `tests/combat_primitive_ratchet_test.gd`,
which scans combat scenes and combat scripts for both authored nodes and
runtime construction. Existing violators live in its `SCENE_ALLOWLIST` /
`SCRIPT_ALLOWLIST` — a ratchet with the same rules as
`ContactSheetBeatsContract.MIGRATION_ALLOWLIST`:

- both lists only shrink; the target state is empty;
- a violation outside the lists fails, and so does a violation count that grew
  inside them;
- a stale entry — the violator was fixed or deleted but the entry remains, or
  its count dropped — fails until the entry shrinks with the fix;
- entries record exact violation counts measured on `dev @ 13c0855d`; each
  FAN-3002 retrofit card removes its own entries.

### Production route: PixelLab animated pack → flipbook scene

Every combat visual effect — basic-attack strikes, projectiles, hits,
ultimates, per-victim impacts, cast flashes — is produced through one route.
Manual procedural effects and static single-frame stand-ins are outside it; an
exception exists only by explicit owner decision. The reference precedent is
FAN-3005 (berserk); the process replicates from it unchanged:

1. The art lane (`art_assets`, PixelLab MCP) generates an ANIMATED pack:
   6–12+ frames for bursts/impacts/auras; repeated strikes may vary the start
   frame. The PixelLab token lives only in the artist's env, never in the
   repository or comments.
2. Frames land under `assets/sprites/effects/<class>/<weapon>/<effect>/`
   together with an `<effect>_spriteframes.tres` `SpriteFrames` resource built
   from them.
3. The scene assembles the effect as a flipbook: `AnimatedSprite2D` playing
   that `SpriteFrames` resource — not a tinted primitive, not a stretched
   static sprite.
4. The scene is wired through the existing presentation manifest for its exact
   `(class_id, weapon_id)` pair. Presentation, animation, VFX and SFX IDs and
   the event phases do not change; only the scene content does.
5. Contact-sheet evidence (see "Contact-sheet beat evidence" below) is
   acceptable only when its `release`/`active`/`recovery` frames show the
   DRAWN animation frames; primitive stand-ins in a sheet fail review.

Mandatory techniques: weapon-shaped smears/arcs for melee (the weapon
silhouette IS the effect, tying into the v2 identity block); additive blending
plus glow for energy and magic; a 1–2 frame white-flash shader on the damaged
enemy; dissolve for deaths and effect expiry. Hi-res overlays stay allowed per
Direction v2. The quality bar is "bright and spectacular": saturated class
colors, glow, readable motion. Reference for "how it should look":
`assets/sprites/effects/vfx_weapon_shadow_daggers.png` and the shadow-daggers
packs; the berserk screenshot on FAN-3005 is the anti-reference.

### Per-victim impact

1. Every damaging or controlling ultimate plays a short impact ON each enemy
   it touches: a 0.3–0.6 s flipbook burst in the ultimate's style plus the
   standard 1–2 frame white flash on the victim's sprite. The victims, not a
   drawn zone, communicate the ultimate's coverage.
2. Area telegraphs are demoted: blinking rectangles and area overlays as the
   primary read are banned; a short stylized ground/ambient effect remains
   allowed as flavour.
3. Performance contract (coverage = every enemy on the map): impact instances
   are pooled; impacts stagger 3–8 frames in a wave outward from the hero
   (which also reads better); under heavy enemy counts the impact degrades to
   a reduced variant, but the white flash is never dropped.

### Basic attacks are in scope

The standard covers ALL basic-attack effects — projectiles, melee strikes and
hit effects — not only ultimates. Non-conforming effects join the FAN-3002
retrofit plan in the same per-class batches.

### Basic-attack flipbook plumbing (FAN-3010)

`scripts/attack_vfx.gd` builds every basic-attack effect and takes both routes.
`AttackVfx.effect_pack(class_id, weapon_id, effect)` is the single resolution
rule and applies the convention path literally:

```
res://assets/sprites/effects/<class>/<weapon>/<effect>/<effect>_spriteframes.tres
```

Pack present → the effect's identity figure is an `AnimatedSprite2D` playing
that `SpriteFrames`. Pack absent → the effect keeps the temporary static
stand-in it has today, unchanged. The flipbook is scaled to the stand-in's
footprint, so existing timings, blend modes, class colors and effect geometry
are untouched; a pack replaces only the identity figure, while shared glow,
shockwave, dust and note layers stay as they are.

`<effect>` is the effect family name: `weapon_signature` for the per-weapon
release cue, and `slash`, `hammer_slam`, `orb_projectile`, `projectile_trace`,
`orb_burst`, `beam`, `sound_wave_blast`, `ring_pulse`, `curse_skull` for the
nine shared families (`AttackVfx.EFFECT_FAMILIES`). The weapon-signature route
resolves its pack itself from the attacking hero's class, so an art card only
has to land the files. The nine shared families take the resolved pack as their
trailing argument, because one static family serves many weapons.

Repeated strikes may open on a varied frame; the switch is per family in
`AttackVfx.START_FRAME_VARIATION` and every family must have an explicit entry.
It is off for travelling projectiles, traces, beams and the curse skull, where a
fixed opening frame carries the read. All layers of one effect share one start
frame.

Effects still on the static stand-in live in the shrink-only allowlists of
`tests/basic_attack_flipbook_ratchet_test.gd`, with the same ratchet rules as
the primitive ratchet above: a fallback outside the lists fails, a stale entry
(its pack landed, or the entry no longer matches live content) fails, and the
target state is two empty lists. Each per-class art card removes its own
entries together with the packs it delivers.

Focused verification:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/basic_attack_flipbook_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/basic_attack_flipbook_ratchet_test.gd
```

### Combat vs UI boundary

The ban covers combat presentation only. UI and other non-combat imagery are
exempt by explicit design-review boundary, never via the ratchet allowlists:
`scripts/ui/` and `scenes/ui/` entirely, plus `scripts/ui_screens.gd`,
`scripts/route_map_screen.gd`, `scripts/pause_stats_menu.gd` (and
`scenes/PauseStatsMenu.tscn`), `scripts/enemy_health_bar.gd`, and
`scripts/cutout_rig_2d.gd` (the character-rig ground shadow is character
rendering, not a combat effect). UI primitives never enter the allowlists.
Extending the exemption list is a design decision recorded here and in the
test's `NON_COMBAT_EXEMPT_*` constants — it is not a way to ship a combat
primitive, and the grep scope must not be widened or narrowed blindly. The
scan scope is `scenes/**` and `scripts/**` for both `.tscn` scenes and `.gd`
scripts — combat ultimate scenes also live under `scripts/ultimates/classes/`;
combat code does not live outside those roots.

Focused verification:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/combat_primitive_ratchet_test.gd
```

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

**Packages that spawn nothing.** A class whose executors are static and spawn no
effect node (`beat_routing_gate_test.PRESENTATION_ONLY_PAIRS`) has no place to
put the service except the authored scene. Those executors name the enemies a
beat actually damaged in a `victims` payload entry on the beat they already
emit, and the scene's `present(event_id, payload)` opens the ripple on exactly
that set — the first beat calls `play()`, later beats `enqueue()`. A beat that
damaged nobody carries an empty list and draws nothing, so an unaffected target
can never receive a burst. Only the live run draws: the mechanics chain outlasts
the presentation, so a scene drops a beat that arrives once its own timeline has
ended instead of opening a ripple nothing would tick. One enemy named twice in a
payload is still one hit and takes exactly one burst. Doctor is the reference
implementation.

**Pause.** `UltimateVictimImpactPlayer.set_paused()` disables the whole subtree
rather than only its `_process`: every live burst is a child flipbook playing on
its own clock, so stopping the queue alone leaves the drawn frames running
through the pause.

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

**Wiring the service is a gate (FAN-2944).** `victim_impact` checks every
weapon separately. It accepts only a `victim_impact_player.gd` preload followed
by construction of `UltimateVictimImpactPlayer` in that weapon's executor or a
script attached to its declared activation scene. Comments, inert strings and
unrelated scripts do not count; a missing route reports
`victim_impact.unwired: <class>/<weapon>`. The class ratchet only lists weapons
that genuinely lack the route and fails stale entries closed.

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

## Precedent assembly record: berserk trio (FAN-3012)

The berserk rebuild was the first card to walk the full v2 route — flipbook
scenes, zero visible primitives, per-victim impacts, the 2.5–4.0 s corridor —
end to end. What follows is what the route actually took, in the order the
work happened, with the parts that were not obvious from this document alone.

### Real step order (differs from the nominal route above)

1. **Timings first, scenes second.** The corridor is not a scene-only
   constraint: `tests/ultimates/mechanics/berserk_package_test.gd` binds each
   executor's `lifetime` to the manifest `timing_seconds.recovery`, and the
   timing-distinctness test enforces the v2 envelope the moment a pair leaves
   `PRESENTATION_V2_MIGRATION_ALLOWLIST`. Pick all five beats per weapon
   BEFORE drawing anything: total 2.5–4.0 s, windup window (release − windup)
   0.6–1.0 s, active window (recovery − release) ≥ 1.2 s, and pairwise
   distinct `cancel` and `recovery − active` axes ≥ 0.1 s inside the trio.
2. **Compressing the presentation lifetime compresses mechanics.** Because of
   the lifetime↔recovery binding, moving the berserk trio into the corridor
   changed executor params (sweep count, beat intervals, cooldowns). Keep the
   balance coefficients stable while re-timing: the sword kept its frozen
   6-bite/137-damage solo coefficient by trading 11 sweeps at 0.55 s for
   6 sweeps at 0.45 s with a 1.3 s blade cooldown. The frozen-literal
   expectations in the mechanics tests (`EXPECTED` block, live-test advance
   amounts) are part of the change and must be re-pinned in the same commit.
3. **Retire the ratchets in the same change.** Three ratchets keyed the old
   berserk state and all fail stale simultaneously: the scene-primitive
   allowlist in `tests/combat_primitive_ratchet_test.gd`, the v2 migration
   allowlist in `weapon_ultimate_presentation_schema.gd`, and the
   `quality` gap in `UltimateVisualDirectionContract.ADOPTION_GAPS`. A card
   that leaves one of them behind fails CI on the next run.
4. **Scene assembly.** One shared driver per class (`berserk_ultimate_v2_driver.gd`,
   the chemist FAN-2958 pattern with exported beats) plus flipbook nodes:
   cast flash, one looping identity pack, beat-layered pulses, a fullscreen
   backdrop veil (`Sprite2D` + radial `GradientTexture2D`, metadata
   `fullscreen_layer=true` — the veil must be excluded from capture bounds,
   see the gotcha below). Frame tracks are discrete (`update = 1`) so a
   `seek(t, true)` in a contact sheet reproduces the exact drawn frame.
5. **Per-victim impacts through the shared service.** One
   `UltimateVictimImpactPlayer` per effect instance; the first beat calls
   `play()`, every later beat `enqueue()` — a multi-beat activation lands
   beats closer together than one ripple spans, and `play()` would drop the
   queued wave. The service's outward-wave read is measured on spawn order:
   the joined beat must queue after the running wave, and its sort must be
   stable within equal delays.

### Real names of the evidence artifacts

- Contact sheets (windowed, one per resolution):
  `docs/design/references/weapon_ultimates/berserk/berserk_ultimate_timelines_{648p,720p,1080p,2k}.png`
  regenerated by
  `tests/ultimates/presentation/berserk_ultimate_contact_capture.gd`.
- Runtime motion strip (spinning/expanding proof across sampled beats):
  `docs/design/previews/fan3012_berserk_frame_strip.png` from
  `tools/capture_fan3012_berserk_frames.gd`.
- Pack provenance: `docs/design/references/weapon_ultimates/berserk/provenance_manifest_fan3005_trio.json`.

### Gotchas the nominal route does not say out loud

- `capture_content_bounds` in the class timeline test must skip nodes with
  `metadata/fullscreen_layer = true`, or the veil's world-space fit rect
  swamps the panel auto-fit and every composition check fails.
- The class-local manifest is the single source the bridge reads: `presence`,
  `identity`, `packs_fan3005`, `timing_rhythm`, material budgets and quality
  records live in the weapon record of
  `docs/design/references/weapon_ultimates/<class>/manifest.json`, not in the
  registry profile. The registry profile's `presentation` block stays frozen.
- Identity `weapon_silhouette_asset` must be a real frame of the weapon's own
  pack and unique per pair — a shared generic burst frame fails closed in the
  catalog validation.
- Regenerating a contact sheet runs the scene's driver `_process`, which fits
  the veil to the SubViewport: run captures windowed exactly like the class
  capture script does, never headless.
- The scene-primitive ratchet can be red on `dev` for reasons outside your
  card (it was during FAN-3012: chemist/engineer/legacy entries). Verify your
  own entries are gone with a stashed run before claiming the suite green;
  report unrelated drift instead of retiring other cards' entries.
