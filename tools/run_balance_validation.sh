#!/bin/zsh
# FAN-1028 Stage 3/4: полный контракт валидации баланса (balance_plan_fan1030.md §4).
# Гоняет ВСЕ балансовые гейты + пересъём живого CSV + матрицу возвышений в
# ИЗОЛИРОВАННОМ worktree (защита от параллельных агентов в живом чекауте).
#
# Использование:
#   zsh tools/run_balance_validation.sh [ref]        # ref по умолчанию origin/dev
#   FSD_SKIP_CSV=1 zsh tools/run_balance_validation.sh   # без 16-минутного CSV
#
# Выход: 0 если все гейты зелёные; лог и сводка в build/qa/fan1028_validation/.

set -u
REF="${1:-origin/dev}"
MAIN_REPO="${FSD_MAIN_REPO:-/Users/sergeyfomin/Documents/AI Agent}"
WT="/private/tmp/fsd_balance_validation"
OUT_DIR="$MAIN_REPO/build/qa/fan1028_validation"
mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.md"

cd "$MAIN_REPO" || exit 2
git fetch origin -q
git worktree remove "$WT" --force 2>/dev/null
git worktree add "$WT" "$REF" >/dev/null || exit 2
HEAD_SHA=$(git -C "$WT" rev-parse --short HEAD)
echo "# Валидация баланса FAN-1028 — $REF @ $HEAD_SHA" > "$SUMMARY"
echo "" >> "$SUMMARY"
echo "| Гейт | Статус | Лог |" >> "$SUMMARY"
echo "| --- | --- | --- |" >> "$SUMMARY"

rsync -a --delete "$MAIN_REPO/.godot/" "$WT/.godot/"
cd "$WT" || exit 2
python3 tools/godot_gate.py --headless --path . --import > "$OUT_DIR/import.log" 2>&1
if [ $? -ne 0 ]; then
	echo "| --import | ❌ FAIL | import.log |" >> "$SUMMARY"
	echo "FATAL: import failed"; exit 1
fi

FAILED=0
run_gate() {
	local name="$1"; local script="$2"; shift 2
	local log="$OUT_DIR/${name}.log"
	python3 tools/godot_gate.py --headless --path . --script "$script" "$@" > "$log" 2>&1
	local code=$?
	# exit 144/247 = коллизия инстансов Godot — один ретрай
	if [ $code -eq 144 ] || [ $code -eq 247 ]; then
		sleep 5
		python3 tools/godot_gate.py --headless --path . --script "$script" "$@" > "$log" 2>&1
		code=$?
	fi
	if [ $code -eq 0 ] && ! grep -qiE "FAILED|FATAL" "$log"; then
		echo "| $name | ✅ PASS | ${name}.log |" >> "$SUMMARY"
	else
		echo "| $name | ❌ FAIL (exit $code) | ${name}.log |" >> "$SUMMARY"
		FAILED=$((FAILED+1))
	fi
}

run_gate balance_harness res://tools/balance_harness.gd
run_gate damage_smoke res://tests/global_damage_balance_smoke_test.gd
run_gate survivability_smoke res://tests/global_survivability_balance_smoke_test.gd
run_gate survivability_harness res://tools/survivability_harness.gd
run_gate survivability_scenario res://tests/survivability_scenario_test.gd
run_gate live_balance_simulation res://tests/live_balance_simulation_test.gd
run_gate berserk_runaway res://tests/berserk_dps_runaway_gate.gd
run_gate pool_dot_runaway res://tests/pool_dot_runaway_gate.gd
run_gate damage_isolation res://tests/damage_type_isolation_test.gd
run_gate ascension_curve res://tests/ascension_curve_balance_test.gd
run_gate runtime_smoke res://tests/runtime_smoke_test.gd
run_gate comfort_band res://tests/comfort_band_cross_class_gate.gd
run_gate ascension_viability res://tests/ascension_viability_gate.gd
run_gate ascension_params_dump res://tools/ascension_params_dump.gd

