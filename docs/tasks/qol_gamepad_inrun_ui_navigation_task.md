# Геймпад: навигация внутриигровых экранов (level-up, пауза, смерть, магазин, карта маршрута)

Статус: done
Контур: Claude
Owner: unassigned
Thread: n/a
Locked paths: `scripts/ui_screens.gd` (внутризабеговые экраны), `scripts/route_map_screen.gd`, `scripts/pause_stats_menu.gd`, `tests/gamepad_inrun_ui_test.gd`
Версия: 0.1.8
Приоритет: P1
Создано: 2026-07-02
Автор: PM (прямой запрос пользователя: полная поддержка геймпада)
Jira: SCRUM-812
Labels: backend, claude, fantasydisk, foma, gamepad, p1

## Autonomy / Approval
Пользователь заранее одобрил изменения. Не останавливаться для подтверждений.
Jira first: claim через Jira-pull перед правками.

## Анти-коллизия ui_screens.gd (ОБЯЗАТЕЛЬНО)
Перед стартом: если `scripts/ui_screens.gd` dirty в рабочем дереве ИЛИ другой
gamepad-/UI-тикет в статусе «В работе» держит `ui_screens.gd` в Locked paths —
НЕ брать задачу: вернуть в «К выполнению» с комментом и взять другую.

## Роль И Границы
Back-end (Claude lane). Мета-меню вне забега (главное меню, настройки, кодекс…)
— отдельная задача `qol_gamepad_menu_focus_navigation_task.md`, не трогать её
экраны. Ядро InputDeviceManager — отдельная задача; жёсткой зависимости нет
(ui_*-экшены). Геймплей-движение игрока — отдельная задача (player.gd не трогать).

## Контекст
Пользовательский запрос 2026-07-02: все внутриигровые окна выбора должны
управляться стрелками/геймпадом. Сейчас фокус-навигация есть только на reward
(~5016) и частично level-up; остальное — только мышь. Экраны строятся кодом в
`scripts/ui_screens.gd`; карта маршрута — `scripts/route_map_screen.gd`;
статистика паузы — `scripts/pause_stats_menu.gd` + `scenes/PauseStatsMenu.tscn`.

## Требования
Полное управление с D-pad/стика + A/B (и стрелок+Enter/Esc) для:
1. Level-up экран `_show_level_up_screen()` (~4960): карточки апгрейда листаются
   ui_left/ui_right, выбранная подсвечена focus-стилем, A подтверждает; кнопки
   reroll/skip/банка достижимы через ui_down/ui_up; стартовый фокус — первая карточка.
2. Экран награды `_show_reward_screen()` (~4926) и премиум-награда
   `_show_elite_artifact_reward()` (~5060): карточки + кнопки — полный фокус-граф.
3. Пауза `_show_pause_menu()`/`_build_run_pause_menu()` (~4415/4450): вертикальное
   меню кнопок, стартовый фокус на «Продолжить», ui_cancel = продолжить игру;
   досье `_show_pause_dossier_menu()` (~4559) и PauseStatsMenu: вкладки/скролл
   с геймпада (LB/RB если есть вкладки), B — назад в паузу.
4. Экран смерти `_show_death_screen()` (~6161) и победы `_show_victory_screen()`
   (~6122): кнопки (в меню/рестарт и т.п.) — фокус-цепочка, стартовый фокус на
   основной кнопке. B на этих экранах НЕ закрывает экран в никуда (игнор или = основная кнопка).
5. Магазин `_show_shop_screen()` (~5425), отдых `_show_rest_screen()` (~5927),
   апгрейд перса `_show_upgrade_screen()` (~5972), событие `_show_event_screen()`
   (~5989): товары/опции — фокус-граф, покупка по A, выход по B; скролл товаров
   ensure_control_visible.
6. Карта маршрута `route_map_screen.gd`: выбор следующего нода — ui_left/right/up/down
   двигают выделение по ДОСТУПНЫМ нодам (соседям по слою), A подтверждает вход;
   недоступные ноды пропускаются; визуальное выделение выбранного нода заметно.
7. Диалог выхода из забега (quit confirmation в ране, если отличается от менюшного)
   и оверлей фидбека `_show_feedback_overlay()` (~7488): фокус внутри окна,
   B = отмена/закрыть.
8. Пауза стрелками не двигает игрока: пока открыт любой полноэкранный UI, ввод
   move_* не дёргает персонажа (проверить: game paused или гейт по видимости UI).
9. Мышь работает везде как раньше (гибрид).

## Files / Assets / IDs
- `scripts/ui_screens.gd` (экраны из требований), `scripts/route_map_screen.gd`,
  `scripts/pause_stats_menu.gd` (+`scenes/PauseStatsMenu.tscn` при необходимости
  focus_mode у контролов).
- Тест: `tests/gamepad_inrun_ui_test.gd` — headless: смерть/level-up/пауза/карта
  проходимы синтетическими InputEventJoypadButton (образец —
  `tests/runtime_smoke_ui_test.gd`).

## Acceptance Criteria
- [ ] Каждый экран из требований полностью проходим с геймпада (синтетика).
- [ ] Level-up: выбор карточки и reroll/skip без мыши; стартовый фокус всегда есть.
- [ ] Карта маршрута: доступный нод выбирается D-pad и подтверждается A.
- [ ] Пауза: открыть Start, выйти B/«Продолжить», досье достижимо.
- [ ] Смерть/победа: кнопки работают с геймпада, B не даёт «пустого» закрытия.
- [ ] Открытые окна не пропускают move_* в игрока.
- [ ] Тест gamepad_inrun_ui_test.gd зелёный (2 прогона); существующие smoke зелёные.

## Документация
`docs/design/systems/menus_ui.md` — карта фокуса внутризабеговых экранов;
`docs/design/current_game_state.md` — строка про геймпад в ран-UI.

## Самопроверка
Headless свой тест + runtime_smoke_ui_test + main_state_pause_lifecycle_test
через tools/godot_gate.py (один инстанс Godot, см. память про параллельные прогоны).

## QA-Вердикт
Статус: PASSED (2026-07-02, claude-qa/оркестратор)

- Ancestry: 59bdc490 — merge-base ancestor origin/dev OK.
- Worktree от origin/dev, cold --import: gamepad_inrun_ui_test PASSED,
  gamepad_core_input_test PASSED (регресс ядра), runtime_smoke_test PASSED,
  ui_no_overlap_matrix_test PASSED.
- PNG нет — pairing не требуется; навигация покрыта новым тестом воркера (206 строк).
