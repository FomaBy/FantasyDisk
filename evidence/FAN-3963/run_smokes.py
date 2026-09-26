import hashlib, json, subprocess, sys, time, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "FAN-3963"
MARKERS = {
    "runtime_smoke_test": "Runtime smoke test passed.",
    "runtime_smoke_ui_test": "Runtime UI smoke suite passed.",
    "runtime_smoke_combat_test": "Runtime combat smoke suite passed.",
    "runtime_smoke_progression_economy_test": "Runtime progression/economy smoke suite passed.",
    "runtime_smoke_weapon_mechanics_test": "Runtime weapon mechanics smoke suite passed.",
    "runtime_smoke_boss_elite_test": "Runtime boss/elite smoke suite passed.",
}
results = []
def run(name, cmd, marker=None):
    log = OUT / f"{name}.log"
    t0 = time.monotonic()
    with open(log, "wb") as fh:
        p = subprocess.run(cmd, cwd=ROOT, stdout=fh, stderr=subprocess.STDOUT)
    dur = round(time.monotonic() - t0, 2)
    data = log.read_bytes()
    text = data.decode("utf-8", "replace")
    entry = {"name": name, "command": " ".join(cmd), "exit_code": p.returncode,
             "duration_seconds": dur, "log": f"build/FAN-3963/{name}.log",
             "log_size": len(data), "log_sha256": hashlib.sha256(data).hexdigest()}
    if marker:
        entry["pass_marker"] = marker
        entry["marker_found"] = marker in text
        entry["script_error_lines"] = sum(1 for l in text.splitlines() if "SCRIPT ERROR" in l)
        entry["error_lines"] = [l.strip() for l in text.splitlines() if l.startswith("ERROR:")][:20]
        entry["passed"] = p.returncode == 0 and marker in text and entry["script_error_lines"] == 0
    results.append(entry)
    print(f"[{name}] exit={p.returncode} dur={dur}s marker={entry.get('marker_found')} script_errors={entry.get('script_error_lines')}", flush=True)
    (OUT / "smoke_outputs.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
run("import_prepass", [sys.executable, "tools/godot_gate.py", "--headless", "--path", ".", "--ensure-import-cache"])
for name, marker in MARKERS.items():
    run(name, [sys.executable, "tools/godot_gate.py", "--headless", "--path", ".", "--script", f"res://tests/{name}.gd"], marker)
ok = all(r.get("passed", r["exit_code"] == 0) for r in results)
print("ALL_SMOKES_PASSED" if ok else "SMOKES_FAILED", flush=True)