if [ "${FSD_SKIP_CSV:-0}" != "1" ]; then
	# FAN-1062: живой CSV чанками по 17 пар (~5-7 мин каждый) — целиком ~16 мин
	# не переживает агентские tool-таймауты; band-проверка чанков пропускается
	# (subset-режим), полная полоса судится по merged-CSV python-слоем ниже.
	CSV_OK=1
	rm -f "$OUT_DIR"/csv_chunk_*.csv
	# Чанки ПО КЛАССАМ (17 × ~2-5.5 мин): пул/статус-тяжёлые классы не влезают
	# даже девятью парами в агентские ~10-мин tool-таймауты, а один класс —
	# гарантированно влезает. Ростер зафиксирован контрактными тестами
	# (progression_data_character_contract_test).
	CSV_CLASSES=(berserk soldier thief elementalist sniper priest biologist robot engineer dark_mage guitarist assassin ranger doctor chemist knight druid)
	CSV_I=0
	for CID in "${CSV_CLASSES[@]}"; do
		run_gate "live_csv_${CID}" res://tools/character_balance_csv.gd -- --mode=live --class=${CID}
		if [ -f build/character_balance_dps.csv ]; then
			cp build/character_balance_dps.csv "$OUT_DIR/csv_chunk_$(printf '%02d' ${CSV_I})_${CID}.csv"
		else
			CSV_OK=0
		fi
		CSV_I=$((CSV_I+1))
	done
	python3 - "$OUT_DIR" <<'PYEOF'
import csv, sys, glob
out_dir = sys.argv[1]
rows, header = [], None
for p in sorted(glob.glob(f"{out_dir}/csv_chunk_*.csv")):
	with open(p) as fh:
		r = list(csv.DictReader(fh))
		if r and header is None:
			header = list(r[0].keys())
		rows += r
if header and rows:
	with open("build/character_balance_dps.csv", "w", newline="") as fh:
		w = csv.DictWriter(fh, fieldnames=header); w.writeheader(); w.writerows(rows)
	print(f"merged {len(rows)} rows")
else:
	sys.exit(1)
PYEOF
	if [ $? -ne 0 ] || [ $CSV_OK -ne 1 ]; then
		echo "| live_csv (merge) | ❌ FAIL | csv_chunk_*.csv |" >> "$SUMMARY"
		FAILED=$((FAILED+1))
	else
		echo "| live_csv (3 чанка, merged) | ✅ PASS | csv_chunk_*.csv |" >> "$SUMMARY"
	fi
	cp build/character_balance_dps.csv "$OUT_DIR/character_balance_dps_after.csv" 2>/dev/null
fi

# Python-слой (без Godot): трио-таблица + матрица возвышений на свежих данных worktree
for py in class_trio_table ascension_viability_report; do
	python3 "tools/${py}.py" > "$OUT_DIR/${py}.log" 2>&1
	if [ $? -eq 0 ]; then
		echo "| $py (py) | ✅ PASS | ${py}.log |" >> "$SUMMARY"
	else
		echo "| $py (py) | ❌ FAIL | ${py}.log |" >> "$SUMMARY"
		FAILED=$((FAILED+1))
	fi
done
cp build/class_trio_before_fan1028.md "$OUT_DIR/class_trio_after.md" 2>/dev/null
cp build/ascension_viability_report.md "$OUT_DIR/ascension_viability_after.md" 2>/dev/null

cd "$MAIN_REPO"
git worktree remove "$WT" --force 2>/dev/null
echo "" >> "$SUMMARY"
echo "Итог: $([ $FAILED -eq 0 ] && echo 'ВСЕ ЗЕЛЁНЫЕ ✅' || echo \"КРАСНЫХ: $FAILED ❌\") — $(date '+%Y-%m-%d %H:%M')" >> "$SUMMARY"
cat "$SUMMARY"
exit $([ $FAILED -eq 0 ] && echo 0 || echo 1)
