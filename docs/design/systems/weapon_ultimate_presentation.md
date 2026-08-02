# Weapon ultimate presentation bridge

## Scope

This bridge supplies a versioned, weapon-keyed presentation manifest for all
51 declared weapon ultimate profiles. It is a contract layer only: it neither
changes combat mechanics nor instantiates a live VFX scene. In particular, it
does not enable generic player-body attack animations; weapon-owned effects
remain separate from normal attacks.

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
The current reviewed bootstrap source for a weapon is its existing
`assets/sprites/effects/vfx_weapon_<weapon_id>.png`; it is a preflight resource
identity, not a request to play that texture as a body animation. Class-local
animation work replaces those data paths when an individual weapon becomes
ready.

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

## Timeline lifecycle and integration boundary

`WeaponUltimatePresentationTimeline` gives adapters a small testable lifecycle:

- `begin()` owns only the supplied animation, VFX, and audio handles;
- `set_paused(true)` freezes elapsed timeline time and event emission;
- `finish("cancel")`, `finish("death")`, and `finish("node_end")` release every
  supplied handle.

The class deliberately does not create nodes or modify shared pools. In a
headless run, the adapter constructs it with headless mode and receives the
deterministic `headless_no_op` result without attaching a handle.

FAN-1541 is the live-runtime enforcement owner. Its shared adapter must create
this timeline for a ready selected weapon, forward pause, and invoke `finish`
on cancel, owner death, and node teardown. That task owns the actual pooled
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
