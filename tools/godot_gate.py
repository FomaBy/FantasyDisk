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
    FSD_GODOT_SEM_DIR     lock directory (default: stable machine-wide directory)
    FSD_GODOT_EXCLUSIVE=1 waits for every gated run and blocks new ones while
                          this command executes; use for timing-sensitive work;
                          emergency timeout bypass is intentionally disabled
    FSD_GODOT_MAXWAIT     maximum slot wait in seconds (default: 2400)
    FSD_GODOT_RUN_TIMEOUT maximum Godot runtime in seconds (default: 3600)
    FSD_GODOT_BYPASS_ON_TIMEOUT=1 allows an explicit emergency bypass

Exit status 3 means the requested run printed a fatal Godot diagnostic even
when the engine process itself exited successfully.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import BinaryIO, Sequence


FATAL_OUTPUT_RE = re.compile(r"\bSCRIPT ERROR\b|\bFATAL\b", re.IGNORECASE)
SCRIPT_LOAD_FAILURE = "Failed to load script"
# Godot 4.7 phrases a script/resource load failure differently depending on
# the code path that rejects it; a requested suite that never ran must fail
# closed under any of them.
SCRIPT_LOAD_FAILURE_PATTERNS = (
    SCRIPT_LOAD_FAILURE,
    "Can't load script",
    "Failed loading resource",
)
IMPORT_CACHE_MISSING_MESSAGE = "godot_gate: import cache missing, running headless import first"
MACHINE_RUN_TOKENS = 64


def _positive_int_env(name: str, default: int) -> int:
    return max(1, int(os.getenv(name, str(default))))


def _positive_float_env(name: str, default: float) -> float:
    return max(0.0, float(os.getenv(name, str(default))))


def _default_semaphore_dir() -> Path:
    """Return a lock directory that is shared by separate Multica tasks."""
    if os.name == "nt":
        return Path(os.getenv("PUBLIC", r"C:\\Users\\Public")) / "FantasyDisk" / "fsd_godot_sem"
    return Path("/tmp") / "fsd_godot_sem"


def _semaphore_dir() -> Path:
    explicit = os.getenv("FSD_GODOT_SEM_DIR", "").strip()
    return Path(explicit).expanduser() if explicit else _default_semaphore_dir()


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


def _needs_import_cache(args: Sequence[str], *, require_script: bool = True) -> bool:
    if (require_script and "--script" not in args) or "--import" in args:
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


def _ensure_import_cache(args: Sequence[str], godot: str, *, force: bool = False) -> int:
    if not _needs_import_cache(args, require_script=not force):
        return 0
    project_path = _project_path(args)
    sys.stderr.write(f"{IMPORT_CACHE_MISSING_MESSAGE}\n")
    # The import pre-pass is intentionally diagnostic-tolerant: existing green
    # suites can emit unrelated import/resource warnings while warming the
    # cache. Only the requested executable run below is a certifying call site.
    return _run_godot([godot, "--headless", "--path", project_path, "--import", "--quit"])


def _write_live_output(chunk: bytes) -> None:
    """Tee one captured process chunk to the caller's stdout immediately."""
    try:
        binary_output = getattr(sys.stdout, "buffer", None)
        if binary_output is not None:
            binary_output.write(chunk)
            binary_output.flush()
            return
        sys.stdout.write(chunk.decode("utf-8", errors="replace"))
        sys.stdout.flush()
    except (BrokenPipeError, OSError, ValueError):
        # A closed output consumer must not stop draining the child pipe.
        pass


def _fatal_output_signal(output: str) -> str:
    match = FATAL_OUTPUT_RE.search(output)
    if match is not None:
        return match.group(0)
    for pattern in SCRIPT_LOAD_FAILURE_PATTERNS:
        if pattern in output:
            return pattern
    return ""


