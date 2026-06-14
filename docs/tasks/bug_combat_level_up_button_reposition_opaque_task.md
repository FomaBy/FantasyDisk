# BUG/UX: Кнопка повышения уровня в бою — в правый-нижний угол, непрозрачная, без hover

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя)
Jira: SCRUM-278
QA: PASSED (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (отчёт пользователя)
«В игре кнопка повышения уровня внизу — давай сдвинем её направо вниз, и сделаем
непрозрачной — без hover-эффекта».

Это in-run кнопка «Повышение уровня (N)» внизу боевого экрана
(ui_screens.gd:779-781, `_update_level_up_button`; FAB-кнопка докачки за золото).

## Требования
1. Переместить кнопку повышения уровня в **правый нижний угол** HUD (anchor
   bottom-right с безопасным отступом от края; не перекрывать другие HUD-элементы:
   полоску опыта, миникарту/таймер, FAB докачки — развести по углам).
2. Сделать кнопку **полностью непрозрачной** (modulate.a = 1.0; убрать любую
   полупрозрачность фона/стиля для этой кнопки).
3. **Убрать hover-эффект** для этой кнопки (нет подсветки/изменения стиля при
   наведении и при focus; pressed-состояние можно оставить минимальным).
4. Бейдж счётчика (N) сохранить читаемым на непрозрачном фоне.
5. Не ломать клик/назначение действия и обновление видимости
   (`_update_level_up_button` показывает кнопку только при наличии незабранных пиков).
6. Тест (smoke): кнопка присутствует в правом-нижнем якоре, modulate.a==1.0,
   hover не меняет stylebox; no-overlap с другими HUD-узлами. Скрин в build/qa/.

## Files / Assets / IDs
- scripts/ui_screens.gd (_update_level_up_button ~779-790; стиль кнопки повышения)
- scripts/main.gd (level_up_button ~321)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Кнопка в правом-нижнем углу, не перекрывает HUD.
- [x] Непрозрачная (alpha=1), без hover-эффекта.
- [x] Клик/видимость работают; smoke зелёный; dump; CHANGELOG.

## Документация
docs/design/current_game_state.md (боевой HUD).

## Result
2026-06-14 — Back-end done.

- `LevelUpPlusButton` перенесена на bottom-right anchors с безопасным отступом.
- Для боевой кнопки добавлен отдельный статичный opaque `StyleBoxFlat`: normal/hover/focus/pressed/disabled используют один и тот же stylebox, `modulate.a = 1.0`.
- Pending badge сохранен и остается читаемым.
- `tests/runtime_smoke_test.gd` расширен проверкой якорей, фактического bottom-right rect, alpha, отсутствия hover/focus restyle и no-overlap с HUD controls.
- QA dump: `build/qa/combat_level_up_button.md`.
- Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`.

Verification:
- PASS — `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- Note — extra `runtime_smoke_ui_test.gd` / `ui_no_overlap_matrix_test.gd` are currently blocked by a separate hero-select layout regression (`HeroSelectDossier` overlaps `HeroSelectRadarPanel` at 1280x720), not by SCRUM-278. This should be handled by the active hero-select UI bug lane.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 352f8189 (ветка dev)

Проверено (фактически, smoke-ассерты содержательны):
- **Дамп** `build/qa/combat_level_up_button.md`: `LevelUpPlusButton` rect
  `(1188,1470) 384×104` в правом-нижнем углу (viewport 1600), **Alpha=1.000**,
  **HoverSameAsNormal=true**, бейдж `LevelUpPlusBadgePanel` 28×28.
- **Ассерты** (runtime_smoke:733-745): anchor=1 (право-низ); `modulate.a≈1.0`;
  normal==hover==focus stylebox (нет hover-эффекта); bg `StyleBoxFlat.a≥0.999`
  (фон непрозрачный); кнопка НЕ перекрывает HUD; бейдж присутствует.
- **Прогон**: `runtime_smoke` + `runtime_smoke_ui` + `ui_no_overlap_matrix` —
  все passed.

Acceptance:
- [x] Кнопка в правом-нижнем углу, не перекрывает HUD.
- [x] Непрозрачная (alpha=1, фон opaque), без hover-эффекта (hover==normal==focus).
- [x] Бейдж читаем; smoke зелёные; дамп в build/qa/.

Примечание: caveat из Result («ui/no-overlap заблокированы hero-select
регрессией») СНЯТ — это была churn SCRUM-281 (теперь QA passed); оба теста зелёные.

Баги: нет.
