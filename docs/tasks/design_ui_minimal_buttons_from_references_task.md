# ART/UX: Красивые кнопки по референсам (минимал-металлик, иногда рубины) — ПРИОРИТЕТ

Статус: new
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-450
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
- [ ] Новый красивый button-kit (минимал-металлик, опц. рубин) по референсам, прозрачный фон, все состояния (hover без жёлтого).
- [ ] Заменены по ВСЕМ экранам; текст/иконка в content-зоне, не обрезаны; старое в бэкап.
- [ ] smoke+matrix зелёные; контакт-лист+скрины; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.
