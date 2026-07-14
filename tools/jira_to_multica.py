#!/usr/bin/env python3
"""Idempotently migrate completed Jira issues to Multica.

Dry-run is the default. Apply mode requires an authenticated `multica` CLI.
Imported issues are created unassigned and already `done`, so the migration never
dispatches an AI agent merely by copying historical work.
"""
from __future__ import annotations

import argparse
import base64
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_JIRA_URL = "https://fantasydisk.atlassian.net"
DEFAULT_JIRA_EMAIL = "fomamoney@gmail.com"
JIRA_ARCHIVE_PROJECT_ID = "a2cb75b5-d6c9-451c-8a29-4d267f09d67d"
METADATA_WORKERS = 4


def jira_request(path: str) -> dict:
    token = os.getenv("JIRA_API_TOKEN", "").strip()
    if not token:
        raise RuntimeError("JIRA_API_TOKEN is required")
    site = os.getenv("JIRA_BASE_URL", DEFAULT_JIRA_URL).rstrip("/")
    email = os.getenv("JIRA_EMAIL", DEFAULT_JIRA_EMAIL)
    auth = base64.b64encode(f"{email}:{token}".encode()).decode()
    request = urllib.request.Request(site + path)
    request.add_header("Authorization", "Basic " + auth)
    request.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:1000]
        raise RuntimeError(f"Jira HTTP {error.code}: {detail}") from error


def adf_to_markdown(node) -> str:
    if node is None:
        return ""
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return "".join(adf_to_markdown(item) for item in node)
    if not isinstance(node, dict):
        return str(node)
    kind = node.get("type", "")
    text = node.get("text", "")
    if kind == "text":
        for mark in node.get("marks", []):
            mark_type = mark.get("type")
            if mark_type == "strong":
                text = f"**{text}**"
            elif mark_type == "em":
                text = f"*{text}*"
            elif mark_type == "code":
                text = f"`{text}`"
            elif mark_type == "link":
                text = f"[{text}]({mark.get('attrs', {}).get('href', '')})"
        return text
    children = node.get("content", [])
    body = "".join(adf_to_markdown(item) for item in children)
    if kind in {"doc"}:
        return body
    if kind in {"paragraph", "blockquote"}:
        prefix = "> " if kind == "blockquote" else ""
        return prefix + body.strip() + "\n\n"
    if kind == "heading":
        level = max(1, min(6, int(node.get("attrs", {}).get("level", 2))))
        return "#" * level + " " + body.strip() + "\n\n"
    if kind == "bulletList":
        return body + "\n"
    if kind == "orderedList":
        return body + "\n"
    if kind == "listItem":
        lines = body.strip().splitlines() or [""]
        return "- " + lines[0] + "\n" + "\n".join("  " + x for x in lines[1:]) + "\n"
    if kind == "codeBlock":
        language = node.get("attrs", {}).get("language", "")
        return f"```{language}\n{body.rstrip()}\n```\n\n"
    if kind == "hardBreak":
        return "  \n"
    if kind == "rule":
        return "---\n\n"
    if kind == "inlineCard":
        return node.get("attrs", {}).get("url", "")
    return body


def completed_issues(limit: int | None = None) -> list[dict]:
    fields = ",".join(
        [
            "summary", "description", "status", "issuetype", "priority",
            "labels", "created", "updated", "resolutiondate", "parent",
        ]
    )
    jql = "project = SCRUM AND statusCategory = Done ORDER BY key ASC"
    base = "/rest/api/3/search/jql?jql=" + urllib.parse.quote(jql)
    path = f"{base}&maxResults=100&fields={fields}"
    result: list[dict] = []
    while path and (limit is None or len(result) < limit):
        page = jira_request(path)
        result.extend(page.get("issues", []))
        token = page.get("nextPageToken")
        path = (
            f"{base}&maxResults=100&fields={fields}&nextPageToken="
            + urllib.parse.quote(token)
            if token
            else ""
        )
    return result[:limit] if limit else result


def jira_comments(issue_key: str) -> list[dict]:
    comments: list[dict] = []
    start = 0
    while True:
        page = jira_request(
            f"/rest/api/3/issue/{issue_key}/comment?startAt={start}&maxResults=100"
        )
        rows = page.get("comments", [])
        comments.extend(rows)
        start += len(rows)
        if not rows or start >= int(page.get("total", 0)):
            return comments


def run_multica(
    args: list[str],
    expect_json: bool = False,
    stdin_text: str | None = None,
):
    command = ["multica", *args]
    if expect_json:
        command += ["--output", "json"]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        input=stdin_text,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(command)}\n"
            + result.stderr.strip()[:2000]
        )
    if not expect_json:
        return result.stdout.strip()
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"Multica returned non-JSON output: {result.stdout[:1000]}") from error


def rows_from_json(value) -> list[dict]:
    if isinstance(value, list):
        return [row for row in value if isinstance(row, dict)]
    if isinstance(value, dict):
        for key in ("issues", "items", "data", "results"):
            if isinstance(value.get(key), list):
                return [row for row in value[key] if isinstance(row, dict)]
        return [value]
    return []


