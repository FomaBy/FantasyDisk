#!/usr/bin/env python3
"""FAN-3994 cold-start summary for measure_cold_start_app.sh logs.

For every ``<label>_run<N>.log`` in the directory: first-frame estimate =
(timestamp of the first ``Project FPS`` line) - START - 1.0 s (FAN-3973 /
FAN-3964 method).  Prints a Markdown table (median, min, max per label) and
writes ``cold_start_summary.json`` next to the logs.
"""
from __future__ import annotations

import json
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

RUN_RE = re.compile(r"^(?P<label>.+)_run(?P<run>\d+)\.log$")
FPS_RE = re.compile(r"^(?P<ts>\d+\.\d+) Project FPS")


def first_frame_seconds(log: Path) -> float | None:
    start = None
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("START "):
            start = float(line.split()[1])
            continue
        match = FPS_RE.match(line)
        if match and start is not None:
            return round(float(match.group("ts")) - start - 1.0, 3)
    return None


def main(argv: list[str]) -> int:
    directory = Path(argv[1] if len(argv) > 1 else "cold_start")
    runs: dict[str, list[dict]] = defaultdict(list)
    for log in sorted(directory.glob("*_run*.log")):
        match = RUN_RE.match(log.name)
        if not match:
            continue
        seconds = first_frame_seconds(log)
        runs[match.group("label")].append({"run": int(match.group("run")), "log": log.name, "first_frame_s": seconds})
    summary = {}
    print("| build | runs | median first frame (s) | min | max | per run |")
    print("|---|---|---|---|---|---|")
    for label, entries in runs.items():
        values = [e["first_frame_s"] for e in entries if e["first_frame_s"] is not None]
        if not values:
            print(f"| {label} | {len(entries)} | n/a | n/a | n/a | no Project FPS line |")
            summary[label] = {"runs": entries, "median_s": None}
            continue
        summary[label] = {
            "runs": entries,
            "median_s": round(statistics.median(values), 3),
            "min_s": min(values),
            "max_s": max(values),
        }
        print(f"| {label} | {len(values)} | {summary[label]['median_s']:.2f} | {min(values):.2f} | {max(values):.2f} | {', '.join(f'{v:.2f}' for v in values)} |")
    (directory / "cold_start_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
