# Guitarist weapon ultimates

FAN-1493 promotes the three frozen Guitarist profiles to exact class-local
packages. The shared registry, controller, player adapter and presentation
bridge remain unchanged: a matching JSON overlay and GDScript executor are the
only readiness boundary for each weapon pair.

## Trio roles

| Weapon | Ultimate | Role and hard rail |
| --- | --- | --- |
| `electric_guitar` | Последний Аккорд | Five 1400px aimed riff strips alternate at ±24°. A perpendicular final chord damages the 14-target corridor and stuns only normal enemies that were struck by a riff strip. |
| `bass_guitar` | Сабвуфер Преисподней | Four 12-target concentric waves pull, compress, launch and finally eject a crowd. The heavy ring is the longest slow; epic control is reduced and bosses never move. |
| `sound_amp` | Стена Звука | Four cardinal amp points form a 520px square field for presentation. Four feedback pulses damage and slow every eligible live enemy on the map, and the four-way overload damages those same targets while applying the existing control-resistance rules; the field shape is presentation-only and there is no count cap. |

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

| Weapon | Solo output (ratio) | Five-target output (ratio) | Crowd cap | Decisive control |
| --- | ---: | ---: | ---: | --- |
| `electric_guitar` | 2036.26 (1.033) | 6587.91 (0.826) | 14 | 1.40s intersection stun |
| `bass_guitar` | 2012.61 (1.023) | 6786.70 (0.849) | 12 | 1.80s weighted slow plus staged displacement |
| `sound_amp` | 2055.37 (1.042) | 10276.86 (1.293) | 14 | 2.00s field slow plus overload eject |

The class averages are solo **1.033**, AoE **0.989**, crowd **1.000** and
defense **0.963**, for an equal-weight total **0.996** inside the 0.90–1.10
corridor. The individual AoE lanes remain deliberately distinct: aimed
intersection burst, expanding displacement sequence, and a stationary square
field.

## Verification

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/guitarist_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/guitarist_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/guitarist_ultimate_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
```

FAN-1492 presentation timelines and assets are read-only inputs. FAN-1541 owns
the shared live presentation adapter; these executors only emit the existing
generic presentation events and do not modify animation or asset paths.
