# Doctor weapon ultimate presentation pack

FAN-1486 supplies three isolated, class-local presentation timelines. It does
not change damage, healing, shields, infection, armor shred, targeting,
cooldowns, balance, shared registries, or the live runtime adapter.

| Weapon | Presentation | Timeline |
| --- | --- | --- |
| `restore_potion` | Aimed giant flask, green outer pool, white inner spiral, shield crystal | 6.20 s |
| `plague_syringe` | Patient-zero pierce, branching veins, timed plague waves, mask vapor | 6.85 s |
| `bone_saw` | Fast close saw orbit, sparks, red-to-green drain ribbons, shield stitches | 3.85 s |

All timelines bind the frozen Doctor Cast IDs as `windup`,
`release→execute`, `active→active`, `recovery→recover`, and
`cancel→cleanup`. The class-local driver delegates pause and
`cancel` / `death` / `node_end` handle cleanup to
`WeaponUltimatePresentationTimeline`.

No raster asset was created. `manifest.json` records the accepted source,
runtime VFX, and weapon-sprite paths. The procedural scenes directly sample the
three `assets/sprites/weapons/*.png` files. The recorded
`vfx_weapon_<weapon_id>.png` files remain manifest/bridge inputs until FAN-1541
and are not sampled by the current procedural renderer.

Each of the four 648p, 720p, 1080p, and 2K contact sheets now shows release,
active, and recovery frames for every weapon, with measured phase/time labels.
The frames expose flask `GlassImpact` before the counter-rotating zones, the
syringe's late active arena wave before `MaskVaporBurst`, and the saw orbit/drain
before `ShieldStitches`. The focused test shares those frame timestamps and
asserts each beat inside its own sub-zone at every resolution. The sheet title,
panel labels, and frame labels are centered from
`ThemeDB.fallback_font.get_string_size(...)` and checked against their measured
rectangles.

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/doctor_ultimate_timelines.gd
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/doctor_ultimate_contact_capture.gd
```
