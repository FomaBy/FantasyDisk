# SCRUM-833: Process: switch active release planning to 0.2.0

Jira: SCRUM-833
Версия: 0.2.0
Статус: done
Роль: PM/process
Контур: Codex
Owner: Codex process worker
Thread/Worker: current Codex desktop thread
Locked paths: `project.godot`, `export_presets.cfg`, `AGENTS.md`, `CHANGELOG.md`, `docs/process/*` version/Jira/PM docs, `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `docs/design/systems/technical_architecture.md`, `tests/patch_notes_data_smoke_test.gd`, Jira sprint/version/fixVersion metadata

## Контекст

Пользователь 2026-07-02 зафиксировал новую линию планирования: текущая версия
FantasyDisk должна стать `0.2.0`, потому что релиз будет включать новый редизайн
персонажей. Плановые `0.1.8` и `0.1.9` отменены/superseded; после `0.2.0`
следующая SemVer patch-линия идёт как `0.2.1`, `0.2.2`, ...

Релизный flow пока не начинать: без freeze, build, tag, merge в `main` или
публикации.

## Требования

- Обновить runtime version source: `project.godot` и export presets до `0.2.0`.
- Обновить process/onboarding docs для Codex, Claude, QA и dispatcher.
- Перенацелить active local mirrors с `0.1.8` на `0.2.0`.
- Синхронизировать Jira: active sprint, Jira Version, fixVersions и process issue.
- Явно записать, что `0.1.8` и `0.1.9` больше не используются как плановые версии.
- Не запускать релизный flow.

## Acceptance Criteria

- [x] `project.godot` `application/config/version` = `0.2.0`.
- [x] `export_presets.cfg` macOS/Windows version fields = `0.2.0` / `0.2.0.0`.
- [x] Jira active sprint = `Спринт 0.2.0`.
- [x] Jira Version `0.2.0` is the active unreleased target; Jira Version `0.1.8`
  is superseded/archived or otherwise unavailable for new planning.
- [x] Existing active-scope `fixVersion = 0.1.8` assignments are moved to `0.2.0`.
- [x] Agent-facing process docs say `0.1.8`/`0.1.9` are skipped and next patches are
  `0.2.1`, `0.2.2`, ...
- [x] Verification evidence is recorded; release build/publish flow was not started.

## Результат

2026-07-02 Codex:

- `project.godot` bumped to `config/version="0.2.0"`.
- `export_presets.cfg` synced: macOS `short_version/version=0.2.0`, Windows
  `file_version=0.2.0.0`, `product_version=0.2.0`.
- Jira active sprint id `166` renamed to `Спринт 0.2.0`; sprint goal records
  `0.1.8/0.1.9` as skipped/superseded.
- Jira Version `0.2.0` updated as active unreleased target; Jira Version `0.1.8`
  archived with superseded note.
- Jira bulk fixVersion migration: `128` issues moved from `0.1.8` to `0.2.0`;
  post-check found `0` remaining `fixVersion=0.1.8` issues.
- Agent-facing docs updated: `AGENTS.md`, `docs/process/versioning_and_branching.md`,
  `docs/process/task_board.md`, `docs/process/jira_sync.md`, `docs/process/pm_workflow.md`,
  `docs/process/agent_role_boundaries_and_handoffs.md`, `docs/process/release_versioning.md`.
- Runtime/design references updated: `docs/design/current_game_state.md`,
  `docs/design/content_registry.md`, `docs/design/systems/technical_architecture.md`,
  active `docs/tasks/*` mirrors that had `Версия: 0.1.8` / `Спринт: 0.1.8`.
- Codex `Back` and `QA Claude` threads notified via `send_message_to_thread`; Claude/other
  workers are notified through Jira sprint/fixVersion state and process docs.
- Release flow was not started: no freeze, release build, tag, `main` merge, or publication.

Verification:

- `python3 tools/godot_gate.py --headless --path . --script res://tests/patch_notes_data_smoke_test.gd` — PASS.
- `python3 tests/test_jira_board_sync.py` — PASS.
- `git diff --check -- AGENTS.md CHANGELOG.md docs/process docs/design docs/tasks tests project.godot export_presets.cfg` — PASS.
- Jira post-check — active sprint `Спринт 0.2.0`, Version `0.2.0` active/unreleased,
  Version `0.1.8` archived, `fixVersion=0.1.8` remaining: `0`.

Disk cleanup: none created.
Thread cleanup: not a disposable worker thread.

## QA-Вердикт: PASSED

Статус: done

2026-07-02 claude-qa — приёмка на committed HEAD `origin/dev c8cc231b` (рабочее
дерево грязное из-за живого Godot-редактора, verify по коммиту + live Jira):

- `project.godot` `config/version="0.2.0"` — PASS.
- `export_presets.cfg`: macOS `short_version/version=0.2.0`, Windows
  `file_version=0.2.0.0`, `product_version=0.2.0` — PASS.
- Jira active sprint id `166` = `Спринт 0.2.0` — PASS.
- Jira Version `0.2.0` unreleased + not-archived (active target); Version `0.1.8`
  archived — PASS.
- `fixVersion=0.1.8` remaining: `0` (migrated to `0.2.0`) — PASS.
- Docs `AGENTS.md`, `docs/process/release_versioning.md`,
  `docs/process/versioning_and_branching.md` фиксируют `0.1.8`/`0.1.9` как
  skipped/superseded, next patch-линия `0.2.1`/`0.2.2` — PASS.
- Нет stale `Версия/Спринт: 0.1.8` в active design/task docs — PASS.
- `python3 tests/test_jira_board_sync.py` — PASS (4/4).
- Release flow не запускался (ветка dev, без tag/main-merge/publication) — PASS.

Godot-смоук не гонялся из-за живого редактора (single-instance коллизия);
изменение — version-string + docs + Jira metadata, runtime не затронут;
патч-нотес smoke уже PASS у исполнителя, board_sync test независимо PASS.
