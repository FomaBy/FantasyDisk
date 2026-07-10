# BUG: Audio docs still mark landed UI/Credits tail as deferred

Статус: done
Приоритет: normal
Роль: Back-end / Documentation
Контур: Codex
Owner: /root/backend_docs_1041
Thread/Worker: /root/backend_docs_1041
Jira: SCRUM-1041
Версия: 0.2.1
Найдено QA при тестировании: SCRUM-968
Locked paths: `docs/design/systems/audio.md`;
`docs/design/current_game_state.md`; `docs/CREDITS.md`; `docs/design/audio.md`;
this mirror; scoped Jira sync bookkeeping for SCRUM-1041 only

## Контекст

Runtime SCRUM-968 UI tail уже landed в `scripts/ui_screens.gd`: purchase и
ui_error подключены к покупкам/отказам, ui_click/ui_back — через общий helper,
artifact_reveal используется для трёх reward/reveal точек, а Main Menu ведёт на
player-facing Credits screen. Независимая функциональная QA этих сценариев
зелёная.

Четыре docs-точки всё ещё говорят, что эти вызовы «отложены», или
ссылаются на удалённый SCRUM-968 tail mirror:

- `docs/design/systems/audio.md` (summary и Current state / SFX);
- `docs/design/current_game_state.md` (раздел «Звук»);
- `docs/CREDITS.md` (player-facing атрибуции);
- `docs/design/audio.md` (сводка пака/лицензий).

## Acceptance Criteria

- [x] Все четыре docs-точки описывают landed purchase/ui_error/ui_click/ui_back/
      artifact_reveal call sites и Credits screen.
- [x] Все ссылки/формулировки про удалённый deferred tail убраны.
- [x] Runtime code, tests и assets не меняются.
- [x] Reference/link grep и релевантный docs/runtime smoke проходят.
- [x] Результат готов к commit/push в `origin/dev` и передаче QA.

## Результ (2026-07-11)

- Исправлены четыре stale docs-точки: audio system summary/current
  state, общий current game state, канонические Credits и audio
  sourcing summary.
- Документы теперь точно описывают landed `purchase`/
  `ui_error`, `_connect_ui_sfx` для `ui_click`/`ui_back`, `artifact_reveal`
  на баннере победы и elite/boss reward screens, а также live
  `MainMenuCreditsButton` → `CreditsScreen` → `CreditsBackButton`/Escape flow.
- Repo-wide `rg 'SCRUM-968_ui_screens_tail\\.md'` — zero references; stale
  deferral grep по четырём документам — zero matches.
- UTF-8/LF/final-newline и referenced-path checks — PASS; `git diff --check`
  — PASS; modified paths — только docs/mirror этой задачи.
- `python3 tools/godot_gate.py --headless --path . --script
  res://tests/runtime_smoke_test.gd` — PASS (`Runtime smoke test passed`; только
  известное benign headless screenshot warning).

## QA routing

SCRUM-968 функционально PASSED, но остаётся в `Контроль качества` только до
исправления этого documentation child. Jira issue создан первым; локальный файл
— spec/evidence mirror.
