# Refactor Wave: Settings, Audio, Feedback And Input Persistence

Jira: SCRUM-720
Статус: done
Приоритет: P2
Роль: Back-end / settings quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-settings, area-audio, area-feedback
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task covers non-visual settings, audio, feedback and input persistence helpers. It must not expose secrets or alter UI layout.

## Scope / Locked Paths

- `scripts/game_settings.gd`
- `scripts/display_resolution.gd`
- `scripts/audio_manager.gd`
- `scripts/feedback_reporter.gd`
- Settings/audio/feedback tests
- `docs/design/systems/persistence.md`
- `docs/design/systems/audio.md`
- `docs/design/systems/feedback_reporting.md`

## Required Change

Audit and safely refactor settings/audio/feedback helpers: config schema, HiDPI/window resolution helpers, input bindings, audio bus setup, mute/volume persistence, feedback webhook fallback/retry/size handling and no-secret logging. Do not expose tokens or webhook values.

## Acceptance Criteria

- Settings/audio/feedback audit is recorded.
- Save/config compatibility is preserved.
- Feedback fallback never prints or stores secrets in repo files.
- Audio and display settings still apply immediately where expected.
- Focused tests cover changed behavior.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/game_settings_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/display_resolution_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/audio_manager_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/feedback_webhook_config_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
