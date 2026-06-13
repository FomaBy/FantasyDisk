# Арт/VFX уникального оружия и атак всех классов (патч 0.1.5)

Статус: blocked (ждёт механик: SCRUM-256/251/254/245 — арт под готовые атаки)
Приоритет: normal
Роль: Design (Codex генерация) → Claude-Designer
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-258
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## ФИЧА-ФРИЗ 0.1.4
Бэклог `Версия: 0.1.5`. НЕ брать в работу и НЕ dispatch до релиза 0.1.4 и снятия
фриза. Статус new, в активный спринт не попадает (sync уважает версию).

## Parked Draft (2026-06-13)

По superseded dispatcher handoff Design успел сгенерировать черновой VFX-kit до
коррекции фриза. Черновики убраны из live assets и припаркованы для будущей
версии `0.1.5`:

- `docs/design/backlog/vfx_015/effects/`
- `docs/design/backlog/vfx_015/previews/`
- `docs/design/backlog/vfx_015/vfx_unique_weapon_enemy_kit.md`
- `docs/design/backlog/vfx_015/generate_unique_weapon_enemy_vfx.py`

Это не active 0.1.4 content, не runtime wiring и не основание переводить задачу
в `in_progress`.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Переделать оружие» под уникальные механики; новым атакам/аурам/статусам нужен
читаемый VFX.

## Требования
1. По итогам механик-задач: дорисовать/обновить спрайты оружия и VFX-кадры для
   новых уникальных атак, аур, баффов/дебаффов — в D&D-каноне, читаемо (telegraph
   там, где задержка/зона), без неона.
2. Генерация — Codex с референсами; Claude-Designer ревью/интеграция.
3. content_registry; превью; smoke (attack_vfx/hazard_vfx/runtime).
4. CHANGELOG.

## Files / Assets / IDs
- assets/sprites/weapons/, assets/sprites/effects/, docs/design/previews/
- content_registry.md

## Acceptance Criteria
- [ ] Оружие/VFX новых механик в каноне, читаемы; превью.
- [ ] content_registry/CHANGELOG; smoke зелёные.
