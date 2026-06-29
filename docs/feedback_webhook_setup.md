# Настройка Discord-вебхука для внутриигрового фидбека (SCRUM-362)

Фича: игрок жмёт **P** → пишет баг + автоскриншот → репорт уходит тебе в Discord.

## Шаги (один раз)
1. В Discord: выбери сервер/канал для багов → **Настройки канала → Интеграции →
   Вебхуки → Новый вебхук** → задай имя (напр. «FantasyDisk Feedback») →
   **Копировать URL вебхука**.
2. Для локального релиза в корне проекта скопируй `feedback_webhook.cfg.example`
   → `feedback_webhook.cfg` и вставь URL в поле `discord_webhook_url`.
3. Для CI/чистой машины задай переменную окружения
   `FANTASYDISK_FEEDBACK_WEBHOOK`; `tools/build_release.sh` сам создаст
   gitignored `feedback_webhook.cfg` в release-worktree перед экспортом.
4. Готово. Реальный URL не коммитится и не печатается в лог; release-сборка
   остановится, если webhook не найден или env выглядит некорректно.

## Как это работает
- Игра при отправке шлёт `multipart/form-data` на этот URL: `payload_json.content`
  (текст бага + метаданные: версия, персонаж, возвышение, экран, разрешение,
  ОС, время), `payload_json.attachments[0]` с именем
  `fantasydisk_feedback.jpg`, и `files[0]` (ужатый JPG-скриншот). Discord
  показывает сообщение с картинкой в канале; локальный fallback хранит полный PNG.
- Если URL не задан/некорректен/нет сети — репорт сохраняется локально в
  `user://feedback/` (не теряется), а UI показывает понятную config/offline/send
  failure причину. Успех показывается только после успешного HTTP-ответа webhook.

## Безопасность
- Webhook URL — секрет: не коммить, не публикуй. Если утёк — удали вебхук в
  Discord и создай новый, обнови `feedback_webhook.cfg`.
