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
runtime VFX, and weapon-sprite paths. The four contact sheets are rendered from
the same scene driver used by the package at 648p, 720p, 1080p, and 2K. Their
sheet title is centered from `ThemeDB.fallback_font.get_string_size(...)`; the
focused test verifies the measured title rectangle stays inside every sheet.

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/doctor_ultimate_timelines.gd
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/doctor_ultimate_contact_capture.gd
```
