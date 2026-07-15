# Telegram: переходный релиз v0.2.2

Обновлено: 2026-07-15

Telegram больше не является основным хостингом сборок. Канонические загрузки и
механизм обновления используют публичные GitHub Releases. `v0.2.2` — последний
и единственный новый релиз, который по требованию пользователя дополнительно
доставляется в Telegram. `telegram_publish.py` fail-closed отклоняет версии выше
`0.2.2` ещё до проверки credentials или файлов.

## Настройка для v0.2.2

Инсталлеры могут превышать лимит Telegram Bot API, поэтому используется Telethon
userbot на аккаунте оператора.

1. Установить `telethon`.
2. Получить `api_id` и `api_hash` на `https://my.telegram.org`.
3. Сохранить их в gitignored `release_webhook.cfg`, секция `[telegram]`; session
   также остаётся локальным секретом.
4. Задать канал через `FANTASYDISK_RELEASE_TG_CHANNEL` или gitignored
   `release_tg.cfg`.
5. После успешных build/local verify/GitHub publish выполнить:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version 0.2.2 --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version 0.2.2
```

Discord-анонс для 0.2.2 всё равно ведёт на GitHub Release; Telegram — только
дополнительная копия. Для 0.2.3 и всех последующих релизов шаг Telegram полностью
пропускается.

## Безопасность

`api_id`, `api_hash`, телефонный код и `*.session` — секреты. Их нельзя печатать,
коммитить или передавать агенту. При компрометации сессию нужно завершить в
Telegram → Настройки → Устройства.
