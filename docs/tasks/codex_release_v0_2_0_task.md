# Задача Для Release-Агента: FantasyDisk v0.2.0 — релиз, сборки и публикация

Статус: done
Jira: SCRUM-843
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

- [x] `project.godot::config/version` соответствует `0.2.0`.
- [x] `CHANGELOG.md` содержит секцию `0.2.0` с пользовательскими highlights и новой пустой `Unreleased`.
- [x] `scripts/patch_notes_data.gd` содержит запись `0.2.0` первой в списке.
- [x] Релизная картинка создана с content-zone evidence и сохранена в `assets/marketing/`.
- [x] Префлайт smoke tests зелёные.
- [x] В `dev` есть release commit, `main` содержит merge release, тег `v0.2.0` создан и запушен.
- [x] `releases/v0.2.0/` содержит DMG, Windows setup EXE, Windows ZIP, SHA256SUMS и changelog snapshot.
- [x] Discord/Telegram publication выполнена.
- [x] Disk cleanup выполнен.

## Progress

- 2026-07-02: задача взята в работу через `fantasydisk-release-director`; релиз ведётся в чистом worktree `/tmp/FantasyDisk-release-020` от `origin/dev`.
- 2026-07-02: `CHANGELOG.md` закрыт в секцию `0.2.0`, `scripts/patch_notes_data.gd` получил внутриигровые patch notes `0.2.0`.
- 2026-07-02: релизная картинка создана: `assets/marketing/fantasydisk_020_announcement_telegram_discord.png`; content-zone report `docs/design/previews/release_0_2_0/release_0_2_0_report.json` вернул `ok: true`.
- 2026-07-02: preflight PASS через `python3 tools/godot_gate.py`: `runtime_smoke_test.gd`, `runtime_smoke_ui_test.gd`, `runtime_smoke_combat_test.gd`, `runtime_smoke_progression_economy_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_boss_elite_test.gd`, `patch_notes_data_smoke_test.gd`; forbidden log markers не найдены, `git diff --check` PASS.
- 2026-07-02: release commit `2b5af705 release: prepare FantasyDisk 0.2.0` запушен в `origin/dev`.
- 2026-07-02: `origin/main` получил merge commit `8fe46c14 Release v0.2.0`; annotated tag `v0.2.0` создан и запушен.
- 2026-07-02: `tools/build_release.sh 0.2.0` собрал `FantasyDisk-0.2.0-macos.dmg`, `FantasyDisk-0.2.0-windows-setup.exe`, `FantasyDisk-0.2.0-windows.zip`, `SHA256SUMS.txt`; добавлены `CHANGELOG-0.2.0.md` и релизный PNG рядом с артефактами.
- 2026-07-02: build verification PASS: `shasum -a 256 -c SHA256SUMS.txt`, `unzip -tq FantasyDisk-0.2.0-windows.zip`, `hdiutil verify FantasyDisk-0.2.0-macos.dmg`, DMG mount check `FantasyDisk.app` with `CFBundleShortVersionString=0.2.0` and `CFBundleVersion=0.2.0`.
- 2026-07-02: релизные артефакты сохранены локально в `/Users/sergeyfomin/Documents/AI Agent/releases/v0.2.0/`.
- 2026-07-02: Telegram publication PASS: релизный постер опубликован, затем загружены DMG, Windows setup EXE, Windows ZIP и `SHA256SUMS.txt`.
- 2026-07-02: Discord publication PASS: `release_publish.py --version 0.2.0` вернул `Discord: 200`, релизный постер также опубликован через release webhook.
- 2026-07-02: Disk cleanup: disposable build worktree removed by `tools/build_release.sh`; final runner cleanup removes `/tmp/FantasyDisk-release-020-main`, `/tmp/FantasyDisk-release-020`, their `.godot` caches, and runs `git worktree prune` after this evidence commit/push.
- 2026-07-02: corrective rebuild started after user noted that initial `v0.2.0` artifacts were tag-based and missed newer local checkout state. Local dirty state was captured on source commit `1e71b7cb`, replayed onto fresh `origin/dev` as commit `88556899`, pushed to `origin/dev`, then merged to `origin/main` as `98dc48b8 Release v0.2.0 local rebuild correction`.
- 2026-07-02: corrective verification PASS on snapshot `88556899`: `runtime_smoke_test.gd`, `runtime_smoke_ui_test.gd`, `runtime_smoke_combat_test.gd`, `runtime_smoke_progression_economy_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_boss_elite_test.gd`, `patch_notes_data_smoke_test.gd`, `level_up_effect_duration_test.gd`, `level_up_toast_smoke_test.gd`, `meta40_atlas_screen_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`, `gamepad_combat_actions_test.gd`, `gamepad_full_flow_smoke_test.gd`; `git diff --check` PASS.
- 2026-07-02: corrective artifacts rebuilt manually from commit `98dc48b8` with `config/version=0.2.0` because `tools/build_release.sh 0.2.0` intentionally builds from the older `v0.2.0` tag. New `SHA256SUMS.txt`: macOS DMG `6b96a567f11a37a9f0efa9d477171b7b579cfc7efb20b4823c6a8877cfaf8163`; Windows setup EXE `3cf36f63050905aee2b9246e0fc3f5acafa48e6960e3161fe84011d581808fa6`; Windows ZIP `50e1c953ff8a7ee1f2811ebd5e57dd499e2d588f2e56c587f3819c7522c5c476`.
- 2026-07-02: corrective build verification PASS: `shasum -a 256 -c SHA256SUMS.txt`, `unzip -tq FantasyDisk-0.2.0-windows.zip`, `hdiutil verify FantasyDisk-0.2.0-macos.dmg`, mounted DMG contains `FantasyDisk.app` with `CFBundleShortVersionString=0.2.0` and `CFBundleVersion=0.2.0`.
- 2026-07-02: corrective Telegram re-upload PASS: verified the latest channel messages contain caption `исправленная пересборка ... snapshot 98dc48b8` and all four files: `FantasyDisk-0.2.0-macos.dmg`, `FantasyDisk-0.2.0-windows-setup.exe`, `FantasyDisk-0.2.0-windows.zip`, `SHA256SUMS.txt`.
- 2026-07-02: corrective artifacts saved locally in `/Users/sergeyfomin/Documents/AI Agent/releases/v0.2.0/`, replacing the previous tag-built files.

## QA-Вердикт

Статус: PASSED
Проверено: 2026-07-02

- Preflight smoke suite PASS.
- Release artifacts built and integrity-checked.
- macOS DMG mounts and contains `FantasyDisk.app` version `0.2.0`.
- Telegram and Discord publication completed; corrective Telegram file re-upload verified against channel messages.
