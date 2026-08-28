# Robot weapon ultimate reference pack

FAN-2537 reconciles the three accepted Robot ultimate profiles with Ultimate
Direction v2 coverage. The aggregate card records the shared coverage ledger,
deterministic effectiveness evidence, and focused class tests; the weapon-local
executors, overlays, scenes, and presentation adapter remain unchanged.

| Weapon | Identity | Reach contract |
| --- | --- | --- |
| `robot_magnetic_anchor` | singularity pull, implosion, EMP release | every eligible target in the existing anchor geometry |
| `robot_hydraulic_press` | repeated corridor crush and release | every eligible target in the existing press geometry |
| `robot_reactor_core` | accelerating vent waves and absorb window | fixed nearest-target vent lanes plus full-set terminal exhaust |

The `performance.crowd_cap` values in `manifest.json` are presentation node
budgets owned by FAN-1541. They remain unchanged and must not be interpreted as
enemy-count limits. The v2 conversion is proven by the shared harness and by
the absence of count-shaped target parameters in all three executor sources.

The manifest's `effectiveness_evidence` section mirrors the six canonical
scenarios from `build/ultimate_effectiveness_baseline.json`. Baseline and final
metrics are intentionally identical for this aggregate-only change; only the
report label differs.

Focused checks:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/robot_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/robot_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/robot_ultimate_balance_test.gd
```
