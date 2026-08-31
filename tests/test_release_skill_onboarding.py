"""Regression tests for persistent release-skill onboarding provenance."""

from __future__ import annotations

import base64
import hashlib
import io
import os
import signal
import shutil
import socket
import stat
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ONBOARD = ROOT / "scripts" / "onboard.sh"
SOURCE_SKILL = ROOT / "skills" / "codex" / "fantasydisk-release-director"
LEGACY_SKILL_COMMIT = "2cba1b7050cb168bca70b6354cc7b654334dd53e"
LEGACY_SKILL_PATH = "skills/codex/fantasydisk-release-director"
PRE_FIX_ONBOARD_COMMIT = "5d23555117c11620ee0f0834e6c30877fd1dafb8"
LEGACY_SKILL_MD_SHA256 = "9ae5871b81165d655f262efbae410891af4eb384504dd7158c2de79d9a348a50"

EXPECTED_RELEASE_SKILL_FILES = {
    "SKILL.md",
    "scripts/build_update_manifest.py",
    "scripts/github_release_publish.py",
    "scripts/github_release_verify.py",
    "scripts/local_release.py",
    "scripts/release_publish.py",
    "scripts/telegram_publish.py",
}
MIRROR_RELATIVE_PATH = Path(
    ".codex", "skill-mirrors", "FantasyDisk", "fantasydisk-release-director"
)
VERSIONS_RELATIVE_PATH = Path(
    ".codex",
    "skill-mirrors",
    "FantasyDisk",
    ".fantasydisk-release-director.versions",
)
SELECTED_RELATIVE_PATH = Path(".codex", "skills", "fantasydisk-release-director")
# Keep the child watchdog below quality_gate.py's 60-second idle watchdog.
ONBOARD_WATCHDOG_SECONDS = 15.0
_ONBOARD_CLEANUP_SECONDS = 2.0


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _inventory(root: Path) -> dict[str, tuple[str, ...]]:
    """Return an entry/type/hash inventory without following child symlinks."""
    entries: dict[str, tuple[str, ...]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        mode = f"{os.lstat(path).st_mode & 0o7777:04o}"
        if path.is_symlink():
            entries[relative] = ("symlink", os.readlink(path))
        elif path.is_dir():
            entries[relative] = ("directory", mode)
        elif path.is_file():
            entries[relative] = ("file", mode, _file_sha256(path))
        else:
            entries[relative] = ("other", mode)
    return entries


# `git archive` here is a read of already-local history: it must never wait on
# unrelated repository maintenance. `-c gc.auto=0` keeps it from triggering a
# background `git gc --auto`, which git detaches into its own session (outside
# any process group a caller could kill) and which can hold this call's
# inherited stdout pipe open for as long as the detached gc runs. A bounded
# `timeout` is the backstop: any stall here now fails fast with a diagnostic
# instead of silently consuming the suite's shared idle-output budget.
_GIT_ARCHIVE_TIMEOUT_SECONDS = 20.0


def _extract_legacy_skill(destination: Path) -> None:
    """Materialize the exact repo-owned pre-fix tree from git history."""
    try:
        archive = subprocess.run(
            [
                "git",
                "-c",
                "gc.auto=0",
                "archive",
                "--format=tar",
                LEGACY_SKILL_COMMIT,
                LEGACY_SKILL_PATH,
            ],
            cwd=ROOT,
            check=True,
            stdout=subprocess.PIPE,
            timeout=_GIT_ARCHIVE_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as timeout_error:
        raise AssertionError(
            "git archive for the legacy release-skill fixture timed out after "
            f"{_GIT_ARCHIVE_TIMEOUT_SECONDS:.0f}s; repository access is stalled"
        ) from timeout_error
    with tarfile.open(fileobj=io.BytesIO(archive.stdout), mode="r:") as tar:
        for member in tar.getmembers():
            if member.name == LEGACY_SKILL_PATH:
                relative = Path(".")
            elif member.name.startswith(f"{LEGACY_SKILL_PATH}/"):
                relative = Path(member.name).relative_to(LEGACY_SKILL_PATH)
            else:
                continue
            output = destination / relative
            if member.isdir():
                output.mkdir(parents=True, exist_ok=True)
                output.chmod(0o755)
            elif member.isfile():
                output.parent.mkdir(parents=True, exist_ok=True)
                source = tar.extractfile(member)
                assert source is not None
                output.write_bytes(source.read())
                output.chmod(0o644)
            else:
                raise AssertionError(f"unexpected legacy archive entry: {member.name}")


def _fake_multica(home: Path) -> Path:
    fake_bin = home / "fake-bin"
    fake_bin.mkdir(parents=True, exist_ok=True)
    multica = fake_bin / "multica"
    multica.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
    multica.chmod(0o755)
    return fake_bin


def _onboard_environment(
    script: Path,
    home: Path,
    *,
    path_prefix: Path | None = None,
    extra: dict[str, str] | None = None,
) -> dict[str, str]:
    environment = os.environ.copy()
    fake_bin = _fake_multica(home)
    if path_prefix is not None:
        path = f"{path_prefix}{os.pathsep}{fake_bin}{os.pathsep}{environment['PATH']}"
    else:
        path = f"{fake_bin}{os.pathsep}{environment['PATH']}"
    environment.update({"HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"), "PATH": path})
    if extra:
        environment.update(extra)
    return environment


def _run_onboard(
    script: Path,
    home: Path,
    *,
    path_prefix: Path | None = None,
    extra: dict[str, str] | None = None,
    args: tuple[str, ...] = (),
    timeout: float = ONBOARD_WATCHDOG_SECONDS,
) -> subprocess.CompletedProcess[str]:
    command = ["bash", str(script), *args]
    process = subprocess.Popen(
        command,
        cwd=script.parents[1],
        env=_onboard_environment(script, home, path_prefix=path_prefix, extra=extra),
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=os.name != "nt",
    )
    try:
        stdout, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as timeout_error:
        _kill_process_group(process)
        try:
            stdout, _ = process.communicate(timeout=_ONBOARD_CLEANUP_SECONDS)
        except subprocess.TimeoutExpired as cleanup_error:
            _kill_process_group(process)
            if process.stdout is not None:
                process.stdout.close()
            try:
                process.wait(timeout=_ONBOARD_CLEANUP_SECONDS)
            except subprocess.TimeoutExpired as wait_error:
                raise AssertionError(
                    "onboarding child cleanup exceeded the watchdog window; "
                    f"process group root pid={process.pid}"
                ) from wait_error
            stdout = cleanup_error.output
        captured = _captured_output(stdout)
        raise AssertionError(
            f"onboarding child timed out after {timeout:.2f}s; "
            f"terminated and reaped process group root pid={process.pid}; "
            f"task home={home}; captured output:\n{captured or '<no output captured>'}"
        ) from timeout_error
    _assert_process_group_exited(process.pid)
    return subprocess.CompletedProcess(command, process.returncode, stdout=stdout)


def _assert_process_group_exited(pgid: int) -> None:
    """Fail loudly if a descendant outlived the onboarding child it came from.

    `communicate()` returning already proves nothing still holds this call's
    stdout pipe open, but a descendant that closed its inherited fds while
    continuing to run (for example a detached `git gc --auto`) would keep
    the process group alive without deadlocking this run. Left unchecked,
    that survivor is exactly the kind of leak that stalls a *later* run.
    """
    if os.name == "nt":
        return
    # A child that exits cleanly may leave a grandchild as a momentary zombie
    # awaiting reaping; give that ordinary teardown a brief, bounded window
    # before treating a still-visible group as a genuine leak.
    deadline = time.monotonic() + 1.0
    while True:
        try:
            os.killpg(pgid, 0)
        except (ProcessLookupError, PermissionError):
            return
        if time.monotonic() >= deadline:
            break
        time.sleep(0.05)
    raise AssertionError(
        f"onboarding process group root pid={pgid} still has live members "
        "after the run completed; a descendant leaked"
    )


def _run_release_only(
    script: Path,
    home: Path,
    *,
    extra: dict[str, str] | None = None,
    timeout: float = ONBOARD_WATCHDOG_SECONDS,
) -> subprocess.CompletedProcess[str]:
    return _run_onboard(
        script,
        home,
        extra=extra,
        args=("--release-only",),
        timeout=timeout,
    )


def _start_onboard(
    script: Path,
    home: Path,
    *,
    extra: dict[str, str] | None = None,
) -> subprocess.Popen[str]:
    return subprocess.Popen(
        ["bash", str(script)],
        cwd=script.parents[1],
        env=_onboard_environment(script, home, extra=extra),
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )


def _kill_process_group(process: subprocess.Popen[str]) -> None:
    if os.name == "nt":
        try:
            process.kill()
        except ProcessLookupError:
            pass
        return
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        if process.poll() is None:
            process.kill()


def _captured_output(output: str | bytes | None) -> str:
    if output is None:
        return ""
    if isinstance(output, bytes):
        return output.decode("utf-8", errors="replace")
    return output


def _process_is_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _wait_for_marker(marker: Path, process: subprocess.Popen[str]) -> None:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if marker.exists():
            return
        if process.poll() is not None:
            output = process.communicate()[0]
            raise AssertionError(f"onboarding exited before marker: {output}")
        time.sleep(0.01)
    process.kill()
    process.wait()
    raise AssertionError(f"onboarding did not reach marker {marker}")


def _commit_source_change(checkout: Path, suffix: str) -> Path:
    skill_md = checkout / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md"
    skill_md.write_text(skill_md.read_text(encoding="utf-8") + f"\n{suffix}\n", encoding="utf-8")
    subprocess.run(["git", "add", str(skill_md.relative_to(checkout))], cwd=checkout, check=True)
    subprocess.run(["git", "commit", "-m", f"updated source {suffix}"], cwd=checkout, check=True)
    return skill_md


def _selected(home: Path) -> Path:
    return home / SELECTED_RELATIVE_PATH


def _mirror(home: Path) -> Path:
    return Path(os.path.realpath(home / MIRROR_RELATIVE_PATH))


def _mirror_pointer(home: Path) -> Path:
    return home / MIRROR_RELATIVE_PATH


def _versions(home: Path) -> Path:
    return home / VERSIONS_RELATIVE_PATH


def _lock(home: Path) -> Path:
    return _versions(home).parent / ".fantasydisk-release-director.lock"


def _lock_reclaim(home: Path) -> Path:
    return _versions(home).parent / ".fantasydisk-release-director.lock.reclaim"


def _lstat_signature(path: Path) -> tuple[str, ...]:
    """Return a stable root-type/content signature without following links."""
    metadata = os.lstat(path)
    mode = f"{metadata.st_mode & 0o7777:04o}"
    if stat.S_ISLNK(metadata.st_mode):
        return ("symlink", os.readlink(path), mode)
    if stat.S_ISDIR(metadata.st_mode):
        return ("directory", mode)
    if stat.S_ISREG(metadata.st_mode):
        return ("file", mode, _file_sha256(path))
    if stat.S_ISFIFO(metadata.st_mode):
        return ("fifo", mode)
    if stat.S_ISSOCK(metadata.st_mode):
        return ("socket", mode)
    return ("other", mode)


def _physical_signature(path: Path) -> tuple[str, ...]:
    """Include no-follow identity plus ctime to catch immediate inode reuse."""
    metadata = os.lstat(path)
    return (
        str(metadata.st_dev),
        str(metadata.st_ino),
        str(metadata.st_ctime_ns),
        *_lstat_signature(path),
    )


def _lstat_or_absent(path: Path) -> tuple[str, ...]:
    if path.exists() or path.is_symlink():
        return _lstat_signature(path)
    return ("absent",)


def _metadata_signature(path: Path) -> tuple[str, ...]:
    """Capture type/mode/size without reading a possibly unreadable file."""
    metadata = os.lstat(path)
    mode = f"{metadata.st_mode & 0o7777:04o}"
    if stat.S_ISLNK(metadata.st_mode):
        return ("symlink", os.readlink(path), mode)
    if stat.S_ISDIR(metadata.st_mode):
        return ("directory", mode)
    if stat.S_ISREG(metadata.st_mode):
        return ("file", mode, str(metadata.st_size))
    return ("other", mode, str(metadata.st_size))


def _managed_lock_state(home: Path) -> tuple[dict[str, tuple[str, ...]], tuple[str, ...], tuple[str, ...]]:
    """Capture every managed mirror entry plus both selected pointers."""
    parent = _versions(home).parent
    return (
        _inventory(parent),
        _lstat_or_absent(_selected(home)),
        _lstat_or_absent(_mirror_pointer(home)),
    )


def _make_external_versions_sentinel(root: Path) -> None:
    """Create ordinary and residue-pattern entries that onboarding must not touch."""
    root.mkdir(parents=True)
    (root / "ordinary-sentinel.txt").write_bytes(b"operator data must survive\n")
    for suffix in (
        "staging.external",
        "mirror-stage.external",
        "legacy-mirror.external",
    ):
        residue = root / f".fantasydisk-release-director.{suffix}"
        residue.mkdir()
        (residue / "sentinel.txt").write_bytes(b"do not remove\n")


def _install_unsafe_versions_root(
    path: Path, kind: str, external: Path
) -> socket.socket | None:
    """Install one disposable unsafe root; return an open Unix socket when needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if kind == "symlink-to-directory":
        path.symlink_to(external, target_is_directory=True)
        return None
    if kind == "dangling-symlink":
        path.symlink_to(external.parent / "missing-version-store")
        return None
    if kind == "regular-file":
        path.write_bytes(b"not a directory\n")
        return None
    if kind == "fifo":
        os.mkfifo(path)
        return None
    if kind == "socket":
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(str(path))
        return listener
    raise AssertionError(f"unknown unsafe root kind: {kind}")


def _assert_durable_selected_tree(home: Path, expected_source: Path) -> None:
    target = _selected(home)
    mirror = _mirror(home)
    assert target.is_symlink()
    assert _mirror_pointer(home).is_symlink()
    assert os.path.realpath(os.readlink(target)) == os.path.realpath(mirror)
    assert os.path.realpath(os.readlink(_mirror_pointer(home))) == os.path.realpath(mirror)
    assert mirror.is_dir()
    assert not mirror.is_symlink()
    assert target.resolve() == mirror.resolve()
    assert _inventory(mirror) == _inventory(expected_source)
    assert set(path.relative_to(mirror).as_posix() for path in mirror.rglob("*") if path.is_file()) == (
        EXPECTED_RELEASE_SKILL_FILES
    )


def _make_disposable_source_checkout(destination: Path) -> Path:
    """Create a small, clean Git checkout that onboarding may safely verify."""
    (destination / "scripts").mkdir(parents=True)
    shutil.copy2(ONBOARD, destination / "scripts" / "onboard.sh")
    shutil.copytree(
        SOURCE_SKILL,
        destination / "skills" / "codex" / "fantasydisk-release-director",
    )
    for command in (
        ["git", "init"],
        ["git", "config", "user.email", "test@example.invalid"],
        ["git", "config", "user.name", "FantasyDisk test"],
        ["git", "add", "scripts/onboard.sh", "skills/codex/fantasydisk-release-director"],
        ["git", "commit", "-m", "test source"],
    ):
        subprocess.run(command, cwd=destination, check=True, stdout=subprocess.PIPE)
    return destination


def _make_liveness_python_shim(destination: Path) -> Path:
    """Inject errno-specific process-probe outcomes without host privileges."""
    destination.mkdir(parents=True, exist_ok=True)
    shim = destination / "python3"
    shim.write_text(
        f"""#!{sys.executable}
import errno
import os
import sys

if len(sys.argv) > 3 and sys.argv[1] == "-c" and "os.kill" in sys.argv[2]:
    mode = os.environ.get("FANTASYDISK_ONBOARD_TEST_LIVENESS")
    if mode == "failure":
        raise SystemExit(73)

    def injected_kill(_pid, _signal):
        if mode == "live":
            return None
        if mode == "dead":
            raise ProcessLookupError(errno.ESRCH, "injected dead owner")
        if mode == "unknown":
            raise PermissionError(errno.EPERM, "injected permission denial")
        if mode == "error":
            raise OSError(errno.EIO, "injected probe failure")
        if mode == "invalid":
            return None
        raise AssertionError(f"unexpected test mode: {{mode!r}}")

    probe_code = sys.argv[2]
    probe_pid = "not-a-pid" if mode == "invalid" else sys.argv[3]
    os.kill = injected_kill
    sys.argv = ["release-lock-probe", probe_pid]
    exec(probe_code, {{"__name__": "__main__"}})
    raise SystemExit(0)

os.execv(sys.executable, [sys.executable, *sys.argv[1:]])
""",
        encoding="utf-8",
    )
    shim.chmod(0o755)
    return destination


def _install_complete_lock_owner(home: Path, suffix: str = "fixture") -> Path:
    parent = Path(os.path.realpath(_versions(home).parent))
    owner = parent / f".fantasydisk-release-director.lock-owner.{suffix}"
    owner.mkdir()
    (owner / "pid").write_text("1\n", encoding="ascii")
    return owner


def _write_schema_valid_residue_marker(
    parent: Path,
    namespace: str,
    suffix: str,
    kind: str,
    target: str,
    tree: str,
) -> Path:
    """Create the old public v1 shape without claiming it is trustworthy."""
    marker = parent / f".fantasydisk-release-director.residue-owner.{namespace}.{suffix}"
    encoded_target = base64.urlsafe_b64encode(target.encode("utf-8")).decode("ascii")
    marker.write_text(
        "magic=fantasydisk-release-director-residue-v1\n"
        f"namespace={namespace}\n"
        f"residue=.fantasydisk-release-director.{namespace}.{suffix}\n"
        f"parent={parent}\n"
        f"kind={kind}\n"
        f"target={encoded_target}\n"
        f"tree={tree}\n"
        f"pid={os.getpid()}\n"
        "files=7\n",
        encoding="ascii",
    )
    marker.chmod(0o600)
    return marker


def _write_pre_fix_onboard(destination: Path) -> Path:
    result = subprocess.run(
        ["git", "show", f"{PRE_FIX_ONBOARD_COMMIT}:scripts/onboard.sh"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )
    destination.write_bytes(result.stdout)
    destination.chmod(0o755)
    return destination


@unittest.skipIf(os.name == "nt", "release onboarding execution requires POSIX/Bash")
class ReleaseSkillOnboardingTest(unittest.TestCase):
    def test_release_only_mode_isolated_from_unrelated_runtime_state(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-release-only-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = workspace / "checkout"
            _make_disposable_source_checkout(checkout)

            codex_skill = home / ".codex" / "skills" / "unrelated-codex-skill"
            claude_skill = home / ".claude" / "skills" / "unrelated-claude-skill"
            codex_skill.mkdir(parents=True)
            claude_skill.mkdir(parents=True)
            (codex_skill / "operator.md").write_bytes(b"Codex operator data\n")
            (claude_skill / "operator.md").write_bytes(b"Claude operator data\n")
            operator_file = home / ".codex" / "operator-state.json"
            daemon_file = home / ".multica" / "daemon-state.json"
            operator_file.write_bytes(b'{"operator":"keep"}\n')
            daemon_file.parent.mkdir(parents=True)
            daemon_file.write_bytes(b'{"daemon":"keep"}\n')

            hooks_path = workspace / "custom-hooks"
            hooks_path.mkdir()
            subprocess.run(
                ["git", "config", "--local", "core.hooksPath", str(hooks_path)],
                cwd=checkout,
                check=True,
            )
            git_config = checkout / ".git" / "config"
            before = {
                "git_config": git_config.read_bytes(),
                "codex": _inventory(codex_skill),
                "claude": _inventory(claude_skill),
                "operator": operator_file.read_bytes(),
                "daemon": daemon_file.read_bytes(),
                "hooks": subprocess.run(
                    ["git", "config", "--local", "--get", "core.hooksPath"],
                    cwd=checkout,
                    check=True,
                    stdout=subprocess.PIPE,
                    encoding="utf-8",
                ).stdout,
            }

            result = _run_release_only(checkout / "scripts" / "onboard.sh", home)

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("MIRROR", result.stdout)
            self.assertIn("SELECTION", result.stdout)
            self.assertNotIn("Linking Codex skills", result.stdout)
            self.assertNotIn("Linking Claude skills", result.stdout)
            self.assertNotIn("onboarding complete", result.stdout.lower())
            self.assertNotIn("daemon", result.stdout.lower())
            _assert_durable_selected_tree(
                home,
                checkout / "skills" / "codex" / "fantasydisk-release-director",
            )
            selected_publisher = (
                _selected(home)
                / "scripts"
                / "github_release_publish.py"
            ).read_text(encoding="utf-8")
            self.assertIn(
                "type(installation_id) is not int or installation_id <= 0",
                selected_publisher,
            )

            self.assertEqual(git_config.read_bytes(), before["git_config"])
            self.assertEqual(_inventory(codex_skill), before["codex"])
            self.assertEqual(_inventory(claude_skill), before["claude"])
            self.assertEqual(operator_file.read_bytes(), before["operator"])
            self.assertEqual(daemon_file.read_bytes(), before["daemon"])
            hooks_after = subprocess.run(
                ["git", "config", "--local", "--get", "core.hooksPath"],
                cwd=checkout,
                check=True,
                stdout=subprocess.PIPE,
                encoding="utf-8",
            ).stdout
            self.assertEqual(hooks_after, before["hooks"])

    def test_release_only_mode_rejects_extra_arguments_without_creating_state(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-release-only-args-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = workspace / "checkout"
            _make_disposable_source_checkout(checkout)

            result = subprocess.run(
                [
                    "bash",
                    str(checkout / "scripts" / "onboard.sh"),
                    "--release-only",
                    "--unexpected",
                ],
                cwd=checkout,
                env=_onboard_environment(checkout / "scripts" / "onboard.sh", home),
                encoding="utf-8",
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )

            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn("usage:", result.stdout)
            self.assertNotIn("Linking Codex skills", result.stdout)
            self.assertFalse((home / ".codex").exists())

    def test_previous_onboarding_reproduces_silent_skip_and_drift(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-before-") as raw:
            home = Path(raw)
            target = home / ".codex" / "skills" / "fantasydisk-release-director"
            target.mkdir(parents=True)
            _extract_legacy_skill(target)
            repo_tmp = ROOT / "tmp"
            repo_tmp_was_present = repo_tmp.exists()
            repo_tmp.mkdir(exist_ok=True)
            old_script_fd, old_script_name = tempfile.mkstemp(
                prefix="onboard-before-fan1299-", suffix=".sh", dir=repo_tmp
            )
            os.close(old_script_fd)
            old_script = Path(old_script_name)
            try:
                _write_pre_fix_onboard(old_script)
                result = _run_onboard(old_script, home)
            finally:
                old_script.unlink(missing_ok=True)
                if not repo_tmp_was_present:
                    try:
                        repo_tmp.rmdir()
                    except OSError:
                        pass

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("SKIP", result.stdout)
            self.assertTrue(target.is_dir())
            self.assertFalse(target.is_symlink())
            self.assertEqual(_file_sha256(target / "SKILL.md"), LEGACY_SKILL_MD_SHA256)
            self.assertFalse((target / "scripts" / "build_update_manifest.py").exists())

    def test_known_legacy_copy_is_migrated_to_complete_repo_tree(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-migrate-") as raw:
            home = Path(raw)
            target = _selected(home)
            target.mkdir(parents=True)
            _extract_legacy_skill(target)

            result = _run_onboard(ONBOARD, home)

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("MIGRATE", result.stdout)
            _assert_durable_selected_tree(home, SOURCE_SKILL)
            self.assertTrue(EXPECTED_RELEASE_SKILL_FILES.issubset(_inventory(SOURCE_SKILL)))

            skill_text = (target / "SKILL.md").read_text(encoding="utf-8")
            for marker in (
                "X.Y.Z.R",
                "unsigned",
                "FomaBy/FantasyDisk-Releases",
                "mandatory Telegram",
                "only safe action",
            ):
                self.assertIn(marker, skill_text)
            self.assertNotIn("tools/build_release.sh X.Y.Z", skill_text)
            self.assertNotIn("signed-only", skill_text.lower())

    def test_unknown_real_release_directory_is_preserved_and_blocks(self) -> None:
        mutations = {
            "extra operator file": lambda target: (target / "operator-notes.txt").write_text(
                "local operator data\n", encoding="utf-8"
            ),
            "changed tracked file": lambda target: (target / "scripts" / "local_release.py").write_text(
                (target / "scripts" / "local_release.py").read_text(encoding="utf-8")
                + "\n# operator WIP\n",
                encoding="utf-8",
            ),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-block-"
            ) as raw:
                home = Path(raw)
                target = home / ".codex" / "skills" / "fantasydisk-release-director"
                target.mkdir(parents=True)
                _extract_legacy_skill(target)
                mutate(target)
                before = _inventory(target)

                result = _run_onboard(ONBOARD, home)

                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("BLOCK", result.stdout)
                self.assertIn("preserved", result.stdout.lower())
                self.assertTrue(target.is_dir())
                self.assertFalse(target.is_symlink())
                self.assertEqual(_inventory(target), before)

    def test_unproven_residue_namespaces_preserve_directories_and_symlinks(self) -> None:
        """Filename matches never authorize cleanup in any managed namespace."""
        cases = (
            ("staging-mirror", "staging", "mirror"),
            ("staging-versions", "staging", "versions"),
            ("mirror-stage", "mirror-stage", "mirror"),
            ("selection", "selection", "selection"),
            ("legacy-selection", "legacy", "selection"),
            ("legacy-mirror", "legacy-mirror", "mirror"),
        )
        for case_name, namespace, parent_kind in cases:
            for residue_kind in ("directory", "symlink"):
                with self.subTest(case=case_name, residue_kind=residue_kind), tempfile.TemporaryDirectory(
                    prefix="fantasydisk-onboard-unproven-residue-"
                ) as raw:
                    workspace = Path(raw)
                    home = workspace / "home"
                    mirror_parent = home / ".codex" / "skill-mirrors" / "FantasyDisk"
                    versions = mirror_parent / ".fantasydisk-release-director.versions"
                    selection_parent = home / ".codex" / "skills"
                    mirror_parent.mkdir(parents=True)
                    versions.mkdir()
                    selection_parent.mkdir(parents=True)

                    parent = mirror_parent if parent_kind == "mirror" else (
                        versions if parent_kind == "versions" else selection_parent
                    )
                    residue = parent / f".fantasydisk-release-director.{namespace}.operator"
                    external = workspace / "external-sentinel"
                    external.mkdir()
                    (external / "keep.txt").write_bytes(b"operator data must survive\n")
                    if residue_kind == "directory":
                        residue.mkdir()
                        (residue / "keep.txt").write_bytes(b"operator data must survive\n")
                        residue_before = _inventory(residue)
                    else:
                        residue.symlink_to(external, target_is_directory=True)
                        residue_before = _lstat_or_absent(residue)
                    external_before = _inventory(external)

                    result = _run_onboard(ONBOARD, home)

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("BLOCK", result.stdout)
                    self.assertIn("preserved", result.stdout.lower())
                    if residue_kind == "directory":
                        self.assertEqual(_inventory(residue), residue_before)
                    else:
                        self.assertEqual(_lstat_or_absent(residue), residue_before)
                    self.assertEqual(_inventory(external), external_before)

    def test_malformed_residue_provenance_is_preserved_and_blocks(self) -> None:
        marker_variants = ("malformed", "incomplete", "unreadable", "symlink")
        for variant in marker_variants:
            with self.subTest(variant=variant), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-malformed-residue-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                parent = home / ".codex" / "skill-mirrors" / "FantasyDisk"
                versions = parent / ".fantasydisk-release-director.versions"
                parent.mkdir(parents=True)
                versions.mkdir()
                residue = parent / ".fantasydisk-release-director.staging.operator"
                residue.mkdir()
                (residue / "keep.txt").write_bytes(b"operator data must survive\n")
                marker = parent / ".fantasydisk-release-director.residue-owner.staging.operator"
                external = workspace / "external-marker-target"
                external.write_bytes(b"external marker target\n")
                if variant == "malformed":
                    marker.write_text("not a provenance record\n", encoding="ascii")
                elif variant == "incomplete":
                    marker.write_text(
                        "magic=fantasydisk-release-director-residue-v1\n", encoding="ascii"
                    )
                elif variant == "unreadable":
                    marker.write_text("unreadable\n", encoding="ascii")
                    marker.chmod(0)
                else:
                    marker.symlink_to(external)
                residue_before = _inventory(residue)
                marker_before = _metadata_signature(marker)
                external_before = _inventory(external)

                result = _run_onboard(ONBOARD, home)

                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("BLOCK", result.stdout)
                self.assertEqual(_inventory(residue), residue_before)
                self.assertEqual(_metadata_signature(marker), marker_before)
                self.assertEqual(_inventory(external), external_before)

    def test_all_persistent_residue_and_marker_states_block_without_mutation(self) -> None:
        """A same-UID process can forge every persistent v1 evidence shape."""
        namespaces = (
            ("staging-mirror", "staging", "mirror", "directory"),
            ("staging-versions", "staging", "versions", "directory"),
            ("mirror-stage", "mirror-stage", "mirror", "symlink"),
            ("selection", "selection", "selection", "symlink"),
            ("legacy-selection", "legacy", "selection", "directory"),
            ("legacy-mirror", "legacy-mirror", "mirror", "directory"),
        )
        marker_variants = (
            "exact-schema",
            "marker-only",
            "malformed",
            "incomplete",
            "unreadable",
            "wrong-type",
            "symlinked",
        )
        for case_name, namespace, parent_kind, expected_kind in namespaces:
            for variant in marker_variants:
                with self.subTest(case=case_name, variant=variant), tempfile.TemporaryDirectory(
                    prefix="fantasydisk-onboard-persistent-state-"
                ) as raw:
                    workspace = Path(raw)
                    home = workspace / "home"
                    mirror_parent = home / ".codex" / "skill-mirrors" / "FantasyDisk"
                    versions = _versions(home)
                    selection_parent = home / ".codex" / "skills"
                    mirror_parent.mkdir(parents=True)
                    versions.mkdir()
                    selection_parent.mkdir(parents=True)
                    parent = (
                        mirror_parent
                        if parent_kind == "mirror"
                        else versions
                        if parent_kind == "versions"
                        else selection_parent
                    )
                    suffix = "operator"
                    residue = parent / f".fantasydisk-release-director.{namespace}.{suffix}"
                    marker = parent / (
                        f".fantasydisk-release-director.residue-owner.{namespace}.{suffix}"
                    )
                    external = workspace / "external-sentinel"
                    external.mkdir()
                    (external / "keep.txt").write_bytes(b"must not be followed or changed\n")

                    if variant != "marker-only":
                        actual_kind = (
                            "symlink"
                            if variant == "wrong-type" and expected_kind == "directory"
                            else "directory"
                            if variant == "wrong-type"
                            else expected_kind
                        )
                        if actual_kind == "directory":
                            residue.mkdir()
                            (residue / "keep.txt").write_bytes(b"operator residue\n")
                        else:
                            residue.symlink_to(external, target_is_directory=True)

                    if variant == "malformed":
                        marker.write_text("not a marker\n", encoding="ascii")
                    elif variant == "incomplete":
                        marker.write_text(
                            "magic=fantasydisk-release-director-residue-v1\n",
                            encoding="ascii",
                        )
                    elif variant == "unreadable":
                        marker.write_text("unreadable\n", encoding="ascii")
                        marker.chmod(0)
                    elif variant == "wrong-type":
                        marker.mkdir()
                    elif variant == "symlinked":
                        marker.symlink_to(external / "keep.txt")
                    else:
                        marker = _write_schema_valid_residue_marker(
                            parent,
                            namespace,
                            suffix,
                            expected_kind,
                            str(external) if expected_kind == "symlink" else "-",
                            "0" * 64,
                        )

                    mirror_before = (
                        None if variant == "unreadable" else _inventory(mirror_parent)
                    )
                    selection_before = (
                        None if variant == "unreadable" else _inventory(selection_parent)
                    )
                    residue_before = _lstat_or_absent(residue)
                    marker_before = _metadata_signature(marker)
                    external_before = _inventory(external)
                    selection_hook = workspace / "selection-hook"
                    result = _run_onboard(
                        ONBOARD,
                        home,
                        extra={
                            "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(
                                selection_hook
                            )
                        },
                    )

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("BLOCK", result.stdout)
                    self.assertIn("pre-existing", result.stdout)
                    self.assertFalse(selection_hook.exists())
                    if mirror_before is not None:
                        self.assertEqual(_inventory(mirror_parent), mirror_before)
                    if selection_before is not None:
                        self.assertEqual(_inventory(selection_parent), selection_before)
                    self.assertEqual(_lstat_or_absent(residue), residue_before)
                    self.assertEqual(_metadata_signature(marker), marker_before)
                    self.assertEqual(_inventory(external), external_before)
                    if variant == "unreadable":
                        marker.chmod(0o600)

    def test_marker_without_residue_variants_are_preserved_in_every_namespace(self) -> None:
        namespaces = (
            ("staging-mirror", "staging", "mirror", "directory"),
            ("staging-versions", "staging", "versions", "directory"),
            ("mirror-stage", "mirror-stage", "mirror", "symlink"),
            ("selection", "selection", "selection", "symlink"),
            ("legacy-selection", "legacy", "selection", "directory"),
            ("legacy-mirror", "legacy-mirror", "mirror", "directory"),
        )
        variants = (
            "exact-schema",
            "malformed",
            "incomplete",
            "unreadable",
            "wrong-type",
            "symlinked",
            "foreign",
        )
        for case_name, namespace, parent_kind, expected_kind in namespaces:
            for variant in variants:
                with self.subTest(case=case_name, variant=variant), tempfile.TemporaryDirectory(
                    prefix="fantasydisk-onboard-marker-only-"
                ) as raw:
                    workspace = Path(raw)
                    home = workspace / "home"
                    mirror_parent = home / ".codex" / "skill-mirrors" / "FantasyDisk"
                    versions = _versions(home)
                    selection_parent = home / ".codex" / "skills"
                    mirror_parent.mkdir(parents=True)
                    versions.mkdir()
                    selection_parent.mkdir(parents=True)
                    parent = (
                        mirror_parent
                        if parent_kind == "mirror"
                        else versions
                        if parent_kind == "versions"
                        else selection_parent
                    )
                    suffix = "marker-only"
                    marker = parent / (
                        f".fantasydisk-release-director.residue-owner.{namespace}.{suffix}"
                    )
                    external = workspace / "external-sentinel"
                    external.write_bytes(b"must not be opened or changed\n")
                    if variant == "malformed":
                        marker.write_bytes(b"not a marker\n")
                    elif variant == "incomplete":
                        marker.write_bytes(b"magic=fantasydisk-release-director-residue-v1\n")
                    elif variant == "unreadable":
                        marker.write_bytes(b"unreadable\n")
                        marker.chmod(0)
                    elif variant == "wrong-type":
                        marker.mkdir()
                    elif variant == "symlinked":
                        marker.symlink_to(external)
                    else:
                        marker = _write_schema_valid_residue_marker(
                            parent,
                            namespace,
                            suffix,
                            expected_kind,
                            str(external) if expected_kind == "symlink" else "-",
                            "0" * 64,
                        )
                        if variant == "foreign":
                            marker.write_text(
                                marker.read_text(encoding="ascii").replace(
                                    f"parent={parent}", f"parent={external.parent}"
                                ),
                                encoding="ascii",
                            )

                    marker_before = _metadata_signature(marker)
                    external_before = _file_sha256(external)
                    selection_hook = workspace / "selection-hook"
                    result = _run_onboard(
                        ONBOARD,
                        home,
                        extra={
                            "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(
                                selection_hook
                            )
                        },
                    )

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("pre-existing", result.stdout)
                    self.assertFalse(selection_hook.exists())
                    self.assertEqual(_metadata_signature(marker), marker_before)
                    self.assertEqual(_file_sha256(external), external_before)
                    if variant == "unreadable":
                        marker.chmod(0o600)

    def test_symlinked_entries_are_preserved_and_block_without_following_targets(self) -> None:
        mutations = {}
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-link-target-") as raw:
            external = Path(raw) / "external-skill.md"
            external.write_bytes(b"same bytes as the tracked legacy file\n")
            mutations["same-byte SKILL.md symlink"] = lambda target: (
                (target / "SKILL.md").unlink(),
                (target / "SKILL.md").symlink_to(external),
            )

            for name, mutate in mutations.items():
                with self.subTest(name=name), tempfile.TemporaryDirectory(
                    prefix="fantasydisk-onboard-symlink-"
                ) as home_raw:
                    home = Path(home_raw)
                    target = home / ".codex" / "skills" / "fantasydisk-release-director"
                    target.mkdir(parents=True)
                    _extract_legacy_skill(target)
                    external.write_bytes((target / "SKILL.md").read_bytes())
                    mutate(target)
                    before = _inventory(target)
                    external_before = _file_sha256(external)

                    result = _run_onboard(ONBOARD, home)

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("BLOCK", result.stdout)
                    self.assertEqual(_inventory(target), before)
                    self.assertEqual(_file_sha256(external), external_before)
                    self.assertTrue((target / "SKILL.md").is_symlink())

        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-symlink-") as raw:
            home = Path(raw)
            target = home / ".codex" / "skills" / "fantasydisk-release-director"
            target.mkdir(parents=True)
            _extract_legacy_skill(target)
            dangling = target / "dangling-link"
            dangling.symlink_to(home / "missing-target")
            extra = target / "extra-link"
            extra.symlink_to(home, target_is_directory=True)
            before = _inventory(target)

            result = _run_onboard(ONBOARD, home)

            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("BLOCK", result.stdout)
            self.assertEqual(_inventory(target), before)
            self.assertEqual(os.readlink(dangling), str(home / "missing-target"))
            self.assertEqual(os.readlink(extra), str(home))

    def test_fifo_is_preserved_and_blocks(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-fifo-") as raw:
            home = Path(raw)
            target = home / ".codex" / "skills" / "fantasydisk-release-director"
            target.mkdir(parents=True)
            _extract_legacy_skill(target)
            fifo = target / "operator-pipe"
            os.mkfifo(fifo)
            before = _inventory(target)

            result = _run_onboard(ONBOARD, home)

            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("BLOCK", result.stdout)
            self.assertEqual(_inventory(target), before)
            self.assertTrue(fifo.exists())

    def test_fifo_is_preserved_and_blocks_repeatedly_without_leaking(self) -> None:
        """FAN-3837 regression: CI saw this scenario stall past the idle watchdog.

        `_run_onboard` now asserts its process group is fully gone on every
        return (see `_assert_process_group_exited`), and the legacy fixture's
        git call can no longer stall unboundedly (see `_extract_legacy_skill`).
        Five consecutive runs give that invariant real odds of catching a
        reintroduced leak instead of passing by luck on a single attempt.
        """
        for attempt in range(5):
            with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-fifo-") as raw:
                home = Path(raw)
                target = home / ".codex" / "skills" / "fantasydisk-release-director"
                target.mkdir(parents=True)
                _extract_legacy_skill(target)
                fifo = target / "operator-pipe"
                os.mkfifo(fifo)
                before = _inventory(target)

                result = _run_onboard(ONBOARD, home)

                self.assertNotEqual(result.returncode, 0, f"attempt {attempt}: {result.stdout}")
                self.assertIn("BLOCK", result.stdout, f"attempt {attempt}")
                self.assertEqual(_inventory(target), before, f"attempt {attempt}")
                self.assertTrue(fifo.exists(), f"attempt {attempt}")

    def test_watchdog_terminates_process_group_and_reports_captured_output(self) -> None:
        temp_root: Path | None = None
        child_pids: list[int] = []
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-watchdog-") as raw:
            temp_root = Path(raw)
            script = temp_root / "checkout" / "scripts" / "hang.sh"
            pid_file = temp_root / "child-pids.txt"
            script.parent.mkdir(parents=True)
            script.write_text(
                "#!/bin/bash\n"
                f"printf 'parent=%s\\n' \"$$\" > {pid_file}\n"
                "printf 'watchdog fixture started\\n'\n"
                "sleep 300 &\n"
                "printf 'child=%s\\n' \"$!\" >> "
                f"{pid_file}\n"
                "wait\n",
                encoding="utf-8",
            )
            script.chmod(0o755)

            with self.assertRaises(AssertionError) as raised:
                _run_onboard(script, temp_root / "home", timeout=0.2)
            message = str(raised.exception)
            self.assertIn("onboarding child timed out after", message)
            self.assertIn("captured output:\nwatchdog fixture started", message)

            child_pids = [
                int(line.split("=", 1)[1])
                for line in pid_file.read_text(encoding="ascii").splitlines()
            ]
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                if all(
                    not _process_is_alive(pid)
                    for pid in child_pids
                ):
                    break
                time.sleep(0.01)
            self.assertTrue(all(not _process_is_alive(pid) for pid in child_pids))

        self.assertIsNotNone(temp_root)
        self.assertFalse(temp_root.exists())

    def test_mode_drift_is_preserved_and_blocks(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-mode-") as raw:
            home = Path(raw)
            target = home / ".codex" / "skills" / "fantasydisk-release-director"
            target.mkdir(parents=True)
            _extract_legacy_skill(target)
            skill_md = target / "SKILL.md"
            skill_md.chmod(0o600)
            before = _inventory(target)

            result = _run_onboard(ONBOARD, home)

            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("BLOCK", result.stdout)
            self.assertEqual(_inventory(target), before)
            self.assertEqual(before["SKILL.md"][1], "0600")

    def test_fresh_isolated_home_selects_repo_provenance(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-fresh-") as raw:
            home = Path(raw)

            result = _run_onboard(ONBOARD, home)

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertTrue(_versions(home).is_dir())
            self.assertFalse(_versions(home).is_symlink())
            _assert_durable_selected_tree(home, SOURCE_SKILL)

    def test_unsafe_versions_root_fails_closed_before_first_run_traversal(self) -> None:
        for kind in (
            "symlink-to-directory",
            "dangling-symlink",
            "regular-file",
            "fifo",
            "socket",
        ):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory(
                prefix="u-"
            ) as raw:
                workspace = Path(raw).resolve()
                home = Path(tempfile.mkdtemp(prefix="h-", dir="/tmp")).resolve()
                self.addCleanup(shutil.rmtree, home, ignore_errors=True)
                external = workspace / "external-sentinel"
                _make_external_versions_sentinel(external)
                listener = None
                try:
                    listener = _install_unsafe_versions_root(_versions(home), kind, external)
                    external_before = _inventory(external)
                    root_before = _lstat_signature(_versions(home))
                    result = _run_onboard(ONBOARD, home)

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("BLOCK", result.stdout)
                    self.assertIn("version store", result.stdout.lower())
                    self.assertEqual(_inventory(external), external_before)
                    self.assertEqual(_lstat_signature(_versions(home)), root_before)
                    self.assertFalse(_selected(home).exists())
                    self.assertFalse(_selected(home).is_symlink())
                    self.assertFalse(_mirror_pointer(home).exists())
                    self.assertFalse(_mirror_pointer(home).is_symlink())
                    managed_parent = _versions(home).parent
                    self.assertFalse(
                        (managed_parent / ".fantasydisk-release-director.lock").exists()
                    )
                    self.assertEqual(
                        list(managed_parent.glob(".fantasydisk-release-director.staging.*")),
                        [],
                    )
                    self.assertEqual(
                        list(managed_parent.glob(".fantasydisk-release-director.mirror-stage.*")),
                        [],
                    )
                finally:
                    if listener is not None:
                        listener.close()

    def test_unsafe_versions_root_preserves_existing_selection_and_mirror(self) -> None:
        for kind in (
            "symlink-to-directory",
            "dangling-symlink",
            "regular-file",
            "fifo",
            "socket",
        ):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory(
                prefix="u-"
            ) as raw:
                workspace = Path(raw).resolve()
                home = Path(tempfile.mkdtemp(prefix="h-", dir="/tmp")).resolve()
                self.addCleanup(shutil.rmtree, home, ignore_errors=True)
                initial = _run_onboard(ONBOARD, home)
                self.assertEqual(initial.returncode, 0, initial.stdout)

                previous_target = Path(os.path.realpath(_mirror_pointer(home)))
                previous_inventory = _inventory(previous_target)
                preserved_target = workspace / "prior-valid-tree"
                shutil.copytree(previous_target, preserved_target)

                # Keep both durable pointers byte-identical throughout the
                # unsafe-root probe while their prior valid target remains
                # resolvable outside the root being rejected.
                for pointer in (_selected(home), _mirror_pointer(home)):
                    pointer.unlink()
                    pointer.symlink_to(preserved_target)
                selected_before = os.readlink(_selected(home))
                mirror_before = os.readlink(_mirror_pointer(home))

                shutil.rmtree(_versions(home))
                external = workspace / "external-sentinel"
                _make_external_versions_sentinel(external)
                listener = None
                try:
                    listener = _install_unsafe_versions_root(_versions(home), kind, external)
                    external_before = _inventory(external)
                    root_before = _lstat_signature(_versions(home))
                    result = _run_onboard(ONBOARD, home)

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("BLOCK", result.stdout)
                    self.assertIn("version store", result.stdout.lower())
                    self.assertEqual(os.readlink(_selected(home)), selected_before)
                    self.assertEqual(os.readlink(_mirror_pointer(home)), mirror_before)
                    self.assertEqual(
                        Path(os.path.realpath(_selected(home))), preserved_target.resolve()
                    )
                    self.assertEqual(
                        Path(os.path.realpath(_mirror_pointer(home))), preserved_target.resolve()
                    )
                    self.assertEqual(_inventory(preserved_target), previous_inventory)
                    self.assertEqual(_inventory(external), external_before)
                    self.assertEqual(_lstat_signature(_versions(home)), root_before)
                    self.assertFalse(
                        (home / ".codex" / "skill-mirrors" / "FantasyDisk" / ".fantasydisk-release-director.lock").exists()
                    )
                finally:
                    if listener is not None:
                        listener.close()

    def test_selected_skill_uses_durable_mirror_not_the_source_checkout(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-durable-") as raw:
            home = Path(raw)

            result = _run_onboard(ONBOARD, home)

            self.assertEqual(result.returncode, 0, result.stdout)
            _assert_durable_selected_tree(home, SOURCE_SKILL)
            self.assertNotIn(str(SOURCE_SKILL.resolve()), os.readlink(_selected(home)))
            self.assertNotIn("multica_workspaces", os.readlink(_selected(home)))

    def test_untrusted_selected_links_are_rejected_without_reading_operator_data(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-link-repair-") as raw:
            home = Path(raw)
            self.assertEqual(_run_onboard(ONBOARD, home).returncode, 0)
            target = _selected(home)
            external = home / "operator-wip"
            external.mkdir()
            (external / "notes.txt").write_text("do not copy or remove\n", encoding="utf-8")
            external_before = _inventory(external)

            target.unlink()
            target.symlink_to(external, target_is_directory=True)
            repaired = _run_onboard(ONBOARD, home)

            self.assertEqual(repaired.returncode, 0, repaired.stdout)
            self.assertIn("REJECT", repaired.stdout)
            self.assertEqual(_inventory(external), external_before)
            _assert_durable_selected_tree(home, SOURCE_SKILL)

            target.unlink()
            target.symlink_to(home / "removed-task-worktree")
            repaired_dangling = _run_onboard(ONBOARD, home)

            self.assertEqual(repaired_dangling.returncode, 0, repaired_dangling.stdout)
            self.assertIn("REJECT", repaired_dangling.stdout)
            _assert_durable_selected_tree(home, SOURCE_SKILL)

    def test_managed_mirror_update_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-idempotent-") as raw:
            home = Path(raw)

            first = _run_onboard(ONBOARD, home)
            before = _inventory(_mirror(home))
            second = _run_onboard(ONBOARD, home)

            self.assertEqual(first.returncode, 0, first.stdout)
            self.assertEqual(second.returncode, 0, second.stdout)
            self.assertIn("up-to-date", second.stdout)
            self.assertEqual(_inventory(_mirror(home)), before)
            self.assertEqual(
                list(_versions(home).glob(".fantasydisk-release-director.staging.*")), []
            )

    def test_failed_staging_preserves_last_known_good_mirror_and_selection(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-rollback-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = _make_disposable_source_checkout(workspace / "disposable-checkout")
            script = checkout / "scripts" / "onboard.sh"
            initial = _run_onboard(script, home)
            self.assertEqual(initial.returncode, 0, initial.stdout)
            mirror_before = _inventory(_mirror(home))
            selected_before = os.readlink(_selected(home))

            skill_md = checkout / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md"
            skill_md.write_text(skill_md.read_text(encoding="utf-8") + "\n", encoding="utf-8")
            subprocess.run(
                ["git", "add", str(skill_md.relative_to(checkout))],
                cwd=checkout,
                check=True,
            )
            subprocess.run(["git", "commit", "-m", "updated test source"], cwd=checkout, check=True)

            fake_bin = _fake_multica(home)
            fake_cp = fake_bin / "cp"
            fake_cp.write_text(
                "#!/bin/sh\n"
                "/bin/cp \"$@\" || exit $?\n"
                "for arg in \"$@\"; do destination=\"$arg\"; done\n"
                "printf 'staging mutation\\n' > \"$destination/unexpected-file\"\n",
                encoding="utf-8",
            )
            fake_cp.chmod(0o755)

            failed = _run_onboard(script, home, path_prefix=fake_bin)

            self.assertNotEqual(failed.returncode, 0, failed.stdout)
            self.assertIn("immutable version", failed.stdout)
            self.assertEqual(_inventory(_mirror(home)), mirror_before)
            self.assertEqual(os.readlink(_selected(home)), selected_before)
            self.assertTrue((_selected(home) / "SKILL.md").is_file())
            self.assertEqual(
                list(_versions(home).glob(".fantasydisk-release-director.staging.*")), []
            )

    def test_changed_source_has_continuous_old_or_new_selection(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-continuity-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = _make_disposable_source_checkout(workspace / "checkout")
            script = checkout / "scripts" / "onboard.sh"
            self.assertEqual(_run_onboard(script, home).returncode, 0)
            old_target = Path(os.path.realpath(_selected(home)))
            old_snapshot = _inventory(old_target)

            _commit_source_change(checkout, "changed-source-continuity")
            new_source = checkout / "skills" / "codex" / "fantasydisk-release-director"
            new_snapshot = _inventory(new_source)
            before = workspace / "before-selection-commit"
            after = workspace / "after-selection-commit"
            process = _start_onboard(
                script,
                home,
                extra={
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(before),
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_SELECTION_COMMIT": str(after),
                },
            )
            _wait_for_marker(before, process)
            self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), old_snapshot)

            errors: list[str] = []
            stop_reader = threading.Event()

            def read_selected_until_done() -> None:
                while not stop_reader.is_set():
                    try:
                        selected_target = _selected(home)
                        if not selected_target.is_symlink():
                            raise AssertionError("selected path stopped being a symlink")
                        resolved = Path(os.path.realpath(selected_target))
                        observed = _inventory(resolved)
                        if observed not in (old_snapshot, new_snapshot):
                            raise AssertionError("reader observed mixed or unexpected inventory")
                    except (OSError, AssertionError) as exc:
                        errors.append(str(exc))
                        return

            reader = threading.Thread(target=read_selected_until_done)
            reader.start()
            before.unlink()
            _wait_for_marker(after, process)
            self.assertEqual(_inventory(old_target), old_snapshot)
            self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), new_snapshot)
            after.unlink()
            output = process.communicate(timeout=10)[0]
            stop_reader.set()
            reader.join(timeout=10)

            self.assertEqual(process.returncode, 0, output)
            self.assertEqual(errors, [])
            _assert_durable_selected_tree(home, new_source)

    def test_failure_before_commit_preserves_old_and_after_commit_keeps_new(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-fault-boundaries-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = _make_disposable_source_checkout(workspace / "checkout")
            script = checkout / "scripts" / "onboard.sh"
            self.assertEqual(_run_onboard(script, home).returncode, 0)
            old_snapshot = _inventory(Path(os.path.realpath(_selected(home))))

            _commit_source_change(checkout, "pre-commit-fault")
            source = checkout / "skills" / "codex" / "fantasydisk-release-director"
            new_snapshot = _inventory(source)
            failed_before = _run_onboard(
                script,
                home,
                extra={"FANTASYDISK_ONBOARD_TEST_FAIL_BEFORE_SELECTION_COMMIT": "1"},
            )
            self.assertNotEqual(failed_before.returncode, 0, failed_before.stdout)
            self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), old_snapshot)
            retry_before = _run_onboard(script, home)
            self.assertEqual(retry_before.returncode, 0, retry_before.stdout)
            self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), new_snapshot)

            _commit_source_change(checkout, "post-commit-fault")
            source = checkout / "skills" / "codex" / "fantasydisk-release-director"
            newest_snapshot = _inventory(source)
            failed_after = _run_onboard(
                script,
                home,
                extra={"FANTASYDISK_ONBOARD_TEST_FAIL_AFTER_SELECTION_COMMIT": "1"},
            )
            self.assertNotEqual(failed_after.returncode, 0, failed_after.stdout)
            self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), newest_snapshot)
            retry_after = _run_onboard(script, home)
            self.assertEqual(retry_after.returncode, 0, retry_after.stdout)
            _assert_durable_selected_tree(home, source)

    def test_selection_activation_rejects_replaced_captured_entries(self) -> None:
        """Selection must not commit a stage, parent, destination, or marker replacement."""
        for replacement_kind in ("parent", "stage", "destination", "marker", "equivalent-stage"):
            with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-selection-activation-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                self.assertEqual(_run_onboard(script, home).returncode, 0)
                old_target = os.readlink(_selected(home))
                _commit_source_change(checkout, f"selection-{replacement_kind}")
                pause = workspace / "before-selection-commit"
                process = _start_onboard(
                    script,
                    home,
                    extra={"FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(pause)},
                )
                _wait_for_marker(pause, process)

                selection_parent = _selected(home).parent
                stage = next(selection_parent.glob(".fantasydisk-release-director.selection.*"))
                marker = next(
                    selection_parent.glob(
                        ".fantasydisk-release-director.residue-owner.selection.*"
                    )
                )
                external = workspace / "external-sentinel"
                external.mkdir()
                (external / "keep.txt").write_bytes(b"must not be touched\n")
                external_before = _inventory(external)

                if replacement_kind == "parent":
                    moved_parent = workspace / "original-selection-parent"
                    selection_parent.rename(moved_parent)
                    selection_parent.mkdir()
                    replacement = selection_parent / stage.name
                    replacement.symlink_to(external, target_is_directory=True)
                    replacement_marker = selection_parent / marker.name
                    replacement_marker.write_bytes(b"replacement marker\n")
                    expected = (_physical_signature(replacement), _physical_signature(replacement_marker))
                elif replacement_kind == "destination":
                    replacement = _selected(home)
                    replacement.unlink()
                    replacement.symlink_to(old_target, target_is_directory=True)
                    expected = _physical_signature(replacement)
                elif replacement_kind == "marker":
                    replacement = marker
                    marker.unlink()
                    marker.write_bytes(b"replacement marker\n")
                    expected = _physical_signature(replacement)
                else:
                    replacement = stage
                    original = _physical_signature(stage)
                    raw_target = os.readlink(stage)
                    stage.unlink()
                    stage.symlink_to(
                        raw_target if replacement_kind == "equivalent-stage" else external,
                        target_is_directory=True,
                    )
                    expected = _physical_signature(replacement)
                    if replacement_kind == "equivalent-stage":
                        self.assertEqual(os.readlink(replacement), raw_target)
                        self.assertNotEqual(expected, original)

                pause.unlink()
                output = process.communicate(timeout=10)[0]

                self.assertNotEqual(process.returncode, 0, output)
                self.assertNotIn("SELECTION_COMMIT", output)
                self.assertNotIn("linked ", output)
                self.assertEqual(_inventory(external), external_before)
                if replacement_kind == "parent":
                    self.assertEqual(
                        (
                            _physical_signature(selection_parent / stage.name),
                            _physical_signature(selection_parent / marker.name),
                        ),
                        expected,
                    )
                else:
                    self.assertEqual(_physical_signature(replacement), expected)
                if replacement_kind == "destination":
                    self.assertEqual(os.readlink(_selected(home)), old_target)

    def test_mirror_activation_rejects_replaced_captured_entries(self) -> None:
        """Mirror activation has the same immediate identity contract as selection."""
        for replacement_kind in ("parent", "stage", "destination", "marker", "equivalent-stage"):
            with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-mirror-activation-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                self.assertEqual(_run_onboard(script, home).returncode, 0)
                old_mirror_target = os.readlink(_mirror_pointer(home))
                _commit_source_change(checkout, f"mirror-{replacement_kind}")
                source = checkout / "skills" / "codex" / "fantasydisk-release-director"
                pause = workspace / "before-mirror-commit"
                process = _start_onboard(
                    script,
                    home,
                    extra={"FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_MIRROR_COMMIT": str(pause)},
                )
                _wait_for_marker(pause, process)

                mirror_parent = _mirror_pointer(home).parent
                stage = next(mirror_parent.glob(".fantasydisk-release-director.mirror-stage.*"))
                marker = next(
                    mirror_parent.glob(
                        ".fantasydisk-release-director.residue-owner.mirror-stage.*"
                    )
                )
                external = workspace / "external-sentinel"
                external.mkdir()
                (external / "keep.txt").write_bytes(b"must not be touched\n")
                external_before = _inventory(external)

                if replacement_kind == "parent":
                    moved_parent = workspace / "original-mirror-parent"
                    mirror_parent.rename(moved_parent)
                    mirror_parent.mkdir()
                    replacement = mirror_parent / stage.name
                    replacement.symlink_to(external, target_is_directory=True)
                    replacement_marker = mirror_parent / marker.name
                    replacement_marker.write_bytes(b"replacement marker\n")
                    expected = (_physical_signature(replacement), _physical_signature(replacement_marker))
                elif replacement_kind == "destination":
                    replacement = _mirror_pointer(home)
                    replacement.unlink()
                    replacement.symlink_to(old_mirror_target, target_is_directory=True)
                    expected = _physical_signature(replacement)
                elif replacement_kind == "marker":
                    replacement = marker
                    marker.unlink()
                    marker.write_bytes(b"replacement marker\n")
                    expected = _physical_signature(replacement)
                else:
                    replacement = stage
                    original = _physical_signature(stage)
                    raw_target = os.readlink(stage)
                    stage.unlink()
                    stage.symlink_to(
                        raw_target if replacement_kind == "equivalent-stage" else external,
                        target_is_directory=True,
                    )
                    expected = _physical_signature(replacement)
                    if replacement_kind == "equivalent-stage":
                        self.assertEqual(os.readlink(replacement), raw_target)
                        self.assertNotEqual(expected, original)

                pause.unlink()
                output = process.communicate(timeout=10)[0]

                self.assertNotEqual(process.returncode, 0, output)
                self.assertIn("SELECTION_COMMIT", output)
                self.assertNotIn("MIRROR_POINTER", output)
                self.assertNotIn("linked ", output)
                self.assertEqual(_inventory(external), external_before)
                if replacement_kind == "parent":
                    # The actor moved the mirror parent itself, so the prior
                    # selected path may be dangling.  It must not be rebound
                    # through the replacement parent or external sentinel.
                    self.assertEqual(
                        (
                            _physical_signature(mirror_parent / stage.name),
                            _physical_signature(mirror_parent / marker.name),
                        ),
                        expected,
                    )
                else:
                    # Selection committed before mirror activation.  A mirror
                    # identity mismatch therefore leaves the old mirror in
                    # place and a verified new selection; it must not claim
                    # that the two pointers are synchronized.
                    self.assertTrue(_selected(home).is_symlink())
                    self.assertEqual(
                        _inventory(Path(os.path.realpath(_selected(home)))), _inventory(source)
                    )
                    self.assertEqual(_physical_signature(replacement), expected)
                    self.assertEqual(os.readlink(_mirror_pointer(home)), old_mirror_target)
                if replacement_kind == "destination":
                    self.assertEqual(os.readlink(_mirror_pointer(home)), old_mirror_target)

    def test_legacy_backup_or_marker_replacement_preserves_the_absent_destination(self) -> None:
        """A substituted legacy backup/marker fails closed without a replacement pointer."""
        for flow, replacement_kind in (
            ("selection", "backup"),
            ("selection", "marker"),
            ("mirror", "backup"),
            ("mirror", "marker"),
        ):
            with self.subTest(flow=flow, replacement=replacement_kind), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-legacy-activation-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                self.assertEqual(_run_onboard(script, home).returncode, 0)
                source = checkout / "skills" / "codex" / "fantasydisk-release-director"

                if flow == "selection":
                    _selected(home).unlink()
                    _extract_legacy_skill(_selected(home))
                    pause_variable = "FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_SELECTION_LEGACY_BACKUP"
                    residue_pattern = ".fantasydisk-release-director.legacy.*"
                    marker_pattern = ".fantasydisk-release-director.residue-owner.legacy.*"
                    parent = _selected(home).parent
                    required_success = "SELECTION_COMMIT"
                    forbidden_success = "linked "
                else:
                    mirror_pointer = _mirror_pointer(home)
                    previous_target = Path(os.path.realpath(mirror_pointer))
                    mirror_pointer.unlink()
                    shutil.copytree(previous_target, mirror_pointer)
                    _commit_source_change(checkout, "mirror-legacy-backup")
                    source = checkout / "skills" / "codex" / "fantasydisk-release-director"
                    pause_variable = "FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_MIRROR_LEGACY_BACKUP"
                    residue_pattern = ".fantasydisk-release-director.legacy-mirror.*"
                    marker_pattern = ".fantasydisk-release-director.residue-owner.legacy-mirror.*"
                    parent = mirror_pointer.parent
                    required_success = "MIRROR_POINTER"
                    forbidden_success = "linked "

                pause = workspace / f"before-{flow}-legacy-commit"
                process = _start_onboard(script, home, extra={pause_variable: str(pause)})
                _wait_for_marker(pause, process)
                residue = next(parent.glob(residue_pattern))
                marker = next(parent.glob(marker_pattern))
                external = workspace / "external-sentinel"
                external.mkdir()
                (external / "keep.txt").write_bytes(b"must not be touched\n")
                external_before = _inventory(external)

                if replacement_kind == "backup":
                    replacement = residue
                    residue.rename(workspace / "original-legacy-backup")
                    replacement.symlink_to(external, target_is_directory=True)
                else:
                    replacement = marker
                    marker.unlink()
                    marker.write_bytes(b"replacement marker\n")
                expected = _physical_signature(replacement)

                pause.unlink()
                output = process.communicate(timeout=10)[0]

                self.assertNotEqual(process.returncode, 0, output)
                self.assertNotIn(required_success, output)
                self.assertNotIn(forbidden_success, output)
                self.assertEqual(_physical_signature(replacement), expected)
                self.assertEqual(_inventory(external), external_before)
                if flow == "selection":
                    # The known legacy directory was moved aside before the
                    # attacker changed its backup/marker.  Do not activate a
                    # new selected pointer or restore through that replacement.
                    self.assertFalse(os.path.lexists(_selected(home)))
                else:
                    # Selection was already independently committed; mirror
                    # activation must leave its missing destination absent.
                    self.assertFalse(os.path.lexists(_mirror_pointer(home)))
                    self.assertTrue(_selected(home).is_symlink())
                    self.assertEqual(
                        _inventory(Path(os.path.realpath(_selected(home)))), _inventory(source)
                    )

    def _assert_signal_recovery_contract(self, interrupt: signal.Signals) -> None:
        for phase, expected_new in (("before", False), ("after", True)):
            with self.subTest(phase=phase, interrupt=interrupt.name), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-signal-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                self.assertEqual(_run_onboard(script, home).returncode, 0)
                old_snapshot = _inventory(Path(os.path.realpath(_selected(home))))
                _commit_source_change(checkout, f"signal-{phase}-{interrupt.name}")
                source = checkout / "skills" / "codex" / "fantasydisk-release-director"
                new_snapshot = _inventory(source)
                marker = workspace / f"{phase}-selection-commit"
                variable = (
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT"
                    if phase == "before"
                    else "FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_SELECTION_COMMIT"
                )
                process = _start_onboard(script, home, extra={variable: str(marker)})
                _wait_for_marker(marker, process)
                os.killpg(process.pid, interrupt)
                output = process.communicate(timeout=10)[0]
                marker.unlink(missing_ok=True)

                self.assertNotEqual(process.returncode, 0, output)
                expected = new_snapshot if expected_new else old_snapshot
                self.assertEqual(
                    _inventory(Path(os.path.realpath(_selected(home)))), expected, output
                )
                selection_parent = _selected(home).parent
                persistent = sorted(
                    [
                        *selection_parent.glob(".fantasydisk-release-director.selection.*"),
                        *selection_parent.glob(
                            ".fantasydisk-release-director.residue-owner.selection.*"
                        ),
                    ]
                )
                persistent_before_retry = {
                    path: _metadata_signature(path) for path in persistent
                }
                retry = _run_onboard(script, home)
                if interrupt == signal.SIGKILL:
                    self.assertTrue(persistent_before_retry)
                    self.assertNotEqual(retry.returncode, 0, retry.stdout)
                    self.assertIn("pre-existing", retry.stdout)
                    self.assertEqual(
                        {path: _metadata_signature(path) for path in persistent_before_retry},
                        persistent_before_retry,
                    )
                    self.assertEqual(
                        _inventory(Path(os.path.realpath(_selected(home)))), expected
                    )
                else:
                    self.assertEqual(retry.returncode, 0, retry.stdout)
                    self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), new_snapshot)
                    self.assertEqual(persistent_before_retry, {})
                    self.assertEqual(
                        list(_versions(home).glob(".fantasydisk-release-director.staging.*")), []
                    )

    def test_sigterm_cleans_current_run_residue(self) -> None:
        self._assert_signal_recovery_contract(signal.SIGTERM)

    def test_sigkill_preserves_residue_and_blocks_next_run(self) -> None:
        self._assert_signal_recovery_contract(signal.SIGKILL)

    def test_current_run_cleanup_preserves_replaced_parent_residue_and_marker(self) -> None:
        """Descriptor-relative cleanup must not touch a replacement after its pause hook."""
        for replacement_kind in ("parent", "residue", "marker"):
            with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-runtime-replacement-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                self.assertEqual(_run_onboard(script, home).returncode, 0)
                _commit_source_change(checkout, f"runtime-{replacement_kind}-replacement")
                cleanup_pause = workspace / "before-runtime-cleanup"
                process = _start_onboard(
                    script,
                    home,
                    extra={
                        "FANTASYDISK_ONBOARD_TEST_FAIL_BEFORE_SELECTION_COMMIT": "1",
                        "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_RUNTIME_CLEANUP": str(
                            cleanup_pause
                        ),
                    },
                )
                _wait_for_marker(cleanup_pause, process)

                selection_parent = _selected(home).parent
                residue = next(
                    selection_parent.glob(".fantasydisk-release-director.selection.*")
                )
                marker = next(
                    selection_parent.glob(
                        ".fantasydisk-release-director.residue-owner.selection.*"
                    )
                )
                external = workspace / "external-sentinel"
                external.mkdir()
                (external / "keep.txt").write_bytes(b"must not be touched\n")

                if replacement_kind == "parent":
                    moved_parent = workspace / "original-selection-parent"
                    selection_parent.rename(moved_parent)
                    selection_parent.mkdir(parents=True)
                    replacement = selection_parent / residue.name
                    replacement.symlink_to(external, target_is_directory=True)
                    replacement_marker = selection_parent / marker.name
                    replacement_marker.write_bytes(b"replacement marker\n")
                    expected_replacement = (
                        _lstat_signature(replacement),
                        _lstat_signature(replacement_marker),
                    )
                elif replacement_kind == "residue":
                    original_residue = workspace / "original-residue"
                    residue.rename(original_residue)
                    residue.symlink_to(external, target_is_directory=True)
                    expected_replacement = (_lstat_signature(residue), _lstat_signature(marker))
                else:
                    original_marker = workspace / "original-marker"
                    marker.rename(original_marker)
                    marker.write_bytes(b"replacement marker\n")
                    expected_replacement = (_lstat_signature(residue), _lstat_signature(marker))
                external_before = _inventory(external)

                cleanup_pause.unlink()
                output = process.communicate(timeout=10)[0]

                self.assertNotEqual(process.returncode, 0, output)
                self.assertIn("current-run", output)
                if replacement_kind == "parent":
                    self.assertEqual(
                        (
                            _lstat_signature(selection_parent / residue.name),
                            _lstat_signature(selection_parent / marker.name),
                        ),
                        expected_replacement,
                    )
                else:
                    self.assertEqual(
                        (_lstat_signature(residue), _lstat_signature(marker)), expected_replacement
                    )
                self.assertEqual(_inventory(external), external_before)

    def test_prepublication_contention_fails_closed_without_managed_mutation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-lock-prepub-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            first_checkout = _make_disposable_source_checkout(workspace / "first-checkout")
            second_checkout = _make_disposable_source_checkout(workspace / "second-checkout")
            first_script = first_checkout / "scripts" / "onboard.sh"
            second_script = second_checkout / "scripts" / "onboard.sh"
            self.assertEqual(_run_onboard(first_script, home).returncode, 0)
            _commit_source_change(first_checkout, "first-before-lock-publication")
            _commit_source_change(second_checkout, "second-before-lock-publication")

            lock_publication = workspace / "before-lock-publication"
            selection_hook = workspace / "second-selection-hook"
            first = _start_onboard(
                first_script,
                home,
                extra={
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_LOCK_PUBLICATION": str(
                        lock_publication
                    )
                },
            )
            _wait_for_marker(lock_publication, first)
            self.assertFalse(_lock(home).exists() or _lock(home).is_symlink())
            before_loser = _managed_lock_state(home)

            second = _run_onboard(
                second_script,
                home,
                extra={
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(
                        selection_hook
                    )
                },
            )
            self.assertNotEqual(second.returncode, 0, second.stdout)
            self.assertIn("lock", second.stdout.lower())
            self.assertFalse(selection_hook.exists())
            self.assertEqual(_managed_lock_state(home), before_loser)

            lock_publication.unlink()
            first_output = first.communicate(timeout=10)[0]
            self.assertEqual(first.returncode, 0, first_output)
            self.assertFalse(_lock(home).exists() or _lock(home).is_symlink())
            self.assertFalse(list(_versions(home).parent.glob(".fantasydisk-release-director.lock-owner.*")))

    def test_postpublication_contention_rejects_loser_before_selection_hook(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-lock-postpub-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            first_checkout = _make_disposable_source_checkout(workspace / "first-checkout")
            second_checkout = _make_disposable_source_checkout(workspace / "second-checkout")
            first_script = first_checkout / "scripts" / "onboard.sh"
            second_script = second_checkout / "scripts" / "onboard.sh"
            self.assertEqual(_run_onboard(first_script, home).returncode, 0)
            _commit_source_change(first_checkout, "first-after-lock-publication")
            _commit_source_change(second_checkout, "second-after-lock-publication")

            lock_publication = workspace / "after-lock-publication"
            selection_hook = workspace / "second-selection-hook"
            first = _start_onboard(
                first_script,
                home,
                extra={
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_LOCK_PUBLICATION": str(
                        lock_publication
                    )
                },
            )
            _wait_for_marker(lock_publication, first)
            self.assertTrue(_lock(home).is_symlink())
            before_loser = _managed_lock_state(home)

            second = _run_onboard(
                second_script,
                home,
                extra={
                    "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(
                        selection_hook
                    )
                },
            )
            self.assertNotEqual(second.returncode, 0, second.stdout)
            self.assertIn("lock", second.stdout.lower())
            self.assertFalse(selection_hook.exists())
            self.assertEqual(_managed_lock_state(home), before_loser)

            lock_publication.unlink()
            first_output = first.communicate(timeout=10)[0]
            self.assertEqual(first.returncode, 0, first_output)
            self.assertFalse(_lock(home).exists() or _lock(home).is_symlink())
            self.assertFalse(_lock_reclaim(home).exists() or _lock_reclaim(home).is_symlink())

    def test_sigkill_after_lock_publication_reclaims_dead_owner(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-lock-sigkill-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = _make_disposable_source_checkout(workspace / "checkout")
            script = checkout / "scripts" / "onboard.sh"
            self.assertEqual(_run_onboard(script, home).returncode, 0)
            _commit_source_change(checkout, "sigkill-after-lock-publication")
            source = checkout / "skills" / "codex" / "fantasydisk-release-director"
            marker = workspace / "after-lock-publication"
            process = _start_onboard(
                script,
                home,
                extra={"FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_LOCK_PUBLICATION": str(marker)},
            )
            _wait_for_marker(marker, process)
            self.assertTrue(_lock(home).is_symlink())

            os.killpg(process.pid, signal.SIGKILL)
            killed_output = process.communicate(timeout=10)[0]
            marker.unlink(missing_ok=True)
            self.assertEqual(process.returncode, -signal.SIGKILL, killed_output)

            retry = _run_onboard(script, home)
            self.assertEqual(retry.returncode, 0, retry.stdout)
            _assert_durable_selected_tree(home, source)
            self.assertFalse(_lock(home).exists() or _lock(home).is_symlink())
            self.assertFalse(_lock_reclaim(home).exists() or _lock_reclaim(home).is_symlink())
            self.assertFalse(list(_versions(home).parent.glob(".fantasydisk-release-director.lock-owner.*")))

    def _assert_lock_liveness_cases(
        self, cases: tuple[tuple[str, str, str, bool], ...]
    ) -> None:
        for name, outcome, lock_kind, reclaims in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-lock-probe-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                source = checkout / "skills" / "codex" / "fantasydisk-release-director"
                initial = _run_onboard(script, home)
                self.assertEqual(initial.returncode, 0, initial.stdout)

                owner = _install_complete_lock_owner(home)
                if lock_kind == "canonical":
                    _lock(home).symlink_to(owner, target_is_directory=True)
                elif lock_kind == "marker":
                    _lock_reclaim(home).symlink_to(owner, target_is_directory=True)
                before = _managed_lock_state(home)
                selection_hook = workspace / "selection-hook"
                shim = _make_liveness_python_shim(workspace / "python-shim")

                result = _run_onboard(
                    script,
                    home,
                    path_prefix=shim,
                    extra={
                        "FANTASYDISK_ONBOARD_TEST_LIVENESS": outcome,
                        "FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(
                            selection_hook
                        ),
                    },
                )

                if reclaims:
                    self.assertEqual(result.returncode, 0, result.stdout)
                    self.assertFalse(_lock(home).exists() or _lock(home).is_symlink())
                    self.assertFalse(
                        _lock_reclaim(home).exists() or _lock_reclaim(home).is_symlink()
                    )
                    self.assertFalse(owner.exists())
                    self.assertFalse(
                        list(_versions(home).parent.glob(".fantasydisk-release-director.lock-owner.*"))
                    )
                    _assert_durable_selected_tree(home, source)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("lock", result.stdout.lower())
                    self.assertFalse(selection_hook.exists())
                    self.assertEqual(_managed_lock_state(home), before)

    def test_lock_liveness_probe_distinguishes_live_from_esrch(self) -> None:
        self._assert_lock_liveness_cases(
            (
                ("canonical-live", "live", "canonical", False),
                ("canonical-dead", "dead", "canonical", True),
            )
        )

    def test_lock_liveness_probe_preserves_canonical_unknown_results(self) -> None:
        self._assert_lock_liveness_cases(
            (
                ("canonical-permission-denied", "unknown", "canonical", False),
                ("canonical-oserror", "error", "canonical", False),
            )
        )

    def test_lock_liveness_probe_preserves_invalid_and_probe_failure(self) -> None:
        self._assert_lock_liveness_cases(
            (
                ("canonical-invalid-pid", "invalid", "canonical", False),
                ("canonical-probe-failure", "failure", "canonical", False),
            )
        )

    def test_lock_liveness_probe_preserves_reclaimer_and_orphan_unknown_state(self) -> None:
        self._assert_lock_liveness_cases(
            (
                ("reclaim-marker-permission-denied", "unknown", "marker", False),
                ("orphan-permission-denied", "unknown", "orphan", False),
            )
        )

    def test_malformed_unreadable_incomplete_and_foreign_locks_fail_closed(self) -> None:
        cases = ("incomplete", "malformed", "unreadable", "foreign")
        for kind in cases:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory(
                prefix="fantasydisk-onboard-lock-state-"
            ) as raw:
                workspace = Path(raw)
                home = workspace / "home"
                checkout = _make_disposable_source_checkout(workspace / "checkout")
                script = checkout / "scripts" / "onboard.sh"
                parent = _versions(home).parent
                parent.mkdir(parents=True)
                _versions(home).mkdir()
                owner = (
                    workspace / "foreign-owner"
                    if kind == "foreign"
                    else parent / ".fantasydisk-release-director.lock-owner.fixture"
                )
                owner.mkdir()
                pid = owner / "pid"
                if kind == "malformed":
                    pid.write_text("not-a-pid\n", encoding="utf-8")
                elif kind == "unreadable":
                    pid.write_text(f"{os.getpid()}\n", encoding="utf-8")
                    pid.chmod(0)
                elif kind == "foreign":
                    pid.write_text(f"{os.getpid()}\n", encoding="utf-8")
                elif kind == "incomplete":
                    pass
                if kind == "incomplete":
                    _lock(home).mkdir()
                else:
                    _lock(home).symlink_to(owner, target_is_directory=True)

                if kind == "unreadable":
                    before = (
                        _metadata_signature(_lock(home)),
                        _metadata_signature(owner),
                        _metadata_signature(pid),
                    )
                else:
                    before = _managed_lock_state(home)
                try:
                    result = _run_onboard(script, home)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("lock", result.stdout.lower())
                    if kind == "unreadable":
                        self.assertEqual(
                            (
                                _metadata_signature(_lock(home)),
                                _metadata_signature(owner),
                                _metadata_signature(pid),
                            ),
                            before,
                        )
                    else:
                        self.assertEqual(_managed_lock_state(home), before)
                finally:
                    if pid.exists():
                        pid.chmod(0o600)

    def test_concurrent_updater_fails_closed_without_touching_active_selection(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-concurrent-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            first_checkout = _make_disposable_source_checkout(workspace / "first-checkout")
            second_checkout = _make_disposable_source_checkout(workspace / "second-checkout")
            first_script = first_checkout / "scripts" / "onboard.sh"
            second_script = second_checkout / "scripts" / "onboard.sh"
            self.assertEqual(_run_onboard(first_script, home).returncode, 0)
            _commit_source_change(first_checkout, "first-concurrent-update")
            _commit_source_change(second_checkout, "second-concurrent-update")
            first_source = first_checkout / "skills" / "codex" / "fantasydisk-release-director"
            first_snapshot = _inventory(first_source)
            marker = workspace / "first-before-selection-commit"
            first = _start_onboard(
                first_script,
                home,
                extra={"FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT": str(marker)},
            )
            _wait_for_marker(marker, first)
            second = _run_onboard(second_script, home)
            self.assertNotEqual(second.returncode, 0, second.stdout)
            self.assertIn("lock", second.stdout.lower())
            self.assertTrue(_selected(home).is_symlink())

            marker.unlink()
            first_output = first.communicate(timeout=10)[0]
            self.assertEqual(first.returncode, 0, first_output)
            self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), first_snapshot)
            self.assertEqual(_inventory(_mirror(home)), first_snapshot)

    def test_durable_mirror_survives_disposable_source_checkout_removal(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fantasydisk-onboard-checkout-loss-") as raw:
            workspace = Path(raw)
            home = workspace / "home"
            checkout = _make_disposable_source_checkout(workspace / "disposable-checkout")
            source = checkout / "skills" / "codex" / "fantasydisk-release-director"
            result = _run_onboard(checkout / "scripts" / "onboard.sh", home)

            self.assertEqual(result.returncode, 0, result.stdout)
            _assert_durable_selected_tree(home, source)
            retired_checkout = workspace / "removed-checkout"
            checkout.rename(retired_checkout)
            shutil.rmtree(retired_checkout)

            target = _selected(home)
            self.assertTrue(target.is_symlink())
            self.assertTrue((target / "SKILL.md").is_file())
            self.assertEqual(set(path.relative_to(_mirror(home)).as_posix() for path in _mirror(home).rglob("*") if path.is_file()), EXPECTED_RELEASE_SKILL_FILES)
            fresh_process = subprocess.run(
                [
                    "python3",
                    "-c",
                    "from pathlib import Path; import os; "
                    "skill = Path(os.environ['HOME']) / '.codex/skills/fantasydisk-release-director'; "
                    "assert (skill / 'SKILL.md').is_file(); "
                    "assert len([path for path in skill.rglob('*') if path.is_file()]) == 7",
                ],
                env={**os.environ, "HOME": str(home)},
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                encoding="utf-8",
            )
            self.assertEqual(fresh_process.returncode, 0, fresh_process.stderr)


if __name__ == "__main__":
    unittest.main()
