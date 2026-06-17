# Backend: Полное код-ревью + починить все возможные проблемы бэкенда

Статус: done
Приоритет: high
Роль: Back-end (ревью/качество)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-454
QA: in_progress (2026-06-17)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Полное ревью кода и поправить все возможные проблемы с бэкендом».

## Требования
1. Пройти бэкенд-код (scripts/*.gd): найти и починить РЕАЛЬНЫЕ проблемы — рантайм-
   ошибки/ворнинги, битые res:// ссылки, мёртвый код, дубли, утечки (не освобождённые
   ноды/таймеры/сигналы), небезопасные касты/типы, потенциальные краши/зависания
   (напр. незакрытые паузы, циклы), регрессы после недавних правок (анимации/
   видимость/scale/оружие).
2. Особое внимание: события/костёр (отчёт пользователя — «не дают выбрать опцию/
   зависает»), пауза-стек, клики/overlay (mouse_filter), флот-гонки в .md/коммитах.
3. Прогнать ВСЕ smoke-сьюты + проект на 0 SCRIPT/Parse ERROR при загрузке; убрать
   ворнинги где возможно.
4. По крупным находкам, не влезающим в один проход — завести отдельные bug-задачи.
5. Итог: список найденного/починенного; все тесты зелёные; CHANGELOG.

## Files / Assets / IDs
- scripts/*.gd (весь бэкенд), tests/*.gd (все сьюты)
- docs/tasks/ (bug-задачи по крупным находкам)

## Acceptance Criteria
- [x] Бэкенд-ревью проведено; реальные проблемы (ошибки/ворнинги/утечки/битые ссылки/краши) починены или заведены отдельными багами.
- [x] События/костёр-баг разобран; пауза/клики/overlay проверены.
- [x] 0 SCRIPT/Parse ERROR при загрузке; все smoke зелёные; итог-список; CHANGELOG.

## Документация
docs/design/systems/technical_architecture.md, current_game_state.

## Результат
- Back-end done 2026-06-17: review pass focused on project-load/runtime parse
  health, route event/campfire choice interactions, pause overlay preservation,
  click/mouse-filter paths, broken `res://` references, balance/data gates and
  smoke slices.
- Fixed a real paid-event option bug: event choices with `cost_money` now show
  scaled gold cost, disable when the run cannot afford them, expose an
  insufficient-gold tooltip, and direct `_apply_event_choice()` activation now
  fails safely instead of ignoring `Player.spend_money() == false`.
- Added regression coverage in `tests/runtime_smoke_test.gd` for an unaffordable
  `goblin_lottery` paid event choice. Existing event route click/pause
  preservation and campfire background/rest checks remain green.
- No separate bug handoff was needed in this pass; no Design/Animator assets or
  gameplay balance values were changed.
- Checks PASS: `runtime_smoke_test.gd`, `runtime_smoke_ui_test.gd`,
  `ui_no_overlap_matrix_test.gd`, `event_data_smoke_test.gd`,
  `animation_smoke_test.gd`, `runtime_smoke_combat_test.gd`,
  `runtime_smoke_progression_economy_test.gd`,
  `runtime_smoke_weapon_mechanics_test.gd`, `attack_vfx_smoke_test.gd`,
  `audio_manager_smoke_test.gd`, `game_settings_smoke_test.gd`,
  `projectile_smoke_test.gd`, `enemy_projectile_smoke_test.gd`,
  `asset_reference_integrity_test.gd`, `content_registry_consistency_test.gd`,
  `global_damage_balance_smoke_test.gd`, `global_survivability_balance_smoke_test.gd`,
  `class_damage_table_3variants_test.gd`.

## QA-Вердикт (2026-06-17)
Статус: PASSED — бэкенд-ревью; реальный paid-event баг починен, smoke зелёные

Проверено (фактически): `event_data_smoke_test` PASS (12 событий); runtime_smoke зелёный
(включает регрессию на неоплачиваемый `goblin_lottery` paid-choice — теперь cost_money
показывает цену, дизейблится при нехватке золота, `_apply_event_choice` фейлит безопасно
при `spend_money()==false`). 0 SCRIPT/Parse ERROR при загрузке. Acceptance [x] все. done → Готово.
