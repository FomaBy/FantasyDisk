# Sniper weapon ultimates

Status: the three exact Sniper packages are ready. Each JSON binding is paired
with one class-local executor and is discovered by the shared weapon ultimate
registry; no Player, registry, schema, progression or sibling-class code is
changed.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `sniper_deadeye_rifle` | Выстрел Мертвого Глаза | One aimed rail, one shot, resolved on the activation frame. The highest-HP silhouette on the rail takes the ×1.5 headshot wherever it stands; every other body keeps only `penetration_falloff^depth` of the shot, so the rail decays strictly with pierce depth and stops at four bodies. The scope lock is presentation only — the ultimate is the shot. |
| `sniper_spotter_scope` | Прицел Наводчика | Nine sky locks are dealt round-robin over the most dangerous silhouettes inside the kill zone, at most three per silhouette; surplus locks are never armed. Locking suppresses under the tier policy. Each lock drops one artillery round; a lock whose body is already gone transfers to the most dangerous survivor still inside the zone instead of being wasted. |
| `sniper_shatter_rounds` | Осколочные Патроны | Five ricochet trajectories open on distinct entry silhouettes and bounce twice each to the nearest untouched body, spraying one shard per impact. A per-target damage cap is the anti-focus rail: converging trajectories cannot spend more than the declared share of any one silhouette. |

The runtime scenes under `scripts/ultimates/classes/sniper/` are mechanics
owners. Each embeds the already accepted presentation scene as a child, exposes
`ultimate_damage_sink`, and is spawned by `UltimateActivation`, so deferred
damage shares idempotency, applied-HP attribution and the whole-cast boss
budget.

## Safety and lifecycle

- All profiles use the frozen Sniper `total_boss_cap = 0.10`. Every shot,
  strike, impact and shard event uses the same activation ledger.
- Normal control is full strength. Epic displacement is ×0.25 and duration ×0.5
  with no movement lock; bosses reject displacement, receive ×0.25 duration and
  no movement lock. Only the kill zone ever pins a normal target; the shatter
  volley staggers but never pins and never displaces.
- Status IDs include the activation-owned node instance ID and the target
  instance ID. Teardown removes only those exact leases, preserving unrelated
  statuses.
- The rail resolves synchronously so a cast always has a measurable combat
  effect on its own activation frame; only the kill zone deliberately delays
  its artillery, which is that weapon's declared identity.
- Controller completion or cancellation kills the tracked timeline and frees
  the rail, kill zone or sweep. The kill zone deliberately stays live for its
  whole suppression window so teardown never cuts the declared duration short.
- Event IDs are stable per target and phase. Repeating the shot, strike or
  impact event is idempotent; shards are secondary by contract, so they cannot
  spray another shard.
- The sky-lock ledger holds a count, so a transfer releases exactly one lock
  from the lost silhouette and arms exactly one on the survivor.
- Charge declares `ultimate_charge_ledger`. The shared ledger is the authority
  for one spend, no active-window income, one activation per encounter and
  battle/act/Continue snapshots; the package tests exercise those rules for all
  three weapon rows. Wiring that already-frozen ledger into Player remains a
  shared-runtime adoption concern and is intentionally outside this class-local
  write set.

## Caps and timing

| Weapon | Lifetime | Crowd | Additional hard caps |
| --- | ---: | ---: | --- |
| Deadeye Rifle | instant shot + 0.25s recovery | 4-body rail | 1 headshot; 0.28 penetration decay per depth |
| Spotter Scope | 1.0s lock + 9×0.12s strikes, held to the 4.4s suppression window | 9 locks | 3 locks per silhouette; 1 transfer per lock |
| Shatter Rounds | 2.82s volley | 15-target sweep | 5 trajectories; 2 ricochets each; 1 shard per impact; 40% per-target damage cap |

## Balance evidence

The frozen budget prices each activation against 20–35 seconds of that weapon's
own normal solo output. The focused proof derives live
`damage × ultimate_multiplier` from the selected weapon and measures the
declared coefficients rather than accepting a hand-authored score.

| Weapon | Solo / budget midpoint | Crowd AoE / midpoint | Crowd cap | Control |
| --- | ---: | ---: | ---: | ---: |
| Deadeye Rifle | 0.995 | 0.578 | 4 | — |
| Spotter Scope | 0.923 | 1.283 | 9 | 4.4s suppression |
| Shatter Rounds | 0.826 | 1.156 | 15 | 2.8s stagger |

Deadeye pays for headshot certainty instead of line clear: 79.8% of a full
four-body rail still lands on the priority target. Spotter leads AoE and is the
only weapon in the trio that clears the shared 4.0s decisive-control bar.
Shatter leads crowd reach at the lowest solo share. The class composite is
0.980 across solo, AoE, capped crowd and defense axes, inside the project
0.90–1.10 corridor. A long-range burst class buys reach with control, so the
defense axis is normalized against the 2.4s Sniper class reference rather than
a melee-grade one.

The balance test also multiplies the sky-lock coefficient out of corridor and
requires the proof to fail specifically on Spotter Scope, preventing an
inherited always-green result.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/sniper_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/sniper_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/sniper_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_package_discovery_test.gd
```

## Known foundation gap

`tests/ultimates/controller_player_integration_test.gd` still snapshots the
shipped ready set as Biologist-only (`SHIPPED_READY_CLASS`,
`SHIPPED_READY_WEAPONS`, `SHIPPED_LEGACY_PAIRS = 48`). That half of the suite
goes red on any second ready class, exactly as it did before FAN-2057 aligned
it to Biologist. It lives outside this card's locked paths, so aligning it is a
separate foundation change; the sniper fixture halves of the same suite, and
its real-Player routing assertions for the three Sniper pairs, already pass.
