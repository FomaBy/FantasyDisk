#!/usr/bin/env python3
"""FAN-1135: remediation of the retrospective story-points backfill.

The 2026-07-15 backfill attached retrospective ``SP:<N>`` Labels and
``story_points``/``estimation_model`` metadata to closed live FantasyDisk
issues and to the whole read-only Jira Archive, violating the transition
rule in ``docs/process/story_points.md`` («Исторические done, cancelled и
Jira Archive массово не переоцениваются»).

Subcommands (all read-only except ``apply``):

- ``inventory`` — page every issue of the live FantasyDisk and Jira
  Archive projects into a rollback snapshot under ``build/FAN-1135/``.
- ``plan`` — classify closed live issues by estimate provenance and emit
  an idempotent mutation plan restricted to the live project.
- ``apply`` — execute the plan with per-issue re-verification; refuses
  any target outside the live project or outside ``done``/``cancelled``.
- ``audit`` — re-fetch both projects and verify post-change invariants,
  including that the Jira Archive was not modified at all.
- ``report`` — regenerate the closed story-points report with accepted
  pre-work estimates explicitly separated from non-canonical
  retrospective analytics.

The Jira Archive project is hard-guarded: no code path in this tool may
issue a mutating command against it. Every mutation re-fetches its target
and re-checks project, status and provenance before writing.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORKDIR = ROOT / "build" / "FAN-1135"

LIVE_PROJECT_ID = "2ac963eb-b644-4540-8042-a1a4508f1a65"
ARCHIVE_PROJECT_ID = "a2cb75b5-d6c9-451c-8a29-4d267f09d67d"
PROJECTS = {"live": LIVE_PROJECT_ID, "archive": ARCHIVE_PROJECT_ID}

CANONICAL_MODEL = "CUE Fibonacci 1,2,3,5,8,13"
RETROSPECTIVE_MARKER = "retrospective"
SP_LABEL_RE = re.compile(r"^SP:(1|2|3|5|8|13)$")
CLOSED_STATUSES = ("done", "cancelled")
REMOVABLE_METADATA_KEYS = ("story_points", "estimation_model")
# A canonical pre-work estimate is one full line `Story points: N` with N a
# Fibonacci point value and nothing else on the line (horizontal whitespace
# and a CRLF ending are tolerated). Anchoring the whole line is what rejects
# `5.0`, `5abc` and any other continuation: a numeric prefix of a malformed
# value must never parse as an estimate (FAN-1170).
DESCRIPTION_ESTIMATE_RE = re.compile(
    r"^[ \t]*Story points:[ \t]*(13|8|5|3|2|1)[ \t]*\r?$",
    re.IGNORECASE | re.MULTILINE,
)
# Every `Story points:` marker, canonical or not. Counting markers separately
# from canonical lines is what makes malformed/duplicate blocks fail closed
# even when one valid estimate line is also present (FAN-1170).
ESTIMATE_MARKER_RE = re.compile(r"Story points[ \t]*:", re.IGNORECASE)

PAGE_LIMIT = 100

# Classes whose Labels/metadata were written by the 2026-07-15 backfill and
# must be removed from closed live issues. ``conflicted`` issues additionally
# carry a pre-work `Story points:` block in the description, which the
# backfill overwrote with a different retrospective value; the description
# record is preserved untouched.
CLEANABLE_CLASSES = ("retrospective_backfill", "conflicted_needs_review")

# Provenance classes.
RETROSPECTIVE_BACKFILL = "retrospective_backfill"
ACCEPTED_PREWORK = "accepted_prework"
UNESTIMATED = "unestimated"
INCONSISTENT = "inconsistent_needs_review"
CONFLICTED = "conflicted_needs_review"
# A retrospective backfill that cannot be auto-cleaned because its SP-label
# provenance is ambiguous (zero or more than one removable SP Label). These
# issues are diverted to manual review and never mutated automatically.
AMBIGUOUS = "ambiguous_needs_review"


class RemediationError(RuntimeError):
    pass


def run_multica(args: list[str]) -> str:
    proc = subprocess.run(
        ["multica", *args], text=True, capture_output=True, check=False
    )
    if proc.returncode != 0:
        raise RemediationError(
            "multica {} failed: {}".format(
                " ".join(args), (proc.stderr or proc.stdout).strip()
            )
        )
    return proc.stdout


def multica_json(*args: str) -> object:
    return json.loads(run_multica([*args, "--output", "json"]))


def fetch_issues(project_id: str) -> list[dict]:
    issues: list[dict] = []
    offset = 0
    while True:
        page = multica_json(
            "issue", "list",
            "--project", project_id,
            "--sort", "created_at", "--direction", "asc",
            "--limit", str(PAGE_LIMIT), "--offset", str(offset),
        )
        batch = page["issues"]
        issues.extend(batch)
        offset += len(batch)
        if not page.get("has_more") or not batch:
            break
    ids = {issue["id"] for issue in issues}
    if len(ids) != len(issues):
        raise RemediationError(
            f"duplicate issues while paging project {project_id}"
        )
    for issue in issues:
        if issue["project_id"] != project_id:
            raise RemediationError(
                f"issue {issue['identifier']} outside requested project"
            )
    return issues


def sp_labels(issue: dict) -> list[dict]:
    return [
        label
        for label in (issue.get("labels") or [])
        if SP_LABEL_RE.match(label.get("name", ""))
    ]


def description_estimates(issue: dict) -> list[int]:
    """Values of every canonical full-line ``Story points: N`` estimate.

    Only a complete line whose whole value is one Fibonacci point counts.
    `Story points: 5.0`, `Story points: 5abc` and similar malformed values
    yield nothing here — the numeric prefix is not an estimate (FAN-1170).
    Compare against :func:`description_markers` to detect malformed blocks.
    """
    text = issue.get("description") or ""
    return [int(m.group(1)) for m in DESCRIPTION_ESTIMATE_RE.finditer(text)]


def description_markers(issue: dict) -> int:
    """Count of every ``Story points:`` marker, canonical or malformed.

    A marker that is not simultaneously a canonical estimate line is a
    malformed or extra estimate record; its presence must fail the issue
    closed even next to one valid line (FAN-1170).
    """
    text = issue.get("description") or ""
    return len(ESTIMATE_MARKER_RE.findall(text))


def canonical_sp_labels(issue: dict) -> list[dict]:
    """SP Labels on ``issue`` de-duplicated by label id.

    A raw issue payload can repeat the exact same label record; those are a
    single attachment and collapse to one entry. Two *distinct* label ids are
    kept separate even when they share a name, because two different label
    records both encoding a story-point value is precisely the ambiguous
    provenance this tool must refuse to auto-resolve.
    """
    unique: dict[str, dict] = {}
    for label in sp_labels(issue):
        unique.setdefault(label["id"], label)
    return list(unique.values())


def single_sp_label(issue: dict) -> dict | None:
    """Return the one removable SP Label, or ``None`` when ambiguous.

    Ambiguous means zero SP Labels or more than one distinct SP Label record.
    Automatic cleanup requires exactly one removable SP Label; any other count
    is diverted to manual review and never auto-mutated (fail-closed).
    """
    labels = canonical_sp_labels(issue)
    return labels[0] if len(labels) == 1 else None


def has_estimate_block(issue: dict) -> bool:
    """True when the description carries any ``Story points:`` marker.

    Malformed markers count: a broken pre-work record is still a record and
    must be preserved/reviewed, not treated as absent (FAN-1170).
    """
    return description_markers(issue) > 0


def label_points(label: dict) -> int:
    return int(label["name"].split(":")[1])


def metadata_points(meta: dict) -> int | None:
    """Numeric ``story_points`` metadata, or ``None`` when absent/non-numeric."""
    value = meta.get("story_points")
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    text = str(value).strip()
    return int(text) if text.isdigit() else None


def classify(issue: dict) -> str:
    meta = issue.get("metadata") or {}
    model = str(meta.get("estimation_model", ""))
    retrospective = RETROSPECTIVE_MARKER in model.lower()
    estimates = description_estimates(issue)
    markers = description_markers(issue)
    labels = sp_labels(issue)
    has_sp_data = bool(labels) or "story_points" in meta or bool(model)
    if retrospective:
        # Fail-closed: a retrospective backfill is only auto-cleanable when it
        # carries exactly one removable SP Label. Zero or multiple SP Labels is
        # ambiguous provenance — we cannot tell which estimate (if any) is
        # legitimate — so it goes to manual review, never silent mutation.
        if single_sp_label(issue) is None:
            return AMBIGUOUS
        return CONFLICTED if markers else RETROSPECTIVE_BACKFILL
    if not has_sp_data:
        return UNESTIMATED
    # Accepted only when the description carries exactly one `Story points:`
    # marker, that marker is the one full canonical estimate line, and its
    # value exactly matches the single canonical Label and the numeric
    # metadata. A missing, malformed, duplicated, or mismatched marker —
    # even next to one valid line — fails closed to
    # ``inconsistent_needs_review`` and stays out of the canonical report
    # (FAN-1166, FAN-1170).
    if (
        markers == 1
        and len(estimates) == 1
        and model == CANONICAL_MODEL
        and len(labels) == 1
        and label_points(labels[0]) == estimates[0]
        and metadata_points(meta) == estimates[0]
    ):
        return ACCEPTED_PREWORK
    return INCONSISTENT


def derive_actions(issue: dict) -> list[dict]:
    """Cleanup actions for one retrospectively backfilled closed live issue.

    Requires exactly one removable SP Label. An ambiguous issue (zero or
    multiple SP Labels) must be diverted to manual review before this is
    called; reaching here with ambiguous provenance is a fail-closed error,
    never a silent multi-label removal.
    """
    label = single_sp_label(issue)
    if label is None:
        raise RemediationError(
            "{}: ambiguous SP Labels {} — automatic cleanup requires exactly "
            "one removable SP Label; divert to manual review".format(
                issue.get("identifier", issue.get("id", "?")),
                sorted(existing["name"] for existing in sp_labels(issue)),
            )
        )
    actions: list[dict] = [
        {
            "op": "label_remove",
            "label_id": label["id"],
            "label_name": label["name"],
        }
    ]
    meta = issue.get("metadata") or {}
    for key in REMOVABLE_METADATA_KEYS:
        if key in meta:
            actions.append(
                {"op": "metadata_delete", "key": key, "old_value": meta[key]}
            )
    return actions


def build_plan(live_issues: list[dict]) -> list[dict]:
    plan: list[dict] = []
    for issue in sorted(live_issues, key=lambda i: i.get("number") or 0):
        if issue["project_id"] == ARCHIVE_PROJECT_ID:
            raise RemediationError(
                f"{issue['identifier']}: Jira Archive is read-only; "
                "it must never enter a mutation plan"
            )
        if issue["project_id"] != LIVE_PROJECT_ID:
            raise RemediationError(
                f"{issue['identifier']}: outside the live FantasyDisk project"
            )
        if issue["status"] not in CLOSED_STATUSES:
            continue
        cls = classify(issue)
        if cls not in CLEANABLE_CLASSES:
            continue
        actions = derive_actions(issue)
        if not actions:
            continue
        plan.append(
            {
                "issue_id": issue["id"],
                "identifier": issue["identifier"],
                "status": issue["status"],
                "classification": cls,
                "updated_at": issue["updated_at"],
                "actions": actions,
            }
        )
    return plan


def review_needed(live_issues: list[dict]) -> list[dict]:
    """Closed live issues whose ambiguous SP Labels block automatic cleanup."""
    flagged: list[dict] = []
    for issue in live_issues:
        if issue.get("project_id") != LIVE_PROJECT_ID:
            continue
        if issue["status"] not in CLOSED_STATUSES:
            continue
        if classify(issue) == AMBIGUOUS:
            flagged.append(issue)
    return flagged


def execute_action(issue: dict, action: dict, runner=run_multica) -> None:
    """Run one mutation. Fail-closed: only live-project closed issues."""
    if issue["project_id"] != LIVE_PROJECT_ID:
        raise RemediationError(
            f"{issue['identifier']}: refusing to mutate an issue outside "
            "the live FantasyDisk project (Jira Archive is read-only)"
        )
    if issue["status"] not in CLOSED_STATUSES:
        raise RemediationError(
            f"{issue['identifier']}: refusing to mutate a non-closed issue"
        )
    if action["op"] == "label_remove":
        if not SP_LABEL_RE.match(action["label_name"]):
            raise RemediationError(
                f"{issue['identifier']}: refusing to remove non-SP label "
                f"{action['label_name']}"
            )
        runner(
            ["issue", "label", "remove", issue["id"], action["label_id"],
             "--output", "json"]
        )
    elif action["op"] == "metadata_delete":
        if action["key"] not in REMOVABLE_METADATA_KEYS:
            raise RemediationError(
                f"{issue['identifier']}: refusing to delete metadata key "
                f"{action['key']}"
            )
        runner(
            ["issue", "metadata", "delete", issue["id"],
             "--key", action["key"], "--output", "json"]
        )
    else:
        raise RemediationError(f"unknown action op {action['op']}")


def apply_plan(plan: list[dict], limit: int | None, runner=run_multica,
               fetch=None) -> dict:
    # Fail-closed on a bad canary limit: reject non-positive values before any
    # fetch or mutation. A negative ``limit`` would otherwise become the slice
    # ``plan[:limit]`` (e.g. ``plan[:-1]``) and silently run a near-full apply
    # instead of the intended single-issue canary (FAN-1165).
    if limit is not None and limit <= 0:
        raise RemediationError(
            f"--limit must be a positive integer for a canary apply "
            f"(got {limit}); refusing to run before any fetch or mutation"
        )
    fetch = fetch or (lambda issue_id: multica_json("issue", "get", issue_id))
    log = {"applied": [], "skipped": [], "errors": []}
    targets = plan if limit is None else plan[:limit]
    for entry in targets:
        fresh = fetch(entry["issue_id"])
        if fresh["project_id"] != LIVE_PROJECT_ID:
            log["errors"].append(
                {"identifier": entry["identifier"],
                 "error": "outside live project at apply time"}
            )
            continue
        if fresh["status"] not in CLOSED_STATUSES:
            log["errors"].append(
                {"identifier": entry["identifier"],
                 "error": f"status changed to {fresh['status']} since plan"}
            )
            continue
        cls = classify(fresh)
        if cls == AMBIGUOUS:
            log["errors"].append(
                {"identifier": entry["identifier"],
                 "error": "ambiguous SP Labels at apply time — exactly one "
                          "removable SP Label required; refused, manual review"}
            )
            continue
        if cls not in CLEANABLE_CLASSES:
            log["skipped"].append(
                {"identifier": entry["identifier"],
                 "reason": "no retrospective backfill present (already clean)"}
            )
            continue
        actions = derive_actions(fresh)
        for action in actions:
            execute_action(fresh, action, runner=runner)
        log["applied"].append(
            {"identifier": entry["identifier"], "issue_id": entry["issue_id"],
             "actions": actions}
        )
    return log


def summarize(issues: list[dict]) -> dict:
    summary: dict = {
        "total": len(issues),
        "by_status": defaultdict(int),
        "closed": {
            "total": 0,
            "by_class": defaultdict(int),
        },
    }
    for issue in issues:
        summary["by_status"][issue["status"]] += 1
        if issue["status"] in CLOSED_STATUSES:
            summary["closed"]["total"] += 1
            summary["closed"]["by_class"][classify(issue)] += 1
    summary["by_status"] = dict(summary["by_status"])
    summary["closed"]["by_class"] = dict(summary["closed"]["by_class"])
    return summary


def completion_date(issue: dict) -> tuple[str, str]:
    """Return (YYYY-MM-DD, source) preserving the original close date."""
    meta = issue.get("metadata") or {}
    for key in ("completed_at", "jira_resolved"):
        value = str(meta.get(key, "")).strip()
        if value:
            return value[:10], key
    return str(issue.get("updated_at", ""))[:10], "updated_at_fallback"


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
        + "\n",
        encoding="utf-8",
    )


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def snapshot_index(issues: list[dict]) -> dict:
    return {issue["id"]: issue for issue in issues}


def issue_fingerprint(issue: dict) -> dict:
    """Fields that remediation must never change."""
    return {
        "status": issue["status"],
        "description": issue.get("description"),
        "assignee_id": issue.get("assignee_id"),
        "created_at": issue["created_at"],
        "completed": completion_date(issue),
    }


def cmd_inventory(args: argparse.Namespace) -> int:
    workdir = Path(args.workdir)
    for name, project_id in PROJECTS.items():
        issues = fetch_issues(project_id)
        write_json(workdir / f"inventory_{name}.json", issues)
        summary = summarize(issues)
        write_json(workdir / f"inventory_{name}_summary.json", summary)
        print(f"[{name}] {summary['total']} issues, "
              f"closed={summary['closed']['total']}, "
              f"by_class={summary['closed']['by_class']}")
    print(f"Inventory written to {workdir}")
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    workdir = Path(args.workdir)
    live = load_json(workdir / "inventory_live.json")
    plan = build_plan(live)
    write_json(workdir / "plan.json", plan)
    total_actions = sum(len(entry["actions"]) for entry in plan)
    print(f"Plan: {len(plan)} live closed issues to clean, "
          f"{total_actions} actions -> {workdir / 'plan.json'}")
    for entry in plan:
        ops = ", ".join(
            a["op"] + ":" + a.get("label_name", a.get("key", ""))
            for a in entry["actions"]
        )
        print(f"  {entry['identifier']} [{entry['status']}] {ops}")

    review = review_needed(live)
    if review:
        write_json(
            workdir / "needs_review.json",
            [
                {
                    "identifier": issue["identifier"],
                    "issue_id": issue["id"],
                    "status": issue["status"],
                    "sp_labels": sorted(
                        label["name"] for label in sp_labels(issue)
                    ),
                }
                for issue in review
            ],
        )
        print(f"MANUAL REVIEW REQUIRED: {len(review)} closed issue(s) with "
              "ambiguous SP Labels were NOT auto-cleaned -> "
              f"{workdir / 'needs_review.json'}")
        for issue in review:
            names = ", ".join(sorted(l["name"] for l in sp_labels(issue)))
            print(f"  {issue['identifier']} [{issue['status']}] "
                  f"SP Labels: {names or '(none)'}")
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    workdir = Path(args.workdir)
    plan = load_json(workdir / "plan.json")
    log = apply_plan(plan, args.limit)
    suffix = "canary" if args.limit is not None else "full"
    write_json(workdir / f"apply_log_{suffix}.json", log)
    print(f"Applied: {len(log['applied'])}, skipped: {len(log['skipped'])}, "
          f"errors: {len(log['errors'])}")
    for err in log["errors"]:
        print(f"  ERROR {err['identifier']}: {err['error']}")
    return 1 if log["errors"] else 0


def cmd_audit(args: argparse.Namespace) -> int:
    workdir = Path(args.workdir)
    failures: list[str] = []
    plan = load_json(workdir / "plan.json")
    planned_ids = {entry["issue_id"] for entry in plan}

    live_before = snapshot_index(load_json(workdir / "inventory_live.json"))
    live_now = fetch_issues(LIVE_PROJECT_ID)
    write_json(workdir / "audit_live.json", live_now)

    for issue in live_now:
        if issue["status"] not in CLOSED_STATUSES:
            continue
        cls = classify(issue)
        if cls in CLEANABLE_CLASSES:
            failures.append(
                f"live {issue['identifier']}: retrospective backfill still "
                f"present ({cls})"
            )
        before = live_before.get(issue["id"])
        if before is None or before["status"] not in CLOSED_STATUSES:
            # Closed after the inventory snapshot by another actor; not part
            # of the remediation scope.
            continue
        if issue_fingerprint(before) != issue_fingerprint(issue):
            failures.append(
                f"live {issue['identifier']}: status/description/assignee/"
                "dates changed during remediation"
            )
        if issue["id"] not in planned_ids:
            if classify(before) != classify(issue):
                failures.append(
                    f"live {issue['identifier']}: out-of-plan provenance "
                    f"change {classify(before)} -> {classify(issue)}"
                )

    archive_before = snapshot_index(load_json(workdir / "inventory_archive.json"))
    archive_now = fetch_issues(ARCHIVE_PROJECT_ID)
    write_json(workdir / "audit_archive.json", archive_now)
    if len(archive_now) != len(archive_before):
        failures.append(
            f"archive issue count changed: {len(archive_before)} -> "
            f"{len(archive_now)}"
        )
    for issue in archive_now:
        before = archive_before.get(issue["id"])
        if before is None:
            failures.append(f"archive {issue['identifier']}: new issue appeared")
            continue
        if issue["updated_at"] != before["updated_at"]:
            failures.append(
                f"archive {issue['identifier']}: updated_at changed — "
                "the read-only archive was touched"
            )

    summary = {
        "live": summarize(live_now),
        "archive": summarize(archive_now),
        "planned_issue_count": len(plan),
        "failures": failures,
    }
    write_json(workdir / "audit_summary.json", summary)
    print(json.dumps(summary["live"], ensure_ascii=False, indent=2))
    if failures:
        print("AUDIT FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print("AUDIT PASSED: no retrospective backfill on closed live issues, "
          "no side effects, Jira Archive untouched.")
    return 0


def build_report_rows(issues: list[dict], provenance: str) -> list[dict]:
    daily: dict[tuple[str, str], dict] = {}
    for issue in issues:
        date, source = completion_date(issue)
        meta = issue.get("metadata") or {}
        labels = sp_labels(issue)
        points = meta.get("story_points")
        if points is None and labels:
            points = int(labels[0]["name"].split(":")[1])
        if points is None:
            continue
        key = (date, provenance)
        row = daily.setdefault(
            key,
            {"date": date, "provenance": provenance, "issues": 0,
             "story_points": 0, "date_sources": set()},
        )
        row["issues"] += 1
        row["story_points"] += int(points)
        row["date_sources"].add(source)
    rows = []
    for _, row in sorted(daily.items()):
        row["date_sources"] = ",".join(sorted(row["date_sources"]))
        rows.append(row)
    return rows


def write_report_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["date", "provenance", "issues", "story_points",
                  "date_sources"]
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        total_issues = sum(r["issues"] for r in rows)
        total_points = sum(r["story_points"] for r in rows)
        for row in rows:
            writer.writerow(row)
        writer.writerow(
            {"date": "TOTAL", "provenance": rows[0]["provenance"] if rows else "",
             "issues": total_issues, "story_points": total_points,
             "date_sources": ""}
        )


def cmd_report(args: argparse.Namespace) -> int:
    workdir = Path(args.workdir)
    live_path = workdir / "audit_live.json"
    if not live_path.exists():
        live_path = workdir / "inventory_live.json"
    archive_path = workdir / "audit_archive.json"
    if not archive_path.exists():
        archive_path = workdir / "inventory_archive.json"
    live = load_json(live_path)
    archive = load_json(archive_path)

    accepted = [
        issue for issue in live
        if issue["status"] in CLOSED_STATUSES
        and classify(issue) == ACCEPTED_PREWORK
    ]
    retrospective_archive = [
        issue for issue in archive
        if issue["status"] in CLOSED_STATUSES
        and classify(issue) in CLEANABLE_CLASSES
    ]

    accepted_rows = build_report_rows(accepted, "accepted_prework")
    retro_rows = build_report_rows(
        retrospective_archive,
        "retrospective_non_canonical_jira_archive_read_only",
    )
    report_dir = workdir / "report"
    write_report_csv(
        report_dir / "closed_story_points_accepted.csv", accepted_rows
    )
    write_report_csv(
        report_dir / "jira_archive_retrospective_reference.csv", retro_rows
    )

    accepted_sp = sum(r["story_points"] for r in accepted_rows)
    retro_sp = sum(r["story_points"] for r in retro_rows)
    summary_md = "\n".join(
        [
            "# Closed story points — provenance-separated report",
            "",
            "## Accepted pre-work estimates (canonical, live FantasyDisk)",
            "",
            f"- issues: {len(accepted)}",
            f"- story points: {accepted_sp}",
            "- source: exactly-one canonical `SP:<N>` Label + matching",
            "  `story_points` metadata + `estimation_model="
            f"\"{CANONICAL_MODEL}\"` + `Story points:` block in description.",
            "",
            "## Retrospective analytics (NON-canonical, reference only)",
            "",
            f"- Jira Archive issues carrying `CUE retrospective v1` marks: "
            f"{len(retrospective_archive)}",
            f"- story points (non-canonical): {retro_sp}",
            "- The Jira Archive is read-only legacy history: these values were",
            "  written by the 2026-07-15 backfill, are not accepted pre-work",
            "  estimates, are excluded from live readiness/plan-vs-fact",
            "  reporting, and are kept here only as clearly-labelled",
            "  reference until Сергей Фомин explicitly authorizes or retires",
            "  retrospective analytics.",
            "",
            "Cleaned live issues (backfill removed, rollback snapshot in",
            "`inventory_live.json`): see `plan.json` / `apply_log_full.json`.",
            "",
        ]
    )
    (report_dir / "closed_story_points_summary.md").write_text(
        summary_md, encoding="utf-8"
    )
    print(f"Report written to {report_dir}")
    print(f"  accepted: {len(accepted)} issues / {accepted_sp} SP")
    print(f"  retrospective archive reference: "
          f"{len(retrospective_archive)} issues / {retro_sp} SP")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--workdir", default=str(DEFAULT_WORKDIR),
        help="artifact directory (default: build/FAN-1135)",
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("inventory", help="snapshot both projects (read-only)")
    sub.add_parser("plan", help="build the live-project mutation plan")
    apply_parser = sub.add_parser("apply", help="execute the plan")
    apply_parser.add_argument(
        "--limit", type=int, default=None,
        help="apply only the first N plan entries (canary)",
    )
    sub.add_parser("audit", help="verify post-change invariants (read-only)")
    sub.add_parser("report", help="regenerate provenance-separated report")
    args = parser.parse_args(argv)
    handlers = {
        "inventory": cmd_inventory,
        "plan": cmd_plan,
        "apply": cmd_apply,
        "audit": cmd_audit,
        "report": cmd_report,
    }
    try:
        return handlers[args.command](args)
    except RemediationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
