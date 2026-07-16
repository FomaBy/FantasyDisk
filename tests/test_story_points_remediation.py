from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import story_points_remediation as spr  # noqa: E402


SP8_LABEL = {"id": "label-sp8", "name": "SP:8"}
SP5_LABEL = {"id": "label-sp5", "name": "SP:5"}
# A second, distinct SP:5 label record (different id, same name) — two label
# records both encoding "5" is ambiguous provenance, not a single estimate.
SP5_LABEL_DUP = {"id": "label-sp5-b", "name": "SP:5"}
OTHER_LABEL = {"id": "label-bug", "name": "bug"}
RETRO_MODEL = "CUE retrospective v1; Fibonacci 1,2,3,5,8,13"
DESCRIPTION_BLOCK = (
    "## Оценка сложности\n\nStory points: 5\nLabel: `SP:5`\n"
    "Модель: CUE / Fibonacci `1, 2, 3, 5, 8, 13`\nОбоснование: bounded.\n"
)


def estimate_block(points) -> str:
    return (
        f"## Оценка сложности\n\nStory points: {points}\nLabel: `SP:{points}`\n"
        "Модель: CUE / Fibonacci `1, 2, 3, 5, 8, 13`\nОбоснование: bounded.\n"
    )


def make_issue(**overrides) -> dict:
    issue = {
        "id": "issue-1",
        "identifier": "FAN-1",
        "number": 1,
        "project_id": spr.LIVE_PROJECT_ID,
        "status": "done",
        "description": "",
        "assignee_id": None,
        "created_at": "2026-07-01T00:00:00Z",
        "updated_at": "2026-07-15T18:20:00Z",
        "labels": [],
        "metadata": {},
    }
    issue.update(overrides)
    return issue


