# SCRUM-665: Feedback Webhook In Player Builds

Статус: review
Контур: Codex
Owner: Backend/Codex
Thread: backend_665_restart_codex
Locked paths: scripts/feedback_reporter.gd; tools/build_release.sh; tests/feedback_webhook_config_test.gd; docs/feedback_webhook_setup.md; docs/design/systems/feedback_reporting.md; docs/design/current_game_state.md
Jira: SCRUM-665

## Result
Player builds now get feedback webhook config through release packaging without committing the secret: `tools/build_release.sh` copies ignored `feedback_webhook.cfg` or generates it from `FANTASYDISK_FEEDBACK_WEBHOOK`, and fails release export if neither exists. Runtime rejects missing, placeholder, or non-Discord URLs as clear build/config errors, keeps local fallback, and only reports success after webhook HTTP success.

## Verification
- `tests/feedback_webhook_config_test.gd`
- `tests/feedback_retry_policy_test.gd`
- `tests/feedback_upload_size_test.gd`
- secret/static scan for Discord webhook placeholders only
