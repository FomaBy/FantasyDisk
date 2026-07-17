from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "quality.yml"
CI_REQUIREMENTS = ROOT / "requirements-ci.txt"


class QualityWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = WORKFLOW.read_text(encoding="utf-8")

    def test_all_candidate_event_types_are_covered(self) -> None:
        self.assertIn("push:", self.source)
        self.assertIn("pull_request:", self.source)
        self.assertIn("merge_group:", self.source)
        self.assertIn("github.event.merge_group.base_sha", self.source)

    def test_checkout_is_asserted_to_be_exact_github_sha(self) -> None:
        self.assertIn('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', self.source)
        self.assertIn("quality_gate_candidate_sha.txt", self.source)

    def test_machine_readable_evidence_is_hashed_and_uploaded(self) -> None:
        self.assertIn("build/quality_gate_report.json", self.source)
        self.assertIn("build/quality_gate_report.sha256", self.source)
        self.assertIn(
            "sha256sum quality_gate_report.json > quality_gate_report.sha256",
            self.source,
        )
        self.assertIn("sha256sum -c quality_gate_report.sha256", self.source)
        self.assertNotIn(
            "sha256sum build/quality_gate_report.json >", self.source
        )
        self.assertIn("actions/upload-artifact@v7", self.source)
        self.assertIn("quality-${{ github.event_name }}-${{ github.sha }}", self.source)
        self.assertIn("if-no-files-found: error", self.source)

    def test_job_has_bounded_runtime(self) -> None:
        self.assertIn("timeout-minutes: 30", self.source)

    def test_ci_dependencies_are_installed_before_quality_gate(self) -> None:
        self.assertEqual(CI_REQUIREMENTS.read_text(encoding="utf-8").splitlines(), [
            "# Python packages required by the repository's deterministic CI/static gates.",
            "Pillow==11.3.0",
        ])
        install = "python -m pip install --requirement requirements-ci.txt"
        self.assertIn(install, self.source)
        self.assertLess(self.source.index(install), self.source.index("tools/quality_gate.py"))


if __name__ == "__main__":
    unittest.main()
