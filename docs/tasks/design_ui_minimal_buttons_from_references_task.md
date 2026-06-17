# ART/UX: Красивые кнопки по референсам (минимал-металлик, иногда рубины) — ПРИОРИТЕТ

Статус: done
Приоритет: high
Роль: Designer 2 (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-450
QA: in_progress (2026-06-17)
Связано: SCRUM-273 (текущий button-kit), опорная минимал-серии, ui-references

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«ГЛАВНОЕ — сделать красивые кнопки. Референсы у тебя есть — используй их».

Референсы кнопок (в репо):
- docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png
- docs/design/references/ui_dark_fantasy_2026_06/: button_obsidian_brass_runed,
  button_warplate_iron, button_royal_crimson_gold, button_dragon_scale,
  button_dwarven_stone, button_eldritch_void, button_necromancer_green,
  button_bone_skulls, button_parchment_wax_seal.
Под «строгий металлик + иногда рубины» ОРИЕНТИР: obsidian_brass_runed / warplate_iron
(металлик) + royal_crimson_gold (рубиново-красный акцент).

Графику генерировать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG, ПРОЗРАЧНЫЙ фон); чистить прозрачность `tools/strip_white_background.py`. Стиль: МИНИМАЛИЗМ, строгий МЕТАЛЛИК (тёмная сталь/обсидиан/латунь), ИНОГДА рубины-акценты. Без тяжёлого орнамента/драконьих завитков. Контент в content-зоне (правило фреймов).

## Требования
1. **Красивые кнопки** в минимал-металлик стиле ПО РЕФЕРЕНСАМ (взять лучшее из
   указанных, не копировать 1-в-1 — воспроизвести/улучшить скиллом на прозрачном
   фоне): чистый металл, тонкая окантовка, опц. рубин-акцент; состояния
   normal/hover/pressed/focus/disabled (hover — ярче/контрастнее, БЕЗ жёлтого
   свечения, SCRUM-318).
2. Все размеры/типы кнопок игры (главные действия, назад, компактные, табы,
   +/- возвышение) — единый комплект 9-slice.
3. Заменить текущие кнопки на новые по ВСЕМ экранам (через button-стиль-билдер
   _apply_fantasy_button_theme/_button_state_style); старый kit — в бэкап.
4. Контент кнопки (текст/иконка) в content-зоне, не на окантовке; читаемо.
5. Тест (smoke+no-overlap): кнопки на всех экранах в новом стиле, состояния
   работают, не обрезаны. Контакт-лист кнопок + скрины в build/qa/.
6. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_button, _apply_fantasy_button_theme, _button_state_style,
  RED_GOLD_BUTTON_*; _apply_compact_button_theme)
- assets/sprites/ui/ (новый button-kit) + бэкап старого
- docs/design/references/Buttons + ui_dark_fantasy_2026_06 (источники)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] Новый красивый button-kit (минимал-металлик, опц. рубин) по референсам, прозрачный фон, все состояния (hover без жёлтого).
- [x] Design-source kit готов; runtime replacement/backups по всем экранам переданы Back-end handoff.
- [x] Контакт-лист+safe-zone preview; CHANGELOG; runtime smoke/matrix scope передан Back-end handoff.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Результат

Designer 2 завершил Design-source button kit для SCRUM-450.

OpenAI-generated source sheet:

- `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_source_sheet.png`

Production-candidate assets:

- `assets/sprites/ui/frames/minimal_metal_buttons/` — 15 button types × 5 states
  (`normal`, `hover`, `pressed`, `focus`, `disabled`), всего 75 RGBA PNG.
- Source-candidate copies: `docs/design/references/ui_minimal_metal_buttons/buttons_raw/`

Spec/docs:

- `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_style_guide.md`
- `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`
- `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
- `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_alpha_audit.md`

Previews:

- `docs/design/previews/scrum450_minimal_metal_button_contact.png`
- `docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`

All 75 production PNGs validate as:

- `white_opaque_pixels=0`
- `pale_visible_pixels_after_cleanup=0`
- `pale_edge_visible_pixels=0`

Design choices:

- Visual basis: `button_obsidian_brass_runed` + `button_warplate_iron`, with
  restrained ruby accents from `button_royal_crimson_gold`.
- Hover/focus states use neutral/cool-metal brightening, no yellow glow.
- Runtime labels/icons must stay inside `content_rect_xywh`; side caps, ruby
  pins, rails, bevels and back-arrow ornaments are forbidden content zones.
- The existing SCRUM-273 Red & Gold runtime kit is not replaced in this Design
  pass. Runtime wiring, backups, UI no-overlap matrix and smokes are handed off
  to `docs/tasks/backend_ui_minimal_buttons_from_references_integration_task.md`.

## QA-Вердикт (2026-06-17)
Статус: PASSED (Design-source: minimal-metal button kit)
Проверено: 75 RGBA PNG (15 типов × 5 состояний normal/hover/pressed/focus/disabled) в
`minimal_metal_buttons/`; source sheet сохранён. Кнопки — solid-поверхности (валидированы
интеграцией 462 через dark_fantasy_ui_theme_test). done → Готово.
