# A5 ultimate and Guild Atlas attribution fragment (FAN-2412)

`ultimate_atlas_attribution.json` is a standalone runtime record. It keeps the
class ultimate separate from the 51 sustain-only weapon rows: no per-weapon
row contains an ultimate field or is allowed to include ultimate damage.

Each of the 17 class kits is probed for 60 fixed seconds (3,600 frames) with
the same seed under no meta, full class constellation and legal Atlas-50. The
trace records initial charge, activation count/timing and damage with a
central lifecycle provenance tag: `ultimate_provenance=activation` plus a
unique `ultimate_provenance_event_id`. This tag is written after executor
feedback, so every `UltimateActivation.deal_damage()` result is an
`ultimate_source` event even when an executor has no `ultimate_mechanic` tag.
All other damage is `sustain_source`; an event cannot belong to both.
Atlas-59 is retained only in the manifest as
`NON-PLAYABLE: cap 50`; it is never a runtime arm.

The direct-zero cases are explicit, evaluated declarations rather than an
implicit allowlist. Chemist's `acid_flask._corrode`, Elementalist's
`elementalist_meteor_core.impact/crater_pulse`, and Ranger's
`hunter_trap.snap/close_net` record zero only when their aimed area applies no
damage to a static dummy. Priest's `priest_censer.counter_burst` records zero
only because this fixture sets `contact_damage=0`, hence its ward receives no
absorbed damage to spend. Any other activated class with zero provenance
events is rejected by the fragment evaluator.

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

Run that full 17-class sequence twice from a clean checkout and compare the
two SHA-256 digests of `ultimate_atlas_attribution.json`; identical bytes are
the reproducibility requirement. `--fixed-fps 60` is part of every replay
command, not only the merge step. The probe samples the effective process
timestep before it measures an arm and records the observed process FPS and
delta in every measurement. It refuses to write certifying output unless all
samples are exactly the required `1/60` step; `Engine.max_fps = 60` alone is
only a wall-clock cap. Therefore any output produced without `--fixed-fps 60`
is untrusted and cannot be used as certifying attribution evidence.

Verify the frozen contract and the committed raw fragment without replaying the
60-second probes:

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/a5/scenarios/ultimate_atlas_attribution_test.gd
```
