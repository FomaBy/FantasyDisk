#!/usr/bin/env python3
"""FAN-1039: устойчивый runaway-гейт берсерка (медиана N изолированных прогонов).

Живой замер DPS берсерка (tests/berserk_dps_runaway_gate.gd) детерминирован ВНУТРИ
одного процесса, но имеет неустранимый межпроцессный разброс дискретными «полками»:
число полных слэмов в 24-с окне и редкий геометрический режим (внешние дамми
попадают в полный тир diminish) задаются стартовым сабкадровым джиттером процесса.
Из-за этого ОДИН прогон гейтить нельзя — потолок FAN-1034 (4400) пробивался шумом
в ~40% прогонов БЕЗ изменений кода (см. FAN-1039).

Решение (usаaverаging N прогонов): гоняем замер GATE_RUNS раз в ИЗОЛИРОВАННЫХ
процессах через godot_gate (по одному инстансу Godot), берём МЕДИАНУ 20t и 1t и
судим её по потолку. Медиана отбрасывает и «просадочные» (−13%), и редкие «полки»
(+70% геометрия) — устойчивое число. Потолок откалиброван от медианы чистого dev
с запасом, который ловит runaway множителей/экспонент (+30% к базе): это НЕ
маскировка завышением потолка, а честная перекалибровка после починки замера
(старая база 3950 была артефактом — 480 idle-кадров покрывали доли 8с, но делились
на жёсткие 8.0; чинёный замер меряет истинный sustained DPS).

Обязателен --fixed-fps 60: фиксирует кадровую дельту, иначе headless-цикл ломает
детерминизм физики/твинов.

Запуск:
    python3 tools/berserk_runaway_gate.py
Env:
    FSD_RUNAWAY_RUNS   число изолированных прогонов (по умолчанию 13, нечётное)
    GODOT_BIN / FSD_GODOT_SLOTS — как в tools/godot_gate.py
"""
from __future__ import annotations

import os
import re
import statistics
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GATE_SCRIPT = "res://tests/berserk_dps_runaway_gate.gd"
SAMPLE_RE = re.compile(r"RUNAWAY_SAMPLE\s+20t=([0-9.]+)\s+1t=([0-9.]+)")

# Нечётное число прогонов: медиана — центральный элемент. 15 надёжно отбрасывает
# 20t-«геометрический режим» (внешние дамми в полном тире, наблюдался в ~10-23%
# прогонов, ×1.7) — чтобы сдвинуть медиану, его нужно в >7 из 15 прогонов.
GATE_RUNS = int(os.getenv("FSD_RUNAWAY_RUNS", "15"))

# Потолки по МЕДИАНЕ (не по одиночному прогону). Откалибровано от чистого origin/dev
# (FAN-1039): медиана 20t≈9050 (полка 9048, детерминирована), 1t≈1132. Запас ~+10%.
# Проверено: инфляция урона молота на +30% (damage_multiplier 0.55→0.715) поднимает
# медиану 20t до 10221 (>потолка) — runaway ловится; чистый dev проходит.
# 1t-ось чище (без геометрического режима), потому потолок теснее — независимый
# сигнал на случай, если 20t-медиана изредка уходит в полку. Правишь оружие/пул —
# перекалибруй ОБА по свежей медиане (см. заголовок гейта).
MAX_MEDIAN_20T = 10000.0
MAX_MEDIAN_1T = 1250.0
ZERO_EPS = 0.01


def _run_once(index: int) -> tuple[float, float] | None:
    """Один изолированный прогон замера; возвращает (dps_20t, dps_1t) или None."""
    cmd = [
        sys.executable, os.path.join(HERE, "godot_gate.py"),
        "--headless", "--fixed-fps", "60",
        "--path", REPO, "--script", GATE_SCRIPT,
    ]
    proc = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
    out = proc.stdout + "\n" + proc.stderr
    match = None
    for line in out.splitlines():
        m = SAMPLE_RE.search(line)
        if m:
            match = m
    if match is None:
        sys.stderr.write(
            f"berserk_runaway_gate: прогон {index} не дал RUNAWAY_SAMPLE (rc={proc.returncode})\n"
        )
        # Хард-фейл гейта в замере (сломанный режим оружия) — тоже сигнал.
        tail = "\n".join(out.strip().splitlines()[-8:])
        sys.stderr.write(tail + "\n")
        return None
    return float(match.group(1)), float(match.group(2))


def main() -> int:
    samples_20t: list[float] = []
    samples_1t: list[float] = []
    for i in range(1, GATE_RUNS + 1):
        result = _run_once(i)
        if result is None:
            continue
        dps_20t, dps_1t = result
        samples_20t.append(dps_20t)
        samples_1t.append(dps_1t)
        print(f"  run {i:2d}/{GATE_RUNS}: 20t={dps_20t:8.1f}  1t={dps_1t:7.1f}")

    # Нужно большинство валидных прогонов, чтобы медиана была осмысленной.
    if len(samples_20t) < (GATE_RUNS // 2 + 1):
        print(f"FAILED: слишком мало валидных прогонов ({len(samples_20t)}/{GATE_RUNS}) — замер сломан")
        return 1

    med_20t = statistics.median(samples_20t)
    med_1t = statistics.median(samples_1t)

    failures: list[str] = []
    if max(med_20t, med_1t) <= ZERO_EPS:
        failures.append(f"0 живого урона (медианы 20t={med_20t:.2f} 1t={med_1t:.2f}) — режим оружия сломан")
    if med_20t > MAX_MEDIAN_20T:
        failures.append(
            f"berserk/hammer lvl20_ideal медиана 20t = {med_20t:.0f} > потолка {MAX_MEDIAN_20T:.0f} — "
            f"runaway множителей вернулся (проверь soft-cap забеговых множителей и upgrade_*_exponent молота)"
        )
    if med_1t > MAX_MEDIAN_1T:
        failures.append(
            f"berserk/hammer lvl20_ideal медиана 1t = {med_1t:.0f} > потолка {MAX_MEDIAN_1T:.0f} — solo-пик вне коридора"
        )

    print(
        f"[runaway-gate] berserk/hammer lvl20_ideal (медиана {len(samples_20t)} прогонов): "
        f"20t={med_20t:.0f} (≤{MAX_MEDIAN_20T:.0f}) 1t={med_1t:.0f} (≤{MAX_MEDIAN_1T:.0f})"
    )

    if failures:
        for f in failures:
            print(f"FAILED: {f}")
        return 1
    print("Berserk DPS runaway gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
