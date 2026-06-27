#!/usr/bin/env python3
"""Pull + (опционально) claim следующую подходящую задачу роли из активного спринта Jira.

Jira — единый источник задач (проект SCRUM). Агент-рутина вызывает этот тул, чтобы
взять СЕБЕ работу, а не читать локальную доску.

Usage:
    python3 tools/jira_next_task.py --role backend --lane claude          # показать следующую (read-only)
    python3 tools/jira_next_task.py --role backend --lane claude --claim --worker claude-backend
    python3 tools/jira_next_task.py --role design --lane codex --required-label designer2 --json
    python3 tools/jira_next_task.py --role qa --json

Логика выбора: активный спринт (board 1) → статус «К выполнению» → label роли →
label контура/lane, если задан → без метки `hold` → не взято в работу → старший
приоритет первым. Claim = перевод в «В работе» + комментарий (это и есть
anti-collision лок: задачу в «В работе» другой агент уже не возьмёт).

Креды: `JIRA_API_TOKEN` + `JIRA_EMAIL`/`JIRA_BASE_URL` для кросс-девайсной работы;
fallback на macOS Keychain, сервис `fantasydisk-jira` (НЕ хранить токен в репо).
"""
from __future__ import annotations  # PEP 604 (str | None) совместимость с Python 3.9

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

SITE = os.getenv("JIRA_BASE_URL", "https://fantasydisk.atlassian.net").rstrip("/")
EMAIL = os.getenv("JIRA_EMAIL", "fomamoney@gmail.com")
KEYCHAIN_SERVICE = os.getenv("JIRA_KEYCHAIN_SERVICE", "fantasydisk-jira")
PROJECT = "SCRUM"
BOARD = 1
TODO = "К выполнению"
IN_PROGRESS = ("В работе", "In Progress")
LANE_LABELS = {"codex", "claude", "otherai"}


def _token() -> str:
    env_token = os.getenv("JIRA_API_TOKEN")
    if env_token:
        return env_token.strip()
    try:
        token = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True,
            check=False,
        ).stdout.strip()
    except FileNotFoundError:
        token = ""
    if not token:
        raise RuntimeError(
            "Jira token not found. Set JIRA_API_TOKEN or configure macOS Keychain "
            f"service '{KEYCHAIN_SERVICE}'."
        )
    return token


def _auth_header() -> str:
    return "Basic " + base64.b64encode(f"{EMAIL}:{_token()}".encode()).decode()


