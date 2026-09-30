#!/usr/bin/env bash
# FAN-3989 cold-start-to-first-frame measurement (perf checklist M4, P1 main
# menu) of an exported/installed macOS app binary — the FAN-3973 method as
# FAN-3983 applied it to the built app: launch the bundle executable with
# `--print-fps --verbose --quit-after N`, timestamp every output line with
# wall time, take the first `Project FPS` line as "main loop has run for
# ~1 s" and report that time minus 1 s as the first-frame estimate. HOME is
# an isolated directory so the player's real saves/settings are never read
# or written by the measurement.
#
# Usage: measure_cold_start_app.sh <label> <FantasyDisk.app> <runs> <out_dir>
set -euo pipefail
LABEL="$1"
APP="$2"
RUNS="$3"
OUT="$4"
QUIT_AFTER_FRAMES="${QUIT_AFTER_FRAMES:-600}"
BIN="${APP}/Contents/MacOS/FantasyDisk"
if [[ ! -x "${BIN}" ]]; then
  echo "ERROR: ${BIN} is not executable" >&2
  exit 2
fi
mkdir -p "${OUT}"
ISOLATED_HOME="$(mktemp -d "${TMPDIR:-/tmp}/fan3989-coldstart-home-XXXXXX")"
echo "isolated HOME ${ISOLATED_HOME}"
for i in $(seq 1 "${RUNS}"); do
  LOG="${OUT}/${LABEL}_run${i}.log"
  START="$(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')"
  echo "START ${START}" > "${LOG}"
  HOME="${ISOLATED_HOME}" "${BIN}" --print-fps --verbose --quit-after "${QUIT_AFTER_FRAMES}" 2>&1 \
    | perl -MTime::HiRes=time -pe 'my $t = sprintf("%.3f", time); s/^(.*)$/length($1) ? "$t $1" : $t/e' >> "${LOG}" || true
  echo "END $(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')" >> "${LOG}"
  sleep 2
done
rm -rf "${ISOLATED_HOME}"
