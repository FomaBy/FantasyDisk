#!/usr/bin/env python3
"""FAN-3994: Markdown tables from the perf_ultimate_driver.gd reports in
evidence/FAN-3994/perf/**.json (one row per run, one row per cast)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main() -> int:
    directory = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "perf"
    reports = sorted(p for p in directory.rglob("*.json") if not p.name.endswith("_summary.json"))
    print("| run | class/weapon | source | casts | s | avg FPS | 1% low | worst s | >50 ms | >100 ms | longest ms | first-cast frame ms | later casts max ms | objects start | objects peak | objects end | pickups at end | peak texture MiB | objects back at menu |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for report in reports:
        d = json.loads(report.read_text(encoding="utf-8"))
        ph = d.get("phase") or {}
        casts = d.get("casts", [])
        first = casts[0]["longest_frame_ms_within_60_frames"] if casts and "longest_frame_ms_within_60_frames" in casts[0] else None
        later = max((c.get("longest_frame_ms_within_60_frames", 0.0) for c in casts[1:] if c.get("activated")), default=None)
        pickups = (ph.get("tree_breakdown") or {}).get("groups", {}).get("pickups")
        print(f"| {d['label']} | {d['character_id']}/{d['weapon_id']} | {d.get('resolution_source')} | {d.get('casts_activated')}/{d.get('casts_total')} | {ph.get('seconds')} | {ph.get('avg_fps', 0):.0f} | {ph.get('low_1pct_fps', 0):.0f} | {ph.get('worst_second_fps', 0):.0f} | {ph.get('frames_over_50ms')} | {ph.get('frames_over_100ms')} | {ph.get('longest_frame_ms', 0):.1f} | {first if first is None else f'{first:.1f}'} | {later if later is None else f'{later:.1f}'} | {ph.get('objects_first_second')} | {ph.get('objects_peak')} | {ph.get('objects_last_second')} | {pickups if pickups is not None else 'n/a'} | {ph.get('peak_texture_mib', 0):.0f} | {d.get('menu_objects_after_run')} |")
    print()
    print("Per cast (second in window, activated, failure, longest frame in the next 60 frames, OBJECT_COUNT before the cast, alive enemies):")
    for report in reports:
        d = json.loads(report.read_text(encoding="utf-8"))
        rows = ", ".join(f"@{c['second']}s {'ok' if c['activated'] else 'no(' + c.get('activation_failure', '') + ')'} {c.get('longest_frame_ms_within_60_frames', 0):.0f} ms {c['objects_before']} obj {c['alive']} alive" for c in d.get("casts", []))
        print(f"- {d['label']} {d['character_id']}/{d['weapon_id']}: {rows}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
