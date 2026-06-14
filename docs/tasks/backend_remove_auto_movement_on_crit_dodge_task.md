# Убрать автоматическое перемещение персонажа при крите/уворота — полный контроль игроком

Статус: done
Приоритет: high
Роль: Back-end (бой)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-253
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## Dispatcher Dispatch (2026-06-14)

Queued to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after current
SCRUM-260 work. Keep reasoning High/no low. SCRUM-253 is independent from enemy
size balance: avoid SCRUM-260 enemy-scale files unless absolutely required; if
animation/VFX/art polish appears, create/update Animator or Design handoff
instead of doing it in Back-end scope.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«У персонажей убрать автоматические перемещения когда крит или уворот — всё
должно контролироваться человеком».

Некоторые классовые механики при крите/уклонении дают авто-рывок/смещение
персонажа (например dash/blink). Пользователь хочет, чтобы позиция управлялась
ТОЛЬКО игроком.

## Требования
1. Найти все авто-перемещения игрока, триггерящиеся по криту/уклонению (dash,
   blink, отскок, charge-on-crit и т.п.) в player.gd / class_weapon.gd / классовых
   механиках.
2. Убрать автоматическое смещение ПЕРСОНАЖА по этим триггерам. Эффект крита/
   уворота сохраняется как боевой (доп. урон/избегание), но БЕЗ телепортации/
   рывка тела игрока. Если механика класса была завязана на рывок — заменить на
   не-перемещающий эффект (вспышка урона, бафф, снаряд) и зафиксировать в отчёте.
3. Перемещение персонажа — только ввод игрока.
4. Тест (smoke): после крита/уворота global_position игрока не меняется скачком
   (только от ввода); классовые механики не двигают тело.
5. CHANGELOG; current_game_state; mechanics_extract (изменённые механики).

## Files / Assets / IDs
- scripts/player.gd, scripts/class_weapon.gd, классовые механики (assassin dash и т.п.)
- tests/

## Acceptance Criteria
- [x] Нет авто-смещения игрока по криту/уклонению; позиция = только ввод.
- [x] Затронутые классовые механики переделаны на не-перемещающие, задокументированы.
- [x] Тест отсутствия скачка позиции; 6 smoke + balance smoke зелёные.

## Result Summary (2026-06-13, Back-end)

- Убран player-body crit dash Ассасина: `dash_on_crit_distance` заменен на совместимый `crit_shadow_burst_radius`, а крит теперь вызывает неподвижный shadow burst/удар у цели через `trigger_assassin_crit_shadow`.
- Совместимость сохранена: старый `trigger_assassin_dash()` оставлен wrapper-методом без движения тела.
- Дополнительно устранён найденный автотелепорт игрока у `thief_shadow_cloak`: `shadow_backstab` стал фантомным ударом за целью без изменения `global_position` Вора.
- Runtime smoke расширен проверкой, что крит Ассасина, уворот и shadow backstab не меняют `global_position` героя без ввода.
- Обновлены `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/mechanics_extract.md` и кодексные описания.

Verification:
- `res://tests/runtime_smoke_weapon_mechanics_test.gd` — passed.
- `res://tests/runtime_smoke_test.gd` — passed.
- `res://tests/progression_data_api_surface_test.gd` — passed.
- `res://tests/global_damage_balance_smoke_test.gd` — passed.
- `res://tests/global_survivability_balance_smoke_test.gd` — passed.
