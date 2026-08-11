# Discord-вебхук внутриигрового фидбека (SCRUM-362, security review FAN-1040)

Фича: игрок жмёт **P** (или кнопку **«Фидбек»** в меню паузы) → пишет баг +
автоскриншот → репорт уходит в Discord-канал фидбека.

## Security contract

Discord webhook — это credential. Его нельзя хранить в исходниках или player
build даже в Base64/чанках: пользователь может восстановить URL из клиента.
FAN-1040 удалил такой fallback. Значение, попавшее в Git до этого исправления,
отозвано 2026-07-13 (FAN-1041: `DELETE 204`, проверка `404`); новый credential
нельзя добавлять обратно в репозиторий.

Production-доставка идёт только через rate-limited relay из
`services/feedback_proxy/`, который хранит Discord credential на серверной
стороне. Пока endpoint не provisioned и не записан в публичный project setting,
player build сохраняет отчёт локально в `user://feedback/`.

## Production relay

Публичный (не секретный) session endpoint задаётся в `project.godot`:

```ini
[feedback]
relay_session_url="https://feedback.example.org/v1/session"
```

Для локальной отладки приоритетнее env `FANTASYDISK_FEEDBACK_RELAY_URL`, затем
project setting, затем `user://feedback_config.cfg` key `relay_session_url`.
Разрешён только HTTPS URL без query/fragment/userinfo и с точным path
`/v1/session`. Client получает короткоживущий anonymous session token и отправляет
JSON в тот же origin `/v1/feedback`; один UUIDv4 используется как report ID и
`Idempotency-Key` на всех retry.

Relay проверяет auth/session, schema, allowlist метаданных, JPEG type/размер,
server-side IP+installation rate limits и idempotency. Он сам строит Discord
multipart, запрещает mentions и никогда не логирует текст/скриншот/token/webhook.
Поскольку Discord не поддерживает idempotency key, неоднозначный исход после
начала upstream request помечается non-retryable и уходит в local fallback:
at-most-once важнее риска продублировать приватный отчёт.
Deployment/environment/checklist описаны в `services/feedback_proxy/README.md`.

## Provider-neutral staging bundle

`services/feedback_proxy/compose.yaml` описывает один relay replica без
provider-specific ресурсов: origin опубликован только на `127.0.0.1`, root
filesystem read-only, `/tmp` — bounded tmpfs, SQLite хранится на durable named
volume, а CPU/memory/PID и Linux capabilities ограничены. Публичный HTTPS
reverse proxy/WAF остаётся обязательным и не входит в Compose bundle.

`services/feedback_proxy/relay.env.example` содержит полный список имён и
пустые placeholders для server credentials, но не содержит значений. Локальная
детерминированная проверка запускает настоящий relay и fake Discord upstream:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest \
  tests.test_feedback_proxy tests.test_feedback_relay_smoke
```

После отдельного запуска разрешённого staging endpoint redacted smoke принимает
только публичный `/v1/session` URL и параметры теста; server webhook, signing
secret и log salt ему не передаются:

```bash
python3 tools/feedback_relay_smoke.py \
  https://feedback-staging.example.org/v1/session \
  > relay-smoke-evidence.json
python3 tools/scan_release_secrets.py relay-smoke-evidence.json
```

JSON evidence содержит только имена проверок, HTTP status и redacted failure
kind. Smoke проверяет health, session, text-only, image, повтор того же key,
same-key conflict и fail-closed timeout/error. Это no-cost staging preparation,
а не production activation: `relay_session_url` остаётся пустым до отдельного
операционного одобрения, privacy/retention gate, production secrets, HTTPS/DNS,
durable backup и необходимых финансовых подтверждений.

## Direct Discord — только debug

Raw Discord transport вообще не читается release build. В debug build порядок:

1. env `FANTASYDISK_FEEDBACK_WEBHOOK` (dev-машина/CI);
2. `res://feedback_webhook.cfg` (локальный dev-оверрайд, gitignored,
   см. `feedback_webhook.cfg.example`);
3. `user://feedback_config.cfg` (legacy/пользовательский оверрайд).

Невалидный source игнорируется без печати URL. Если relay не настроен, release
никогда не падает обратно на direct Discord: отчёт сохраняется локально.

## Выполненная ротация после FAN-1040

1. Старый встроенный webhook удалён через Discord API 2026-07-13.
2. Контрольный запрос после удаления возвращает `404`.
3. Новый webhook можно создавать только для server/proxy intake.
4. Новый URL должен жить в secret storage сервера/CI, не в Git и не в клиенте.

## Как это работает

- Production client шлёт relay-owned JSON schema с текстом, allowlisted
  метаданными и base64 JPG (до 1280px, q0.72). Relay, а не клиент, формирует
  Discord multipart. Debug-only direct transport остаётся для разработчиков.
- Session/upload имеют отдельные phase guards: поздний callback/timer старой
  фазы не может затронуть новый upload. 401 обновляет session один раз; 409,
  429, 5xx и сетевые ошибки ретраятся с тем же report UUID и теми же bytes.
- Нет сети / Discord недоступен / вебхук удалён → репорт сохраняется локально
  в `user://feedback/<timestamp>_<report-uuid>/` (полный PNG), UI показывает
  понятную причину. Успех — только после HTTP 2xx от relay/debug transport.

Release pipeline запускает `tools/scan_release_secrets.py` по DMG, Windows EXE,
installer и ZIP до публикации checksums; macOS DMG предварительно монтируется
read-only, чтобы сканировать app/PCK, а ZIP проверяется и как контейнер, и по
распакованным entries. Scanner не печатает найденный secret и ловит raw, full
Base64 и соседние quoted split-Base64 webhook значения.

`relay_session_url` должен оставаться пустым и online delivery выключенным, пока
не готовы player-facing disclosure (скриншот, game/OS metadata, persistent
installation UUID, edge IP), retention/operator policy и staging load/TLS tests.
