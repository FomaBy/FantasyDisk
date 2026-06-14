# BUG: Фидбек-вебхук — текст доходит в Discord, скриншот НЕ прикрепляется

Статус: new
Приоритет: high
Роль: Back-end (сеть/UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: QA (пользовательский E2E-репорт)
Jira: pending sync
Связано: SCRUM-362 (фича фидбека по P), HEAD-коммит «вебхук проверен (Discord 204 OK)»

## Симптом (пользовательский E2E 2026-06-14)
Пользователь прогнал END-TO-END тест фидбека «как шлёт игра» (payload_json +
files[0] + User-Agent). В Discord **пришёл только текст** сообщения; **картинка-
скриншот НЕ прикрепилась**. Запрос при этом успешен (Discord возвращает 204).

## QA-анализ корня (фактический)
Сгенерировал реальный `FeedbackReporter.multipart_payload(...)` игры и
проинспектировал байты:
- multipart структурно КОРРЕКТЕН: границы `--<boundary>` (CRLF), part `payload_json`
  (Content-Type application/json), part `files[0]` с `filename="fantasydisk_feedback.png"`
  + `Content-Type: image/png`, PNG-сигнатура `\x89PNG` цела (на байте 379/585),
  закрывающая граница `--<boundary>--` корректна.
- **НО** `payload_json` собирается как `JSON.stringify({"content": ...})` —
  **без массива `attachments`** (`scripts/feedback_reporter.gd:64`).

Текущий Discord API (v10): когда в multipart присутствует поле `payload_json`,
загружаемые файлы НУЖНО явно объявлять массивом `attachments`, где `id`
соответствует индексу `files[N]`. Без этого Discord принимает запрос (204),
публикует `content`, но **неассоциированный файл отбрасывает** — ровно наблюдаемый
симптом (текст есть, картинки нет, 204).

## Воспроизведение
1. Настроить `feedback_webhook.cfg`/env с реальным Discord webhook URL.
2. В игре нажать `P`, ввести текст, «Отправить» (или прогнать E2E-скрипт,
   реплицирующий `multipart_payload`).
3. Discord: приходит текст без вложенной картинки.

## Предлагаемый фикс (Back-end)
В `scripts/feedback_reporter.gd:multipart_payload` (стр.62-75) добавить в
`payload_json` массив `attachments`, ссылающийся на `files[0]`:

```gdscript
var payload_json := JSON.stringify({
    "content": discord_content(text, metadata),
    "attachments": [{"id": 0, "filename": "fantasydisk_feedback.png"}],
})
```

`filename` в `attachments[0]` должен совпадать с `filename` в Content-Disposition
части `files[0]`. После фикса — E2E-проверка: реальный POST на Discord webhook
показывает картинку во вложении.

## Files / IDs
- `scripts/feedback_reporter.gd` (`multipart_payload` 62-75; `discord_content` 55)
- `tests/runtime_smoke_test.gd` / `runtime_smoke_ui_test.gd` (multipart payload
  проверка — расширить ассертом на наличие `attachments[0].filename` ==
  Content-Disposition filename, чтобы регрессия ловилась автоматически)

## Acceptance Criteria
- [ ] `payload_json` содержит `attachments:[{"id":0,"filename":"fantasydisk_feedback.png"}]`,
      filename совпадает с частью `files[0]`.
- [ ] E2E: реальный Discord webhook показывает текст И прикреплённый скриншот.
- [ ] Smoke-ассерт на attachments↔filename соответствие (ловит регрессию без сети).
- [ ] Локальный фолбэк/оффлайн-поведение не сломаны; runtime_smoke зелёный; CHANGELOG.

## Документация
docs/design/systems/feedback_reporting.md (формат multipart/attachments),
docs/feedback_webhook_setup.md при необходимости.

## QA-нота к SCRUM-362
Вердикт SCRUM-362 (PASSED) опирался на СТРУКТУРНЫЙ тест `multipart_payload` (форма
байтов) + локальный фолбэк + визуал формы — он НЕ проверял фактическое поведение
Discord-attachment (E2E). Этот класс дефекта (структура валидна, но реальная
интеграция отбрасывает файл) ловится только живым POST. Урок: для сетевых
интеграций нужен E2E с реальным эндпоинтом, не только структурный ассерт.
