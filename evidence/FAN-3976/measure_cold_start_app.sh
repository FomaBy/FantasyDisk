#!/usr/bin/env bash
# FAN-3976 cold-start-to-first-frame measurement of a BUILT macOS app.
# Same method as FAN-3973 `measure_cold_start.sh` / the FAN-3964 review, with the
# exported app binary instead of the editor + project: `--print-fps --verbose
# --quit-after 600`, every output line wall-clock timestamped, first `Project FPS`
# line minus 1 s = first-frame estimate. Summarize with
# `python3 evidence/FAN-3973/analyze_cold_start.py <out_dir>`.
#
# Usage: measure_cold_start_app.sh <label> <app_binary> <runs> <out_dir>
set -euo pipefail
LABEL="$1"; BIN="$2"; RUNS="$3"; OUT="$4"
QUIT_AFTER_FRAMES="${QUIT_AFTER_FRAMES:-600}"
mkdir -p "$OUT"
for i in $(seq 1 "$RUNS"); do
  LOG="$OUT/${LABEL}_run${i}.log"
  START="$(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')"
  echo "START $START" > "$LOG"
  "$BIN" --print-fps --verbose --quit-after "$QUIT_AFTER_FRAMES" 2>&1 \
    | perl -MTime::HiRes=time -pe 'my $t = sprintf("%.3f", time); s/^(.*)$/length($1) ? "$t $1" : $t/e' >> "$LOG" || true
  echo "END $(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')" >> "$LOG"
  sleep 2
done
