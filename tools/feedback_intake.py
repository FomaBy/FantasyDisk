#!/usr/bin/env python3
"""Приём фидбека из Discord-канала FantasyDisk для триажа PM.

Вебхук пишет фидбек в Discord; читать сообщения вебхук НЕ может — нужен Discord-бот
с правом Read Message History на канале фидбека.

- channel_id выводится из `feedback_webhook.cfg` (GET webhook -> channel_id).
- Bot-токен: macOS Keychain, сервис `fantasydisk-discord-bot`
  (`security add-generic-password -s fantasydisk-discord-bot -a fantasydisk -w <TOKEN>`).
- Дедуп: `tools/.feedback_intake_state.json` (last_seen message id; в .gitignore).
- Вложения (скриншоты) скачиваются в `build/feedback_intake/<msg_id>/`.
- Вывод: JSON-список НОВЫХ фидбеков для триажа (PM сам решает, что заводить в таски).

Запуск: python3 tools/feedback_intake.py [--limit N] [--all]
"""
import base64
import configparser
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEBHOOK_CFG = os.path.join(ROOT, "feedback_webhook.cfg")
STATE_PATH = os.path.join(ROOT, "tools", ".feedback_intake_state.json")
ATTACH_DIR = os.path.join(ROOT, "build", "feedback_intake")
API = "https://discord.com/api/v10"
KEYCHAIN_SERVICE = "fantasydisk-discord-bot"
UA = "FantasyDisk-Feedback/1.0"


def bot_token() -> str:
    return subprocess.check_output(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
        text=True).strip()


def webhook_channel_id() -> str:
    cfg = configparser.ConfigParser()
    cfg.read(WEBHOOK_CFG)
    url = cfg.get("feedback", "discord_webhook_url").strip().strip('"')
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return str(json.loads(urllib.request.urlopen(req).read())["channel_id"])


def api_get(path: str, token: str):
    req = urllib.request.Request(API + path,
                                 headers={"Authorization": "Bot " + token,
                                          "User-Agent": UA})
    return json.loads(urllib.request.urlopen(req).read())


def load_state() -> dict:
    return json.load(open(STATE_PATH)) if os.path.exists(STATE_PATH) else {}


def save_state(state: dict) -> None:
    json.dump(state, open(STATE_PATH, "w"), indent=1)


def main() -> None:
    limit = 100
    take_all = "--all" in sys.argv
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])
    token = bot_token()
    channel = webhook_channel_id()
    state = load_state()
    last = state.get("last_seen_id")
    query = "?limit=%d" % limit + ("" if (take_all or not last) else "&after=%s" % last)
    try:
        messages = api_get("/channels/%s/messages%s" % (channel, query), token)
    except urllib.error.HTTPError as e:
        sys.stderr.write("Discord API %s: %s\n" % (e.code, e.read().decode()[:200]))
        sys.stderr.write("Проверь, что бот добавлен на сервер и имеет доступ к каналу.\n")
        raise
    messages = sorted(messages, key=lambda m: int(m["id"]))  # старые -> новые
    out = []
    for m in messages:
        attachments = []
        for a in m.get("attachments", []):
            url = a.get("url", "")
            local = ""
            if url:
                d = os.path.join(ATTACH_DIR, m["id"])
                os.makedirs(d, exist_ok=True)
                local = os.path.join(d, a.get("filename", "attachment"))
                try:
                    req = urllib.request.Request(url, headers={"User-Agent": UA})
                    open(local, "wb").write(urllib.request.urlopen(req).read())
                except Exception as ex:
                    local = "DOWNLOAD_FAILED: %s" % ex
            attachments.append({"filename": a.get("filename"), "url": url, "local": local})
        out.append({
            "id": m["id"],
            "timestamp": m.get("timestamp"),
            "author": (m.get("author") or {}).get("username"),
            "webhook_id": m.get("webhook_id"),
            "content": m.get("content", ""),
            "attachments": attachments,
        })
    if out:
        state["last_seen_id"] = out[-1]["id"]
        save_state(state)
    print(json.dumps({"new_count": len(out), "channel_id": channel, "feedback": out},
                     ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
