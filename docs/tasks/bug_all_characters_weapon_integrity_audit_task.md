# BUG: Аудит оружия ВСЕХ персонажей — у Священника усилок вместо «Колокола»

Статус: in_progress
Приоритет: high
Роль: Back-end (геймплей)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя)
Jira: SCRUM-277

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
