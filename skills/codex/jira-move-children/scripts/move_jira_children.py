#!/usr/bin/env python3
"""Safely move all direct Jira child issues from one parent to another."""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass
class Credentials:
    base_url: str
    email: str
    token: str


class JiraError(Exception):
    def __init__(self, message: str, status: int | None = None, body: str | None = None):
        super().__init__(message)
        self.status = status
        self.body = body


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Move all direct Jira child issues from one parent issue to another."
    )
    parser.add_argument("--from", dest="source", required=True, help="Source Jira parent key")
    parser.add_argument("--to", dest="target", required=True, help="Target Jira parent key")
    parser.add_argument("--base-url", help="Jira Cloud base URL, e.g. https://example.atlassian.net")
    parser.add_argument("--email", help="Jira account email")
    parser.add_argument("--token", help="Jira API token")
    parser.add_argument(
        "--credential-file",
        default="APIToken.rtf",
        help="Optional local credential file to parse when env/flags are not provided",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually update Jira. Without this flag the script only validates and prints a plan.",
    )
    parser.add_argument("--max-results", type=int, default=100, help="Search page size")
    return parser.parse_args()


def read_credential_file(path: str) -> dict[str, str]:
    if not path or not os.path.exists(path):
        return {}

    text = ""
    if path.lower().endswith(".rtf"):
        try:
            text = subprocess.check_output(
                ["textutil", "-convert", "txt", "-stdout", path],
                text=True,
                stderr=subprocess.DEVNULL,
            )
        except (OSError, subprocess.CalledProcessError):
            with open(path, "r", encoding="utf-8", errors="ignore") as handle:
                text = handle.read()
    else:
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            text = handle.read()

    result: dict[str, str] = {}
    token_match = re.search(r"this is the token:\s*(\S+)", text, re.IGNORECASE)
    email_match = re.search(r"my account is\s*([^\s]+)", text, re.IGNORECASE)
    url_match = re.search(r"link to atlassian:\s*(https?://[^\s]+)", text, re.IGNORECASE)

    if token_match:
        result["token"] = token_match.group(1).strip()
    if email_match:
        result["email"] = email_match.group(1).strip()
    if url_match:
        result["base_url"] = url_match.group(1).strip()
    return result


def load_credentials(args: argparse.Namespace) -> Credentials:
    file_values = read_credential_file(args.credential_file)
    base_url = args.base_url or os.getenv("JIRA_BASE_URL") or file_values.get("base_url")
    email = args.email or os.getenv("JIRA_EMAIL") or file_values.get("email")
    token = args.token or os.getenv("JIRA_API_TOKEN") or file_values.get("token")

    missing = [
        name
        for name, value in (
            ("Jira base URL", base_url),
            ("Jira email", email),
            ("Jira API token", token),
        )
        if not value
    ]
    if missing:
        raise JiraError(
            "Missing credentials: "
            + ", ".join(missing)
            + ". Provide flags, environment variables, or --credential-file."
        )

    return Credentials(base_url=base_url.rstrip("/"), email=email, token=token)


def request_json(
    creds: Credentials,
    method: str,
    path: str,
    query: dict[str, str] | None = None,
    payload: dict[str, Any] | None = None,
) -> Any:
    url = creds.base_url + path
    if query:
        url += "?" + urllib.parse.urlencode(query)

    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    auth = base64.b64encode(f"{creds.email}:{creds.token}".encode("utf-8")).decode("ascii")
    headers["Authorization"] = f"Basic {auth}"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
            if not body:
                return None
            return json.loads(body)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise JiraError(summarize_error(body), status=error.code, body=body) from error
    except urllib.error.URLError as error:
        raise JiraError(f"Cannot reach Jira: {error.reason}") from error


def summarize_error(body: str) -> str:
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError:
        return body[:500] or "Jira returned an empty error response"

    messages = parsed.get("errorMessages") or []
    errors = parsed.get("errors") or {}
    parts = [str(message) for message in messages]
    parts.extend(f"{field}: {message}" for field, message in errors.items())
    return "; ".join(parts) or json.dumps(parsed)[:500]


def get_issue(creds: Credentials, key: str) -> dict[str, Any]:
    return request_json(
        creds,
        "GET",
        f"/rest/api/3/issue/{urllib.parse.quote(key)}",
        {"fields": "key,summary,issuetype,status,parent"},
    )


def search_children(creds: Credentials, source: str, max_results: int) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    next_page_token: str | None = None

    while True:
        query = {
            "jql": f"parent = {source} ORDER BY key",
            "fields": "key,summary,issuetype,status,parent",
            "maxResults": str(max_results),
        }
        if next_page_token:
            query["nextPageToken"] = next_page_token
        page = request_json(creds, "GET", "/rest/api/3/search/jql", query)
        issues.extend(page.get("issues", []))
        if page.get("isLast", True):
            return issues
        next_page_token = page.get("nextPageToken")
        if not next_page_token:
            return issues


def validate_update_permission(creds: Credentials, child_key: str, target: str) -> None:
    request_json(
        creds,
        "PUT",
        f"/rest/api/3/issue/{urllib.parse.quote(child_key)}",
        {"validateOnly": "true"},
        {"fields": {"parent": {"key": target}}},
    )


def update_parent(creds: Credentials, child_key: str, target: str) -> None:
    request_json(
        creds,
        "PUT",
        f"/rest/api/3/issue/{urllib.parse.quote(child_key)}",
        None,
        {"fields": {"parent": {"key": target}}},
    )


def print_issue(prefix: str, issue: dict[str, Any]) -> None:
    fields = issue["fields"]
    print(
        f"{prefix} {issue['key']} | {fields['issuetype']['name']} | "
        f"{fields['status']['name']} | {fields['summary']}"
    )


def main() -> int:
    args = parse_args()
    source = args.source.upper()
    target = args.target.upper()

    try:
        creds = load_credentials(args)
        source_issue = get_issue(creds, source)
        target_issue = get_issue(creds, target)
        children = search_children(creds, source, args.max_results)

        print("Jira child move plan")
        print(f"Source: {source_issue['key']} | {source_issue['fields']['issuetype']['name']} | {source_issue['fields']['summary']}")
        print(f"Target: {target_issue['key']} | {target_issue['fields']['issuetype']['name']} | {target_issue['fields']['summary']}")
        print(f"Children found: {len(children)}")
        for child in children:
            print_issue("-", child)

        if not children:
            print("Nothing to move.")
            return 0

        validate_update_permission(creds, children[0]["key"], target)
        print(f"Permission check: OK to update parent on {children[0]['key']} (validateOnly=true)")

        if not args.execute:
            print("Dry-run only. Re-run with --execute after user confirmation to perform the move.")
            return 0

        print("Executing move...")
        moved: list[str] = []
        for child in children:
            update_parent(creds, child["key"], target)
            moved.append(child["key"])
            print(f"Moved {child['key']} -> {target}")

        remaining = search_children(creds, source, args.max_results)
        print(f"Verification: {len(remaining)} direct children remain under {source}.")
        print("Moved keys: " + ", ".join(moved))
        return 0
    except JiraError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        if error.status in {401, 403}:
            print(
                "Access help: verify Jira API credentials, Browse Projects, and Edit Issues permissions.",
                file=sys.stderr,
            )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
