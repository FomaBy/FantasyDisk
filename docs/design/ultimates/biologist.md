# Biologist weapon ultimates

Status: the three exact Biologist packages are ready. Each JSON binding is
paired with one class-local executor and is discovered by the shared weapon
ultimate registry; no Player, registry, schema, progression or sibling-class
code is changed.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `biologist_spore_lens` | Мировой Мицелий | Immediate contact germination followed by two expanding propagation branches (the first outward release remains at 0.9s). First contact roots and slows normal enemies, applies an infection lease, and resolves infection damage through the activation ledger. Creditable infected deaths can open at most three blooms; bloom hits are secondary and never trigger another bloom. |
| `biologist_sample_injector` | Идеальный Образец | Captures one aimed line, extracts the highest-HP target on that rail, and records a 10-second direct-hit sample. Durable, ranged and swarm archetypes receive ×1.35, ×1.25 and ×1.15 direct-hit adaptation. Exactly three analysis pulses revisit the sample; nearby rail tissue receives only a reduced secondary share. |
| `biologist_symbiote_seed` | Матка Симбионта | Deploys one owned pod at the captured aim point, suspends only player-owned prior symbiotes, pulls/roots admitted targets, launches exactly six ledger-bound larvae, then resolves one terminal hatch burst. |

The runtime scenes under `scripts/ultimates/classes/biologist/` are mechanics
owners. Each embeds the already accepted presentation scene as a child, exposes
`ultimate_damage_sink`, and is spawned by `UltimateActivation`, so deferred
damage shares idempotency, applied-HP attribution and the whole-cast boss
budget.

## Safety and lifecycle

- All profiles use the frozen Biologist `total_boss_cap = 0.09`. Every primary,
  secondary, pulse, larva and hatch event uses the same activation ledger.
- Normal control is full strength. Epic displacement is ×0.25 and duration is
  ×0.45 with no movement lock; bosses reject displacement, receive ×0.20
  duration and no movement lock.
- Status IDs include the activation-owned node instance ID. Teardown removes
  only those exact leases, preserving unrelated statuses.
- Controller completion or cancellation kills the tracked timeline and frees
  the growth, sample mark or pod. The pod interaction restores the exact prior
  visibility/process state of player-owned summons and never snapshots foreign
  summons.
- Event IDs are stable per target and phase. Repeated extraction/damage events
  are idempotent. Secondary bloom/tissue results are non-creditable by contract,
  which makes recursion impossible.
- Charge declares `ultimate_charge_ledger`. The shared ledger is the authority
  for one spend, no active-window income, one activation per encounter and
  battle/act/Continue snapshots; the package tests exercise those rules for all
  three weapon rows. Wiring that already-frozen ledger into Player remains a
  shared-runtime adoption concern and is intentionally outside this class-local
  write set.

## Caps and timing

| Weapon | Lifetime | Crowd | Additional hard caps |
| --- | ---: | ---: | --- |
| Spore Lens | 8.6s | 18 | 3 waves; 3 blooms; 3 neighbors per bloom; no recursion |
| Sample Injector | 0.65s release + 10.0s sample | 16-line acquisition | 3 pulses; 4 tissue targets per pulse |
| Symbiote Seed | 9.0s | 22 | 1 temporary pod; 6 larvae; 1 hatch |

## Balance evidence

The frozen budget prices each activation against 20–35 seconds of that
weapon's own normal solo output. The focused proof derives live
`magic_damage × ultimate_multiplier` from the selected weapon and measures the
declared coefficients rather than accepting a hand-authored score.

| Weapon | Solo / budget midpoint | 5-target AoE / midpoint | Crowd cap | Control |
| --- | ---: | ---: | ---: | ---: |
| Spore Lens | 0.952 | 1.190 | 18 | 5.0s root/slow |
| Sample Injector | 0.996 | 0.341 | 16 | — |
| Symbiote Seed | 0.998 | 0.830 | 22 | 4.5s pull/root |

Sample intentionally pays for priority-target certainty instead of broad AoE.
Spore leads crowd/control and Seed bridges area damage with defensive grouping.
The resulting class composite is 0.940 across solo, AoE, capped crowd and
defense axes, inside the project 0.90–1.10 corridor. The pre-package normal-kit
audit remains `solo 1.000 / AoE 1.000 / crowd 0.991 / defense 0.820 / total
0.953`; this package does not rebalance normal attacks.

The balance test also multiplies extraction damage out of corridor and requires
the proof to fail specifically on Sample Injector, preventing an inherited
always-green result.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/biologist_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/biologist_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/biologist_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/global_damage_balance_smoke_test.gd
```
