# BUG: Настройки → «Управление» — элементы не помещаются на экране, нужен скролл

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя)
Jira: SCRUM-275

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (отчёт пользователя)
«В настройках в разделе "Управление" не помещаются элементы на экране — давай
скролл добавим».

Вкладка «Управление» (ui_screens.gd:1463-1518) содержит: ряд «Прицеливание»
(aim mode, добавлен в SCRUM-241), список ВСЕХ биндингов `INPUT_ACTIONS`
(по ряду на действие, ~WASD/абилки/пауза и т.д.) и кнопку «Сбросить управление
по умолчанию». Контент перерос высоту окна. У соседних вкладок ScrollContainer
есть (ui_screens.gd:862/964/1065), а у «Управления» — нет (или контент вышел
за него).

## Требования
1. Обернуть содержимое вкладки «Управление» в `ScrollContainer` (вертикальный
   скролл, горизонтальный disabled — как в других вкладках settings), чтобы все
   элементы (прицеливание + все биндинги + кнопка сброса) были доступны прокруткой
   на любом поддерживаемом разрешении (включая 1280x720 и оконные).
2. Скролл работает мышью (колесо) и клавиатурой/геймпадом (фокус-навигация
   доходит до нижних рядов, авто-прокрутка к сфокусированному элементу).
3. Сохранить отступы/выравнивание рядов; контент не наезжает на рамку
   вкладки/скроллбар; кнопка «Назад» снизу остаётся видимой и не перекрывается
   (правило «UI не наползает», qa_protocol).
4. Применить тот же паттерн к ЛЮБОЙ другой вкладке settings, если её контент
   тоже может переполниться (проверить «Звук»/«Экран» на узких окнах).
5. Тест (smoke): на узком окне (1280x720) контент вкладки «Управление» больше
   высоты вьюпорта → присутствует ScrollContainer и нижние элементы достижимы
   (фактическое дерево: ScrollContainer оборачивает controls_box; reset-кнопка
   внутри прокручиваемой области).
6. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (вкладка «Управление» 1463-1518, _make_settings_tab,
  паттерн ScrollContainer как на 862/964/1065)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Вкладка «Управление» прокручивается; все элементы доступны на 1280x720 и оконных.
- [ ] Скролл мышью и клавиатурой/геймпадом; авто-прокрутка к фокусу.
- [ ] «Назад» не перекрыта; no-overlap; 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md (настройки/управление).

## Result (2026-06-14)

Done. The settings `Управление` tab now uses `ControlsScroll` with vertical-only
scrolling and `follow_focus`, so the aim mode selector, all keybinding rows, the
hint and `SettingsResetBindingsButton` remain reachable at 1280x720/windowed
sizes while the `Назад` button stays outside the scrollable area. Added runtime
smoke assertions that `ControlsScroll` wraps `ControlsContent`, contains
`SettingsAimModeOption` and `SettingsResetBindingsButton`, disables horizontal
scrolling and follows keyboard/gamepad focus.

QA dump:
- `build/qa/settings_controls_scroll.md`

Verification:
- `res://tests/runtime_smoke_test.gd` PASS.
- `res://tests/runtime_smoke_ui_test.gd` PASS.
- `res://tests/ui_no_overlap_matrix_test.gd` PASS.
- `res://tests/aim_mode_settings_test.gd` PASS.

Docs:
- `CHANGELOG.md`
- `docs/design/current_game_state.md`