def issue_identity(value) -> str:
    for row in rows_from_json(value):
        for key in ("key", "identifier", "id"):
            candidate = row.get(key)
            if candidate:
                return str(candidate)
    raise RuntimeError(f"Cannot find issue identity in Multica response: {value}")


def find_existing(jira_key: str, project: str) -> str | None:
    if project != JIRA_ARCHIVE_PROJECT_ID:
        raise RuntimeError("archive lookup requires the pinned Jira Archive project")
    response = run_multica(
        [
            "issue",
            "list",
            "--project",
            project,
            "--metadata",
            f"jira_key={jira_key}",
            "--limit",
            "2",
        ],
        expect_json=True,
    )
    rows = rows_from_json(response)
    if len(rows) > 1:
        raise RuntimeError(
            f"duplicate archival jira_key {jira_key} in project {project}"
        )
    return issue_identity(rows[0]) if rows else None


def priority_name(field) -> str:
    name = ((field or {}).get("name") or "").lower()
    if "highest" in name or "urgent" in name:
        return "urgent"
    if "high" in name:
        return "high"
    if "low" in name:
        return "low"
    return "medium"


def imported_description(issue: dict) -> str:
    fields = issue["fields"]
    site = os.getenv("JIRA_BASE_URL", DEFAULT_JIRA_URL).rstrip("/")
    legacy = [
        "---",
        "Imported from Jira history. This issue is archival and must not dispatch an agent.",
        f"Jira: {site}/browse/{issue['key']}",
        f"Type: {fields['issuetype']['name']}",
        f"Created: {fields.get('created') or ''}",
        f"Resolved: {fields.get('resolutiondate') or ''}",
        f"Labels: {', '.join(fields.get('labels') or []) or 'none'}",
        "---",
        "",
    ]
    return "\n".join(legacy) + adf_to_markdown(fields.get("description")).strip()


def metadata_for(issue: dict) -> dict[str, str]:
    fields = issue["fields"]
    site = os.getenv("JIRA_BASE_URL", DEFAULT_JIRA_URL).rstrip("/")
    values = {
        "jira_key": issue["key"],
        "jira_url": f"{site}/browse/{issue['key']}",
        "jira_issue_type": fields["issuetype"]["name"],
        "jira_created": fields.get("created") or "",
        "jira_updated": fields.get("updated") or "",
        "jira_resolved": fields.get("resolutiondate") or "",
        "jira_labels": ",".join(fields.get("labels") or []),
        "historical_import": "true",
    }
    parent = (fields.get("parent") or {}).get("key")
    if parent:
        values["jira_parent_key"] = parent
    return values


def create_issue(issue: dict, project: str | None) -> str:
    fields = issue["fields"]
    command = [
        "issue", "create", "--title", fields["summary"],
        "--description-stdin",
        "--status", "done", "--priority", priority_name(fields.get("priority")),
    ]
    if project:
        command += ["--project", project]
    created = run_multica(
        command,
        expect_json=True,
        stdin_text=imported_description(issue),
    )
    identity = issue_identity(created)
    set_issue_metadata(issue, identity)
    return identity


def set_issue_metadata(issue: dict, identity: str) -> None:
    metadata = metadata_for(issue)
    # jira_key is the idempotency anchor used by find_existing(). Persist it
    # before any parallel work so an interruption can never duplicate the issue.
    run_multica(
        ["issue", "metadata", "set", identity, "--key", "jira_key", "--value", metadata.pop("jira_key"), "--type", "string"]
    )

    def set_metadata(item: tuple[str, str]) -> None:
        key, value = item
        run_multica(
            ["issue", "metadata", "set", identity, "--key", key, "--value", value, "--type", "string"]
        )

    # Remaining metadata fields are independent. A small bounded pool cuts the
    # 1,019-row migration wall time without turning the CLI into an API burst.
    with ThreadPoolExecutor(max_workers=METADATA_WORKERS) as executor:
        list(executor.map(set_metadata, metadata.items()))


def copy_comments(issue: dict, multica_id: str) -> int:
    count = 0
    for comment in jira_comments(issue["key"]):
        author = (comment.get("author") or {}).get("displayName") or "Unknown Jira user"
        created = comment.get("created") or "unknown time"
        body = adf_to_markdown(comment.get("body")).strip()
        content = f"[Imported Jira comment — {author}, {created}]\n\n{body}"
        run_multica(
            ["issue", "comment", "add", multica_id, "--content-stdin"],
            stdin_text=content,
        )
        count += 1
    return count


