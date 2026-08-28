# Doctor weapon ultimates

FAN-2529 reconciles the three frozen Doctor ultimate profiles as one
class-local Ultimate Direction v2 package. The gameplay leaves are already
integrated through FAN-3359, FAN-3297, and FAN-3278; this aggregate changes
only the shared coverage ratchet, deterministic evidence, and class references.
The registry still binds each JSON profile to its exact Doctor executor, while
the shared controller, Player, ClassWeapon, scenes, and presentation adapter
remain unchanged.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `restore_potion` | Эликсир Жизни и Смерти | Aimed outer pool reaches every eligible enemy through four pulses; the inner healing spiral repairs the Doctor and its overflow becomes a temporary absorb shield. The visible 220 px ring remains the targeting identity. |
| `plague_syringe` | Чёрная Эпидемия | Highest-HP patient zero receives the syringe strike, then five fixed plague waves resolve across every eligible enemy before the mask finale. `wave_visual_radius` is presentation-only. |
| `bone_saw` | Экстренная Операция | Six close orbit cuts drain actual removed HP into repair and a temporary stitch shield. The existing 240 px orbit remains a close-range identity and has no count-shaped target cap. |

The trio separates on geometry and rhythm: aimed dual pool, delayed map-wide
infection waves, and a close surgical orbit. Their defensive contributions also
stay distinct: Life and Death owns repair plus absorb, Black Epidemic owns
repair while spending its budget on sustained reach, and Emergency Surgery owns
actual-HP drain plus absorb.

## Safety and lifecycle

- Every profile uses the frozen Doctor `total_boss_cap = 0.08`. Delayed hits
  share the activation ledger, so actual removed HP — not attempted damage — is
  attributed and the cap applies to the complete cast.
- Every profile uses `rare_charge_ledger`, spends one charge per encounter, and
  earns no charge during its active window. The neutral measured charge is
  `33.50`, elite charge is `42.30`, and recurring readiness is three normal
  encounters.
- Effect nodes, VFX children, tweens, absorb modifiers, and status leases are
  activation-owned. Cancellation, death, node end, and a new run remove only
  state taken by that activation; charge snapshots do not persist active-effect
  state.
- The accepted Doctor presentation events remain the seam with FAN-1541:
  flask/release, poison-ring, healing-spiral, and shield for Life and Death;
  injection, veins, wave, and mask for Black Epidemic; stance, orbit, and
  stitch-shield for Emergency Surgery.

## Balance evidence

The aggregate uses the 51-row live effectiveness baseline from the current
`origin/dev`. Baseline and final metrics are intentionally identical because
this card does not change weapon mechanics; only the shared coverage ledger
and class evidence are new.

The focused level-1 proof measures each weapon against its own live budget
midpoint. The class-trio summary is `solo 1.185 / AoE 0.960 / crowd 0.889 /
defense 1.000 / total 1.009`: solo and AoE are live damage ratios, crowd is
the average canonical formation reach, and defense is implemented-utility
presence (repair, drain, or absorb), not an invented EHP magnitude.

| Weapon | Solo / budget midpoint | AoE / midpoint | Crowd reach | Defense utility |
| --- | ---: | ---: | ---: | --- |
| `restore_potion` | 1.156 | 1.156 | 1.000 | repair + absorb |
| `plague_syringe` | 1.200 | 0.925 | 1.000 | repair |
| `bone_saw` | 1.200 | 0.800 | 0.667 | drain + absorb |

The per-weapon spread is intentional: Life and Death owns reliable full-set
damage and sustain, Black Epidemic owns map-wide cadence, and Emergency Surgery
trades formation reach for the strongest close-range drain/shield payoff. No
weapon is a dead-weight filler, and no weapon is universal across all axes.

## Map-wide coverage (FAN-2529 / Ultimate Direction v2)

The Doctor executors now sit outside `COVERAGE_MIGRATION_ALLOWLIST` and inside
`COVERAGE_V2_CLASSES`. The conversion removes count-shaped reach constraints
without rewriting the accepted weapon profiles. Life and Death's aimed release
point and ring remain visual/targeting geometry; Black Epidemic's five waves
start from the complete eligible set; Emergency Surgery keeps its finite orbit
radius as geometry rather than a count cap.

The rebuilt 51-row artifact records this deterministic six-scenario matrix. The
values below are `targets_struck` followed by applied damage, in the order
`solo / crowd_5 / crowd_10 / crowd_20 / elite / boss`:

| Weapon | Struck | Applied damage | Boss cap ratio | Uptime |
| --- | --- | --- | ---: | ---: |
| `restore_potion` | 1/1 · 5/5 · 10/10 · 20/20 · 1/1 · 1/1 | 1748.92 · 8744.61 · 17489.21 · 34978.42 · 1748.92 · 1748.92 | 0.963 | 4.06s |
| `plague_syringe` | 1/1 · 5/5 · 10/10 · 20/20 · 1/1 · 1/1 | 1815.75 · 7195.98 · 13921.27 · 27371.84 · 1815.75 · 1815.75 | 1.000 | 5.86s |
| `bone_saw` | 1/1 · 4/5 · 7/10 · 10/20 · 1/1 · 1/1 | 1798.20 · 7192.80 · 12587.40 · 17982.00 · 1798.20 · 1798.20 | 1.000 | 3.86s |

The close saw's 5/10/20 formation misses are shape-specific: the 240 px orbit
does not claim map-wide geometry. They are not hidden count caps, and the
aggregate test still proves that its executor source is free of count-shaped
reach parameters. The full row set preserves all 48 non-Doctor rows from the
live baseline.

Focused evidence: `doctor_bone_saw_direction_v2_test.gd`,
`doctor_package_test.gd`, `doctor_balance_test.gd`, and `doctor_live_test.gd`.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/doctor_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/doctor_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/doctor_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tools/ultimate_effectiveness_report.gd -- --label=final
```
