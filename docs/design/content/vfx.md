<!-- content-registry-section -->

# FantasyDisk Content Registry — VFX И Projectiles

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## VFX-Ассеты Эффектов

Папка: `assets/sprites/effects/`. Генераторы: `tools/generate_attack_vfx.py` (оружие игрока), `tools/generate_elite_vfx.py` (уникальные атаки элиток), `tools/generate_elite_boss_vfx_015.py` (SCRUM-261 elite/boss skill VFX), `tools/generate_unique_weapon_vfx_015.py` (SCRUM-258 unique weapon identity plates). Все PNG с прозрачным фоном.

Опасные зоны врагов/босса (2026-06-12, обновлено SCRUM-261) оформлены через `scripts/hazard_vfx.gd` (`HazardVfx.telegraph`/`detonate`): базовый `hazard_zone.png` остается tint-friendly warning circle, затем `impact_ring`+`impact_flash` дают момент детонации, для яда — бурлящая `poison_pool` лужа. После SCRUM-261 `HazardVfx` выбирает dedicated painterly D&D texture по runtime node name: `BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`, а также shield/summon/aura helpers. Тайминги, урон, радиусы и node names не менялись.

Оружие игрока (используются `scripts/attack_vfx.gd`):

| Файл | Назначение | Статус |
| --- | --- | --- |
| `slash_arc.png` | Дуга-слэш меча/топора и конусных атак (тонируемый) | Реализовано |
| `impact_ring.png` | Ударное кольцо (молот, импульсы, взрывы) | Реализовано |
| `impact_flash.png` | Звездная вспышка попадания | Реализовано |
| `dust_puff_0..2.png` | Клубы пыли удара молота | Реализовано |
| `void_orb.png` | Снаряд темной книги | Реализовано |
| `beam_strip.png` | Луч темного жезла | Реализовано |
| `sound_wave.png` | Звуковая волна электрогитары | Реализовано |
| `music_note.png` | Ноты гитарных атак | Реализовано |
| `poison_pool.png` | Растровая пузырящаяся poison/acid pool Химика вместо программного круга | Реализовано |
| `spark_pool.png` | Растровое spark-cloud пятно Взрывной пыли Химика вместо программного круга | Реализовано |
| `briar_pool.png` | Растровая thorn/briar зона Друида вместо программного круга | Реализовано |

VFX pass 2026-06-12: `ClassWeapon._spawn_damage_pool()` больше не рисует видимый `Polygon2D`-диск для persistent pools. Химик/Друид используют эти PNG как `Sprite2D` с мягким scale/rotation pulse; damage radius/tick timing остались из weapon config. QA preview: `docs/design/previews/vfx_pool_assets_contact.png`.

D&D VFX restyle pass 2026-06-12: все 19 PNG в `assets/sprites/effects/` заменены на сдержанный tabletop fantasy style без кислотного неона и пересветов. Размеры/имена/alpha сохранены; `hazard_zone` и `elite_telegraph_circle` оставлены warm-neutral/tintable под кодовую модуляцию. Non-runtime QA preview вынесен из `assets/` в `build/cleanup_backup_2026_06_12/assets/sprites/effects/effects_dnd_preview.png`.

SCRUM-261 elite/boss VFX pass 2026-06-14: добавлены dedicated 512x512/256x256 PNG для новых mechanics SCRUM-259: `boss_gravity_well_zone.png`, `boss_vampiric_bite_zone.png`, `boss_rift_zone.png`, `boss_bone_prison_zone.png`, `boss_brood_web_zone.png`, `boss_ash_ember_zone.png`, `boss_molten_armor_pulse.png`, `enemy_summon_portal.png`, `enemy_shield_block_front.png`, `enemy_reflect_thorns_aura.png`, `enemy_command_aura_pulse.png`, `enemy_shadow_blink_mark.png`, `enemy_shard_fan_burst.png`. QA/contact preview: `docs/design/previews/scrum261_elite_boss_vfx_contact.png`.

