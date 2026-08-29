# Priest weapon ultimates

Status: the three exact Priest packages are ready. Each JSON binding has one
class-local executor and a small activation-owned scene that embeds the
accepted presentation asset. The implementation does not change Player,
ClassWeapon, the shared registry, schema, progression data, siblings or the
presentation assets.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `priest_reliquary` | Суд Светлого Святилища | The opened reliquary grows three consecration rings across every live enemy. The first damages, the second leases a sanctify mark, and the pillar converts HP actually removed by all three rings into a capped heal. Only actual overheal becomes a capped temporary absorb shield. Rank falloff keeps the sanctuary focused while a 40% floor protects each enemy. |
| `priest_censer` | Нерушимый Обет | The giant censer's chain orbit is a 7.6s strong temporary absorb window. Its activation-local owner-event adapter records the real Player `damage_absorbed` payload, stores only 65% up to its declared cap, and returns that stored value across every live enemy as one holy finish counter. No incoming hit means no counter damage; a funded counter keeps a 41% per-enemy floor. |
| `priest_chime` | Три Колокола Рассвета | Bell one interrupts every normal enemy; elite and boss policy rejects the movement lock and leaves a shortened stagger. Bell two sends a falling holy chain through every live enemy, with a 27% chain floor after rank falloff. Bell three heals from that chain's actually removed HP and opens one activation-owned `death_save` window until the cast ends. |

The three signatures differ across at least targeting, timing and defensive
axes: Reliquary is a delayed sanctuary + sustain conversion, Censer is an
observed-damage defensive counter, and Chime is a map-wide interrupt followed
by a ranked chain and a short lethal-prevention window.

## Runtime, caps and cleanup

- All profiles declare `ultimate_charge_ledger`, `activation_owned` cleanup and
  the frozen Priest `total_boss_cap = 0.08`. The shared ledger remains the
  authority for one spend per encounter, active-window income lockout, and
  battle/act/Continue snapshots.
- Every outgoing hit goes through `UltimateActivation.deal_damage`; boss budget,
  stable event IDs and HP-removed attribution therefore cover every ring, chain
  link and counter burst. Reliquary and Chime repairs use `repair()` and are
  metered by a declaration cap as well.
- The accepted VFX scenes are embedded in the local effect scene, so opening
  reliquary/rings/pillar/shield halo, censer chain/smoke/beads/slam and the three
  bell waves all start and disappear with the same activation-owned node as the
  mechanics.
- Sanctify and interrupt statuses include the local effect instance ID. On
  completion or cancel their teardown removes only those leases; activation
  reversal removes Reliquary shield, Censer absorb and Chime `death_save`.
- Censer temporarily occupies the Player's existing owner-event adapter seam,
  forwards every event to the real equipped weapon and restores that weapon on
  teardown. Its activation-local host proxy forwards the generic runtime
  contract unchanged and synchronously removes the zero-valued absorb key when
  the modifier unwinds. It adds no Player or ClassWeapon branch and never
  estimates prevented damage from a requested incoming hit.
- Chime's resistance policy permits full normal interruption, removes movement
  lock on elites/bosses and shortens their stagger duration to 45%/25%.

| Weapon | Active lifetime | Coverage | Per-target and utility rails |
| --- | ---: | ---: | --- |
| Reliquary | 8.6s | every live enemy | 1.25s / 2.60s / 5.30s rings; 0.80 rank falloff clamped at 0.40; 35% actual-damage heal; 46× base heal cap; 24× base shield cap |
| Censer | 7.6s | every live enemy when the counter is funded | 65% observed-prevention storage; 56× base stored/counter cap; 0.75 rank falloff clamped at 0.41; one 6.30s finish burst |
| Chime | 6.4s | every live enemy | 0.50s / 2.30s / 4.10s tolls; 0.75 chain falloff clamped at 0.27; 2.30s lethal-prevention window |

`radius`, `crowd_cap`, `counter_radius`, `counter_target_cap`,
`interrupt_radius`, `chain_radius` and `chain_targets` are removed from the
ready profiles and executor contracts. Visible ring/arc/chain geometry is now
presentation and rank attribution only; it never decides whether a live enemy
is eligible.

## Balance proof

