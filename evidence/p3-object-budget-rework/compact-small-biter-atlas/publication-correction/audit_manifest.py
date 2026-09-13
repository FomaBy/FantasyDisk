#!/usr/bin/env python3
"""FAN-3934: reproducible canonical-manifest audit.

Reads every manifest entry's blob from a Git COMMIT (never the working tree,
so local ignored/generated files cannot masquerade as delivered evidence) and
classifies each as MATCH / HASH-MISMATCH / ABSENT. Expected-failure
demonstration: auditing a deliberately altered entry list must report
HASH-MISMATCH and ABSENT.

Usage: python3 audit_manifest.py <manifest.md> <commit> [--self-test]
"""
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

ENTRY = re.compile(r"^- `?([^` ]+)`? `([0-9a-f]{64})`$")


def blob(commit: str, path: str) -> bytes | None:
    result = subprocess.run(["git", "cat-file", "blob", f"{commit}:{path}"],
                            capture_output=True)
    return result.stdout if result.returncode == 0 else None


def audit(manifest_text: str, commit: str) -> dict:
    entries = ENTRY.findall(manifest_text)
    match, mismatch, absent = [], [], []
    for path, digest in entries:
        data = blob(commit, path)
        if data is None:
            absent.append(path)
        elif hashlib.sha256(data).hexdigest() == digest:
            match.append(path)
        else:
            mismatch.append(path)
    return {"entries": len(entries), "match": match,
            "hash_mismatch": mismatch, "absent": absent}


def main() -> int:
    manifest_path, commit = sys.argv[1], sys.argv[2]
    text = Path(manifest_path).read_text(encoding="utf-8")
    result = audit(text, commit)
    print(f"audit of {manifest_path} at {commit}: "
          f"{len(result['match'])}/{result['entries']} match, "
          f"{len(result['hash_mismatch'])} mismatched, {len(result['absent'])} absent")
    if "--self-test" in sys.argv[3:]:
        # Expected-failure demonstration: corrupt one digest and drop one path.
        lines = text.splitlines()
        changed = False
        for i, line in enumerate(lines):
            m = ENTRY.match(line)
            if m and not changed:
                first = m.group(2)
                lines[i] = line.replace(first, "0" * 64)
                changed = True
        probe = audit("\n".join(lines) + "\n- does/not/exist.txt " + " " * 0 + "`" + "1" * 64 + "`", commit)
        expect_mismatch = len(probe["hash_mismatch"]) >= 1
        expect_absent = len(probe["absent"]) >= 1
        print(f"self-test: mismatch-detected={expect_mismatch} absent-detected={expect_absent}")
        return 0 if (expect_mismatch and expect_absent) else 1
    return 0 if not (result["hash_mismatch"] or result["absent"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
