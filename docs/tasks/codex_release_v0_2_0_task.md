# Задача Для Release-Агента: FantasyDisk v0.2.0 — релиз, сборки и публикация

Статус: in_progress
Версия: 0.2.0
Создано: 2026-07-02
Автор: User / Codex release director
Роль: Release
Исполнитель: Codex
Контур: Codex
Owner: Codex release control thread
Locked paths: `project.godot`, `export_presets.cfg`, `CHANGELOG.md`, `scripts/patch_notes_data.gd`, `docs/design/current_game_state.md`, `docs/tasks/codex_release_v0_2_0_task.md`, `assets/marketing/`, `docs/design/mockups/release_0_2_0/`, `docs/design/previews/release_0_2_0/`, `releases/v0.2.0/`

## Цель

Подготовить и опубликовать полный релиз FantasyDisk `v0.2.0`:

- обновить человекочитаемый `CHANGELOG.md`;
- обновить внутриигровые patch notes «Что нового»;
- подготовить релизную картинку для Telegram/Discord;
- собрать macOS DMG, Windows setup EXE и Windows ZIP;
- слить `dev` в `main`, поставить тег `v0.2.0`;
- опубликовать релизную новость в Telegram и Discord обычным release-flow.

## Acceptance Criteria

- [ ] `project.godot::config/version` соответствует `0.2.0`.
- [ ] `CHANGELOG.md` содержит секцию `0.2.0` с пользовательскими highlights и новой пустой `Unreleased`.
- [ ] `scripts/patch_notes_data.gd` содержит запись `0.2.0` первой в списке.
- [ ] Релизная картинка создана с content-zone evidence и сохранена в `assets/marketing/`.
- [ ] Префлайт smoke tests зелёные.
- [ ] В `dev` есть release commit, `main` содержит merge release, тег `v0.2.0` создан и запушен.
- [ ] `releases/v0.2.0/` содержит DMG, Windows setup EXE, Windows ZIP, SHA256SUMS и changelog snapshot.
- [ ] Discord/Telegram publication выполнена или blocker записан с точной причиной.
- [ ] Disk cleanup выполнен.

## Progress

- 2026-07-02: задача взята в работу через `fantasydisk-release-director`; релиз ведётся в чистом worktree `/tmp/FantasyDisk-release-020` от `origin/dev`.
- 2026-07-02: `CHANGELOG.md` закрыт в секцию `0.2.0`, `scripts/patch_notes_data.gd` получил внутриигровые patch notes `0.2.0`.
- 2026-07-02: релизная картинка создана: `assets/marketing/fantasydisk_020_announcement_telegram_discord.png`; content-zone report `docs/design/previews/release_0_2_0/release_0_2_0_report.json` вернул `ok: true`.
- 2026-07-02: preflight PASS через `python3 tools/godot_gate.py`: `runtime_smoke_test.gd`, `runtime_smoke_ui_test.gd`, `runtime_smoke_combat_test.gd`, `runtime_smoke_progression_economy_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_boss_elite_test.gd`, `patch_notes_data_smoke_test.gd`; forbidden log markers не найдены, `git diff --check` PASS.
