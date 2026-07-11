# SCRUM-1062 — Continue Run: общий игровой шрифт заголовка

Статус: done
Версия: 0.2.1
Jira: SCRUM-1062
Контур: Codex
Owner: Back-end/Codex `/root/scrum1062_continue_title`
Thread: `/root/scrum1062_continue_title`
Locked paths: ContinueRun-only hunks in `scripts/ui_screens.gd`; focused
ContinueRun title tests; `docs/design/mockups/scrum582_continue_run/spec.md`;
ContinueRun-only sections of `docs/design/systems/menus_ui.md` and
`docs/design/current_game_state.md`.

## Цель

Заменить отдельный PNG-wordmark `Продолжить забег?`, сгенерированный системным
Luminari, на доступный живой Godot `Label` в общей runtime title-family игры,
не меняя Continue Run frame/button art, callbacks, autosave flow или focus graph.

## Design / Typography Contract

- UI Director source: принятый PixelLab SCRUM-842 Continue Run reference
  `docs/design/mockups/scrum582_continue_run/scrum842_continue_run_button_fit_reference.png`.
- Новая графика не генерируется и generic fallback не используется.
- До SCRUM-1061 разрешён текущий effective theme/default Font, как у
  `QuitConfirmationTitle`, и fit-safe title tier `_readable_font_size(29)`;
  broad typography
  migration остаётся SCRUM-1061.
- Весь заголовок и его glyph effects должны оставаться внутри пустой content-zone
  `ContinueRunPanel`; rails/орнамент не перекрываются.

## Acceptance Criteria

- `ContinueRunTitle` — live `Label` с точным текстом `Продолжить забег?`, одной
  строкой и общим theme/default font resource.
- Нет runtime texture-wordmark или Luminari/Trattatello.
- Glyph bounds/outline/shadow, title slot, subtitle и кнопки не пересекаются и
  остаются frame-safe на 1152x648, 1280x720, 1920x1080, 2560x1440 + live resize.
- Продолжение autosave, новая игра, Escape, mouse/keyboard/gamepad focus не меняются.
- Focused title test, no-overlap, gamepad, runtime UI/full smoke и Metal matrix PASS.
- UI docs/spec обновлены; green commit pushed to `origin/dev`; Jira routed to QA.

## Результат

- `ContinueRunTitle` заменён с `TextureRect` на live `Label` с точным текстом
  `Продолжить забег?`, одной строкой, общим inherited theme/default Font resource,
  тёплым золотом, 2px outline и 2px shadow.
- Fit-safe pre-SCRUM-1061 title tier `_readable_font_size(29)` даёт
  `38/40/42/42px`; `Viewport.size_changed` обновляет tier при live resize.
- Exact matrix: panel `840×380`; safe local `Rect2(72,72,696,242)`; title
  `696×70` at local y `74/73/72/72` для 648p/720p/1080p/2K. Измеренные
  glyph/effect bounds frame-safe, subtitle/buttons не пересекаются.
- Принятый PixelLab SCRUM-842 frame/button reference переиспользован без новой
  или fallback-графики. Устаревшие `continue_run_title.png`, `.import` и
  `tools/build_continue_run_title_logo.py` удалены после sole-consumer audit;
  asset-reference integrity PASS.
- Autosave Continue/New Game callbacks, Escape и mouse/keyboard/gamepad focus
  сохранены; runtime/full smoke подтверждают оба autosave пути.
- PASS: `scrum1062_continue_run_title_test`, `ui_no_overlap_matrix_test`,
  `gamepad_menu_focus_test`, `gamepad_full_flow_smoke_test`,
  `runtime_smoke_ui_test`, `asset_reference_integrity_test`, полный
  `runtime_smoke_test`.
- Metal Apple M4 Pro: PASS и визуальная проверка 1152×648, 1280×720,
  1920×1080, 2560×1440.
- Independent read-only review: PASS, actionable findings нет; reviewer повторил
  focused/no-overlap/gamepad/runtime/full gates.
- Jira routing: после green push задача переводится в `Контроль качества`;
  `Готово` только после отдельного QA PASSED.

## QA-Вердикт (2026-07-11)

Статус: PASSED

Проверено: независимый QA на свежем `origin/dev` `625e97d82` подтвердил
implementation `3fd29ae30`: live `ContinueRunTitle` Label с точным русским
текстом и общей theme/default Font family; отсутствие runtime PNG/Luminari/
Trattatello reference; безопасное удаление wordmark/generator после sole-consumer
audit; frame-safe glyph/outline/shadow bounds, subtitle/actions и focus graph.
PASS: `scrum1062_continue_run_title_test`, `ui_no_overlap_matrix_test`,
`gamepad_menu_focus_test`, `gamepad_full_flow_smoke_test`,
`runtime_smoke_ui_test`, `asset_reference_integrity_test`, полный
`runtime_smoke_test`.

Краевые случаи: 1152×648, 1280×720, 1920×1080, 2560×1440, live resize,
Escape с сохранением autosave, Continue/New Game callbacks и стартовый focus.
Metal Apple M4 Pro matrix PASS; все четыре capture проверены глазами: одна строка,
без clip/wrap, декоративные rails/corners и пустая content-zone не перекрыты.

Баги: нет. Единственный diagnostic — известный non-failing dummy-renderer null
texture warning в headless weapon-select screenshot helper.

Disk cleanup: QA captures, isolated HOME/XDG/user-data roots, `.godot/`,
generated UID sidecars и fresh QA worktree удаляются после evidence push.
