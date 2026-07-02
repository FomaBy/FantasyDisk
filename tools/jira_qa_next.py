#!/usr/bin/env python3
"""Найти следующую задачу на QA-приёмку (статус «Контроль качества») в активном спринте Jira.

QA-рутина вызывает этот тул, чтобы взять задачу на верификацию. В отличие от
tools/jira_next_task.py (берёт «К выполнению» на ИСПОЛНЕНИЕ), этот берёт задачи,
которые исполнитель уже сдал на приёмку. QA сам переводит её в «Готово» (PASS)
или заводит баг + возвращает в «К выполнению» (FAIL).

Usage:
    python3 tools/jira_qa_next.py            # человекочитаемо
    python3 tools/jira_qa_next.py --json

Креды: JIRA_API_TOKEN env (+ JIRA_EMAIL/JIRA_BASE_URL) для кросс-девайса;
fallback на macOS Keychain, сервис fantasydisk-jira.
"""
from __future__ import annotations

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
BOARD = 1
REVIEW_STATUS = "Контроль качества"  # колонка приёмки QA


def _token() -> str:
    env_token = os.getenv("JIRA_API_TOKEN")
    if env_token:
        return env_token.strip()
    try:
        token = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True, check=False,
        ).stdout.strip()
    except FileNotFoundError:
        token = ""
    if not token:
        raise RuntimeError("Jira token not found. Set JIRA_API_TOKEN or Keychain "
                           f"service '{KEYCHAIN_SERVICE}'.")
    return token


AUTH = "Basic " + base64.b64encode(f"{EMAIL}:{_token()}".encode()).decode()


def api(path: str):
    req = urllib.request.Request(SITE + path, method="GET")
    req.add_header("Authorization", AUTH)
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            t = r.read().decode()
            return json.loads(t) if t else {}
    except urllib.error.HTTPError as e:
        print(f"  ! Jira HTTP {e.code}: {e.read().decode()[:160]}", file=sys.stderr)
        return None


def _plain(adf) -> str:
    out = []

    def walk(n):
        if isinstance(n, dict):
            if n.get("type") == "text":
                out.append(n.get("text", ""))
            for c in n.get("content", []) or []:
                walk(c)
        elif isinstance(n, list):
            for c in n:
                walk(c)
    walk(adf)
    return "\n".join(s for s in "".join(out).split("\n") if s)


def active_sprint():
    v = api(f"/rest/agile/1.0/board/{BOARD}/sprint?state=active") or {}
    vals = v.get("values", [])
    return (vals[0]["id"], vals[0]["name"]) if vals else (None, None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    sid, sname = active_sprint()
    if not sid:
        print("Нет активного спринта.", file=sys.stderr)
        sys.exit(2)

    # JQL по имени статуса с кириллицей ненадёжен → берём не-Done и фильтруем по имени в Python.
    jql = f'project=SCRUM AND sprint={sid} AND statusCategory != Done ORDER BY created ASC'
    r = api("/rest/api/3/search/jql?maxResults=100&fields=summary,status,labels,description&jql="
            + urllib.parse.quote(jql)) or {}
    cands = [i for i in r.get("issues", []) if i["fields"]["status"]["name"] == REVIEW_STATUS]
    cands.sort(key=lambda i: next(
        (p for p in ("p0", "p1", "p2") if p in [l.lower() for l in i["fields"].get("labels", [])]), "p9"))

    if not cands:
        if args.json:
            print(json.dumps({"sprint": sname, "task": None}))
        else:
            print(f"Нет задач на QA-приёмку («{REVIEW_STATUS}») в спринте «{sname}».")
        sys.exit(0)

    issue = cands[0]
    f = issue["fields"]
    if args.json:
        print(json.dumps({
            "sprint": sname, "key": issue["key"], "summary": f["summary"],
            "labels": f.get("labels", []), "url": f"{SITE}/browse/{issue['key']}",
            "description": _plain(f.get("description")),
        }, ensure_ascii=False, indent=2))
    else:
        print(f"Спринт: {sname}")
        print(f"На приёмку: {issue['key']}  {f['summary']}")
        print(f"  labels: {', '.join(f.get('labels', []))}")
        print(f"  {SITE}/browse/{issue['key']}")
        desc = _plain(f.get("description"))
        if desc:
            print("\n" + desc)


if __name__ == "__main__":
    main()
