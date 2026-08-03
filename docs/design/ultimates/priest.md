# Priest weapon ultimates

Status: the three exact Priest packages are ready. Each JSON binding has one
class-local executor and a small activation-owned scene that embeds the
accepted presentation asset. The implementation does not change Player,
ClassWeapon, the shared registry, schema, progression data, siblings or the
presentation assets.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `priest_reliquary` | Суд Светлого Святилища | The opened reliquary grows three consecration rings. The first damages the sanctuary, the second leases a sanctify mark, and the pillar converts HP actually removed by all three rings into a capped heal. Only actual overheal becomes a capped temporary absorb shield. |
| `priest_censer` | Нерушимый Обет | The giant censer's chain orbit is a 7.6s strong temporary absorb window. Its activation-local owner-event adapter records the real Player `damage_absorbed` payload, stores only 65% up to its declared cap, and returns that stored value as one holy finish counter. No incoming hit means no counter damage. |
| `priest_chime` | Три Колокола Рассвета | Bell one interrupts normal targets; elite and boss policy rejects the movement lock and leaves a shortened stagger. Bell two sends a six-body falling holy chain. Bell three heals from that chain's actually removed HP and opens one activation-owned `death_save` window until the cast ends. |

The three signatures differ across at least targeting, timing and defensive
axes: Reliquary is a delayed 22-body sanctuary + sustain conversion, Censer is
an observed-damage defensive counter, and Chime is an 18-body interrupt followed
by a six-link chain and a short lethal-prevention window.

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
  teardown. It adds no Player or ClassWeapon branch and never estimates
  prevented damage from a requested incoming hit.
- Chime's resistance policy permits full normal interruption, removes movement
  lock on elites/bosses and shortens their stagger duration to 45%/25%.

| Weapon | Active lifetime | Crowd rail | Extra hard caps |
| --- | ---: | ---: | --- |
| Reliquary | 8.6s | 22 | 1.25s / 2.60s / 5.30s rings; 0.80 crowd falloff; 35% actual-damage heal; 46× base heal cap; 24× base shield cap |
| Censer | 7.6s | 12 | 65% observed-prevention storage; 56× base stored/counter cap; 0.75 counter falloff; one 6.30s finish burst |
| Chime | 6.4s | 18 | 0.50s / 2.30s / 4.10s tolls; six chain links; 2.30s lethal-prevention window |

## Balance proof

The focused balance test derives each weapon's normal `damage ×
ultimate_multiplier` and prices the declared cap against the shared 20–35
second activation corridor. Reliquary is paid partly in its delayed
actual-damage sustain, Censer has no offensive value unless actual prevention
occurred, and Chime pays for its six-link crowd chain with a short defensive
window. The proof also mutates the Chime coefficient out of corridor and
requires that mutation to fail, preventing an always-green balance gate.

| Weapon | Solo / budget midpoint | Crowd AoE / midpoint | Crowd cap | Defense window |
| --- | ---: | ---: | ---: | ---: |
| Reliquary | 1.016 | 1.156 | 22 | 3.30s shield tail |
| Censer | 1.008 | 1.042 | 12 | 7.60s mitigation |
| Chime | 0.991 | 1.208 | 18 | 2.30s lethal prevention |

The composite is 1.005 on solo, 1.135 on crowd AoE and 1.000 on the declared
defense axis; its four-axis score is 1.035, inside the 0.90–1.10 class
corridor. The individual weapons stay distinct: Censer owns the long
protection window, Chime leads crowd pressure, and Reliquary is the delayed
sustain conversion.

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
