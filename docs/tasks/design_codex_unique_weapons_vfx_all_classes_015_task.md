# Арт/VFX уникального оружия и атак всех классов (патч 0.1.5)

Статус: in_progress
Приоритет: normal
Роль: Design (Codex генерация) → Claude-Designer
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-258
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## PM Override (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Эта уже существующая board-задача поднята из backlog `0.1.5` в текущий релиз и
отправлена Design владельцу. Новые задачи после этой директивы остаются backlog
`0.1.5`, если PM явно не решит иначе.

## Dispatcher Redispatch (2026-06-13)

Отправлено в существующий Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`
как 0.1.4 board-completion task. Keep reasoning High/no low. Scope Design/VFX
only; motion/rig/timing/animation states — Animator handoff, code integration —
Back-end handoff.

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
