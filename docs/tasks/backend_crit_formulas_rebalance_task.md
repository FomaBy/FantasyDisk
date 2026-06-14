# Формулы крита — отбалансить шанс крита, силу крита и связанное

Статус: done
Приоритет: high
Роль: Back-end (баланс)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-247
Эпик-патч: 0.1.5 Бой и баланс (overhaul)


## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Отбалансить криты, силу критов и всё остальное» (в рамках патча формул урона).

## Требования
1. Пересмотреть формулы `crit_chance` и `crit_damage_multiplier` (stat_formulas.gd):
   разумные капы шанса, кривая множителя; крит — значимый, но не доминирует над
   стабильным уроном.
2. Согласовать крит с бюджетом DPS: средний урон с учётом крита у классов в
   коридоре ±коридор глобального balance smoke (по 1-цели и 5-целям).
3. Прочие урон-модификаторы (knockback/range множители и т.п.) — проверить на
   согласованность, если влияют на эффективный урон.
4. Все правки через balance_harness; отчёт «было/стало».
5. CHANGELOG; mechanics_extract; docs баланса.

## Files / Assets / IDs
- scripts/stat_formulas.gd (crit_chance, crit_damage_multiplier)
- scripts/progression_data.gd (derived_parameters), tools/balance_harness.gd, tests/

## Acceptance Criteria
- [x] Крит-формулы сбалансированы, капы разумны; средний урон в коридоре DPS-smoke.
- [x] Отчёт harness; 6 smoke + глобальный damage smoke зелёные; CHANGELOG/доки.

## Result Summary (2026-06-14)

Back-end balance complete. Crit formulas now use shared 0.1.5 constants:
- `crit_chance = effective_crit_chance(0.04 + Agility*0.0075 + flat*0.75)`,
  diminishing returns, cap 55%;
- `crit_damage_multiplier = clamp(1.30 + Agility*0.055 + flat*0.75, 1.0, 2.75)`;
- passive `crit_damage_multiplier` in weapon configs is folded in as a flat
  delta (`1.08` => `+0.08`) so existing passive configs are no longer ignored.

`build/crit_rebalance_scrum247_report.md` records sample before/after numbers:
Agility 20 with +50% crit chance and +80% crit damage goes from ~3.10x average
crit factor to ~1.92x. `tools/balance_harness.gd` regenerated
`build/balance_report.md`; average class+weapon DPS remains inside the global
damage smoke corridor through existing budget tuning.

Verification:
- `tests/stat_formulas_smoke_test.gd` passed.
- `tests/progression_data_api_surface_test.gd` passed.
- `tools/balance_harness.gd` passed.
- `tests/global_damage_balance_smoke_test.gd` passed.
- `tests/global_survivability_balance_smoke_test.gd` passed.
- `tests/runtime_smoke_weapon_mechanics_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed.

Docs updated: `CHANGELOG.md`, `docs/design/mechanics_extract.md`,
`docs/design/current_game_state.md`.
