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
`skills/codex/pixellab_mcp_auth.md` before marking a Jira issue blocked.
