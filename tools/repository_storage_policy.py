#!/usr/bin/env python3
"""Enforce future-only LFS storage for changed design binaries."""
from __future__ import annotations

import argparse
import codecs
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple, Sequence


FUTURE_PREFIX = "docs/design/reference-assets-lfs/"
RESTRICTED_PREFIXES = ("docs/design/", "build/qa/")
MAX_LFS_POINTER_BYTES = 256
CONTENT_SCAN_CHUNK_BYTES = 8192
TEXT_SUFFIXES = frozenset({
    ".cfg", ".csv", ".gd", ".godot", ".html", ".import", ".ini", ".js",
    ".json", ".log", ".md", ".py", ".rst", ".sh", ".toml", ".tres", ".tscn",
    ".tsv", ".txt", ".xml", ".yaml", ".yml",
})
TEXT_FILENAMES = frozenset({".gitattributes", ".gdignore", ".gitignore"})
LFS_POINTER_RE = re.compile(
    rb"\Aversion https://git-lfs\.github\.com/spec/v1\n"
    rb"oid sha256:[0-9a-f]{64}\n"
    rb"size (?:0|[1-9][0-9]*)\n\Z"
)


class ChangedEntry(NamedTuple):
    status: str
    old_path: str | None
    path: str


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


def changed_entries(root: Path, changed_ref: str) -> list[ChangedEntry]:
    output = _git(
        root,
        "diff",
        "--name-status",
        "-z",
        "--find-renames",
        "--find-copies-harder",
        "--diff-filter=ACMRD",
        f"{changed_ref}...HEAD",
        "--",
    )
    fields = output.split(b"\0")
    if fields and fields[-1] == b"":
        fields.pop()
    entries: list[ChangedEntry] = []
    index = 0
    while index < len(fields):
        raw_status = fields[index].decode("ascii", errors="strict")
        index += 1
        status = raw_status[:1]
        path_count = 2 if status in {"C", "R"} else 1
        if status not in {"A", "C", "D", "M", "R"} or index + path_count > len(fields):
            raise RuntimeError("malformed git diff --name-status output")
        paths = [
            fields[index + offset].decode(errors="surrogateescape")
            for offset in range(path_count)
        ]
        index += path_count
        old_path = paths[0] if path_count == 2 else None
        entries.append(ChangedEntry(status, old_path, paths[-1]))
    return sorted(entries, key=lambda entry: (entry.path, entry.status, entry.old_path or ""))


def head_blob_size(root: Path, path: str) -> int:
    output = _git(root, "cat-file", "-s", f"HEAD:{path}").strip()
    try:
        return int(output)
    except ValueError as exc:
        raise RuntimeError(f"invalid Git blob size for {path}: {output!r}") from exc


def head_blob(root: Path, path: str) -> bytes:
    return _git(root, "cat-file", "blob", f"HEAD:{path}")


def head_blob_is_binary(root: Path, path: str) -> bool:
    """Scan the HEAD blob without materializing it in Python or the worktree."""
    process = subprocess.Popen(
        ["git", "cat-file", "blob", f"HEAD:{path}"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    decoder = codecs.getincrementaldecoder("utf-8")()
    is_binary = False
    try:
        while chunk := process.stdout.read(CONTENT_SCAN_CHUNK_BYTES):
            if any(byte < 32 and byte not in b"\t\n\r\f\b" for byte in chunk):
                is_binary = True
                break
            try:
                decoder.decode(chunk)
            except UnicodeDecodeError:
                is_binary = True
                break
        if not is_binary:
            try:
                decoder.decode(b"", final=True)
            except UnicodeDecodeError:
                is_binary = True
    finally:
        if is_binary and process.poll() is None:
            process.kill()
        return_code = process.wait()
        errors = process.stderr.read()
        process.stdout.close()
        process.stderr.close()
    if not is_binary and return_code != 0:
        message = errors.decode(errors="replace").strip()
        raise RuntimeError(message or f"git cat-file blob HEAD:{path} failed")
    return is_binary


def is_lfs_pointer(content: bytes) -> bool:
    return len(content) <= MAX_LFS_POINTER_BYTES and LFS_POINTER_RE.fullmatch(content) is not None


def _is_binary(root: Path, path: str, size: int) -> bool:
    candidate = Path(path)
    declared_text = (
        candidate.name.lower() in TEXT_FILENAMES or candidate.suffix.lower() in TEXT_SUFFIXES
    )
    if candidate.suffix and not declared_text:
        return True
    if not declared_text and size > CONTENT_SCAN_CHUNK_BYTES:
        return True
    # A text extension must not mask binary content. Scan the complete stream
    # and fail closed on invalid UTF-8 or control bytes while keeping memory
    # bounded to one chunk.
    return head_blob_is_binary(root, path)


def _has_pack_nesting(path: str) -> bool:
    relative = path.removeprefix(FUTURE_PREFIX)
    parts = relative.split("/")
    return len(parts) >= 2 and all(parts)


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
    for entry in changed_entries(root, changed_ref):
        if entry.status == "D" or not entry.path.startswith(RESTRICTED_PREFIXES):
            continue
        size = head_blob_size(root, entry.path)
        if not _is_binary(root, entry.path, size):
            continue
        if not entry.path.startswith(FUTURE_PREFIX):
            origin = f" copied/renamed from {entry.old_path}" if entry.old_path else ""
            errors.append(
                f"{entry.path}: changed binary ({size} bytes, status {entry.status}{origin}) must live under "
                f"{FUTURE_PREFIX}<issue-or-pack>/ and use Git LFS"
            )
            continue
        if not _has_pack_nesting(entry.path):
            errors.append(
                f"{entry.path}: future binaries require {FUTURE_PREFIX}<issue-or-pack>/<file> nesting"
            )
            continue
        attribute_error = lfs_attribute_error(root, entry.path)
        if attribute_error:
            errors.append(attribute_error)
        if size > MAX_LFS_POINTER_BYTES:
            errors.append(
                f"{entry.path}: Git LFS pointer blob is too large ({size} bytes; maximum "
                f"{MAX_LFS_POINTER_BYTES}); add the binary through Git LFS"
            )
            continue
        if not is_lfs_pointer(head_blob(root, entry.path)):
            errors.append(
                f"{entry.path}: expected an exact canonical Git LFS pointer; add the file through Git LFS"
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
