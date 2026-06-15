# BUG: HP-бар элитки/босса уезжает за верх экрана (крупные спрайты)

Статус: done
Приоритет: high
Роль: Back-end (бой/HUD)
Версия: 0.1.5
Создано: 2026-06-15
Автор: PM (отчёт пользователя)
Jira: SCRUM-414

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch
- 2026-06-15T06:13Z — Board dispatcher routed to Back-end thread
  `019eabd9-780b-78a2-9f4b-e7203d659ef2` as priority 3 in the Back-end bug
  queue (reasoning High/no low). Active-owner audit: Back-end was idle; Design
  main was actively working SCRUM-412; Designer 2 and Animator had no eligible
  owner work. Back-end owns combat/HUD behavior, tests, docs, and QA evidence.

## Контекст (отчёт пользователя)
«В бою с элиткой или боссом HP элитки/босса слишком высоко и не видно».

HealthBar — дочерний узел сущности (enemy.gd:264 `get_node_or_null("HealthBar")`,
boss.gd:51), позиционируется фикс-офсетом над спрайтом. У элиток/боссов спрайты
теперь КРУПНЫЕ (256-512px после апскейла), поэтому бар над головой уезжает за
верхний край экрана и не виден.

## Требования
1. **HP-бар элитки/босса всегда видим**: либо клампить плавающий бар в пределах
   вьюпорта (если над головой уходит за верх — прижимать к верхней кромке экрана),
   либо для боссов/элиток сделать **фиксированный бар сверху экрана** (как принято
   для боссов) с именем/фазами. Обычные враги — без изменений.
2. Учесть крупные спрайты (512 боссы / 256-384 элитки): офсет бара считать от
   реального верха спрайта/коллайдера, не фикс-константой, ИЛИ перейти на screen-space
   бар для боссов/элиток.
3. Фазовые маркеры босса (boss.gd:53 BOSS_PHASE_MARKERS) сохранить; полоска
   обновляется (enemy.gd:225 _update_health_bar / boss.gd:272).
4. Не ломать HP-бары обычных врагов и их скрытие (enemy.gd:264-266).
5. Тест (smoke): заспавнить элитку и босса — HP-бар в пределах экрана и виден на
   1280×720/1920×1080/2560×1440 (с учётом камеры/зума 2K-арены). Скрин боя в build/qa/.
6. CHANGELOG; systems/combat; current_game_state.

## Files / Assets / IDs
- scripts/enemy.gd (_create_health_bar 111; _update_health_bar 225; HealthBar 264;
  позиция бара/офсет; entity_kind elite)
- scripts/boss.gd (HealthBar 51-53; _update_health_bar 272; BOSS_PHASE_MARKERS)
- scripts/enemy_health_bar.gd (HEALTH_BAR_SCRIPT)
- scripts/main.gd / combat_director.gd (камера/зум арены — для screen-space клампа)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] HP-бар элитки и босса всегда виден в пределах экрана (не уезжает за верх) при крупных спрайтах.
- [x] Фазовые маркеры босса целы; обычные враги не сломаны.
- [x] smoke зелёные; QA smoke coverage; CHANGELOG; combat.

## Документация
docs/design/systems/combat.md, current_game_state.

## Result / Back-end report
- 2026-06-15 — Fixed in `scripts/enemy.gd` / `scripts/boss.gd`.
- Normal enemy HP bars keep the existing world-space overhead placement.
  Elite and boss HP bars still attach to their entity, but after setup/update
  their local position is converted through the current canvas transform and
  clamped into the visible viewport when a large sprite would push the bar
  above the screen edge.
- Boss phase marker metadata remains on the same `HealthBar`; `boss.gd` now
  refreshes the bar after assigning phase markers so initial boss placement is
  also clamped.
- Runtime smoke now moves representative boss/elite entities to the viewport
  top edge and asserts their bar remains on-screen.
- Verification:
  - `enemy_health_bar_smoke_test.gd` — PASS;
  - `runtime_smoke_test.gd` — PASS;
  - `runtime_smoke_ui_test.gd` — PASS;
  - `ui_no_overlap_matrix_test.gd` — PASS.


## QA-Вердикт (2026-06-15)
Статус: PASSED — HP-бары элиток/боссов клэмпятся в вьюпорт

Проверено (фактически):
- **Фикс** (`enemy.gd`/`boss.gd`): HP-бары элиток/боссов после setup/update
  конвертируются через canvas transform и **клэмпятся в видимый вьюпорт**, когда
  крупный спрайт выталкивает бар за верхний край; обычные враги — прежнее
  overhead-размещение. `boss.gd` рефрешит бар после phase-маркеров (начальное
  размещение тоже клэмпится).
- **Тесты**: `enemy_health_bar_smoke_test` PASS (setup/configure-клэмпы/set_value/
  ratio — двигает boss/elite к верхнему краю, бар остаётся на экране);
  `runtime_smoke` + `runtime_smoke_ui` + `ui_no_overlap_matrix` PASS.

Acceptance:
- [x] HP-бары элиток/боссов не уходят за верх экрана (клэмп в вьюпорт).
- [x] Обычные враги не затронуты; health-bar smoke + runtime зелёные.

Статус done. Баги: нет.
