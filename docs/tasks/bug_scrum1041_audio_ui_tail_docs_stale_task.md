# BUG: Audio docs still mark landed UI/Credits tail as deferred

Статус: new
Приоритет: normal
Роль: Back-end / Documentation
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Jira: SCRUM-1041
Версия: 0.2.1
Найдено QA при тестировании: SCRUM-968
Locked paths: `docs/design/systems/audio.md`;
`docs/design/current_game_state.md`; this mirror only

## Контекст

Runtime SCRUM-968 UI tail уже landed в `scripts/ui_screens.gd`: purchase и
ui_error подключены к покупкам/отказам, ui_click/ui_back — через общий helper,
artifact_reveal используется для трёх reward/reveal точек, а Main Menu ведёт на
player-facing Credits screen. Независимая функциональная QA этих сценариев
зелёная.

Два authoritative документа всё ещё говорят, что эти вызовы «отложены», и
ссылаются на удалённый `docs/tasks/SCRUM-968_ui_screens_tail.md`:

- `docs/design/systems/audio.md` (summary и Current state / SFX);
- `docs/design/current_game_state.md` (раздел «Звук»).

## Acceptance Criteria

- [ ] Оба документа описывают landed purchase/ui_error/ui_click/ui_back/
      artifact_reveal call sites и Credits screen.
- [ ] Все ссылки/формулировки про удалённый deferred tail убраны.
- [ ] Runtime code, tests и assets не меняются.
- [ ] Reference/link grep и релевантный docs/runtime smoke проходят.
- [ ] Результат закоммичен и запушен в `origin/dev`, затем передан QA.

## QA routing

SCRUM-968 функционально PASSED, но остаётся в `Контроль качества` только до
исправления этого documentation child. Jira issue создан первым; локальный файл
— spec/evidence mirror.
