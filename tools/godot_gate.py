#!/usr/bin/env python3
"""Cross-platform bounded-concurrency runner for FantasyDisk Godot commands.

Every automated Godot invocation should pass through this script.  It keeps a
small shared set of process slots, creates the import cache when a script needs
it, and works on macOS/Linux (``fcntl``) and Windows (``msvcrt``).

Usage:
    python3 tools/godot_gate.py --headless --path . \
        --script res://tests/runtime_smoke_test.gd

Environment:
    FSD_GODOT_SLOTS       concurrent slots (default: 3)
    GODOT_BIN / GODOT     executable path or command name
    FSD_GODOT_SEM_DIR     lock directory (default: OS temp directory)
    FSD_GODOT_MAXWAIT     maximum slot wait in seconds (default: 2400)
    FSD_GODOT_RUN_TIMEOUT maximum Godot runtime in seconds (default: 3600)
    FSD_GODOT_BYPASS_ON_TIMEOUT=1 allows an explicit emergency bypass
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import BinaryIO, Sequence


def _positive_int_env(name: str, default: int) -> int:
    return max(1, int(os.getenv(name, str(default))))


def _positive_float_env(name: str, default: float) -> float:
    return max(0.0, float(os.getenv(name, str(default))))


def _resolve_godot() -> str:
    explicit = os.getenv("GODOT_BIN", "").strip() or os.getenv("GODOT", "").strip()
    if explicit:
        expanded = os.path.expanduser(explicit)
        return shutil.which(expanded) or expanded

    candidates = ["godot4", "godot"]
    if sys.platform == "darwin":
        candidates.insert(0, os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot"))
    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return ""


def _project_path(args: Sequence[str]) -> str:
    for index, arg in enumerate(args):
        if arg == "--path" and index + 1 < len(args):
            return args[index + 1]
        if arg.startswith("--path="):
            return arg.split("=", 1)[1]
    return "."


def _needs_import_cache(args: Sequence[str]) -> bool:
    if "--script" not in args or "--import" in args:
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


def _ensure_import_cache(args: Sequence[str], godot: str) -> int:
    if not _needs_import_cache(args):
        return 0
    project_path = _project_path(args)
    sys.stderr.write("godot_gate: import cache missing, running headless import first\n")
    return _run_godot([godot, "--headless", "--path", project_path, "--import", "--quit"])


def _run_godot(command: Sequence[str]) -> int:
    try:
        timeout = _positive_float_env("FSD_GODOT_RUN_TIMEOUT", 3600.0)
    except ValueError as exc:
        sys.stderr.write(f"godot_gate: invalid FSD_GODOT_RUN_TIMEOUT: {exc}\n")
        return 2
    try:
        return subprocess.run(
            list(command),
            check=False,
            timeout=timeout if timeout > 0.0 else None,
        ).returncode
    except subprocess.TimeoutExpired:
        sys.stderr.write(
            f"godot_gate: Godot timed out after {timeout:g}s; process terminated\n"
        )
        return 124


def _prepare_lock_file(file: BinaryIO) -> None:
    if os.name != "nt":
        return
    file.seek(0, os.SEEK_END)
    if file.tell() == 0:
        file.write(b"\0")
        file.flush()
    file.seek(0)


def _try_lock(file: BinaryIO) -> bool:
    try:
        if os.name == "nt":
            import msvcrt

            file.seek(0)
            msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl

            fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except (BlockingIOError, OSError):
        return False


def _unlock(file: BinaryIO) -> None:
    if os.name == "nt":
        import msvcrt

        file.seek(0)
        msvcrt.locking(file.fileno(), msvcrt.LK_UNLCK, 1)
    else:
        import fcntl

        fcntl.flock(file.fileno(), fcntl.LOCK_UN)


class _SlotLock:
    """One-byte advisory lock with a uniform POSIX/Windows interface."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.file: BinaryIO | None = None

    def try_acquire(self) -> bool:
        self.file = self.path.open("a+b")
        _prepare_lock_file(self.file)
        if not _try_lock(self.file):
            self.file.close()
            self.file = None
            return False
        return True

    def release(self) -> None:
        if self.file is None:
            return
        try:
            _unlock(self.file)
        finally:
            self.file.close()
            self.file = None


def main(argv: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        slots = _positive_int_env("FSD_GODOT_SLOTS", 3)
        max_wait = _positive_float_env("FSD_GODOT_MAXWAIT", 2400.0)
    except ValueError as exc:
        sys.stderr.write(f"godot_gate: invalid numeric environment value: {exc}\n")
        return 2

    sem_dir = Path(os.getenv(
        "FSD_GODOT_SEM_DIR",
        os.path.join(tempfile.gettempdir(), "fsd_godot_sem"),
    )).expanduser()
    sem_dir.mkdir(parents=True, exist_ok=True)

    godot = _resolve_godot()
    if not godot or not os.path.isfile(godot) or not os.access(godot, os.X_OK):
        sys.stderr.write(
            "godot_gate: Godot executable not found; set GODOT_BIN (or GODOT) "
            "to an executable path\n"
        )
        return 127

    deadline = time.monotonic() + max_wait
    while True:
        for index in range(slots):
            slot = _SlotLock(sem_dir / f"slot{index}.lock")
            if not slot.try_acquire():
                continue
            try:
                import_code = _ensure_import_cache(args, godot)
                if import_code != 0:
                    return import_code
                return _run_godot([godot, *args])
            finally:
                slot.release()

        if time.monotonic() > deadline:
            if os.getenv("FSD_GODOT_BYPASS_ON_TIMEOUT", "") == "1":
                sys.stderr.write(
                    "godot_gate: slot wait timed out; explicit bypass enabled\n"
                )
                import_code = _ensure_import_cache(args, godot)
                if import_code != 0:
                    return import_code
                return _run_godot([godot, *args])
            sys.stderr.write(
                "godot_gate: slot wait timed out; bypass is disabled "
                "(set FSD_GODOT_BYPASS_ON_TIMEOUT=1 only for manual recovery)\n"
            )
            return 124
        time.sleep(1.5)


if __name__ == "__main__":
    raise SystemExit(main())
