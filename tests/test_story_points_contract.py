from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "tools" / "validate_story_points_contract.py"


class StoryPointsContractTest(unittest.TestCase):
    def _run(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), *args],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_canonical_documents_share_the_contract(self) -> None:
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_formula_based_cue_rubric_is_rejected(self) -> None:
        incompatible = """\
CUE не складывается по формуле, но эта строка ниже намеренно нарушает контракт.
Шкала: 1, 2, 3, 5, 8, 13. Label: SP:<N>.
Metadata: story_points и estimation_model.
Каждый фактор получает значение от 1 до 5.
Сложить C + U + E и выбрать размер.
"""
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "incompatible.md"
            candidate.write_text(incompatible, encoding="utf-8")
            result = self._run("--document", str(candidate))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("forbidden C + U + E conversion formula", result.stderr)
        self.assertIn("forbidden per-factor 1-to-5 CUE rubric", result.stderr)


if __name__ == "__main__":
    unittest.main()
