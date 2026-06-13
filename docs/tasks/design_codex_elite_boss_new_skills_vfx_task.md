# Арт/VFX новых скилов элиток и боссов (ауры/лужи/яд/телепорт/щит) — патч 0.1.5

Статус: new
Приоритет: normal
Роль: Design (Codex генерация) → Claude-Designer
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-261
Эпик-патч: 0.1.5 Бой и баланс (SCRUM-232)

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

## Контекст (запрос пользователя)
Новым уникальным скилам элиток/боссов (ауры, лужи урона, яд, телепортация,
блок/щит, призыв и придуманные) нужен читаемый D&D VFX и телеграфы.

## Требования
1. По каталогу механик (backend_elites_bosses_unique_skills_mechanics_task):
   нарисовать/обновить VFX-кадры и телеграфы — аура-кольца, лужи (огонь/кислота/
   яд), маркеры телепорта (вход/выход), щит/блок-эффект, призывной портал,
   зоны замедления/гравитации и т.д. D&D-канон, читаемо, без неона; telegraph
   чётко отличим от детонации.
2. Генерация — Codex с референсами; Claude-Designer ревью/нарезка/интеграция в
   HazardVfx/эффект-пулы.
3. content_registry; превью; smoke (hazard_vfx/attack_vfx/runtime).
4. CHANGELOG.

## Files / Assets / IDs
- assets/sprites/effects/, scripts/hazard_vfx.gd (интеграция), docs/design/previews/
- content_registry.md

## Acceptance Criteria
- [ ] VFX/телеграфы новых скилов в каноне, читаемы; превью.
- [ ] Интегрированы в HazardVfx/пулы; content_registry/CHANGELOG; smoke зелёные.
