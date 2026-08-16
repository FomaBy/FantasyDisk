# Telegram delivery for every stable FantasyDisk release

Обновлено: 2026-07-16 (FAN-1210)

Telegram — обязательный канал файловой доставки, а public binary-only GitHub
repository `FomaBy/FantasyDisk-Releases` — канонический источник updater manifest
и latest downloads. После полного local/public verification Telegram получает
release poster, macOS DMG, Windows Setup и `SHA256SUMS.txt`; затем Discord
публикует player-facing новость с Telegram download link.

## Локальная настройка

Инсталлеры могут превышать лимит Telegram Bot API, поэтому используется Telethon
userbot на аккаунте оператора.

1. Установить `telethon`.
2. Получить `api_id` и `api_hash` на `https://my.telegram.org`.
3. Сохранить их в gitignored `release_webhook.cfg`, секция `[telegram]`; session
   также остаётся локальным секретом.
4. Задать destination и player-facing link одним из способов:

```text
export FANTASYDISK_RELEASE_TG_CHANNEL='https://t.me/your_channel'
export FANTASYDISK_RELEASE_TG_DOWNLOAD_URL='https://t.me/your_channel'
```

   Либо создать ignored `release_tg.cfg` рядом с `release_webhook.cfg`:

```ini
chat = "https://t.me/your_channel"
download_url = "https://t.me/your_channel"
```

   Числовой chat id допустим для upload, но требует отдельного `download_url` для
   Discord. Invite links могут быть использованы только если они подходят игрокам.

## Release gate

После GitHub publication и unauthenticated verification выполните:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version <version> --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version <version>
python3 skills/codex/fantasydisk-release-director/scripts/release_publish.py \
  --version <version>
```

Скрипты fail closed, если durable release не верифицирован, отсутствует один из
четырёх Telegram files, destination/link не настроены или нет нужных credentials.

## Безопасность

`api_id`, `api_hash`, телефонный код и `*.session` — секреты. Их нельзя печатать,
коммитить или передавать в Multica. При компрометации завершите session в Telegram
→ Настройки → Устройства.
