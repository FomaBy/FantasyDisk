#!/usr/bin/env python3
"""Enforce future-only LFS storage for changed design binaries."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Sequence


MIB = 1024 * 1024
LEGACY_LIMIT = MIB
LEGACY_AGGREGATE_LIMIT = 5 * MIB
FUTURE_PREFIX = "docs/design/reference-assets-lfs/"
LEGACY_PREFIXES = (
    "docs/design/references/",
    "docs/design/previews/",
    "docs/design/mockups/",
    "docs/design/backups/",
    "build/qa/",
)
BINARY_SUFFIXES = frozenset({
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".wav", ".ogg",
    ".mp3", ".ttf", ".otf", ".ico", ".dmg", ".exe", ".zip", ".res",
})
OID_RE = re.compile(rb"oid sha256:[0-9a-fA-F]{64}")
SIZE_RE = re.compile(rb"size [0-9]+")
POINTER_VERSION = b"version https://git-lfs.github.com/spec/v1"


def _git(root: Path, *arguments: str) -> bytes:
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.decode(errors="replace").strip()
        raise RuntimeError(message or f"git {' '.join(arguments)} failed")
    return result.stdout


def changed_paths(root: Path, changed_ref: str) -> list[str]:
    output = _git(
        root,
        "diff",
        "--name-only",
        "--diff-filter=ACMR",
        "-z",
        f"{changed_ref}...HEAD",
        "--",
    )
    return sorted(path.decode(errors="surrogateescape") for path in output.split(b"\0") if path)


def head_blob(root: Path, path: str) -> bytes:
    return _git(root, "cat-file", "blob", f"HEAD:{path}")


def is_lfs_pointer(content: bytes) -> bool:
    lines = content.splitlines()
    return bool(
        lines
        and lines[0] == POINTER_VERSION
        and any(OID_RE.fullmatch(line) for line in lines[1:])
        and any(SIZE_RE.fullmatch(line) for line in lines[1:])
    )


def lfs_attribute_error(root: Path, path: str) -> str | None:
    output = _git(root, "check-attr", "--cached", "-z", "filter", "diff", "merge", "text", "--", path)
    fields = output.split(b"\0")
    attributes = {
        fields[index + 1].decode(): fields[index + 2].decode()
        for index in range(0, len(fields) - 2, 3)
    }
    expected = {"filter": "lfs", "diff": "lfs", "merge": "lfs", "text": "unset"}
    if attributes == expected:
        return None
    return f"{path}: requires Git attributes filter=lfs diff=lfs merge=lfs -text"


def collect_errors(root: Path, changed_ref: str) -> list[str]:
    errors: list[str] = []
    legacy_raw: list[tuple[str, int]] = []
    for path in changed_paths(root, changed_ref):
        if Path(path).suffix.lower() not in BINARY_SUFFIXES:
            continue
        content = head_blob(root, path)
        if path.startswith(FUTURE_PREFIX):
            attribute_error = lfs_attribute_error(root, path)
            if attribute_error:
                errors.append(attribute_error)
            if not is_lfs_pointer(content):
                errors.append(
                    f"{path}: expected a valid Git LFS pointer; add the file through Git LFS"
                )
        elif path.startswith(LEGACY_PREFIXES) and not is_lfs_pointer(content):
            size = len(content)
            legacy_raw.append((path, size))
            if size >= LEGACY_LIMIT:
                errors.append(
                    f"{path}: changed raw legacy binary is {size} bytes (limit is below 1 MiB); "
                    f"move it under {FUTURE_PREFIX}<issue-or-pack>/ and use Git LFS"
                )

    total = sum(size for _, size in legacy_raw)
    if total > LEGACY_AGGREGATE_LIMIT:
        paths = ", ".join(path for path, _ in legacy_raw)
        errors.append(
            f"{paths}: aggregate changed raw legacy binary size is {total} bytes "
            f"(limit is 5 MiB); use {FUTURE_PREFIX}<issue-or-pack>/ with Git LFS"
        )
    return errors


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--changed-ref", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    root = args.root.resolve()
    try:
        errors = collect_errors(root, args.changed_ref)
    except RuntimeError as exc:
        print(f"repository storage policy: {exc}", file=sys.stderr)
        return 2
    for error in errors:
        print(f"STORAGE POLICY FAIL: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
