# Knight weapon ultimates

The ready Knight trio is discovered only from its matching class-local package.
Each activation stays owned by the generic controller, so cancel, natural
completion, death/node exit, encounter end, and Continue/new-run reset clear
its scene, timers, transient ledgers, modifiers, and leased controls.

| Weapon ID | Identity | Bounded outcome | Boss/control rail |
| --- | --- | --- | --- |
| `long_spear` | aimed phalanx corridor | three ordered pierce rows and normal-only pin | 9% cast cap; epic and boss receive no pin or push |
| `tower_shield` | frontal guard and stored counter | measured eligible prevention fills one 80-point ledger; one 135° counter releases it to every eligible enemy in its arc | 7% cast cap; epic push/duration are 25%/50%, bosses receive no counter control |
| `holy_flail` | expanding pull-launch spiral | seven ordered turns, then one outward launch | 7% cast cap; epic controls are reduced and bosses never move |

## Tower Shield guard contract

`tower_shield` opens the existing generic measured-prevention seam with one
activation-local owner, `contact` as its only admitted source, the frozen 110°
front arc, and an 80-point resource cap. The ledger credits only
`incoming_amount - applied_amount`; wrong owner, source, direction, nominal
substitution, duplicate IDs, replay, a spent counter, or a finished activation
all fail closed in the shared owner-resource contract.

At 5.6 seconds the leaf consumes its resource exactly once. The counter uses
the accepted shield geometry: a 195px, 135° forward arc with no target-count
cap, and a 55% stored-damage conversion. Normal enemies receive the 230px push and
0.85-second slow; epic targets receive 25% push and 50% duration; bosses can
take the bounded player-owned counter damage but receive neither displacement
nor a status. The activation-owned scene reuses the approved
`KnightTowerShieldImpassableLine` presentation and removes only statuses it
leased itself.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/knight_tower_shield_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/knight_trio_integration_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/guard_prevention_resource_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/knight_ultimate_timelines.gd
```
