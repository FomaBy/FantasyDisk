"""Regression tests for persistent release-skill onboarding provenance."""

from __future__ import annotations

import hashlib
import io
import os
import subprocess
import tarfile
import tempfile
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
    fake_bin.mkdir()
    multica = fake_bin / "multica"
    multica.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
    multica.chmod(0o755)
    return fake_bin


def _run_onboard(script: Path, home: Path) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment.update(
        {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / "config"),
            "PATH": f"{_fake_multica(home)}{os.pathsep}{environment['PATH']}",
        }
    )
    return subprocess.run(
        ["bash", str(script)],
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


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
            target = home / ".codex" / "skills" / "fantasydisk-release-director"
            target.mkdir(parents=True)
            _extract_legacy_skill(target)

            result = _run_onboard(ONBOARD, home)

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("MIGRATE", result.stdout)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), SOURCE_SKILL.resolve())
            self.assertEqual(_inventory(target.resolve()), _inventory(SOURCE_SKILL))
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
            target = home / ".codex" / "skills" / "fantasydisk-release-director"
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), SOURCE_SKILL.resolve())
            self.assertEqual(_inventory(target.resolve()), _inventory(SOURCE_SKILL))
            self.assertTrue(EXPECTED_RELEASE_SKILL_FILES.issubset(_inventory(target.resolve())))


if __name__ == "__main__":
    unittest.main()
