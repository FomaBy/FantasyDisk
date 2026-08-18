#!/usr/bin/env python3
"""One-off fetch of a completed PixelLab character as raw JSON (FAN-2610)."""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
from pathlib import Path

DEFAULT_URL = "https://api.pixellab.ai/mcp"


def read_auth_header(config_path: Path) -> str:
    auth_header = os.environ.get("AUTH_HEADER", "").strip()
    if auth_header:
        return auth_header
    bearer_token = os.environ.get("PIXELLAB_BEARER_TOKEN", "").strip()
    if bearer_token:
        return f"Bearer {bearer_token}"
    text = config_path.read_text(encoding="utf-8", errors="replace")
    match = re.search(r'^\s*AUTH_HEADER\s*=\s*"([^"]+)"\s*$', text, re.M)
    if match:
        return match.group(1).strip()
    raise RuntimeError("no auth header found")


def main() -> int:
    character_id = sys.argv[1]
    out_path = Path(sys.argv[2])
    auth_header = read_auth_header(Path.home() / ".codex" / "config.toml")
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": "get_character", "arguments": {"character_id": character_id, "include_preview": False}},
    }
    request = urllib.request.Request(
        DEFAULT_URL,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": auth_header,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read().decode("utf-8", errors="replace")
    out_path.write_text(body, encoding="utf-8")
    print(f"wrote {out_path} ({len(body)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
