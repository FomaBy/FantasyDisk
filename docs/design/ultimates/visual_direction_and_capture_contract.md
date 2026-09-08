# Visual direction and live-capture contract for the 51 weapon ultimates

FAN-2517. The common quality bar that makes every ultimate unmistakable on
screen while keeping the three weapons of a class distinct from each other.

`scripts/ultimates/presentation/ultimate_visual_direction_contract.gd` owns every
threshold quoted here; this document explains them. The focused gate is
`tests/ultimates/presentation/visual_direction_contract_test.gd`:

```bash
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/visual_direction_contract_test.gd
```

The contract validates declarations in
`docs/design/references/weapon_ultimates/<class>/manifest.json` and the capture
files those manifests point at. It never instantiates a presentation scene:
live budget enforcement stays in `WeaponUltimatePresentationRuntime`,
phase/pivot/asset binding stays in `WeaponUltimatePresentationSchema`, and
timing parity stays in the contact-sheet beats and timing-distinctness gates.
This contract adds only what none of them cover.

`doctor` is the reference implementation — the one package that satisfies every
gate today, and the example a class package copies from.

## The five phases

Every ultimate declares the same five phases, in this order, in
`timing_seconds` as absolute seconds from activation:

| Phase | Meaning | Bound cast-phase id |
| --- | --- | --- |
| `windup` | the tell: the player and everyone nearby can see it is coming | `…windup` |
| `release` | the commitment frame; the point of no return | `…execute` |
| `active` | the effect doing its work | `…active` |
| `recovery` | the effect resolving; no new commitment | `…recover` |
| `cancel` | cleanup; also the path taken on interrupt, pause-abort and death | `…cleanup` |

Gates (`phases.*`, `cleanup.*`):

- all five keys present, numeric, never running backwards;
- `windup` is exactly `0.00` — the timeline is measured from activation;
- `cancel` never exceeds `10.0 s`, matching the presentation schema ceiling;
- `cancel` is strictly greater than `recovery`. A cleanup phase that shares its
  timestamp with recovery is a zero-length window: nothing can tear down on an
  interrupt, so the effect outlives its own cast;
- each `phase_ids` entry ends with the frozen registry suffix for its phase, so
  presentation and the registry cannot drift apart.

## Sibling distinctness

Each weapon declares three free-text direction fields, and the three weapons of
a class must differ on all of them (`direction.*`):

- `silhouette` — what shape reads at a glance, before colour;
- `motion_path` — how that shape travels;
- `impact_language` — how the hit resolves.

Two weapons of a class sharing any of the three means a player cannot name which
ultimate fired. Timing separation inside a trio is a separate, already-shipped
gate (`weapon_ultimate_timing_distinctness_test.gd`); this one is about reading
the effect, not its rhythm.

## Live captures

Every class package commits one contact sheet per supported viewport, rendered
from the running scene by the script named in `evidence.capture_script`
(`capture.*`):

| Slot | Size | Why |
| --- | --- | --- |
| `_648p.png` | 1152x648 | worst case: the smallest window the game supports |
| `_720p.png` | 1280x720 | the common laptop window |
| `_1080p.png` | 1920x1080 | the fallback fullscreen resolution |
| `_2k.png` | 2560x1440 | the default fullscreen resolution |

`evidence.contact_sheets` lists exactly four paths, one per slot, and each file
must be a PNG of exactly that pixel size. The size is read from the PNG header,
so a sheet re-captured at the editor window size fails even when it looks right.
A capture that no committed script can reproduce is not evidence, so
`capture_script` must name a file that exists.

Readability is judged on the 648p sheet: if the effect is not legible there, it
is not legible.

## Asset provenance

PixelLab (MCP) is the required source for isolated sprites, character and
creature frames, and transparent VFX animation frames. The built-in Image
Generator produces full-canvas images and may not stand in for it.

`generator_provenance` declares which route a package took (`provenance.*`):

- **new PixelLab frames** — `new_pixellab_assets` is non-empty, and `route` says
  `pixellab`;
- **reuse of already-accepted assets** — `new_pixellab_assets` is empty, `route`
  says `reused`, and `reused_sources` records what was reused. A package that
  generated nothing and reuses nothing has no provenance at all;
- **the full-canvas exception** — the one narrow case where the built-in Image
  Generator is admitted: a genuinely full-canvas cinematic underlay or impact
  plate. It is declared explicitly in `full_canvas_exception`, which must name a
  real class `weapon_id`, give a `reason`, set `full_canvas` to `true`, and set
  `transparent_frames` to `false`. An exception claiming transparent frames is
  rejected — that is precisely the substitution the rule exists to prevent.

No live class uses the exception today; the gate's red path is proven by fixture.

## Readability, reduced motion and photosensitivity

Each weapon declares a `quality` block. These are declared caps, like
`performance.max_visual_nodes`, reviewed against the committed captures:

