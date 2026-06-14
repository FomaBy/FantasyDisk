# BUG: Аудит оружия ВСЕХ персонажей — у Священника усилок вместо «Колокола»

Статус: done
Приоритет: high
Роль: Back-end (геймплей)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя)
Jira: SCRUM-277
QA: in_progress (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (отчёт пользователя)
«Надо перепроверить оружие всех персонажей — у меня Священник с усилком вместо
колокола! Надо всех проверить и убедиться, что у всех персонажей их оружие».

Симптом: в забеге за Священника вместо оружия **«Колокол Молитвы»**
(`priest_chime`, attack_mode `priest_prayer_chain`, scene
`res://scenes/PriestChime.tscn`) игрок получает «усилок» (пассивный предмет /
апгрейд), а не само оружие.

PM-проверка маппинга верхнего уровня: `WEAPONS_BY_CLASS["priest"] = PRIEST_WEAPONS`
содержит 3 корректных оружия (priest_reliquary «Светлый Реликварий», priest_censer
«Кадило Обета», priest_chime «Колокол Молитвы») — значит баг НЕ в этой таблице,
а ниже по цепочке (выдача/отображение в забеге, scene_path, codex, или
level-up/weapon-pickup путает оружие с пассивным предметом). Найти и починить.

## Требования
1. **Воспроизвести** баг со Священником и «Колоколом Молитвы»: где именно вместо
   оружия подставляется «усилок» (level-up выбор? стартовая выдача? codex?
   подмена scene/attack_mode? коллизия id с пассивным предметом, напр.
   `summoners_bell` в progression_data_content.gd?). Указать корневую причину.
2. **Сквозной аудит всех 17 классов**: для КАЖДОГО персонажа подтвердить, что его
   3 оружия:
   - присутствуют в его `*_WEAPONS` и в `WEAPONS_BY_CLASS`;
   - имеют существующий и корректный `scene_path` (.tscn реально есть);
   - имеют валидный `attack_mode` (есть ветка в player.gd/боевой логике);
   - корректно выдаются/отображаются в забеге (не подменяются пассивкой/усилком);
   - название/иконка/описание соответствуют классу (нет чужих оружий).
   Список классов: berserk, soldier, thief, elementalist, sniper, priest,
   biologist, robot, engineer, dark_mage, guitarist, assassin, ranger, doctor,
   chemist, knight, druid.
3. Починить все найденные расхождения (не только Священника).
4. **Тест** (smoke/новый): пройтись по всем character_ids, для каждого проверить
   `weapon_ids(id)` → ровно 3, каждое резолвится через `weapon(id, wid)` с
   непустыми scene_path + attack_mode; ни одно оружие не указывает на пассивный
   предмет; scene_path-файлы существуют. Зелёный прогон.
5. CHANGELOG; current_game_state; короткий отчёт-таблица «класс → 3 оружия → ОК».

## Files / Assets / IDs
- scripts/progression_data_weapons.gd (все *_WEAPONS, WEAPONS_BY_CLASS)
- scripts/progression_data.gd (weapon_ids 425, weapon 763, weapon_mechanic_identity 161)
- scripts/progression_data_content.gd (пассивные предметы, напр. summoners_bell:76)
- scripts/player.gd (configure_character 142; attack_mode ветки)
- scenes/*.tscn (оружейные сцены)
- tests/ (новый weapon_integrity_test.gd или расширить runtime_smoke_test)

## Acceptance Criteria
- [ ] Корневая причина бага Священника найдена и устранена (Колокол выдаётся как оружие).
- [ ] У всех 17 классов по 3 корректных оружия (data+scene+attack_mode+выдача), без чужих/пассивок.
- [ ] Новый/расширенный тест целостности оружия зелёный; 6 smoke зелёные.
- [ ] Отчёт-таблица в задаче/доке; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/combat.md, current_game_state.

## Result (2026-06-14)

Done. Root cause: `PriestChime.tscn` had the correct `weapon_id =
"priest_chime"` and `attack_mode = "priest_prayer_chain"`, but its
`WeaponVisual` texture still pointed at the Guitarist `sound_amp.png`. The
issue was not a collision with passive `summoners_bell`; it was a stale proxy
texture reference in the scene. The full audit found the same proxy-texture
class of bug in 18 scenes across Thief, Elementalist, Sniper, Priest, Biologist
and Engineer. All 18 now point to their canonical
`assets/sprites/weapons/<weapon_id>.png`.

Additional scene/data mismatches fixed:
- `TwoHandedAxe.tscn`: scene `attack_shape` now matches data (`sweep`).
- `RestorePotion.tscn`: scene `attack_mode` now matches data (`drain_link`).
- `PlagueSyringe.tscn`: scene `attack_mode` now matches data (`drain_link`).

New regression coverage:
- `tests/weapon_integrity_test.gd` checks all 17 classes and 51 weapons:
  exactly 3 weapon IDs per class, non-empty config/scene marker, no passive/shop
  ID collision, existing scene and canonical texture, scene `weapon_id`, scene
  attack mode/shape for the owning script, and actual
  `Player.configure_character(character, weapon)` equipped visual.

Audit table:

| Class | Weapons | Status |
| --- | --- | --- |
| berserk | sword, axe, hammer | OK |
| soldier | soldier_rifle, soldier_grenade, soldier_bayonet | OK |
| thief | thief_coin_pouch, thief_shadow_cloak, thief_smoke_bomb | OK |
| elementalist | elementalist_orb_ring, elementalist_prism_focus, elementalist_meteor_core | OK |
| sniper | sniper_deadeye_rifle, sniper_spotter_scope, sniper_shatter_rounds | OK |
| priest | priest_reliquary, priest_censer, priest_chime | OK |
| biologist | biologist_spore_lens, biologist_sample_injector, biologist_symbiote_seed | OK |
| robot | robot_magnetic_anchor, robot_hydraulic_press, robot_reactor_core | OK |
| engineer | engineer_sentry_wrench, engineer_repair_drone, engineer_pressure_mines | OK |
| dark_mage | dark_book, cursed_skull, dark_wand | OK |
| guitarist | electric_guitar, bass_guitar, sound_amp | OK |
| assassin | chakrams, shadow_daggers, venom_wire | OK |
| ranger | moon_crossbow, storm_longbow, hunter_trap | OK |
| doctor | restore_potion, plague_syringe, bone_saw | OK |
| chemist | blast_powder, acid_flask, homunculus_vial | OK |
| knight | long_spear, tower_shield, holy_flail | OK |
| druid | summon_amulet, briar_staff, raven_totem | OK |

Verification:
- `res://tests/weapon_integrity_test.gd` PASS (17 classes, 51 weapons).
- `res://tests/progression_data_api_surface_test.gd` PASS.
- `res://tests/weapon_identity_diversity_test.gd` PASS.
- `res://tests/runtime_smoke_weapon_mechanics_test.gd` PASS.
- `res://tests/global_damage_balance_smoke_test.gd` PASS.
- `res://tests/runtime_smoke_test.gd` PASS.

Docs updated:
- `CHANGELOG.md`
- `docs/design/content_registry.md`
- `docs/design/current_game_state.md`
- `docs/design/systems/combat.md`

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 352f8189 (ветка dev)

Проверено (фактически, целевые тесты содержательны):
- **Корень бага** устранён: `PriestChime.tscn` WeaponVisual указывал на
  guitarist `sound_amp.png` (stale proxy-баг в 18 сценах Thief/Elementalist/
  Sniper/Priest/Biologist) — исправлено на корректные per-weapon текстуры. Это
  НЕ коллизия с пассивкой `summoners_bell`, как казалось.
- **Целевые тесты — все зелёные**:
  - `weapon_integrity_test` — **17 classes, 51 weapons** (data+scene+attack_mode+
    выдача, исключение пассивок);
  - `weapon_scene_integrity_test` — 51, все scene_path резолвятся, id уникальны;
  - `weapon_identity_diversity_test` — 51 уникальных сигнатур, дублей нет;
  - `progression_data_api_surface` + `runtime_smoke_weapon_mechanics` +
    `runtime_smoke_combat` — passed.

Acceptance:
- [x] Корень бага Священника найден/устранён (stale WeaponVisual, не Колокол-пассивка).
- [x] 17 классов × 3 корректных оружия (data+scene+mode+выдача), без чужих/пассивок.
- [x] Тест целостности оружия зелёный (+ identity/scene); отчёт; CHANGELOG.

Примечание: umbrella `runtime_smoke` сейчас транзиентно red, но ТОЛЬКО на ассерте
SCRUM-273 (main-menu Red&Gold button textures, кит мигрируется) — это отдельная
активная задача, НЕ дефект SCRUM-277. Weapon-integrity деливерабл полностью зелёный.

Баги: нет.
