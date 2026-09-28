#!/usr/bin/env bash
# FAN-3980 AC3 scripted combat check of the BUILT 0.3.1 bytes with the FAN-3977
# metrics. The exported app does not run an external `--script` (probe hung), so
# the editor engine binary runs the retained/installed PCK (`--main-pack`, the
# FAN-3973 exported_pack_probe approach) with the unchanged FAN-3977 perf driver
# (`evidence/FAN-3977/perf_driver.gd`), windowed on the real GL Compatibility
# renderer, isolated HOME so the operator's saves are never touched.
#
# Usage: run_combat_check.sh <label> <FantasyDisk.pck> <out_dir> [class weapon]
set -euo pipefail
LABEL="$1"; PCK="$2"; OUT="$3"; CLASS="${4:-berserk}"; WEAPON="${5:-sword}"
GODOT_BIN="${GODOT_BIN:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="${ROOT}/evidence/FAN-3977/perf_driver.gd"
mkdir -p "$OUT" "$OUT/home_${LABEL}"
export HOME="$OUT/home_${LABEL}"
"$GODOT_BIN" --main-pack "$PCK" --script "$DRIVER" -- "label=${LABEL}" "out=${OUT}" "class=${CLASS}" "weapon=${WEAPON}" > "$OUT/${LABEL}.log" 2>&1 || true
echo "exit_recorded=$?"
grep -c "encounter roster miss" "$OUT/${LABEL}.log" || true
