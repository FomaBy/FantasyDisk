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

## QA-Вердикт (2026-07-11)

Статус: PASSED

Проверено:

- fresh `origin/dev` с `ae91d4731` + `c2846324d`; implementation/runtime paths
  оставались read-only;
- repo-wide deleted-tail reference grep и целевой deferred/pending grep для
  `purchase`, `ui_error`, `ui_click`, `ui_back`, `artifact_reveal` и Credits —
  zero matches;
- все четыре исправленных документа: UTF-8, LF, final newline; runtime↔docs
  oracle подтверждает live call sites и player-facing Credits flow;
- шесть треков Kevin MacLeod, CC BY 4.0-блок, CC0-вклад и Godot attribution
  совпадают с `SOURCES.md`, mastering manifest и runtime Credits text;
- `audio_integration_test.gd` — PASS;
- `ui_no_overlap_matrix_test.gd` — PASS;
- `runtime_smoke_test.gd` — PASS на финальном серийном прогоне. Первый
  параллельный прогон встретил известную общую `user://` autosave-гонку; она не
  воспроизвелась серийно. Benign headless screenshot texture diagnostic не
  изменил exit 0 / `Runtime smoke test passed`.

Краевые случаи: повреждённый первым crash'ем импорт-кэш удалён и полностью
пересобран в `--single-threaded` режиме; проверены отсутствие удалённой ссылки
во всём репозитории, точные лицензии/названия треков и live UI/audio call sites.

Баги: нет.

Jira: `SCRUM-1041` → `Готово`; родитель `SCRUM-968` независимо перепринят и
также переведён в `Готово`.
