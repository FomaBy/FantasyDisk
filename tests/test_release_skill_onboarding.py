"""Regression tests for persistent release-skill onboarding provenance."""

from __future__ import annotations

import hashlib
import io
import os
import shutil
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
MIRROR_RELATIVE_PATH = Path(
    ".codex", "skill-mirrors", "FantasyDisk", "fantasydisk-release-director"
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


def _run_onboard(
    script: Path, home: Path, *, path_prefix: Path | None = None
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    fake_bin = _fake_multica(home)
    if path_prefix is not None:
        path = f"{path_prefix}{os.pathsep}{fake_bin}{os.pathsep}{environment['PATH']}"
    else:
        path = f"{fake_bin}{os.pathsep}{environment['PATH']}"
    environment.update(
        {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / "config"),
            "PATH": path,
        }
    )
    return subprocess.run(
        ["bash", str(script)],
        cwd=script.parents[1],
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def _selected(home: Path) -> Path:
    return home / SELECTED_RELATIVE_PATH


def _mirror(home: Path) -> Path:
    return home / MIRROR_RELATIVE_PATH


def _assert_durable_selected_tree(home: Path, expected_source: Path) -> None:
    target = _selected(home)
    mirror = _mirror(home)
    assert target.is_symlink()
    assert os.path.realpath(os.readlink(target)) == os.path.realpath(mirror)
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
            _assert_durable_selected_tree(home, SOURCE_SKILL)

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
                list(_mirror(home).parent.glob(".fantasydisk-release-director.staging.*")), []
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
            self.assertIn("staged mirror", failed.stdout)
            self.assertEqual(_inventory(_mirror(home)), mirror_before)
            self.assertEqual(os.readlink(_selected(home)), selected_before)
            self.assertTrue((_selected(home) / "SKILL.md").is_file())
            self.assertEqual(
                list(_mirror(home).parent.glob(".fantasydisk-release-director.staging.*")), []
            )

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
