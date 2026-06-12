#!/usr/bin/env python3
"""Синхронизация задач FantasyDisk (docs/tasks/*.md) в Jira SCRUM.

- md-файлы — источник истины; Jira — зеркало-витрина.
- Идемпотентен: соответствие файл -> ключ Jira хранится в docs/process/jira_sync_map.json.
- Создает отсутствующие тикеты, двигает статусы существующих при изменении.

Маппинг статусов:
  new/blocked            -> К выполнению
  in_progress/review     -> В работе
  done (без QA PASSED)   -> Контроль качества
  done + QA PASSED       -> Готово
Тип: bug_*.md -> Баг, остальные -> Задача. Лейблы: роль + fantasydisk (+blocked).

Креды: macOS Keychain, сервис `fantasydisk-jira` (security find-generic-password).
Запуск: python3 tools/jira_board_sync.py [--dry-run]
"""
import base64
import glob
import json
import os
import re
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASKS_GLOB = os.path.join(ROOT, "docs/tasks/*.md")
MAP_PATH = os.path.join(ROOT, "docs/process/jira_sync_map.json")
SITE = "https://fantasydisk.atlassian.net"
PROJECT = "SCRUM"
EMAIL = "fomamoney@gmail.com"
KEYCHAIN_SERVICE = "fantasydisk-jira"

STATUS_TARGET = {
    "new": "К выполнению",
    "blocked": "К выполнению",
    "in_progress": "В работе",
    "review": "В работе",
    "done": "Контроль качества",   # если QA PASSED — перекрывается на «Готово»
    "qa_passed": "Готово",
}


def token() -> str:
    return subprocess.check_output(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
        text=True).strip()


def api(method: str, path: str, payload=None):
    req = urllib.request.Request(SITE + path, method=method)
    auth = base64.b64encode(f"{EMAIL}:{token()}".encode()).decode()
    req.add_header("Authorization", f"Basic {auth}")
    req.add_header("Content-Type", "application/json")
    data = json.dumps(payload).encode() if payload is not None else None
    try:
        with urllib.request.urlopen(req, data=data) as r:
            body = r.read().decode()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"HTTP {e.code} {path}: {e.read().decode()[:300]}\n")
        raise


def active_sprint():
    """(id, name) активного спринта доски 1; если нет — стартует следующий future."""
    data = api("GET", "/rest/agile/1.0/board/1/sprint?state=active")
    vals = data.get("values", [])
    if vals:
        return vals[0]["id"], vals[0]["name"]
    fut = api("GET", "/rest/agile/1.0/board/1/sprint?state=future").get("values", [])
    if fut:
        api("POST", f"/rest/agile/1.0/sprint/{fut[0]['id']}", {"state": "active"})
        return fut[0]["id"], fut[0]["name"]
    return None, ""


def active_sprint_id():
    return active_sprint()[0]


def sprint_version(sprint_name: str):
    """Версия из имени спринта («Спринт 0.1.4» -> «0.1.4»). Спринт = релиз."""
    m = re.search(r"(\d+\.\d+\.\d+)", sprint_name or "")
    return m.group(1) if m else None


def add_to_sprint(sprint_id, keys):
    if sprint_id and keys:
        for i in range(0, len(keys), 50):
            api("POST", f"/rest/agile/1.0/sprint/{sprint_id}/issue",
                {"issues": keys[i:i + 50]})


