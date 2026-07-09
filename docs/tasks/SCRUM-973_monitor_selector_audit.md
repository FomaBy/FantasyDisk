# SCRUM-973 — Audit monitor selector behavior

Статус: review
Контур: Codex
Owner: Backend/Codex
Thread: /root/audit_ready
Locked paths: `tests/monitor_selector_behavior_test.gd`, `docs/tasks/SCRUM-973_monitor_selector_audit.md`; `scripts/game_settings.gd` only if a missing pure persistence/clamp helper is proven; `docs/process/jira_sync_map.json` only if scoped sync changes it
Jira: SCRUM-973

## Контекст

Проверить существующий выбор монитора во вкладке «Экран», не дублируя уже
реализованный control. Runtime UI и общие UI-тесты заняты параллельными задачами,
поэтому `scripts/ui_screens.gd`, `tests/video_settings_apply_test.gd`,
`tests/ui_no_overlap_matrix_test.gd` и `tests/runtime_smoke_test.gd` в этой задаче
используются только для чтения и проверки.

## Acceptance audit

- Один монитор: `SettingsScreenOption` создаётся только при `screen_count > 1`,
  поэтому лишний selector скрыт.
- Несколько мониторов: selector строит стабильные подписи `Экран N (WxH)`,
  хранит выбор в pending state и применяет его только через Apply.
- Apply/Revert: pending video state отделён от сохранённого состояния;
  Apply вызывает `_apply_video_settings()` и persistence, Revert восстанавливает
  текущие значения.
- Исчезнувший монитор: pending и runtime screen index клампятся в диапазон
  доступных экранов до обращения к geometry выбранного экрана.
- Разрешения: selector использует текущие `RESOLUTION_OPTIONS` (2K и Full HD),
  availability проверяется относительно выбранного монитора.
- Навигация/геометрия: существующие video settings, no-overlap и runtime smoke
  остаются обязательными regression gates.

## План проверки

1. Добавить отдельный deterministic headless test для virtual one/multi-screen
   state, label contract, clamp, persistence и pending Apply/Revert semantics.
2. Прогнать focused test, `game_settings_smoke_test.gd`,
   `video_settings_apply_test.gd`, `ui_no_overlap_matrix_test.gd` и
   `runtime_smoke_test.gd` через `tools/godot_gate.py`.
3. После green gates синхронизировать Jira mirror, commit/push в `origin/dev` и
   передать задачу в «Контроль качества» без self-QA.

## Результат

- Подтверждено, что текущий runtime уже выполняет весь monitor-selector contract;
  production UI и persistence code менять не потребовалось.
- Добавлен `tests/monitor_selector_behavior_test.gd`: deterministic headless
  coverage для one/multi-screen state, стабильной подписи `Экран N (WxH)`,
  stale-index clamp, pending dirty state, Apply/Revert и restart persistence.
- `scripts/ui_screens.gd`, `scripts/game_settings.gd` и существующие общие тесты
  не изменялись; конфликтующие locks SCRUM-955/SCRUM-1002 соблюдены.
- Product docs не менялись: `docs/design/current_game_state.md` и
  `docs/design/systems/menus_ui.md` уже документируют фактическое поведение.

## Проверки

- `python3 tools/godot_gate.py --headless --path . --script res://tests/monitor_selector_behavior_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/game_settings_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/video_settings_apply_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS; headless dummy renderer emitted the existing non-fatal `Parameter \"t\" is null` capture warning.

## Cleanup

Disk cleanup: pending final push; disposable `.godot/` cache and worktree will be removed.
Thread cleanup: not a disposable top-level worker thread; sub-agent will report to dispatcher.
