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
Запуск: python3 tools/jira_board_sync.py [--dry-run] [--no-create]
"""
from __future__ import annotations

import base64
import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
try:
    import fcntl  # type: ignore
except ImportError:
    fcntl = None
    import msvcrt  # type: ignore

LOCK_PATH = os.path.join(tempfile.gettempdir(), "fantasydisk_jira_sync.lock")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASKS_GLOB = os.path.join(ROOT, "docs/tasks/*.md")
MAP_PATH = os.path.join(ROOT, "docs/process/jira_sync_map.json")
EPICS_PATH = os.path.join(ROOT, "docs/process/jira_epics.json")
SITE = os.getenv("JIRA_BASE_URL", "https://fantasydisk.atlassian.net").rstrip("/")
PROJECT = "SCRUM"
EMAIL = os.getenv("JIRA_EMAIL", "fomamoney@gmail.com")
KEYCHAIN_SERVICE = os.getenv("JIRA_KEYCHAIN_SERVICE", "fantasydisk-jira")

# Аджайл-эпики: новые тикеты привязываются к parent-эпику по имени файла/заголовку.
if os.path.exists(EPICS_PATH):
    with open(EPICS_PATH, encoding="utf-8") as f:
        EPICS = json.load(f).get("epics", {})
else:
    EPICS = {}


def epic_for(name: str, title: str) -> str:
    """Код эпика по имени task-файла + заголовку (зеркало ручной классификации)."""
    f = (name or "").lower()
    s = (title or "").lower()

    def has(*ks):
        return any(k in f or k in s for k in ks)

    if f.startswith(("cleanup_", "refactor_audit_")) or has("cleanup_pass", "deadcode", "dead_code", "рефакторинг и чистка"):
        return "CLEANUP"
    if f.startswith(("qol_", "ux_")) or has("qol", "quality_of_life", "удобств", "качество жизни"):
        return "QOL"
    if has("add_character", "class_identity", "new_classes", "hero_select", "class_sheet", "three_weapons"):
        return "CHARS"
    if "animation" in f or has("rig", "motion", "cutout", "анимац", "_pose_", "movement"):
        return "ANIM"
    if has("music", "audio", "volume", "sfx", "звук", "музык", "эмбиент"):
        return "AUDIO"
    if has("balance", "vampir", "survivab", "level_up", "levelup", "drop_econom", "economy",
           "dps", "harness", "reroll", "attribute_relevance", "баланс", "экономик", "дроп"):
        return "BALANCE"
    if has("meta_skill", "skill_tree", "patch_notes", "ascension_difficulty", "codex_encyclop",
           "encyclopedia", "древо", "патч-ноут", "мета-прогресс"):
        return "META"
    if has("refactor", "_test_", "test_", "audit", "cleanup", "unused_asset", "domain_split",
           "docs_domain", "registry_consist", "module_split", "type_inference", "smoke",
           "performance", "code_quality"):
        return "QUALITY"
    if has("release", "build", "windows", "installer", "versioning", "jira_sync", "feature_block",
           "process_", "integrity"):
        return "RELEASE"
    if has("elite", "boss", "mini_elite", "enemy", "attack_aim", "weapon_identity", "weapon_target",
           "combat_feedback", "ascension", "event", "hazard", "spawn", "scaling",
           "возвыш", "элит", "босс", "событ", "враг"):
        return "COMBAT"
    if name.startswith(("codex_design", "design_")) or has("sprite", "background", "backdrop", "icon",
           "vfx_sprite", "art_", "_art", "redraw", "visual", "перерисов", "спрайт", "фон", "иконк", "арт"):
        return "ART"
    if has("ui_", "_ui_", "shop", "menu", "pause", "settings", "hud", "escape", "radar", "overlap",
           "victory", "localization", "russian", "glossary", "tooltip", "frame", "button", "screen",
           "dark_fantasy", "slider", "магазин", "меню", "интерфейс", "экран", "перевод", "локализ"):
        return "UI"
    return "QUALITY"

STATUS_TARGET = {
    "new": "К выполнению",
    "blocked": "К выполнению",
    "in_progress": "В работе",
    "review": "В работе",
    "done": "Контроль качества",   # если QA PASSED — перекрывается на «Готово»
    "qa_passed": "Готово",
}


class JiraApiError(RuntimeError):
    def __init__(self, code: int, path: str, body: str):
        super().__init__(f"Jira HTTP {code} {path}: {body[:300]}")
        self.code = code
        self.path = path
        self.body = body


class JiraNotFound(JiraApiError):
    pass


def token() -> str:
    env_token = os.getenv("JIRA_API_TOKEN")
    if env_token:
        return env_token.strip()
    try:
        return subprocess.check_output(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            text=True).strip()
    except FileNotFoundError as exc:
        raise RuntimeError(
            "Jira token not found. Set JIRA_API_TOKEN or configure macOS Keychain "
            f"service '{KEYCHAIN_SERVICE}'."
        ) from exc


def api(method: str, path: str, payload=None, *, tolerate_not_found: bool = False):
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
        body = e.read().decode(errors="replace")
        if e.code == 404:
            sys.stderr.write(f"SKIP_INACCESSIBLE {path}: HTTP 404 {body[:300]}\n")
            if tolerate_not_found:
                return None
            raise JiraNotFound(e.code, path, body) from e
        sys.stderr.write(f"HTTP {e.code} {path}: {body[:300]}\n")
        raise JiraApiError(e.code, path, body) from e


def find_existing_issue(summary: str):
    """Дедуп-страж: вернуть ключ уже существующего тикета с ТАКИМ ЖЕ summary
    (точное совпадение), чтобы повторный/параллельный прогон не плодил дубль,
    даже если локальная карта (jira_sync_map.json) устарела. None если нет."""
    esc = summary.replace("\\", "\\\\").replace('"', '\\"')
    jql = f'project = {PROJECT} AND summary ~ "\\"{esc}\\"" ORDER BY created ASC'
    try:
        data = api("GET", "/rest/api/3/search/jql?jql="
                   + urllib.parse.quote(jql) + "&maxResults=50&fields=summary,status")
    except Exception:
        return None
    for it in data.get("issues", []):
        if it["fields"]["summary"].strip() == summary.strip():
            return it["key"]
    return None


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
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
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
    qa_m = re.search(r"^##\s*QA-Вердикт.*?(?=^##\s+|\Z)", text, re.S | re.M)
    qa_block = qa_m.group(0) if qa_m else ""
    qa_passed = bool(re.search(r"^Статус:\s*PASSED\b", qa_block, re.M | re.I))
    if status == "done" and qa_passed:
        status = "qa_passed"
    if name.startswith("bug_"):
        role, itype = "bug", "Баг"
    elif name.startswith(("design_", "codex_design", "codex_redesign")):
        role, itype = "design", "Задача"
    elif name.startswith("qa_"):
        role, itype = "qa", "Задача"
    elif name.startswith("animation"):
        role, itype = "animation", "Задача"
    else:
        role, itype = "backend", "Задача"
    ver_m = re.search(r"^Версия:\s*(\d+\.\d+\.\d+)", text, re.M)
    task_version = ver_m.group(1) if ver_m else None
    # исполнитель: codex — генерация/исполнение контуром Codex; иначе claude
    is_codex = name.startswith("codex_") or bool(
        re.search(r"^(Исполнитель|Executor):.*Codex", text, re.M | re.I))
    executor = "codex" if is_codex else "claude"
    excerpt = text[:4500]
    desc_hash = hashlib.md5(excerpt.encode("utf-8")).hexdigest()
    jira_m = re.search(r"^Jira:\s*(SCRUM-\d+)", text, re.M | re.I)
    jira_key = jira_m.group(1).upper() if jira_m else None
    if jira_key is None:
        file_key = re.match(r"^(SCRUM-\d+)[_-]", name, re.I)
        jira_key = file_key.group(1).upper() if file_key else None
    explicit_backlog = bool(
        re.search(r"^(Backlog|Sprint|Спринт):\s*(backlog|future|next|hold|бэклог|будущ)", text, re.M | re.I)
        or re.search(r"^(Labels|Метки):.*\b(backlog|future-release|next-release|deferred)\b", text, re.M | re.I)
    )
    return {"file": name, "title": title[:250], "status": status,
            "role": role, "itype": itype, "excerpt": excerpt, "desc_hash": desc_hash,
            "blocked": raw_status.startswith("blocked"),
            "task_version": task_version if not name.startswith("bug_") else None,
            "executor": executor, "jira_key": jira_key,
            "explicit_backlog": explicit_backlog}


def adf(text: str) -> dict:
    paras = [p for p in text.split("\n\n") if p.strip()][:30]
    return {"type": "doc", "version": 1, "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": p[:1500]}]}
        for p in paras]}


def build_arg_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        description="Sync docs/tasks mirrors to Jira SCRUM with safe scoped guards."
    )
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-create", action="store_true",
                    help="Do not create Jira issues. Without --task/--issue this is status-safe.")
    ap.add_argument("--task", action="append", default=[],
                    help="Limit sync to a task path or basename. May be repeated.")
    ap.add_argument("--issue", action="append", default=[],
                    help="Limit sync to a Jira key, for example SCRUM-635. May be repeated.")
    ap.add_argument("--allow-broad-status-sync", action="store_true",
                    help="Dispatcher-only escape hatch: allow broad status/description updates without --task/--issue.")
    return ap


def norm_task_filters(tasks: list[str]) -> set[str]:
    out = set()
    for task in tasks:
        norm = os.path.normpath(task)
        out.add(norm)
        out.add(os.path.basename(norm))
    return out


def in_scope(path: str, task: dict, entry: dict | None, task_filters: set[str], issue_filters: set[str]) -> bool:
    if not task_filters and not issue_filters:
        return True
    norm = os.path.normpath(path)
    if norm in task_filters or os.path.basename(norm) in task_filters or task["file"] in task_filters:
        return True
    keys = {task.get("jira_key")}
    if entry:
        keys.add(entry.get("key"))
    keys = {str(k).upper() for k in keys if k}
    return bool(keys.intersection(issue_filters))


def load_mapping() -> dict:
    if not os.path.exists(MAP_PATH):
        return {}
    with open(MAP_PATH, encoding="utf-8") as f:
        return json.load(f)


def save_mapping(mapping: dict) -> None:
    with open(MAP_PATH, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=1)


def main():
    dry = "--dry-run" in sys.argv
    no_create = "--no-create" in sys.argv or os.getenv("JIRA_SYNC_NO_CREATE") == "1"
    # Взаимоисключающий lock: два параллельных синка (PM + воркер) больше не гоняются
    # по одним task-файлам со стаканной картой и не плодят дубли тикетов.
    lock_fd = open(LOCK_PATH, "w")
    try:
        if fcntl is not None:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        else:
            msvcrt.locking(lock_fd.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError:
        print("another jira_board_sync is running — abort (lock held)")
        return
    mapping = json.load(open(MAP_PATH)) if os.path.exists(MAP_PATH) else {}
    created = moved = 0
    sprint_id, sprint_name = (None, "") if dry else active_sprint()
    fix_version = sprint_version(sprint_name)
    sprint_queue = []
    for path in sorted(glob.glob(TASKS_GLOB)):
        t = parse_task(path)
        # User directive 2026-07-03: all chat-added work goes into the live
        # active sprint by default. Keep an issue out of the sprint only when
        # the local spec explicitly marks it as backlog/future/hold.
        t["next_version"] = bool(t["explicit_backlog"])
        target_status = STATUS_TARGET[t["status"]]
        entry = mapping.get(t["file"])
        labels = ["fantasydisk", t["role"], t["executor"]] + (["blocked"] if t["blocked"] else [])
        if entry is None:
            if dry or no_create:
                action = "CREATE" if dry else "SKIP_CREATE"
                print(f"{action} {t['file']} -> [{t['itype']}] {target_status}")
                continue
            # Дедуп-страж: если тикет с таким summary уже есть в Jira (карта устарела
            # или другой прогон его создал) — переиспользовать ключ, не плодить дубль.
            existing = find_existing_issue(t["title"])
            if existing:
                mapping[t["file"]] = {"key": existing, "status": "К выполнению"}
                json.dump(mapping, open(MAP_PATH, "w"), ensure_ascii=False, indent=1)
                entry = mapping[t["file"]]
                print(f"linked existing {existing}: {t['file']} (dedup, not created)")
            else:
                fields = {
                    "project": {"key": PROJECT},
                    "issuetype": {"name": t["itype"]},
                    "summary": t["title"],
                    "labels": labels,
                    "description": adf(f"Файл: docs/tasks/{t['file']}\n\n" + t["excerpt"]),
                }
                if t["next_version"] and t["task_version"]:
                    # Explicit backlog/freeze marker: keep the issue outside the
                    # active sprint with its requested future fixVersion.
                    fields["fixVersions"] = [{"name": t["task_version"]}]
                elif fix_version:
                    fields["fixVersions"] = [{"name": fix_version}]
                # Аджайл: привязать новый тикет к parent-эпику (кроме самих эпиков).
                if t["itype"] != "Эпик":
                    ep = EPICS.get(epic_for(t["file"], t["title"]))
                    if ep:
                        fields["parent"] = {"key": ep}
                issue = api("POST", "/rest/api/3/issue", {"fields": fields})
                key = issue["key"]
                mapping[t["file"]] = {"key": key, "status": "К выполнению", "desc_hash": t["desc_hash"]}
                json.dump(mapping, open(MAP_PATH, "w"), ensure_ascii=False, indent=1)
                entry = mapping[t["file"]]
                created += 1
                if not t["next_version"]:
                    sprint_queue.append(key)  # текущий release scope -> active sprint
                print(f"created {key}: {t['file']}")
        elif not t["next_version"]:
            sprint_queue.append(entry["key"])
        # Описание в Jira держим в синхроне с .md: при изменении контента (хэш)
        # переписываем description, чтобы текст «Статус: blocked» и т.п. не устаревал.
        if not dry and entry.get("desc_hash") != t["desc_hash"]:
            api("PUT", f"/rest/api/3/issue/{entry['key']}",
                {"fields": {"description": adf(f"Файл: docs/tasks/{t['file']}\n\n" + t["excerpt"])}})
            entry["desc_hash"] = t["desc_hash"]
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


def safe_main():
    args = build_arg_parser().parse_args()
    dry = args.dry_run
    no_create = args.no_create or os.getenv("JIRA_SYNC_NO_CREATE") == "1"
    task_filters = norm_task_filters(args.task)
    issue_filters = {issue.upper() for issue in args.issue}
    broad_status_guard = no_create and not (task_filters or issue_filters) and not args.allow_broad_status_sync

    lock_fd = open(LOCK_PATH, "w")
    try:
        if fcntl is not None:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        else:
            msvcrt.locking(lock_fd.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError:
        lock_fd.close()
        print("another jira_board_sync is running - abort (lock held)")
        return

    mapping = load_mapping()
    created = moved = guarded = inaccessible = scanned = 0
    if broad_status_guard:
        print("SAFE_GUARD --no-create without --task/--issue: broad status/description updates are disabled. "
              "Use --task/--issue for worker sync or --allow-broad-status-sync for dispatcher maintenance.")

    needs_live_sprint = not dry and not no_create
    sprint_id, sprint_name = (None, "") if not needs_live_sprint else active_sprint()
    fix_version = sprint_version(sprint_name)
    sprint_queue = []

    for path in sorted(glob.glob(TASKS_GLOB)):
        t = parse_task(path)
        entry = mapping.get(t["file"])
        if not in_scope(path, t, entry, task_filters, issue_filters):
            continue
        scanned += 1
        # User directive 2026-07-03: all chat-added work goes into the live
        # active sprint by default. A different task Version is not enough to
        # leave it in backlog; backlog/future scope must be explicit.
        t["next_version"] = bool(t["explicit_backlog"])
        target_status = STATUS_TARGET[t["status"]]
        labels = ["fantasydisk", t["role"], t["executor"]] + (["blocked"] if t["blocked"] else [])

        if entry is None and t.get("jira_key") and not broad_status_guard:
            entry = {"key": t["jira_key"], "status": None, "desc_hash": None}
            if not dry:
                mapping[t["file"]] = entry
                save_mapping(mapping)
            print(f"linked declared {t['jira_key']}: {t['file']}")

        if entry is None:
            if dry or no_create:
                action = "CREATE" if dry else "SKIP_CREATE"
                print(f"{action} {t['file']} -> [{t['itype']}] {target_status}")
                continue
            existing = find_existing_issue(t["title"])
            if existing:
                mapping[t["file"]] = {"key": existing, "status": STATUS_TARGET["new"]}
                save_mapping(mapping)
                entry = mapping[t["file"]]
                print(f"linked existing {existing}: {t['file']} (dedup, not created)")
            else:
                fields = {
                    "project": {"key": PROJECT},
                    "issuetype": {"name": t["itype"]},
                    "summary": t["title"],
                    "labels": labels,
                    "description": adf(f"File: docs/tasks/{t['file']}\n\n" + t["excerpt"]),
                }
                if t["next_version"] and t["task_version"]:
                    fields["fixVersions"] = [{"name": t["task_version"]}]
                elif fix_version:
                    fields["fixVersions"] = [{"name": fix_version}]
                ep = EPICS.get(epic_for(t["file"], t["title"]))
                if ep:
                    fields["parent"] = {"key": ep}
                issue = api("POST", "/rest/api/3/issue", {"fields": fields})
                key = issue["key"]
                mapping[t["file"]] = {"key": key, "status": STATUS_TARGET["new"], "desc_hash": t["desc_hash"]}
                save_mapping(mapping)
                entry = mapping[t["file"]]
                created += 1
                if needs_live_sprint and not t["next_version"]:
                    sprint_queue.append(key)
                print(f"created {key}: {t['file']}")
        elif needs_live_sprint and not t["next_version"]:
            sprint_queue.append(entry["key"])

        if not dry and not broad_status_guard and entry.get("desc_hash") != t["desc_hash"]:
            res = api("PUT", f"/rest/api/3/issue/{entry['key']}",
                      {"fields": {"description": adf(f"File: docs/tasks/{t['file']}\n\n" + t["excerpt"])}},
                      tolerate_not_found=True)
            if res is None:
                inaccessible += 1
                continue
            entry["desc_hash"] = t["desc_hash"]

        if entry.get("status") == STATUS_TARGET["qa_passed"]:
            continue
        if entry.get("status") != target_status:
            if dry:
                print(f"MOVE {entry.get('key','?')} {entry.get('status')} -> {target_status}")
                continue
            if broad_status_guard:
                guarded += 1
                print(f"GUARD_SKIP_MOVE {entry.get('key','?')} {entry.get('status')} -> {target_status}")
                continue
            trs = api("GET", f"/rest/api/3/issue/{entry['key']}/transitions", tolerate_not_found=True)
            if trs is None:
                inaccessible += 1
                continue
            tr = next((x for x in trs.get("transitions", []) if x["to"]["name"] == target_status), None)
            if tr:
                moved_res = api("POST", f"/rest/api/3/issue/{entry['key']}/transitions",
                                {"transition": {"id": tr["id"]}}, tolerate_not_found=True)
                if moved_res is None:
                    inaccessible += 1
                    continue
                entry["status"] = target_status
                moved += 1
                print(f"moved {entry['key']} -> {target_status}")

    if not dry and needs_live_sprint:
        add_to_sprint(sprint_id, sprint_queue)
    if not dry:
        save_mapping(mapping)
    lock_fd.close()
    print(f"done: scanned {scanned}, created {created}, moved {moved}, "
          f"guarded {guarded}, inaccessible {inaccessible}, total tracked {len(mapping)}")

main = safe_main


if __name__ == "__main__":
    main()
