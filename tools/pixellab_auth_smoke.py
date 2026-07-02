#!/usr/bin/env python3
"""Safe PixelLab auth smoke test.

The script reads auth from AUTH_HEADER, PIXELLAB_BEARER_TOKEN, or
~/.codex/config.toml and calls get_balance without printing the token.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request


DEFAULT_URL = "https://api.pixellab.ai/mcp"


def redact(text: str) -> str:
    text = re.sub(r"Bearer\s+[A-Za-z0-9._~+/=-]+", "Bearer <REDACTED>", text, flags=re.I)
    text = re.sub(r"(Authorization\s*[:=]\s*)([^\s,;]+)", r"\1<REDACTED>", text, flags=re.I)
    return text


def read_auth_header(config_path: Path) -> str | None:
    auth_header = os.environ.get("AUTH_HEADER", "").strip()
    if auth_header:
        return auth_header

    bearer_token = os.environ.get("PIXELLAB_BEARER_TOKEN", "").strip()
    if bearer_token:
        return f"Bearer {bearer_token}"

    if not config_path.exists():
        return None

    text = config_path.read_text(encoding="utf-8", errors="replace")
    match = re.search(r'^\s*AUTH_HEADER\s*=\s*"([^"]+)"\s*$', text, re.M)
    if match:
        return match.group(1).strip()
    return None


def call_get_balance(api_url: str, auth_header: str, timeout: float) -> tuple[int, str]:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": "get_balance", "arguments": {}},
    }
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        api_url,
        data=body,
        method="POST",
        headers={
            "Authorization": auth_header,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.status, response.read().decode("utf-8", errors="replace")


def looks_successful(response_text: str) -> bool:
    lowered = response_text.lower()
    if '"error"' in lowered and '"iserror":false' not in lowered:
        return False
    return '"result"' in lowered or '"iserror":false' in lowered


def main() -> int:
    parser = argparse.ArgumentParser(description="Check PixelLab MCP auth without printing secrets.")
    parser.add_argument("--api-url", default=DEFAULT_URL)
    parser.add_argument("--config", default=str(Path.home() / ".codex" / "config.toml"))
    parser.add_argument("--timeout", type=float, default=30.0)
    args = parser.parse_args()

    auth_header = read_auth_header(Path(args.config).expanduser())
    if not auth_header:
        print(
            "PixelLab auth smoke FAIL: no AUTH_HEADER, PIXELLAB_BEARER_TOKEN, "
            "or AUTH_HEADER in ~/.codex/config.toml.",
            file=sys.stderr,
        )
        return 2

    if not auth_header.lower().startswith("bearer "):
        print("PixelLab auth smoke FAIL: auth header must start with 'Bearer '.", file=sys.stderr)
        return 2

    try:
        status, response_text = call_get_balance(args.api_url, auth_header, args.timeout)
    except urllib.error.HTTPError as exc:
        error_text = exc.read().decode("utf-8", errors="replace")
        print(f"PixelLab auth smoke FAIL: HTTP {exc.code}: {redact(error_text)[:600]}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001 - smoke script should report all failures clearly.
        print(f"PixelLab auth smoke FAIL: {type(exc).__name__}: {redact(str(exc))}", file=sys.stderr)
        return 1

    if status == 200 and looks_successful(response_text):
        print("PixelLab auth smoke PASS: get_balance returned a JSON-RPC result.")
        return 0

    print(
        f"PixelLab auth smoke FAIL: HTTP {status}: {redact(response_text)[:600]}",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
