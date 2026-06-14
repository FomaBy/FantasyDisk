# Система аур, баффов и дебаффов — дать персонажам ауры/бафы/дебафы

Статус: done
Приоритет: high
Роль: Back-end (механики)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-245
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## Dependency Update (2026-06-13)

SCRUM-256 завершён: `ProgressionData.CLASS_MECHANIC_IDENTITIES` фиксирует
главный атрибут, mechanic tags и weapon identity для каждого класса. Эта задача
больше не заблокирована framework-зависимостью и может назначать ауры/баффы/
дебаффы по class identity table.


## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Дать каким-то персонажам ауры, бафы, дебафы и т.д.».

## Требования
1. Реализовать переиспользуемую систему статус-эффектов: ауры (постоянная зона
   вокруг игрока/миньона), баффы (себе/союзникам), дебаффы (врагам) — с
   длительностью, стаком (по правилам), визуальным маркером.
2. Назначить ауры/баффы/дебаффы тематически подходящим классам в стиле их
   основной характеристики (например лидер — командная аура баффа; маг — дебафф
   уязвимости; лекарь — аура регена союзникам/миньонам; химик — дебафф яда).
3. Согласовать с балансом: эффекты в DPS/выживаемость-коридорах; ауры не
   стакаются в бессмертие (учесть нерф выживаемости).
4. VFX-маркеры аур/статусов — handoff Design (Codex) при необходимости.
5. Тест: применение/снятие/длительность статуса (фактическое состояние),
   аура影响 в радиусе.
6. CHANGELOG; mechanics_extract; docs.

## Files / Assets / IDs
- scripts/player.gd, scripts/class_weapon.gd, scripts/enemy.gd (приём дебаффов),
  scripts/progression_data.gd, новый status/aura модуль, tools/balance_harness.gd, tests/
- Handoff Design: VFX аур/статусов

## Acceptance Criteria
- [ ] Система статус-эффектов (ауры/баффы/дебаффы) с длительностью/стаком/маркером.
- [ ] Назначены подходящим классам в стиле основного атрибута; в балансе.
- [ ] Тесты статусов; 6 smoke + balance smoke зелёные; доки; VFX-handoff если нужно.

## Result — 2026-06-13

Статус: done

Implemented SCRUM-245 Back-end status/aura layer:
- Added reusable `scripts/status_effects.gd` with duration, stack policy, DoT ticks, slow, damage buff, vulnerability and marker metadata.
- Wired `Enemy` to tick status effects, apply slow to movement and vulnerability to incoming damage.
- Wired `AllyMinion` to tick status effects and consume command aura damage/speed buffs.
- Wired `Player` class hooks: Dark Mage/Elementalist arcane vulnerability, Chemist/Doctor/Assassin/Biologist toxic DoT, Soldier/Knight/Robot stagger slow, and Guitarist/Druid/Engineer/Priest class auras.
- Existing `AttackVfx.ring_pulse()` is enough for aura feedback; no Design/Animator handoff required.
- Added focused smoke `tests/status_effects_aura_test.gd` and report `build/status_effects_auras_scrum245_report.md`.

Verification passed:
- `res://tests/status_effects_aura_test.gd`
- `res://tests/runtime_smoke_combat_test.gd`
- `res://tests/runtime_smoke_weapon_mechanics_test.gd`
- `res://tests/global_damage_balance_smoke_test.gd`
- `res://tests/global_survivability_balance_smoke_test.gd`
- `res://tools/balance_harness.gd`
- `res://tests/runtime_smoke_test.gd`