SCRUM-258 unique weapon VFX pass 2026-06-14: добавлены 51 dedicated `256x256` RGBA PNG `vfx_weapon_<weapon_id>.png` для всех текущих `ProgressionData.WEAPONS_BY_CLASS` weapon IDs. Это короткие D&D/painterly VFX-пластины под реальные mechanics SCRUM-256/251/254/245: melee execute/cleave/stagger, charged shots/traps, drain/status links, summon/deploy identities, auras and buff/debuff reads. `scripts/attack_vfx.gd::weapon_signature()`, `scripts/class_weapon.gd::_spawn_weapon_signature()` и SCRUM-335 `scripts/berserk_weapon.gd::_show_weapon_signature()` подключают их визуально по `weapon_id` без изменения урона, формул, targeting, cooldowns или таймингов. QA previews: `docs/design/previews/scrum258_unique_weapon_vfx_contact.png`, `docs/design/previews/scrum258_unique_weapon_vfx_readability.png`.

SCRUM-337 attack VFX source regeneration 2026-06-14: весь активный runtime-пак эффектов атак пересобран через `fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`) и deterministic sheet-cut pipeline `tools/build_scrum337_attack_vfx_from_sources.py`. Заменены на месте 83 `assets/sprites/effects/*.png` и 2 `assets/sprites/projectiles/*.png`; имена, размеры, alpha/RGBA и runtime-пути сохранены. Source sheets/manifest: `docs/design/references/attack_vfx_realistic_dark_fantasy/`; QA previews: `docs/design/previews/scrum337_attack_vfx_core_contact.png`, `docs/design/previews/scrum337_attack_vfx_weapon_contact.png`. Gameplay timing, damage, targeting, formulas и Back-end runtime logic не менялись.

SCRUM-756 attack VFX targeted redraw 2026-07-01: `vfx_weapon_priest_reliquary.png` заменен через PixelLab MCP / `fantasydisk-asset-generator` как отдельная полупрозрачная sanctify-seal пластина с ghost-силуэтом `assets/sprites/weapons/priest_reliquary.png`. Runtime path, размер `256x256`, alpha/RGBA контракт, gameplay timing, damage, healing, targeting, formulas и Back-end runtime logic не менялись. Evidence: `docs/design/references/weapon_attack_animations/priest_reliquary/manifest.json`, preview `docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png`.

Иконки артефактов: `assets/sprites/ui/icons/artifacts/artifact_*.png` (71 шт., 256x256; SCRUM-606/609 добавили 10 dedicated icons для новых artifact IDs, SCRUM-619/623 добавили `rift_key`). Финальный Design pass SCRUM-340 от 2026-06-14: все активные артефакты пересозданы через `fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`) как realistic epic D&D/dark-fantasy raster magic items с прозрачным фоном. Это не пентаграммы, не плоские UI-symbols и не векторные пиктограммы: каждый файл содержит отдельный нарисованный предмет с объемом, материалами, магическим светом и смысловой привязкой к `ProgressionData.ARTIFACTS`. Source references для SCRUM-606/609 лежат в `docs/design/references/icons/artifacts/<id>/`; QA evidence: `docs/design/previews/artifact_icons_606_609_contact.png` и `docs/design/reports/artifact_icons_606_609_qa.md`. Предыдущие пассы (flat v1, dark fantasy v2, glossy RPG v3, concept-sheet tile/cut pass, per-item pictogram pass, 2026-06-12 raster sheet pass) superseded.

Таймер боя: `assets/sprites/ui/hud/timer_frame.png` и `assets/sprites/ui/hud/timer_frame_alarm.png` (оба 300x90, прозрачный фон) — фэнтези-рамка под цифры (золотая окантовка, темная ниша, самоцветы по бокам, гребень сверху). Для тревоги Back-end просто меняет текстуру на `timer_frame_alarm.png` (красное свечение и красные самоцветы) — программная подсветка не нужна. Генерируются тем же инструментом.

