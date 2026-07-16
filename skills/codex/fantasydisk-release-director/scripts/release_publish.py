#!/usr/bin/env python3
"""Publish the verified FantasyDisk release news to Discord after Telegram delivery."""

import argparse
import configparser
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

from telegram_publish import public_download_url


DISCORD_LIMIT = 24 * 1024 * 1024
UA = "FantasyDisk-Release/1.0"
DISTRIBUTION_REPOSITORY = "FomaBy/FantasyDisk-Releases"


def verify_local_release(root: str, version: str) -> str:
    helper = os.path.join(os.path.dirname(__file__), "local_release.py")
    result = subprocess.run(
        [sys.executable, helper, "verify", "--version", version, "--repo-root", root],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        sys.exit("Локальная копия релиза не прошла проверку; Discord publication запрещена")
    try:
        return json.loads(result.stdout)["local_release"]
    except (KeyError, TypeError, json.JSONDecodeError):
        sys.exit("Локальная проверка не вернула путь к проверенным байтам релиза")


def repo_root() -> str:
    return os.environ.get("FANTASYDISK_REPO", os.getcwd())


def github_release_url(version: str) -> str:
    return "https://github.com/%s/releases/tag/v%s" % (DISTRIBUTION_REPOSITORY, version)


def webhook_url(root: str) -> str:
    config = configparser.ConfigParser()
    path = os.path.join(root, "release_webhook.cfg")
    if not config.read(path):
        sys.exit("release_webhook.cfg не найден в %s" % root)
    return config.get("release", "discord_webhook_url").strip().strip('"')


def read_highlights(release_dir: str, version: str) -> list[str]:
    patch_notes = os.path.join(release_dir, "project", "scripts", "patch_notes_data.gd")
    if os.path.exists(patch_notes):
        import re

        source = open(patch_notes, encoding="utf-8").read()
        match = re.search(r'"version":\s*"%s".*?"highlights":\s*\[(.*?)\]' % re.escape(version), source, re.S)
        if match:
            highlights = re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(1))
            if highlights:
                return [highlight.replace('\\"', '"') for highlight in highlights][:12]
    changelog = os.path.join(release_dir, "CHANGELOG-%s.md" % version)
    if os.path.exists(changelog):
        lines = [line.strip("-* \t").rstrip() for line in open(changelog, encoding="utf-8") if line.strip().startswith(("-", "*"))]
        if lines:
            return lines[:12]
    return []


def post(url: str, content: str, files: list[tuple[str, bytes]], dry_run: bool) -> None:
    if dry_run:
        print("[dry-run] content:\n" + content)
        print("[dry-run] attach:", [name for name, _data in files])
        return
    boundary = "----FantasyDiskRelease"
    body = b""
    body += ("--%s\r\n" % boundary).encode()
    body += b'Content-Disposition: form-data; name="payload_json"\r\nContent-Type: application/json\r\n\r\n'
    body += json.dumps({"username": "FantasyDisk Releases", "content": content[:1900]}).encode() + b"\r\n"
    for index, (name, data) in enumerate(files):
        body += ("--%s\r\n" % boundary).encode()
        body += ('Content-Disposition: form-data; name="files[%d]"; filename="%s"\r\n' % (index, name)).encode()
        content_type = "image/png" if name.lower().endswith(".png") else "application/octet-stream"
        body += ("Content-Type: %s\r\n\r\n" % content_type).encode() + data + b"\r\n"
    body += ("--%s--\r\n" % boundary).encode()
    request = urllib.request.Request(url, data=body, method="POST", headers={"Content-Type": "multipart/form-data; boundary=%s" % boundary, "User-Agent": UA})
    try:
        with urllib.request.urlopen(request) as response:
            print("Discord:", response.status, "— опубликовано ✓")
    except urllib.error.HTTPError as exc:
        sys.exit("Discord ошибка %s: %s" % (exc.code, exc.read().decode()[:200]))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    root = repo_root()
    rel = verify_local_release(root, args.version)
    installers = [f"FantasyDisk-{args.version}-macos.dmg", f"FantasyDisk-{args.version}-windows-setup.exe"]
    poster = f"fantasydisk_{args.version.replace('.', '')}_announcement.png"
    required = [*installers, "SHA256SUMS.txt", "CHANGELOG-%s.md" % args.version, poster]
    missing = [name for name in required if not os.path.isfile(os.path.join(rel, name))]
    if missing:
        sys.exit("Проверенный релиз неполон для Discord: " + ", ".join(missing))
    if os.path.getsize(os.path.join(rel, poster)) > DISCORD_LIMIT:
        sys.exit("Release poster превышает лимит Discord webhook")
    highlights = read_highlights(rel, args.version)
    telegram_link = public_download_url(root)
    lines = ["# 🐉 FantasyDisk v%s" % args.version, ""]
    if highlights:
        lines += ["**✨ Главное:**"] + ["**•** %s" % line for line in highlights[:5]] + [""]
    if len(highlights) > 5:
        lines += ["Также:"] + ["• %s" % line for line in highlights[5:]] + [""]
    lines += [
        "**📨 Скачать файлы (macOS + Windows) в Telegram:**",
        telegram_link,
        "",
        "**🔄 Автообновления и текущий стабильный релиз:**",
        github_release_url(args.version),
        "",
        "_Сборки: %s. SHA256 — во вложении и в Telegram._" % ", ".join(installers),
    ]
    files = []
    for name in ["CHANGELOG-%s.md" % args.version, "SHA256SUMS.txt", poster]:
        path = os.path.join(rel, name)
        if os.path.getsize(path) <= DISCORD_LIMIT:
            files.append((name, open(path, "rb").read()))
    post("dry-run" if args.dry_run else webhook_url(root), "\n".join(lines), files, args.dry_run)


if __name__ == "__main__":
    main()
