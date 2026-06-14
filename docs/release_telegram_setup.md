# Публикация релизов в Telegram с файлами (Telethon userbot)

Инсталлеры ~200 МБ. Cloud Telegram-БОТ грузит максимум 50 МБ, поэтому для файлов
используется **userbot на твоём аккаунте** (Telethon, до 2 ГБ).

## Настройка (один раз)
1. `pip3 install telethon`
2. Получить **api_id** и **api_hash**: https://my.telegram.org → API development tools.
3. Вписать их в `release_webhook.cfg`, секция `[telegram]` (`api_id`, `api_hash`).
   `chat` уже указывает на канал загрузок (инвайт-ссылку). `session` — имя файла сессии.
4. Первый вход (создаёт сессию): запусти
   `FANTASYDISK_REPO="$PWD" python3 ~/.codex/skills/fantasydisk-release-director/scripts/telegram_publish.py --version <любая_собранная>`
   Telethon спросит **номер телефона + код из Telegram** — введи САМ (это вход в твой
   аккаунт; никому не передавай код). Создастся `fantasydisk_release.session` (в .gitignore).
5. Дальше публикация идёт без вопросов.

## Что делает скилл при релизе
- `telegram_publish.py --version X.Y.Z` — заливает `releases/vX.Y.Z/*` (dmg/exe/zip/SHA256)
  в Telegram-канал одним сообщением с подписью.
- `release_publish.py --version X.Y.Z` — постит в Discord новость + ключевые изменения +
  **ссылку на этот Telegram-канал** + SHA256.

## Безопасность
- api_id/api_hash и `*.session` — секреты, в `.gitignore`. Сессия = доступ к аккаунту;
  при компрометации — разлогинить сессию в Telegram (Настройки → Устройства).
- Код входа из Telegram НЕ передавай никому (включая ассистента).
