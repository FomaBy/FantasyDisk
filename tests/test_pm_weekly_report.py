"""FAN-3903: fixture tests for the PM weekly product-behavior report.

Every test drives the tool through a fake read-only Multica reader or a fake
`multica` executable, so the suite never reads and never writes the live board.
"""
from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import pm_weekly_report as pwr  # noqa: E402


SINCE = "2026-08-30T22:00:00Z"
UNTIL = "2026-09-06T22:00:00Z"
AFTER_WINDOW = datetime(2026, 9, 7, 6, 0, tzinfo=timezone.utc)

PRODUCT_LABEL = {"id": "label-pb", "name": pwr.PRODUCT_BEHAVIOR_LABEL}
OTHER_LABEL = {"id": "label-sp5", "name": "SP:5"}


def make_issue(
    number: int,
    title: str = "Card",
    labels=(),
    created_at: str = "2026-08-01T00:00:00Z",
    updated_at: str = "2026-09-02T00:00:00Z",
) -> dict:
    return {
        "id": f"issue-{number}",
        "identifier": f"FAN-{number}",
        "number": number,
        "project_id": pwr.LIVE_PROJECT_ID,
        "status": "done",
        "title": title,
        "labels": list(labels),
        "created_at": created_at,
        "updated_at": updated_at,
    }


def done_at(*timestamps: str) -> list:
    """A status_changed history that enters `done` at each timestamp."""
    entries = []
    for index, moment in enumerate(timestamps):
        if index:
            entries.append({
                "action": "status_changed",
                "created_at": moment,
                "details": {"from": "done", "to": "in_progress"},
            })
        entries.append({
            "action": "status_changed",
            "created_at": moment,
            "details": {"from": "in_review", "to": "done"},
        })
    return entries


def paginate(issues, limit=pwr.PAGE_LIMIT, total=None):
    """Server-shaped pages for `issue list`, keyed by offset."""
    total = len(issues) if total is None else total
    pages = {}
    offset = 0
    while True:
        batch = issues[offset:offset + limit]
        pages[offset] = {
            "issues": batch,
            "limit": limit,
            "offset": offset,
            "total": total,
            "has_more": offset + len(batch) < len(issues),
        }
        offset += len(batch)
        if offset >= len(issues):
            break
    return pages


class FakeReader:
    """A read-only stand-in for the Multica CLI, backed by fixtures."""

    def __init__(self, pages, timelines=None, timeline_stderr=None):
        self.pages = pages
        self.timelines = timelines or {}
        self.timeline_stderr = timeline_stderr or {}
        self.calls = []

    def json(self, *args):
        if tuple(args[:2]) not in pwr.READ_ONLY_COMMANDS:
            raise AssertionError(f"fixture reader got a write command: {args}")
        self.calls.append(args)
        if args[:2] == ("issue", "list"):
            offset = int(args[args.index("--offset") + 1])
            if offset not in self.pages:
                raise AssertionError(f"no fixture page at offset {offset}")
            return self.pages[offset], ""
        issue_id = args[2]
        if issue_id not in self.timelines:
            raise AssertionError(f"no fixture timeline for {issue_id}")
        return self.timelines[issue_id], self.timeline_stderr.get(issue_id, "")

    def timeline_ids(self):
        return [call[2] for call in self.calls if call[:2] == ("issue", "timeline")]


def collect(reader, since=SINCE, until=UNTIL, label=pwr.PRODUCT_BEHAVIOR_LABEL,
            now=AFTER_WINDOW):
    return pwr.collect(
        reader,
        pwr.LIVE_PROJECT_ID,
        pwr.parse_rfc3339(since),
        pwr.parse_rfc3339(until),
        label,
        since,
        until,
        now,
    )


def run_capture(argv, reader=None, now=AFTER_WINDOW):
    """Run the CLI entry point, returning (exit code, stdout)."""
    buffer = io.StringIO()
    with redirect_stdout(buffer):
        code = pwr.main(argv, reader=reader, now=now)
    return code, buffer.getvalue()