def parse_task(path: str) -> dict:
    text = open(path, encoding="utf-8", errors="replace").read()
    name = os.path.basename(path)
    title_m = re.search(r"^#\s+(.+)$", text, re.M)
    title = title_m.group(1).strip() if title_m else name
    status_m = re.search(r"^Статус:\s*(\S+)", text, re.M)
    raw_status = (status_m.group(1).lower() if status_m else "new").strip()
    for key in ("done", "in_progress", "review", "blocked", "new"):
        if raw_status.startswith(key):
            status = key
            break
    else:
        # русские исторические статусы
        status = "done" if raw_status.startswith(("выполн", "закрыт", "реализ", "fixed")) else "new"
    qa_passed = bool(re.search(r"##\s*QA-Вердикт.*?\n.{0,80}?PASSED", text, re.S))
    if status == "done" and qa_passed:
        status = "qa_passed"
    if name.startswith("bug_"):
        role, itype = "bug", "Баг"
    elif name.startswith(("design_", "codex_design")):
        role, itype = "design", "Задача"
    elif name.startswith("qa_"):
        role, itype = "qa", "Задача"
    elif name.startswith("animation"):
        role, itype = "animation", "Задача"
    else:
        role, itype = "backend", "Задача"
    next_version = bool(re.search(r"^Версия:\s*0\.1\.4", text, re.M))
    # исполнитель: codex — генерация/исполнение контуром Codex; иначе claude
    is_codex = name.startswith("codex_") or bool(
        re.search(r"^(Исполнитель|Executor):.*Codex", text, re.M | re.I))
    executor = "codex" if is_codex else "claude"
    excerpt = text[:4500]
    return {"file": name, "title": title[:250], "status": status,
            "role": role, "itype": itype, "excerpt": excerpt,
            "blocked": raw_status.startswith("blocked"),
            "next_version": next_version and not name.startswith("bug_"),
            "executor": executor}


def adf(text: str) -> dict:
    paras = [p for p in text.split("\n\n") if p.strip()][:30]
    return {"type": "doc", "version": 1, "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": p[:1500]}]}
        for p in paras]}


def main():
    dry = "--dry-run" in sys.argv
    mapping = json.load(open(MAP_PATH)) if os.path.exists(MAP_PATH) else {}
    created = moved = 0
    sprint_id, sprint_name = (None, "") if dry else active_sprint()
    fix_version = sprint_version(sprint_name)
    sprint_queue = []
    for path in sorted(glob.glob(TASKS_GLOB)):
        t = parse_task(path)
        target_status = STATUS_TARGET[t["status"]]
        entry = mapping.get(t["file"])
        labels = ["fantasydisk", t["role"], t["executor"]] + (["blocked"] if t["blocked"] else [])
        if entry is None:
            if dry:
                print(f"CREATE {t['file']} -> [{t['itype']}] {target_status}")
                continue
            fields = {
                "project": {"key": PROJECT},
                "issuetype": {"name": t["itype"]},
                "summary": t["title"],
                "labels": labels,
                "description": adf(f"Файл: docs/tasks/{t['file']}\n\n" + t["excerpt"]),
            }
            if fix_version and not t["next_version"]:
                fields["fixVersions"] = [{"name": fix_version}]
            issue = api("POST", "/rest/api/3/issue", {"fields": fields})
            key = issue["key"]
            mapping[t["file"]] = {"key": key, "status": "К выполнению"}
            entry = mapping[t["file"]]
            created += 1
            if not t["next_version"]:
                sprint_queue.append(key)  # фичи 0.1.4 остаются в бэклоге (feature freeze)
            print(f"created {key}: {t['file']}")
        if entry.get("status") == "Готово":
            continue  # финальное состояние: из «Готово» не понижаем
        if entry.get("status") != target_status:
            if dry:
                print(f"MOVE {entry.get('key','?')} {entry.get('status')} -> {target_status}")
                continue
            trs = api("GET", f"/rest/api/3/issue/{entry['key']}/transitions")
            tr = next((x for x in trs.get("transitions", [])
                       if x["to"]["name"] == target_status), None)
            if tr:
                api("POST", f"/rest/api/3/issue/{entry['key']}/transitions",
                    {"transition": {"id": tr["id"]}})
                entry["status"] = target_status
                moved += 1
                print(f"moved {entry['key']} -> {target_status}")
    if not dry:
        add_to_sprint(sprint_id, sprint_queue)
        json.dump(mapping, open(MAP_PATH, "w"), ensure_ascii=False, indent=1)
    print(f"done: created {created}, moved {moved}, total tracked {len(mapping)}")


if __name__ == "__main__":
    main()
