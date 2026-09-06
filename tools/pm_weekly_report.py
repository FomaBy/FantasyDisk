#!/usr/bin/env python3
"""FAN-3903: weekly PM report on the share of player-visible completions.

The report answers one question for a fixed week: of everything the board
finished, how much was work a player can see (gameplay, playable content, art,
player-facing UI) and how much was pipeline work. The inclusion rule itself is
PM-owned and lives in ``docs/process/pm_weekly_product_behavior_report.md``;
this tool only counts what PM already classified with the workspace label.

Contract:

- The interval is start-inclusive and end-exclusive: ``[--since, --until)``.
- Multica is read only through the ``multica`` CLI, and only through the
  read-only commands in :data:`READ_ONLY_COMMANDS`. The tool never writes to
  the board it measures and never reopens a terminal card.
- A completion is a card sitting in ``done``, dated by its latest authoritative
  ``status_changed`` transition into ``done``, never by ``updated_at``. A card
  that re-entered ``done`` after a reopen counts once, at its latest entry; a
  card reopened after the window is not a completion of that window.
- Any truncated or ambiguous read — a short page, a moving page total, a
  duplicate id, a server-capped timeline, a ``done`` card with no recorded
  transition into ``done`` — refuses the whole report instead of publishing a
  number nobody can reproduce.
- ``--snapshot-out`` writes the timestamped immutable inputs, and
  ``--from-snapshot`` recomputes the published numbers from them, so
  independent QA reproduces a report after the live board has moved on.

Usage::

    python3 tools/pm_weekly_report.py \\
        --since 2026-08-30T22:00:00Z --until 2026-09-06T22:00:00Z \\
        --snapshot-out build/FAN-3903/week-2026-08-31.json

    python3 tools/pm_weekly_report.py \\
        --from-snapshot build/FAN-3903/week-2026-08-31.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# The live FantasyDisk project. The read-only Jira Archive is a different
# project and is never part of a weekly delivery metric.
LIVE_PROJECT_ID = "2ac963eb-b644-4540-8042-a1a4508f1a65"

PRODUCT_BEHAVIOR_LABEL = "product-behavior"
DONE_STATUS = "done"

# The server caps a page at 100; asking for more silently returns 100.
PAGE_LIMIT = 100

SNAPSHOT_FORMAT = "fan3903-pm-weekly-report/v1"

# Legacy proxy only: some titles carry a standalone `REWORK` marker from the
# pre-label era. It is a title convention, not the same-card rework history,
# and the report must never present it as "all rework" (see the process doc).
REWORK_TOKEN = "rework"
# A token is a run of letters and digits; underscores and punctuation separate
# it. That is what makes `REWORK:` and `pre-rework` match while `reworked` and
# `REWORKS` do not.
TOKEN_RE = re.compile(r"[^\W_]+")

RFC3339_RE = re.compile(
    r"^(\d{4})-(\d{2})-(\d{2})[Tt]"
    r"(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?"
    r"([Zz]|[+-]\d{2}:\d{2})$"
)

# Read-only Multica commands this tool is allowed to run. Anything else is a
# write path and is refused before the process starts.
READ_ONLY_COMMANDS = (
    ("issue", "list"),
    ("issue", "timeline"),
)

# The CLI prints this on stderr when the server capped a timeline read. Older
# entries are missing, so "latest transition into done" cannot be concluded.
TIMELINE_TRUNCATED_MARKER = "timeline truncated"


class ReportError(RuntimeError):
    """A refusal: the inputs cannot support a reproducible number."""


class PartialWindow(ReportError):
    """The collected inputs do not cover the whole requested window."""


# --------------------------------------------------------------------------
# Time
# --------------------------------------------------------------------------


def parse_rfc3339(value: object, field: str = "timestamp") -> datetime:
    """Parse an RFC3339 instant with an explicit offset, normalised to UTC.

    An offset is mandatory: a bare local timestamp would silently shift the
    week boundaries by the reader's timezone.
    """
    if not isinstance(value, str):
        raise ReportError(f"{field}: expected an RFC3339 string, got {value!r}")
    match = RFC3339_RE.match(value.strip())
    if not match:
        raise ReportError(
            f"{field}: {value!r} is not RFC3339 with an explicit offset "
            "(for example 2026-08-30T22:00:00Z or 2026-08-31T00:00:00+02:00)"
        )
    year, month, day, hour, minute, second, fraction, offset = match.groups()
    microsecond = int(fraction.ljust(6, "0")[:6]) if fraction else 0
    try:
        if offset in ("Z", "z"):
            tzinfo = timezone.utc
        else:
            sign = 1 if offset[0] == "+" else -1
            tzinfo = timezone(
                sign * timedelta(hours=int(offset[1:3]), minutes=int(offset[4:6]))
            )
        moment = datetime(
            int(year), int(month), int(day),
            int(hour), int(minute), int(second), microsecond,
            tzinfo,
        )
    except ValueError as error:
        raise ReportError(f"{field}: {value!r} is not a valid instant: {error}")
    return moment.astimezone(timezone.utc)


def format_rfc3339(moment: datetime) -> str:
    """Render a UTC instant, keeping sub-second precision only when present."""
    moment = moment.astimezone(timezone.utc)
    if moment.microsecond:
        return moment.strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------------------
# Multica access
# --------------------------------------------------------------------------


class MulticaReader:
    """Read-only Multica CLI access.

    Every call is checked against :data:`READ_ONLY_COMMANDS`, so no code path
    in this tool can mutate the board it measures. stdout and stderr stay
    separate: the CLI prints warnings (including the timeline truncation
    warning) on stderr, and merging them would corrupt the JSON.
    """

    def __init__(self, executable: str = "multica") -> None:
        self.executable = executable

    def json(self, *args: str):
        if tuple(args[:2]) not in READ_ONLY_COMMANDS:
            raise ReportError(
                "refusing a Multica command outside the read-only allowlist: "
                + " ".join(args)
            )
        proc = subprocess.run(
            [self.executable, *args, "--output", "json"],
            text=True,
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            raise ReportError("multica {} failed: {}".format(" ".join(args), detail))
        try:
            payload = json.loads(proc.stdout)
        except json.JSONDecodeError as error:
            raise ReportError(
                "multica {} returned unparseable JSON: {}".format(
                    " ".join(args), error
                )
            )
        return payload, proc.stderr


def page_done_issues(reader: MulticaReader, project_id: str) -> list:
    """Page every ``done`` issue of the project, refusing an unsafe snapshot.

    A weekly count is only worth publishing if the underlying read was
    complete, so a short page, a page total that moves under us, a duplicate
    id or a final count that disagrees with the server all refuse.
    """
    issues: list = []
    seen = set()
    offset = 0
    total = None
    while True:
        payload, _ = reader.json(
            "issue", "list",
            "--project", project_id,
            "--status", DONE_STATUS,
            "--sort", "created_at", "--direction", "asc",
            "--limit", str(PAGE_LIMIT), "--offset", str(offset),
        )
        if not isinstance(payload, dict) or "issues" not in payload:
            raise ReportError(
                f"issue list at offset {offset} returned an unexpected payload"
            )
        batch = payload.get("issues") or []
        page_total = payload.get("total")
        if not isinstance(page_total, int):
            raise ReportError(
                f"issue list at offset {offset} reported no usable total"
            )
        if total is None:
            total = page_total
        elif page_total != total:
            raise ReportError(
                f"the board changed while paging ({total} -> {page_total} "
                f"issues at offset {offset}); re-run the report"
            )
        if len(batch) > PAGE_LIMIT:
            raise ReportError(
                f"issue list at offset {offset} returned {len(batch)} issues "
                f"for a limit of {PAGE_LIMIT}"
            )
        has_more = bool(payload.get("has_more"))
        if has_more and len(batch) < PAGE_LIMIT:
            raise ReportError(
                f"incomplete page at offset {offset}: {len(batch)} of "
                f"{PAGE_LIMIT} issues with more pages pending; refusing a "
                "truncated snapshot"
            )
        for issue in batch:
            issue_id = issue.get("id")
            if not issue_id:
                raise ReportError(f"issue without an id at offset {offset}")
            if issue_id in seen:
                raise ReportError(
                    f"duplicate issue {issue.get('identifier', issue_id)} "
                    "while paging; refusing an ambiguous snapshot"
                )
            seen.add(issue_id)
            issues.append(issue)
        offset += len(batch)
        if not has_more:
            break
    if len(issues) != total:
        raise ReportError(
            f"collected {len(issues)} issues but the server reported {total}; "
            "refusing an incomplete snapshot"
        )
    return issues


def latest_done_transition(reader: MulticaReader, issue: dict) -> datetime:
    """The instant of the latest ``status_changed`` transition into ``done``.

    A card that was reopened and finished again counts at its latest entry,
    which is why the whole transition history is read rather than the first
    match. ``updated_at`` is never a completion time: a comment, a label or a
    metadata write moves it without finishing anything.
    """
    card = issue.get("identifier") or issue.get("id")
    payload, stderr = reader.json(
        "issue", "timeline", issue["id"], "--action", "status_changed",
    )
    if TIMELINE_TRUNCATED_MARKER in (stderr or "").lower():
        raise ReportError(
            f"{card}: the server capped the timeline read, so the latest "
            "transition into done cannot be concluded; refusing a truncated "
            "snapshot"
        )
    if not isinstance(payload, list):
        raise ReportError(f"{card}: timeline returned an unexpected payload")
    latest = None
    for entry in payload:
        if not isinstance(entry, dict):
            raise ReportError(f"{card}: timeline returned an unexpected entry")
        if entry.get("action") != "status_changed":
            continue
        details = entry.get("details") or {}
        if details.get("to") != DONE_STATUS:
            continue
        moment = parse_rfc3339(entry.get("created_at"), f"{card} timeline entry")
        if latest is None or moment > latest:
            latest = moment
    if latest is None:
        raise ReportError(
            f"{card}: no recorded status_changed transition into done; "
            "the completion cannot be dated from the authoritative history"
        )
    return latest


# --------------------------------------------------------------------------
# Collection
# --------------------------------------------------------------------------


def population_digest(issues: list) -> str:
    """A digest binding a snapshot to the ``done`` population it was read from.

    QA cannot re-read a past board, so the digest is an integrity marker for
    the collecting run, not a reproduction input.
    """
    lines = sorted(
        "{}\t{}".format(issue.get("id", ""), issue.get("updated_at", ""))
        for issue in issues
    )
    payload = "\n".join(lines).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def collect(
    reader: MulticaReader,
    project_id: str,
    since: datetime,
    until: datetime,
    label: str,
    since_input: str,
    until_input: str,
    collected_at: datetime,
) -> dict:
    """Read the board and build the immutable snapshot for a window."""
    issues = page_done_issues(reader, project_id)
    scanned = []
    skipped = 0
    for issue in issues:
        identifier = issue.get("identifier") or issue.get("id")
        updated_at = parse_rfc3339(issue.get("updated_at"), f"{identifier} updated_at")
        created_at = parse_rfc3339(issue.get("created_at"), f"{identifier} created_at")
        # Conservative bounds on which timelines can matter, never a date for
        # a completion: every mutation moves `updated_at` forward, so a card
        # last touched before the window cannot have entered `done` inside it,
        # and a card created at or after the window end cannot have finished
        # before it. Everything that survives is dated from its timeline.
        if updated_at < since or created_at >= until:
            skipped += 1
            continue
        completed_at = latest_done_transition(reader, issue)
        scanned.append({
            "id": issue["id"],
            "identifier": issue.get("identifier") or issue["id"],
            "title": issue.get("title") or "",
            "labels": sorted(
                name
                for name in (
                    entry.get("name", "") for entry in (issue.get("labels") or [])
                )
                if name
            ),
            "completed_at": format_rfc3339(completed_at),
        })
    scanned.sort(key=lambda record: (record["completed_at"], record["identifier"]))
    return {
        "format": SNAPSHOT_FORMAT,
        "collected_at": format_rfc3339(collected_at),
        "project_id": project_id,
        "label": label,
        "window": {
            "since": format_rfc3339(since),
            "until": format_rfc3339(until),
            "since_requested": since_input,
            "until_requested": until_input,
        },
        "population": {
            "done_total": len(issues),
            "scanned": len(scanned),
            "skipped_outside_window_bounds": skipped,
        },
        "population_digest": population_digest(issues),
        "records": scanned,
    }


def load_snapshot(path: Path) -> dict:
    try:
        snapshot = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ReportError(f"cannot read snapshot {path}: {error}")
    except json.JSONDecodeError as error:
        raise ReportError(f"snapshot {path} is not valid JSON: {error}")
    if not isinstance(snapshot, dict):
        raise ReportError(f"snapshot {path} is not a snapshot object")
    if snapshot.get("format") != SNAPSHOT_FORMAT:
        raise ReportError(
            f"snapshot {path} has format {snapshot.get('format')!r}, "
            f"expected {SNAPSHOT_FORMAT!r}"
        )
    for key in ("collected_at", "window", "label", "records"):
        if key not in snapshot:
            raise ReportError(f"snapshot {path} is missing {key!r}")
    return snapshot


def write_snapshot(path: Path, snapshot: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------


def has_rework_token(title: str) -> bool:
    """Whether a title carries the standalone legacy ``REWORK`` token."""
    return any(token.lower() == REWORK_TOKEN for token in TOKEN_RE.findall(title or ""))


def percentage(part: int, whole: int) -> float:
    """Share of *whole*, with an empty week reported as 0.0 rather than NaN."""
    if whole <= 0:
        return 0.0
    return round(100.0 * part / whole, 1)


def summarize(snapshot: dict) -> dict:
    """Derive the published numbers from a snapshot, without touching Multica."""
    window = snapshot.get("window") or {}
    since = parse_rfc3339(window.get("since"), "snapshot window.since")
    until = parse_rfc3339(window.get("until"), "snapshot window.until")
    if until <= since:
        raise ReportError("snapshot window is empty: until must be after since")
    label = snapshot["label"]
    collected_at = parse_rfc3339(snapshot.get("collected_at"), "snapshot collected_at")

    completions = []
    for record in snapshot.get("records") or []:
        completed_at = parse_rfc3339(
            record.get("completed_at"),
            "{} completed_at".format(record.get("identifier", "?")),
        )
        if since <= completed_at < until:
            completions.append({
                "id": record.get("id", ""),
                "identifier": record.get("identifier", ""),
                "title": record.get("title", ""),
                "completed_at": format_rfc3339(completed_at),
                "product_behavior": label in (record.get("labels") or []),
                "rework_title_token": has_rework_token(record.get("title", "")),
            })
    completions.sort(key=lambda item: (item["completed_at"], item["identifier"]))

    total = len(completions)
    product = sum(1 for item in completions if item["product_behavior"])
    rework = sum(1 for item in completions if item["rework_title_token"])
    return {
        "window": {"since": format_rfc3339(since), "until": format_rfc3339(until)},
        "window_requested": {
            "since": window.get("since_requested", window.get("since")),
            "until": window.get("until_requested", window.get("until")),
        },
        "collected_at": format_rfc3339(collected_at),
        "complete_interval": collected_at >= until,
        "project_id": snapshot.get("project_id", ""),
        "label": label,
        "population_digest": snapshot.get("population_digest", ""),
        "counts": {
            "completions": total,
            "product_behavior": product,
            "legacy_rework_title_token": rework,
        },
        "percentages": {
            "product_behavior": percentage(product, total),
            "legacy_rework_title_token": percentage(rework, total),
        },
        "completions": completions,
    }


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------


def _cell(text: str) -> str:
    """Make a title safe for a Markdown table cell."""
    return text.replace("|", r"\|").replace("\n", " ").replace("\r", " ").strip()


def render_markdown(summary: dict) -> str:
    counts = summary["counts"]
    shares = summary["percentages"]
    total = counts["completions"]
    interval = (
        "complete" if summary["complete_interval"] else "PARTIAL — not a full week"
    )
    lines = [
        "## PM weekly product-behavior report",
        "",
        "- Window: `{}` … `{}` (start inclusive, end exclusive)".format(
            summary["window"]["since"], summary["window"]["until"]
        ),
        "- Requested as: `{}` … `{}`".format(
            summary["window_requested"]["since"], summary["window_requested"]["until"]
        ),
        "- Collected: `{}`".format(summary["collected_at"]),
        "- Interval: {}".format(interval),
        "- Project: `{}`, label: `{}`".format(summary["project_id"], summary["label"]),
        "- Input digest: `{}`".format(summary["population_digest"]),
        "",
        "| Metric | Count | Share of completions |",
        "| --- | ---: | ---: |",
        "| Completions in window | {} | {:.1f}% |".format(
            total, percentage(total, total)
        ),
        "| `{}` completions | {} | {:.1f}% |".format(
            summary["label"], counts["product_behavior"], shares["product_behavior"]
        ),
        "| Legacy `REWORK` title-token proxy | {} | {:.1f}% |".format(
            counts["legacy_rework_title_token"],
            shares["legacy_rework_title_token"],
        ),
        "",
        "The `REWORK` line is a legacy title-token proxy: it counts completions "
        "whose title carries the standalone token `REWORK`. It is not the "
        "same-card rework history — a card reworked after a failed review "
        "without that token in its title is not counted here, and this number "
        "must never be published as \"all rework\".",
        "",
        "### Completions (source IDs)",
        "",
    ]
    if not summary["completions"]:
        lines.append("No completions in this window.")
    else:
        lines.append(
            "| Issue | ID | Completed (UTC) | `{}` | `REWORK` token | Title |"
            .format(summary["label"])
        )
        lines.append("| --- | --- | --- | :---: | :---: | --- |")
        for item in summary["completions"]:
            lines.append("| {} | `{}` | {} | {} | {} | {} |".format(
                item["identifier"],
                item["id"],
                item["completed_at"],
                "yes" if item["product_behavior"] else "no",
                "yes" if item["rework_title_token"] else "no",
                _cell(item["title"]),
            ))
    lines.append("")
    return "\n".join(lines)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Weekly PM report on the share of player-visible completions. "
            "The interval is start-inclusive and end-exclusive."
        ),
    )
    parser.add_argument("--since", help="window start, RFC3339 with an explicit offset")
    parser.add_argument("--until", help="window end, RFC3339 with an explicit offset")
    parser.add_argument(
        "--from-snapshot",
        help="recompute the report from a saved snapshot instead of the board",
    )
    parser.add_argument(
        "--snapshot-out",
        help="write the immutable inputs of this run to this path",
    )
    parser.add_argument(
        "--project", default=None,
        help=f"Multica project id (default: {LIVE_PROJECT_ID})",
    )
    parser.add_argument(
        "--label", default=None,
        help=f"PM-owned classification label (default: {PRODUCT_BEHAVIOR_LABEL})",
    )
    parser.add_argument(
        "--allow-partial",
        action="store_true",
        help="emit a report whose window had not ended when it was collected",
    )
    parser.add_argument(
        "--format", choices=("markdown", "json"), default="markdown",
        help="output format (default: %(default)s)",
    )
    return parser


def run(argv: list, reader=None, now=None) -> int:
    args = build_parser().parse_args(argv)
    reader = reader or MulticaReader()
    collected_at = now or datetime.now(timezone.utc)

    if args.from_snapshot:
        snapshot = load_snapshot(Path(args.from_snapshot))
        window = snapshot.get("window") or {}
        # Anything passed alongside a snapshot is a claim about that snapshot,
        # so a mismatch is a refusal rather than a silent re-scope.
        for name, value in (("since", args.since), ("until", args.until)):
            if value is None:
                continue
            if parse_rfc3339(value, f"--{name}") != parse_rfc3339(
                window.get(name), f"snapshot window.{name}"
            ):
                raise ReportError(
                    f"--{name} {value!r} does not match the snapshot window "
                    f"{window.get(name)!r}"
                )
        for name, value in (("project", args.project), ("label", args.label)):
            recorded = snapshot.get("project_id" if name == "project" else "label")
            if value is not None and value != recorded:
                raise ReportError(
                    f"--{name} {value!r} does not match the snapshot's {recorded!r}"
                )
        if args.snapshot_out:
            raise ReportError("--snapshot-out is meaningless with --from-snapshot")
    else:
        if not args.since or not args.until:
            raise ReportError(
                "--since and --until are required without --from-snapshot"
            )
        since = parse_rfc3339(args.since, "--since")
        until = parse_rfc3339(args.until, "--until")
        if until <= since:
            raise ReportError("--until must be after --since")
        snapshot = collect(
            reader,
            args.project or LIVE_PROJECT_ID,
            since,
            until,
            args.label or PRODUCT_BEHAVIOR_LABEL,
            args.since,
            args.until,
            collected_at,
        )
        if args.snapshot_out:
            write_snapshot(Path(args.snapshot_out), snapshot)

    summary = summarize(snapshot)
    if not summary["complete_interval"] and not args.allow_partial:
        raise PartialWindow(
            "the window had not ended when these inputs were collected "
            "({} < {}); this is a partial report and does not satisfy the "
            "complete-week criterion. Re-run after the window ends, or pass "
            "--allow-partial and publish it as explicitly partial.".format(
                summary["collected_at"], summary["window"]["until"]
            )
        )
    if args.format == "json":
        print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(render_markdown(summary))
    return 0


def main(argv=None, reader=None, now=None) -> int:
    try:
        return run(
            list(sys.argv[1:] if argv is None else argv), reader=reader, now=now
        )
    except PartialWindow as error:
        print(f"pm_weekly_report: partial window: {error}", file=sys.stderr)
        return 2
    except ReportError as error:
        print(f"pm_weekly_report: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
