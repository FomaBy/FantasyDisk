# Elementalist weapon ultimates

FAN-1477 promotes the three frozen Elementalist declarations to distinct,
class-local, convention-discovered packages. FAN-2531 reconciles their aggregate
effectiveness evidence without changing any weapon-local mechanics. The immutable
catalog identities remain unchanged. No shared Player, registry, controller,
schema, ProgressionData, sibling-class, or presentation-owned file is modified.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `elementalist_orb_ring` | Великий Конклав | Four elemental sigils hold a rotating square around the hero. Burn, frost, gale, and shock resolve in order at 1.0/2.2/3.4/4.6s; shock chains across at most six bodies with 0.86 falloff. At 6.0s the four marks combine into one supernova whose damage grows with the marks actually recorded on each target. |
| `elementalist_prism_focus` | Призматический Суд | The cast captures one aimed point. Six X-lattice sweeps rotate by 7.5° at 0.9s intervals while two focus points orbit the center. One silhouette can receive at most three lattice hits. A rainbow fracture at 6.4s damages and slows the final arena; its declared `crowd_cap=18` remains a profile rail while live selection reaches every runner probe. |
| `elementalist_meteor_core` | Падение Звезды | A full-radius rune warns for 2.45s before the meteor descends and impacts at 2.75s. The impact destroys only admitted normal enemies with at most 900 maximum HP, then a gravity-fire crater emits five 0.85s pulses. |

Every mechanics scene embeds its accepted Elementalist presentation scene as
`Presentation` and emits stable phase events through `UltimateActivation`.
Damage, control, target selection, attribution, tracked timelines, and teardown
remain on the shared runtime surfaces.

## Safety and lifecycle

- All three profiles use `rare_charge_ledger`: a full bar is spent once, a live
  payoff earns no dealt- or taken-damage charge, and a second activation in the
  encounter is refused.
- Only charge survives the battle, act, and Continue snapshot chain. Active
  state, use latches, target ledgers, tweens, statuses, and effect nodes do not.
- `activation_owned` cleanup frees the effect and its timeline on completion,
  cancellation, new-run configuration, or node teardown. Status leases carry
  the owning effect instance ID and remove only those exact entries.
- Stable target-local event IDs make repeated beat, sweep, impact, and pulse
  callbacks idempotent. Damage attribution records HP actually removed, not
  requested damage or overkill.
- All primary, chained, terminal, impact, execute, and crater damage shares one
  `total_boss_cap = 0.10` ledger for the whole activation.
- Normal targets receive full declared control. Conclave epic displacement and
  duration are ×0.35; boss displacement/duration are ×0.10/×0.15. Prism
  duration is ×0.50 for epics and ×0.25 for bosses. Meteor displacement is
  ×0.25 for epics and rejected by bosses; crater duration is ×0.40/×0.20.
  Epic and boss tiers can never use the meteor execute rail.

## Caps and timing

| Weapon | Lifetime | Crowd rail | Additional hard caps |
| --- | ---: | ---: | --- |
| Orb Ring | 8.4s | 24 (profile) | 4 ordered beats; 6-target shock chain; 1 supernova |
| Prism Focus | 7.2s | 18 (profile) | 6 sweeps; 3 lattice hits per silhouette; 2 moving focus points |
| Meteor Core | 8.9s | 20 (profile) | 2.45s fair telegraph; normals ≤900 max HP only; 5 crater pulses |

The profile rails above are presentation/performance declarations. The live
effectiveness proof uses the shared deterministic formation and records every
eligible target struck at 1, 5, 10, 20, elite, and boss sizes. Prism's rail is
therefore retained for its authored lattice contract, not used as a live target
selection limit.

## Balance evidence

The normal-weapon baseline excludes ultimate contribution and remains unchanged
after the class-local overlays. The current shared runner source is the
`89397858fb8d33eb3a81ad6fbee76b7ea80365c4` dev baseline.

| Weapon | Reference solo DPS | Power budget (30–45s) | Normal charge | Elite charge |
| --- | ---: | ---: | ---: | ---: |
| Orb Ring | 27.62 | 828.60–1242.90 | 32.66 | 40.62 |
| Prism Focus | 27.25 | 817.50–1226.25 | 32.66 | 40.62 |
| Meteor Core | 27.13 | 813.90–1220.85 | 32.66 | 40.62 |

The focused proof derives each weapon's live
`magic_damage × ultimate_multiplier`, prices the activation against the frozen
20–35 seconds of its own output, and separately measures AoE, crowd, and
control. It also mutates Prism lattice damage out of corridor and requires the
proof to fail, preventing an inherited always-green result.

| Weapon | Solo / budget midpoint | 5-target AoE / midpoint | Profile rail | Control contribution |
| --- | ---: | ---: | ---: | ---: |
| Orb Ring | 0.910 | 1.175 | 24 | 4.0s freeze/slow |
| Prism Focus | 0.909 | 0.967 | 18 | 2.4s fracture slow |
| Meteor Core | 0.910 | 1.241 | 20 | 4.8s crater slow/pull |

Orb leads sequencing and control, Prism spends output on aimed arena geometry,
and Meteor leads bounded crowd burst after the longest warning. The class means
are `solo 0.910 / AoE 1.128 / crowd 1.000 / defense 0.996`; the equally weighted
class composite is `1.008`, inside the required 0.90–1.10 corridor.

### Live effectiveness matrix

The focused live proof records the following target coverage in the runner's
scenario order `solo / crowd_5 / crowd_10 / crowd_20 / elite / boss`:

| Weapon | Targets struck | Applied damage (scenario order) | Uptime | Boss cap ratio |
| --- | --- | --- | ---: | ---: |
| Orb Ring | 1/1 · 5/5 · 10/10 · 20/20 · 1/1 · 1/1 | 637.25 · 3156.12 · 5908.81 · 10785.13 · 637.25 · 637.25 | 8.4s | 0.513 |
| Prism Focus | 1/1 · 5/5 · 10/10 · 20/20 · 1/1 · 1/1 | 928.52 · 4642.58 · 9485.92 · 19122.42 · 928.52 · 928.52 | 7.2s | 0.757 |
| Meteor Core | 1/1 · 5/5 · 10/10 · 20/20 · 1/1 · 1/1 | 925.73 · 4628.66 · 9257.32 · 18514.63 · 925.73 · 925.73 | 8.9s | 0.758 |

For normal and elite formations, the Elementalist balance test checks each
target's damage against `0.5 × live_standard_pool / enemy_count`; the elite
pool uses its 34-second encounter window. Boss probes must also be struck, and
the boss result must deal positive damage without exceeding the whole-activation
cap. All three weapons use `32.66` normal charge, `40.62` elite charge, and
require four neutral encounters to refill. Boss caps remain `0.10` per complete
activation.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/elementalist_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/elementalist_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/elementalist_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tools/ultimate_effectiveness_report.gd -- --label=baseline
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/elementalist_ultimate_timelines.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/balance_charge_economy_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/global_survivability_balance_smoke_test.gd
```

The mechanics suite covers exact routing, distinct execution, ordered phases,
aim geometry, caps, tier resistance, weak-normal admission, idempotency,
actual-HP attribution, shared boss budgets, presentation events, and teardown.
The live suite drives all three pairs through `Player.tscn` and proves charge
spend, active-window lockout, re-entry refusal, presentation embedding, and
new-run cleanup.

## Presentation boundary

The accepted FAN-1476 presentation scenes, manifests, timelines, source art,
runtime images, and contact sheets are read-only inputs. This package only
instances the three accepted scenes and emits their phase events. The shared
presentation bridge remains the FAN-1541 foundation boundary.
