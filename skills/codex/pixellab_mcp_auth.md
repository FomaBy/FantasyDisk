# PixelLab MCP Auth Runbook

Use this before declaring any FantasyDisk PixelLab task blocked by MCP auth.

## Current Codex Desktop Config

PixelLab is configured in `~/.codex/config.toml`, not in the repository. Never
copy the bearer token into Jira, task files, commits, prompts, or logs.

Expected shape:

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

The `PATH` line matters: Codex's bundled `npx` may fail with
`env: node: No such file or directory` unless the bundled `node` directory is in
the MCP server environment.

## Do Not Create False Blockers

- `tool_search pixellab` returning zero tools in an already-open thread does not
  prove PixelLab is down. MCP tool namespaces may be stale until a fresh thread
  or app/server restart.
- Missing shell environment variable `AUTH_HEADER` does not prove auth is broken.
  The value is supplied from `[mcp_servers.pixellab.env]`.
- Before adding `blocked` / `pixellab-blocked`, run a post-fix config-based
  bridge check. Only block if that check fails.

## Safe Smoke Check

From the FantasyDisk repo or any shell, run without printing the token:

```bash
AUTH_HEADER=$(perl -ne 'print $1 if /^AUTH_HEADER\s*=\s*"([^"]+)"/' "$HOME/.codex/config.toml")
PIXELLAB_PATH=$(perl -ne 'print $1 if /^PATH\s*=\s*"([^"]+)"/' "$HOME/.codex/config.toml")
curl -sS -X POST "https://api.pixellab.ai/mcp" \
  -H "Authorization: $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_balance","arguments":{}}}'
```

Success looks like a JSON-RPC result with `isError: false`. A full bridge smoke
may use:

```bash
PATH="$PIXELLAB_PATH" /Applications/Codex.app/Contents/Resources/cua_node/bin/npx \
  mcp-remote@latest https://api.pixellab.ai/mcp \
  --transport http-only \
  --header "Authorization:${AUTH_HEADER}"
```

If you capture logs, redact any `Bearer ...` value before storing or pasting.

## Task Handling

- If direct PixelLab tools are exposed, use them normally.
- If direct tools are stale but the config-based bridge succeeds, either use the
  local JSON-RPC bridge for read/create/fetch calls or move the work to a fresh
  Codex thread where MCP discovery can reload. Do not mark Jira blocked for the
  old auth issue.
- Record in Jira/task evidence: `PixelLab MCP config smoke PASS`, the tool used
  (`get_balance`, `tools/list`, `create_character`, etc.), and that no secrets
  were printed.
