# Release & Versioning — FantasyDisk

Обновлено: 2026-06-11
Ведет: PM. Исполняет сборки: Back-end.

## Версионирование

- Схема: **SemVer** `MAJOR.MINOR.PATCH`; до выхода 1.0 — `0.MINOR.PATCH`
  (0.1.0 → 0.2.0 — новые фичи; 0.2.1 — только хотфиксы).
- **Источник истины версии** — `project.godot` → `[application] config/version`.
  Код может читать её через `ProjectSettings.get_setting("application/config/version")`
  (показывать в главном меню мелким текстом).
- Каждый релиз помечается git-тегом `vX.Y.Z` на ветке `main`.
- Версия дублируется в экспорт-пресетах (macOS `application/version`, Windows
  `application/file_version`/`product_version`) — Back-end синхронизирует при сборке.
- История изменений — `CHANGELOG.md` (раздел Unreleased пополняется по ходу dev,
  при релизе переименовывается в номер версии с датой).

## Ветки

```text
main — только релизные состояния. Каждый коммит в main = релиз с тегом vX.Y.Z.
dev  — основная ветка разработки. Все чаты (Backend/Designer/Animator/PM) работают здесь.
```

- Все агенты работают в одном рабочем каталоге, поэтому **текущая checked-out
  ветка всегда dev**. Переключение на main делает только PM в момент релиза.
- Хотфикс релиза: ветка от main → фикс → merge в main (tag vX.Y.Z+1) → merge main в dev.

## Релизный цикл (чек-лист PM)

1. Все задачи версии на доске `done`; документация в `docs/design/` обновлена.
2. Code freeze: новые задачи в dev не выдаются до конца релиза.
3. Backend прогоняет все smoke-тесты + ручной чек-лист (меню, забег, бой, элитка,
   босс, магазин, пауза) на macOS и Windows-сборке.
4. Поднять версию: `config/version` в project.godot + CHANGELOG (Unreleased → X.Y.Z).
5. Коммит в dev → `git checkout main` → `git merge dev --no-ff` → `git tag vX.Y.Z`
   → `git checkout dev`.
6. Backend собирает релизные билды для Windows и macOS (см. ниже) в `releases/vX.Y.Z/`
   (каталог в .gitignore — артефакты не коммитятся).
7. Smoke-проверка установленных билдов. Готово.

## Сборки (Godot 4.6)

Общее правило: **версия export templates обязана совпадать с версией редактора**
(сейчас 4.6). Templates ставятся один раз: Editor → Manage Export Templates.

### macOS
- Пресет `macOS` (уже есть в `export_presets.cfg`), формат экспорта — **.dmg**.
- Подпись: ad-hoc (без Apple Developer аккаунта). У пользователей Gatekeeper
  попросит правый клик → Open при первом запуске — это нормально для не-стора.
- Выход: `releases/vX.Y.Z/FantasyDisk-X.Y.Z-macos.dmg`.

### Windows (собирается с этого же Mac)
- Добавить пресет `Windows Desktop` (x86_64): exe + embedded pck (`binary_format/embed_pck=true`),
  иконка — .ico, сгенерированный из `icon.svg`.
- Для иконки/метаданных exe нужен `rcedit` + wine; если ставить wine нежелательно —
  допустимо собирать без кастомной иконки exe (не блокер релиза).
- «Установочный файл»: инсталлер **NSIS** (`brew install makensis`) — скрипт
  `tools/windows_installer.nsi`, на выходе `FantasyDisk-X.Y.Z-windows-setup.exe`.
  Запасной вариант: zip `FantasyDisk-X.Y.Z-windows.zip` с exe.
- Headless-сборка обеих платформ:
  ```bash
  GODOT="/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot"
  "$GODOT" --headless --path . --export-release "macOS" "releases/vX.Y.Z/FantasyDisk-X.Y.Z-macos.dmg"
  "$GODOT" --headless --path . --export-release "Windows Desktop" "releases/vX.Y.Z/win/FantasyDisk.exe"
  ```
  Обертка: `tools/build_release.sh` (создает Back-end).

## Кроссплатформенная совместимость (правила для всех агентов)

1. **Пути ресурсов чувствительны к регистру** в экспортированных сборках:
   в коде путь `res://...` должен совпадать с именем файла побуквенно
   (на macOS в редакторе ошибка не всплывет, в Windows-сборке — сломается).
2. Сохранения/настройки — только в `user://`, никогда в `res://` (read-only в сборке).
3. Не использовать платформо-специфичные шорткаты/API без `OS.get_name()` проверки.
4. Рендерер проекта должен оставаться совместимым (Forward+ ок для desktop;
   не включать Metal/DirectX-специфику).
5. Каждый релиз тестируется на обеих платформах до публикации.
6. `.godot/`, `build/`, `releases/` не коммитятся.
