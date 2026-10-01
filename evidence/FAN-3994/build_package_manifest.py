#!/usr/bin/env python3
"""FAN-3994: assemble package_manifest.json from the collected evidence files
in this directory (run after every measurement has landed).

Usage: build_package_manifest.py [--retained /Users/.../releases/v0.3.1.2]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VERSION = "0.3.1.2"
TAG = f"v{VERSION}"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_optional(path: Path):
    return load(path) if path.is_file() else None


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--retained", type=Path, default=Path(f"/Users/sergeyfomin/FantasyDisk/releases/{TAG}"))
    args = parser.parse_args()
    retained = args.retained
    local_release = load(retained / "LOCAL_RELEASE.json")
    fresh_inventory = {}
    for name in sorted(p.name for p in retained.iterdir() if p.is_file() and p.name != ".DS_Store"):
        fresh_inventory[name] = {"size": (retained / name).stat().st_size, "sha256": sha256(retained / name)}
    recorded = local_release["package_inventory"]
    inventory_matches = all(fresh_inventory[k]["sha256"] == v["sha256"] and fresh_inventory[k]["size"] == v["size"] for k, v in recorded.items())

    ls_remote_before = (HERE / "package" / "ls_remote_before_build.txt").read_text()
    ls_remote_after = (HERE / "package" / "ls_remote_after_build.txt").read_text()
    build_log = (HERE / "package" / "run_build.stdout.log").read_text()
    started = re.search(r"build start (\S+)", build_log)
    ended = re.search(r"build end (\S+) exit (\d+)", build_log)

    probe = load(HERE / "installed_app_probe" / "export_probe_summary.json")
    probe_report = load(HERE / "installed_app_probe" / "export_probe_probe_report.json")
    pairs = probe_report["pairs"]
    player_path = load(HERE / "installed_app_probe" / "export_probe_player_path.json")
    pck_compare = load(HERE / "pck_tables_macos_vs_windows.json")
    hash_proof = load(HERE / "package" / "hash_difference_proof.json")
    transfer = load(HERE / "transfer" / "fan3990_transfer_post.json")
    menu = load_optional(HERE / "main_menu" / "main_menu_capture.json") or {}

    sessions = {}
    for summary in sorted((HERE / "session").glob("*/*_summary.json")):
        data = load(summary)
        sessions[summary.parent.name] = {
            "pass": data["pass"], "mode": data["mode"], "windowed": data["windowed"], "probe": data["probe"],
            "clone_pck_identical": data["source_pck_sha256"] == data["clone_pck_sha256"],
            "sequences": [{k: s.get(k) for k in ("sequence", "exit_code", "timed_out", "seconds", "pairs_total", "pairs_passing", "report_pass",
                                                  "display_server", "peak_object_count", "problems")}
                          | {"lifecycle_errors_engine_log": s["engine_log_scan"]["total"], "lifecycle_errors_stdout": s["stdout_scan"]["total"]}
                          for s in data["sequences"]],
        }
    perf = {}
    for summary in sorted((HERE / "perf").glob("*/*_summary.json")):
        perf[summary.stem.replace("_summary", "")] = load(summary)
    cold = load_optional(HERE / "cold_start" / "cold_start_summary.json") or {}

    saves_dir = HERE / "saves"
    saves_before = (saves_dir / "user_data_before_build.sha256").read_bytes()
    saves_after_install = (saves_dir / "user_data_after_install.sha256").read_bytes()
    saves_reinstall_before = (saves_dir / "user_data_before_reinstall.sha256").read_bytes()
    saves_reinstall_after = (saves_dir / "user_data_after_reinstall.sha256").read_bytes()
    saves_final = (saves_dir / "user_data_after_all_measurements.sha256").read_bytes() if (saves_dir / "user_data_after_all_measurements.sha256").is_file() else None
    preservation_final = HERE / "preservation" / "preservation_diff_final.txt"

    manifest = {
        "issue": "FAN-3994",
        "version": VERSION,
        "source": {
            "tag": TAG,
            "tag_object": git("rev-parse", TAG),
            "tag_commit": git("rev-parse", f"{TAG}^{{commit}}"),
            "tag_tree": git("rev-parse", f"{TAG}^{{tree}}"),
            "ls_remote_unchanged_across_build": ls_remote_before == ls_remote_after,
            "ls_remote": ls_remote_after.strip().splitlines(),
        },
        "build": {
            "command": f"tools/build_release.sh {VERSION} (FANTASYDISK_MACOS_CHANNEL=signed, MACOS_NOTARY_PROFILE=FantasyDiskRelease, MACOS_SIGN_IDENTITY resolved locally) via evidence/FAN-3994/run_build.sh",
            "started_utc": started.group(1) if started else None,
            "ended_utc": ended.group(1) if ended else None,
            "exit_code": int(ended.group(2)) if ended else None,
            "sanitized_log": "build_release.sanitized.log",
            "sanitized_log_sha256": sha256(HERE / "build_release.sanitized.log"),
        },
        "retained_package": {
            "path": str(retained),
            "macos_channel": local_release["macos_channel"],
            "tag_commit": local_release["tag_commit"],
            "source_tree_sha256": local_release["source_tree_sha256"],
            "inventory": fresh_inventory,
            "inventory_matches_LOCAL_RELEASE": inventory_matches,
            "LOCAL_RELEASE_sha256": sha256(retained / "LOCAL_RELEASE.json"),
            "project_snapshot_equals_git_archive": "diff -rq exit 0" in (HERE / "package" / "project_vs_git_archive.txt").read_text(),
            "update_manifest_consistent": "update-manifest consistent: True" in (HERE / "package" / "update_manifest_check.txt").read_text(),
            "local_release_verify": load(HERE / "package" / "local_release_verify.txt"),
        },
        "hash_difference": {
            "all_built_artifacts_differ_from_every_retained_package": hash_proof["all_built_artifacts_differ"],
            "installer_collisions": hash_proof["installer_collisions"],
            "collisions": hash_proof["collisions"],
        },
        "preservation": {
            "summary": (HERE / "preservation" / "README.md").read_text(),
            "diff_after_build_bytes": (HERE / "preservation" / "preservation_diff_after_build.txt").stat().st_size,
            "diff_final_bytes": preservation_final.stat().st_size if preservation_final.is_file() else None,
        },
        "installed_app": {
            "path": "/Applications/FantasyDisk.app",
            "files": {line.split("  ", 1)[1]: line.split("  ", 1)[0] for line in (HERE / "package" / "installed_app.sha256").read_text().splitlines()},
            "equals_dmg_app": (HERE / "package" / "installed_app.sha256").read_bytes() == (HERE / "package" / "dmg_app.sha256").read_bytes(),
            "trust_checks": "package/trust_checks.txt",
            "main_menu": menu,
        },
        "pck": {
            "macos_installed_sha256": pck_compare["macos_pck"]["sha256"],
            "macos_entries": pck_compare["macos_pck"]["entry_count"],
            "presentation_documents": len(pck_compare["macos_pck"]["presentation_documents"]),
            "forbidden_entries_macos": len(pck_compare["macos_pck"]["forbidden_entries"]),
            "forbidden_entries_windows": len(pck_compare["windows_embedded_pck"]["forbidden_entries"]),
            "windows_embedded": {k: pck_compare["windows_embedded_pck"][k] for k in ("exe_size", "pck_offset", "pck_size", "pck_sha256", "entry_count")},
            "windows_exe_sha256": (HERE / "package" / "windows_exe_sha256.txt").read_text().split()[0],
            "tables_identical_by_path": pck_compare["tables_identical_by_path"],
            "content_sample_md5_mismatches": pck_compare["content_sample_md5_mismatches"],
        },
        "installed_app_probe": {
            "pass": probe["pass"],
            "duration_seconds": probe["duration_seconds"],
            "probe_input_pck_sha256": probe["export"]["pck_sha256"],
            "headless_pairs_passing": f"{probe['headless_probe']['pairs_passing']}/{probe['headless_probe']['pairs']}",
            "resolution_sources": {s: sum(1 for p in pairs if p.get("resolution_source") == s) for s in sorted({p.get("resolution_source") for p in pairs})},
            "begin_ok_all": all(p.get("begin_ok") for p in pairs),
            "scene_paths_class_owned_all": all(str(p.get("scene_path", "")).startswith("res://scenes/vfx/ultimates/" + p["key"].split("/")[0] + "/") for p in pairs),
            "mutations": [{"name": m["name"], "exit_code": m["exit_code"], "pairs_passing": m["pairs_passing"], "problems": m["problems"]} for m in probe["mutations"]],
            "player_path": {"pairs_passing": player_path["pairs_passing"], "pairs": len(player_path["pairs"]), "crashes": player_path["crashes"], "captures": len([c for c in player_path["captures"] if c["pass"]])},
            "presentation_captures": probe["captures"]["files"],
        },
        "long_session_fan3991": sessions,
        "perf": perf,
        "cold_start": cold,
        "saves": {
            "user_data_dir": "~/Library/Application Support/Godot/app_userdata/FantasyDisk (logs/, shader_cache/, vulkan/ excluded)",
            "files_before_build": len(saves_before.splitlines()),
            "unchanged_after_install_and_launch_smoke": saves_before == saves_after_install,
            "difference_after_install": (HERE / "saves" / "diff_before_build_vs_after_install.txt").read_text(),
            "controlled_reinstall_test": "saves/reinstall_test.log",
            "unchanged_across_controlled_reinstall_and_launch_smoke": saves_reinstall_before == saves_reinstall_after,
            "unchanged_after_all_measurements_vs_reinstall_baseline": (saves_reinstall_before == saves_final) if saves_final is not None else None,
        },
        "transfer_fan3990": transfer,
    }
    (HERE / "package_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({k: manifest[k] for k in ("source", "build", "hash_difference", "saves")}, indent=2, ensure_ascii=False))
    print("inventory_matches_LOCAL_RELEASE", inventory_matches, "probe pass", probe["pass"], "pck pass", pck_compare["pass"], "sessions", {k: v["pass"] for k, v in sessions.items()})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
