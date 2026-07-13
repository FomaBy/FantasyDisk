from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "quality.yml"


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
        self.assertIn("sha256sum build/quality_gate_report.json", self.source)
        self.assertIn("actions/upload-artifact@v4", self.source)
        self.assertIn("quality-${{ github.event_name }}-${{ github.sha }}", self.source)
        self.assertIn("if-no-files-found: error", self.source)


if __name__ == "__main__":
    unittest.main()
