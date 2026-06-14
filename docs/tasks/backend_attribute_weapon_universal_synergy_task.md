# Все атрибуты логично сочетаются с любым оружием

Статус: done
Приоритет: high
Роль: Back-end (баланс/механики)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-243
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
«Все атрибуты должны логично сочетаться с любыми оружиями».

Сейчас есть CLASS_INTERPRETATIONS/derived_parameters, но не каждый атрибут даёт
осмысленный эффект на каждом оружии. Нужно: любой атрибут — полезен и понятен
на любом оружии (через универсальные хуки).

## Требования
1. Карта «атрибут × тип оружия → эффект»: для каждого базового атрибута
   определить осмысленный эффект на каждом архетипе оружия (melee cone, projectile,
   beam, aoe, summon, aura). Без «мёртвых» сочетаний.
2. Реализовать недостающие хуки в derived_parameters/класс-механиках так, чтобы
   прокачка любого атрибута давала видимый вклад на любом оружии (масштаб —
   сбалансированный, не ломающий DPS-бюджет).
3. Согласовать с ATTRIBUTE_PRIORITIES (приоритеты класса) и взвешенным level-up:
   приоритетные сильнее, но непрофильные тоже работают.
4. Все правки через balance_harness; проверка, что универсальные эффекты не
   уводят DPS/выживаемость за коридоры.
5. Тест: для выборки атрибут×оружие прокачка атрибута меняет фактический
   эффект (урон/радиус/частота/бафф).
6. CHANGELOG; mechanics_extract (карта синергий); docs.

## Files / Assets / IDs
- scripts/progression_data.gd (derived_parameters, CLASS_INTERPRETATIONS, ATTRIBUTE_PRIORITIES)
- scripts/player.gd, scripts/class_weapon.gd, tools/balance_harness.gd, tests/

## Acceptance Criteria
- [x] Каждый атрибут даёт осмысленный эффект на каждом архетипе оружия (карта в доке).
- [x] Нет мёртвых сочетаний; DPS/выживаемость в коридорах.
- [x] Тест эффекта атрибут×оружие; 6 smoke + balance smoke зелёные; доки.

## Result Summary (2026-06-14)

Back-end balance/system pass complete. Added a canonical data-driven synergy
matrix:
- `ProgressionData.ATTRIBUTE_WEAPON_SYNERGY_MAP`;
- `ProgressionData.weapon_archetype(weapon_config)`;
- `ProgressionData.attribute_weapon_synergy_description(stat_id, weapon_config)`.

`derived_parameters` now has soft universal cross-scaling for:
damage/magic/sound, attack speed, range/AoE, projectile speed, DoT,
aura/buff, summon amount and ultimate multiplier. This makes every base
attribute change at least one effective parameter for representative
melee/projectile/beam/aoe/summon/aura weapons while keeping baseline DPS
controlled by `budget_damage_multiplier`.

Runtime hardening included in-scope:
- `Player._vfx_parent()` now always returns a `Node2D` fallback for slash VFX,
  avoiding root `Window` type errors when current_scene is absent in headless
  smoke contexts;
- the contact-damage smoke enemy is made high-HP so the test cannot be killed by
  automatic weapon effects before contact assertions.

Docs/reports updated:
- `docs/design/mechanics_extract.md` — 8×6 synergy table and formula notes;
- `docs/design/current_game_state.md`;
- `CHANGELOG.md`;
- `build/attribute_weapon_synergy_scrum243_report.md`;
- `build/balance_report.md`.

Verification:
- `tests/stat_formulas_smoke_test.gd` passed.
- `tests/progression_data_api_surface_test.gd` passed.
- `tests/runtime_smoke_progression_economy_test.gd` passed.
- `tools/balance_harness.gd` passed.
- `tests/global_damage_balance_smoke_test.gd` passed.
- `tests/global_survivability_balance_smoke_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Проверено (фактически):
- **API/карта**: `ATTRIBUTE_WEAPON_SYNERGY_MAP` (progression_data_balance.gd:96,
  фасад-const progression_data.gd:46), `weapon_archetype()` (167),
  `attribute_weapon_synergy_map()` (174), `attribute_weapon_synergy_description()`
  (178). Карта 8×6 задокументирована в `mechanics_extract.md`.
- **Целевой тест** `stat_formulas_smoke_test` (детерминированный, не combat-флака):
  passed (35 определений, 8 базовых + 27 производных).
- **Баланс в коридоре** (нет «мёртвых» сочетаний, ломающих коридор):
  `global_damage_balance` (51 пара, combined ±25%/solo ±20%/CCT ±30%) +
  `global_survivability` — зелёные; api_surface + runtime — зелёные.

Acceptance:
- [x] Каждый атрибут даёт эффект на каждом архетипе оружия (карта 8×6 в доке).
- [x] Нет мёртвых сочетаний; DPS/выживаемость в коридорах.
- [x] Тест эффекта; smoke + balance smoke зелёные; доки.

Баги: нет.