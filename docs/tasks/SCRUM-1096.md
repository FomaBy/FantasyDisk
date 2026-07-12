# SCRUM-1096 — Release FantasyDisk v0.2.1

Jira: SCRUM-1096
Статус: done
Контур: Codex
Owner: /root
Thread/Worker: release-v0.2.1 controller

## Scope

- Подготовить только пользовательские release notes для версии 0.2.1.
- Синхронизировать версию игры и внутриигровой экран «Что нового».
- Пройти обязательный релизный green-gate.
- Собрать и проверить macOS/Windows артефакты.
- Опубликовать файлы и текст в Telegram, текст и ссылку на сборки в Discord.

## Locked paths

- `project.godot`
- `export_presets.cfg`
- `CHANGELOG.md`
- `scripts/patch_notes_data.gd`
- `tests/runtime_smoke_test.gd`
- `docs/design/current_game_state.md`
- `docs/tasks/SCRUM-1096.md`
- `releases/v0.2.1/**`

## Result

- Пользовательские release notes добавлены в `CHANGELOG.md`, внутриигровой
  экран «Что нового» и релизный комплект; внутренних ID, QA-процесса и
  технического жаргона в текстах для игроков нет.
- Release preparation: `87f1357c7`, запушен в `origin/dev`.
- Release merge: `0b20b0532`, запушен в `origin/main`.
- Аннотированный тег: `v0.2.1` → `0b20b0532`.
- Green-gate: PASS — patch notes, umbrella runtime, UI, combat,
  progression/economy, weapon mechanics, boss/elite.
- Независимый artifact QA: PASS — SHA-256, ZIP integrity, DMG integrity,
  bundle version `0.2.1`, tag/version consistency, user-only notes.
- Telegram: опубликованы macOS DMG, Windows setup EXE, Windows ZIP,
  `RELEASE_NOTES-0.2.1.txt` и `SHA256SUMS.txt`.
- Discord: пользовательская новость и ссылка на Telegram опубликованы,
  webhook вернул HTTP 200.
- Артефакты сохранены в `releases/v0.2.1/` основного checkout.
- Disk cleanup: build temp worktree/cache и временный main merge worktree
  удалены; release controller worktree удаляется сразу после push этого mirror.
- Thread cleanup: not a disposable worker thread.