def _run_godot(
    command: Sequence[str],
    *,
    fail_on_fatal_output: bool = False,
) -> int:
    try:
        timeout = _positive_float_env("FSD_GODOT_RUN_TIMEOUT", 3600.0)
    except ValueError as exc:
        sys.stderr.write(f"godot_gate: invalid FSD_GODOT_RUN_TIMEOUT: {exc}\n")
        return 2
    process = subprocess.Popen(
        list(command),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    assert process.stdout is not None
    output_parts: list[bytes] = []

    def drain_output() -> None:
        read_chunk = getattr(process.stdout, "read1", process.stdout.read)
        while True:
            chunk = read_chunk(64 * 1024)
            if not chunk:
                return
            output_parts.append(chunk)
            _write_live_output(chunk)

    reader = threading.Thread(
        target=drain_output,
        name="godot-gate-output-reader",
        daemon=True,
    )
    reader.start()
    timed_out = False
    try:
        process.wait(timeout=timeout if timeout > 0.0 else None)
    except subprocess.TimeoutExpired:
        timed_out = True
        process.kill()
        process.wait()
    reader.join()
    process.stdout.close()

    if timed_out:
        sys.stderr.write(
            f"godot_gate: Godot timed out after {timeout:g}s; process terminated\n"
        )
        return 124
    output = b"".join(output_parts).decode("utf-8", errors="replace")
    diagnostic = _fatal_output_signal(output) if fail_on_fatal_output else ""
    if diagnostic:
        sys.stderr.write(
            f"godot_gate: fatal Godot diagnostic detected: {diagnostic}\n"
        )
        return 3
    return process.returncode


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


class _MachineRunLease:
    """Coordinates normal and timing-exclusive runs across every slot count.

    A normal run occupies one of the shared run tokens. An exclusive run first
    closes admission, then acquires every token, so it cannot overlap another
    gate invocation even when that invocation uses a different slot count.
    Advisory locks are released by the operating system if their owner dies.
    """

    def __init__(self, sem_dir: Path, exclusive: bool) -> None:
        self.exclusive = exclusive
        self.admission = _SlotLock(sem_dir / "exclusive-admission.lock")
        self.tokens = [
            _SlotLock(sem_dir / f"machine-run-{index}.lock")
            for index in range(MACHINE_RUN_TOKENS)
        ]
        self.acquired_tokens: list[_SlotLock] = []
        self.admission_held = False

    def try_acquire(self) -> bool:
        if not self.admission.try_acquire():
            return False
        self.admission_held = True

        if not self.exclusive:
            for token in self.tokens:
                if token.try_acquire():
                    self.acquired_tokens.append(token)
                    self.admission.release()
                    self.admission_held = False
                    return True
            self.admission.release()
            self.admission_held = False
            return False

        for token in self.tokens:
            if token.try_acquire():
                self.acquired_tokens.append(token)
                continue
            self.release()
            return False
        return True

    def release(self) -> None:
        for token in reversed(self.acquired_tokens):
            token.release()
        self.acquired_tokens.clear()
        if self.admission_held:
            self.admission.release()
            self.admission_held = False


def main(argv: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    ensure_import_cache_only = "--ensure-import-cache" in args
    if ensure_import_cache_only:
        args = [arg for arg in args if arg != "--ensure-import-cache"]
    try:
        slots = _positive_int_env("FSD_GODOT_SLOTS", 3)
        max_wait = _positive_float_env("FSD_GODOT_MAXWAIT", 2400.0)
    except ValueError as exc:
        sys.stderr.write(f"godot_gate: invalid numeric environment value: {exc}\n")
        return 2

    sem_dir = _semaphore_dir()
    sem_dir.mkdir(parents=True, exist_ok=True)

    godot = _resolve_godot()
    if not godot or not os.path.isfile(godot) or not os.access(godot, os.X_OK):
        sys.stderr.write(
            "godot_gate: Godot executable not found; set GODOT_BIN (or GODOT) "
            "to an executable path\n"
        )
        return 127

    deadline = time.monotonic() + max_wait
    exclusive = os.getenv("FSD_GODOT_EXCLUSIVE", "") == "1"
    while True:
        lease = _MachineRunLease(sem_dir, exclusive)
        if lease.try_acquire():
            try:
                for index in range(slots):
                    slot = _SlotLock(sem_dir / f"slot{index}.lock")
                    if not slot.try_acquire():
                        continue
                    try:
                        import_code = _ensure_import_cache(
                            args, godot, force=ensure_import_cache_only
                        )
                        if import_code != 0:
                            return import_code
                        if ensure_import_cache_only:
                            return 0
                        return _run_godot(
                            [godot, *args],
                            fail_on_fatal_output=True,
                        )
                    finally:
                        slot.release()
            finally:
                lease.release()

        if time.monotonic() > deadline:
            if os.getenv("FSD_GODOT_BYPASS_ON_TIMEOUT", "") == "1" and not exclusive:
                sys.stderr.write(
                    "godot_gate: slot wait timed out; explicit bypass enabled\n"
                )
                import_code = _ensure_import_cache(args, godot, force=ensure_import_cache_only)
                if import_code != 0:
                    return import_code
                if ensure_import_cache_only:
                    return 0
                return _run_godot(
                    [godot, *args],
                    fail_on_fatal_output=True,
                )
            if exclusive and os.getenv("FSD_GODOT_BYPASS_ON_TIMEOUT", "") == "1":
                sys.stderr.write(
                    "godot_gate: slot wait timed out; exclusive runs refuse "
                    "the emergency bypass\n"
                )
                return 124
            sys.stderr.write(
                "godot_gate: slot wait timed out; bypass is disabled "
                "(set FSD_GODOT_BYPASS_ON_TIMEOUT=1 only for manual recovery)\n"
            )
            return 124
        time.sleep(1.5)


if __name__ == "__main__":
    raise SystemExit(main())
