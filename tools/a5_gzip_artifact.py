#!/usr/bin/env python3
"""Deterministic, validated gzip materialization for the A5 canonical raw JSON."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


DEFAULT_MAX_COMPRESSED_BYTES = 100 * 1024 * 1024
MAX_UNCOMPRESSED_BYTES = 512 * 1024 * 1024
GZIP_HEADER = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x02\xff"
CHUNK_SIZE = 1024 * 1024


def _atomic_path(destination: Path) -> tuple[int, Path]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    return tempfile.mkstemp(prefix=".%s." % destination.name, suffix=".tmp", dir=destination.parent)


def _check_compressed_size(path: Path, maximum: int) -> int:
    size = path.stat().st_size
    if size >= maximum:
        raise ValueError("compressed artifact is %d bytes; limit is %d bytes" % (size, maximum))
    return size


def _verify_gzip(path: Path, maximum: int) -> dict[str, int | str]:
    size = _check_compressed_size(path, maximum)
    with path.open("rb") as compressed:
        if compressed.read(len(GZIP_HEADER)) != GZIP_HEADER:
            raise ValueError("gzip header is not the required deterministic header")
    digest = hashlib.sha256()
    uncompressed_size = 0
    with gzip.open(path, "rb") as stream:
        while chunk := stream.read(CHUNK_SIZE):
            uncompressed_size += len(chunk)
            if uncompressed_size > MAX_UNCOMPRESSED_BYTES:
                raise ValueError("uncompressed artifact exceeds %d bytes" % MAX_UNCOMPRESSED_BYTES)
            digest.update(chunk)
    return {
        "compressed_bytes": size,
        "uncompressed_bytes": uncompressed_size,
        "sha256": digest.hexdigest(),
    }


def pack(source: Path, destination: Path, maximum: int = DEFAULT_MAX_COMPRESSED_BYTES) -> dict[str, int | str]:
    source = source.resolve()
    destination = destination.resolve()
    if not source.is_file():
        raise ValueError("source JSON does not exist: %s" % source)
    file_descriptor, temporary = _atomic_path(destination)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(file_descriptor, "wb") as output, source.open("rb") as input_stream:
            # filename='' and mtime=0 make the gzip header byte-for-byte stable.
            with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0, compresslevel=9) as stream:
                shutil.copyfileobj(input_stream, stream, CHUNK_SIZE)
            output.flush()
            os.fsync(output.fileno())
        result = _verify_gzip(temporary_path, maximum)
        os.replace(temporary_path, destination)
        return result
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise


def unpack(source: Path, destination: Path, maximum: int = DEFAULT_MAX_COMPRESSED_BYTES) -> dict[str, int | str]:
    source = source.resolve()
    destination = destination.resolve()
    verification = _verify_gzip(source, maximum)
    file_descriptor, temporary = _atomic_path(destination)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(file_descriptor, "wb") as output, gzip.open(source, "rb") as input_stream:
            copied = 0
            while chunk := input_stream.read(CHUNK_SIZE):
                copied += len(chunk)
                if copied > MAX_UNCOMPRESSED_BYTES:
                    raise ValueError("uncompressed artifact exceeds %d bytes" % MAX_UNCOMPRESSED_BYTES)
                output.write(chunk)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary_path, destination)
        return verification
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("pack", "unpack", "verify"))
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path, nargs="?")
    parser.add_argument("--max-compressed-bytes", type=int, default=DEFAULT_MAX_COMPRESSED_BYTES)
    arguments = parser.parse_args()
    try:
        if arguments.operation == "pack":
            if arguments.destination is None:
                parser.error("pack requires a destination")
            result = pack(arguments.source, arguments.destination, arguments.max_compressed_bytes)
        elif arguments.operation == "unpack":
            if arguments.destination is None:
                parser.error("unpack requires a destination")
            result = unpack(arguments.source, arguments.destination, arguments.max_compressed_bytes)
        else:
            result = _verify_gzip(arguments.source.resolve(), arguments.max_compressed_bytes)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, gzip.BadGzipFile, EOFError) as error:
        print("A5 gzip artifact error: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
