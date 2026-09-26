#!/usr/bin/env bash
# FAN-3973 cold-start-to-first-frame measurement (perf checklist M4, P1 main menu).
#
# Same method as the FAN-3964 Windows review: launch the project with
# `--print-fps --verbose`, timestamp every stdout/stderr line with wall time,
# take the first `Project FPS` line as "main loop has run for ~1 s" and report
# that time minus 1 s as the first-frame estimate. The verbose trace also lists
# every resource load, so analyze_cold_start.py can count actor full-frame
# SpriteFrames/.ctex loads that happened before the first frame.
#
# Usage: measure_cold_start.sh <label> <project_dir> <runs> <out_dir>
set -euo pipefail
LABEL="$1"
PROJECT="$2"
RUNS="$3"
OUT="$4"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
QUIT_AFTER_FRAMES="${QUIT_AFTER_FRAMES:-600}"
mkdir -p "$OUT"
for i in $(seq 1 "$RUNS"); do
  LOG="$OUT/${LABEL}_run${i}.log"
  START="$(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')"
  echo "START $START" > "$LOG"
  "$GODOT_BIN" --path "$PROJECT" --print-fps --verbose --quit-after "$QUIT_AFTER_FRAMES" 2>&1 \
    | perl -MTime::HiRes=time -pe 'my $t = sprintf("%.3f", time); s/^(.*)$/length($1) ? "$t $1" : $t/e' >> "$LOG" || true
  echo "END $(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')" >> "$LOG"
  sleep 2
done
