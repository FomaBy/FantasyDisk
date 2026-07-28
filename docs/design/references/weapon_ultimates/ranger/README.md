# Ranger weapon ultimate presentation pack

FAN-1474 supplies three isolated, class-local ultimate timelines. It does not
change targeting, damage, cooldowns, status effects, shared registries, or the
runtime adapter.

| Weapon | Presentation | Timeline |
| --- | --- | --- |
| `moon_crossbow` | Moon mark, aimed bolt, four-way silver split | 4.80 s |
| `storm_longbow` | Long storm corridor with tail-to-tip lightning beats | 4.45 s |
| `hunter_trap` | Three inward-closing trap-jaw rings | 5.35 s |

All timelines bind the frozen Ranger Cast IDs as `windup`, `release→execute`,
`active→active`, `recovery→recover`, and `cancel→cleanup`. The scene driver
delegates pause and `cancel` / `death` / `node_end` cleanup to
`WeaponUltimatePresentationTimeline`.

No raster asset was created in this package. `manifest.json` records the
accepted source/runtime VFX paths and the existing Storm Longbow PixelLab IDs.
The PixelLab MCP config smoke used `get_balance` and passed. The committed
contact sheet is rendered headlessly from the exact formation function used by
the scenes.

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://scenes/vfx/ultimates/ranger/ranger_ultimate_contact_sheet.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/ranger_ultimate_presentation_test.gd
```