class TimestampTest(unittest.TestCase):
    def test_offsets_and_z_denote_the_same_instant(self):
        self.assertEqual(
            pwr.parse_rfc3339("2026-08-30T22:00:00Z"),
            pwr.parse_rfc3339("2026-08-31T00:00:00+02:00"),
        )
        self.assertEqual(
            pwr.parse_rfc3339("2026-08-30T22:00:00Z"),
            pwr.parse_rfc3339("2026-08-30T17:00:00-05:00"),
        )

    def test_sub_second_precision_round_trips(self):
        moment = pwr.parse_rfc3339("2026-09-01T10:00:00.510867Z")
        self.assertEqual(pwr.format_rfc3339(moment), "2026-09-01T10:00:00.510867Z")

    def test_timestamp_without_an_offset_is_refused(self):
        with self.assertRaises(pwr.ReportError):
            pwr.parse_rfc3339("2026-08-31T00:00:00", "--since")

    def test_impossible_instant_is_refused(self):
        with self.assertRaises(pwr.ReportError):
            pwr.parse_rfc3339("2026-02-30T00:00:00Z", "--since")
        with self.assertRaises(pwr.ReportError):
            pwr.parse_rfc3339("2026-09-01T00:00:00+30:00", "--since")


class ReworkTitleTokenTest(unittest.TestCase):
    def test_standalone_token_matches_in_any_case(self):
        for title in ("REWORK: fix the ultimate", "rework of the HUD",
                      "Rework", "FAN-1 (rework) tail", "ПЕРЕДЕЛКА REWORK карточки"):
            with self.subTest(title=title):
                self.assertTrue(pwr.has_rework_token(title))

    def test_substring_matches_are_not_tokens(self):
        for title in ("reworked the HUD", "prework audit", "REWORKS",
                      "", "no marker here"):
            with self.subTest(title=title):
                self.assertFalse(pwr.has_rework_token(title))

    def test_punctuation_and_underscores_separate_tokens(self):
        self.assertTrue(pwr.has_rework_token("PRE-REWORK/QA"))
        self.assertTrue(pwr.has_rework_token("pre_rework guard"))


class PercentageTest(unittest.TestCase):
    def test_zero_denominator_is_zero_not_an_error(self):
        self.assertEqual(pwr.percentage(0, 0), 0.0)

    def test_share_is_rounded_to_one_decimal(self):
        self.assertEqual(pwr.percentage(1, 3), 33.3)
        self.assertEqual(pwr.percentage(2, 3), 66.7)


class PaginationTest(unittest.TestCase):
    def test_every_page_is_collected(self):
        issues = [make_issue(number) for number in range(1, 251)]
        reader = FakeReader(paginate(issues))
        collected = pwr.page_done_issues(reader, pwr.LIVE_PROJECT_ID)
        self.assertEqual(len(collected), 250)
        self.assertEqual(
            [call[call.index("--offset") + 1] for call in reader.calls],
            ["0", "100", "200"],
        )

    def test_every_page_asks_for_at_most_the_server_cap(self):
        reader = FakeReader(paginate([make_issue(1)]))
        pwr.page_done_issues(reader, pwr.LIVE_PROJECT_ID)
        for call in reader.calls:
            self.assertEqual(call[call.index("--limit") + 1], str(pwr.PAGE_LIMIT))
            self.assertLessEqual(int(call[call.index("--limit") + 1]), 100)

    def test_only_terminal_done_cards_are_collected(self):
        reader = FakeReader(paginate([make_issue(1)]))
        pwr.page_done_issues(reader, pwr.LIVE_PROJECT_ID)
        call = reader.calls[0]
        self.assertEqual(call[call.index("--status") + 1], "done")

    def test_incomplete_page_with_more_pending_is_refused(self):
        pages = paginate([make_issue(number) for number in range(1, 151)])
        pages[0]["issues"] = pages[0]["issues"][:50]
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.page_done_issues(FakeReader(pages), pwr.LIVE_PROJECT_ID)
        self.assertIn("incomplete page", str(raised.exception))

    def test_oversized_page_is_refused(self):
        issues = [make_issue(number) for number in range(1, 102)]
        pages = {0: {"issues": issues, "total": 101, "has_more": False}}
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.page_done_issues(FakeReader(pages), pwr.LIVE_PROJECT_ID)
        self.assertIn("for a limit of 100", str(raised.exception))

    def test_total_moving_between_pages_is_refused(self):
        pages = paginate([make_issue(number) for number in range(1, 151)])
        pages[100]["total"] = 149
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.page_done_issues(FakeReader(pages), pwr.LIVE_PROJECT_ID)
        self.assertIn("the board changed while paging", str(raised.exception))

    def test_duplicate_issue_across_pages_is_refused(self):
        issues = [make_issue(number) for number in range(1, 151)]
        pages = paginate(issues)
        pages[100]["issues"][0] = issues[0]
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.page_done_issues(FakeReader(pages), pwr.LIVE_PROJECT_ID)
        self.assertIn("duplicate issue", str(raised.exception))

    def test_final_count_below_the_reported_total_is_refused(self):
        pages = paginate([make_issue(1)], total=7)
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.page_done_issues(FakeReader(pages), pwr.LIVE_PROJECT_ID)
        self.assertIn("the server reported 7", str(raised.exception))


