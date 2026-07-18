"""Regression tests for persistent release-skill onboarding provenance."""

from __future__ import annotations

import hashlib
import io
import os
import signal
import shutil
import socket
import stat
import subprocess
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


def _extract_legacy_skill(destination: Path) -> None:
    """Materialize the exact repo-owned pre-fix tree from git history."""
    archive = subprocess.run(
        ["git", "archive", "--format=tar", LEGACY_SKILL_COMMIT, LEGACY_SKILL_PATH],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )
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
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(script)],
        cwd=script.parents[1],
        env=_onboard_environment(script, home, path_prefix=path_prefix, extra=extra),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
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
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )


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


class ReleaseSkillOnboardingTest(unittest.TestCase):
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

    def test_sigterm_and_sigkill_reconcile_old_or_new_selection(self) -> None:
        for phase, interrupt, expected_new in (
            ("before", signal.SIGTERM, False),
            ("before", signal.SIGKILL, False),
            ("after", signal.SIGTERM, True),
            ("after", signal.SIGKILL, True),
        ):
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
                retry = _run_onboard(script, home)
                self.assertEqual(retry.returncode, 0, retry.stdout)
                self.assertEqual(_inventory(Path(os.path.realpath(_selected(home)))), new_snapshot)
                self.assertEqual(
                    list(_versions(home).glob(".fantasydisk-release-director.staging.*")), []
                )

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
                text=True,
            )
            self.assertEqual(fresh_process.returncode, 0, fresh_process.stderr)


if __name__ == "__main__":
    unittest.main()
