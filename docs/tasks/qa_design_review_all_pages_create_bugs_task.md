# QA/DESIGN: Финальное дизайн-ревью ВСЕХ страниц — завести баги по находкам

Статус: done
Приоритет: high
Роль: QA (Claude) / Designer
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-458
QA: in_progress (2026-06-17)

## Designer 2 Takeover
2026-06-17 — Designer 2 берёт финальный QA/Design pass после завершения
SCRUM-462/SCRUM-463 Back-end UI-интеграций. Скоуп: обзор экранов, скриншоты,
no-overlap/frame-rule аудит и заведение bug-задач по находкам; runtime/UI
исправления не выполняются в этом проходе.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Финальное ревью дизайна всех страниц; создать таски, если что-то не так:
наслоение элементов, дизайн интерфейса, маленькие или очень большие рамки,
незавершённые/оборванные линии фреймов».

## Требования
1. Пройти ВСЕ экраны (_show_* в ui_screens.gd: меню, настройки, выбор героя, кодекс,
   магазин, награды, повышение, события, отдых, апгрейд, пауза, победа, смерть,
   бой-HUD, тултипы, диалоги) на 1280×720 / 1920×1080 / 2560×1440.
2. Зафиксировать ПРОБЛЕМЫ: наслоение/перекрытие элементов; рамки слишком
   маленькие/большие относительно контента; незавершённые/оборванные/рваные линии
   фреймов; контент на орнаменте; обрезанный/невлезающий текст; кривое выравнивание.
3. Для КАЖДОЙ находки — завести отдельную bug-задачу в docs/tasks/ + Jira (с экраном,
   разрешением, скрином), приоритет по тяжести. Свести в чек-лист в этой задаче.
4. Скрины каждого экрана (3 разрешения) в build/qa/design_review/.
5. CHANGELOG (по факту ревью); current_game_state не менять.

## Files / Assets / IDs
- scripts/ui_screens.gd (все _show_*), tests/ui_no_overlap_matrix_test.gd
- docs/tasks/ (новые bug-задачи по находкам)

## Acceptance Criteria
- [x] Все экраны просмотрены на 3 разрешениях; скрины в build/qa/design_review/.
- [x] По каждой проблеме (наслоение/размер рамок/оборванные линии/overflow) заведена bug-задача + Jira; чек-лист сведён.
- [x] Краткий итог-вывод; CHANGELOG.

## Документация
docs/process/qa_protocol.md, docs/design/systems/menus_ui.md.

## Result (Designer 2 / 2026-06-17)

Final design review pass complete after SCRUM-462/SCRUM-463 UI rollout.

Reviewed 23 UI states at 1280x720, 1920x1080 and 2560x1440:
main menu, quit dialog, Settings tabs, Hero Select, Weapon Select, Codex,
Codex tooltip, battle reward, Level Up, elite reward, shop, Attribute Shop,
Rest, Upgrade, Event, pause menu, pause stats, victory, death, combat HUD and
feedback dialog.

Evidence:
- screenshot manifest: `build/qa/design_review/manifest.md`;
- contact sheets: `build/qa/design_review/contact_1280x720.jpg`,
  `build/qa/design_review/contact_1920x1080.jpg`,
  `build/qa/design_review/contact_2560x1440.jpg`;
- capture harness: `tests/design_review_screenshot_capture_test.gd`.

Defects created:
- SCRUM-464 / `docs/tasks/bug_economy_screens_opaque_matte_washes_content_task.md`
  — Rest/Event economy panels retain a large opaque pale smoky matte over settled
  content.
- SCRUM-465 / `docs/tasks/bug_levelup_screen_overflows_bottom_at_720p_task.md`
  — Level Up reward cards/return button overflow below the viewport at 1280x720
  and partly at 1920x1080.
- SCRUM-466 / `docs/tasks/bug_minimal_metal_frames_internal_lines_cross_content_task.md`
  — minimal-metal panel/card seams draw long internal gold lines through reward,
  upgrade, feedback and economy screen content.

Checks:
- PASS: `tests/ui_no_overlap_matrix_test.gd`.
- PASS: `tests/runtime_smoke_ui_test.gd`.
- PASS: `tests/runtime_smoke_test.gd`.

Notes:
- The screenshot harness uses a windowed Godot run rather than `--headless`
  because the dummy headless viewport does not provide screenshot pixels.
- The harness waits 45 frames after screen open so animated intros settle before
  review captures. No runtime UI fixes were made in this QA pass.

## QA-Вердикт (2026-06-17)
Статус: PASSED — дизайн-ревью всех страниц проведён, баги заведены
Проверено: ревью 23 UI-состояний × 3 разрешения (1280×720/1920×1080/2560×1440), контакт-листы
+ манифест + capture-harness `tests/design_review_screenshot_capture_test.gd`. Заведены валидные
баги SCRUM-464 (economy matte) / 465 (levelup overflow) / 466 (metal seams) — все три по итогу
QA PASSED.
⚠️ QA-дополнение: ревью шло на 1280+; на наименьшем 1152×648 QA нашёл ещё 2 overflow
(settings + attribute_shop), не покрытые этим ревью — заведены `bug_settings_attribute_shop_overflow_overlap_1152x648_task.md`.
done → Готово.