class CompletionTimeTest(unittest.TestCase):
    def test_status_re_entry_counts_the_latest_transition(self):
        issue = make_issue(1)
        reader = FakeReader(
            paginate([issue]),
            {"issue-1": done_at("2026-08-25T09:00:00Z", "2026-09-02T09:00:00Z")},
        )
        self.assertEqual(
            pwr.latest_done_transition(reader, issue),
            pwr.parse_rfc3339("2026-09-02T09:00:00Z"),
        )

    def test_updated_at_is_never_the_completion_time(self):
        issue = make_issue(1, updated_at="2026-09-05T18:00:00Z")
        reader = FakeReader(
            paginate([issue]), {"issue-1": done_at("2026-09-02T09:00:00Z")}
        )
        snapshot = collect(reader)
        self.assertEqual(
            [record["completed_at"] for record in snapshot["records"]],
            ["2026-09-02T09:00:00Z"],
        )

    def test_done_card_without_a_recorded_transition_is_refused(self):
        issue = make_issue(1)
        reader = FakeReader(paginate([issue]), {"issue-1": []})
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.latest_done_transition(reader, issue)
        self.assertIn("no recorded status_changed transition into done",
                      str(raised.exception))

    def test_transitions_out_of_done_are_not_completions(self):
        issue = make_issue(1)
        timeline = [{
            "action": "status_changed",
            "created_at": "2026-09-02T09:00:00Z",
            "details": {"from": "done", "to": "in_progress"},
        }]
        reader = FakeReader(paginate([issue]), {"issue-1": timeline})
        with self.assertRaises(pwr.ReportError):
            pwr.latest_done_transition(reader, issue)

    def test_truncated_timeline_is_refused(self):
        issue = make_issue(1)
        reader = FakeReader(
            paginate([issue]),
            {"issue-1": done_at("2026-09-02T09:00:00Z")},
            {"issue-1": (
                "warning: timeline truncated by the server cap (status_changed): "
                "older entries are missing.\n"
            )},
        )
        with self.assertRaises(pwr.ReportError) as raised:
            pwr.latest_done_transition(reader, issue)
        self.assertIn("capped the timeline read", str(raised.exception))


