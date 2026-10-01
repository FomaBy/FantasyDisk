#!/usr/bin/env python3
"""FAN-3994: sanitize the raw build_release.sh log for evidence.

Collapses the export's per-file "Storing File" lines to a count and replaces
the signing identity name, the team ID, the Apple ID and the notary
submission JSON's account fields with placeholders. Prints the counts so the
README can cite them.

Usage: sanitize_build_log.py <raw.log> <sanitized.log>
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def main() -> int:
    raw = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    out = Path(sys.argv[2])
    identity = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"], capture_output=True, text=True, check=True
    ).stdout
    match = re.search(r'"Developer ID Application: ([^"(]+) \(([A-Z0-9]+)\)"', identity)
    name, team = (match.group(1).strip(), match.group(2)) if match else ("", "")
    raw_lines = raw.replace("\r", "\n").split("\n")
    kept: list[str] = []
    storing = 0
    for line in raw_lines:
        if "Storing File:" in line or line.startswith("Updating files:"):
            storing += 1
            continue
        kept.append(line)
    text = "\n".join(kept)
    text = re.sub(r"Updating files:.*?done\.", "Updating files: <collapsed>", text)
    if name:
        text = text.replace(name, "<signing identity name>")
    if team:
        text = text.replace(team, "<team id>")
    text = re.sub(r'"?[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"?', "<apple id>", text)
    text = re.sub(r"Authority=Developer ID Application: .*", "Authority=Developer ID Application: <redacted>", text)
    header = (
        f"# sanitized build log: {len(raw_lines)} raw lines, {storing} 'Storing File'/'Updating files' lines collapsed; "
        "signing identity, team ID and Apple ID replaced with placeholders\n"
    )
    out.write_text(header + text, encoding="utf-8")
    leaks = [s for s in (name, team) if s and s in text]
    print(f"raw lines {len(raw_lines)}, collapsed {storing}, kept {len(kept)}, leaks {leaks}")
    return 1 if leaks else 0


if __name__ == "__main__":
    raise SystemExit(main())