Reward frame kit SCRUM-338 (Design-ready, Back-end integration handoff):
`assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`,
`ui_frame_reward_card_hover.png`,
`ui_frame_reward_elite_artifact_card.png`,
`ui_frame_reward_elite_artifact_card_hover.png` (`768x1024`, RGBA,
transparent). Source references and safe-zone metadata:
`docs/design/references/rewards/reward_frames_scrum338_metadata.json`; QA preview:
`docs/design/previews/reward_frames_scrum338_contact_safe_zones.png`. Runtime
content must stay inside documented content margins: battle reward card
`Vector4(132, 170, 132, 164)`, elite artifact card
`Vector4(150, 202, 150, 190)`.

Economy node frame kit SCRUM-332 (Design-ready, Back-end integration handoff):
`assets/sprites/ui/frames/economy/ui_frame_economy_panel.png`,
`ui_frame_economy_choice_card.png`, `ui_frame_economy_choice_card_hover.png`,
`ui_frame_economy_dragon_panel.png`, `ui_frame_economy_price_badge.png`,
`ui_frame_economy_tooltip.png`. Mockup/spec:
`docs/design/mockups/scrum332_shop_economy/spec.md`; generated references:
`docs/design/references/ui_overhaul_shop_economy/`; preview:
`docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`. Content
must stay inside the documented safe zones, especially for the irregular dragon
panel.

Wide economy choice-card Design candidate SCRUM-437:
`assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png` and
`ui_frame_economy_choice_card_wide_hover.png` (`960x640`, RGBA transparent).
Source/margins contract:
`docs/design/references/scrum437_wide_economy_choice_card/scrum437_wide_economy_choice_card_metadata.json`;
spec and previews:
`docs/design/mockups/scrum437_wide_economy_choice_card/spec.md`,
`docs/design/previews/scrum437_wide_economy_choice_card_safe_zone.png`.
Status: Design-ready, Back-end runtime integration pending; visible content must
stay inside `Rect2(132,118,696,394)`.

Progression frame kit SCRUM-331 (Design-ready, Back-end integration handoff):
`assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png`,
`ui_frame_progression_branch_panel.png`, `ui_frame_progression_node_available.png`,
`ui_frame_progression_node_locked.png`, `ui_frame_progression_node_purchased.png`,
`ui_frame_progression_node_focus.png`, `ui_frame_progression_class_panel.png`,
`ui_frame_progression_points_badge.png`, `ui_frame_progression_tooltip.png`.
Mockup/spec: `docs/design/mockups/scrum331_progression_codex/spec.md`;
generated references: `docs/design/references/ui_overhaul_progression_codex/`;
preview: `docs/design/previews/scrum331_progression_frame_kit_contact.png`.
Circular node content must stay within the documented inner circle; the existing
SCRUM-345/SCRUM-403 Codex texture kit remains the live Codex baseline.

Уникальные атаки элиток (имена зафиксированы для Back-end интеграции, не переименовывать):

| Файл | Размер | Назначение | Статус |
| --- | --- | --- | --- |
| `elite_shockwave_ring.png` | 512x512 | Кольцевая ударная волна slam-атаки Железного Оплота | Ассет готов |
| `elite_shadow_trail.png` | 256x128 | Шлейф тени рывка Ночного Сталкера | Ассет готов |
| `elite_poison_lob.png` | 96x96 | Ядовитый снаряд Чумного Пророка | Ассет готов |
| `elite_crystal_shard.png` | 96x96 | Кристальный осколок Маршала Осколков (острие +X) | Ассет готов |
| `elite_telegraph_circle.png` | 512x512 | Универсальный круг-предупреждение зоны атаки | Ассет готов |
| `enemy_shadow_blink_mark.png` | 512x512 | Метка выхода/удара `shadow_strike` Ночного Сталкера | Ассет готов |
| `enemy_shard_fan_burst.png` | 512x512 | Предупреждение веера/кольца осколков `shard_fan` | Ассет готов |
| `enemy_shield_block_front.png` | 256x256 | Короткий фронтальный VFX щита для `shield_block` | Ассет готов |
| `enemy_reflect_thorns_aura.png` | 512x512 | Аура отражающих шипов `reflect_thorns` | Ассет готов |
| `enemy_command_aura_pulse.png` | 512x512 | Аура усиления `aura_buff` Маршала Осколков | Ассет готов |

