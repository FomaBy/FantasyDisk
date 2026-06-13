# Unique Weapon And Elite/Boss VFX Kit

Обновлено: 2026-06-13

Design scope for SCRUM-258 and SCRUM-261. The kit adds named transparent PNG
assets for class identity attacks and elite/boss skill telegraphs. Runtime
mechanics and API wiring remain Back-end scope; animation timing and state
sync remain Animator scope.

Generator:

```text
tools/generate_unique_weapon_enemy_vfx.py
```

Previews:

```text
docs/design/previews/unique_weapons_vfx_contact.png
docs/design/previews/elite_boss_skills_vfx_contact.png
docs/design/previews/unique_enemy_vfx_readability_field_meadow.png
```

## Class / Weapon VFX Assets

| Class | Mechanic Family | Asset |
| --- | --- | --- |
| `berserk` | fury melee arc / heavy physical burst | `assets/sprites/effects/vfx_class_berserk_fury_arc.png` |
| `dark_mage` | void sigil / curse marker | `assets/sprites/effects/vfx_class_dark_mage_void_sigil.png` |
| `guitarist` | resonance pulse / rhythm wave marker | `assets/sprites/effects/vfx_class_guitarist_resonance_wave.png` |
| `assassin` | shadow dash / crit mobility trail | `assets/sprites/effects/vfx_class_assassin_shadow_dash.png` |
| `ranger` | focus mark / stance charge marker | `assets/sprites/effects/vfx_class_ranger_focus_mark.png` |
| `doctor` | drain/lifesteal beam | `assets/sprites/effects/vfx_class_doctor_drain_link.png` |
| `chemist` | chemical combo burst | `assets/sprites/effects/vfx_class_chemist_combo_burst.png` |
| `knight` | guard / counter block | `assets/sprites/effects/vfx_class_knight_counter_guard.png` |
| `druid` | command bloom / nature order pulse | `assets/sprites/effects/vfx_class_druid_command_bloom.png` |
| `soldier` | suppression tracer | `assets/sprites/effects/vfx_class_soldier_suppression_tracer.png` |
| `thief` | ricochet coin trail | `assets/sprites/effects/vfx_class_thief_ricochet_coin_trail.png` |
| `elementalist` | triune elemental orbit | `assets/sprites/effects/vfx_class_elementalist_orbit_triune.png` |
| `sniper` | deadeye mark / lockshot marker | `assets/sprites/effects/vfx_class_sniper_deadeye_mark.png` |
| `priest` | sanctify seal / holy support burst | `assets/sprites/effects/vfx_class_priest_sanctify_seal.png` |
| `biologist` | spore bloom | `assets/sprites/effects/vfx_class_biologist_spore_bloom.png` |
| `robot` | magnetic anchor field | `assets/sprites/effects/vfx_class_robot_magnetic_anchor_field.png` |
| `engineer` | sentry link beam | `assets/sprites/effects/vfx_class_engineer_sentry_link.png` |

## Elite / Boss Skill VFX Assets

| Skill Family | Asset |
| --- | --- |
| command aura / elite support pulse | `assets/sprites/effects/vfx_enemy_command_aura_pulse.png` |
| fire / ember hazard pool | `assets/sprites/effects/vfx_enemy_fire_pool.png` |
| acid hazard pool | `assets/sprites/effects/vfx_enemy_acid_pool.png` |
| heavy poison hazard pool | `assets/sprites/effects/vfx_enemy_poison_pool_heavy.png` |
| teleport entry gate | `assets/sprites/effects/vfx_enemy_teleport_gate_in.png` |
| teleport exit gate | `assets/sprites/effects/vfx_enemy_teleport_gate_out.png` |
| frontal shield / block | `assets/sprites/effects/vfx_enemy_shield_block_front.png` |
| summon portal | `assets/sprites/effects/vfx_enemy_summon_portal.png` |
| slow / gravity zone | `assets/sprites/effects/vfx_enemy_slow_gravity_zone.png` |
| Bone Archon bone spike field | `assets/sprites/effects/vfx_boss_bone_archon_bone_spikes.png` |
| Brood Mother web zone | `assets/sprites/effects/vfx_boss_brood_mother_web_zone.png` |
| Ashen Colossus ember slam | `assets/sprites/effects/vfx_boss_ashen_colossus_ember_slam.png` |
| shadow blink marker | `assets/sprites/effects/vfx_elite_shadow_blink_mark.png` |
| plague bell aura | `assets/sprites/effects/vfx_elite_plague_bell_aura.png` |
| spark wight static field | `assets/sprites/effects/vfx_elite_spark_wight_static_field.png` |

## Technical Notes

- All files are PNG/RGBA with transparent alpha and clean transparent corners.
- Sizes are `256x64`, `256x128`, `256x256`, or `512x512` depending on use.
- Assets are painterly D&D/tabletop VFX plates, not Godot primitive circles.
- The field readability preview checks the kit over `field_meadow.png`.
- Back-end can either use these as direct `Sprite2D.texture` plates or register
  them inside `AttackVfx` / `HazardVfx` helpers once SCRUM-256/SCRUM-259 mechanics
  finalize exact spawn timings and radii.
