import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "repository_storage_policy.py"
GENERATOR = ROOT / "skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py"
POINTER_LIMIT = 256


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


POLICY = load_module(TOOL, "repository_storage_policy_under_test")
GENERATOR_MODULE = load_module(GENERATOR, "asset_generator_under_test")


def canonical_pointer(oid: str = "a" * 64, size: str = "7340032") -> bytes:
    return (
        "version https://git-lfs.github.com/spec/v1\n"
        f"oid sha256:{oid}\n"
        f"size {size}\n"
    ).encode()


class LfsPointerTests(unittest.TestCase):
    def test_accepts_only_canonical_pointer(self) -> None:
        self.assertTrue(POLICY.is_lfs_pointer(canonical_pointer()))

    def test_rejects_appended_payload(self) -> None:
        self.assertFalse(POLICY.is_lfs_pointer(canonical_pointer() + b"payload"))

    def test_rejects_reordered_fields(self) -> None:
        self.assertFalse(
            POLICY.is_lfs_pointer(
                b"version https://git-lfs.github.com/spec/v1\n"
                b"size 7340032\n"
                + f"oid sha256:{'a' * 64}\n".encode()
            )
        )

    def test_rejects_duplicate_fields(self) -> None:
        self.assertFalse(POLICY.is_lfs_pointer(canonical_pointer() + b"size 7340032\n"))

    def test_rejects_uppercase_oid(self) -> None:
        self.assertFalse(POLICY.is_lfs_pointer(canonical_pointer(oid="A" * 64)))

    def test_rejects_oversized_pointer_blob(self) -> None:
        self.assertFalse(POLICY.is_lfs_pointer(canonical_pointer() + b"x" * POINTER_LIMIT))


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

    def test_small_added_design_binary_is_rejected(self) -> None:
        base = self.base_commit()
        relative = "docs/design/previews/FAN-3470/small.png"
        self.write(relative, b"small")
        self.commit("add small legacy binary")

        self.assert_policy_fails(base, relative, "reference-assets-lfs")

    def test_small_modified_design_binary_is_rejected(self) -> None:
        relative = "docs/design/mockups/old-pack/screen.png"
        self.write(relative, b"old")
        base = self.base_commit()
        self.write(relative, b"new")
        self.commit("modify small legacy binary")

        self.assert_policy_fails(base, relative, "reference-assets-lfs")

    def test_changed_build_qa_binary_is_rejected(self) -> None:
        relative = "build/qa/old-pack/screen.png"
        self.write(relative, b"old")
        base = self.base_commit()
        self.write(relative, b"new")
        self.commit("modify build QA binary")

        self.assert_policy_fails(base, relative, "reference-assets-lfs")

    def test_rename_from_future_root_to_legacy_is_rejected(self) -> None:
        source = "docs/design/reference-assets-lfs/FAN-3470/source.png"
        destination = "docs/design/references/FAN-3470/source.png"
        self.write(source, canonical_pointer())
        base = self.base_commit()
        (self.repo / destination).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / source).rename(self.repo / destination)
        self.commit("rename future source to legacy")

        self.assert_policy_fails(base, destination, "reference-assets-lfs")

    def test_copy_to_legacy_is_rejected_and_preserves_copy_paths(self) -> None:
        source = "docs/design/reference-assets-lfs/FAN-3470/source.png"
        destination = "docs/design/backups/FAN-3470/source-copy.png"
        self.write(source, canonical_pointer())
        base = self.base_commit()
        self.write(destination, canonical_pointer())
        self.commit("copy future source to legacy")

        entries = POLICY.changed_entries(self.repo, base)
        copy = next(entry for entry in entries if entry.path == destination)
        self.assertEqual(copy.status, "C")
        self.assertEqual(copy.old_path, source)
        self.assert_policy_fails(base, destination, "reference-assets-lfs")

    def test_known_office_and_archive_formats_are_rejected_in_legacy(self) -> None:
        base = self.base_commit()
        relatives = [
            f"docs/design/data/FAN-3470/source{suffix}"
            for suffix in (".docx", ".xlsx", ".pdf", ".gz")
        ]
        for relative in relatives:
            self.write(relative, b"PK\x03\x04binary")
        self.commit("add office and archive sources")

        self.assert_policy_fails(base, *relatives, "reference-assets-lfs")

    def test_known_office_and_archive_formats_have_future_lfs_routes(self) -> None:
        base = self.base_commit()
        for suffix in (".docx", ".xlsx", ".pdf", ".gz"):
            self.write(
                f"docs/design/reference-assets-lfs/FAN-3470/source{suffix}",
                canonical_pointer(),
            )
        self.commit("add future office and archive pointers")

        self.assert_policy_passes(base)

    def test_unknown_binary_format_is_rejected(self) -> None:
        base = self.base_commit()
        relative = "docs/design/data/FAN-3470/source.blend"
        self.write(relative, b"BLENDER-v1\x00\xff")
        self.commit("add unknown binary source")

        self.assert_policy_fails(base, relative, "reference-assets-lfs")

    def test_text_manifest_and_document_changes_are_allowed(self) -> None:
        base = self.base_commit()
        self.write("docs/design/data/FAN-3470/manifest.json", b'{"source": "pack"}\n')
        self.write("docs/design/FAN-3470-notes.md", b"# Notes\n")
        self.commit("add text design records")

        self.assert_policy_passes(base)

    def test_unchanged_legacy_binary_is_grandfathered(self) -> None:
        self.write("docs/design/references/old-pack/source.png", b"old binary")
        base = self.base_commit()
        self.write("notes.txt", b"candidate\n")
        self.commit("unrelated candidate")

        self.assert_policy_passes(base)

    def test_legacy_binary_deletion_is_allowed(self) -> None:
        relative = "docs/design/references/old-pack/source.png"
        self.write(relative, b"old binary")
        base = self.base_commit()
        (self.repo / relative).unlink()
        self.commit("delete legacy binary")

        self.assert_policy_passes(base)

    def test_valid_future_lfs_pointer_is_accepted(self) -> None:
        base = self.base_commit()
        self.write("docs/design/reference-assets-lfs/FAN-3470/source.png", canonical_pointer())
        self.commit("add future LFS source")

        self.assert_policy_passes(base)

    def test_future_binary_requires_pack_nesting(self) -> None:
        base = self.base_commit()
        relative = "docs/design/reference-assets-lfs/source.png"
        self.write(relative, canonical_pointer())
        self.commit("add ungrouped future source")

        self.assert_policy_fails(base, relative, "<issue-or-pack>/<file>")

    def test_future_pointer_requires_lfs_attributes(self) -> None:
        base = self.base_commit()
        (self.repo / ".gitattributes").write_text("* text=auto eol=lf\n", encoding="utf-8")
        relative = "docs/design/reference-assets-lfs/FAN-3470/source.png"
        self.write(relative, canonical_pointer())
        self.commit("remove LFS attributes")

        self.assert_policy_fails(base, relative, "filter=lfs", "diff=lfs", "merge=lfs", "-text")

    def test_runtime_asset_remains_an_ordinary_git_blob(self) -> None:
        base = self.base_commit()
        self.write("assets/sprites/future/runtime.png", b"runtime" * 300_000)
        self.commit("add runtime asset")

        self.assert_policy_passes(base)

    def test_oversized_future_blob_is_rejected_without_blob_read(self) -> None:
        base = self.base_commit()
        relative = "docs/design/reference-assets-lfs/FAN-3470/source.png"
        self.write(relative, canonical_pointer() + b"x" * POINTER_LIMIT)
        self.commit("add oversized future blob")

        with mock.patch.object(POLICY, "head_blob", side_effect=AssertionError("blob read")):
            errors = POLICY.collect_errors(self.repo, base)

        self.assertTrue(any(relative in error and "too large" in error for error in errors))

    def test_legacy_blob_is_rejected_without_blob_read(self) -> None:
        base = self.base_commit()
        relative = "docs/design/previews/FAN-3470/source.png"
        self.write(relative, b"small")
        self.commit("add legacy blob")

        with mock.patch.object(POLICY, "head_blob", side_effect=AssertionError("blob read")):
            errors = POLICY.collect_errors(self.repo, base)

        self.assertTrue(any(relative in error for error in errors))


class ActiveProducerRoutingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="repository-storage-producer-")
        self.project = Path(self.temporary.name)
        (self.project / "project.godot").write_text("[application]\n", encoding="utf-8")
        (self.project / "docs/design/reference-assets-lfs").mkdir(parents=True)
        (self.project / "docs/tasks").mkdir(parents=True)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_generator_routes_output_and_task_to_future_pack(self) -> None:
        output = GENERATOR_MODULE.resolve_output(self.project, "FAN-3470/source")
        expected = self.project / "docs/design/reference-assets-lfs/FAN-3470/source.png"
        self.assertEqual(output, expected)

        task = GENERATOR_MODULE.write_task(
            self.project,
            output,
            "prompt",
            "1024x1024",
            "medium",
            "FAN-3470",
        )
        body = task.read_text(encoding="utf-8")
        self.assertIn("docs/design/reference-assets-lfs/FAN-3470/source.png", body)
        self.assertNotIn("docs/design/references/", body)

    def test_generator_rejects_legacy_absolute_output(self) -> None:
        legacy = self.project / "docs/design/references/FAN-3470/source.png"
        with self.assertRaises(SystemExit):
            GENERATOR_MODULE.resolve_output(self.project, str(legacy))

    def test_generator_rejects_relative_output_escape(self) -> None:
        with self.assertRaises(SystemExit):
            GENERATOR_MODULE.resolve_output(self.project, "FAN-3470/../../../outside.png")

    def test_active_producer_instructions_have_no_legacy_binary_routes(self) -> None:
        producers = (
            ROOT / "skills/codex/fantasydisk-item-icon-generator/SKILL.md",
            ROOT / "skills/codex/fantasydisk-ui-director/references/ui-change-workflow.md",
            GENERATOR,
        )
        for producer in producers:
            with self.subTest(producer=producer.relative_to(ROOT)):
                source = producer.read_text(encoding="utf-8")
                self.assertIn("docs/design/reference-assets-lfs/", source)
                for legacy in (
                    "docs/design/references/",
                    "docs/design/previews/",
                    "docs/design/mockups/",
                ):
                    self.assertNotIn(legacy, source)


if __name__ == "__main__":
    unittest.main()