VFX новых боссовских mechanics SCRUM-259/SCRUM-261:

| Файл | Runtime node/mechanic | Назначение | Статус |
| --- | --- | --- | --- |
| `boss_gravity_well_zone.png` | `BossGravityWell` | Фиолетовая гравитационная воронка Стража Разлома | Ассет готов |
| `boss_vampiric_bite_zone.png` | `BossVampiricBite` | Кровавый круг укуса/вампиризма Пожирателя Диска | Ассет готов |
| `boss_rift_zone.png` | `BossRiftZone` | Разломная зона Стража/волны разлома | Ассет готов |
| `boss_bone_prison_zone.png` | `BossRiftZone` + `boss_behavior=bone_archon` | Костяная тюрьма/стена Архонта | Ассет готов |
| `boss_brood_web_zone.png` | `BroodWebZone` | Паутинная зона Матери Роя | Ассет готов |
| `boss_ash_ember_zone.png` | `AshEmberZone` | Тлеющая зона Пепельного Колосса | Ассет готов |
| `boss_molten_armor_pulse.png` | `BossMoltenArmorPulse` | Раскаленный импульс брони Колосса | Ассет готов |
| `enemy_summon_portal.png` | summon/retinue helper | Портал призыва свиты | Ассет готов |

## Projectiles И VFX Assets

| ID | Игровое имя | Роль | Ассет | Статус |
| --- | --- | --- | --- | --- |
| `enemy_magic_projectile` | Магический снаряд монстра | Маленький заметный снаряд врагов/боссов | `assets/sprites/projectiles/enemy_projectile_magic_64.png` | Реализовано |
| `player_projectile_spark` | Искра игрока | Базовый снаряд игрока вместо Polygon2D placeholder | `assets/sprites/projectiles/player_projectile_spark_64.png` | Реализовано |

SCRUM-335 runtime VFX coverage: `enemy_magic_projectile` дополнительно использует существующие `assets/sprites/effects/beam_strip.png`, `impact_flash.png` и `impact_ring.png` как textured trail/impact feedback в `scripts/enemy_projectile.gd`; gameplay-параметры снаряда не менялись.

SCRUM-337 обновил сами projectile/VFX PNG как часть full attack VFX art pass: `enemy_projectile_magic_64.png` и `player_projectile_spark_64.png` остаются теми же canonical ID/path, но получили новый painterly D&D/dark-fantasy raster treatment с прозрачным фоном.

SCRUM-1066 supersedes the single player-spark runtime contract for canonical
weapons. `scripts/projectile_visual_registry.gd` consumes the accepted
SCRUM-1065 manifest through its export-safe normalized copy
`assets/data/projectile_visual_profiles.json`, keyed by canonical `weapon_id`, and validates all
20 mapped profiles before use. They resolve existing
`res://assets/sprites/projectiles/player/**` textures; the other 31 inventory
rows are intentionally non-projectile. `void_orb.png` and
`player_projectile_spark_64.png` are forbidden fallbacks for registered player
projectile weapons; the old scene remains only as a profile-driven legacy API.

SCRUM-1065 добавляет канонический PixelLab-first player-projectile pack вместо
универсального фиолетового orb. Полный machine-readable inventory находится в
`docs/design/references/SCRUM-1065_player_projectiles/manifest.json`: 17/17
классов, 51/51 selectable weapons, 20 flying/projectile-like visual profiles и
31 механически обоснованный `intentional_non_projectile`. Production PNG лежат
под `assets/sprites/projectiles/player/<character_id>/`; это Design handoff для
SCRUM-1066, поэтому runtime routing в этой задаче не менялся.

