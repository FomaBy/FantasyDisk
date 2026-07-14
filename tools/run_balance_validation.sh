#!/bin/zsh
# FAN-1028 Stage 3/4: полный контракт валидации баланса (balance_plan_fan1030.md §4).
# Гоняет ВСЕ балансовые гейты + пересъём живого CSV + матрицу возвышений в
# ИЗОЛИРОВАННОМ worktree (защита от параллельных агентов в живом чекауте).
#
# Использование:
#   zsh tools/run_balance_validation.sh [ref]        # ref по умолчанию origin/dev
#   FSD_FULL_CSV=1 zsh tools/run_balance_validation.sh   # + живой пересъём CSV
#
# FAN-1062 (процессное решение координатора): живой пересъём CSV НЕ входит в
# QA-контракт по умолчанию — это инструмент КАЛИБРОВОЧНОЙ полосы (медленные
# среды не тянут тяжёлые пары: biologist 12+ мин/класс даже локально).
# Приёмочный CSV зафиксирован в git (среднее ≥2 прогонов, см. no-silent-retune
# лог) и валидируется в контракте: ascension_viability_gate (пороги DoD) +
# python трио-отчёт + инвариант 51 строки. Пересъём — FSD_FULL_CSV=1.
#
# Выход: 0 если все гейты зелёные; лог и сводка в build/qa/fan1028_validation/.

set -u
REF="${1:-origin/dev}"
MAIN_REPO="${FSD_MAIN_REPO:-/Users/sergeyfomin/Documents/AI Agent}"
# FAN-1062: уникальные пути на запуск — два параллельных контракта (QA-лейн +
# калибровочный) не должны сносить worktree/логи друг друга.
RUN_TAG="$$_$(date +%H%M%S)"
WT="/private/tmp/fsd_balance_validation_${RUN_TAG}"
OUT_DIR="$MAIN_REPO/build/qa/fan1028_validation_${RUN_TAG}"
mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.md"

cd "$MAIN_REPO" || exit 2
git fetch origin -q
git worktree remove "$WT" --force 2>/dev/null
git worktree prune 2>/dev/null
rm -rf "$WT" 2>/dev/null
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
# FAN-1062: watchdog — ни один гейт не держит контракт бесконечно. Повисший
# Godot убивается по порогу (FSD_GATE_TIMEOUT, сек; дефолт 480) и гейт честно
# краснеет строкой в сводке вместо вечного 100% CPU.
# Дефолт 570с: худшая CSV-пара (biologist spore, пул/статус-энтити-шторм на
# 20 бессмертных болванках) ≈ 5 мин локально, ~7 на медленной среде.
GATE_TIMEOUT="${FSD_GATE_TIMEOUT:-570}"
run_with_watchdog() {
	local log="$1"; shift
	"$@" > "$log" 2>&1 &
	local pid=$!
	local waited=0
	while kill -0 $pid 2>/dev/null; do
		if [ $waited -ge $GATE_TIMEOUT ]; then
			pkill -9 -P $pid 2>/dev/null
			kill -9 $pid 2>/dev/null
			echo "[watchdog] превышен порог ${GATE_TIMEOUT}с — процесс убит" >> "$log"
			wait $pid 2>/dev/null
			return 124
		fi
		sleep 5
		waited=$((waited+5))
	done
	wait $pid
	return $?
}
run_gate() {
	local name="$1"; local script="$2"; shift 2
	local log="$OUT_DIR/${name}.log"
	run_with_watchdog "$log" python3 tools/godot_gate.py --headless --path . --script "$script" "$@"
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

if [ "${FSD_FULL_CSV:-0}" = "1" ]; then
	# FAN-1062: живой CSV чанками по 17 пар (~5-7 мин каждый) — целиком ~16 мин
	# не переживает агентские tool-таймауты; band-проверка чанков пропускается
	# (subset-режим), полная полоса судится по merged-CSV python-слоем ниже.
	CSV_OK=1
	rm -f "$OUT_DIR"/csv_chunk_*.csv 2>/dev/null || true
	# FAN-1062: чанки ПО ПАРАМ (51 × ~0.5-3 мин, худшая пара — пул/статус 20t).
	# Классовые чанки не влезали в порог на медленных средах (biologist >15 мин
	# у QA). Каждая пара + watchdog = контракт строго ограничен по времени.
	# Ростер зафиксирован progression_data_character_contract_test.
	CSV_I=0
	while [ $CSV_I -lt 51 ]; do
		run_gate "live_csv_row$(printf '%02d' ${CSV_I})" res://tools/character_balance_csv.gd -- --mode=live --offset=${CSV_I} --limit=1
		if [ -f build/character_balance_dps.csv ]; then
			cp build/character_balance_dps.csv "$OUT_DIR/csv_chunk_$(printf '%02d' ${CSV_I}).csv"
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
		echo "| live_csv (51 per-pair чанк, merged) | ✅ PASS | csv_chunk_*.csv |" >> "$SUMMARY"
	fi
	cp build/character_balance_dps.csv "$OUT_DIR/character_balance_dps_after.csv" 2>/dev/null
fi

# Инвариант приёмочного CSV (всегда): 51 строка, ideal-значения ненулевые.
python3 - <<'PYEOF'
import csv, sys
rows = list(csv.DictReader(open("build/character_balance_dps.csv")))
bad = [r for r in rows if float(r["lvl20_ideal_1t"]) <= 0 and float(r["lvl20_ideal_20t"]) <= 0]
sys.exit(0 if len(rows) == 51 and not bad else 1)
PYEOF
if [ $? -eq 0 ]; then
	echo "| csv_integrity (51 строка, ненулевые) | ✅ PASS | — |" >> "$SUMMARY"
else
	echo "| csv_integrity | ❌ FAIL | — |" >> "$SUMMARY"
	FAILED=$((FAILED+1))
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
git worktree prune 2>/dev/null
rm -rf "$WT" 2>/dev/null
echo "" >> "$SUMMARY"
echo "Итог: $([ $FAILED -eq 0 ] && echo 'ВСЕ ЗЕЛЁНЫЕ ✅' || echo \"КРАСНЫХ: $FAILED ❌\") — $(date '+%Y-%m-%d %H:%M')" >> "$SUMMARY"
cat "$SUMMARY"
exit $([ $FAILED -eq 0 ] && echo 0 || echo 1)
