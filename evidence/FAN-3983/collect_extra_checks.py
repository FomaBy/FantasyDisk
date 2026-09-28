"""Assemble evidence/FAN-3983 built-bytes checks (AC3/AC4/transfer) into build/FAN-3983/extra_checks.json.

Reads the scratch outputs of list_pck.py, measure_cold_start_app.sh (+ FAN-3973
analyze_cold_start.py summary), run_combat_check.sh (FAN-3981 perf driver JSON),
the saves/user-data manifests, the snapshot comparison and the FAN-3964 transfer
record. Verdicts are computed here against the FAN-3977 targets and the M3 hard
limits (P2 <= 6,250 / P3 <= 5,000) and the checklist targets (P2 <= 5,000 / P3 <= 4,000).
"""
import hashlib, json, pathlib, re, statistics, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "FAN-3983"
RELEASES = pathlib.Path("/Users/sergeyfomin/FantasyDisk/releases")
NEW = RELEASES / "v0.3.1"
ATT1 = RELEASES / "archive" / "v0.3.1-attempt1-448a0cc1"
ATT2 = RELEASES / "archive" / "v0.3.1-attempt2-165f14aa"

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""): h.update(c)
    return h.hexdigest()
def kv(path):
    return dict(l.split("=", 1) for l in pathlib.Path(path).read_text().splitlines() if "=" in l and not l.startswith("#"))

mac = json.loads((OUT / "pck_0.3.1new_macos.json").read_text())
win = json.loads((OUT / "pck_0.3.1new_windows.json").read_text())
old3980_win = json.loads((OUT / "ref3980" / "evidence" / "FAN-3980" / "pck_0.3.1new_windows.json").read_text())
old3963_win = json.loads((OUT / "ref3980" / "evidence" / "FAN-3980" / "pck_0.3.1old_windows.json").read_text())
pck = {
    "tool": "evidence/FAN-3983/list_pck.py (= FAN-3980 list_pck.py, FAN-3973 rule set); Windows exe extracted read-only from the retained Setup with `7z e`",
    "forbidden_prefixes": ["res://evidence/", "res://skills/", "res://docs/", "res://tools/", "res://tests/", "stray root .import"],
    "macos_installed_app_pck": {k: mac[k] for k in ("file_count", "payload_bytes", "top_level", "root_files", "forbidden_count")},
    "windows_exe_embedded_pck": {k: win[k] for k in ("file_count", "payload_bytes", "top_level", "root_files", "forbidden_count", "pck_start", "container_size")},
    "macos_windows_file_tables_identical": (OUT / "pck_macos_paths.txt").read_bytes() == (OUT / "pck_windows_paths.txt").read_bytes(),
    "forbidden_paths_new_0.3.1": mac["forbidden_count"] + win["forbidden_count"],
    "fan3980_0.3.1_windows_exe_pck_for_comparison": {k: old3980_win[k] for k in ("file_count", "payload_bytes", "forbidden_count")},
    "fan3963_0.3.1_windows_exe_pck_for_comparison": {k: old3963_win[k] for k in ("file_count", "payload_bytes", "forbidden_count")},
    "macos_pck_sha256": sha("/Applications/FantasyDisk.app/Contents/Resources/FantasyDisk.pck"),
    "installed_app_equals_dmg_app": (OUT / "dmg_app_files.sha256").read_bytes() == (OUT / "installed_app_files.sha256").read_bytes(),
    "installed_app_file_count": sum(1 for _ in (OUT / "installed_app_files.sha256").open()),
}
def inv(path):
    return json.loads((path / "LOCAL_RELEASE.json").read_text())["package_inventory"]
