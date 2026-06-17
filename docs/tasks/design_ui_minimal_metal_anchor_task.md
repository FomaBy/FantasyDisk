# ART/UX: Упрощение интерфейса — ОПОРНАЯ (минимал-металлик стиль + единый фрейм)

Статус: done
Приоритет: high
Роль: Designer 2 (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-452
QA: in_progress (2026-06-17)
Связано: SCRUM-448 (минимал-рестайл — поглощается этой серией), SCRUM-384 (фрейм), SCRUM-273 (кнопки)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Серия задач по УПРОЩЕНИЮ интерфейса: перерисовать ВСЕ фреймы с ключевым условием —
МИНИМАЛИСТИЧНО, в строгих МЕТАЛЛИЧЕСКИХ стилях, иногда с РУБИНАМИ. Главное —
красивые КНОПКИ (референсы есть, использовать их)».

Это ОПОРНАЯ задача серии «UI Simplification». Задаёт стиль и единый минимал-фрейм
ПЕРЕД задачами кнопок и рамок (блокирует-координирует их).

Графику генерировать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG, ПРОЗРАЧНЫЙ фон); чистить прозрачность `tools/strip_white_background.py`. Стиль: МИНИМАЛИЗМ, строгий МЕТАЛЛИК (тёмная сталь/обсидиан/латунь), ИНОГДА рубины-акценты. Без тяжёлого орнамента/драконьих завитков. Контент в content-зоне (правило фреймов).

## Требования
1. Зафиксировать единый **минимал-металлик style-guide**: тонкие чистые
   металлические рамки (тёмная сталь/обсидиан + латунь/сталь-акцент), спокойный
   тёмный фон, МИНИМУМ декора, рубины — редкий точечный акцент (углы/центр), НЕ
   обилие. Документ в docs/design/references/ui_minimal_metal/ + visual_style_assets.
2. Спроектировать **единый минимал-фрейм** (9-slice): тонкая окантовка, опц.
   рубин-акцент, content-margins ≥ окантовки (контент строго внутри). Один
   стиль-билдер в коде (переосмыслить SCRUM-384 в минимализм); тинт-вариант для
   акцентов, но визуально один фрейм.
3. Общие UI-атомы (панели/тултипы/подложки) — минимал-набор, прозрачный фон.
4. Зафиксировать разбивку серии (кнопки, рамки-роллаут) и пути/нейминг.
5. Тест: эталонные экраны строятся в минимал-стиле, no-overlap, контент в зонах.
   Контакт-лист стиля в docs/design/previews/.
6. CHANGELOG; visual_style_assets; menus_ui.

## Acceptance Criteria
- [x] Минимал-металлик style-guide + единый минимал-фрейм (тонкий, опц. рубин) задокументированы и собраны скиллом.
- [x] Общие атомы готовы; разбивка серии зафиксирована; контент в content-зонах; no-overlap.
- [x] Контакт-лист стиля; CHANGELOG; runtime smoke/no-overlap scope передан Back-end handoff.

## Документация
docs/design/systems/visual_style_assets.md, menus_ui, content_registry.

## Результат

Designer 2 завершил Design-source anchor для minimal-metal UI simplification.
OpenAI-generated visual sources сохранены в
`docs/design/references/ui_minimal_metal/scrum452_minimal_metal_style_board.png`
и
`docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_source_sheet.png`.

Собран отдельный transparent RGBA production-candidate kit:

- `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_modal.png`
- `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png`
- `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png`
- `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png`
- `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_hud_strip.png`
- `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png`

Source-candidate copies live under
`docs/design/references/ui_minimal_metal/frames_raw/`. Exact texture margins,
content rects and alpha audit are recorded in
`docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`.
Style/spec docs:

- `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_style_guide.md`
- `docs/design/mockups/scrum452_ui_minimal_metal/spec.md`

Previews:

- `docs/design/previews/scrum452_minimal_metal_anchor_contact.png`
- `docs/design/previews/scrum452_minimal_metal_safe_zones.png`

Alpha validation for all six production PNGs:

- `white_opaque_pixels=0`
- `pale_visible_pixels_after_cleanup=0`
- `pale_edge_visible_pixels=0`

Design decision: the OpenAI source sheet is kept as visual direction; production
assets are deterministic transparent redraws derived from it so the handoff has
strict alpha and exact content zones. This avoids the opaque/white-background
defects called out in earlier art feedback.

Back-end runtime integration is handed off to
`docs/tasks/backend_ui_minimal_metal_anchor_integration_task.md`. Runtime code,
Godot theme wiring and smoke/no-overlap tests are intentionally out of this
Design-only pass.

## QA-Вердикт (2026-06-17)
Статус: PASSED (Design-source: minimal-metal anchor kit)
Проверено: production-candidate `minimal_metal/*.png` (modal/panel/card/field/tooltip/hud_strip) —
все RGBA, edge_alpha=0 (прозрачные, без каймы). Style-board + frame source sheet сохранены.
Опорная для интеграций 459/463. done → Готово.
