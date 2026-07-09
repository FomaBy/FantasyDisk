# SCRUM-691 Attribute Icon OpenAI Redraw QA

> Историческая справка: упоминания `sound_wave_damage` в этом документе описывают состояние ДО SCRUM-898 (2026-07-10). Звуковая ось урона удалена; оружия Гитариста/Друида бьют магией (`magic_damage`).

- Generated: 2026-06-30T09:11:33.939057+00:00
- Generator: OpenAI `gpt-image-2` through `fantasydisk-asset-generator/scripts/generate_asset.py` (`--quality high --size 1024x1024 --no-task`).
- Task exception: SCRUM-691 explicitly overrides the normal PixelLab-first icon workflow and requires OpenAI/ChatGPT image generation.
- Runtime export: 256x256 RGBA PNG, centered crop, transparent padding for 32/40/64 readability.
- Contact sheet: `docs/design/previews/attribute_icons_openai_redraw_contact.png`

## Automated Checks

- Source count: 35/35 OpenAI PNGs
- Runtime count: 35/35 PNGs
- Duplicate runtime SHA groups: 0
- Missing targets: none
- Alpha/size issues: none

## Runtime Exports

| ID | Runtime path | Source evidence | SHA-256 | Content bbox |
| --- | --- | --- | --- | --- |
| `strength` | `assets/sprites/ui/icons/stats/stat_strength.png` | `docs/design/references/icons/stats/strength/strength_source_openai.png` | `b77065cb0b60a602` | `(62, 36, 194, 220)` |
| `agility` | `assets/sprites/ui/icons/stats/stat_agility.png` | `docs/design/references/icons/stats/agility/agility_source_openai.png` | `09cf4b34a0fe1eed` | `(58, 37, 198, 220)` |
| `intelligence` | `assets/sprites/ui/icons/stats/stat_intelligence.png` | `docs/design/references/icons/stats/intelligence/intelligence_source_openai.png` | `06a825d3bb0d3b71` | `(36, 47, 220, 207)` |
| `perception` | `assets/sprites/ui/icons/stats/stat_perception.png` | `docs/design/references/icons/stats/perception/perception_source_openai.png` | `9115718e01810110` | `(38, 37, 218, 219)` |
| `energy` | `assets/sprites/ui/icons/stats/stat_energy.png` | `docs/design/references/icons/stats/energy/energy_source_openai.png` | `db8816cc0c871112` | `(51, 36, 205, 220)` |
| `knowledge` | `assets/sprites/ui/icons/stats/stat_knowledge.png` | `docs/design/references/icons/stats/knowledge/knowledge_source_openai.png` | `0e877b28b15fd722` | `(55, 36, 201, 219)` |
| `endurance` | `assets/sprites/ui/icons/stats/stat_endurance.png` | `docs/design/references/icons/stats/endurance/endurance_source_openai.png` | `409c9f32ab0a613c` | `(47, 37, 209, 219)` |
| `leadership` | `assets/sprites/ui/icons/stats/stat_leadership.png` | `docs/design/references/icons/stats/leadership/leadership_source_openai.png` | `ac8228cf157b01e2` | `(54, 36, 202, 220)` |
| `damage` | `assets/sprites/ui/icons/derived/attr_damage.png` | `docs/design/references/icons/attributes/damage/damage_source_openai.png` | `526b29772f50c8a9` | `(45, 36, 211, 220)` |
| `magic_damage` | `assets/sprites/ui/icons/derived/attr_magic_damage.png` | `docs/design/references/icons/attributes/magic_damage/magic_damage_source_openai.png` | `42acb03a7693d4f5` | `(44, 36, 212, 220)` |
| `sound_wave_damage` | `assets/sprites/ui/icons/derived/attr_sound_wave_damage.png` | `docs/design/references/icons/attributes/sound_wave_damage/sound_wave_damage_source_openai.png` | `7e51979991b9db3b` | `(41, 37, 215, 219)` |
| `crit_chance` | `assets/sprites/ui/icons/derived/attr_crit_chance.png` | `docs/design/references/icons/attributes/crit_chance/crit_chance_source_openai.png` | `e8938e2f26140ddd` | `(59, 36, 197, 220)` |
| `crit_damage_multiplier` | `assets/sprites/ui/icons/derived/attr_crit_damage_multiplier.png` | `docs/design/references/icons/attributes/crit_damage_multiplier/crit_damage_multiplier_source_openai.png` | `26c894efd86c2249` | `(58, 36, 197, 220)` |
| `attack_speed` | `assets/sprites/ui/icons/derived/attr_attack_speed.png` | `docs/design/references/icons/attributes/attack_speed/attack_speed_source_openai.png` | `cfc0a3135bc12fc8` | `(55, 36, 201, 220)` |
| `dodge` | `assets/sprites/ui/icons/derived/attr_dodge.png` | `docs/design/references/icons/attributes/dodge/dodge_source_openai.png` | `d4733a219d84d2ca` | `(37, 49, 220, 206)` |
| `move_speed` | `assets/sprites/ui/icons/derived/attr_move_speed.png` | `docs/design/references/icons/attributes/move_speed/move_speed_source_openai.png` | `aed67e2ec8eae34a` | `(36, 41, 220, 214)` |
| `defense` | `assets/sprites/ui/icons/derived/attr_defense.png` | `docs/design/references/icons/attributes/defense/defense_source_openai.png` | `157eeef00c863273` | `(64, 37, 191, 219)` |
| `absorb` | `assets/sprites/ui/icons/derived/attr_absorb.png` | `docs/design/references/icons/attributes/absorb/absorb_source_openai.png` | `3a9a5d495c0189d4` | `(80, 36, 176, 220)` |
| `health_point` | `assets/sprites/ui/icons/derived/attr_health_point.png` | `docs/design/references/icons/attributes/health_point/health_point_source_openai.png` | `a8e0dd0af2b50906` | `(45, 36, 210, 218)` |
| `knockback_distance` | `assets/sprites/ui/icons/derived/attr_knockback_distance.png` | `docs/design/references/icons/attributes/knockback_distance/knockback_distance_source_openai.png` | `16785e6feb47eb50` | `(37, 36, 218, 220)` |
| `summon_amount` | `assets/sprites/ui/icons/derived/attr_summon_amount.png` | `docs/design/references/icons/attributes/summon_amount/summon_amount_source_openai.png` | `7be7ac4b098f829f` | `(56, 37, 199, 220)` |
| `attack_range` | `assets/sprites/ui/icons/derived/attr_attack_range.png` | `docs/design/references/icons/attributes/attack_range/attack_range_source_openai.png` | `876a56808bb382a4` | `(36, 37, 220, 218)` |
| `range_multiplier` | `assets/sprites/ui/icons/derived/attr_range_multiplier.png` | `docs/design/references/icons/attributes/range_multiplier/range_multiplier_source_openai.png` | `a6594475cddc4c5f` | `(37, 47, 219, 209)` |
| `regeneration` | `assets/sprites/ui/icons/derived/attr_regeneration.png` | `docs/design/references/icons/attributes/regeneration/regeneration_source_openai.png` | `86073297cf999212` | `(59, 36, 196, 220)` |
| `vampiric_amount` | `assets/sprites/ui/icons/derived/attr_vampiric_amount.png` | `docs/design/references/icons/attributes/vampiric_amount/vampiric_amount_source_openai.png` | `a90a17ae82e8a84c` | `(59, 36, 197, 220)` |
| `vampiric_chance` | `assets/sprites/ui/icons/derived/attr_vampiric_chance.png` | `docs/design/references/icons/attributes/vampiric_chance/vampiric_chance_source_openai.png` | `098c3f28bceee7e3` | `(57, 36, 199, 220)` |
| `dot_damage` | `assets/sprites/ui/icons/derived/attr_dot_damage.png` | `docs/design/references/icons/attributes/dot_damage/dot_damage_source_openai.png` | `2050159a9c2ca4ef` | `(81, 36, 175, 220)` |
| `dot_speed` | `assets/sprites/ui/icons/derived/attr_dot_speed.png` | `docs/design/references/icons/attributes/dot_speed/dot_speed_source_openai.png` | `519fbea85a9f5a6b` | `(69, 36, 187, 219)` |
| `aoe_radius` | `assets/sprites/ui/icons/derived/attr_aoe_radius.png` | `docs/design/references/icons/attributes/aoe_radius/aoe_radius_source_openai.png` | `61bcc4f0e035a7af` | `(37, 37, 219, 219)` |
| `aura_radius` | `assets/sprites/ui/icons/derived/attr_aura_radius.png` | `docs/design/references/icons/attributes/aura_radius/aura_radius_source_openai.png` | `411834aeaf13407b` | `(36, 36, 219, 220)` |
| `buff_power` | `assets/sprites/ui/icons/derived/attr_buff_power.png` | `docs/design/references/icons/attributes/buff_power/buff_power_source_openai.png` | `d3676a2bb64f5f0b` | `(78, 36, 178, 220)` |
| `knockback_power` | `assets/sprites/ui/icons/derived/attr_knockback_power.png` | `docs/design/references/icons/attributes/knockback_power/knockback_power_source_openai.png` | `97ded9b7eb634152` | `(38, 36, 218, 220)` |
| `projectile_speed` | `assets/sprites/ui/icons/derived/attr_projectile_speed.png` | `docs/design/references/icons/attributes/projectile_speed/projectile_speed_source_openai.png` | `440891d8df82e834` | `(45, 36, 211, 220)` |
| `ultimate_multiplier` | `assets/sprites/ui/icons/derived/attr_ultimate_multiplier.png` | `docs/design/references/icons/attributes/ultimate_multiplier/ultimate_multiplier_source_openai.png` | `4dd2ebe0d34422c7` | `(50, 37, 206, 219)` |
| `pickup_radius` | `assets/sprites/ui/icons/derived/attr_pickup_radius.png` | `docs/design/references/icons/attributes/pickup_radius/pickup_radius_source_openai.png` | `fdc686f514850de7` | `(36, 42, 220, 213)` |

## Manual Review Notes

- Contact sheet includes 64px, 40px, and 32px previews for every icon on a dark checker background.
- No text, letters, numeric labels, UI panels, or decorative frames were added in postprocess.
- Registry paths are expected to map every derived attribute ID to its own `attr_<id>.png` target after the code patch.