i_new, i1, i2 = inv(NEW), inv(ATT1), inv(ATT2)
sizes = {
    "windows_exe_inside_setup": {"new": (OUT / "win_extract" / "FantasyDisk.exe").stat().st_size, "fan3980": 533581104, "fan3963": 850651688},
    "windows_setup_exe": {"new": i_new["FantasyDisk-0.3.1-windows-setup.exe"]["size"], "fan3980": i2["FantasyDisk-0.3.1-windows-setup.exe"]["size"], "fan3963": i1["FantasyDisk-0.3.1-windows-setup.exe"]["size"]},
    "macos_dmg": {"new": i_new["FantasyDisk-0.3.1-macos.dmg"]["size"], "fan3980": i2["FantasyDisk-0.3.1-macos.dmg"]["size"], "fan3963": i1["FantasyDisk-0.3.1-macos.dmg"]["size"]},
    "pck_payload_bytes": {"new": mac["payload_bytes"], "fan3980": old3980_win["payload_bytes"], "fan3963": old3963_win["payload_bytes"]},
    "pck_file_count": {"new": mac["file_count"], "fan3980": old3980_win["file_count"], "fan3963": old3963_win["file_count"]},
}
# cold start
rows = {}
for line in (OUT / "cold_start_summary.md").read_text().splitlines():
    m = re.match(r"\| (v0\.3\.\w+) \| (v0[^|]+_run\d\.log) \| ([\d.]+) \| ([\d.]+) \| ([\d.]+) \| (\d+) \| (\d+) \|", line)
    if m:
        rows.setdefault(m.group(1), []).append({"log": m.group(2).strip(), "first_fps_line_s": float(m.group(3)), "first_frame_est_s": float(m.group(4)), "main_gd_s": float(m.group(5)), "actor_spriteframes_before_first_frame": int(m.group(6)), "actor_textures_before_first_frame": int(m.group(7))})
cold = {
    "method": "FAN-3973 method on the exported app binaries (evidence/FAN-3983/measure_cold_start_app.sh): `--print-fps --verbose --quit-after 600`, first `Project FPS` line minus 1 s; 5 back-to-back launches per build; isolated HOME per build; summary via evidence/FAN-3973/analyze_cold_start.py",
    "builds": {"v0.3.0_app": "FantasyDisk.app extracted read-only from the retained releases/v0.3.0 DMG", "v0.3.1new_app": "/Applications/FantasyDisk.app installed by local_release.py from the new retained DMG (file tree == DMG app)"},
    "runs": rows,
    "median_first_frame_s": {k: statistics.median(r["first_frame_est_s"] for r in v) for k, v in rows.items()},
    "min_first_frame_s": {k: min(r["first_frame_est_s"] for r in v) for k, v in rows.items()},
    "max_first_frame_s": {k: max(r["first_frame_est_s"] for r in v) for k, v in rows.items()},
    "actor_spriteframes_before_first_frame_max": {k: max(r["actor_spriteframes_before_first_frame"] for r in v) for k, v in rows.items()},
    "reference_fan3980_app_medians_s": {"v0.3.0_app": 5.47, "fan3980_0.3.1_app": 5.70},
    "reference_fan3964_windows_old_0.3.1_median_s": 17.4,
}
cold["verdict"] = {"new_within_0.5s_of_v0.3.0": abs(cold["median_first_frame_s"]["v0.3.1new_app"] - cold["median_first_frame_s"]["v0.3.0_app"]) <= 0.5}
# combat / M3
HARD = {"p2_48_enemies": 6250, "p3_boss_act1_rift_warden": 5000}
TARGET = {"p2_48_enemies": 5000, "p3_boss_act1_rift_warden": 4000}
runs = []
for jf in sorted((OUT / "perf").glob("new031_*.json")):
    d = json.loads(jf.read_text())
    log = (OUT / "perf" / (jf.stem + ".log")).read_text()
    phases = []
    for p in d["phases"]:
        phases.append({k: p[k] for k in ("phase", "seconds", "avg_fps", "low_1pct_fps", "frames_over_50ms", "frames_over_100ms", "longest_frame_ms", "peak_texture_mib", "objects_peak", "objects_min", "objects_first_second", "objects_last_second", "resident_packs_start", "resident_packs_end", "boss_natural")})
    byp = {p["phase"]: p for p in phases}
    runs.append({
        "label": d["label"], "class": d["character_id"], "weapon": d["weapon_id"], "renderer": d["renderer"], "window": d["window"],
        "boss_mode": "natural" if any(p.get("boss_natural") for p in d["phases"]) else "48-enemy top-up (FAN-3977 default)",
        "act1_peak_texture_mib": round(d["act1_peak_texture_mib"], 1), "act1_peak_objects": d["act1_peak_objects"],
        "menu_texture_mib_before_after": [round(d["menu_texture_mib"], 1), round(d["menu_texture_after_run_mib"], 1)],
        "menu_objects_before_after": [d["menu_objects_before_main"], d["menu_objects_after_run"]], "menu_resident_packs_after_run": d["menu_resident_packs_after_run"],
        "encounter_roster_miss_warnings": log.count("encounter roster miss"), "warning_lines": sum(1 for l in log.splitlines() if l.startswith("WARNING") or "WARNING:" in l),
        "phases": phases,
        "m3": {ph: {"objects_peak": byp[ph]["objects_peak"], "hard_limit": HARD[ph], "within_hard_limit": byp[ph]["objects_peak"] <= HARD[ph], "checklist_target": TARGET[ph], "within_target": byp[ph]["objects_peak"] <= TARGET[ph]} for ph in HARD if ph in byp},
    })
