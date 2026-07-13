# In-Game Feedback Reporting

Обновлено: 2026-07-13 (FAN-1040 security review)

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
- `payload_json.attachments[0]` declares `id: 0` and filename
  `fantasydisk_feedback.jpg`, matching multipart part `files[0]`. Discord API
  v10 needs this explicit attachment reference when `payload_json` is present.
- `files[0]` contains a downscaled JPG upload copy; the local fallback keeps the
  full PNG screenshot.

Webhook URL lookup order:

1. Environment variable `FANTASYDISK_FEEDBACK_WEBHOOK` for dev/CI.
2. Local development-only `res://feedback_webhook.cfg`, section `[feedback]`,
   key `discord_webhook_url`. It is gitignored and excluded from player exports.
3. Legacy/player override `user://feedback_config.cfg`, section `[feedback]`, key
   `webhook_url`.

Example local config:

```ini
[feedback]
webhook_url="https://discord.com/api/webhooks/..."
```

The project must never commit, obfuscate, or export a real webhook URL. Base64
does not protect a credential in a client binary. Production delivery requires
a rate-limited server/proxy endpoint; until that exists, an unconfigured player
build saves the report locally. On macOS, `user://` normally resolves under the
app data folder managed by Godot, not inside the repository.
Runtime rejects blank, placeholder and non-Discord URLs as build/config errors;
the UI still saves a local fallback and never prints the URL.

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
- multipart payload contains `payload_json` and `fantasydisk_feedback.jpg`;
- `payload_json.attachments[0].filename` matches the `files[0]` multipart
  `Content-Disposition` filename, so Discord keeps the screenshot attachment.
- `tests/feedback_webhook_config_test.gd` rejects missing/placeholder/invalid
  webhook config without leaking the URL.

## Audit (SCRUM-720)

Security/persistence audit of the feedback path — no runtime behaviour changed,
findings + a regression guard:

- **Secrets never leak.** The optional development webhook URL lives only in memory
  (`_pending_webhook_url`) and is passed solely to `request_raw`. It is never
  `print`/`push_error`-logged, never written into `report.txt`, and never embedded
  in failure/config messages. The real `feedback_webhook.cfg` is gitignored
  (`*.cfg`) and untracked; only `feedback_webhook.cfg.example` (placeholder
  `XXXX/YYYY`) and fake test fixtures are committed.
- **Fallback stays out of the repo.** Local reports and the user webhook config
  live under `user://` (`LOCAL_ROOT`, `CONFIG_PATH`); the bundled config is a
  read-only `res://` resource generated at release from the secret. Guarded by
  `feedback_webhook_config_test.gd` (path-prefix asserts) so a regression like
  `LOCAL_ROOT → "res://feedback"` fails the gate instead of leaking player text/
  screenshots into the source tree.
- Resolution priority (env → local `res://` → user `user://`), retry/backoff and
  upload-size handling were reviewed and left as-is (already SCRUM-547/460-hardened).

## Security correction (FAN-1040)

The SCRUM-848 client-embedded Base64 fallback was removed. Obfuscation did not
prevent extracting and abusing the Discord credential, and the value remains in
Git history. The old webhook must be revoked in Discord. Any replacement must be
stored only in server/CI secret storage and must not be added to source or export.
