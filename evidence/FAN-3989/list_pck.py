#!/usr/bin/env python3
"""FAN-3989: list and compare the PCK file tables of the installed macOS app
and of the Windows player embedded in the retained NSIS Setup.

The macOS PCK is a plain file (Contents/Resources/FantasyDisk.pck). The
Windows exe embeds the PCK: the file ends with an 8-byte little-endian PCK
size followed by the ``GDPC`` magic, so the PCK starts at
``len(exe) - 12 - size``. The directory reader is the FAN-3985 probe's own
``read_pck_directory`` (format 4), reused unchanged; only the carved PCK copy
is passed to it. Reports the entry counts, the ``data/ultimates/presentation``
documents, forbidden top-level trees and whether both tables are identical
by path, size and md5.

Usage: list_pck.py --macos-pck <pck> --windows-exe <FantasyDisk-Windows.exe> --out <json>
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from ultimate_export_probe import FORBIDDEN_PREFIXES, PRESENTATION_PREFIX, read_pck_directory  # noqa: E402


def carve_embedded_pck(exe: Path, destination: Path) -> dict:
    size = exe.stat().st_size
    with exe.open("rb") as handle:
        handle.seek(size - 12)
        pck_size, magic = struct.unpack("<Q4s", handle.read(12))
        if magic != b"GDPC":
            raise SystemExit(f"{exe}: no embedded PCK trailer")
        start = size - 12 - pck_size
        handle.seek(start)
        if handle.read(4) != b"GDPC":
            raise SystemExit(f"{exe}: embedded PCK magic missing at {start}")
        handle.seek(start)
        digest = hashlib.sha256()
        with destination.open("wb") as out:
            remaining = pck_size
            while remaining:
                chunk = handle.read(min(1 << 20, remaining))
                out.write(chunk)
                digest.update(chunk)
                remaining -= len(chunk)
    return {"exe_size": size, "pck_offset": start, "pck_size": pck_size, "pck_sha256": digest.hexdigest()}


def table(pck: Path) -> dict:
    directory = read_pck_directory(pck)
    entries = directory["entries"]
    rows = {entry["path"]: {"size": entry["size"], "offset": entry["offset"]} for entry in entries}
    paths = sorted(rows)
    presentation = [p for p in paths if p.startswith(PRESENTATION_PREFIX)]
    forbidden = [p for p in paths if p.startswith(FORBIDDEN_PREFIXES)]
    top = {}
    for p in paths:
        top[p.split("/", 1)[0]] = top.get(p.split("/", 1)[0], 0) + 1
    return {
        "format_version": directory["format_version"],
        "engine_version": directory["engine_version"],
        "entry_count": len(paths),
        "top_level": top,
        "presentation_documents": presentation,
        "forbidden_entries": forbidden,
        "rows": rows,
    }


def content_md5s(pck: Path, rows: dict, sample: list[str]) -> dict:
    out = {}
    with pck.open("rb") as handle:
        for path in sample:
            row = rows[path]
            handle.seek(row["offset"])
            out[path] = hashlib.md5(handle.read(row["size"])).hexdigest()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--macos-pck", type=Path, required=True)
    parser.add_argument("--windows-exe", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="fan3989-pck-") as tmp:
        carved = Path(tmp) / "windows_embedded.pck"
        win_info = carve_embedded_pck(args.windows_exe, carved)
        mac = table(args.macos_pck)
        win = table(carved)
        same_paths = sorted(mac["rows"]) == sorted(win["rows"])
        size_mismatch = [p for p in mac["rows"] if p in win["rows"] and mac["rows"][p]["size"] != win["rows"][p]["size"]]
        # Content check: every data/ultimates/presentation document, every
        # ultimate class script/remap and a fixed sample of other entries.
        sample = [p for p in sorted(mac["rows"]) if p.startswith(PRESENTATION_PREFIX) or p.startswith("scripts/ultimates/")]
        sample += [p for p in sorted(mac["rows"]) if p.endswith(".gdc")][:200]
        sample = sorted(set(sample))
        mac_md5 = content_md5s(args.macos_pck, mac["rows"], sample)
        win_md5 = content_md5s(carved, win["rows"], [p for p in sample if p in win["rows"]])
        md5_mismatch = [p for p in sample if mac_md5.get(p) != win_md5.get(p)]
        result = {
            "macos_pck": {"path": str(args.macos_pck), "size": args.macos_pck.stat().st_size,
                          "sha256": hashlib.sha256(args.macos_pck.read_bytes()).hexdigest(),
                          **{k: v for k, v in mac.items() if k != "rows"}},
            "windows_embedded_pck": {"exe": str(args.windows_exe), **win_info, **{k: v for k, v in win.items() if k != "rows"}},
            "tables_identical_by_path": same_paths,
            "size_mismatches": size_mismatch,
            "content_sample_entries": len(sample),
            "content_sample_md5_mismatches": md5_mismatch,
            "pass": same_paths and not size_mismatch and not md5_mismatch and not mac["forbidden_entries"] and not win["forbidden_entries"]
                    and len(mac["presentation_documents"]) == 17,
        }
    args.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k not in ("macos_pck", "windows_embedded_pck")}, indent=2))
    print("macos entries", mac["entry_count"], "windows entries", win["entry_count"], "presentation docs", len(mac["presentation_documents"]), len(win["presentation_documents"]), "forbidden", len(mac["forbidden_entries"]), len(win["forbidden_entries"]))
    print("windows pck", win_info)
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
