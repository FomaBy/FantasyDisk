# Опции прицеливания — 2 режима: автонаводка на ближайшего и наведение по курсору

Статус: done
Приоритет: high
Роль: Back-end (бой/опции)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-241
QA: in_progress (2026-06-14)
Эпик-патч: 0.1.5 Бой и баланс (overhaul)


## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«В опциях добавить управление направлением удара через мышку: все атаки в сторону
курсора или на курсор. 2 режима: (1) автонаводка на ближайшего монстра,
(2) наведение по курсору».

Сейчас прицеливание — на ближайшего врага (backend_attack_aim_nearest_enemy_fix,
player.gd/class_weapon.gd). Нужен переключаемый режим.

## Требования
1. Опция в настройках (вкладка «Управление»): «Прицеливание» = {Автонаводка на
   ближайшего | По курсору}. Сохранять в user://settings.cfg, применять живьём.
2. Режим «По курсору»: ВСЕ атаки персонажа (ближний конус/дуги, снаряды, лучи,
   зоны) направляются в сторону курсора / на позицию курсора. Единый источник
   направления атаки (aim_direction) для всех weapon-режимов.
3. Режим «Автонаводка»: текущее поведение (ближайший враг).
4. Корректно для всех типов оружия (melee cone, projectile, beam, aoe-on-point,
   boomerang, charge и т.д.) — направление берётся из единой точки.
5. Тест (smoke): переключение режима меняет фактический вектор атаки (по курсору
   vs к ближайшему) для 2-3 типов оружия; персист настройки.
6. CHANGELOG; current_game_state; docs управления.

## Files / Assets / IDs
- scripts/player.gd (направление атаки), scripts/class_weapon.gd, melee/summoner weapons
- scripts/game_settings.gd, scripts/ui_screens.gd (вкладка Управление)
- tests/

## Acceptance Criteria
- [x] Опция 2 режимов, персист, живое применение.
- [x] По курсору работает для всех типов оружия; автонаводка сохранена.
- [x] Тест вектора атаки; 6 smoke + глобальный balance smoke зелёные.

## Result 2026-06-13

SCRUM-241 done. Во вкладку «Управление» добавлен persisted переключатель
`Прицеливание`: `Автонаводка на ближайшего` / `По курсору`. `scripts/player.gd`
теперь дает единый Back-end API `attack_aim_mode`, `attack_aim_direction` и
`attack_aim_position`; `ClassWeapon`, `BerserkWeapon` и `SummonerWeapon`
используют его без изменения баланса. `nearest` сохраняет старую автонаводку,
`cursor` направляет melee/лучи/снаряды/deploy/point-AoE на курсор.

Документация обновлена: `CHANGELOG.md`,
`docs/design/current_game_state.md`, `docs/design/systems/combat.md`. Отчет:
`build/aim_modes_scrum241_report.md`.

Проверки:
- `tests/aim_mode_settings_test.gd` — passed.
- `tests/game_settings_smoke_test.gd` — passed.
- `tests/melee_weapon_targeting_test.gd` — passed.
- `tests/runtime_smoke_weapon_mechanics_test.gd` — passed.
- `tests/runtime_smoke_ui_test.gd` — passed.
- `tests/global_damage_balance_smoke_test.gd` — passed.
- `tests/global_survivability_balance_smoke_test.gd` — passed.
- `tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2f78c734 (ветка dev; 0.1.5 WIP, консистентно)

Проверено (фактически):
- **Единый API** в `player.gd`: `attack_aim_mode()` (327), `attack_aim_position()`
  (333), `attack_aim_direction()` (343) — при `cursor` направление берётся от
  оффсета курсора (344-345). ClassWeapon/Berserk/Summoner используют его.
- **UI-тоггл** (вкладка «Управление», ui_screens.gd:1467-1475): OptionButton
  «Прицеливание» = {Автонаводка на ближайшего | По курсору}, отражает
  `game.aim_mode`, меняет живьём по выбору.
- **Персист + валидация** (game_settings.gd): дефолт `nearest` (20), клэмп в
  {`nearest`,`cursor`} (44-46); round-trip покрыт `game_settings_smoke` (passed).
- **Целевой тест** `aim_mode_settings_test` (133 стр.): mock-player с
  aim_mode/cursor_direction, оружие читает aim-API; passed.
- **Балансовая инвариантность**: `global_damage_balance_smoke` — passed (51 пара
  в коридоре, без изменений) → новый режим не трогает баланс.
- **Регрессия**: melee_targeting / weapon_mechanics / runtime — зелёные.

Acceptance:
- [x] Опция 2 режимов, персист (settings.cfg), живое применение.
- [x] «По курсору» через единый API для melee/снарядов/лучей/deploy/point-AoE;
  автонаводка `nearest` сохранена.
- [x] Тест вектора атаки; smoke + глобальный balance smoke зелёные.

Баги: нет.
