# A5 ultimate and Guild Atlas attribution fragment (FAN-1515)

`ultimate_atlas_attribution.json` is a standalone runtime record. It keeps the
class ultimate separate from the 51 sustain-only weapon rows: no per-weapon
row contains an ultimate field or is allowed to include ultimate damage.

Each of the 17 class kits is probed for 60 fixed seconds (3,600 frames) with
the same seed under no meta, full class constellation and legal Atlas-50. The
trace records initial charge, activation count/timing and damage with an
`ultimate_mechanic` source. Atlas-59 is retained only in the manifest as
`NON-PLAYABLE: cap 50`; it is never a runtime arm.

The stored formula starts from the controlled class stats and applies class and
Atlas modifiers exactly once. In particular, Atlas-50's `ult_start_charge` is
asserted against the runtime initial charge and frame-zero activation; other
Atlas effects remain in the separately recorded class formula and runtime arm.

Generate one deterministic class checkpoint at a time, then merge:

```text
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/ultimate_atlas/ultimate_atlas_probe.gd -- --class=berserk
# Repeat for each class reported by Pack.class_ids().
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/ultimate_atlas/ultimate_atlas_probe.gd -- --merge
```

Verify the frozen contract and the committed raw fragment without replaying the
60-second probes:

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/a5/scenarios/ultimate_atlas_attribution_test.gd
```
