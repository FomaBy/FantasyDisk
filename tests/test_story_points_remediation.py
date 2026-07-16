from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import story_points_remediation as spr  # noqa: E402


SP8_LABEL = {"id": "label-sp8", "name": "SP:8"}
SP5_LABEL = {"id": "label-sp5", "name": "SP:5"}
OTHER_LABEL = {"id": "label-bug", "name": "bug"}
RETRO_MODEL = "CUE retrospective v1; Fibonacci 1,2,3,5,8,13"
DESCRIPTION_BLOCK = (
    "## Оценка сложности\n\nStory points: 5\nLabel: `SP:5`\n"
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
