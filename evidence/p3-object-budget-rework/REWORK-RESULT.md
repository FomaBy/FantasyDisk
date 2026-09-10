# FAN-3934 granted-scope repair — measured result (NOT a passing candidate)

Branch `agent/mac-zcode-developer-high/0b5c06167c31`, follow-up commit on top of the
diagnostic `6cd99ef7d`. Author: dev_high agent `11dd50f9-2322-4aa0-a09e-631e1159c1df`.

## Implemented (inside the 2026-09-09T03:18:24Z grant)

- `scripts/hazard_vfx.gd`: one shared immutable additive `CanvasItemMaterial`
  (`HazardVfx.additive_material()`), used by `_additive` and all telegraph/burst/aura
  sprites; telegraph tween tree consolidated from three tweens (grow, looping pulse,
  urgent switch) to two (parallel grow + urgent switch timeline, pulse loop) with
  identical absolute timings, lifetime and cleanup.
- `scripts/enemy.gd`: `_show_hit_flash` tick uses the shared material (color still via
  modulate — visual identity).
- `tests/p3_feedback_allocation_test.gd` (+uid): focused regression — shared instance
  identity, BLEND_MODE_ADD, every produced sprite references the one material,
  allocation flatness within the consolidated tween budget, per-telegraph non-node
  budget <= 9, orphan-clean cleanup. PASS.

## Validation (unchanged decisive FAN-3877 probe, 12 s warm-up + 60 s, gate exclusive,
observed workload exclusion: 0 competing Godot processes before and after)

| Contour | Result | Peak objects | Avg FPS | 1% low | Peak mem |
|---|---|---:|---:|---:|---:|
| P3 run 1 | **FAIL** | 4,561 / 4,000 | 119.0 | 116.7 | 132.7 MiB |
| P3 run 2 | **FAIL** | 4,570 / 4,000 | 118.6 | 109.1 | 132.7 MiB |
| P1 menu | PASS | 2,690 | 119.9 | 117.0 | 123.2 MiB |
| P2 48 enemies | PASS | 4,803 / 5,000 | 112.8 | 105.8 | 132.2 MiB |

Orphans 0 throughout, no monotonic growth, populations held, cleanup deltas 0.
`tests/boss_summon_cap_test.gd` and `tests/boss_hazard_cap_gate.gd` pass unchanged.

## Honest verdict

The granted repair is implemented and regression-safe but produces **no measurable P3
improvement** (pre-fix peaks 4,558/4,597, post-fix 4,561/4,570 — within run-to-run
noise). Hazard/telegraph materials and the consolidated telegraph tween are not the
mass owners in the live P3 flow (consistent with the earlier `no_rift`/`no_volley`
ablations, which also moved nothing).

## New measured attribution of the remaining ~560-object peak shortfall

On the fixed candidate, read-only runtime ablations (probe variants `no_player`,
`no_feedback`, `no_player_no_feedback` in `attribution/`):

| Variant | Mean | Peak |
|---|---:|---:|
| fixed candidate, full | ~4,100 | 4,561–4,570 |
| player weapon auto-attack frozen (`fire_interval` 1e9) | 3,789 | **3,945** |
| hit-feedback chain off (`combat_feedback` root meta) | 3,918 | 4,130 |
| both | 3,830 | 3,988 |

The dominant remaining owner is the **player weapon swing cycle and its hit-feedback
chain**: with swings frozen the peak drops below the cap. The allocation sites for that
chain live outside the granted surface: `scripts/berserk_weapon.gd` (per-swing timing
tweens, spectral follow-up, spiral beams), `scripts/attack_vfx.gd`
(`_additive_material()` creates a fresh CanvasItemMaterial per figure and
`RandomNumberGenerator.new()` per dust/impact call), `scripts/two_handed_axe_weapon.gd`
(per-swing BerserkAxeCleaveVfx scene instantiation), `scripts/vfx/berserk_axe_cleave_vfx.gd`,
`scripts/player.gd:2896` and `scripts/enemy_projectile.gd` (per-projectile materials).

Per the grant's own boundary, no damage-number cap and no feedback/workload reduction
was attempted. A further measured scope decision is required; requested surface below.

## Requested additional scope (bounded, same repair pattern)

`scripts/attack_vfx.gd` and `scripts/two_handed_axe_weapon.gd` (+ `scripts/vfx/berserk_axe_cleave_vfx.gd`
if needed): one shared immutable additive material in `attack_vfx.gd::_additive_material`,
one shared static `RandomNumberGenerator` (or seeded per-call reuse) replacing
`RandomNumberGenerator.new()` per VFX call, and per-swing cleave-VFX reuse/pooling with
identical visuals and timings. Invariants unchanged: no feedback reduction, no
damage-number cap, no summon/crowd/threshold changes, identical textures, colors,
blend modes, timings and cleanup.
