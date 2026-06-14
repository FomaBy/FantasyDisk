# Усиление призывателей

Статус: done
Приоритет: high
Роль: Back-end (баланс/бой)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-254
QA: in_progress (2026-06-14)
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## Dependency Update (2026-06-13)

SCRUM-256 завершён: `ProgressionData.CLASS_MECHANIC_IDENTITIES` фиксирует
главный атрибут и weapon identity для каждого класса. Эта задача больше не
заблокирована framework-зависимостью и может брать таблицу как источник
направления для summon/leadership-реализаций.


## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Усилить призывателей». Призывные классы (Друид/Инженер/др. summon) должны быть
конкурентны: миньоны полезны, масштабируются, не бесполезны.

## Требования
1. Усилить призывы: урон/живучесть/количество/масштабирование от профильного
   атрибута (Лидерство/призыв) — конкурентно с прямым уроном, без выхода за
   DPS-коридор.
2. Уникальность призывов по классам (звери/гомункулы/турели/тотемы) — разные
   роли (танк/дамаг/контроль/поддержка), в стиле основной характеристики.
3. Согласовать с аур/баффов задачей (часть призывателей даёт баффы).
4. Через balance_harness; отчёт.
5. CHANGELOG; mechanics_extract; docs.

## Files / Assets / IDs
- scripts/summoner_weapon.gd, scripts/ally_minion.gd, scripts/player.gd,
  scripts/progression_data.gd, tools/balance_harness.gd, tests/

## Acceptance Criteria
- [ ] Призыватели конкурентны; призывы масштабируются и полезны (в коридоре).
- [ ] Уникальные роли призывов по классам; balance smoke зелёный; доки.

## Result — 2026-06-13

Статус: done

Implemented SCRUM-254 Back-end summon strengthening:
- Added data-driven summon roles for Druid beasts, Chemist homunculus, Druid raven totem, Engineer sentry and Engineer repair drone.
- `SummonerWeapon` now builds ally combat profiles from owner derived parameters/Leadership: damage, move speed, attack interval, lifetime, max HP, control knockback and support heal.
- `AllyMinion` now supports `set_combat_profile()`, runtime health and `take_damage()` cleanup.
- `ProgressionData.weapon_archetype()` treats `summon_role` as summon archetype, and the balance model evaluates pure summon weapons through minion DPS instead of an invisible direct hit.
- Added `tests/summoner_strengthening_test.gd` and report `build/summoner_strengthening_scrum254_report.md`.

Verification passed:
- `res://tests/summoner_strengthening_test.gd`
- `res://tests/progression_data_api_surface_test.gd`
- `res://tests/runtime_smoke_weapon_mechanics_test.gd`
- `res://tests/global_damage_balance_smoke_test.gd`
- `res://tests/global_survivability_balance_smoke_test.gd`
- `res://tools/balance_harness.gd`
- `res://tests/runtime_smoke_test.gd`

Balance snapshot after tuning: max combined budget deviation 0.1%; summon weapons remain inside global damage/survivability gates.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev; 0.1.5 WIP, консистентно)

Проверено (фактически):
- **Код**: `AllyMinion.set_combat_profile()` (44) + `take_damage()` (57) +
  `summon_role` (22); `SummonerWeapon` строит профиль из Лидерства, передаёт
  `set_combat_profile` (105-106), `summon_role`/`summon_role_damage_multiplier`.
  `ProgressionData` трактует `summon_role` как summon-архетип (balance-модель
  считает summon-оружие через minion DPS, а не невидимый прямой хит).
- **Целевой тест** (`summoner_strengthening_test`, 106 стр.): ассертит
  `summon_role` по парам (напр. druid/summon_amulet=pack_damage),
  `summon_role_damage_multiplier > 0`, и что профиль масштабируется от Лидерства
  + lifecycle миньона. Passed.
- **Балансовая инвариантность**: `global_damage_balance` (51 пара, summon-оружие
  внутри коридора) + `global_survivability` — зелёные; api_surface + weapon_mechanics
  + runtime — зелёные.

Acceptance:
- [x] Призыватели конкурентны; призывы масштабируются (Лидерство) и полезны,
  в DPS-коридоре (worst combined dev 0.1%).
- [x] Уникальные роли призывов по классам (pack_damage/турель/тотем/гомункул/дрон);
  balance smoke зелёный; доки.

Баги: нет.