class WindowBoundaryTest(unittest.TestCase):
    def _summary(self, timestamps, since=SINCE, until=UNTIL):
        issues = [
            make_issue(index + 1, updated_at=moment)
            for index, moment in enumerate(timestamps)
        ]
        timelines = {
            issue["id"]: done_at(moment)
            for issue, moment in zip(issues, timestamps)
        }
        reader = FakeReader(paginate(issues), timelines)
        return pwr.summarize(collect(reader, since=since, until=until))

    def test_start_is_inclusive_and_end_is_exclusive(self):
        summary = self._summary([
            "2026-08-30T21:59:59Z",   # before the window
            "2026-08-30T22:00:00Z",   # exactly the start: included
            "2026-09-06T21:59:59Z",   # last second inside
            "2026-09-06T22:00:00Z",   # exactly the end: excluded
        ])
        self.assertEqual(
            [item["identifier"] for item in summary["completions"]],
            ["FAN-2", "FAN-3"],
        )

    def test_local_offsets_select_the_same_completions(self):
        utc = self._summary(["2026-09-01T10:00:00Z"])
        warsaw = self._summary(
            ["2026-09-01T12:00:00+02:00"],
            since="2026-08-31T00:00:00+02:00",
            until="2026-09-07T00:00:00+02:00",
        )
        self.assertEqual(utc["counts"], warsaw["counts"])
        self.assertEqual(
            [item["completed_at"] for item in warsaw["completions"]],
            ["2026-09-01T10:00:00Z"],
        )

    def test_out_of_band_cards_never_reach_a_timeline_read(self):
        issues = [
            make_issue(1, updated_at="2026-08-29T00:00:00Z"),
            make_issue(2, created_at="2026-09-07T00:00:00Z",
                       updated_at="2026-09-08T00:00:00Z"),
            make_issue(3, updated_at="2026-09-02T00:00:00Z"),
        ]
        reader = FakeReader(
            paginate(issues), {"issue-3": done_at("2026-09-02T00:00:00Z")}
        )
        snapshot = collect(reader)
        self.assertEqual(reader.timeline_ids(), ["issue-3"])
        self.assertEqual(snapshot["population"]["skipped_outside_window_bounds"], 2)

    def test_card_touched_inside_the_window_but_finished_earlier_is_excluded(self):
        issue = make_issue(1, updated_at="2026-09-03T00:00:00Z")
        reader = FakeReader(
            paginate([issue]), {"issue-1": done_at("2026-08-20T00:00:00Z")}
        )
        summary = pwr.summarize(collect(reader))
        self.assertEqual(summary["counts"]["completions"], 0)


class CountsTest(unittest.TestCase):
    def _summary(self):
        issues = [
            make_issue(1, "Ultimate rebuild", labels=[PRODUCT_LABEL, OTHER_LABEL]),
            make_issue(2, "REWORK: dispatcher guard"),
            make_issue(3, "QA: exact-SHA review"),
            make_issue(4, "Boss art pack", labels=[PRODUCT_LABEL]),
            make_issue(5, "REWORK hero select frames", labels=[PRODUCT_LABEL]),
            make_issue(6, "Integration to dev"),
        ]
        timelines = {
            issue["id"]: done_at("2026-09-0{}T09:00:00Z".format(index + 1))
            for index, issue in enumerate(issues)
        }
        reader = FakeReader(paginate(issues), timelines)
        return pwr.summarize(collect(reader))

    def test_counts_and_percentages(self):
        summary = self._summary()
        self.assertEqual(summary["counts"], {
            "completions": 6,
            "product_behavior": 3,
            "legacy_rework_title_token": 2,
        })
        self.assertEqual(summary["percentages"], {
            "product_behavior": 50.0,
            "legacy_rework_title_token": 33.3,
        })

    def test_source_ids_are_preserved_verbatim(self):
        summary = self._summary()
        self.assertEqual(
            [(item["identifier"], item["id"]) for item in summary["completions"]],
            [(f"FAN-{n}", f"issue-{n}") for n in range(1, 7)],
        )

    def test_markdown_separates_the_proxy_from_real_rework_history(self):
        markdown = pwr.render_markdown(self._summary())
        self.assertIn("| Legacy `REWORK` title-token proxy | 2 | 33.3% |", markdown)
        self.assertIn("legacy title-token proxy", markdown)
        self.assertIn("not the same-card rework history", markdown)
        self.assertIn('must never be published as "all rework"', markdown)

    def test_markdown_reports_every_metric_with_its_share(self):
        markdown = pwr.render_markdown(self._summary())
        self.assertIn("| Completions in window | 6 | 100.0% |", markdown)
        self.assertIn("| `product-behavior` completions | 3 | 50.0% |", markdown)


