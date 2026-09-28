#!/usr/bin/env bash
# FAN-3983 AC3 scripted combat check of the BUILT 0.3.1 bytes with the FAN-3977
# metrics plus the FAN-3981 M3 object count. The exported app does not run an
# external `--script` (FAN-3980 probe hung), so the Godot 4.7 editor engine binary
# runs the installed app's PCK (`--main-pack`, the FAN-3973 exported_pack_probe
# approach) with the unchanged FAN-3981 perf driver
# (`evidence/FAN-3981/perf_driver.gd` = FAN-3977 driver + per-phase
# Performance.OBJECT_COUNT), windowed on the real GL Compatibility renderer,
# isolated HOME so the operator's saves are never touched.
#
# Usage: run_combat_check.sh <label> <FantasyDisk.pck> <out_dir> [class weapon] [boss=natural]
set -euo pipefail
LABEL="$1"; PCK="$2"; OUT="$3"; CLASS="${4:-berserk}"; WEAPON="${5:-sword}"; BOSS="${6:-}"
GODOT_BIN="${GODOT_BIN:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="${ROOT}/evidence/FAN-3981/perf_driver.gd"
mkdir -p "$OUT" "$OUT/home_${LABEL}"
export HOME="$OUT/home_${LABEL}"
ARGS=("label=${LABEL}" "out=${OUT}" "class=${CLASS}" "weapon=${WEAPON}")
[[ -n "$BOSS" ]] && ARGS+=("$BOSS")
"$GODOT_BIN" --main-pack "$PCK" --script "$DRIVER" -- "${ARGS[@]}" > "$OUT/${LABEL}.log" 2>&1 || true
echo "exit_recorded=$?"
echo "roster_miss_lines=$(grep -c 'encounter roster miss' "$OUT/${LABEL}.log" || true)"