def load_state(path: Path) -> dict:
    if not path.exists():
        return {"migrated": {}, "failures": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Write to Multica; default is dry-run")
    parser.add_argument("--verify", action="store_true", help="Compare the complete Jira Done key set with a paginated Multica project audit")
    parser.add_argument("--repair", action="store_true", help="Recheck state rows and restore canonical metadata on existing issues (requires --apply)")
    parser.add_argument("--limit", type=int, help="Pilot/import at most N issues")
    parser.add_argument(
        "--project",
        help=f"Target Multica Jira Archive project ID ({JIRA_ARCHIVE_PROJECT_ID})",
    )
    parser.add_argument("--include-comments", action="store_true", help="Copy Jira comments as attributed archival comments")
    parser.add_argument("--state-file", type=Path, default=Path.home() / ".multica" / "fantasydisk-jira-migration-state.json")
    parser.add_argument("--report", type=Path, default=Path.home() / ".multica" / "fantasydisk-jira-migration-report.json")
    return parser.parse_args()


def verify_migration(args: argparse.Namespace, issues: list[dict], type_counts: dict[str, int]) -> int:
    if not args.project:
        raise RuntimeError("--verify requires --project with the Multica project ID")
    rows: list[dict] = []
    offset = 0
    page_size = 100  # Multica CLI/API caps issue list pages at 100 rows.
    while True:
        page = rows_from_json(
            run_multica(
                ["issue", "list", "--project", args.project, "--limit", str(page_size), "--offset", str(offset)],
                expect_json=True,
            )
        )
        rows.extend(page)
        if len(page) < page_size:
            break
        offset += len(page)

    source_keys = {issue["key"] for issue in issues}
    destination_keys = [str((row.get("metadata") or {}).get("jira_key", "")) for row in rows]
    key_counts = Counter(destination_keys)
    checks = {
        "missing_keys": sorted(source_keys - set(destination_keys)),
        "extra_keys": sorted(set(destination_keys) - source_keys),
        "duplicate_keys": sorted(key for key, count in key_counts.items() if key and count != 1),
        "without_jira_key": [row.get("identifier") for row in rows if not (row.get("metadata") or {}).get("jira_key")],
        "not_done": [row.get("identifier") for row in rows if row.get("status") != "done"],
        "assigned": [row.get("identifier") for row in rows if row.get("assignee_id") is not None or row.get("assignee_type") is not None],
        "not_archival": [
            row.get("identifier")
            for row in rows
            if str((row.get("metadata") or {}).get("historical_import")).lower() != "true"
        ],
        "missing_jira_url": [row.get("identifier") for row in rows if not (row.get("metadata") or {}).get("jira_url")],
    }
    failures = {name: values for name, values in checks.items() if values}
    destination_types = Counter((row.get("metadata") or {}).get("jira_issue_type") for row in rows)
    report = {
        "mode": "verify",
        "source": len(source_keys),
        "destination": len(rows),
        "types": type_counts,
        "destination_types": dict(destination_types),
        "failures": failures,
        "passed": not failures and len(rows) == len(source_keys) and dict(destination_types) == type_counts,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


def main() -> int:
    args = parse_args()
    if (args.apply or args.verify) and args.project != JIRA_ARCHIVE_PROJECT_ID:
        raise RuntimeError(
            "archive apply/verify requires --project " + JIRA_ARCHIVE_PROJECT_ID
        )
    if args.repair and not args.apply:
        raise RuntimeError("--repair requires --apply")
    issues = completed_issues(args.limit)
    type_counts: dict[str, int] = {}
    for issue in issues:
        name = issue["fields"]["issuetype"]["name"]
        type_counts[name] = type_counts.get(name, 0) + 1
    if args.verify:
        if not shutil_which("multica"):
            raise RuntimeError("multica CLI is not installed or not on PATH")
        run_multica(["auth", "status"])
        return verify_migration(args, issues, type_counts)
    if not args.apply:
        print(json.dumps({"mode": "dry-run", "issues": len(issues), "types": type_counts}, ensure_ascii=False, indent=2))
        return 0

    if not shutil_which("multica"):
        raise RuntimeError("multica CLI is not installed or not on PATH")
    run_multica(["auth", "status"])
    state = load_state(args.state_file)
    counters = {"source": len(issues), "created": 0, "existing": 0, "resumed": 0, "failed": 0, "comments": 0}
    for index, issue in enumerate(issues, 1):
        key = issue["key"]
        try:
            if key in state["migrated"] and not args.repair:
                counters["resumed"] += 1
                continue
            existing = find_existing(key, args.project)
            if existing:
                identity = existing
                set_issue_metadata(issue, identity)
                counters["existing"] += 1
            else:
                identity = create_issue(issue, args.project)
                counters["created"] += 1
            if args.include_comments:
                counters["comments"] += copy_comments(issue, identity)
            state["migrated"][key] = identity
            state["failures"].pop(key, None)
        except Exception as error:  # continue so one malformed historical issue cannot stop 1,019 rows
            counters["failed"] += 1
            state["failures"][key] = str(error)
            print(f"FAILED {key}: {error}", file=sys.stderr)
        save_state(args.state_file, state)
        print(f"[{index}/{len(issues)}] {key}", file=sys.stderr)
    report = {"counters": counters, "types": type_counts, "state_file": str(args.state_file), "failures": state["failures"]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if counters["failed"] else 0


def shutil_which(program: str) -> str | None:
    for directory in os.getenv("PATH", "").split(os.pathsep):
        candidate = Path(directory) / program
        for path in (candidate, candidate.with_suffix(".exe")):
            if path.is_file():
                return str(path)
    return None


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
