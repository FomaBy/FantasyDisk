#!/usr/bin/env python3
"""Mandatory FantasyDisk file delivery to Telegram through Telethon userbot.

Each stable release sends the release poster, macOS DMG, Windows Setup and
SHA256SUMS from the verified durable copy. GitHub remains the canonical updater
host; Telegram is the mandatory player-facing file-delivery channel.
"""

import argparse
import configparser
import json
import os
import subprocess
import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[4] / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import RELEASE_VERSION_RE, is_valid_release_version

def ensure_telegram_release_version(version: str) -> None:
    if not is_valid_release_version(version):
        sys.exit("Версия должна иметь формат X.Y.Z или X.Y.Z.R")


def verify_local_release(root: str, version: str) -> str:
    helper = os.path.join(os.path.dirname(__file__), "local_release.py")
    result = subprocess.run(
        [sys.executable, helper, "verify", "--version", version, "--repo-root", root],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        sys.exit("Локальная копия релиза не прошла проверку; Telegram upload запрещён")
    try:
        return json.loads(result.stdout)["local_release"]
    except (KeyError, TypeError, json.JSONDecodeError):
        sys.exit("Локальная проверка не вернула путь к проверенным байтам релиза")


def cfg(root: str) -> tuple[str, str, str]:
    """API access from release_webhook.cfg [telegram], without printing secrets."""
    config = configparser.ConfigParser()
    if not config.read(os.path.join(root, "release_webhook.cfg")):
        sys.exit("release_webhook.cfg не найден")
    if not config.has_section("telegram"):
        sys.exit("В release_webhook.cfg нет секции [telegram] (api_id/api_hash). См. docs/release_telegram_setup.md")
    value = lambda key, default="": config.get("telegram", key, fallback=default).strip().strip('"')
    return value("api_id"), value("api_hash"), value("session", "fantasydisk_release")


def _release_channel_config(root: str) -> tuple[str, str]:
    path = os.path.join(root, "release_tg.cfg")
    channel = ""
    download_url = ""
    if not os.path.exists(path):
        return channel, download_url
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith((";", "#", "[")):
                continue
            if "=" not in line and not channel:
                channel = line.strip().strip('"')
                continue
            key, value = line.split("=", 1)
            key = key.strip().lower()
            value = value.strip().strip('"')
            if key in {"chat", "channel"}:
                channel = value
            elif key in {"download_url", "telegram_download_url"}:
                download_url = value
    return channel, download_url


def resolve_channel(root: str) -> str:
    channel = os.environ.get("FANTASYDISK_RELEASE_TG_CHANNEL", "").strip().strip('"')
    if channel:
        return channel
    configured_channel, _download_url = _release_channel_config(root)
    if configured_channel:
        return configured_channel
    sys.exit(
        "Telegram-канал релизов не задан. Задай FANTASYDISK_RELEASE_TG_CHANNEL "
        "или gitignored release_tg.cfg (chat = \"https://t.me/...\")."
    )


def public_download_url(root: str) -> str:
    """Return the player-facing Telegram link required in the Discord announcement."""
    direct = os.environ.get("FANTASYDISK_RELEASE_TG_DOWNLOAD_URL", "").strip().strip('"')
    if direct:
        return direct
    channel, configured_url = _release_channel_config(root)
    if configured_url:
        return configured_url
    channel = channel or os.environ.get("FANTASYDISK_RELEASE_TG_CHANNEL", "").strip().strip('"')
    if channel.startswith("https://t.me/") or channel.startswith("http://t.me/"):
        return channel
    if channel.startswith("@") and len(channel) > 1:
        return "https://t.me/" + channel[1:]
    sys.exit(
        "Нужна player-facing Telegram download link: задай "
        "FANTASYDISK_RELEASE_TG_DOWNLOAD_URL или download_url в release_tg.cfg."
    )


def _release_files(release_dir: str, version: str) -> tuple[str, list[str]]:
    poster = os.path.join(release_dir, f"fantasydisk_{version.replace('.', '')}_announcement.png")
    build_files = [
        os.path.join(release_dir, f"FantasyDisk-{version}-macos.dmg"),
        os.path.join(release_dir, f"FantasyDisk-{version}-windows-setup.exe"),
        os.path.join(release_dir, "SHA256SUMS.txt"),
    ]
    missing = [path for path in [poster, *build_files] if not os.path.isfile(path)]
    if missing:
        sys.exit("Проверенный релиз неполон для Telegram: " + ", ".join(os.path.basename(path) for path in missing))
    return poster, build_files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=False)
    parser.add_argument("--list-chats", action="store_true", help="показать свои группы и их id")
    parser.add_argument("--test", action="store_true", help="отправить тестовое сообщение в канал")
    parser.add_argument("--caption", default="")
    parser.add_argument("--dry-run", action="store_true", help="проверить канал и файлы без отправки")
    args = parser.parse_args()
    root = os.environ.get("FANTASYDISK_REPO", os.getcwd())

    if args.list_chats or args.test:
        from telethon.sync import TelegramClient

        api_id, api_hash, session = cfg(root)
        with TelegramClient(os.path.join(root, session), int(api_id), api_hash) as client:
            if args.list_chats:
                print("Твои группы/каналы (id — для FANTASYDISK_RELEASE_TG_CHANNEL / release_tg.cfg):")
                for dialog in client.get_dialogs():
                    if dialog.is_group or dialog.is_channel:
                        print("  %s\t%s" % (dialog.entity.id, dialog.name))
                return
            chat = resolve_channel(root)
            entity = client.get_entity(int(chat)) if chat.lstrip("-").isdigit() else chat
            client.send_message(entity, args.caption or "🧪 Тест канала релизов FantasyDisk.")
            print("Тестовое сообщение отправлено в Telegram ✓")
        return

    if not args.version:
        sys.exit("Укажи --version X.Y.Z или X.Y.Z.R (или --list-chats / --test)")
    ensure_telegram_release_version(args.version)
    rel = verify_local_release(root, args.version)
    poster, build_files = _release_files(rel, args.version)
    chat = resolve_channel(root)
    download_link = public_download_url(root)
    caption = args.caption or ("FantasyDisk v%s — проверенные сборки macOS + Windows." % args.version)

    if args.dry_run:
        print("[dry-run] канал настроен; player link:", download_link)
        print("[dry-run] poster:", os.path.basename(poster))
        for path in build_files:
            print("[dry-run] file:", os.path.basename(path))
        print("[dry-run] ничего не отправлено.")
        return

    try:
        from telethon.sync import TelegramClient
        from telethon.tl.functions.messages import CheckChatInviteRequest, ImportChatInviteRequest
    except ImportError:
        sys.exit("Нужен Telethon: pip install telethon")

    api_id, api_hash, session = cfg(root)
    if not api_id or not api_hash:
        sys.exit("Заполни [telegram] api_id/api_hash в release_webhook.cfg")
    with TelegramClient(os.path.join(root, session), int(api_id), api_hash) as client:
        if chat.lstrip("-").isdigit():
            entity = client.get_entity(int(chat))
        elif "+" in chat or "joinchat" in chat:
            invite = chat.rstrip("/").split("/")[-1].lstrip("+")
            checked = client(CheckChatInviteRequest(invite))
            entity = getattr(checked, "chat", None)
            if entity is None:
                joined = client(ImportChatInviteRequest(invite))
                joined_chats = list(getattr(joined, "chats", []))
                if len(joined_chats) != 1:
                    sys.exit("Не удалось однозначно определить Telegram-канал по invite link")
                entity = joined_chats[0]
        else:
            entity = chat
        client.send_file(entity, poster, caption=caption, force_document=False)
        client.send_file(
            entity,
            build_files,
            caption="FantasyDisk v%s — DMG, Windows Setup и SHA256. %s" % (args.version, download_link),
            force_document=True,
        )
    print("Готово ✓ — poster, DMG, Windows Setup и SHA256 опубликованы в Telegram.")


if __name__ == "__main__":
    main()
