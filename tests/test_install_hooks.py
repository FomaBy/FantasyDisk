import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "tools" / "install_hooks.sh"


class InstallHooksTest(unittest.TestCase):
    def test_installer_exists_and_is_executable(self):
        self.assertTrue(INSTALLER.is_file())
        mode = INSTALLER.stat().st_mode
        self.assertTrue(mode & stat.S_IXUSR, "tools/install_hooks.sh must be executable")

    def _init_fixture_repo(self, root: Path, *, guard_exit: int) -> Path:
        """A throwaway git repo with the real installer and a stub guard."""
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"], cwd=root, check=True
        )
        subprocess.run(["git", "config", "user.name", "Test"], cwd=root, check=True)

        (root / "tools").mkdir()
        shutil.copy(INSTALLER, root / "tools" / "install_hooks.sh")
        (root / "tools" / "install_hooks.sh").chmod(0o755)
        (root / "tools" / "quality_static_guard.py").write_text(
            f"import sys\nsys.exit({guard_exit})\n", encoding="utf-8"
        )

        subprocess.run(["git", "add", "--", "."], cwd=root, check=True)
        subprocess.run(["git", "commit", "-qm", "fixture"], cwd=root, check=True)
        return root

    def _installed_hook(self, root: Path) -> Path:
        result = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        )
        git_common_dir = result.stdout.strip()
        common_dir = Path(git_common_dir)
        if not common_dir.is_absolute():
            common_dir = root / common_dir
        return common_dir / "hooks" / "pre-push"

    def test_run_installs_executable_pre_push_hook_calling_the_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._init_fixture_repo(Path(tmp), guard_exit=0)
            subprocess.run(["bash", "tools/install_hooks.sh"], cwd=root, check=True)

            hook = self._installed_hook(root)
            self.assertTrue(hook.is_file())
            self.assertTrue(hook.stat().st_mode & stat.S_IXUSR)
            self.assertIn("quality_static_guard.py", hook.read_text(encoding="utf-8"))

    def test_hook_blocks_the_push_when_the_guard_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._init_fixture_repo(Path(tmp), guard_exit=1)
            subprocess.run(["bash", "tools/install_hooks.sh"], cwd=root, check=True)

            hook = self._installed_hook(root)
            result = subprocess.run([str(hook)], cwd=root)
            self.assertNotEqual(result.returncode, 0)

    def test_hook_allows_the_push_when_the_guard_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._init_fixture_repo(Path(tmp), guard_exit=0)
            subprocess.run(["bash", "tools/install_hooks.sh"], cwd=root, check=True)

            hook = self._installed_hook(root)
            result = subprocess.run([str(hook)], cwd=root)
            self.assertEqual(result.returncode, 0)

    def test_installer_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._init_fixture_repo(Path(tmp), guard_exit=0)
            subprocess.run(["bash", "tools/install_hooks.sh"], cwd=root, check=True)
            subprocess.run(["bash", "tools/install_hooks.sh"], cwd=root, check=True)

            hook = self._installed_hook(root)
            self.assertTrue(hook.is_file())

    def test_installer_refuses_to_overwrite_a_foreign_pre_push_hook(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._init_fixture_repo(Path(tmp), guard_exit=0)
            hook = self._installed_hook(root)
            hook.parent.mkdir(parents=True, exist_ok=True)
            foreign_hook = "#!/usr/bin/env bash\necho 'my own pre-push check'\n"
            hook.write_text(foreign_hook, encoding="utf-8")
            hook.chmod(0o755)

            result = subprocess.run(
                ["bash", "tools/install_hooks.sh"], cwd=root, capture_output=True, text=True
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(hook.read_text(encoding="utf-8"), foreign_hook)
            self.assertTrue(hook.stat().st_mode & stat.S_IXUSR)


if __name__ == "__main__":
    unittest.main()
