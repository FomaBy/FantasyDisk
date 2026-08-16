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
catalog against the registry rather than accepting a class fallback.

Pairwise timing distinctness within a class is part of this presentation
contract: every weapon pair must differ by at least `0.1` seconds in both total
length (`cancel`) and active window (`recovery - active`). The shared
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
```

The first test verifies all 51 immutable presentation IDs and the fixture
cleanup, pause, and headless obligations. The mutation suite separately proves
missing/duplicate phases, missing assets, duplicate IDs, placeholder reuse,
invalid paths, pivots, and timing fail closed.

Every class-local presentation package must machine-check the measured title
and panel-label rectangles against their sheet or panel bounds at 648p, 720p,
1080p, and 2K before its contact-sheet evidence is accepted. The shared
`tests/ultimates/presentation/contact_sheet_text_fit.gd` helper keeps capture
layout and the focused-test oracle on the same fallback-font measurements.
This geometric check cannot detect renderer-only divergence such as a
capture-side `Label` offset or a different fallback font, so a windowed pixel
review remains mandatory after any theme, font, or renderer change.
