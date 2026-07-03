# UI: Кодекс — интеграция object-first layout с крупными изображениями

Статус: new
Приоритет: P1
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Jira: SCRUM-850
Создано: 2026-07-03
Автор: Codex PM по прямому запросу пользователя
Depends on: SCRUM-849 / `design_codex_object_first_redesign_task.md`
Locked paths: `scripts/ui_screens.gd`, `scripts/ui/ui_theme_paths.gd` если нужны новые frame paths, `tests/runtime_smoke_ui_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, `tests/codex_data_smoke_test.gd`, `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`, `build/qa/codex_object_first/`

## Контекст

После Design-задачи SCRUM-849 нужно перенести новый object-first Codex layout в
Godot runtime без изменения данных Кодекса и без регрессий навигации. Текущий
экран строится в `scripts/ui_screens.gd` и уже имеет категории, lazy-build
секций, detail panel, glossary tooltips и gamepad shoulder navigation. Это нужно
сохранить, но визуальную иерархию перестроить под крупные изображения и
минимальные логические панели.

## Что Нужно Сделать

1. Начинать только после готового design package из SCRUM-849: mockup/spec,
   assets, margins и handoff должны быть `ready_for_integration`.
2. Перестроить `_show_codex_screen` / `_show_codex_section` по новой композиции:
   left category buttons, center concise selected/list area, right expanded
   detail area with largest object image.
3. Сохранить data-driven источники `scripts/codex_data.gd`,
   `ProgressionData`/`StatFormulas`, Codex unlock tracking, glossary tooltips,
   Escape/back, mouse, keyboard and gamepad navigation including LB/RB section
   switching.
4. Сделать runtime object images крупными и чёткими: aspect preserved,
   no one-axis stretch, nearest filtering for pixel art, alpha/bounding-box aware
   placement where needed. На 1920x1080 right detail image должен читаться как
   главный визуальный объект, не как thumbnail.
5. Убрать/не создавать лишние nested frames; cards/panels нужны только там, где
   они отделяют navigation, central overview/list и detail content.

## Acceptance Criteria

- [ ] Все шесть категорий Codex рендерятся в новом layout и сохраняют существующий
      content coverage.
- [ ] На 1280x720, 1920x1080 и 2560x1440 нет наложения текста, иконок,
      портретов, scrollbars, кнопок или hitboxes на орнамент рамки или другую
      логическую область.
- [ ] Center selected/list entries показывают image + short summary only; right
      detail показывает larger object image + full body text в scroll-safe зоне.
- [ ] Character portraits используют canonical `sprite_path` / full-frame sources;
      artifacts используют canonical artifact icons; monsters/bosses используют
      существующие Codex art paths или documented fallback, а missing-quality
      случаи превращаются в follow-up tasks.
- [ ] Mouse, keyboard and gamepad focus работают: первая category focused on open,
      entry cards/selectors focusable, B/Escape/back возвращает в main menu,
      LB/RB циклично листают categories.
- [ ] Проходят проверки через `tools/godot_gate.py`: `runtime_smoke_ui_test.gd`,
      `ui_no_overlap_matrix_test.gd`, `codex_data_smoke_test.gd`,
      `runtime_smoke_test.gd`.
- [ ] Screenshot evidence записан для Codex на 1280x720, 1920x1080 и 2560x1440,
      включая минимум одну не-character категорию.

## Заметки Для Исполнителя

Это Back-end runtime-задача. Если при интеграции выяснится, что не хватает
качественного изображения для отдельного класса сущностей, не решать это внутри
runtime-задачи: создать отдельный Design asset follow-up и зафиксировать fallback.
