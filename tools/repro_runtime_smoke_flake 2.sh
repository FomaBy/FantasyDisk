#!/usr/bin/env bash
# SCRUM-257: ловушка редкого интермиттентного падения umbrella runtime_smoke +
# предупреждения `Lambda capture ... was freed`. Гоняет runtime_smoke до N раз;
# при первом прогоне, где появилось предупреждение/падение, сохраняет ПОЛНЫЙ
# вывод (с backtrace) в build/qa/ и останавливается. Иначе сообщает flake-rate.
#
# Использование:
#   tools/repro_runtime_smoke_flake.sh [N]     # N прогонов (по умолчанию 40)
#   GODOT=/path/to/Godot tools/repro_runtime_smoke_flake.sh 100
#   STOP_ON_HIT=0 ...                          # не останавливаться, прогнать все N
#
# Exit 0 если поймал репро (backtrace сохранён) или все зелёные; 2 — нет Godot.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}"
N="${1:-40}"
STOP_ON_HIT="${STOP_ON_HIT:-1}"
OUTDIR="$ROOT/build/qa"
SCRIPT="res://tests/runtime_smoke_test.gd"

if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: Godot не найден/не исполняем: $GODOT" >&2
	exit 2
fi
mkdir -p "$OUTDIR"

# Паттерны «что-то пошло не так»: freed-лямбда, падение _fail/push_error, parse.
BAD='Lambda capture|was freed|previously freed|SCRIPT ERROR|Expected |_fail|Parse Error'

pass=0; hits=0; first_hit=""
echo "Repro runtime_smoke flake: до $N прогонов через $GODOT"
echo "-------------------------------------------------------------"
for i in $(seq 1 "$N"); do
	out="$("$GODOT" --headless --path "$ROOT" --script "$SCRIPT" 2>&1)"
	if echo "$out" | grep -qE "$BAD"; then
		hits=$((hits + 1))
		log="$OUTDIR/smoke_flake_run_${i}.log"
		printf '%s\n' "$out" > "$log"
		echo "run $i: ⚠ ПОЙМАНО — лог: ${log#$ROOT/}"
		echo "$out" | grep -iE 'Lambda capture|was freed|SCRIPT ERROR|Expected ' | head -4 | sed 's/^/    /'
		[[ -z "$first_hit" ]] && first_hit="$i"
		if [[ "$STOP_ON_HIT" == "1" ]]; then
			echo "-------------------------------------------------------------"
			echo "Остановлено на первом репро (run $i). Полный backtrace: ${log#$ROOT/}"
			exit 0
		fi
	else
		pass=$((pass + 1))
		printf 'run %d: ok\r' "$i"
	fi
done
echo ""
echo "-------------------------------------------------------------"
echo "Итог: $pass зелёных, $hits с проблемой из $N."
if [[ $hits -eq 0 ]]; then
	echo "Репро не пойман за $N прогонов — флейк реже 1/$N."
fi
exit 0