The focused balance test derives each weapon's normal `damage ×
ultimate_multiplier` and prices the declared cap against the shared 30–45
second activation corridor. Reliquary is paid partly in its delayed
actual-damage sustain, Censer has no offensive value unless actual prevention
occurred, and Chime pays for its six-link crowd chain with a short defensive
window. The proof also mutates the Chime coefficient out of corridor and
requires that mutation to fail, preventing an always-green balance gate.

| Weapon | Solo / midpoint | Five-target AoE / reference | Guaranteed share | Defense window |
| --- | ---: | ---: | ---: | ---: |
| Reliquary | 1.005 | 1.144 | 0.400 | 3.30s shield tail |
| Censer | 0.998 | 1.032 | 0.410 after funded prevention | 7.60s mitigation |
| Chime | 0.982 | 1.132 | 0.409 including the interrupt | 2.30s lethal prevention |

The final composite is 0.995 on solo, 1.103 on five-target AoE and 1.000 on
the declared defense axis; its three-axis score is 1.033, inside the project
0.90–1.10 class corridor. The individual weapons stay distinct: Censer owns
the long protection window, Chime owns immediate map-wide control, and
Reliquary owns delayed damage-to-sustain conversion.

## FAN-2535 live baseline and final evidence

The live effectiveness runner resolved all 51 rows through `weapon_profile`.
The other 48 rows are byte-identical between the reports. Values below are
`effect_total`; `targets` is the 20-probe damage reach where applicable.

| Weapon | Solo | 5 | 10 baseline → final | 20 baseline → final | Elite | Boss | Targets baseline → final |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Reliquary | 1705.60 | 5736.09 | 7625.44 → 9154.28 | 8470.89 → 15990.66 | 1705.60 | 1705.60 | 20 → 20 |
| Censer | 755.47 | 755.47 | 755.47 → 755.47 | 755.47 → 755.47 | 755.47 | 755.47 | conditional counter: 12/26 → 26/26 live fixture |
| Chime | 1650.87 | 5648.83 | 7541.71 → 9026.75 | 10063.56 → 15782.57 | 1650.21 | 1649.97 | 18 → 20 |

Reliquary already reached the runner's 20 nested probes, but the 26-target live
fixture exposed its old 22-target rail (`22/26 → 26/26`). Censer's neutral
runner scenario receives no incoming hit, so its truthful damage and
`prevention_applied` remain zero while the active ward contributes 754.47 via
`modifier_granted`; the real-Player fixture proves actual absorbed HP funds the
counter and that the funded counter reaches `26/26`. Chime improves from
`18/20` to `20/20`. Gameplay summon contribution is zero for the trio; the
runner's `summon_count=1` is the activation-owned effect scene, not a combat
summon. Healing is zero in the full-health runner fixture and remains verified
against damaged players in `priest_live_test.gd`.

Charge and boss protection are unchanged on all three rows:
`encounters_to_ready=3`, `normal_charge=33.38`, `elite_charge=42.06`,
`total_boss_cap=0.08`; solo, elite, boss and active lifetimes are unchanged.
The 26-target runtime fixture and the independent coefficient proof enforce at
least `0.5 ×` one standard monster's HP per enemy for counts
`1, 5, 10, 20, 100, 1000`. Priest therefore leaves
`COVERAGE_MIGRATION_ALLOWLIST` and enters `COVERAGE_V2_CLASSES`.

## Mechanic and timing handoff for visual animation

- Reliquary: ring beats at 1.25s and 2.60s, pillar at 5.30s, cleanup at 8.60s.
  All victims receive each beat; distance/rank may only change visual emphasis,
  never eligibility or the 40% floor.
- Censer: ward begins immediately, stored-prevention counter resolves once at
  6.30s, cleanup at 7.60s. A zero-storage cast has no damage finale. A funded
  finale needs readable victim feedback across the arena while the censer arc
  remains the hero-centred identity anchor.
- Chime: tolls at 0.50s, 2.30s and 4.10s, cleanup at 6.40s. Toll one is the
  map-wide interrupt/stagger beat, toll two the ranked damage chain, toll three
  the heal/death-save beat. Elite/boss control resistance remains 45%/25%.

No visual asset or ordinary-weapon file changes in FAN-2535; this section is
the fixed mechanic/timing contract for the later visual-animation task.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/priest_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/priest_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/priest_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_package_discovery_test.gd
```

The shared controller integration suite derives its ready set from package
discovery, so the same real Player adapter route also covers the Priest trio.
