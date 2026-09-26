# Guitarist weapon ultimates

FAN-1493 promotes the three frozen Guitarist profiles to exact class-local
packages. The shared registry, controller, player adapter and presentation
bridge remain unchanged: a matching JSON overlay and GDScript executor are the
only readiness boundary for each weapon pair.

## Trio roles

| Weapon | Ultimate | Role and hard rail |
| --- | --- | --- |
| `electric_guitar` | Последний Аккорд | Five riff strips alternating at ±24° each damage every live enemy. The perpendicular final chord damages its uncapped 1400px corridor and stuns only the enemies a riff strip already marked. |
| `bass_guitar` | Сабвуфер Преисподней | Four concentric waves pull, compress, launch and finally eject every eligible enemy in their expanding 170/250/330/430px rings. The heavy ring is the longest slow; epic control is reduced and bosses never move. |
| `sound_amp` | Стена Звука | Four cardinal amp points raise a 520px square. Four feedback pulses and the four-way overload reach every live enemy on the map; the linked square is presentation shape, not a reach bound. |

All three overlays use `rare_charge_ledger`, `activation_owned` cleanup and the
frozen `0.09` whole-activation boss-health cap. Every damage event goes through
`UltimateActivation`, so the cap, per-target rail, event idempotency and
`applied_total` use actual HP removed rather than attempted damage.

## Control and cleanup

The Guitarist stays a crowd-control class without boss-locking. Normal targets
receive full displacement/duration where the mechanic calls for it; epic targets
receive 30–35% displacement and half duration; bosses receive no displacement,
at most a quarter duration and no movement lock or execute permission.

The activation owns every tween and presentation handle. Completion, cancel,
death, node exit and a new run therefore remove active timing, presentation and
primitive state. Charge alone is restored through the shared battle/act/Continue
snapshot contract; active state and the encounter-use latch are intentionally
not persisted.

## Balance table

The focused proof measures level-1 normal-weapon `magic_damage ×
ultimate_multiplier` against the frozen 20–35 second budget. Outputs below are
the deterministic test values; ratios are against the corresponding immutable
solo or five-target reference.

| Weapon | Solo output (ratio) | Five-target output (ratio) | Reach | Decisive control |
| --- | ---: | ---: | --- | --- |
| `electric_guitar` | 2750.15 (1.023) | 8899.67 (0.819) | uncapped | 1.40s intersection stun |
| `bass_guitar` | 2717.49 (1.013) | 9163.44 (0.840) | uncapped | 1.80s weighted slow plus staged displacement |
| `sound_amp` | 2774.75 (1.032) | 13873.77 (1.280) | uncapped | 2.00s field slow plus overload eject |

The class averages are solo **1.023**, AoE **0.980**, crowd **1.000** and
defense **0.963**, for an equal-weight total **0.991** inside the 0.90–1.10
corridor. The individual AoE lanes remain deliberately distinct: aimed
intersection burst, expanding displacement sequence, and a stationary square
field.

## Map-wide coverage (FAN-2533, Ultimate Direction v2)

The three conversion leaves have landed on `dev` — FAN-3262 for
`electric_guitar`, FAN-3260 for `bass_guitar`, and the FAN-3285 chain through
FAN-3346/FAN-3361 for `sound_amp`. This aggregate card records the result in
the shared coverage ratchet and moves Guitarist out of
`COVERAGE_MIGRATION_ALLOWLIST` into `COVERAGE_V2_CLASSES`. No weapon-owned
mechanic, overlay, scene, or presentation file changes here.

Reach is no longer a headcount anywhere in the trio, so the class crowd rail is
now the v2 contract itself: a weapon scores only while its executor declares no
count-shaped parameter. The shape each leaf froze is still distinct.

| Weapon | Selection | Shape that remains |
| --- | --- | --- |
| `electric_guitar` | `select_targets(centre, INF, 0, "nearest")` per riff strip | perpendicular final chord in an uncapped 1400px corridor; the stun needs a prior riff mark |
| `bass_guitar` | `targets(origin, radius)` re-read per wave, no limit | four expanding rings, 170 → 430px, terminal shock covering the engagement |
| `sound_amp` | `select_targets(origin, INF, 0, "nearest")` per pulse and overload | 520px linked square as presentation shape only |

Two legacy count keys survive for catalog compatibility and are not read as
reach bounds: `crowd_cap` in `bass_guitar`'s overlay and parameter contract, and
`performance.crowd_cap` in the FAN-1492 presentation manifest — the latter is a
visual-node budget checked against scene metadata, never an enemy count.

`build/ultimate_effectiveness_baseline.json` is unchanged by this card. Its
committed Guitarist rows already record the converted contract, and every row —
Guitarist and non-Guitarist alike — is byte-identical to the admitted base:

| Weapon | Corridor | Struck: solo / 5 / 10 / 20 / elite / boss | Boss cap ratio | Uptime |
| --- | ---: | --- | ---: | ---: |
| Последний Аккорд | 2150.70…3226.05 | 1 / 5 / 10 / 20 / 1 / 1 | 0.852 | 5.4s |
| Сабвуфер Преисподней | 2146.20…3219.30 | 1 / 5 / 10 / 20 / 1 / 1 | 0.726 | 5.8s |
| Стена Звука | 2151.00…3226.50 | 1 / 5 / 10 / 20 / 1 / 1 | 0.860 | 6.0s |

## Verification

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/guitarist_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/guitarist_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/guitarist_ultimate_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/check_druid_baseline_isolation.py --base origin/dev --class guitarist
python3 tools/test_check_druid_baseline_isolation.py
```

The last two are the keyed row-isolation regression: a pure JSON diff of
`build/ultimate_effectiveness_baseline.json` against a known-good revision,
keyed by `class_id/weapon_id`, which fails if any row outside the scoped class
moved. It is the FAN-3383 guard reused with `--class guitarist`; it runs no
Godot, so unrelated live-measurement noise cannot turn it red or green.

FAN-1492 presentation timelines and assets are read-only inputs. FAN-1541 owns
the shared live presentation adapter; these executors only emit the existing
generic presentation events and do not modify animation or asset paths.
