# Внутриигровой фидбек: локальный fallback и dev webhook

Фича: игрок жмёт **P** (или кнопку **«Фидбек»** в меню паузы) → пишет баг +
автоскриншот → репорт сохраняется локально и, при явной dev-конфигурации,
отправляется в Discord-канал фидбека.

## Security contract (FAN-1040)

Discord webhook — credential. Base64, разбиение на чанки и build-time injection
не делают его секретным внутри клиентского export. Поэтому source и player build
не содержат webhook. Без server-side relay игра fail-closed: сохраняет полный
report в `user://feedback/` и честно сообщает, удалось ли локальное I/O.

Webhook, ранее встроенный в git/export, считается скомпрометированным и должен
быть отозван в Discord. Возвращать его или новый credential в source запрещено;
это гейтит `tools/quality_static_guard.py`.

## Приоритет источников URL

1. env `FANTASYDISK_FEEDBACK_WEBHOOK` (дев-машина/CI);
2. `res://feedback_webhook.cfg` (локальный dev-оверрайд, gitignored,
   см. `feedback_webhook.cfg.example`);
3. `user://feedback_config.cfg` (legacy/пользовательский оверрайд);
4. валидного URL нет → только проверенный локальный fallback.

Невалидный оверрайд (плейсхолдер `XXXX/YYYY`, чужой домен) игнорируется с
`push_warning`; если следующего валидного источника нет, сеть не вызывается.

## Dev-настройка

1. Создать отдельный ограниченный dev webhook.
2. Передать его только через `FANTASYDISK_FEEDBACK_WEBHOOK` или скопировать
   `feedback_webhook.cfg.example` в gitignored `feedback_webhook.cfg`.
3. Не коммитить config, URL, его base64 или части токена.

Production network delivery должна идти на rate-limited server-side relay,
который хранит Discord credential вне клиента. До появления relay локальный
fallback — ожидаемое поведение player build.

## Как это работает

- Игра шлёт `multipart/form-data` на вебхук: `payload_json.content` (текст
  бага + метаданные: версия, персонаж, возвышение, экран, разрешение, ОС,
  время) и `files[0]` — ужатый JPG-скриншот (даунскейл до 1280px, q0.72 —
  лимит вложений вебхука, SCRUM-460). Ретраи с бэкоффом на таймаутах/5xx/429
  (SCRUM-547).
- Нет сети / Discord недоступен / вебхук удалён → репорт сохраняется локально
  в `user://feedback/` (полный PNG), UI показывает понятную причину. Успех —
  только после HTTP 2xx от вебхука.
