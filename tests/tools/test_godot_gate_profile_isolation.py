"""FAN-4000: a gated Godot run must never touch the machine's real player profile.

Godot derives ``user://`` from the platform data directory, so a focused run
used to clear the owner's run autosave and rewrite meta/settings.  These tests
drive the real gate end to end with a stand-in ``godot`` that resolves
``user://`` the way the engine does and then behaves like a Main-scene suite:
it deletes the autosave and rewrites meta and settings.  The "real" profile is
itself a scratch directory, so nothing here can reach the actual machine one.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
GODOT_GATE = ROOT / "tools" / "godot_gate.py"
PROFILE_FILES = ("fantasydisk_meta.cfg", "fantasydisk_autosave.cfg", "settings.cfg")
SCRATCH_PREFIX = "fsd-godot-profile-"

# Resolves user:// like Godot 4 (macOS HOME, Windows APPDATA, Linux XDG/HOME),
# records what it saw, then mutates the profile like a Main-scene test does.
GODOT_STUB = r'''
import json, os, sys, time
from pathlib import Path

def user_dir():
    if sys.platform == "darwin":
        base = Path(os.environ["HOME"]) / "Library" / "Application Support"
    elif os.name == "nt":
        base = Path(os.environ["APPDATA"])
    else:
        base = Path(os.environ.get("XDG_DATA_HOME") or Path(os.environ["HOME"]) / ".local" / "share")
    return base / "Godot" / "app_userdata" / "FantasyDisk"

profile = user_dir()
record = {
    "pid": os.getpid(),
    "argv": sys.argv[1:],
    "env": {key: os.environ.get(key, "") for key in ("HOME", "XDG_DATA_HOME", "APPDATA", "LOCALAPPDATA")},
    "user_dir": str(profile),
}
Path(os.environ["FSD_PROFILE_PROBE_RECORD"]).write_text(json.dumps(record), encoding="utf-8")
profile.mkdir(parents=True, exist_ok=True)
(profile / "fantasydisk_autosave.cfg").unlink(missing_ok=True)
(profile / "fantasydisk_meta.cfg").write_text("[meta]\nrewritten=true\n", encoding="utf-8")
(profile / "settings.cfg").write_text("[settings]\nrewritten=true\n", encoding="utf-8")
time.sleep(float(os.environ.get("FSD_PROFILE_PROBE_SLEEP", "0")))
sys.exit(int(os.environ.get("FSD_PROFILE_PROBE_EXIT", "0")))
'''


def _platform_user_dir(root: Path) -> Path:
    """The stub's user:// when every profile variable points at ``root``."""
    base = root / "Library" / "Application Support" if sys.platform == "darwin" else root
    return base / "Godot" / "app_userdata" / "FantasyDisk"


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class GodotGateProfileIsolationTests(unittest.TestCase):
    def setUp(self) -> None:
        work = tempfile.TemporaryDirectory(prefix="fsd-fan4000-")
        self.addCleanup(work.cleanup)
        self.work = Path(work.name).resolve()
        # Stand-in for the machine's real home and its live FantasyDisk profile.
        self.real_home = self.work / "real-home"
        self.real_profile = _platform_user_dir(self.real_home)
        self.real_profile.mkdir(parents=True)
        for name in PROFILE_FILES:
            (self.real_profile / name).write_text(f"[seed]\nfile={name}\n", encoding="utf-8")
        self.seeded = {name: _digest(self.real_profile / name) for name in PROFILE_FILES}
        self.temp_root = self.work / "tmp"
        self.temp_root.mkdir()
        self.record = self.work / "record.json"
        self.stub = self.work / "godot_stub.py"
        self.stub.write_text(GODOT_STUB, encoding="utf-8")

    def _env(self, **overrides: str) -> dict[str, str]:
        env = os.environ.copy()
        # sys.executable stands in for godot; a CI-wide build pin would reject it.
        env.pop("GODOT_BUILD_ID", None)
        env.update(
            {
                "GODOT_BIN": sys.executable,
                "FSD_GODOT_SEM_DIR": str(self.work / "sem"),
                "FSD_GODOT_SLOTS": "1",
                "FSD_GODOT_MAXWAIT": "10",
                "FSD_GODOT_RUN_TIMEOUT": "30",
                "FSD_GODOT_EXCLUSIVE": "",
                "FSD_GODOT_REAL_PROFILE": "",
                "FSD_PROFILE_PROBE_RECORD": str(self.record),
                "TMPDIR": str(self.temp_root),
                "TEMP": str(self.temp_root),
                "TMP": str(self.temp_root),
            }
        )
        for key in ("HOME", "XDG_DATA_HOME", "APPDATA", "LOCALAPPDATA"):
            env[key] = str(self.real_home)
        env.update(overrides)
        return env

    def _gate(self, *args: str, **env: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(GODOT_GATE), str(self.stub), "--headless", *args],
            env=self._env(**env),
            capture_output=True,
            text=True,
            timeout=60,
        )

    def _seen(self) -> dict:
        return json.loads(self.record.read_text(encoding="utf-8"))

    def _assert_real_profile_untouched(self) -> None:
        current = {name: _digest(self.real_profile / name) for name in PROFILE_FILES}
        self.assertEqual(current, self.seeded)

    def _assert_no_scratch_left(self) -> None:
        self.assertEqual(sorted(p.name for p in self.temp_root.glob(f"{SCRATCH_PREFIX}*")), [])

    def _assert_isolated_in(self, seen: dict, root: str) -> None:
        self.assertEqual(set(seen["env"].values()), {root})
        self.assertTrue(seen["user_dir"].startswith(root + os.sep), seen["user_dir"])

    def test_default_run_uses_and_removes_a_fresh_scratch_profile(self) -> None:
        result = self._gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        seen = self._seen()
        self.assertEqual(seen["argv"][-2], "--")
        flag = seen["argv"][-1]
        self.assertTrue(flag.startswith("--user-data-dir="), flag)
        scratch = flag.split("=", 1)[1]
        self.assertTrue(Path(scratch).name.startswith(SCRATCH_PREFIX), scratch)
        self._assert_isolated_in(seen, scratch)
        self.assertIn(f"player profile: scratch {scratch}", result.stderr)
        self.assertFalse(Path(scratch).exists())
        self._assert_no_scratch_left()
        self._assert_real_profile_untouched()

    def test_existing_user_args_keep_their_order(self) -> None:
        result = self._gate("--", "--out", "capture-dir")
        self.assertEqual(result.returncode, 0, result.stderr)
        argv = self._seen()["argv"]
        self.assertEqual(argv[-4:-1], ["--", "--out", "capture-dir"])
        self.assertTrue(argv[-1].startswith("--user-data-dir="), argv)
        self.assertEqual(argv.count("--"), 1)

    def test_failed_run_still_removes_the_scratch_profile(self) -> None:
        result = self._gate(FSD_PROFILE_PROBE_EXIT="7")
        self.assertEqual(result.returncode, 7, result.stderr)
        self._assert_no_scratch_left()
        self._assert_real_profile_untouched()

    def test_timed_out_run_still_removes_the_scratch_profile(self) -> None:
        result = self._gate(FSD_PROFILE_PROBE_SLEEP="30", FSD_GODOT_RUN_TIMEOUT="1")
        self.assertEqual(result.returncode, 124, result.stderr)
        self._assert_no_scratch_left()
        self._assert_real_profile_untouched()

    @unittest.skipIf(os.name == "nt", "SIGTERM delivery to a console process is POSIX-only")
    def test_terminated_gate_kills_godot_and_removes_the_scratch_profile(self) -> None:
        gate = subprocess.Popen(
            [sys.executable, str(GODOT_GATE), str(self.stub), "--headless"],
            env=self._env(FSD_PROFILE_PROBE_SLEEP="30"),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            deadline = time.monotonic() + 20
            while not self.record.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue(self.record.exists(), "stand-in godot never started")
            child = self._seen()["pid"]
            gate.send_signal(signal.SIGTERM)
            self.assertEqual(gate.wait(timeout=20), 128 + signal.SIGTERM)
        finally:
            if gate.poll() is None:
                gate.kill()
                gate.wait()
        with self.assertRaises(ProcessLookupError):
            os.kill(child, 0)
        self._assert_no_scratch_left()
        self._assert_real_profile_untouched()

    def test_caller_scratch_dir_is_honoured_and_kept(self) -> None:
        caller = self.work / "caller-scratch"
        result = self._gate("--", f"--user-data-dir={caller}")
        self.assertEqual(result.returncode, 0, result.stderr)
        seen = self._seen()
        self.assertEqual(seen["argv"][-2:], ["--", f"--user-data-dir={caller}"])
        self._assert_isolated_in(seen, str(caller))
        self.assertIn(f"player profile: caller scratch {caller}", result.stderr)
        self.assertTrue((_platform_user_dir(caller) / "settings.cfg").is_file())
        self._assert_no_scratch_left()
        self._assert_real_profile_untouched()

    def test_empty_caller_scratch_dir_is_refused(self) -> None:
        result = self._gate("--", "--user-data-dir=")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.record.exists())
        self._assert_real_profile_untouched()

    def test_opt_out_uses_the_real_profile_and_says_so(self) -> None:
        result = self._gate(FSD_GODOT_REAL_PROFILE="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        seen = self._seen()
        self.assertNotIn("--", seen["argv"])
        self._assert_isolated_in(seen, str(self.real_home))
        self.assertIn("player profile: REAL machine profile (FSD_GODOT_REAL_PROFILE=1)", result.stderr)
        self.assertFalse((self.real_profile / "fantasydisk_autosave.cfg").exists())

    def test_export_run_keeps_the_editor_data_directory(self) -> None:
        result = self._gate("--export-release", "macOS", str(self.work / "out.zip"))
        self.assertEqual(result.returncode, 0, result.stderr)
        seen = self._seen()
        self.assertEqual(seen["argv"][-3:], ["--export-release", "macOS", str(self.work / "out.zip")])
        self._assert_isolated_in(seen, str(self.real_home))
        self.assertIn("player profile: not isolated for an export run", result.stderr)
        self._assert_no_scratch_left()


class SharedProfileEnvironmentTests(unittest.TestCase):
    @staticmethod
    def _load(name: str, relative: str):
        spec = importlib.util.spec_from_file_location(name, ROOT / relative)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        return module

    def test_quality_gate_uses_the_gate_profile_environment(self) -> None:
        gate = self._load("godot_gate_fan4000", "tools/godot_gate.py")
        quality = self._load("quality_gate_fan4000", "tools/quality_gate.py")
        user_data = Path("/scratch/fan4000")
        env = quality._godot_environment(user_data, exclusive=True)
        for key in gate.PROFILE_ENV_KEYS:
            self.assertEqual(env[key], str(user_data), key)
        self.assertEqual(env["FSD_GODOT_EXCLUSIVE"], "1")
        self.assertEqual(quality._godot_environment(user_data)["FSD_GODOT_EXCLUSIVE"], "")

    def test_gate_pins_its_engine_before_moving_home(self) -> None:
        gate = self._load("godot_gate_fan4000_pin", "tools/godot_gate.py")
        with mock.patch.dict(os.environ, {"GODOT": "godot4"}, clear=False):
            env = gate.isolated_profile_env(Path("/scratch/fan4000"), godot_bin="/engines/godot")
        self.assertEqual(env["GODOT_BIN"], "/engines/godot")
        self.assertEqual(env["GODOT"], "godot4")
        self.assertEqual(env["HOME"], "/scratch/fan4000")


if __name__ == "__main__":
    unittest.main()
