# A5 offensive family fragment (FAN-1512)

`offensive_family_ab.json` is a standalone A/B record for five production
attack families. The versioned matrix derives every runtime class/weapon pair
from `ProgressionData.WEAPONS_BY_CLASS` (51 pairs), maps it to direct,
projectile, beam, chain, or area, and records each schema-6 final's expected
event. One representative from each family is run twice with the same pinned
seed: once with its final node and once with only that node removed.

The representatives collectively cover the 80px minimum, formula-expected
distance, practical range, forward/diagonal/reverse orientations, and solo and
pack target layouts. `ab_verdict` is green only when both arms have casts,
hits, targets, source damage and the enabled arm alone resolves the expected
event. `formula_live_verdict` stays independently red above ±35%; that does
not rewrite or reconcile the observed delta.

Regenerate each bounded checkpoint, then merge them:

```text
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/offensive/offensive_family_probe.gd -- --pair=assassin/venom_wire
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/offensive/offensive_family_probe.gd -- --pair=berserk/sword
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/offensive/offensive_family_probe.gd -- --pair=chemist/blast_powder
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/offensive/offensive_family_probe.gd -- --pair=dark_mage/dark_wand
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/offensive/offensive_family_probe.gd -- --pair=sniper/sniper_deadeye_rifle
python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5/scenarios/offensive/offensive_family_probe.gd -- --merge
```

Verify the contract and committed fragment without replaying live combat:

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/a5/scenarios/offensive_family_pack_test.gd
```
