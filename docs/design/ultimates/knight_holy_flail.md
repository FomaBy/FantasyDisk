# Knight Holy Flail ultimate

`knight/holy_flail` is promoted by one convention-discovered class-local package. `long_spear`, `tower_shield`, the shared registry/controller/Player adapter, and the accepted Knight presentation assets remain unchanged.

## Ordered spiral

`Небесная Спираль` resolves seven strictly ordered source-centered turns over the accepted 7.6-second presentation. Radius grows monotonically from 90 to 430 pixels. Turns 0–5 pull inward; turn 6 changes sign exactly once and launches outward. Replayed turns are no-ops, out-of-order composition aborts, and every damage event is claimed once per target through `UltimateActivation`.

| Ledger entry | Normal | Epic | Boss |
| --- | ---: | ---: | ---: |
| Early signed impulse | `-240` | `-84` (×0.35) | `0` |
| Final signed impulse | `+720` | `+252` (×0.35) | `0` |
| Control duration | `1.2s` | `0.6s` (×0.50) | `0.24s` (×0.20), no movement lock |

The crowd cap is 20 unique targets per turn. A target may lose at most 35% of its own max health from the cast; a boss has the stricter frozen Knight whole-activation cap of 7%.

## Charge and cleanup

The overlay declares `rare_charge_ledger`: one full bar is spent once, a live effect cannot refill itself, and a refilled bar cannot buy a second cast in the same encounter. Continue restores charge only; active state and the encounter latch are transient.

The activation owns the spiral scene, accepted `KnightHolyFlailHeavenlySpiral` presentation child, tween, primitive ledger, target/event budgets, and leased slow statuses. Completion, cancel, death/node exit, encounter end, and new-run/Continue reset free or clear them. The package creates no signal subscription or persistent owner resource.

## Focused verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/knight_holy_flail_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/controller_runtime_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/knight_ultimate_timelines.gd
```
