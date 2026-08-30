# Doctor weapon ultimate presentation pack

FAN-1486 supplies three isolated, class-local presentation timelines. FAN-2529
records their class-wide Ultimate Direction v2 aggregate without changing
damage, healing, shields, infection, armor shred, targeting, cooldowns, shared
registries, or the live runtime adapter.

| Weapon | Presentation | Timeline |
| --- | --- | --- |
| `restore_potion` | Aimed giant flask, green outer pool, white inner spiral, shield crystal | 3.40 s |
| `plague_syringe` | Patient-zero pierce, branching veins, timed plague waves, mask vapor | 3.90 s |
| `bone_saw` | Fast close saw orbit, sparks, red-to-green drain ribbons, shield stitches | 2.80 s |

All three timelines sit inside the Ultimate Direction v2 window
(2.5–4.0 s total, 0.6–1.0 s windup, at least 1.2 s between `release` and
`recovery`). The mechanics chain is unchanged and keeps running past the
presentation: damage, healing, shields, infection ramp, and armor shred come
from `data/ultimates/classes/doctor/`, never from these beats.

| Weapon | Identity | Reach contract |
| --- | --- | --- |
| `restore_potion` | aimed outer pool, healing spiral, and absorb shield | every eligible enemy receives the outer damage channel; the 220 px ring remains presentation geometry |
| `plague_syringe` | patient-zero pierce, infection waves, and mask finale | every eligible enemy receives the five fixed waves; `wave_visual_radius` is presentation-only |
| `bone_saw` | close orbit cuts, drain ribbons, and stitch shield | the existing 240 px orbit keeps its close-range identity without a count-shaped cap |

All timelines bind the frozen Doctor Cast IDs as `windup`,
`release→execute`, `active→active`, `recovery→recover`, and
`cancel→cleanup`. The class-local driver delegates pause and
`cancel` / `death` / `node_end` handle cleanup to
`WeaponUltimatePresentationTimeline`.

No raster asset was created here. Every animated frame comes from the nine
weapon-local PixelLab packs accepted under FAN-3613; each scene binds exactly
three of them through its `cast_frames`, `signature_frames`, and `impact_frames`
exports, and nothing else is sampled. `provenance_manifest_fan3613.json` holds
the pack-level provenance, and `manifest.json` records the same nine bindings
under `generator_provenance.bound_packs`.

| Weapon | `cast_frames` | `signature_frames` | `impact_frames` |
| --- | --- | --- | --- |
| `restore_potion` | `assets/sprites/effects/doctor/restore_potion/cast_flash/cast_flash_spriteframes.tres` | `assets/sprites/effects/doctor/restore_potion/poison_pool/poison_pool_spriteframes.tres` | `assets/sprites/effects/doctor/restore_potion/victim_impact/victim_impact_spriteframes.tres` |
| `plague_syringe` | `assets/sprites/effects/doctor/plague_syringe/cast_flash/cast_flash_spriteframes.tres` | `assets/sprites/effects/doctor/plague_syringe/infection_wave/infection_wave_spriteframes.tres` | `assets/sprites/effects/doctor/plague_syringe/victim_impact/victim_impact_spriteframes.tres` |
| `bone_saw` | `assets/sprites/effects/doctor/bone_saw/cast_flash/cast_flash_spriteframes.tres` | `assets/sprites/effects/doctor/bone_saw/orbit_slash/orbit_slash_spriteframes.tres` | `assets/sprites/effects/doctor/bone_saw/victim_impact/victim_impact_spriteframes.tres` |

The cast pack animates the weapon silhouette through the cast, the signature
pack draws the arena effect, and the impact pack is the per-victim burst the
executor beats trigger on the enemies a beat actually damaged.

Each of the four 648p, 720p, 1080p, and 2K contact sheets shows release,
active, and recovery frames for every weapon, with measured phase/time labels.
They are derived evidence regenerated from the final scenes, so they live in the
Git LFS zone `docs/design/reference-assets-lfs/doctor-ultimate-timelines-fan3691/`
that `tools/repository_storage_policy.py` mandates for changed design binaries.
The frames expose flask `GlassImpact` before the counter-rotating zones, the
syringe's late active arena wave before `MaskVaporBurst`, and the saw orbit/drain
before `ShieldStitches`. The focused test shares those frame timestamps and
asserts each beat inside its own sub-zone at every resolution. The sheet title,
panel labels, and frame labels are centered from
`ThemeDB.fallback_font.get_string_size(...)` and checked against their measured
rectangles.

The manifest's `effectiveness_evidence` section mirrors the six canonical
scenarios from `build/ultimate_effectiveness_baseline.json`. Baseline and
final metrics are intentionally identical for this aggregate-only change; the
shared coverage ratchet and class evidence are the changed surfaces.

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/doctor_ultimate_timelines.gd
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/doctor_ultimate_contact_capture.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/doctor_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/doctor_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/doctor_live_test.gd
```
