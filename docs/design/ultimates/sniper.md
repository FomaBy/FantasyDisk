# Sniper weapon ultimates

The ready Sniper trio uses its three exact package executors. It has no
per-target, ray-pierce, lock, shard, ricochet, or crowd-count damage cap: every
live enemy in the arena receives the non-trivial floor for the cast. The shared
activation ledger remains the only boss protection and keeps each weapon under
the frozen `total_boss_cap = 0.10`.

## Trio roles

| Weapon | Ultimate | Arena-wide combat role |
| --- | --- | --- |
| `sniper_deadeye_rifle` | Выстрел Мертвого Глаза | A 0.75 s held-breath release fires one full-arena rail. The highest-HP enemy receives the 1.5× headshot; every other live enemy receives the regular shot floor. |
| `sniper_spotter_scope` | Прицел Наводчика | After a 0.85 s sky lock, nine 0.12 s artillery pulses strike every live enemy and apply the full suppression window. Pulses are a rhythm, not a target cap. |
| `sniper_shatter_rounds` | Осколочные Патроны | A 0.65 s crystal-fan windup releases five 0.22 s expanding waves. Each wave damages every live enemy and applies stagger once per target. |

Each executor is class-local under `scripts/ultimates/classes/sniper/`, accepts
the shared damage sink, and is spawned by `UltimateActivation`. Damage events
therefore preserve idempotency, applied-HP attribution, cancellation cleanup,
and the whole-cast boss budget without modifying Player, the registry, or
sibling classes.

## Safety and charge economy

- The shared ledger is authoritative for one charge spend, no active-window
  income, one activation per encounter, and battle/act/Continue snapshots.
- Bosses are limited only by the shared 10% whole-cast ledger. Epic and boss
  control follows the class policy; the three executors retain no second
  target-shaped cap.
- The `ultimate_charge_ledger` contract is exercised for a three-to-four
  encounter charge cycle by the package and effectiveness suites.
- Stable per-target event IDs make replayed shot, pulse, and wave events
  idempotent. Teardown releases only statuses owned by this cast.

## Presentation contract

| Weapon | Windup / active / total | Backdrop and impact | Sniper identity |
| --- | --- | --- | --- |
| Deadeye Rifle | 0.75 / 1.25 / 2.90 s | darken, full-arena tracer, shake, 100 ms hitstop | `sniper.cast.steady_breath`, Deadeye silhouette |
| Spotter Scope | 0.85 / 1.55 / 3.40 s | flash, full-arena sky grid, shake, 120 ms hitstop | `sniper.cast.sky_lock`, Spotter silhouette |
| Shatter Rounds | 0.65 / 1.30 / 3.10 s | flash, full-arena crystal fan, shake, 90 ms hitstop | `sniper.cast.shatter_fan`, Shatter silhouette |

Every cast has at least 1.2 seconds of active readability and pairwise release
separation of at least 0.1 seconds. The package-level manifest and the timeline
JSONs both carry the same `sniper.glacial_crimson` class palette, weapon-local
silhouette, arena footprint, backdrop, camera shake, time-scale dip, audio
ducking, and hitstop data. Sniper is in both V2 coverage ratchets; no Sniper
presentation or coverage allowlist entry remains.

## Verification

The checked-in effectiveness baseline records each exact executor in six
scenarios: solo, 5/10/20 regular enemies, elite, and boss. Focused tests also
spawn a 20-enemy live arena to prove that every survivor receives the damage
floor, then verify boss-cap and control behavior. The presentation timeline
test verifies the V2 envelope, full-arena effects, pose/silhouette/palette, and
timing distinction.

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/sniper_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/sniper_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/sniper_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/sniper_ultimate_timelines.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/effectiveness_runner_test.gd
```
