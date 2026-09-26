# PixelLab Pull Setup

This runbook makes the FantasyDisk PixelLab workflow reproducible from git
without committing secrets.

## What is committed

- `skills/codex/fantasydisk-pixellab-animation-integrator/`
- `skills/codex/content-zone-image-compositor/`
- `skills/codex/fantasydisk-ui-director/`
- `skills/codex/fantasydisk-asset-generator/`
- `skills/codex/fantasydisk-item-icon-generator/`
- `skills/codex/pixellab_mcp_auth.md`
- `tools/pixellab_auth_smoke.py`
- `tools/pixellab.env.example`
- `docs/design/references/pixellab_inventory_2026-07-01.md`

## What is not committed

Do not commit a PixelLab bearer token, `Authorization` header, or raw
`~/.codex/config.toml` with secrets. Store the token in local environment,
macOS Keychain, a password manager, or GitHub Actions secrets.

## Restore skills after pull

From the repo root:

```bash
mkdir -p "$HOME/.codex/skills"
rsync -a skills/codex/fantasydisk-pixellab-animation-integrator/ "$HOME/.codex/skills/fantasydisk-pixellab-animation-integrator/"
rsync -a skills/codex/content-zone-image-compositor/ "$HOME/.codex/skills/content-zone-image-compositor/"
rsync -a skills/codex/fantasydisk-ui-director/ "$HOME/.codex/skills/fantasydisk-ui-director/"
rsync -a skills/codex/fantasydisk-asset-generator/ "$HOME/.codex/skills/fantasydisk-asset-generator/"
rsync -a skills/codex/fantasydisk-item-icon-generator/ "$HOME/.codex/skills/fantasydisk-item-icon-generator/"
rsync -a skills/codex/pixellab_mcp_auth.md "$HOME/.codex/skills/pixellab_mcp_auth.md"
```

## Configure auth locally

Use one of these local-only options.

Environment:

```bash
cp tools/pixellab.env.example .env
# Fill PIXELLAB_BEARER_TOKEN in .env, then:
set -a
source .env
set +a
export AUTH_HEADER="Bearer ${PIXELLAB_BEARER_TOKEN}"
```

macOS Keychain:

```bash
security add-generic-password -a "$USER" -s fantasydisk-pixellab-bearer -w "<token>"
export AUTH_HEADER="Bearer $(security find-generic-password -a "$USER" -s fantasydisk-pixellab-bearer -w)"
```

Codex Desktop MCP config:

```toml
[mcp_servers.pixellab]
command = "/Applications/Codex.app/Contents/Resources/cua_node/bin/npx"
args = [
  "mcp-remote@latest",
  "https://api.pixellab.ai/mcp",
  "--transport",
  "http-only",
  "--header",
  "Authorization:${AUTH_HEADER}"
]

[mcp_servers.pixellab.env]
AUTH_HEADER = "Bearer <secret>"
PATH = "/Applications/Codex.app/Contents/Resources/cua_node/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

The config file belongs in `~/.codex/config.toml`, not in the repository.

## Verify access

```bash
python3 tools/pixellab_auth_smoke.py
```

Expected success:

```text
PixelLab auth smoke PASS: get_balance returned a JSON-RPC result.
```

The smoke script never prints the token. If it fails, follow
`skills/codex/pixellab_mcp_auth.md` before marking a Multica issue blocked.

## Blocking pack generation (FAN-2924, mandatory for agents)

`tools/pixellab_generate_pack.py` runs the whole generation cycle — create job,
poll status synchronously to completion, download frames, write the provenance
manifest — as ONE blocking command. Pixel Artist agents MUST use it for pack
generation; polling the PixelLab MCP by hand with a self-armed timer is
forbidden (three orphaned runs: FAN-2608 ×2, FAN-2645).

```bash
python3 tools/pixellab_generate_pack.py \
  --source-dir <raw frames dir> \
  --manifest-out <manifest.json> \
  --description "<object description>" \
  --animation-description "<animation description>" \
  --frame-count 16
```

Key flags: `--poll-interval` seconds between status polls (default 30),
`--timeout` hard wall-clock ceiling per job in seconds (default 900 = 15 min),
`--object-id` to reuse an existing object, `--frame-prefix`, `--size`,
`--view`, `--animate-mode`.

Exit codes: `0` success; `3` timeout (the unfinished object id and its status
are printed); `4` API error (create/animate/download failure, JSON-RPC error);
`5` incomplete pack (fewer frames downloaded than `--frame-count`). On a
non-zero exit, the delivery agent MUST stop the current run and hand the issue
off as blocked. Do not sleep, poll manually, or finish the turn while the issue
is still `in_progress`, and do not promise a later report. Capture the complete
redacted output first; when the service provides them, it contains the
object/job id and the last reported status.
Then use the issue id from the current assignment and post the evidence before
leaving the run:

```bash
multica issue status <FAN-issue-id> blocked --no-start
multica issue comment add <FAN-issue-id> --content-file ./pixellab-failure.md
```

The comment must include the exact command, exit code, object/job id (or
`unavailable` when the output provides none), last status, and the unblock
condition. A timeout may be retried with `--object-id <id from the log>` and a
larger `--timeout` only in a newly dispatched run; never retry it silently in
the failed run. Exit codes `4` and `5` are reported as-is and are not converted
into success.

The token comes only from env `PIXELLAB_BEARER_TOKEN`; it is never printed,
written to the manifest, or committed. Import of a downloaded pack into
runtime assets stays with `tools/update_pixellab_character_animations.py`.
Mocked no-network self-test: `python3 tools/test_pixellab_generate_pack.py`.

## Orphaned-run sweep evidence (sanitized)

The mandatory first-step sweep was recorded as shipped in the PM instructions
at `2026-08-18T03:57:00Z`. Its enabled schedule trigger was `*/20 * * * *`
(Europe/Vilnius), so the 20-minute bound below is measured against the observed
death, not against a guessed completion time. The records contain no tokens,
headers, or raw service output.

| Case | First-hand observation | Result |
| --- | --- | --- |
| Real orphan, `FAN-3089` | Task `c625ca94-1ed7-4a52-9951-78f15a6c85b1` completed at `2026-08-19T05:45:20Z` with `status=completed`, no error, and a background-and-yield wait statement. The agent was idle with no active task. | The sweep released the card at `2026-08-19T05:58:40Z` — `13m20s` after measured death, within one 20-minute cycle. Remote inspection found no work-in-progress commit; the card was authorized for a clean relaunch. Source: Multica comment `1a245a65-7db3-469a-bd5a-fcee9f5348b2`. |
| Live run protected, `FAN-3099` | PM sweep run `3efe588e-61ac-4e30-ae17-726a7cb724e1` recorded the card as `status=running` and explicitly left it untouched. | The run completed on its own at `2026-08-19T06:05:22Z`; delivery comment `a175521a-cbdc-4603-b25d-dfd086847275`, posted at `2026-08-19T06:05:14Z`, confirms the normal handoff. No orphan-release metadata was written. |

These observations are reproducible through the Multica records named above:
measure the agent task state, compare the issue's `updated_at` to the UTC
cutoff, inspect the latest comment, and verify the release order and final card
state. A live run is never released merely because another card is stale.
