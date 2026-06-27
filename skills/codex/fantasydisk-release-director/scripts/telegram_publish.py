#!/usr/bin/env python3
"""Загрузка релизных сборок FantasyDisk в Telegram (userbot, Telethon).

Зачем userbot, а не бот: cloud Bot API ограничен 50 МБ, инсталлеры ~200 МБ.
Telethon на пользовательском аккаунте грузит до 2 ГБ.

Конфиг — release_webhook.cfg (корень проекта, в .gitignore), секция [telegram]:
  api_id = 12345           ; с https://my.telegram.org
  api_hash = "..."         ; оттуда же
  session = fantasydisk_release   ; имя файла сессии (создаётся при первом логине)
  chat = "https://t.me/+YOUR_PRIVATE_CHANNEL_INVITE"  ; инвайт-ссылка / @username / id канала

Первый запуск спросит телефон + код (вход в ТВОЙ аккаунт) — делает пользователь сам,
создаётся <session>.session (секрет, в .gitignore). Дальше — без вопросов.

Запуск: python3 telegram_publish.py --version X.Y.Z [--caption "текст"]
"""
import argparse
import configparser
import os
import sys


def cfg(root):
    c = configparser.ConfigParser()
    if not c.read(os.path.join(root, "release_webhook.cfg")):
        sys.exit("release_webhook.cfg не найден")
    if not c.has_section("telegram"):
        sys.exit("В release_webhook.cfg нет секции [telegram] (api_id/api_hash/chat). См. docs/release_telegram_setup.md")
    g = lambda k, d="": c.get("telegram", k, fallback=d).strip().strip('"')
    return g("api_id"), g("api_hash"), g("session", "fantasydisk_release"), g("chat")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=False)
    ap.add_argument("--list-chats", action="store_true", help="показать свои группы и их id (после логина)")
    ap.add_argument("--test", action="store_true", help="отправить тестовое сообщение в chat")
    ap.add_argument("--caption", default="")
    a = ap.parse_args()
    root = os.environ.get("FANTASYDISK_REPO", os.getcwd())

    # --list-chats / --test: не требуют каталога релиза
    if a.list_chats or a.test:
        from telethon.sync import TelegramClient
        from telethon.tl.functions.messages import ImportChatInviteRequest
        api_id, api_hash, session, chat = cfg(root)
        with TelegramClient(os.path.join(root, session), int(api_id), api_hash) as client:
            if a.list_chats:
                print("Твои группы/каналы (id — для поля chat в release_webhook.cfg):")
                for d in client.get_dialogs():
                    if d.is_group or d.is_channel:
                        print("  %s\t%s" % (d.entity.id, d.name))
                return
            # --test: отправить тестовое текстовое сообщение в chat
            entity = client.get_entity(int(chat)) if chat.lstrip("-").isdigit() else chat
            client.send_message(entity, a.caption or "\U0001F9EA Тест канала релизов FantasyDisk. Сюда будут приходить сборки (mac/win) и новости версий.")
            print("Тестовое сообщение отправлено в Telegram ✓")
        return

    if not a.version:
        sys.exit("Укажи --version X.Y.Z (или --list-chats / --test)")
    rel = os.path.join(root, "releases", "v%s" % a.version)
    if not os.path.isdir(rel):
        sys.exit("Нет каталога релиза: %s" % rel)
    files = [os.path.join(rel, f) for f in sorted(os.listdir(rel))
             if f.endswith((".dmg", ".exe", ".zip", ".txt"))]
    if not files:
        sys.exit("Нет файлов сборки в %s" % rel)

    try:
        from telethon.sync import TelegramClient
        from telethon.tl.functions.messages import ImportChatInviteRequest
    except ImportError:
        sys.exit("Нужен Telethon: pip install telethon")

    api_id, api_hash, session, chat = cfg(root)
    if not api_id or not api_hash or not chat:
        sys.exit("Заполни [telegram] api_id/api_hash/chat в release_webhook.cfg")
    session_path = os.path.join(root, session)

    caption = a.caption or ("FantasyDisk v%s — сборки macOS + Windows. SHA256 — в комплекте." % a.version)
    with TelegramClient(session_path, int(api_id), api_hash) as client:
        # резолв целевого чата: числовой id (надёжно) или инвайт-ссылка
        if chat.lstrip("-").isdigit():
            entity = client.get_entity(int(chat))
        elif "+" in chat or "joinchat" in chat:
            invite = chat.rstrip("/").split("/")[-1].lstrip("+")
            try:
                client(ImportChatInviteRequest(invite))
            except Exception:
                pass  # уже участник
            entity = next((d.entity for d in client.get_dialogs() if d.is_group or d.is_channel), chat)
        else:
            entity = chat
        print("Загружаю %d файл(ов) в Telegram..." % len(files))
        # все файлы одним альбомом-сообщением с подписью на первом
        client.send_file(entity, files, caption=caption, force_document=True)
        print("Готово ✓ — сборки опубликованы в Telegram.")


if __name__ == "__main__":
    main()
