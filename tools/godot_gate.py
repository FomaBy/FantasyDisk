#!/usr/bin/env python3
"""Bounded-concurrency Godot runner (macOS-safe семафор через fcntl.flock).

Ограничивает число ОДНОВРЕМЕННЫХ headless-Godot процессов, чтобы пачка агентов,
гоняющих smoke-тесты параллельно, не выжрала память и не словила OOM-kill (137).
Все воркеры зовут Godot ЧЕРЕЗ этот тул вместо прямого вызова — тогда в любой момент
запущено не больше FSD_GODOT_SLOTS инстансов, сколько бы агентов ни работало.

Usage (как обычный Godot, аргументы прокидываются 1:1):
    python3 tools/godot_gate.py --headless --path /path/wt --script res://tests/runtime_smoke_test.gd

Env:
    FSD_GODOT_SLOTS   число слотов (по умолчанию 3)
    GODOT_BIN         путь к бинарю (по умолчанию ~/Downloads/Godot.app/Contents/MacOS/Godot)
    FSD_GODOT_SEM_DIR каталог lock-файлов (по умолчанию /tmp/fsd_godot_sem)
    FSD_GODOT_MAXWAIT макс. ожидание слота в секундах (по умолчанию 2400)
    FSD_GODOT_BYPASS_ON_TIMEOUT=1 явный аварийный запуск без слота после таймаута
"""
from __future__ import annotations

import fcntl
import os
import subprocess
import sys
import time

SLOTS = max(1, int(os.getenv("FSD_GODOT_SLOTS", "3")))
SEM_DIR = os.getenv("FSD_GODOT_SEM_DIR", "/tmp/fsd_godot_sem")
GODOT = os.getenv("GODOT_BIN", os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot"))
MAXWAIT = float(os.getenv("FSD_GODOT_MAXWAIT", "2400"))


def _project_path(args: list[str]) -> str:
    for index, arg in enumerate(args):
        if arg == "--path" and index + 1 < len(args):
            return args[index + 1]
        if arg.startswith("--path="):
            return arg.split("=", 1)[1]
    return "."


def _needs_import_cache(args: list[str]) -> bool:
    if "--script" not in args:
        return False
    if "--import" in args:
        return False
    project_path = os.path.abspath(_project_path(args))
    imported_dir = os.path.join(project_path, ".godot", "imported")
    class_cache = os.path.join(project_path, ".godot", "global_script_class_cache.cfg")
    if not os.path.isdir(imported_dir) or not os.path.exists(class_cache):
        return True
    try:
        next(os.scandir(imported_dir)).name
    except (StopIteration, FileNotFoundError, NotADirectoryError):
        return True
    return False


def _ensure_import_cache(args: list[str]) -> int:
    if not _needs_import_cache(args):
        return 0
    project_path = _project_path(args)
    sys.stderr.write("godot_gate: import cache missing, running headless import first\n")
    return subprocess.call([GODOT, "--headless", "--path", project_path, "--import", "--quit"])


def main() -> int:
    os.makedirs(SEM_DIR, exist_ok=True)
    args = sys.argv[1:]
    if not os.path.exists(GODOT):
        sys.stderr.write(f"godot_gate: бинарь не найден: {GODOT}\n")
        return 127
    deadline = time.time() + MAXWAIT
    while True:
        for i in range(SLOTS):
            f = open(os.path.join(SEM_DIR, f"slot{i}.lock"), "w")
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except (BlockingIOError, OSError):
                f.close()
                continue
            # слот захвачен — гоним Godot, держим лок до конца процесса
            try:
                import_code = _ensure_import_cache(args)
                if import_code != 0:
                    return import_code
                return subprocess.call([GODOT] + args)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
                f.close()
        if time.time() > deadline:
            if os.getenv("FSD_GODOT_BYPASS_ON_TIMEOUT", "") == "1":
                sys.stderr.write("godot_gate: превышено ожидание слота, FSD_GODOT_BYPASS_ON_TIMEOUT=1 — запуск без гейта\n")
                import_code = _ensure_import_cache(args)
                if import_code != 0:
                    return import_code
                return subprocess.call([GODOT] + args)
            sys.stderr.write(
                "godot_gate: превышено ожидание слота; запуск без семафора запрещён "
                "(для ручного аварийного bypass задай FSD_GODOT_BYPASS_ON_TIMEOUT=1)\n"
            )
            return 124
        time.sleep(1.5)


if __name__ == "__main__":
    sys.exit(main())
