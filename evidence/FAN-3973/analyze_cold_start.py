#!/usr/bin/env python3
"""FAN-3973: summarize measure_cold_start.sh logs.

For every log: seconds from process start to the first `Project FPS` line,
the first-frame estimate (that minus 1 s, the FAN-3964 convention), and the
number of actor full-frame SpriteFrames / .ctex loads that completed before
the first frame. Prints one row per run and the median per label.
"""
from __future__ import annotations

import re
import statistics
import sys
from pathlib import Path

ACTOR_FOLDERS = (
    "res://assets/sprites/enemies/",
    "res://assets/sprites/elites/",
    "res://assets/sprites/bosses/",
    "res://assets/sprites/allies/",
)
LINE_RE = re.compile(r"^(\d+\.\d+) (.*)$")


def analyze(log: Path) -> dict:
    start = None
    first_fps = None
    actor_ctex = 0
    actor_spriteframes = 0
    any_ctex = 0
    main_gd = None
    for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if raw.startswith("START "):
            start = float(raw.split()[1])
            continue
        match = LINE_RE.match(raw)
        if not match:
            continue
        stamp, text = float(match.group(1)), match.group(2)
        if first_fps is None and "Project FPS" in text:
            first_fps = stamp
        if first_fps is not None:
            continue
        # Godot 4.7 prints the imported texture as its `.godot/imported/*.ctex`
        # path (no source folder) and, separately, the source `.png` path it
        # was requested through; the source line is what identifies the actor.
        if text.startswith("Loading resource: ") and ".ctex" in text:
            any_ctex += 1
        if text.startswith("Loading resource: ") and ".png" in text and any(folder in text for folder in ACTOR_FOLDERS):
            actor_ctex += 1
        if text.startswith("Completed load for: ") and "_spriteframes.tres" in text and any(folder in text for folder in ACTOR_FOLDERS):
            actor_spriteframes += 1
        if main_gd is None and "Completed load for: 'res://scripts/main.gd'" in text:
            main_gd = stamp
    if start is None or first_fps is None:
        return {"log": log.name, "error": "no START or no Project FPS line"}
    return {
        "log": log.name,
        "first_fps_s": round(first_fps - start, 2),
        "first_frame_est_s": round(first_fps - start - 1.0, 2),
        "main_gd_s": round(main_gd - start, 2) if main_gd else None,
        "actor_spriteframes_before_first_frame": actor_spriteframes,
        "actor_ctex_before_first_frame": actor_ctex,
        "all_ctex_before_first_frame": any_ctex,
    }


def main(argv: list[str]) -> int:
    out_dir = Path(argv[1]) if len(argv) > 1 else Path(__file__).parent / "cold_start"
    rows = [analyze(log) for log in sorted(out_dir.glob("*_run*.log"))]
    by_label: dict[str, list[dict]] = {}
    for row in rows:
        label = row["log"].rsplit("_run", 1)[0]
        by_label.setdefault(label, []).append(row)
    print("| label | run | first FPS line (s) | first frame est. (s) | main.gd (s) | actor SpriteFrames before first frame | actor textures (.png source) before first frame |")
    print("|---|---|---|---|---|---|---|")
    for label, label_rows in by_label.items():
        for row in label_rows:
            if "error" in row:
                print(f"| {label} | {row['log']} | ERROR {row['error']} | | | | |")
                continue
            print(f"| {label} | {row['log']} | {row['first_fps_s']} | {row['first_frame_est_s']} | {row['main_gd_s']} | {row['actor_spriteframes_before_first_frame']} | {row['actor_ctex_before_first_frame']} |")
    print()
    print("| label | runs | median first frame est. (s) | min | max | max actor SpriteFrames before first frame |")
    print("|---|---|---|---|---|---|")
    for label, label_rows in by_label.items():
        good = [row for row in label_rows if "error" not in row]
        if not good:
            continue
        values = [row["first_frame_est_s"] for row in good]
        print(f"| {label} | {len(good)} | {statistics.median(values):.2f} | {min(values):.2f} | {max(values):.2f} | {max(row['actor_spriteframes_before_first_frame'] for row in good)} |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
