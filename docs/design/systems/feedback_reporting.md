# In-Game Feedback Reporting

Обновлено: 2026-06-14 (0.1.5)

SCRUM-362 adds an in-game feedback and bug report tool. It is a Back-end/runtime system: no webhook secret is stored in the repository, and reports are sent only after explicit player confirmation.

## Player Flow

- `P` opens `FeedbackOverlayLayer` from combat, route map, shop, event, level-up, rewards, settings and menus.
- The tool captures the current viewport before the overlay appears, then shows that screenshot as a preview.
- The player writes a short report and presses `Отправить`.
- `Esc` or `Отмена` closes the overlay without sending.
- While the overlay is open, normal gameplay/menu shortcuts are blocked except Escape, but text input remains available inside `FeedbackTextEdit`.

## Delivery

`scripts/feedback_reporter.gd` sends Discord-compatible multipart payloads through `HTTPRequest`:

- `payload_json.content` contains the player text plus runtime metadata.
- `files[0]` contains `fantasydisk_feedback.png`.

Webhook URL lookup order:

1. Environment variable `FANTASYDISK_FEEDBACK_WEBHOOK`.
2. `user://feedback_config.cfg`, section `[feedback]`, key `webhook_url`.

Example local config:

```ini
[feedback]
webhook_url="https://discord.com/api/webhooks/..."
```

The project must never commit a real webhook URL. On macOS, `user://` normally resolves under the app data folder managed by Godot, not inside the repository.

## Local Fallback

If no webhook URL is configured, or if a send fails, the report is saved locally:

```text
user://feedback/<timestamp>/report.txt
user://feedback/<timestamp>/screenshot.png
```

`report.txt` includes the player's text and metadata such as version, screen, route stage, character, weapon, node type, combat state, viewport size and timestamp.

## Headless And Tests

Headless runs cannot read a real viewport screenshot, so the overlay uses a small fallback screenshot image. `tests/runtime_smoke_test.gd` verifies:

- the `feedback` InputMap action exists and defaults to `P`;
- the overlay opens and closes;
- screenshot preview texture exists;
- local fallback writes `report.txt` and `screenshot.png`;
- multipart payload contains `payload_json` and `fantasydisk_feedback.png`.