class ZeroDenominatorTest(unittest.TestCase):
    def test_empty_week_reports_zero_counts_and_zero_shares(self):
        reader = FakeReader(paginate([]))
        summary = pwr.summarize(collect(reader))
        self.assertEqual(summary["counts"], {
            "completions": 0,
            "product_behavior": 0,
            "legacy_rework_title_token": 0,
        })
        self.assertEqual(summary["percentages"], {
            "product_behavior": 0.0,
            "legacy_rework_title_token": 0.0,
        })
        markdown = pwr.render_markdown(summary)
        self.assertIn("| Completions in window | 0 | 0.0% |", markdown)
        self.assertIn("| `product-behavior` completions | 0 | 0.0% |", markdown)
        self.assertIn("| Legacy `REWORK` title-token proxy | 0 | 0.0% |", markdown)
        self.assertIn("No completions in this window.", markdown)


class MissingLabelTest(unittest.TestCase):
    def test_a_label_no_card_carries_yields_zero_without_failing(self):
        issues = [make_issue(1, "Ultimate rebuild")]
        reader = FakeReader(
            paginate(issues), {"issue-1": done_at("2026-09-01T09:00:00Z")}
        )
        summary = pwr.summarize(collect(reader))
        self.assertEqual(summary["counts"]["completions"], 1)
        self.assertEqual(summary["counts"]["product_behavior"], 0)
        self.assertEqual(summary["percentages"]["product_behavior"], 0.0)


