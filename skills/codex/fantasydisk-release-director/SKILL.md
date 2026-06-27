---
name: fantasydisk-release-director
description: "Use this skill to cut a FantasyDisk release: bump version, build human-readable + in-game changelog with highlighted key changes, build macOS+Windows installers, and publish the release news + build links to the Discord releases webhook. Trigger on 'release', 'выпустить версию', 'собрать релиз', 'опубликовать релиз'."
---

# FantasyDisk Release Director

Оркестрирует полный выпуск версии FantasyDisk. Репозиторий: `/Users/sergeyfomin/Documents/AI Agent`.

## Когда применять
Пользователь просит выпустить/собрать/опубликовать версию (например «релизим 0.1.5»).

## Обязательный поток релиза
1. **Пре-флайт**: на ветке `dev`, все 6 smoke зелёные, ключевые задачи версии done/QA-passed,
   рабочее дерево без мусора. НЕ релизить с падающими тестами.
2. **Версия**: поднять `config/version` в `project.godot` до X.Y.Z. Версия в правом нижнем
   углу игры (`MainMenuVersionLabel`) подтянется автоматически из config/version. См. память
   version-bump-on-release.
3. **Человекочитаемый changelog**: обновить `CHANGELOG.md` — секция `## [X.Y.Z] — <дата>` с
   понятными пользователю формулировками (без внутренних ID/путей), + новая пустая Unreleased.
4. **In-game changelog «Что нового»**: добавить запись в `scripts/patch_notes_data.gd`
   (PATCH_NOTES, новейшая версия первой): version/date/highlights — ТОЛЬКО русские
   пользовательские формулировки.
5. **Выделить самые важные изменения**: в начале новости и в highlights пометить 3-5
   ГЛАВНЫХ пунктов (звёздочкой/жирным), остальное — обычным списком.
6. **Сборка mac+win**: `tools/build_release.sh X.Y.Z` → `releases/vX.Y.Z/`
   (dmg, windows-setup.exe, windows.zip, SHA256SUMS.txt, CHANGELOG-X.Y.Z.md).
7. **Гит**: коммит, merge `dev`→`main` (--no-ff), тег `vX.Y.Z`, вернуться на dev.
8. **Публикация в Discord** (releases webhook): запустить
   `python3 ~/.codex/skills/fantasydisk-release-director/scripts/release_publish.py --version X.Y.Z`
   — постит новость с ключевыми изменениями + SHA256 + размеры; прикладывает SHA256/changelog, а на сборки даёт ссылку Telegram (из конфига).

## Схема публикации (решение пользователя 2026-06-14)
- **Сборки (mac dmg + win setup.exe/zip) выкладываются в Telegram** (канал/группа загрузок).
- **В Discord постится НОВОСТЬ + ключевые изменения + ссылка на скачивание в Telegram** + SHA256.
  Discord webhook принимает ≤25 МБ — инсталлеры ~200 МБ туда НЕ кладём, только ссылку.
- Telegram-ссылка хранится в `release_webhook.cfg` ([release] telegram_download_url);
  можно переопределить флагом `--download-base <URL>`.
- Шаг загрузки в Telegram: пока вручную (положить файлы из `releases/vX.Y.Z/` в Telegram-канал),
  либо авто-аплоад через Telegram-бота (если задан bot token + бот админ канала) — TODO.
- Секреты (webhook URL, telegram link) — в `release_webhook.cfg` (в `.gitignore`), не коммитить.
  В запрос к Discord ОБЯЗАТЕЛЕН заголовок `User-Agent` (иначе 403).

## Проверки
- `release_publish.py --help` показывает параметры.
- Скрипт компилируется python без ошибок.
- Перед публикацией убедиться, что `releases/vX.Y.Z/` существует и содержит артефакты.

## Документация
Обновить `current_game_state.md` (новая версия), записать вердикт в задачу релиза.
