#!/usr/bin/env python3
"""Публикация релиза FantasyDisk в Discord (releases webhook).

Постит новость версии с выделенными ключевыми изменениями, SHA256 и размерами;
прикладывает файлы <25 МБ (changelog, SHA256SUMS); на инсталлеры даёт ссылки
(--download-base) или печатает локальные пути, если хостинга нет.

URL вебхука: release_webhook.cfg (корень проекта, [release] discord_webhook_url) —
секрет, в .gitignore. User-Agent обязателен (иначе Discord 403).

Запуск: python3 release_publish.py --version X.Y.Z [--download-base URL]
        [--highlights "пункт1||пункт2||..."] [--dry-run]
"""
import argparse
import configparser
import json
import os
import sys
import urllib.request
import urllib.error

DISCORD_LIMIT = 24 * 1024 * 1024  # ~25 МБ лимит вложений вебхука
UA = "FantasyDisk-Release/1.0"


def repo_root() -> str:
    # скрипт лежит в ~/.codex/skills/...; корень репо берём из CWD или env
    return os.environ.get("FANTASYDISK_REPO", os.getcwd())


def telegram_url(root: str) -> str:
    cfg = configparser.ConfigParser()
    cfg.read(os.path.join(root, "release_webhook.cfg"))
    try:
        return cfg.get("release", "telegram_download_url").strip().strip('"')
    except Exception:
        return ""


def webhook_url(root: str) -> str:
    cfg = configparser.ConfigParser()
    p = os.path.join(root, "release_webhook.cfg")
    if not cfg.read(p):
        sys.exit("release_webhook.cfg не найден в %s" % root)
    return cfg.get("release", "discord_webhook_url").strip().strip('"')


def read_highlights(root: str, version: str, override: str) -> list:
    if override:
        return [h.strip() for h in override.split("||") if h.strip()]
    # 1) чистые русские highlights из in-game patch_notes_data.gd для этой версии
    pn = os.path.join(root, "scripts", "patch_notes_data.gd")
    if os.path.exists(pn):
        import re
        src = open(pn, encoding="utf-8").read()
        m = re.search(r'"version":\s*"%s".*?"highlights":\s*\[(.*?)\]' % re.escape(version), src, re.S)
        if m:
            hs = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))
            if hs:
                return [h.replace('\\"', '"') for h in hs][:12]
    # из CHANGELOG-<version>.md или releases/v<version>/CHANGELOG-<version>.md
    for cand in [os.path.join(root, "releases", "v%s" % version, "CHANGELOG-%s.md" % version),
                 os.path.join(root, "CHANGELOG.md")]:
        if os.path.exists(cand):
            lines = [l.strip("-* \t").rstrip() for l in open(cand, encoding="utf-8")
                     if l.strip().startswith(("-", "*"))]
            if lines:
                return lines[:12]
    return []


def post(url, content, files, dry):
    if dry:
        print("[dry-run] content:\n" + content)
        print("[dry-run] attach:", [f for f, _ in files])
        return
    boundary = "----FantasyDiskRelease"
    body = b""
    body += ("--%s\r\n" % boundary).encode()
    body += b'Content-Disposition: form-data; name="payload_json"\r\nContent-Type: application/json\r\n\r\n'
    body += json.dumps({"username": "FantasyDisk Releases", "content": content[:1900]}).encode() + b"\r\n"
    for i, (name, data) in enumerate(files):
        body += ("--%s\r\n" % boundary).encode()
        body += ('Content-Disposition: form-data; name="files[%d]"; filename="%s"\r\n'
                 % (i, name)).encode()
        body += b"Content-Type: application/octet-stream\r\n\r\n" + data + b"\r\n"
    body += ("--%s--\r\n" % boundary).encode()
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "Content-Type": "multipart/form-data; boundary=%s" % boundary, "User-Agent": UA})
    try:
        r = urllib.request.urlopen(req)
        print("Discord:", r.status, "— опубликовано ✓")
    except urllib.error.HTTPError as e:
        sys.exit("Discord ошибка %s: %s" % (e.code, e.read().decode()[:200]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--download-base", default="")
    ap.add_argument("--highlights", default="")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    root = repo_root()
    rel = os.path.join(root, "releases", "v%s" % a.version)
    if not os.path.isdir(rel):
        sys.exit("Нет каталога релиза: %s (сначала tools/build_release.sh %s)" % (rel, a.version))
    arts = sorted(os.listdir(rel))
    installers = [f for f in arts if f.endswith((".dmg", ".exe", ".zip"))]
    smalls = [f for f in arts if f.endswith((".txt", ".md"))]

    hl = read_highlights(root, a.version, a.highlights)
    key = hl[:5]
    rest = hl[5:]
    lines = ["# 🐉 FantasyDisk v%s" % a.version, ""]
    if key:
        lines += ["**✨ Главное:**"] + ["**•** %s" % h for h in key] + [""]
    if rest:
        lines += ["Также:"] + ["• %s" % h for h in rest] + [""]
    tg = a.download_base or telegram_url(root)
    lines.append("**\U0001F4E5 Скачать (macOS + Windows):**")
    if tg:
        lines.append(tg)
    else:
        lines.append("_(ссылка на скачивание не задана)_")
    lines.append("")
    lines.append("_Сборки: %s. SHA256 — во вложении._" % ", ".join(installers))

    files = []
    for f in smalls:  # changelog + SHA256SUMS — обычно <25 МБ
        p = os.path.join(rel, f)
        if os.path.getsize(p) <= DISCORD_LIMIT:
            files.append((f, open(p, "rb").read()))

    post(webhook_url(root), "\n".join(lines), files, a.dry_run)


if __name__ == "__main__":
    main()
