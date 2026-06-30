# Refactor Wave: ui_screens Runtime-Only Monolith Audit

Jira: SCRUM-716
Статус: done
Приоритет: P1
Роль: Back-end / UI runtime quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-ui, area-runtime
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

`scripts/ui_screens.gd` is the largest runtime file and needs a careful code-quality pass. This task is runtime-only: it must not redesign UI art, layout direction or frame geometry.

## Scope / Locked Paths

- `scripts/ui_screens.gd`
- Focused UI tests
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/ui_technical_requirements.md`

## Required Change

Audit and safely refactor `ui_screens.gd` runtime code without visual redesign: screen lifecycle, node naming contracts, safe-zone containment helpers, HUD snapshots, tooltip ownership, focus/input flow, duplicated button/card helpers and fragile test-only accessors. No new art, no mockup pass, no frame geometry changes; if visual changes are required, create a separate UI-director handoff.

## Acceptance Criteria

- Runtime UI audit is recorded.
- No content overlaps decorative frame art after changes.
- Existing UI screens preserve layout and interaction contracts.
- Duplicated helper code is reduced only when risk is controlled by tests.
- UI no-overlap and theme tests cover touched screens.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd
```

## Hard UI Rule

Content may never overlap decorative frame texture/ornament. Text, icons, buttons, cards and interactive controls must stay inside the real inner content zones. If a UI visual/layout change is needed, stop this task and create a proper UI-director handoff.

## Результат (Claude backend, 2026-06-30)

Ветка/коммит: `dev` @ `be3e2af7` (origin/dev, ancestor подтверждён).

### Runtime UI-аудит (записан)
- `ui_screens.gd` — крупнейший runtime-файл (был 10077 строк, 383 функции).
  В целом ХОРОШО факторизован: общие theme/style-хелперы вынесены
  (`_apply_fantasy_button_theme`, `_button_state_style`, `_character_card_style`),
  кнопки/карточки строятся через них, дин-диспетчеризации по строке-имени нет
  (только локальные Callable-переменные). Визуальных багов/оверлапов нет
  (no-overlap/theme gates зелёные на baseline).
- **Concrete-находка: мёртвый код.** 36 приватных функций имеют НОЛЬ ссылок по
  всему репозиторию (.gd/.tscn/.tres/.godot) — осиротевшие builder'ы прошлых
  редизайнов (HUD: `_create_artifact_hud_row`/`_create_character_stats_hud`;
  hero-select hs4/pixellab: `_hs4_place`/`_hs4_pixellab_rect`/...; codex/progression
  style-хелперы; `_make_section_label`, `_format_artifact_list`, `_ornate_frame_style`
  и т.д.).

### Изменения (locked path, без визуала/геометрии — per Hard UI Rule)
- `scripts/ui_screens.gd` — удалены ровно эти 36 leaf-dead функций (−460 строк,
  0 добавлений). Подтверждено: (1) два независимых прохода анализа ссылок,
  (2) отсутствие динамического `call("_name")`, (3) функции не ссылаются друг на
  друга → ни каскада новых поломок, ни висячих ссылок. Поведение/арт/раскладка/
  рамки не тронуты — удалён только недостижимый код.

### Проверки (semaphore, GODOT_BIN=fdengine, slots=1) — все RC=0 (после удаления)
- `tests/runtime_smoke_ui_test.gd` → passed.
- `tests/ui_no_overlap_matrix_test.gd` → passed (контент не залезает на рамку).
- `tests/dark_fantasy_ui_theme_test.gd` → passed.
- `tests/runtime_smoke_test.gd` → passed.

### Заметка для будущих волн (не в этом тикете)
Удаление leaf-dead могло осиротить ВТОРОЙ слой хелперов (вызывавшихся только из
удалённых). Повторный dead-scan на следующей UI-волне добьёт каскад — не делал
здесь, чтобы держать диф контролируемым и низкорисковым на hot-файле.

Disk cleanup: рабочий worktree `/private/tmp/fsd_wt_scrum716` удалён после пуша;
бэкап `/tmp/ui_screens_backup.gd` — временный, можно удалить.
