from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "tools" / "validate_story_points_contract.py"


class StoryPointsContractTest(unittest.TestCase):
    CONTRACT_PREAMBLE = """\
CUE не складывается по формуле.
Шкала: 1, 2, 3, 5, 8, 13. Label: SP:<N>.
Metadata: story_points и estimation_model.
"""

    def _run(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), *args],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def _validate_source(self, source: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "candidate.md"
            candidate.write_text(source, encoding="utf-8")
            return self._run("--document", str(candidate))

    def test_canonical_documents_share_the_contract(self) -> None:
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_formula_based_cue_rubric_is_rejected(self) -> None:
        incompatible = self.CONTRACT_PREAMBLE + """\
Каждый фактор получает значение от 1 до 5.
Сложить C + U + E и выбрать размер.
"""
        result = self._validate_source(incompatible)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("forbidden C + U + E conversion formula", result.stderr)
        self.assertIn("forbidden per-factor 1-to-5 CUE rubric", result.stderr)

    def test_per_factor_score_in_a_cue_paragraph_is_rejected(self) -> None:
        result = self._validate_source(
            self.CONTRACT_PREAMBLE + "Каждый фактор получает значение от 1 до 5."
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("forbidden per-factor 1-to-5 CUE rubric", result.stderr)

    def test_natural_language_factor_scale_is_rejected(self) -> None:
        statements = (
            "Оцените Complexity, Uncertainty и Effort по пятибалльной шкале 1–5.",
            "Оцените сложность, неопределённость и трудозатраты по шкале от 1 до 5.",
            "Rate Complexity, Uncertainty and Effort from one to five.",
            "Оцените сложность, неопределённость и трудозатраты от одного до пяти.",
            "Rate C, U and E independently from 1 to 5.",
        )
        for statement in statements:
            with self.subTest(statement=statement):
                self._assert_natural_language_factor_scale_is_rejected(statement)

    def _assert_natural_language_factor_scale_is_rejected(self, statement: str) -> None:
        result = self._validate_source(self.CONTRACT_PREAMBLE + statement)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("forbidden natural-language per-factor 1-to-5 CUE rubric", result.stderr)

    def test_conversion_threshold_rubric_is_rejected(self) -> None:
        statements = (
            "После оценки примените пороги: итог 3–5 = SP 1, 6–8 = SP 2, 9–15 = SP 3.",
            "| Total | SP |\n| --- | --- |\n| 3–5 | 1 |\n| 6–8 | 2 |",
            "| Total | Story points |\n| --- | --- |\n| 3–5 | 1 |\n| 6–8 | 2 |",
            "| Итого | Баллы истории |\n| --- | --- |\n| 3–5 | 1 |\n| 6–8 | 2 |",
            "A total from three to five maps to SP 1; six to eight maps to SP 2.",
            "Итог от трёх до пяти соответствует SP 1; от шести до восьми соответствует SP 2.",
        )
        for statement in statements:
            with self.subTest(statement=statement):
                result = self._validate_source(self.CONTRACT_PREAMBLE + statement)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("forbidden conversion-threshold CUE rubric", result.stderr)

    def test_nearby_non_cue_scales_and_ranges_are_accepted(self) -> None:
        statements = (
            "Complexity, Uncertainty and Effort are considered holistically. "
            "A separate five-point accessibility checklist reviews document presentation only.",
            "Сложность, неопределённость и трудозатраты рассматриваются целиком. "
            "Отдельный пятибалльный чек-лист проверяет только качество текста.",
            "CUE is evaluated holistically while a separate five-point accessibility "
            "checklist reviews document presentation only.",
            "Complexity, Uncertainty and Effort are considered holistically. "
            "Operational evidence rule: attempts 1–3 → 2 sanitized log copies.",
        )
        for statement in statements:
            with self.subTest(statement=statement):
                result = self._validate_source(self.CONTRACT_PREAMBLE + statement)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_semantic_edge_matrix_preserves_cue_context_and_range_subjects(self) -> None:
        cases = (
            (
                "two_sentence_english_cue_scale",
                "- Rate Complexity, Uncertainty and Effort independently.\n"
                "  Use a scale from 1 to 5.",
                True,
            ),
            (
                "two_sentence_russian_cue_scale",
                "Оцените сложность, неопределённость и трудозатраты отдельно. "
                "Используйте шкалу от одного до пяти.",
                True,
            ),
            (
                "english_cue_scale_with_separate_checklist_evasion",
                "Rate Complexity, Uncertainty and Effort from 1 to 5 "
                "in a separate scoring checklist.",
                True,
            ),
            (
                "russian_cue_scale_with_separate_checklist_evasion",
                "Оцените сложность, неопределённость и трудозатраты от одного до пяти "
                "в отдельном чек-листе оценки.",
                True,
            ),
            (
                "english_retry_range",
                "Complexity, Uncertainty and Effort are considered holistically, while "
                "the reviewer retries the export from one to five times.",
                False,
            ),
            (
                "russian_retry_range",
                "Сложность, неопределённость и трудозатраты рассматриваются целиком, а "
                "проверяющий повторяет экспорт от одного до пяти раз.",
                False,
            ),
            (
                "english_accessibility_factors",
                "Complexity, Uncertainty and Effort are considered holistically. "
                "Each factor in a separate accessibility checklist is rated from 1 to 5.",
                False,
            ),
            (
                "russian_accessibility_factors",
                "Сложность, неопределённость и трудозатраты рассматриваются целиком. "
                "Каждый фактор отдельного чек-листа доступности оценивается от 1 до 5.",
                False,
            ),
            (
                "same_sentence_separate_checklist",
                "Complexity, Uncertainty and Effort are considered holistically while a "
                "separate five-point accessibility checklist reviews document presentation only.",
                False,
            ),
            (
                "wrapped_english_factor_scale",
                "- Rate Complexity,\n  Uncertainty,\n  and Effort from one to five.",
                True,
            ),
            (
                "wrapped_russian_factor_scale",
                "- Оцените сложность,\n  неопределённость\n  и трудозатраты от одного до пяти.",
                True,
            ),
            (
                "wrapped_cue_abbreviation_scale",
                "- Rate C,\n  U and E independently from 1 to 5.",
                True,
            ),
            (
                "two_sentence_cue_abbreviation_each_factor",
                "- Score C, U and E independently.\n"
                "  Each factor uses a scale from 1 to 5.",
                True,
            ),
            (
                "numbered_soft_wrap",
                "1. Rate Complexity,\n"
                "   Uncertainty and Effort from one to five.",
                True,
            ),
            (
                "blockquote_soft_wrap",
                "> Rate Complexity,\n"
                "> Uncertainty and Effort from one to five.",
                True,
            ),
            (
                "operational_table_without_story_points",
                "| Attempts | Sanitized copies |\n| --- | --- |\n| 1–3 | 2 |",
                False,
            ),
            (
                "markdown_story_points_header",
                "| Total | Story points |\n| --- | --- |\n| 3–5 | 1 |\n| 6–8 | 2 |",
                True,
            ),
        )
        for name, statement, should_reject in cases:
            with self.subTest(case=name):
                result = self._validate_source(self.CONTRACT_PREAMBLE + statement)
                self.assertEqual(result.returncode != 0, should_reject, result.stderr)

    def test_bounded_subject_context_matrix(self) -> None:
        cases = (
            (
                "english_cue_via_quality_checklist",
                "Rate Complexity, Uncertainty and Effort using a separate five-point "
                "quality checklist.",
                True,
            ),
            (
                "russian_cue_via_quality_checklist",
                "Оцените сложность, неопределённость и трудозатраты с помощью отдельного "
                "пятибалльного чек-листа качества.",
                True,
            ),
            (
                "english_attempts_to_score_cue",
                "The reviewer attempts to rate Complexity, Uncertainty and Effort "
                "from one to five.",
                True,
            ),
            (
                "russian_attempt_to_score_cue",
                "Проверяющий делает попытку оценить сложность, неопределённость и "
                "трудозатраты от одного до пяти.",
                True,
            ),
            (
                "english_independent_quality_subject",
                "Complexity, Uncertainty and Effort are considered holistically. "
                "A separate quality checklist rates document clarity from one to five.",
                False,
            ),
            (
                "russian_independent_quality_subject",
                "Сложность, неопределённость и трудозатраты рассматриваются целиком. "
                "Отдельный чек-лист качества оценивает ясность документа от одного до пяти.",
                False,
            ),
            (
                "english_modified_export_attempts",
                "Complexity, Uncertainty and Effort are considered holistically, while "
                "the reviewer performs from one to five sanitized export attempts.",
                False,
            ),
            (
                "russian_modified_export_attempts",
                "Сложность, неопределённость и трудозатраты рассматриваются целиком, а "
                "проверяющий выполняет от одного до пяти повторных попыток экспорта.",
                False,
            ),
        )
        for name, statement, should_reject in cases:
            with self.subTest(case=name):
                result = self._validate_source(self.CONTRACT_PREAMBLE + statement)
                self.assertEqual(result.returncode != 0, should_reject, result.stderr)

    def test_subject_predicate_boundary_matrix(self) -> None:
        cases = (
            (
                "english_holistic_action_then_clarity_subject",
                "Assess Complexity, Uncertainty and Effort holistically, while a separate "
                "quality checklist rates document clarity from one to five.",
                False,
            ),
            (
                "russian_holistic_action_then_clarity_subject",
                "Оценивайте сложность, неопределённость и трудозатраты целостно, а "
                "отдельный чек-лист качества оценивает ясность документа от одного до пяти.",
                False,
            ),
            (
                "english_direct_cue_quality_checklist_with_clarity_subject",
                "Rate Complexity, Uncertainty and Effort using a separate quality checklist "
                "that rates document clarity from one to five.",
                True,
            ),
            (
                "russian_direct_cue_quality_checklist_with_clarity_subject",
                "Оцените сложность, неопределённость и трудозатраты с помощью отдельного "
                "чек-листа качества, который оценивает ясность документа от одного до пяти.",
                True,
            ),
            (
                "english_mixed_clarity_and_cue_subject",
                "Assess Complexity, Uncertainty and Effort holistically, while a separate "
                "quality checklist rates document clarity and Complexity, Uncertainty and "
                "Effort from one to five.",
                True,
            ),
            (
                "russian_mixed_clarity_and_cue_subject",
                "Оценивайте сложность, неопределённость и трудозатраты целостно, а "
                "отдельный чек-лист качества оценивает ясность документа, сложность, "
                "неопределённость и трудозатраты от одного до пяти.",
                True,
            ),
            (
                "english_attempts_to_score_cue",
                "The reviewer attempts to rate Complexity, Uncertainty and Effort from one "
                "to five.",
                True,
            ),
            (
                "russian_attempts_to_score_cue",
                "Проверяющий делает попытку оценить сложность, неопределённость и "
                "трудозатраты от одного до пяти.",
                True,
            ),
        )
        for name, statement, should_reject in cases:
            with self.subTest(case=name):
                result = self._validate_source(self.CONTRACT_PREAMBLE + statement)
                self.assertEqual(result.returncode != 0, should_reject, result.stderr)


if __name__ == "__main__":
    unittest.main()