def api(method: str, path: str, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(SITE + path, data=data, method=method)
    req.add_header("Authorization", _auth_header())
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            t = r.read().decode()
            return json.loads(t) if t else {}
    except urllib.error.HTTPError as e:
        print(f"  ! Jira HTTP {e.code}: {e.read().decode()[:200]}", file=sys.stderr)
        return None


def _adf(text: str):
    return {"type": "doc", "version": 1,
            "content": [{"type": "paragraph", "content": [{"type": "text", "text": text}]}]}


def active_sprint():
    v = api("GET", f"/rest/agile/1.0/board/{BOARD}/sprint?state=active")
    vals = (v or {}).get("values", [])
    return (vals[0]["id"], vals[0]["name"]) if vals else (None, None)


def _plain(adf) -> str:
    """Грубо вытащить текст из ADF-описания."""
    out = []

    def walk(node):
        if isinstance(node, dict):
            if node.get("type") == "text":
                out.append(node.get("text", ""))
            for c in node.get("content", []) or []:
                walk(c)
        elif isinstance(node, list):
            for c in node:
                walk(c)
    walk(adf)
    return "\n".join(s for s in "".join(out).split("\n") if s)


def _role_label(role: str) -> str:
    aliases = {
        "back-end": "backend",
        "backend": "backend",
        "design-main": "design",
        "designer2": "design",
        "designer-2": "design",
        "design": "design",
        "animation": "animator",
        "animator": "animator",
        "qa": "qa",
    }
    return aliases.get(role.lower(), role.lower())


def _lane_matches(labels: list[str], lane: str | None, allow_unlabeled_lane: bool) -> bool:
    if not lane or lane == "any":
        return True
    lane = lane.lower()
    present_lanes = LANE_LABELS.intersection(labels)
    if lane in present_lanes:
        return True
    return allow_unlabeled_lane and not present_lanes


def find_next(
    role: str,
    sprint_id: int,
    lane: str | None,
    allow_unlabeled_lane: bool,
    required_labels: list[str],
):
    role_label = _role_label(role)
    # statusCategory="To Do" — языконезависимо матчит «К выполнению» (не начатые);
    # claimed-в-«В работе» уходят в категорию In Progress и сюда не попадают (anti-collision).
    jql = (f'project={PROJECT} AND sprint={sprint_id} AND statusCategory="To Do" '
           f'AND labels="{role_label}" AND assignee is EMPTY ORDER BY created ASC')
    r = api("GET", "/rest/api/3/search/jql?maxResults=50&fields=summary,labels,priority,description&jql="
            + urllib.parse.quote(jql))
    cands = []
    for issue in (r or {}).get("issues", []):
        labels = [l.lower() for l in issue["fields"].get("labels", [])]
        if {"hold", "user-hold", "blocked"}.intersection(labels):
            continue
        if not _lane_matches(labels, lane, allow_unlabeled_lane):
            continue
        if any(label.lower() not in labels for label in required_labels):
            continue
        # приоритет берём из метки p0/p1/p2 (Jira-поле priority не проставлено)
        prio = next((p for p in ("p0", "p1", "p2") if p in labels), "p9")
        cands.append((prio, issue))
    cands.sort(key=lambda c: c[0])  # p0 раньше p1 раньше p2; внутри — created ASC из JQL
    return cands[0][1] if cands else None


def assign_if_configured(key: str) -> None:
    account_id = os.getenv("JIRA_ACCOUNT_ID")
    if not account_id:
        return
    api("PUT", f"/rest/api/3/issue/{key}/assignee", {"accountId": account_id})


def claim(key: str, worker: str, role: str, lane: str | None) -> bool:
    trs = api("GET", f"/rest/api/3/issue/{key}/transitions") or {}
    tr = next((t for t in trs.get("transitions", []) if t["to"]["name"] in IN_PROGRESS), None)
    if not tr:
        print(f"  ! нет перехода в 'В работе' для {key}", file=sys.stderr)
        return False
    assign_if_configured(key)
    api("POST", f"/rest/api/3/issue/{key}/transitions", {"transition": {"id": tr["id"]}})
    api("POST", f"/rest/api/3/issue/{key}/comment",
        {"body": _adf(
            f"Claimed by {worker} (Jira-pull) — role={_role_label(role)}, "
            f"lane={lane or 'any'}, взято в работу."
        )})
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--role", required=True, help="backend|design|qa|animator|pm")
    ap.add_argument("--lane", choices=["codex", "claude", "otherai", "any"],
                    help="execution lane label to require before claiming")
    ap.add_argument("--required-label", action="append", default=[],
                    help="extra Jira label required for this worker; may be repeated")
    ap.add_argument("--allow-unlabeled-lane", action="store_true",
                    help="allow To Do issues that have no codex/claude/otherai label")
    ap.add_argument("--claim", action="store_true", help="перевести в 'В работе' + коммент (взять себе)")
    ap.add_argument("--worker", default="agent", help="id воркера для комментария-клейма")
    ap.add_argument("--json", action="store_true", help="вывод в JSON")
    args = ap.parse_args()

    sid, sname = active_sprint()
    if not sid:
        print("Нет активного спринта.", file=sys.stderr)
        sys.exit(2)

    issue = find_next(args.role, sid, args.lane, args.allow_unlabeled_lane, args.required_label)
    if not issue:
        if args.json:
            print(json.dumps({
                "sprint": sname,
                "role": args.role,
                "lane": args.lane,
                "required_labels": args.required_label,
                "task": None,
            }, ensure_ascii=False))
        else:
            lane = f", lane '{args.lane}'" if args.lane else ""
            req = f", labels {', '.join(args.required_label)}" if args.required_label else ""
            print(f"Нет задач '{TODO}' для роли '{args.role}'{lane}{req} в спринте «{sname}».")
        sys.exit(0)

    key = issue["key"]
    f = issue["fields"]
    claimed = False
    if args.claim:
        claimed = claim(key, args.worker, args.role, args.lane)

    if args.json:
        print(json.dumps({
            "sprint": sname, "role": args.role, "lane": args.lane,
            "required_labels": args.required_label, "claimed": claimed,
            "key": key, "summary": f["summary"],
            "priority": (f.get("priority") or {}).get("name"),
            "labels": f.get("labels", []),
            "url": f"{SITE}/browse/{key}",
            "description": _plain(f.get("description")),
        }, ensure_ascii=False, indent=2))
    else:
        print(f"Спринт: {sname}")
        print(f"Задача: {key}  [{(f.get('priority') or {}).get('name','?')}]  {'(ВЗЯТА в работу)' if claimed else '(read-only)'}")
        print(f"  {f['summary']}")
        print(f"  labels: {', '.join(f.get('labels', []))}")
        print(f"  {SITE}/browse/{key}")
        desc = _plain(f.get("description"))
        if desc:
            print("\n" + desc)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(f"Jira-pull unavailable: {exc}", file=sys.stderr)
        raise SystemExit(2)