class ClassifyTest(unittest.TestCase):
    def test_retrospective_backfill(self):
        issue = make_issue(
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        self.assertEqual(spr.classify(issue), spr.RETROSPECTIVE_BACKFILL)

    def test_conflicted_when_backfill_overwrote_prework_estimate(self):
        issue = make_issue(
            description=DESCRIPTION_BLOCK,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        self.assertEqual(spr.classify(issue), spr.CONFLICTED)

    def test_accepted_prework(self):
        issue = make_issue(
            description=DESCRIPTION_BLOCK,
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.ACCEPTED_PREWORK)

    def test_unestimated(self):
        self.assertEqual(spr.classify(make_issue()), spr.UNESTIMATED)

    def test_canonical_metadata_without_label_is_inconsistent(self):
        issue = make_issue(
            description=DESCRIPTION_BLOCK,
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_label_metadata_mismatch_is_inconsistent(self):
        issue = make_issue(
            description=DESCRIPTION_BLOCK,
            labels=[SP8_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_description_5_vs_label_metadata_8_is_inconsistent(self):
        # FAN-1166 repro: description says 5 while Label/metadata say 8.
        issue = make_issue(
            description="Story points: 5",
            labels=[SP8_LABEL],
            metadata={
                "story_points": 8,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_description_8_vs_label_metadata_5_is_inconsistent(self):
        # Opposite direction: description says 8 while Label/metadata say 5.
        issue = make_issue(
            description="Story points: 8",
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_missing_description_estimate_is_inconsistent(self):
        issue = make_issue(
            description="No estimate block here.",
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_malformed_description_estimate_is_inconsistent(self):
        issue = make_issue(
            description="Story points: five",
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_duplicate_description_estimate_is_inconsistent(self):
        issue = make_issue(
            description="Story points: 5\n...\nStory points: 5",
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_accepted_with_string_metadata_points(self):
        issue = make_issue(
            description=estimate_block(5),
            labels=[SP5_LABEL],
            metadata={
                "story_points": "5",
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        self.assertEqual(spr.classify(issue), spr.ACCEPTED_PREWORK)

    def test_description_estimates_parsing(self):
        self.assertEqual(
            spr.description_estimates(make_issue(description=DESCRIPTION_BLOCK)),
            [5],
        )
        self.assertEqual(
            spr.description_estimates(make_issue(description="")), []
        )
        self.assertEqual(
            spr.description_estimates(
                make_issue(description="Story points: 8")
            ),
            [8],
        )
        self.assertEqual(
            spr.description_estimates(
                make_issue(description="Story points: five")
            ),
            [],
        )
        self.assertEqual(
            spr.description_estimates(
                make_issue(description="Story points: 5\nStory points: 5")
            ),
            [5, 5],
        )

    def test_description_estimates_reject_partial_values(self):
        # FAN-1170: a numeric prefix of a malformed value is not an estimate.
        for text in (
            "Story points: 5.0",
            "Story points: 5abc",
            "Story points: 5 later prose",
            "Story points: 4",       # not a Fibonacci point value
            "Story points: 55",      # not a point value; `5` prefix must not parse
            "Story points: 135",     # `13` prefix must not parse
            "Story points:",         # marker without a value
            "see the Story points: 5 marker inline",  # not a full line
        ):
            self.assertEqual(
                spr.description_estimates(make_issue(description=text)),
                [],
                text,
            )

    def test_description_estimates_accept_whitespace_and_crlf_boundaries(self):
        self.assertEqual(
            spr.description_estimates(
                make_issue(description="Story points: 13")
            ),
            [13],
        )
        self.assertEqual(
            spr.description_estimates(
                make_issue(
                    description="## Оценка сложности\r\n\r\nStory points: 5\r\n"
                                "Label: `SP:5`\r\n"
                )
            ),
            [5],
        )
        self.assertEqual(
            spr.description_estimates(
                make_issue(description="  Story points: 5  \nLabel: `SP:5`\n")
            ),
            [5],
        )
        self.assertEqual(
            spr.description_estimates(
                make_issue(description="story points: 5")
            ),
            [5],
        )

    def test_description_markers_count_every_marker(self):
        self.assertEqual(spr.description_markers(make_issue(description="")), 0)
        self.assertEqual(
            spr.description_markers(make_issue(description=DESCRIPTION_BLOCK)), 1
        )
        self.assertEqual(
            spr.description_markers(
                make_issue(description="Story points: five\nStory points: 5")
            ),
            2,
        )
        self.assertEqual(
            spr.description_markers(
                make_issue(description="see the `Story points:` marker inline")
            ),
            1,
        )
        self.assertEqual(
            spr.description_markers(
                make_issue(description="Story points : 5")
            ),
            1,
        )


class MalformedMarkerTest(unittest.TestCase):
    """FAN-1170: malformed/duplicate `Story points:` markers fail closed."""

    def _canonical_issue(self, description) -> dict:
        # Canonical Label SP:5 + numeric metadata 5 + canonical model: the
        # bug reproduction where only the description marker is broken.
        return make_issue(
            description=description,
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )

    def test_decimal_value_is_inconsistent(self):
        # Was falsely accepted: `5.0` parsed as `5` via its numeric prefix.
        issue = self._canonical_issue("Story points: 5.0")
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_suffixed_value_is_inconsistent(self):
        # Was falsely accepted: `5abc` parsed as `5` via its numeric prefix.
        issue = self._canonical_issue("Story points: 5abc")
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_malformed_marker_next_to_valid_line_is_inconsistent(self):
        # Was falsely accepted: `five` was invisible, leaving one valid line.
        issue = self._canonical_issue("Story points: five\nStory points: 5")
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_valueless_marker_next_to_valid_line_is_inconsistent(self):
        issue = self._canonical_issue("Story points:\nStory points: 5")
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_inline_marker_next_to_valid_line_is_inconsistent(self):
        issue = self._canonical_issue(
            "prose quoting a `Story points:` marker\n\nStory points: 5"
        )
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_non_fibonacci_value_is_inconsistent(self):
        issue = self._canonical_issue("Story points: 4")
        self.assertEqual(spr.classify(issue), spr.INCONSISTENT)

    def test_crlf_estimate_block_stays_accepted(self):
        issue = self._canonical_issue(
            "## Оценка сложности\r\n\r\nStory points: 5\r\nLabel: `SP:5`\r\n"
            "Модель: CUE / Fibonacci `1, 2, 3, 5, 8, 13`\r\n"
        )
        self.assertEqual(spr.classify(issue), spr.ACCEPTED_PREWORK)

    def test_trailing_whitespace_estimate_line_stays_accepted(self):
        issue = self._canonical_issue(
            "## Оценка сложности\n\nStory points: 5  \nLabel: `SP:5`\n"
        )
        self.assertEqual(spr.classify(issue), spr.ACCEPTED_PREWORK)

    def test_exact_accepted_control_stays_accepted(self):
        issue = self._canonical_issue(DESCRIPTION_BLOCK)
        self.assertEqual(spr.classify(issue), spr.ACCEPTED_PREWORK)

    def test_retrospective_with_malformed_marker_is_conflicted(self):
        # A broken pre-work record is still a description record: cleanup may
        # remove backfill Label/metadata but must flag the description as
        # conflicted, never treat it as absent.
        issue = make_issue(
            description="Story points: five",
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        self.assertEqual(spr.classify(issue), spr.CONFLICTED)


class AmbiguousSpLabelTest(unittest.TestCase):
    """FAN-1167: exactly one removable SP Label is required for cleanup."""

    def _retro_meta(self, points=8):
        return {"story_points": points, "estimation_model": RETRO_MODEL}

    def test_two_distinct_sp_labels_is_ambiguous(self):
        issue = make_issue(
            labels=[SP5_LABEL, SP8_LABEL], metadata=self._retro_meta()
        )
        self.assertEqual(spr.classify(issue), spr.AMBIGUOUS)

    def test_same_name_distinct_ids_is_ambiguous(self):
        issue = make_issue(
            labels=[SP5_LABEL, SP5_LABEL_DUP], metadata=self._retro_meta(5)
        )
        self.assertEqual(spr.classify(issue), spr.AMBIGUOUS)

    def test_zero_sp_labels_retrospective_is_ambiguous(self):
        # Backfill metadata but no SP Label: still ambiguous, no cleanup.
        issue = make_issue(metadata=self._retro_meta())
        self.assertEqual(spr.classify(issue), spr.AMBIGUOUS)

    def test_conflicted_with_multiple_labels_is_ambiguous(self):
        issue = make_issue(
            description=DESCRIPTION_BLOCK,
            labels=[SP5_LABEL, SP8_LABEL],
            metadata=self._retro_meta(),
        )
        self.assertEqual(spr.classify(issue), spr.AMBIGUOUS)

    def test_repeated_same_label_id_collapses_to_one(self):
        # The exact same label record repeated is one attachment: still clean.
        issue = make_issue(
            labels=[SP5_LABEL, dict(SP5_LABEL)], metadata=self._retro_meta(5)
        )
        self.assertEqual(spr.classify(issue), spr.RETROSPECTIVE_BACKFILL)
        self.assertEqual(spr.single_sp_label(issue), SP5_LABEL)
        removes = [
            a for a in spr.derive_actions(issue) if a["op"] == "label_remove"
        ]
        self.assertEqual(len(removes), 1)
        self.assertEqual(removes[0]["label_name"], "SP:5")

    def test_derive_actions_refuses_multiple_distinct_sp_labels(self):
        issue = make_issue(
            labels=[SP5_LABEL, SP8_LABEL], metadata=self._retro_meta()
        )
        with self.assertRaises(spr.RemediationError):
            spr.derive_actions(issue)

    def test_derive_actions_refuses_zero_sp_labels(self):
        issue = make_issue(metadata=self._retro_meta())
        with self.assertRaises(spr.RemediationError):
            spr.derive_actions(issue)

    def test_plan_diverts_ambiguous_issue_to_manual_review(self):
        # Reproduction from the bug: SP:5 + SP:8 must NOT yield two removals.
        ambiguous = make_issue(
            id="issue-amb", identifier="FAN-20", number=20,
            labels=[SP5_LABEL, SP8_LABEL], metadata=self._retro_meta(),
        )
        plan = spr.build_plan([ambiguous])
        self.assertEqual(plan, [])
        self.assertEqual(spr.review_needed([ambiguous]), [ambiguous])

    def test_plan_keeps_clean_issue_and_flags_ambiguous_one(self):
        clean = make_issue(
            id="issue-c", identifier="FAN-30", number=30,
            labels=[SP8_LABEL], metadata=self._retro_meta(),
        )
        ambiguous = make_issue(
            id="issue-a", identifier="FAN-31", number=31,
            labels=[SP5_LABEL, SP8_LABEL], metadata=self._retro_meta(),
        )
        plan = spr.build_plan([clean, ambiguous])
        self.assertEqual([e["identifier"] for e in plan], ["FAN-30"])
        self.assertEqual(
            [i["identifier"] for i in spr.review_needed([clean, ambiguous])],
            ["FAN-31"],
        )


class BuildPlanTest(unittest.TestCase):
    def test_plan_covers_only_closed_cleanable_issues(self):
        retro = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        conflicted = make_issue(
            id="issue-c", identifier="FAN-11", number=11,
            status="cancelled",
            description=DESCRIPTION_BLOCK,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        accepted = make_issue(
            id="issue-a", identifier="FAN-12", number=12,
            description=DESCRIPTION_BLOCK,
            labels=[SP5_LABEL],
            metadata={
                "story_points": 5,
                "estimation_model": spr.CANONICAL_MODEL,
            },
        )
        open_retro = make_issue(
            id="issue-o", identifier="FAN-13", number=13,
            status="in_review",
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        plan = spr.build_plan([retro, conflicted, accepted, open_retro])
        self.assertEqual(
            [entry["identifier"] for entry in plan], ["FAN-10", "FAN-11"]
        )
        ops = {
            (action["op"], action.get("label_name") or action.get("key"))
            for action in plan[0]["actions"]
        }
        self.assertEqual(
            ops,
            {
                ("label_remove", "SP:8"),
                ("metadata_delete", "story_points"),
                ("metadata_delete", "estimation_model"),
            },
        )

    def test_plan_refuses_archive_issues(self):
        archived = make_issue(project_id=spr.ARCHIVE_PROJECT_ID)
        with self.assertRaises(spr.RemediationError):
            spr.build_plan([archived])

    def test_derive_actions_ignores_non_sp_labels_and_foreign_metadata(self):
        issue = make_issue(
            labels=[SP8_LABEL, OTHER_LABEL],
            metadata={
                "story_points": 8,
                "estimation_model": RETRO_MODEL,
                "release": "0.2.2",
                "completed_at": "2026-07-14T10:13:43Z",
            },
        )
        actions = spr.derive_actions(issue)
        self.assertEqual(
            [a.get("label_name") for a in actions if a["op"] == "label_remove"],
            ["SP:8"],
        )
        self.assertEqual(
            sorted(a["key"] for a in actions if a["op"] == "metadata_delete"),
            ["estimation_model", "story_points"],
        )


class ExecuteActionGuardTest(unittest.TestCase):
    def test_refuses_archive_project(self):
        issue = make_issue(project_id=spr.ARCHIVE_PROJECT_ID)
        action = {"op": "label_remove", "label_id": "x", "label_name": "SP:8"}
        with self.assertRaises(spr.RemediationError):
            spr.execute_action(issue, action, runner=self._forbidden_runner)

    def test_refuses_open_issue(self):
        issue = make_issue(status="in_progress")
        action = {"op": "label_remove", "label_id": "x", "label_name": "SP:8"}
        with self.assertRaises(spr.RemediationError):
            spr.execute_action(issue, action, runner=self._forbidden_runner)

    def test_refuses_non_sp_label_and_foreign_metadata_key(self):
        issue = make_issue()
        with self.assertRaises(spr.RemediationError):
            spr.execute_action(
                issue,
                {"op": "label_remove", "label_id": "x", "label_name": "bug"},
                runner=self._forbidden_runner,
            )
        with self.assertRaises(spr.RemediationError):
            spr.execute_action(
                issue,
                {"op": "metadata_delete", "key": "release"},
                runner=self._forbidden_runner,
            )

    @staticmethod
    def _forbidden_runner(args):
        raise AssertionError(f"mutation must not run: {args}")


class ApplyPlanTest(unittest.TestCase):
    def test_apply_reverifies_and_is_idempotent(self):
        retro = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        plan = spr.build_plan([retro])
        commands: list[list[str]] = []

        state = {"issue": retro}

        def fetch(issue_id):
            return state["issue"]

        def runner(args):
            commands.append(args)

        log = spr.apply_plan(plan, None, runner=runner, fetch=fetch)
        self.assertEqual(len(log["applied"]), 1)
        self.assertEqual(len(commands), 3)
        for args in commands:
            self.assertIn(retro["id"], args)

        # Second run against the already-clean issue: no mutations at all.
        state["issue"] = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[], metadata={},
        )
        commands.clear()
        log = spr.apply_plan(plan, None, runner=runner, fetch=fetch)
        self.assertEqual(log["applied"], [])
        self.assertEqual(len(log["skipped"]), 1)
        self.assertEqual(commands, [])

    def test_apply_refuses_issue_that_became_ambiguous(self):
        # Planned as clean, but a second SP Label appears before apply:
        # re-verification must refuse it with zero mutation commands.
        retro = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        plan = spr.build_plan([retro])
        self.assertEqual(len(plan), 1)
        ambiguous = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[SP8_LABEL, SP5_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        log = spr.apply_plan(
            plan, None,
            runner=ExecuteActionGuardTest._forbidden_runner,
            fetch=lambda issue_id: ambiguous,
        )
        self.assertEqual(log["applied"], [])
        self.assertEqual(len(log["errors"]), 1)
        self.assertIn("ambiguous", log["errors"][0]["error"].lower())

    def test_apply_records_error_when_issue_left_live_project(self):
        retro = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        plan = spr.build_plan([retro])
        moved = dict(retro, project_id=spr.ARCHIVE_PROJECT_ID)
        log = spr.apply_plan(
            plan, None,
            runner=ExecuteActionGuardTest._forbidden_runner,
            fetch=lambda issue_id: moved,
        )
        self.assertEqual(log["applied"], [])
        self.assertEqual(len(log["errors"]), 1)

    @staticmethod
    def _fail_fetch(issue_id):
        raise AssertionError(
            f"fetch must not run for an invalid limit: {issue_id}"
        )

    def _single_retro_plan(self):
        retro = make_issue(
            id="issue-r", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        return spr.build_plan([retro])

    def test_apply_rejects_negative_limit_before_any_fetch_or_mutation(self):
        plan = self._single_retro_plan()
        with self.assertRaises(spr.RemediationError):
            spr.apply_plan(
                plan, -1,
                runner=ExecuteActionGuardTest._forbidden_runner,
                fetch=self._fail_fetch,
            )

    def test_apply_rejects_zero_limit_before_any_fetch_or_mutation(self):
        plan = self._single_retro_plan()
        with self.assertRaises(spr.RemediationError):
            spr.apply_plan(
                plan, 0,
                runner=ExecuteActionGuardTest._forbidden_runner,
                fetch=self._fail_fetch,
            )

    def test_apply_positive_canary_limit_touches_only_first_entry(self):
        first = make_issue(
            id="issue-r10", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        second = make_issue(
            id="issue-r20", identifier="FAN-20", number=20,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        plan = spr.build_plan([first, second])
        by_id = {"issue-r10": first, "issue-r20": second}
        fetched: list[str] = []
        commands: list[list[str]] = []

        def fetch(issue_id):
            fetched.append(issue_id)
            return by_id[issue_id]

        def runner(args):
            commands.append(args)

        log = spr.apply_plan(plan, 1, runner=runner, fetch=fetch)
        self.assertEqual([e["identifier"] for e in log["applied"]], ["FAN-10"])
        self.assertEqual(fetched, ["issue-r10"])
        self.assertEqual(len(commands), 3)
        for args in commands:
            self.assertIn("issue-r10", args)
            self.assertNotIn("issue-r20", args)

    def test_apply_without_limit_covers_every_plan_entry(self):
        first = make_issue(
            id="issue-r10", identifier="FAN-10", number=10,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        second = make_issue(
            id="issue-r20", identifier="FAN-20", number=20,
            labels=[SP8_LABEL],
            metadata={"story_points": 8, "estimation_model": RETRO_MODEL},
        )
        plan = spr.build_plan([first, second])
        by_id = {"issue-r10": first, "issue-r20": second}

        log = spr.apply_plan(
            plan, None,
            runner=lambda args: None,
            fetch=lambda issue_id: by_id[issue_id],
        )
        self.assertEqual(
            [e["identifier"] for e in log["applied"]], ["FAN-10", "FAN-20"]
        )


class ReportTest(unittest.TestCase):
    def test_rows_group_by_completion_date_and_keep_provenance(self):
        issues = [
            make_issue(
                id="i1", identifier="FAN-1", number=1,
                labels=[SP5_LABEL],
                metadata={
                    "story_points": 5,
                    "estimation_model": spr.CANONICAL_MODEL,
                    "completed_at": "2026-07-14T10:00:00Z",
                },
                description=DESCRIPTION_BLOCK,
            ),
            make_issue(
                id="i2", identifier="FAN-2", number=2,
                labels=[SP8_LABEL],
                metadata={
                    "story_points": 8,
                    "estimation_model": spr.CANONICAL_MODEL,
                    "jira_resolved": "2026-07-14T23:59:59+0300",
                },
                description=DESCRIPTION_BLOCK,
            ),
        ]
        rows = spr.build_report_rows(issues, "accepted_prework")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["date"], "2026-07-14")
        self.assertEqual(rows[0]["issues"], 2)
        self.assertEqual(rows[0]["story_points"], 13)
        self.assertEqual(rows[0]["provenance"], "accepted_prework")
        self.assertEqual(
            rows[0]["date_sources"], "completed_at,jira_resolved"
        )

    def test_completion_date_preserves_original_dates(self):
        issue = make_issue(
            metadata={"completed_at": "2026-07-14T10:13:43Z"},
            updated_at="2026-07-15T18:28:58Z",
        )
        self.assertEqual(
            spr.completion_date(issue), ("2026-07-14", "completed_at")
        )
        bare = make_issue(updated_at="2026-07-15T18:28:58Z")
        self.assertEqual(
            spr.completion_date(bare), ("2026-07-15", "updated_at_fallback")
        )


if __name__ == "__main__":
    unittest.main()
