# Арт/VFX новых скилов элиток и боссов (ауры/лужи/яд/телепорт/щит) — патч 0.1.5

Статус: in_progress
Приоритет: normal
Роль: Design (Codex генерация) → Claude-Designer
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-261
Эпик-патч: 0.1.5 Бой и баланс (SCRUM-232)

## PM Override (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Эта уже существующая board-задача поднята из backlog `0.1.5` в текущий релиз и
отправлена Design владельцу. Новые задачи после этой директивы остаются backlog
`0.1.5`, если PM явно не решит иначе.

## Dispatcher Redispatch (2026-06-13)

Отправлено в существующий Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`
как 0.1.4 board-completion task. Keep reasoning High/no low. Scope Design/VFX
only; mechanics/API integration depends on Back-end `SCRUM-259`, and motion/rig/
animation timing must be handed to Animator.

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
