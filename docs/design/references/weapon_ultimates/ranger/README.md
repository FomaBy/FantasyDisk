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

## Live four-viewport capture package (FAN-3889)

`docs/design/reference-assets-lfs/ranger-ultimate-timelines-fan3889/` holds four
contact sheets at 1152x648, 1280x720, 1920x1080 and 2560x1440. Each sheet is the
same twelve panels: the three canonical weapon IDs by four presentation modes.

| Mode | What the panel renders |
| --- | --- |
| `normal` | the shipped scene alone, at its beat |
| `crowded` | the same beat over the declared crowd cap of 12 |
| `reduced_motion` | the same beat with the shipped `screen_shake` toggle off |
| `photosensitivity_safe` | the same beat with the arena-wide backdrop veil suppressed |

Every panel is a real render of the shipped `.tscn`, driven through
`begin()`/`step()` in fixed steps and then held, so the sheets are reproducible
byte-for-byte. The two mode knobs are capture-side state: `screen_shake` is the
root meta `main.gd` already publishes, and the veil is suppressed on the
instanced copy. No production scene, VFX, gameplay or balance value changes.

Each panel reserves a HUD strip, a player column, two hazard markers and a state
caption, and the effect zone is disjoint from all of them — that disjointness is
what the gate checks, so "the ultimate stays readable" is measured rather than
asserted. Readability is judged on the 648p sheet.

`manifest.json` → `evidence.live_capture` pins the base commit and tree, the
capture script, the weapon IDs, the modes, the viewports and the sha256 object ID
of every committed PNG.

```bash
# Re-render the four sheets (windowed; a headless display has no render target).
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/ranger_ultimate_contact_capture.gd
# Gate the layout, the live composition and the committed evidence.
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/ranger_ultimate_timelines.gd
```

The FAN-1474 strip above and its renderer stay as they are; this package adds the
four viewport captures the shared visual-direction contract requires.
