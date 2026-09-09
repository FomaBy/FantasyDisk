#!/bin/zsh
# FAN-3934 round-5d evidence-owned foreground driver. Records expanded argv,
# environment pins, own process identity, verbatim process-query output
# (excluding this driver's own PIDs) before/during/after every run, and SHA-256
# of every produced file. Foreign processes are observed and preserved, never
# cancelled; the gate's exclusive mode is admission, not workload proof.

set -u
REPO="$1"
OUT="$REPO/evidence/p3-object-budget-rework/round5d"
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
PROBE=res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd
DRIVER_PID=$$

mkdir -p "$OUT"
{
  echo "driver_pid=$DRIVER_PID"
  echo "driver_argv=$0 $*"
  echo "start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "git_head=$(git -C $REPO rev-parse HEAD)"
  echo "git_tree=$(git -C $REPO rev-parse 'HEAD^{tree}')"
  echo "godot=$($GODOT --version)"
  echo "probe_sha256=$(shasum -a 256 $REPO/evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd | awk '{print $1}')"
  echo "env: GODOT_BIN=$GODOT FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT unset (default 3600)"
} > "$OUT/driver-header.txt"

observe() {
  local tag="$1"
  {
    echo "observed_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "ps_query=ps axo pid,pcpu,time,command | grep -i godot | grep -v grep | grep -v godot_gate | grep -v $DRIVER_PID"
    ps axo pid,pcpu,time,command | grep -i godot | grep -v grep | grep -v godot_gate | grep -v $DRIVER_PID || echo "(no foreign godot processes)"
  } >> "$OUT/$tag"
}

start_sampler() {
  ( while true; do
      echo "--- sampled_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      ps axo pid,pcpu,time,command | grep -i godot | grep -v grep | grep -v godot_gate | grep -v $DRIVER_PID || echo "(none)"
      sleep 5
    done ) &
  SAMPLER_PID=$!
}

stop_sampler() {
  kill $SAMPLER_PID 2>/dev/null
  wait $SAMPLER_PID 2>/dev/null
}

run_matrix() {
  local run="$1"; local scenario="$2"
  observe "env-$run.txt"
  start_sampler
  ( cd "$REPO" && FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=$GODOT python3 tools/godot_gate.py --path . --script "$PROBE" -- "$scenario" ) > "$OUT/log-$run.txt" 2>&1
  local status=$?
  stop_sampler
  echo "exit_status=$status" >> "$OUT/log-$run.txt"
  observe "env-$run.txt"
  local lower=$(echo "$scenario" | tr 'A-Z' 'a-z')
  cp "$REPO/evidence/FAN-3877/perf_$lower.json" "$OUT/perf-$run.json"
  cp "$REPO/evidence/FAN-3877/perf_$lower.csv" "$OUT/perf-$run.csv"
  echo "raw_staging_name=perf_$lower.json / perf_$lower.csv (shared staging; disambiguated by manifest)" >> "$OUT/env-$run.txt"
}

run_suite() {
  local name="$1"; local script="$2"
  observe "suite-env-$name.txt"
  ( cd "$REPO" && GODOT_BIN=$GODOT python3 tools/godot_gate.py --headless --path . --script "$script" ) > "$OUT/suite-log-$name.txt" 2>&1
  echo "exit_status=$?" >> "$OUT/suite-log-$name.txt"
  observe "suite-env-$name.txt"
}

run_matrix p3-run1 P3
run_matrix p3-run2 P3
run_matrix p1 P1
run_matrix p2 P2
rm -rf "$REPO/evidence/FAN-3877"

run_suite feedback tests/p3_feedback_allocation_test.gd
run_suite residency tests/p3_executor_residency_test.gd
run_suite summon tests/boss_summon_cap_test.gd
run_suite hazard tests/boss_hazard_cap_gate.gd
run_suite hazardsmoke tests/hazard_vfx_smoke_test.gd
run_suite berserk tests/ultimates/berserk_balance_test.gd

observe "env-final.txt"
{
  echo "end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for f in "$OUT"/perf-*.json "$OUT"/perf-*.csv "$OUT"/log-*.txt "$OUT"/env-*.txt "$OUT"/suite-log-*.txt "$OUT"/suite-env-*.txt "$OUT"/driver-header.txt; do
    echo "$(shasum -a 256 "$f")"
  done
} > "$OUT/file-hashes.txt"
echo "DRIVER COMPLETE"