| Field | Gate | Meaning |
| --- | --- | --- |
| `max_viewport_coverage_ratio` | `> 0`, `<= 0.35` | fraction of the viewport the effect may cover opaquely at its widest frame |
| `hud_bands_clear` | must be `true` | the effect never occludes the HUD bands |
| `reduced_motion_substitute` | non-empty | the non-motion cue that carries the beat when motion is reduced |
| `reduced_motion_preserves_timing` | must be `true` | the reduced-motion variant keeps the same phase timing |
| `full_screen_flash_hz` | `0.0 … 3.0` | full-screen flash rate; `3.0` is the WCAG 2.3.1 general flash threshold |
| `max_flash_coverage_ratio` | `0.0 … 1.0` | flash coverage; above `0.25` a repeating flash is refused outright |

The reduced-motion variant is a *variant*, not a second timeline: it may replace
a motion cue with a contrast or colour cue, but it may not retime the cast,
because the phase timing is what the player reads and what QA measures.

Doctor's declared caps come from its own scene geometry
(`doctor_ultimate_timeline_scene.gd`) measured against the smallest supported
viewport: the 126 px poison-pool ring covers ≈0.09 of 1152x648, the plague waves
peak at ≈224 px radius for ≈0.27, and the 112 px saw orbit covers ≈0.07. None of
the three scenes drives camera shake or a full-screen flash, so both flash
values are `0.0`.

## Performance budgets

Per weapon, in `performance` (`budget.*`): `max_visual_nodes` and `crowd_cap`
are positive whole numbers, `max_visual_nodes` never exceeds `crowd_cap`, and
neither exceeds **32**. The live roster peaks at 26 drawn nodes, so the ceiling
keeps working headroom while bounding what a single activation may add on top of
a crowd. `WeaponUltimatePresentationRuntime` counts the real drawn nodes against
the same declared numbers and fails closed.

## Adoption

Adoption state is class-owned data. Each class commits one shard at
`data/ultimates/classes/<class_id>/presentation_adoption.json`:

```json
{"schema_version": 1, "class_id": "thief", "adoption_gaps": {"quality": "reason"}}
```

`adoption_gaps` maps a gate to the reason the class does not satisfy it yet; a
fully adopted class commits `{}`. The contract reads every class directory
under `ADOPTION_SHARD_ROOT` through `load_adoption_shards()` and exposes the
aggregate as `ADOPTION_GAPS`, gate → `{class_id → reason}` with every gate
present, which is what the roster gate and the per-class suites read. A class
adopts a gate by deleting the entry from its own shard; the shared contract is
not edited for that.

The loader fails closed and reports `adoption.<code>` violations: a class
directory without a shard (`shard_missing`), an unparsable shard
(`shard_parse`), a shard whose `class_id` is not its directory
(`shard_class_mismatch`) or names a class another shard already declared
(`shard_duplicate`), any key outside `schema_version` / `class_id` /
`adoption_gaps` (`shard_field`, so a shard cannot restate a ceiling or a
budget), a wrong `schema_version`, an unknown gate, an empty reason, and an
exemption outside the shared ceiling (`gap_not_admitted`). A rejected shard or
entry contributes nothing, so broken class data can never exempt a class; its
real failures then surface as `adoption.unlisted`.

`ADMITTED_ADOPTION_GAPS` in the contract is the ratchet ceiling: per gate, the
widest set of classes whose shard may still claim an exemption. Like
`ContactSheetBeatsContract.MIGRATION_ALLOWLIST` it only shrinks. A shard may
drop an admitted pair once the class adopted the gate, but it can never add
one, so class data cannot widen the shared budget, coverage or flash ceilings
by exempting itself. `adoption_violations()` keeps the ratchet honest in both
directions: an exemption for a gate the class already passes is `adoption.stale`,
a failing gate without an exemption is `adoption.unlisted`. The focused gate is
`tests/ultimates/presentation/adoption_shards_test.gd`; the roster gate in
`visual_direction_contract_test.gd` still checks the aggregate against every
manifest. The shard name is reserved in `WeaponUltimatePackageDiscovery` and
`tools/ultimate_feature_list_check.py`, which pair every other JSON in a class
directory with a weapon executor and a catalog identity. Roster-wide adoption
belongs to the per-class animation cards, not to this contract.

Current state — the roster gate prints this every run:

| Gate | Conforming | Pending |
| --- | --- | --- |
| `phases` | 16/17 | thief |
| `cleanup` | 17/17 | — |
| `budget` | 17/17 | — |
| `direction` | 16/17 | thief |
| `capture` | 16/17 | thief |
| `provenance` | 16/17 | thief |
| `quality` | 7/17 | assassin, druid, elementalist, guitarist, knight, priest, ranger, robot, soldier, thief |
| `victim_impact` | 17/17 | — |
| `telegraph` | 17/17 | — |

thief still ships the legacy asset-pipeline manifest shape (no per-weapon
`phase_ids`, direction fields or `generator_provenance`) and a single wide
contact strip instead of the four viewport captures.
