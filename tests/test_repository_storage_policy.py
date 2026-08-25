import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "repository_storage_policy.py"
MIB = 1024 * 1024


class RepositoryStoragePolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="repository-storage-policy-")
        self.repo = Path(self.temporary.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Storage Policy Test")
        self.git("config", "user.email", "storage-policy@example.invalid")
        shutil.copy(ROOT / ".gitattributes", self.repo / ".gitattributes")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def git(self, *arguments: str) -> str:
        result = subprocess.run(
            ["git", *arguments],
            cwd=self.repo,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def write(self, relative: str, content: bytes) -> None:
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    def commit(self, message: str) -> str:
        self.git("add", "--all")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def run_policy(self, changed_ref: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(self.repo),
                "--changed-ref",
                changed_ref,
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def base_commit(self) -> str:
        return self.commit("base")

    def assert_policy_passes(self, changed_ref: str) -> None:
        result = self.run_policy(changed_ref)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_policy_fails(self, changed_ref: str, *messages: str) -> None:
        result = self.run_policy(changed_ref)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 1, output)
        for message in messages:
            self.assertIn(message, output)

    def test_unchanged_legacy_binary_is_grandfathered(self) -> None:
        self.write("docs/design/references/old-pack/source.png", b"x" * MIB)
        base = self.base_commit()
        self.write("notes.txt", b"candidate\n")
        self.commit("unrelated candidate")

        self.assert_policy_passes(base)

    def test_changed_legacy_binary_at_limit_is_rejected(self) -> None:
        relative = "docs/design/mockups/old-pack/screen.png"
        self.write(relative, b"old")
        base = self.base_commit()
        self.write(relative, b"x" * MIB)
        self.commit("grow legacy binary")

        self.assert_policy_fails(base, relative, "1 MiB")

    def test_aggregate_legacy_raw_binary_size_above_limit_is_rejected(self) -> None:
        base = self.base_commit()
        for index in range(6):
            self.write(
                f"docs/design/previews/pack/preview-{index}.png",
                bytes([index]) * (900 * 1024),
            )
        self.commit("add oversized raw preview pack")

        self.assert_policy_fails(
            base,
            "docs/design/previews/pack/preview-0.png",
            "aggregate",
            "5 MiB",
        )

    def test_valid_future_lfs_pointer_is_accepted(self) -> None:
        base = self.base_commit()
        pointer = (
            "version https://git-lfs.github.com/spec/v1\n"
            f"oid sha256:{'a' * 64}\n"
            "size 7340032\n"
        ).encode()
        self.write("docs/design/reference-assets-lfs/FAN-3470/source.png", pointer)
        self.commit("add future LFS source")

        self.assert_policy_passes(base)

    def test_future_binary_rejects_malformed_lfs_pointer(self) -> None:
        base = self.base_commit()
        pointer = (
            "version https://git-lfs.github.com/spec/v1\n"
            "oid sha256:not-a-sha256\n"
            "size seven-million\n"
        ).encode()
        relative = "docs/design/reference-assets-lfs/FAN-3470/source.png"
        self.write(relative, pointer)
        self.commit("add malformed future source")

        self.assert_policy_fails(base, relative, "Git LFS pointer")

    def test_future_pointer_requires_lfs_attributes(self) -> None:
        base = self.base_commit()
        (self.repo / ".gitattributes").write_text("* text=auto eol=lf\n", encoding="utf-8")
        pointer = (
            "version https://git-lfs.github.com/spec/v1\n"
            f"oid sha256:{'b' * 64}\n"
            "size 1048576\n"
        ).encode()
        relative = "docs/design/reference-assets-lfs/FAN-3470/source.png"
        self.write(relative, pointer)
        self.commit("remove LFS attributes")

        self.assert_policy_fails(base, relative, "filter=lfs", "diff=lfs", "merge=lfs", "-text")

    def test_runtime_asset_remains_an_ordinary_git_blob(self) -> None:
        base = self.base_commit()
        self.write("assets/sprites/future/runtime.png", b"runtime" * 300_000)
        self.commit("add runtime asset")

        self.assert_policy_passes(base)


if __name__ == "__main__":
    unittest.main()
