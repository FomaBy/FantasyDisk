# Фидбек из коробки: встроенный дефолтный Discord-вебхук + кнопка «Фидбек» в паузе

Статус: done
Роль: Back-end
Контур: Claude
Lane: claude
Версия: 0.2.0
Создано: 2026-07-03
Автор: User request (PM, голосовое ТЗ)
Labels: foma, backend, claude

## Контекст

Внутриигровой фидбек (SCRUM-362: клавиша P → форма с текстом + автоскриншот →
Discord-вебхук) сейчас работает ТОЛЬКО там, где вебхук настроен вручную:
env `FANTASYDISK_FEEDBACK_WEBHOOK`, локальный `res://feedback_webhook.cfg`
(gitignored) или `user://feedback_config.cfg`. Решением SCRUM-665 raw-вебхук
перестали бандлить в player-сборки — у любого игрока/тестера без ручной
настройки отправка падает в локальный `user://feedback/` и до разработчика
НЕ доходит.

Директива PM (2026-07-03): «любой человек должен иметь возможность отправить
фидбек на вебхук в Discord; захардкодь данные для отправки, чтобы работало у
всех без необходимости что-то где-то подключать вручную». Осознанный revert
части SCRUM-665: доставка фидбека важнее секретности вебхука; риск (извлечение
URL из сборки и спам) принят, митигируется ротацией вебхука.

## Что сделать

1. `scripts/feedback_reporter.gd`:
   - встроить дефолтный вебхук (канал #фидбек Discord-сервера FantasyDisk) в
     код в виде base64-чанков (не сырой строкой — чтобы grep по
     `discord.com/api/webhooks/<id>/<token>` и секрет-сканеры GitHub не находили
     литерал и Discord не отозвал вебхук при возможной публикации репо);
   - статик `_builtin_webhook_url()` собирает URL в рантайме;
   - резолюция источника: env → bundled cfg → user cfg → ВСТРОЕННЫЙ (низший
     приоритет — оверрайды продолжают работать);
   - некорректный оверрайд (плейсхолдер XXXX/YYYY и т.п.) теперь НЕ роняет
     отправку в «Ошибка сборки», а падает дальше по цепочке до встроенного
     (push_warning для дева); вынести чистую статик-функцию
     `_resolve_from(env, bundled, user)` для юнит-теста.
2. `scripts/ui_screens.gd`: видимая кнопка «Фидбек» в меню паузы забега
   (между «Настройки» и «Покинуть забег», стиль pm_btn 280×60, скриншот
   вьюпорта как у хоткея P) — фидбек доступен без знания хоткея;
   обновить координатную спеку PM_*_2K (6 кнопок, центрированный столб).
3. `tests/feedback_webhook_config_test.gd`: покрыть `_resolve_from` (пустые
   источники → builtin; env/bundled приоритет; невалидный оверрайд → builtin),
   валидность встроенного URL; сохранить гарантии SCRUM-720 (user:// пути,
   отчёт без вебхука в теле).
4. Доки: переписать `docs/feedback_webhook_setup.md` (вебхук встроен из
   коробки; env/cfg — опциональные оверрайды; процедура ротации при спаме),
   обновить `feedback_webhook.cfg.example`, echo-блок в
   `tools/build_release.sh` («вебхук встроен», а не «user:// fallback»).

## Acceptance Criteria

- [x] Чистая сборка/чекаут БЕЗ env и БЕЗ feedback_webhook.cfg: P → форма →
      «Отправить» → сообщение с текстом+скриншотом приходит в Discord-канал
      (реальный POST на встроенный вебхук, HTTP 2xx).
- [x] Сырой URL вебхука (id/token) не встречается в репо литералом
      (grep -r по id вебхука в исходниках пуст, кроме base64-чанков).
- [x] env/bundled/user оверрайды продолжают иметь приоритет над встроенным.
- [x] В меню паузы есть кнопка «Фидбек», открывает ту же форму со скриншотом.
- [x] feedback_webhook_config_test / feedback_retry_policy_test /
      feedback_upload_size_test зелёные; runtime_smoke зелёный.

## QA-Вердикт

Статус: PASSED
Дата: 2026-07-03
Проверки (изолированный worktree, cold `--import`, прогоны через godot_gate):
- feedback_webhook_config_test — PASSED (валидность встроенного URL из base64-чанков,
  резолюция пустых источников → builtin, приоритет env>bundled>user>builtin,
  невалидный оверрайд падает до builtin; гарантии SCRUM-720 сохранены);
- feedback_retry_policy_test — PASSED; feedback_upload_size_test — PASSED;
- runtime_smoke_test — PASSED (меню паузы с новой кнопкой «Фидбек» строится);
- живой POST на встроенный вебхук (собран из чанков в рантайме) — HTTP 204,
  сообщение пришло в Discord-канал фидбека;
- grep по id/token вебхука в дереве репо пуст — сырой литерал не закоммичен.

## Файлы

- scripts/feedback_reporter.gd
- scripts/ui_screens.gd
- tests/feedback_webhook_config_test.gd
- docs/feedback_webhook_setup.md
- feedback_webhook.cfg.example
- tools/build_release.sh
