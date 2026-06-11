# Задача Для Back-end-Агента: Релизные Сборки v0.1.0 — Windows И macOS

Статус: done 2026-06-11. Результат: releases/v0.1.0/ содержит FantasyDisk-0.1.0-macos.dmg (102MB, смонтирован, оконный запуск до главного меню — OK, ad-hoc подпись), FantasyDisk-0.1.0-windows-setup.exe (59MB, NSIS/lzma, Program Files + ярлыки + деинсталлятор) и FantasyDisk-0.1.0-windows.zip (69MB, запаска). Все собрано из тега v0.1.0 через git worktree (checkout тега в рабочем каталоге не делался — параллельные агенты; зафиксировано как стандарт в release_versioning.md). Windows-шаблоны 4.6.3 установлены из официального tpz; icon.ico 16-256 сгенерирован из icon.svg. ВАЖНЫЙ НЮАНС: makensis на macOS требует LC_ALL=en_US.UTF-8 — в C-локали падает с фиктивным bad_alloc из-за iconv wchar_t (воспроизводится даже на бандловом примере NSIS); решение зашито в build_release.sh и задокументировано. НЕ ПРОВЕРЕНО НА MAC: запуск Windows exe и инсталлера — нужен тест пользователя на Windows-машине (установка, ярлыки, запуск до меню, деинсталляция). Повторный прогон tools/build_release.sh 0.1.0 воспроизводит артефакты одной командой.
Создано: 2026-06-11
Автор: PM

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи, включая установку
инструментов сборки через Homebrew (makensis; wine — только если потребуется для
иконки exe и не иначе как с фиксацией в отчете).

## Роль И Границы
Ты — Back-end-агент (сборка, экспорт, инфраструктура). Процесс релизов описан в
`docs/process/release_versioning.md` — он источник истины; противоречия — сообщить PM.

## Контекст
Проект зафиналлен как v0.1.0: тег `v0.1.0` на ветке `main`, рабочая ветка — `dev`.
`config/version="0.1.0"` уже прописан в project.godot. Экспорт-пресет есть только
для macOS. Нужны установочные файлы обеих платформ с текущей версии.

ВАЖНО: собирать из тега v0.1.0 (`git stash` при необходимости → `git checkout v0.1.0`
→ сборка → `git checkout dev` → `git stash pop`). Артефакты класть в `releases/v0.1.0/`
(каталог в .gitignore).

## Требования
1. **Export templates 4.6**: убедиться, что установлены templates ровно под версию
   редактора (Godot 4.6); если нет — установить
   (`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot` поддерживает headless установку или скачать tpz).
2. **Windows-пресет**: добавить в `export_presets.cfg` пресет `Windows Desktop`
   (x86_64, `binary_format/embed_pck=true`). Сгенерировать `assets/icon.ico` из
   `icon.svg` (мультиразмерный 16-256). Если для встраивания иконки нужен
   rcedit+wine и wine ставить нецелесообразно — собрать без кастомной иконки exe
   и зафиксировать это в отчете (не блокер).
3. **Версии в пресетах**: проставить 0.1.0 в полях версий обоих пресетов
   (macOS `application/version`/`short_version`, Windows `application/file_version="0.1.0.0"`,
   `product_version`), название продукта FantasyDisk.
4. **Скрипт сборки** `tools/build_release.sh`: принимает версию, читает/сверяет
   `config/version`, собирает обе платформы headless в `releases/v<версия>/`:
   - `FantasyDisk-<версия>-macos.dmg` (экспорт macOS в dmg, ad-hoc подпись);
   - Windows exe → затем инсталлер.
5. **Windows-инсталлер**: `brew install makensis`, написать `tools/windows_installer.nsi`
   (NSIS): установка в Program Files, ярлыки в меню Пуск/на рабочий стол, деинсталлятор.
   Выход: `FantasyDisk-0.1.0-windows-setup.exe`. Дополнительно положить и просто
   zip с exe как запасной вариант.
6. **Проверка**: dmg смонтировать и запустить приложение (полный запуск до главного
   меню); Windows exe — минимум проверить, что файл собрался ненулевого размера и
   инсталлер создается без ошибок (запуск Windows-бинаря на Mac невозможен — отметить
   в отчете, что нужен тест на реальной Windows-машине пользователем).
7. **Документация**: дополнить `docs/process/release_versioning.md` фактическими
   командами/нюансами, выявленными при сборке; обновить `docs/design/current_game_state.md`
   (раздел «Проект»: версия, платформы).

## Files / Assets / IDs
- `export_presets.cfg`, `project.godot`, `icon.svg` → `assets/icon.ico`.
- Новые: `tools/build_release.sh`, `tools/windows_installer.nsi`.
- Выход: `releases/v0.1.0/FantasyDisk-0.1.0-macos.dmg`,
  `releases/v0.1.0/FantasyDisk-0.1.0-windows-setup.exe`, `...-windows.zip`.

## Acceptance Criteria
- [ ] Оба артефакта лежат в `releases/v0.1.0/` и собраны из тега v0.1.0.
- [ ] dmg монтируется, игра запускается до меню, версия 0.1.0 корректна.
- [ ] NSIS-инсталлер собирается без ошибок; zip-запаска есть.
- [ ] `tools/build_release.sh` воспроизводит сборку одной командой.
- [ ] Изменения инфраструктуры (пресеты, скрипты, ico) закоммичены в ветку dev.
- [ ] Документация обновлена; в отчете — что протестировано и что осталось проверить на Windows.

## Самопроверка
- Повторный прогон `tools/build_release.sh 0.1.0` с чистого состояния — артефакты
  воспроизводятся.
- `git status` чистый после работы (артефакты не попали в индекс).