| Projectile visual ID | Weapon | Runtime asset |
| --- | --- | --- |
| `soldier_arquebus_round` | `soldier_rifle` | `assets/sprites/projectiles/player/soldier/soldier_arquebus_round.png` |
| `soldier_fuse_grenade` | `soldier_grenade` | `assets/sprites/projectiles/player/soldier/soldier_fuse_grenade.png` |
| `thief_ricochet_coin` | `thief_coin_pouch` | `assets/sprites/projectiles/player/thief/thief_ricochet_coin.png` |
| `thief_smoke_bomb` | `thief_smoke_bomb` | `assets/sprites/projectiles/player/thief/thief_smoke_bomb.png` |
| `elementalist_meteor` | `elementalist_meteor_core` | `assets/sprites/projectiles/player/elementalist/elementalist_meteor.png` |
| `sniper_shatter_round` | `sniper_shatter_rounds` | `assets/sprites/projectiles/player/sniper/sniper_shatter_round.png` |
| `engineer_sentry_round` | `engineer_sentry_wrench` | `assets/sprites/projectiles/player/engineer/engineer_sentry_round.png` |
| `dark_mage_mirror_page` | `dark_book` | `assets/sprites/projectiles/player/dark_mage/dark_mage_mirror_page.png` |
| `dark_mage_cursed_skull` | `cursed_skull` | `assets/sprites/projectiles/player/dark_mage/dark_mage_cursed_skull.png` |
| `dark_mage_chain_bolt` | `dark_wand` | `assets/sprites/projectiles/player/dark_mage/dark_mage_chain_bolt.png` |
| `assassin_void_chakram` | `chakrams` | `assets/sprites/projectiles/player/assassin/assassin_void_chakram.png` |
| `ranger_moon_bolt` | `moon_crossbow` | `assets/sprites/projectiles/player/ranger/ranger_moon_bolt.png` |
| `ranger_storm_arrow` | `storm_longbow` | `assets/sprites/projectiles/player/ranger/ranger_storm_arrow.png` |
| `doctor_restore_potion` | `restore_potion` | `assets/sprites/projectiles/player/doctor/doctor_restore_potion.png` |
| `doctor_plague_syringe` | `plague_syringe` | `assets/sprites/projectiles/player/doctor/doctor_plague_syringe.png` |
| `chemist_blast_powder` | `blast_powder` | `assets/sprites/projectiles/player/chemist/chemist_blast_powder.png` |
| `chemist_acid_flask` | `acid_flask` | `assets/sprites/projectiles/player/chemist/chemist_acid_flask.png` |
| `druid_briar_seed` | `briar_staff` | `assets/sprites/projectiles/player/druid/druid_briar_seed.png` |
| `druid_spectral_raven` | `raven_totem` | `assets/sprites/projectiles/player/druid/druid_spectral_raven.png` |
| `biologist_sample_dart` | `biologist_sample_injector` | `assets/sprites/projectiles/player/biologist/biologist_sample_dart.png` |

## Sprite QA Notes

Активные спрайты персонажей, стандартных монстров, элиток, боссов, оружия, projectiles, pickups, route icons и UI icons проходят quality-audit перед сдачей визуальных задач. После аудита 2026-06-10 у `assets/sprites/enemies/enemy_suicide_runner.png` удален лишний правый фрагмент текстуры; активные pickup/player projectile больше не используют Polygon2D-placeholder как видимый слой.

SCRUM-177 read-only sprite audit 2026-06-13: отчет `docs/design/reviews/sprite_visual_audit_2026_06.md`, contact sheets `docs/design/previews/audit_*.png`, inventory `docs/design/reviews/sprite_visual_audit_inventory_2026_06.*`. Вывод: активные персонажи/оружие/основные враги/артефакты/фоны в целом соответствуют D&D/dark-fantasy канону; отдельные 0.1.4 follow-up задачи заведены для placeholder/tint новых боссов и мини-элиток, polish VFX, унификации derived/shop UI icons и cleanup legacy placeholder sprites.

SCRUM-269 read-only asset/image cleanup audit 2026-06-14: отчет `docs/design/reviews/cleanup_assets_audit_2026_06.md`. Мертвого игрового арта не найдено: 51 `vfx_weapon_<weapon_id>.png`, 18 canonical weapon PNG, новые boss/mini-elite source sprites, marketing collateral и dynamic UI/icon/cutout families защищены от ложных cleanup-срабатываний. Реальный мусор ограничен orphan ` 2.png.import` sidecars после SCRUM-270; cleanup передан и выполнен отдельной Back-end задачей SCRUM-271.
