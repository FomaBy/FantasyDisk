#!/usr/bin/env bash
# Прогон всех standalone smoke/integrity тестов (tests/*.gd, extends SceneTree)
# headless через Godot, со сводкой pass/fail. Каждый тест — отдельный SceneTree
# со своим quit(0/1); процессный exit-код = вердикт.
#
# Использование:
#   tools/run_focused_tests.sh                 # все standalone тесты
#   tools/run_focused_tests.sh codex_data event_data   # только совпадающие по имени
#   GODOT=/path/to/Godot tools/run_focused_tests.sh     # переопределить движок
#
# Exit 0 если все зелёные, 1 если есть падения/ошибки запуска.
# Зонтичный tests/runtime_smoke_test.gd ВКЛЮЧЁН; пропустить — SKIP_UMBRELLA=1.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: Godot не найден/не исполняем: $GODOT (переопредели через GODOT=...)" >&2
	exit 2
fi

# Собираем standalone-тесты: tests/*.gd, содержащие 'extends SceneTree'.
# Портативно (без mapfile — macOS bash 3.2): read-loop через process substitution.
ALL_TESTS=()
while IFS= read -r f; do
	[[ -n "$f" ]] && ALL_TESTS+=("$f")
done < <(grep -lE '^extends SceneTree' "$ROOT"/tests/*.gd 2>/dev/null | sort)

if [[ ${#ALL_TESTS[@]} -eq 0 ]]; then
	echo "Не найдено standalone-тестов в $ROOT/tests/." >&2
	exit 2
fi

# Фильтр по аргументам (подстрока имени) + опциональный пропуск зонтика.
TESTS=()
for path in "${ALL_TESTS[@]}"; do
	name="$(basename "$path" .gd)"
	if [[ "${SKIP_UMBRELLA:-0}" == "1" && "$name" == "runtime_smoke_test" ]]; then
		continue
	fi
	if [[ $# -gt 0 ]]; then
		match=0
		for pat in "$@"; do
			[[ "$name" == *"$pat"* ]] && match=1
		done
		[[ $match -eq 1 ]] || continue
	fi
	TESTS+=("$path")
done

if [[ ${#TESTS[@]} -eq 0 ]]; then
	echo "Нет тестов для запуска (фильтр: $*)." >&2
	exit 2
fi

echo "Прогон ${#TESTS[@]} тест(ов) через $GODOT"
echo "-------------------------------------------------------------"

PASS=0
FAIL=0
FAILED_NAMES=()
START=$(date +%s)

for path in "${TESTS[@]}"; do
	name="$(basename "$path" .gd)"
	rel="res://tests/$(basename "$path")"
	out="$("$GODOT" --headless --path "$ROOT" --script "$rel" 2>&1)"
	code=$?
	if [[ $code -eq 0 ]]; then
		PASS=$((PASS + 1))
		printf 'PASS  %s\n' "$name"
	else
		FAIL=$((FAIL + 1))
		FAILED_NAMES+=("$name")
		# Первая строка push_error/SCRIPT ERROR для контекста.
		reason="$(printf '%s\n' "$out" | grep -iE 'SCRIPT ERROR|push_error|: [0-9]+ ошибок|FAIL' | head -1)"
		printf 'FAIL  %s  (exit %d) %s\n' "$name" "$code" "$reason"
	fi
done

ELAPSED=$(( $(date +%s) - START ))
echo "-------------------------------------------------------------"
echo "Итог: $PASS зелёных, $FAIL падений из ${#TESTS[@]} (${ELAPSED}s)."
if [[ $FAIL -gt 0 ]]; then
	echo "Упали: ${FAILED_NAMES[*]}"
	exit 1
fi
echo "Все тесты зелёные."
exit 0
