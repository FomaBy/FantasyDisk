# Emergency Surgery — Ultimate Direction v2

`doctor/bone_saw` applies each orbit tick to every live enemy within its
declared `orbit_radius`; it has no target-count limit. Every standard enemy
therefore receives the same six-tick floor at solo, 5, 10, and 20 targets.

The whole-activation boss cap remains `8%` of the boss's maximum health. The
`rare_charge_ledger` still spends one full charge, blocks charge gain while the
ultimate is active, and permits one activation per encounter.

Run the focused proof with:

```sh
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/doctor_bone_saw_direction_v2_test.gd
```
