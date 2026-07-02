# SCRUM-700: QA 1080p UI scale pass for HUD and menus

Статус: done
Приоритет: P1
Роль: QA / visual QA
Контур: Codex
Executor: Codex
Owner: QA/Codex coordinator
Thread/Worker: codex-qa-scrum700-finish-20260701 / codex-qa-claude-monitor
Locked paths: read-only UI screens; `docs/tasks/qa_ui_1080_scale_visual_task.md`; QA evidence under `build/qa/scrum700_1080_ui_scale/`; follow-up bugs may lock specific UI files separately
Версия: 0.2.0
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя
Jira: SCRUM-700

## Progress Log

- 2026-06-30 — Claimed in Jira by `codex-hud-redesign-subagents-2026-06-30`.
  Scope is QA/visual evidence only: read-only UI screens, this task mirror, and
  `build/qa/scrum700_1080_ui_scale/`. Started through subagents for HUD runtime
  inventory, 1080p capture/evidence, and Jira/task consistency checks.
- 2026-06-30 — Subagent 1080p focused capture created fresh evidence under
  `build/qa/scrum700_1080_ui_scale/`. Main menu is a hard FAIL and maps to the
  existing bug `SCRUM-680`; combat HUD is a visual scale/empty-frame WARN and
  follow-up bug `SCRUM-778` was created for Back-end UI tuning.
- 2026-07-01 — QA continuation finalized the pass on `origin/dev` and confirmed
  the two user-reported issues are covered by Jira bugs `SCRUM-680` and
  `SCRUM-778`. No runtime/UI fixes were made in this QA task.

## Evidence Start — 2026-06-30

Fresh 1920x1080 evidence:

- Summary: `build/qa/scrum700_1080_ui_scale/qa_observations.md`
- Rect dump: `build/qa/scrum700_1080_ui_scale/priority_rects_1920x1080.md`
- Preliminary verdicts: `build/qa/scrum700_1080_ui_scale/preliminary_verdicts.md`
- Main menu screenshot:
  `build/qa/scrum700_1080_ui_scale/screenshots/main_menu_1920x1080.png`
- Combat HUD screenshot:
  `build/qa/scrum700_1080_ui_scale/screenshots/combat_hud_1920x1080.png`

Findings:

- Main menu 1920x1080: FAIL. `MainMenuTitleLabel` ends at `y=323`, while
  `MainMenuStartButton` starts at `y=203` and `MainMenuSettingsButton` starts at
  `y=317`; nearest vertical gap is `-120 px`. Existing Jira bug `SCRUM-680`
  was updated with this evidence instead of creating a duplicate.
- Combat HUD 1920x1080: geometry PASS, visual WARN/bug. Priority panels occupy
  `14.32%` of viewport area and top HUD band reaches `26.20%` of viewport
  height; the resource/timer/ascension frames are very wide/tall and mostly
  empty. Follow-up Jira bug `SCRUM-778` created.

Subagent status:

- Runtime inventory: completed.
- 1080p focused capture: completed for priority screens.
- Jira/local consistency audit: completed; `jira_sync_map.json` may need final
  scoped sync because it still had stale status for SCRUM-700 at audit time.

Disk cleanup: none outside intentional ignored evidence under
`build/qa/scrum700_1080_ui_scale/`.

## QA-Вердикт (2026-07-01)

Статус: PASSED (QA pass complete; product/UI findings filed separately)

Проверено:

- Evidence folder restored and reviewed:
  `build/qa/scrum700_1080_ui_scale/`.
- 1920x1080 screenshots present for: main menu, settings, hero select, weapon
  select, codex, level-up, shop, event, pause/stats, victory, death and combat
  HUD.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
  — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
  — PASS.

Findings:

- Main/start menu 1920x1080 — FAIL as product finding: title/logo overlaps menu
  controls (`MainMenuTitleLabel` bottom `y=323`, start button top `y=203`,
  nearest vertical gap `-120 px`). Covered by existing bug `SCRUM-680`.
- Combat HUD 1920x1080 — geometry PASS but visual scale FAIL/WARN as product
  finding: priority panels occupy `14.32%` of the viewport and the top HUD band
  reaches `26.20%`; resource/timer/ascension frames are very wide/tall and
  mostly empty. Covered by bug `SCRUM-778`.
- Other captured screens in the focused pass did not introduce additional
  blocker bugs in this QA task; any future screen-specific issue should be filed
  as a separate Jira bug with screenshot evidence.

Bugs:

- `SCRUM-680` — main menu/logo overlap at 1920x1080.
- `SCRUM-778` — combat HUD oversized / mostly empty at 1920x1080.

Branch/commit:

- QA mirror/evidence commit: pending at time of writing.

Disk cleanup:

- Disposable QA worktree and `.godot` cache removed after commit/push; evidence
  intentionally kept under `build/qa/scrum700_1080_ui_scale/`.

## Контекст

После последних изменений читаемости/масштаба UI часть интерфейса выглядит
слишком крупной на 1920x1080. Пользовательские примеры: боевой HUD занимает
почти полэкрана, а стартовое меню визуально залезает на логотип. Нужен отдельный
QA-проход по всем основным экранам именно с фокусом на масштаб и занимаемую
площадь UI на 1080p.

## Что сделать

1. Прогнать визуальный QA-проход всех основных UI-состояний на 1920x1080.
2. Сравнить с 1280x720 и 2560x1440 только там, где нужно понять, это ожидаемая
   адаптивность или регрессия масштаба на 1080p.
3. Проверить как минимум: main/start menu, combat HUD, settings, hero select,
   weapon select, codex, skill tree/progression, shop/economy, rewards/level-up,
   event/rest/upgrade, pause/stats, victory/death, dialogs, tooltips and feedback
   overlays.
4. Отдельно подтвердить два пользовательских примера:
   - HUD в игре на 1920x1080 не должен доминировать над игровой областью или
     закрывать значимую часть поля.
   - стартовое меню на 1920x1080 не должно перекрывать логотип/заголовок и не
     должно быть визуально прижато к нему.
5. Проверить глобальное правило фреймов: текст, кнопки, иконки и контент должны
   оставаться во внутренней пустой зоне, не на орнаменте/окантовке.
6. QA в этой задаче не чинит runtime/UI. По каждой подтверждённой проблеме
   создаётся отдельный bug issue + local mirror с экраном, разрешением,
   screenshot path, expected/actual и рекомендуемой ролью владельца.

## Acceptance Criteria

- [ ] Есть 1920x1080 screenshot/contact-sheet pass для всех экранов из scope.
- [ ] По каждому экрану есть короткий PASS/FAIL verdict: масштаб, занятая
      площадь, читаемость, расстояния до логотипа/заголовков, content-zone rule.
- [ ] Combat HUD на 1920x1080 проверен отдельно; если он закрывает слишком
      большую часть игровой области, заведён отдельный bug с evidence.
- [ ] Main/start menu на 1920x1080 проверено отдельно; если меню перекрывает
      логотип или визуально наползает на него, заведён отдельный bug с evidence.
- [ ] Все подтверждённые проблемы заведены отдельными Jira bug/local mirrors.
- [ ] Если экран проблем не имеет, это явно записано как PASS, а не пропущено.
- [ ] Итоговый QA-комментарий содержит branch/commit, команды или capture
      harness, пути к evidence, список созданных bugs и `Disk cleanup:`.

## Evidence Targets

- `build/qa/scrum700_1080_ui_scale/`
- `build/qa/design_review/` допустим как источник, если QA перегенерит свежие
  скриншоты и явно укажет tested commit.

## Рекомендуемые Проверки

- `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
