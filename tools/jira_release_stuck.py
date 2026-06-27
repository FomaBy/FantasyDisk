#!/usr/bin/env python3
"""Безопасный сброс «зависших» задач: вернуть claimed («В работе») задачи активного
спринта обратно в «К выполнению» — для чистого перезапуска после остановки агентов
или выключения компа.

Запускать ПОСЛЕ остановки рутин (чтобы не отобрать задачу у живого прогона). Любая
сделанная работа уже на GitHub (dev); этот тул лишь снимает claim-лок, чтобы задачу
снова можно было взять с чистого листа.

Usage:
    python3 tools/jira_release_stuck.py             # сброс foma-задач «В работе» -> «К выполнению»
    python3 tools/jira_release_stuck.py --dry-run   # только показать, ничего не менять
    python3 tools/jira_release_stuck.py --all        # включая non-foma

Креды: JIRA_API_TOKEN env / macOS Keychain fantasydisk-jira.
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
IN_PROGRESS = "В работе"
TODO = "К выполнению"
AUTO_LABEL = os.getenv("JIRA_AUTO_LABEL", "foma").strip().lower()


def _token() -> str:
    t = os.getenv("JIRA_API_TOKEN")
    if t:
        return t.strip()
    try:
        t = subprocess.run(["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
                           capture_output=True, text=True, check=False).stdout.strip()
    except FileNotFoundError:
        t = ""
    if not t:
        raise RuntimeError(f"Jira token not found. Set JIRA_API_TOKEN or Keychain '{KEYCHAIN_SERVICE}'.")
    return t


AUTH = "Basic " + base64.b64encode(f"{EMAIL}:{_token()}".encode()).decode()


def api(method: str, path: str, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(SITE + path, data=data, method=method)
    req.add_header("Authorization", AUTH)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            t = r.read().decode()
            return json.loads(t) if t else {}
    except urllib.error.HTTPError as e:
        print(f"  ! Jira HTTP {e.code}: {e.read().decode()[:160]}", file=sys.stderr)
        return None


def _adf(text: str):
    return {"type": "doc", "version": 1,
            "content": [{"type": "paragraph", "content": [{"type": "text", "text": text}]}]}


def active_sprint():
    v = api("GET", f"/rest/agile/1.0/board/{BOARD}/sprint?state=active") or {}
    vals = v.get("values", [])
    return (vals[0]["id"], vals[0]["name"]) if vals else (None, None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--all", action="store_true", help="включая non-foma задачи")
    args = ap.parse_args()

    sid, sname = active_sprint()
    if not sid:
        print("Нет активного спринта.", file=sys.stderr)
        sys.exit(2)

    jql = f'project=SCRUM AND sprint={sid} AND statusCategory != Done ORDER BY created ASC'
    r = api("GET", "/rest/api/3/search/jql?maxResults=80&fields=summary,status,labels&jql="
            + urllib.parse.quote(jql)) or {}
    targets = []
    for issue in r.get("issues", []):
        f = issue["fields"]
        if f["status"]["name"] != IN_PROGRESS:
            continue
        labels = [l.lower() for l in f.get("labels", [])]
        if AUTO_LABEL and not args.all and AUTO_LABEL not in labels:
            continue
        targets.append(issue)

    if not targets:
        print(f"Зависших задач «{IN_PROGRESS}» в спринте «{sname}» нет — всё чисто.")
        return

    print(f"Спринт «{sname}»: {len(targets)} задач(и) «{IN_PROGRESS}» -> «{TODO}»"
          + (" (dry-run)" if args.dry_run else ""))
    for issue in targets:
        key = issue["key"]
        print(f"  {key}  {issue['fields']['summary'][:50]}")
        if args.dry_run:
            continue
        trs = api("GET", f"/rest/api/3/issue/{key}/transitions") or {}
        tr = next((t for t in trs.get("transitions", []) if t["to"]["name"] == TODO), None)
        if not tr:
            print(f"     ! нет перехода в «{TODO}»", file=sys.stderr)
            continue
        api("POST", f"/rest/api/3/issue/{key}/transitions", {"transition": {"id": tr["id"]}})
        api("POST", f"/rest/api/3/issue/{key}/comment",
            {"body": _adf("Released for safe restart — claim снят, задача возвращена в очередь.")})
    if not args.dry_run:
        print("Готово. Задачи снова можно брать с чистого листа.")


if __name__ == "__main__":
    main()
