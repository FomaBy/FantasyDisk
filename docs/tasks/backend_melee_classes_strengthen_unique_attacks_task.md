# Усиление милишников + уникальные атаки ближнего боя

Статус: done
Приоритет: high
Роль: Back-end (баланс/бой)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-251
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## Dependency Update (2026-06-13)

SCRUM-256 завершён: `ProgressionData.CLASS_MECHANIC_IDENTITIES` фиксирует
главный атрибут и weapon identity для каждого класса. Эта задача больше не
заблокирована framework-зависимостью и может брать таблицу как источник
направления для melee-реализаций.


## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Усиление милишников, создание уникальных атак». Милишники должны быть сильными
и иметь уникальные ближние атаки (в стиле основной характеристики класса).

## Требования
1. Усилить классы ближнего боя (Берсерк/Солдат/Рыцарь/Робот/др. melee) до
   конкурентного уровня — компенсация за риск ближней дистанции (выживаемость/
   урон), без выхода за DPS-коридор глобального smoke.
2. Уникальные ближние атаки на класс/оружие: разные конусы/дуги/напоры/контратаки/
   станы — не повторяющие друг друга; в стиле основного атрибута.
3. Согласовать с убранным авто-перемещением (отдельная задача) — напор/charge
   только если это явная управляемая механика, не авто-рывок по криту.
4. Через balance_harness; отчёт.
5. CHANGELOG; mechanics_extract; docs.

## Files / Assets / IDs
- scripts/class_weapon.gd, scripts/player.gd, scripts/progression_data.gd,
  tools/balance_harness.gd, tests/

## Acceptance Criteria
- [x] Милишники усилены до конкурентного DPS/выживаемости (в коридоре).
- [x] Уникальные ближние атаки на класс/оружие; нет дублей.
- [x] Отчёт harness; 6 smoke + balance smoke зелёные; доки.

## Result Summary (2026-06-14)

Back-end melee mechanics pass complete. Added shared data-driven melee identity
hooks to `ClassWeapon` and `BerserkWeapon`:
- close-risk damage bonus;
- wounded-target execute;
- stagger knockback;
- cleave/follow-up splash;
- small on-hit sustain for explicit sustain melee.

Configured distinct identities for Berserk sword/axe/hammer, Soldier bayonet,
Assassin shadow daggers, Doctor bone saw, Knight long spear/tower shield/holy
flail, and Robot magnetic anchor/hydraulic press. Effects do not move the player
body automatically; they only affect enemies or small self-sustain. DoT ticks are
guarded with `_damage_enemy(..., false)` so melee identity effects fire on direct
weapon hits only.

Balance model updated through `ProgressionData._budget_melee_unique_bonus()` so
`ProgressionData.weapon()` tuning accounts for close/execute/follow-up damage.

Docs/reports updated:
- `CHANGELOG.md`;
- `docs/design/current_game_state.md`;
- `docs/design/mechanics_extract.md`;
- `build/melee_unique_attacks_scrum251_report.md`;
- regenerated `build/balance_report.md`.

Verification:
- `tests/melee_unique_mechanics_test.gd` passed.
- `tools/balance_harness.gd` passed.
- `tests/global_damage_balance_smoke_test.gd` passed.
- `tests/global_survivability_balance_smoke_test.gd` passed.
- `tests/runtime_smoke_weapon_mechanics_test.gd` passed.
- `tests/melee_weapon_targeting_test.gd` passed.
- `tests/progression_data_api_surface_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed.
