# Engineer ultimate certification readability report (FAN-3939)

This package certifies the canonical Engineer trio with 48 individual native
runtime frames: 3 weapons × 4 requested views × 4 viewport sizes. Exact source
commit/tree, Godot/renderer identity, controlled seed, windowed command and
one SHA-256 per image are recorded in
`certification_capture_manifest.json`; the final candidate SHA is intentionally
kept out of that document so capture provenance is not self-referential.

## Evidence layout

Each PNG is a single isolated `SubViewport`, not a 3×4 contact sheet. Its
filename encodes `viewport / weapon / mode / beat`, so art, HUD, hazard and
target content cannot bleed into a neighboring evidence cell or cover a shared
caption. All frames retain their native dimensions:

| Viewport | Native dimensions | Frames |
|---|---:|---:|
| 648p | 1152 × 648 | 12 |
| 720p | 1280 × 720 | 12 |
| 1080p | 1920 × 1080 | 12 |
| 2k | 2560 × 1440 | 12 |

## Runtime composition

Every frame runs the same shipped context before it is frozen for readback:

- `GameSettings.DEFAULTS` is copied through
  `UltimateAccessibilitySettings.apply_settings` before casting; the mounted
  Engineer driver reads that normalized root snapshot.
- `Player.tscn` is configured as Engineer with the canonical weapon, receives
  a full ultimate charge, and starts the cast through `Player.activate_ultimate`.
- Actual `EnemySpitter.tscn` targets are used (3 normally, 39 for the crowded
  load condition). An actual target invokes `_spawn_elite_hazard`, yielding an
  `ElitePoisonZone` with its shipped `HazardTelegraph`.
- `UltimateHudRuntimeAdapter` mounts the shipped `UltimateHudWidget`, whose
  selection and active charge state are read from that same Player.

| View | Persisted production settings | Real targets | Captured beat | Review focus |
|---|---|---:|---|---|
| normal | reduced motion off; photosensitivity safe off | 3 | active | authored animation, normal release weight and active formation |
| crowded | reduced motion off; photosensitivity safe off | 39 | release | real crowd target load and bounded victim feedback |
| reduced motion | reduced motion on; photosensitivity safe off | 3 | active | Engineer driver's held, no-shake/no-hitstop production branch |
| photosensitivity safe | reduced motion off; photosensitivity safe on | 3 | recovery | held safe visual and bounded real damage-feedback path |

The four views collectively include release, active, and recovery. `crowded`
is accurately described as a 39-target fixture/load condition, not as a third
persisted setting.

## Determinism and readability controls

Before readback, the renderer advances the real activation and presentation
only with fixed tween/runtime steps. It then pauses the activation tweens,
every relevant `AnimationPlayer` and `AnimatedSprite2D`, real actors and the
hazard, renders three explicit `UPDATE_ONCE` frames, and switches the target to
`UPDATE_DISABLED`. The verification pass repeats the windowed capture and
compares every file hash; the matching value is retained as both `sha256` and
`repeat_sha256` in the manifest.

The paired headless integrity gate validates all 48 manifest keys and native
IHDR sizes, LFS hydration, image decoding and file hashes. Its negative probes
fail closed for a missing mode, missing provenance key, missing PNG, LFS
pointer, and wrong dimensions. The same gate also runs real Player/enemy/
hazard/HUD mode checks, while `engineer_accessibility_modes_test.gd` remains the
broader production accessibility and lifecycle regression suite.

## Reproduction

Run the manifest's recorded `capture_source.command` exactly (windowed and
through `tools/godot_gate.py`); headless invocation intentionally creates no
PNG evidence. Follow it with the manifest's focused headless integrity gate,
the Engineer accessibility/timeline presentation checks, static scope guard,
and `git lfs fsck` after hydration.
