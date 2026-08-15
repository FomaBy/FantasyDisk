#!/usr/bin/env python3
"""Fail a release when an exported artifact contains a Discord webhook.

The scanner reports only artifact paths and finding kinds, never the matched
credential. It detects raw URLs, complete Base64 values, and nearby split
Base64 chunks such as strings retained in a packed script resource.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import re
import sys
import zipfile
from pathlib import Path
from typing import Iterable, Optional, Sequence


RAW_WEBHOOK_RE = re.compile(
    rb"https://(?:discord(?:app)?\.com)/api/webhooks/[0-9]{15,}/[A-Za-z0-9_-]{20,}"
)
BASE64_RUN_RE = re.compile(rb"[A-Za-z0-9+/]{12,}={0,2}")
QUOTED_BASE64_RE = re.compile(rb"[\"']([A-Za-z0-9+/]{1,}={0,2})[\"']")
MAX_CHUNK_GAP = 128
MAX_ARCHIVE_ENTRY_BYTES = 1024 * 1024 * 1024
MAX_ARCHIVE_TOTAL_BYTES = 4 * 1024 * 1024 * 1024


def _contains_webhook(decoded: bytes) -> bool:
    return RAW_WEBHOOK_RE.search(decoded) is not None


def _decode_base64(candidate: bytes) -> bytes:
    padded = candidate + b"=" * (-len(candidate) % 4)
    try:
        return base64.b64decode(padded, validate=True)
    except (binascii.Error, ValueError):
        return b""


def finding_kinds(data: bytes) -> set[str]:
    findings: set[str] = set()
    if RAW_WEBHOOK_RE.search(data):
        findings.add("raw-discord-webhook")
    generic_runs = [(match.start(), match.end(), match.group(0)) for match in BASE64_RUN_RE.finditer(data)]
    quoted_runs = [(match.start(1), match.end(1), match.group(1)) for match in QUOTED_BASE64_RE.finditer(data)]
    for runs in (generic_runs, quoted_runs):
        _scan_base64_runs(runs, findings)
    return findings


def _scan_base64_runs(runs: list[tuple[int, int, bytes]], findings: set[str]) -> None:
    # Normalize the fragment stream: join every run (separators removed) into
    # gap-bounded segments and scan each joined segment once, so fragmentation
    # of any width is detected in linear time instead of joining a bounded
    # number of fragment combinations.
    segment = b""
    previous_end = 0
    for run_start, run_end, value in runs:
        if segment and run_start - previous_end > MAX_CHUNK_GAP:
            if _joined_segment_contains_webhook(segment):
                findings.add("base64-discord-webhook")
                return
            segment = b""
        segment += value.rstrip(b"=")
        previous_end = run_end
    if segment and _joined_segment_contains_webhook(segment):
        findings.add("base64-discord-webhook")


def _joined_segment_contains_webhook(segment: bytes) -> bool:
    # The encoded secret may start at any position inside the joined segment,
    # so decode each of the four Base64 block alignments; interior blocks then
    # decode independently of any surrounding noise fragments.
    for offset in range(min(4, len(segment))):
        aligned = segment[offset:]
        for candidate in (aligned, aligned[: len(aligned) // 4 * 4]):
            if _contains_webhook(_decode_base64(candidate)):
                return True
    return False


def _files(paths: Sequence[Path]) -> Iterable[Path]:
    for path in paths:
        if path.is_dir():
            yield from (candidate for candidate in sorted(path.rglob("*")) if candidate.is_file())
        elif path.is_file():
            yield path
        else:
            raise FileNotFoundError(path)


def scan_paths(paths: Sequence[Path]) -> list[tuple[Path, str]]:
    findings = []
    for path in _files(paths):
        data = path.read_bytes()
        findings.extend((path, kind) for kind in sorted(finding_kinds(data)))
        if zipfile.is_zipfile(path):
            total = 0
            with zipfile.ZipFile(path) as archive:
                for info in archive.infolist():
                    if info.is_dir():
                        continue
                    if info.file_size > MAX_ARCHIVE_ENTRY_BYTES:
                        raise ValueError("archive entry exceeds scan limit: %s!%s" % (path, info.filename))
                    total += info.file_size
                    if total > MAX_ARCHIVE_TOTAL_BYTES:
                        raise ValueError("archive exceeds total scan limit: %s" % path)
                    entry = archive.read(info)
                    virtual_path = Path("%s!%s" % (path, info.filename))
                    findings.extend((virtual_path, kind) for kind in sorted(finding_kinds(entry)))
    return findings


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args(argv)
    try:
        findings = scan_paths(args.paths)
    except (OSError, FileNotFoundError, ValueError, zipfile.BadZipFile) as exc:
        print("Release secret scan could not read an artifact: %s" % exc, file=sys.stderr)
        return 2
    if findings:
        for path, kind in findings:
            print("SECRET SCAN FAIL: %s: %s" % (path, kind), file=sys.stderr)
        return 1
    print("Release secret scan passed (%d artifact root(s))." % len(args.paths))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
