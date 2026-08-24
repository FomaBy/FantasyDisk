# Elementalist weapon ultimates

FAN-1477 promotes the three frozen Elementalist declarations to distinct,
class-local, convention-discovered packages. The immutable catalog identities
remain unchanged. No shared Player, registry, controller, schema,
ProgressionData, sibling-class, or presentation-owned file is modified.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `elementalist_orb_ring` | Великий Конклав | Four elemental sigils hold a rotating square around the hero. Burn, frost, gale, and shock resolve in order at 1.0/2.2/3.4/4.6s; shock chains across at most six bodies with 0.86 falloff. At 6.0s the four marks combine into one supernova whose damage grows with the marks actually recorded on each target. |
| `elementalist_prism_focus` | Призматический Суд | The cast captures one aimed point. Six X-lattice sweeps rotate by 7.5° at 0.9s intervals while two focus points orbit the center. One silhouette can receive at most three lattice hits. A rainbow fracture at 6.4s damages and slows the final arena. |
| `elementalist_meteor_core` | Падение Звезды | A rune warns inside its visual `impact_radius` for 2.45s before the meteor descends and impacts at 2.75s, then a gravity-fire crater emits five 0.85s pulses. Impact and every pulse reach every live enemy map-wide — the warning ring is presentation only, not a mechanics range gate. The impact additionally executes admitted normal enemies with at most 900 maximum HP. |

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
| Orb Ring | 8.4s | 24 | 4 ordered beats; 6-target shock chain; 1 supernova |
| Prism Focus | 7.2s | 18 | 6 sweeps; 3 lattice hits per silhouette; 2 moving focus points |
| Meteor Core | 8.9s | map-wide (no count cap) | 2.45s fair telegraph; normals ≤900 max HP only; 5 crater pulses; 10% whole-activation boss cap |

## Balance evidence

The normal-weapon baseline was captured before adding the packages. It excludes
ultimate contribution and remains unchanged after the class-local overlays.

| Weapon | Normal solo DPS | Normal 5-target DPS | 5/10/20 clear time | Reference EHP |
| --- | ---: | ---: | ---: | ---: |
| Orb Ring | 27.82 | 104.04 | 3.7 / 7.6 / 16.2s | 50.8 |
| Prism Focus | 27.82 | 103.90 | 3.9 / 8.2 / 17.4s | 50.8 |
| Meteor Core | 27.83 | 103.95 | 3.7 / 7.7 / 16.4s | 50.8 |

The focused proof derives each weapon's live
`magic_damage × ultimate_multiplier`, prices the activation against the frozen
20–35 seconds of its own output, and separately measures AoE, crowd, and
control. It also mutates Prism lattice damage out of corridor and requires the
proof to fail, preventing an inherited always-green result.

| Weapon | Solo / budget midpoint | 5-target AoE / midpoint | Crowd cap | Control contribution |
| --- | ---: | ---: | ---: | ---: |
| Orb Ring | 0.954 | 1.232 | 24 | 4.0s freeze/slow |
| Prism Focus | 0.953 | 1.014 | 18 | 2.4s fracture slow |
| Meteor Core | 0.954 | 1.301 | map-wide (no count cap) | 4.8s crater slow/pull |

Orb leads sequencing and control, Prism spends output on aimed arena geometry,
and Meteor leads bounded crowd burst after the longest warning. The class means
are `solo 0.954 / AoE 1.182 / crowd 1.000 / defense 0.996`; the equally weighted
class composite is `1.033`, inside the required 0.90–1.10 corridor.

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
