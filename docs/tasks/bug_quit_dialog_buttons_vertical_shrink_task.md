# BUG: Диалог выхода — кнопки «скукоживаются» по вертикали, исправить

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-344
QA: in_progress (2026-06-14)
Связано: SCRUM-319 (диалог подтверждения выхода)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«При подтверждении выхода кнопки скукоживаются по вертикали — не надо так делать,
исправить».

Диалог `_show_quit_confirmation_dialog` (ui_screens.gd:236): кнопки «Выйти»/«Отмена»
в `QuitConfirmationButtons` HBoxContainer (297), `_set_action_button_size(btn,
220.0, 72.0)` (304/315). Кнопки сжимаются по высоте (вертикальное скукоживание) —
вероятно контейнер/диалог ужимает высоту, или size_flags_vertical/мин.высота
рамки не держат заданные 72px.

## Требования
1. Кнопки «Выйти»/«Отмена» сохраняют полную заданную высоту (≈72px), НЕ сжимаются
   по вертикали; рамка кнопки не сплющивается. Зафиксировать вертикальный размер
   (custom_minimum_size.y, size_flags_vertical без нежелательного EXPAND/SHRINK,
   при необходимости поправить контейнер/панель диалога).
2. Текст по центру, читаем; единый размер двух кнопок; диалог по центру экрана,
   модальность и фокус на «Отмена» (SCRUM-319) не сломаны.
3. Контент в content-зоне рамки (глоб. правило фреймов); no-overlap.
4. Тест (smoke): диалог выхода строится; высота кнопок == заданной (не сжата);
   скрин диалога в build/qa/. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_quit_confirmation_dialog 236-323; QuitConfirmationButtons
  297; confirm/cancel 302-317; box VBox; _set_action_button_size)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Кнопки диалога выхода не скукоживаются по вертикали, держат высоту; текст читаем.
- [ ] Модальность/фокус/центрирование (SCRUM-319) целы; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md

## Result 2026-06-14

Implemented Back-end UI fix:
- `QuitConfirmationButtons` row and both dialog buttons now keep shrink-centered
  vertical sizing with 72px minimum height;
- `QuitConfirmExitButton` and `QuitConfirmCancelButton` are routed to the
  Red&Gold `pause` button frame, which has safe margins for 220x72 buttons,
  instead of falling back to the vertically squashed `back_s` texture;
- runtime smoke asserts the actual 220x72 rect, `pause` texture type, modal
  behavior and safe default focus on `Отмена`.

QA dump: `build/qa/scrum319/quit_confirmation_dialog.md`.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

Docs updated: `CHANGELOG.md`, `docs/design/systems/menus_ui.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: dev (зелёный build)

Проверено (фактически):
- **QA-dump** `build/qa/scrum319/quit_confirmation_dialog.md`:
  `QuitConfirmExitButton` и `QuitConfirmCancelButton` — оба rect `S(220,72)`,
  min `(220,72)`, texture `ui_btn_red_gold_pause.png` → НЕ сжаты по вертикали
  (держат полные 72px). `dialog: true` (модальный), `focus_owner:
  QuitConfirmCancelButton` (фокус на «Отмена», SCRUM-319 цел), panel
  `P(500,630) S(600,340)` → центр (800,800) = центр экрана.
- **Визуал** `build/qa/cap_quit_dialog.png`: «Выйти»/«Отмена» полной высоты,
  текст по центру читаем, рамки не сплющены, диалог по центру, оверлей затемнён.
- runtime_smoke (`_test_main_menu_quit_confirmation`) — passed.

Acceptance:
- [x] Кнопки не скукоживаются, держат 72px; текст читаем.
- [x] Модальность/фокус/центрирование целы; smoke зелёные; скрин есть.

Баги: нет.