class SnapshotTest(unittest.TestCase):
    def _reader(self):
        issues = [
            make_issue(1, "Ultimate rebuild", labels=[PRODUCT_LABEL]),
            make_issue(2, "REWORK: dispatcher guard"),
        ]
        return FakeReader(paginate(issues), {
            "issue-1": done_at("2026-09-01T09:00:00Z"),
            "issue-2": done_at("2026-09-03T09:00:00Z"),
        })

    def test_unchanged_snapshot_reproduces_the_published_report(self):
        snapshot = collect(self._reader())
        first = pwr.render_markdown(pwr.summarize(snapshot))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            pwr.write_snapshot(path, snapshot)
            reloaded = pwr.load_snapshot(path)
            self.assertEqual(reloaded, snapshot)
            self.assertEqual(pwr.render_markdown(pwr.summarize(reloaded)), first)

    def test_report_from_snapshot_matches_the_live_run_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            code, live = run_capture(
                ["--since", SINCE, "--until", UNTIL, "--snapshot-out", str(path)],
                reader=self._reader(),
            )
            self.assertEqual(code, 0)
            replay_code, replay = run_capture(["--from-snapshot", str(path)])
            self.assertEqual(replay_code, 0)
            self.assertEqual(replay, live)

    def test_replay_does_not_read_multica_at_all(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            run_capture(
                ["--since", SINCE, "--until", UNTIL, "--snapshot-out", str(path)],
                reader=self._reader(),
            )
            reader = FakeReader({})
            code, _ = run_capture(["--from-snapshot", str(path)], reader=reader)
            self.assertEqual(code, 0)
            self.assertEqual(reader.calls, [])

    def test_snapshot_binds_the_population_it_was_read_from(self):
        first = collect(self._reader())
        reader = self._reader()
        reader.pages[0]["issues"][0]["updated_at"] = "2026-09-04T00:00:00Z"
        self.assertNotEqual(
            first["population_digest"], collect(reader)["population_digest"]
        )

    def test_window_that_contradicts_the_snapshot_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            run_capture(
                ["--since", SINCE, "--until", UNTIL, "--snapshot-out", str(path)],
                reader=self._reader(),
            )
            code, _ = run_capture(
                ["--from-snapshot", str(path), "--since", "2026-08-24T22:00:00Z"]
            )
            self.assertEqual(code, 1)

    def test_equivalent_window_spelling_is_accepted_on_replay(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            run_capture(
                ["--since", SINCE, "--until", UNTIL, "--snapshot-out", str(path)],
                reader=self._reader(),
            )
            code, _ = run_capture([
                "--from-snapshot", str(path),
                "--since", "2026-08-31T00:00:00+02:00",
                "--until", "2026-09-07T00:00:00+02:00",
            ])
            self.assertEqual(code, 0)

    def test_label_or_project_that_contradicts_the_snapshot_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            run_capture(
                ["--since", SINCE, "--until", UNTIL, "--snapshot-out", str(path)],
                reader=self._reader(),
            )
            for override in (["--label", "other-label"], ["--project", "other"]):
                with self.subTest(override=override):
                    code, output = run_capture(
                        ["--from-snapshot", str(path)] + override
                    )
                    self.assertEqual(code, 1)
                    self.assertEqual(output, "")
            code, _ = run_capture([
                "--from-snapshot", str(path),
                "--label", pwr.PRODUCT_BEHAVIOR_LABEL,
                "--project", pwr.LIVE_PROJECT_ID,
            ])
            self.assertEqual(code, 0)

    def test_foreign_snapshot_format_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            path.write_text(json.dumps({"format": "other/v9"}), encoding="utf-8")
            with self.assertRaises(pwr.ReportError):
                pwr.load_snapshot(path)


class PartialWindowTest(unittest.TestCase):
    def _reader(self):
        return FakeReader(
            paginate([make_issue(1, "Ultimate rebuild", labels=[PRODUCT_LABEL])]),
            {"issue-1": done_at("2026-09-01T09:00:00Z")},
        )

    def test_report_collected_before_the_window_ends_is_refused(self):
        code, output = run_capture(
            ["--since", SINCE, "--until", UNTIL],
            reader=self._reader(),
            now=datetime(2026, 9, 5, 0, 0, tzinfo=timezone.utc),
        )
        self.assertEqual(code, 2)
        self.assertEqual(output, "")

    def test_partial_report_is_labelled_partial_when_explicitly_allowed(self):
        code, output = run_capture(
            ["--since", SINCE, "--until", UNTIL, "--allow-partial"],
            reader=self._reader(),
            now=datetime(2026, 9, 5, 0, 0, tzinfo=timezone.utc),
        )
        self.assertEqual(code, 0)
        self.assertIn("Interval: PARTIAL — not a full week", output)

    def test_complete_window_is_labelled_complete(self):
        code, output = run_capture(
            ["--since", SINCE, "--until", UNTIL], reader=self._reader()
        )
        self.assertEqual(code, 0)
        self.assertIn("Interval: complete", output)

    def test_a_partial_snapshot_stays_partial_on_replay(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "week.json"
            run_capture(
                ["--since", SINCE, "--until", UNTIL, "--allow-partial",
                 "--snapshot-out", str(path)],
                reader=self._reader(),
                now=datetime(2026, 9, 5, 0, 0, tzinfo=timezone.utc),
            )
            code, _ = run_capture(["--from-snapshot", str(path)])
            self.assertEqual(code, 2)


class ReadOnlyTest(unittest.TestCase):
    def test_write_commands_are_refused_before_any_process_starts(self):
        reader = pwr.MulticaReader(executable="multica-must-never-run")
        for command in (
            ("issue", "update", "FAN-1", "--status", "done"),
            ("issue", "status", "FAN-1", "done"),
            ("issue", "comment", "add", "FAN-1"),
            ("label", "create", "--name", pwr.PRODUCT_BEHAVIOR_LABEL),
            ("issue", "metadata", "set", "FAN-1"),
        ):
            with self.subTest(command=command):
                with self.assertRaises(pwr.ReportError) as raised:
                    reader.json(*command)
                self.assertIn("read-only allowlist", str(raised.exception))

    def test_the_allowlist_only_holds_read_commands(self):
        self.assertEqual(
            pwr.READ_ONLY_COMMANDS, (("issue", "list"), ("issue", "timeline"))
        )

    def test_a_full_run_issues_only_read_commands(self):
        issues = [make_issue(1, "Ultimate rebuild", labels=[PRODUCT_LABEL])]
        reader = FakeReader(
            paginate(issues), {"issue-1": done_at("2026-09-01T09:00:00Z")}
        )
        run_capture(["--since", SINCE, "--until", UNTIL], reader=reader)
        self.assertEqual(
            {call[:2] for call in reader.calls},
            {("issue", "list"), ("issue", "timeline")},
        )


FAKE_MULTICA = """#!{python}
import json
import sys

ARGS = sys.argv[1:]
FIXTURES = {fixtures!r}

with open(FIXTURES + "/argv.log", "a", encoding="utf-8") as handle:
    handle.write(json.dumps(ARGS) + "\\n")

if ARGS[:2] == ["issue", "list"]:
    sys.stdout.write(open(FIXTURES + "/page.json", encoding="utf-8").read())
elif ARGS[:2] == ["issue", "timeline"]:
    # A warning the tool must not mistake for a truncation refusal, and must
    # never let leak into the JSON it parses.
    sys.stderr.write("warning: an unrelated stderr note\\n")
    sys.stdout.write(open(FIXTURES + "/timeline.json", encoding="utf-8").read())
else:
    sys.stderr.write("fake multica refuses a write command\\n")
    raise SystemExit(3)
"""


@unittest.skipIf(os.name == "nt", "POSIX shebang executable fixture")
class ExecutableContractTest(unittest.TestCase):
    """The real reader must shell out correctly and keep stderr out of stdout."""

    def _fake_multica(self, directory, page, timeline):
        (directory / "page.json").write_text(
            json.dumps(page), encoding="utf-8"
        )
        (directory / "timeline.json").write_text(
            json.dumps(timeline), encoding="utf-8"
        )
        fake = directory / "multica"
        fake.write_text(
            FAKE_MULTICA.format(python=sys.executable, fixtures=str(directory)),
            encoding="utf-8",
        )
        fake.chmod(0o755)
        return fake

    def test_cli_arguments_and_stream_separation(self):
        issue = make_issue(1, "Ultimate rebuild", labels=[PRODUCT_LABEL])
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            fake = self._fake_multica(
                directory, paginate([issue])[0], done_at("2026-09-01T09:00:00Z")
            )
            snapshot = collect(pwr.MulticaReader(executable=str(fake)))
            recorded = [
                json.loads(line)
                for line in (directory / "argv.log").read_text(
                    encoding="utf-8"
                ).splitlines()
            ]
        self.assertEqual(
            [record["completed_at"] for record in snapshot["records"]],
            ["2026-09-01T09:00:00Z"],
        )
        self.assertEqual(recorded[0][:2], ["issue", "list"])
        self.assertEqual(recorded[0][recorded[0].index("--limit") + 1], "100")
        self.assertEqual(recorded[0][recorded[0].index("--output") + 1], "json")
        self.assertEqual(recorded[1][:3], ["issue", "timeline", "issue-1"])
        self.assertEqual(
            recorded[1][recorded[1].index("--action") + 1], "status_changed"
        )

    def test_a_failing_cli_call_refuses_the_report(self):
        with tempfile.TemporaryDirectory() as name:
            fake = Path(name) / "multica"
            fake.write_text(
                "#!{}\nimport sys\nsys.stderr.write('boom\\n')\n"
                "raise SystemExit(1)\n".format(sys.executable),
                encoding="utf-8",
            )
            fake.chmod(0o755)
            reader = pwr.MulticaReader(executable=str(fake))
            with self.assertRaises(pwr.ReportError) as raised:
                pwr.page_done_issues(reader, pwr.LIVE_PROJECT_ID)
        self.assertIn("boom", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
