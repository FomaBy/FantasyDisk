"""Regression coverage for the registry's CI sparse-checkout inputs."""
from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/quality.yml"
REQUIRED_DOCUMENTS = (
    "docs/design/content/ui.md",
    "docs/design/content_registry.md",
    "docs/design/systems/characters_weapons.md",
)


def candidate_sparse_paths() -> list[str]:
    """Return the static-quality sparse roots from the checked-in workflow."""
    source = WORKFLOW.read_text(encoding="utf-8")
    job = source[source.index("\n  static-quality:"):]
    checkout = job[:job.index("- uses: actions/setup-python@v6")]
    marker = "          sparse-checkout: |\n"
    entries = []
    for entry in checkout[checkout.index(marker) + len(marker):].splitlines():
        if not entry.startswith("            "):
            break
        entries.append(entry.strip())
    return entries


class ContentRegistryCiCheckoutTest(unittest.TestCase):
    def test_sparse_checkout_materializes_registry_and_source_reading_documents(self) -> None:
        sparse_paths = candidate_sparse_paths()
        self.assertIn("docs/design/content", sparse_paths)
        self.assertIn("docs/design/systems", sparse_paths)

        with tempfile.TemporaryDirectory() as temp_dir:
            source = Path(temp_dir) / "source"
            checkout = Path(temp_dir) / "checkout"
            for relative in REQUIRED_DOCUMENTS:
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(relative + "\n", encoding="utf-8")
            for relative in sparse_paths:
                path = source / relative / ".ci-keep"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture\n", encoding="utf-8")

            self.run_git(source, "init", "--initial-branch=main")
            self.run_git(source, "add", ".")
            self.run_git(
                source,
                "-c", "user.name=CI fixture",
                "-c", "user.email=ci-fixture@example.invalid",
                "commit", "-m", "fixture",
            )
            self.run_git(ROOT, "clone", "--no-checkout", str(source), str(checkout))
            self.run_git(checkout, "sparse-checkout", "set", "--cone", *sparse_paths)
            self.run_git(checkout, "checkout")

            for relative in REQUIRED_DOCUMENTS:
                with self.subTest(document=relative):
                    self.assertTrue((checkout / relative).is_file())

    @staticmethod
    def run_git(cwd: Path, *args: str) -> None:
        subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