combat = {
    "method": "evidence/FAN-3983/run_combat_check.sh: unchanged evidence/FAN-3981/perf_driver.gd (= FAN-3977 driver + Performance.OBJECT_COUNT per phase) run by the Godot 4.7.stable editor engine binary with --main-pack on the installed app's PCK (exported app binary does not run an external --script), windowed, gl_compatibility, vsync 120 Hz, 2560x1440, isolated HOME per run; route map 8 s -> P2 48 enemies 60 s (every mini-elite kind) -> elite night_stalker 20 s -> P3 act-1 boss rift_warden 60 s -> act-2 boss disk_devourer 20 s -> main menu",
    "driver_sha256": sha(ROOT / "evidence" / "FAN-3981" / "perf_driver.gd"),
    "targets_fan3977": {"synchronous_combat_loads": 0, "act1_peak_texture_mib_max": 1536, "p2_frames_over_100ms": 0},
    "m3_limits": {"hard": HARD, "checklist_target": TARGET},
    "runs": runs,
    "reference_fan3981_qa_numbers": {"source": "FAN-3981 QA PASSED comment 01a0e641-65f9-7838-8417-af81fa8b52ea (reviewer d7bc8435, run 01a0e60c-6f2c-75ef-a361-15c488ac4895), editor project run and exported PCK", "candidate_topup": {"p2": 4042, "p3": 4845, "exported_pck_p2": 4123, "exported_pck_p3": 4808}, "candidate_natural": {"p2": 4023, "p3": 3288}, "v0.3.1_165f14aa_topup": {"p2": 8993, "p3": 7362}, "v0.3.1_165f14aa_natural": {"p2": 9176, "p3": 5677}, "v0.3.0_topup": {"p2": 4363, "p3": 5305}, "v0.3.0_natural": {"p2": 4251, "p3": 3378}, "fan3964_windows_fan3980_package": {"p2": "8643-8719", "p3": 5680}},
    "reference_fan3980_package_metrics": {"berserk_p2_frames_over_100ms": 0, "druid_p2_frames_over_100ms": 0, "act1_peak_texture_mib": {"berserk": 1407, "druid": 1488}},
}
combat["verdict"] = {
    "no_synchronous_combat_loads_all_runs": all(r["encounter_roster_miss_warnings"] == 0 for r in runs),
    "act1_peak_texture_within_1536_mib_all_runs": all(r["act1_peak_texture_mib"] <= 1536 for r in runs),
    "p2_frames_over_100ms_zero_all_runs": all(next(p for p in r["phases"] if p["phase"] == "p2_48_enemies")["frames_over_100ms"] == 0 for r in runs),
    "m3_within_hard_limits_all_runs": all(all(v["within_hard_limit"] for v in r["m3"].values()) for r in runs),
    "m3_within_checklist_targets_per_run": {r["label"]: {k: v["within_target"] for k, v in r["m3"].items()} for r in runs},
}
snap = {"retained_project_vs_git_archive_v0.3.1": (OUT / "snapshot_files_vs_tag.txt").read_text().splitlines(), "changelog_section_equals_tag": True, "poster_sha256_equals_tag_blob": True, "poster_sha256": sha(NEW / "fantasydisk_031_announcement.png")}
ver = json.loads((OUT / "local_release_verify.json").read_text())
plist = lambda k: subprocess.run(["/usr/libexec/PlistBuddy", "-c", f"Print :{k}", "/Applications/FantasyDisk.app/Contents/Info.plist"], capture_output=True, text=True).stdout.strip()
reinstall = {
    "before": {"app_short": "0.3.1", "app_build": "1.3.10", "package": "FAN-3980 attempt 2 (source 165f14aa), file tree == FAN-3980 DMG app", "current_project": "v0.3.1/godot-project (FAN-3980 package)"},
    "after": {"app_short": plist("CFBundleShortVersionString"), "app_build": plist("CFBundleVersion"), "installed_app_equals_new_dmg_app": pck["installed_app_equals_dmg_app"], "current_project": ver.get("current_project"), "local_release_verify": {k: ver.get(k) for k in ("status", "version", "tag_commit", "macos_channel")}},
    "saves_dir": "~/Library/Application Support/Godot/app_userdata/FantasyDisk",
    "save_cfg_files_unchanged": (OUT / "saves_before.sha256").read_bytes() == (OUT / "saves_after_install.sha256").read_bytes() == (OUT / "saves_after_all.sha256").read_bytes(),
    "save_cfg_manifest": (OUT / "saves_before.sha256").read_text().splitlines(),
    "userdata_excluding_logs_shader_cache_vulkan_diff_lines": sum(1 for _ in subprocess.run(["diff", str(OUT / "userdata_before.sha256"), str(OUT / "userdata_after.sha256")], capture_output=True, text=True).stdout.splitlines()),
    "userdata_files_hashed": sum(1 for _ in (OUT / "userdata_before.sha256").open()),
    "note": "same version reinstall 0.3.1 -> 0.3.1 with new bytes; cold-start and perf runs used isolated HOME directories; verify --launch-smoke ran the installed app once with the operator HOME",
}
transfer = {"record": (OUT / "transfer" / "transfer_record.txt").read_text().splitlines(), "readback": "PARTS.sha256 and part-ai downloaded back from FAN-3964 and byte-equal to the local files", "marking": "package review pending"}
extra = {"pck_exclusion": pck, "sizes_vs_old_0.3.1_packages": sizes, "macos_cold_start": cold, "combat_check_fan3977_metrics_and_fan3981_m3": combat, "source_snapshot": snap, "operator_app_reinstall": reinstall, "transfer_fan3964": transfer}
(OUT / "extra_checks.json").write_text(json.dumps(extra, indent=2, ensure_ascii=False) + "\n")
print(json.dumps({"pck_forbidden": pck["forbidden_paths_new_0.3.1"], "tables_identical": pck["macos_windows_file_tables_identical"], "installed==dmg": pck["installed_app_equals_dmg_app"], "cold": cold["median_first_frame_s"], "cold_verdict": cold["verdict"], "combat_verdict": combat["verdict"], "saves_unchanged": reinstall["save_cfg_files_unchanged"], "userdata_diff": reinstall["userdata_excluding_logs_shader_cache_vulkan_diff_lines"], "sizes": sizes}, indent=1))
for r in runs:
    print(r["label"], r["boss_mode"], "tex", r["act1_peak_texture_mib"], "m3", {k: v["objects_peak"] for k, v in r["m3"].items()}, "miss", r["encounter_roster_miss_warnings"], "warn", r["warning_lines"])
