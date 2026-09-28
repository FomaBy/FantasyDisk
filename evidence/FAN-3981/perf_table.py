#!/usr/bin/env python3
"""FAN-3981: Markdown tables from perf_driver.gd JSON reports.

Usage: perf_table.py <report.json> [<report.json> ...]
Prints (1) the per-phase M1/M3/texture table, (2) the M3 summary against the
perf checklist (P2 target 5,000 / red > 6,250; P3 target 4,000 / red > 5,000)
and (3) the per-second object and alive series of P2/P3 for the growth check.
"""
import json
import sys

reports = [json.load(open(path, encoding="utf-8")) for path in sys.argv[1:]]
print("| build | phase | s | avg FPS | 1% low | frames >50 ms | frames >100 ms | longest frame ms | peak texture MiB | objects peak | objects min | objects first s | objects last s | resident packs |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for report in reports:
    for phase in report["phases"]:
        packs = "%d -> %d" % (phase["resident_packs_start"], phase["resident_packs_end"]) if phase["resident_packs_start"] >= 0 else "n/a (no registry counter)"
        print("| %s | %s | %d | %.0f | %.0f | %d | %d | %.1f | %.0f | %d | %d | %d | %d | %s |" % (
            report["label"], phase["phase"], phase["seconds"], phase["avg_fps"], phase["low_1pct_fps"], phase["frames_over_50ms"],
            phase["frames_over_100ms"], phase["longest_frame_ms"], phase["peak_texture_mib"], phase["objects_peak"], phase["objects_min"],
            phase["objects_first_second"], phase["objects_last_second"], packs))
print()


def band(value, target, red):
    if value <= target:
        return "green"
    if value <= red:
        return "yellow"
    return "red"


print("| build | boss phases | P1 menu peak | route map peak (packs) | P2 peak (band) | P3 peak (band) | elite peak | act-2 boss peak | menu after run (packs) | act-1 peak texture MiB | menu texture after run MiB |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for report in reports:
    by = {phase["phase"]: phase for phase in report["phases"]}
    p2 = by["p2_48_enemies"]["objects_peak"]
    p3 = by["p3_boss_act1_rift_warden"]["objects_peak"]
    route = by["route_map_first_show"]
    mode = "natural spawns" if by["p3_boss_act1_rift_warden"].get("boss_natural") else "48-enemy top-up"
    print("| %s | %s | %d | %d (%s) | %d (%s) | %d (%s) | %d | %d | %d (%s) | %.0f | %.0f |" % (
        report["label"], mode, by["p1_main_menu"]["objects_peak"], route["objects_peak"],
        route["resident_packs_end"] if route["resident_packs_end"] >= 0 else "n/a",
        p2, band(p2, 5000, 6250), p3, band(p3, 4000, 5000), by["elite_night_stalker"]["objects_peak"],
        by["boss_act2_disk_devourer"]["objects_peak"], report["menu_objects_after_run"],
        report["menu_resident_packs_after_run"] if report["menu_resident_packs_after_run"] >= 0 else "n/a",
        report["act1_peak_texture_mib"], report["menu_texture_after_run_mib"]))
print()
for report in reports:
    for name in ("p2_48_enemies", "p3_boss_act1_rift_warden"):
        phase = next(p for p in report["phases"] if p["phase"] == name)
        series = phase["objects_per_second"]
        rises = sum(1 for a, b in zip(series, series[1:]) if b > a)
        falls = sum(1 for a, b in zip(series, series[1:]) if b < a)
        print("%s %s objects per second (%d rises / %d falls, min %d, max %d): %s" % (
            report["label"], name, rises, falls, min(series), max(series), " ".join(str(v) for v in series)))
        if phase.get("alive_per_second"):
            print("%s %s alive enemies+boss per second: %s" % (report["label"], name, " ".join(str(v) for v in phase["alive_per_second"])))
