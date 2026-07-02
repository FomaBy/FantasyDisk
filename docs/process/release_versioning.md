# Release & Versioning — FantasyDisk

Обновлено: 2026-07-02
Ведет: PM. Исполняет сборки: Back-end.

## Версионирование

- Схема: **SemVer** `MAJOR.MINOR.PATCH`; до выхода 1.0 — `0.MINOR.PATCH`
  (0.1.0 → 0.2.0 — новые фичи; 0.2.1 — только хотфиксы).
- Текущий active target: `0.2.0`. Плановые `0.1.8` и `0.1.9` отменены/superseded:
  не создавать под них sprint, Jira fixVersion, changelog-финализацию или release
  tasks. После `0.2.0` следующая patch-линия: `0.2.1`, `0.2.2`, ...
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
3a. **Гейт «чистый HEAD зелёный»** (урок SCRUM-171, 2026-06-13): smoke на рабочем
   дереве НЕ достаточно — прогнать 6 сьютов на ЧИСТОМ `git worktree --detach HEAD`
   с предварительным `--import`. Это ловит ситуацию «done, но код не закоммичен»
   (вызовы есть в HEAD, определения — в несведённом дереве). Красный чистый HEAD —
   блокер релиза.
4. **CHANGELOG — ОБЯЗАТЕЛЬНЫЙ ШАГ КАЖДОГО ДЕПЛОЯ** (правило пользователя, 2026-06-12):
   - финализировать раздел версии: Unreleased → `## [X.Y.Z] — дата`;
   - сверить ПОЛНОТУ с фактическим составом релиза: `git log v<пред>..HEAD --oneline` —
     каждое игровое/видимое изменение должно иметь пункт (внутренние docs/чекпоинты
     можно опускать); пункты — человеческим языком, для игрока/тестера;
   - создать новый пустой раздел Unreleased сверху.
   Релиз без финализированного changelog НЕ выполняется — это блокирующий гейт.
5. Поднять версию: `config/version` в project.godot.
6. Коммит в dev → `git checkout main` → `git merge dev --no-ff` → `git tag vX.Y.Z`
   → `git checkout dev`.
7. Backend собирает релизные билды для Windows и macOS (см. ниже) в `releases/vX.Y.Z/`
   (каталог в .gitignore — артефакты не коммитятся).
8. Положить копию changelog версии в артефакты релиза:
   `releases/vX.Y.Z/CHANGELOG-X.Y.Z.md` (раздел версии из CHANGELOG.md) — чтобы
   получатель билда видел, что нового, без доступа к репозиторию.
9. Smoke-проверка установленных билдов.
10. **Jira-спринт и Jira-релиз** (правило пользователя 2026-06-12: спринт = релиз):
    - завершить активный спринт (complete) на доске SCRUM;
    - пометить Jira-версию X.Y.Z released (Releases проекта SCRUM), в описание
      версии — краткий ченджлог + ссылка releases/vX.Y.Z/CHANGELOG-X.Y.Z.md;
    - создать следующую Jira-версию X.Y.Z+1 (unreleased) с кратким описанием
      плана; создать и запустить «Спринт X.Y.Z+1»;
    - tools/jira_board_sync.py автоматически ставит новым тикетам
      fixVersion = версия из имени активного спринта (тикеты «Версия: <след>»
      остаются в бэклоге без fixVersion до своего спринта).
11. **Патч-ноуты в игре**: обновить игровой файл патч-ноутов (см. задачу
    backend_ingame_patch_notes_task.md / экран «Что нового») — человекочитаемые
    заметки версии для игрока, по-русски, синхронно с CHANGELOG. Это часть
    блокирующего changelog-гейта шага 4. Готово.

## Feature Block

Feature block 0.1.5 снят релизом v0.1.5 (2026-06-15). На 2026-07-02 активной
freeze-директивы нет; текущий Jira sprint/release target — `0.2.0`. При следующей
стабилизации PM включает freeze отдельной директивой: в текущий релиз остаются
уже заведенные строки доски, bugfix/QA defect/regression/release-blocker задачи
и явно разрешенные PM исключения; новые не-баговые фичи уходят в следующую
SemVer patch/minor версию.

Исторически блок 0.1.3 был снят релизом v0.1.3 (2026-06-12); механизм остается
тем же для каждой релизной стабилизации.

## Сборки (Godot 4.7)

Общее правило: **версия export templates обязана совпадать с версией редактора**
(сейчас 4.7). Templates ставятся один раз: Editor → Manage Export Templates.

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


## Фактические Нюансы Сборки (выявлено при v0.1.0)

- Сборка из тега идет через **отдельный git worktree** (`git worktree add --detach /tmp/... vX.Y.Z`),
  а не checkout в рабочем каталоге: в каталоге параллельно работают другие агенты,
  переключение ветки под ними недопустимо. Реализовано в `tools/build_release.sh`.
- Свежая сборочная инфраструктура (export_presets.cfg, assets/icon.ico) копируется
  в worktree поверх тега — старые теги могли не содержать Windows-пресет.
- **Export templates**: проверка `~/Library/Application Support/Godot/export_templates/<версия>/`;
  Windows-шаблоны ставятся из официального tpz (godotengine releases), распаковать
  `windows_release_x86_64.exe` / `windows_debug_x86_64.exe` в каталог шаблонов.
- **makensis (NSIS, brew install makensis) требует UTF-8 локали**: в локали `C`
  iconv-конверсия `wchar_t` падает на не-ASCII символах NSIS-констант с фиктивным
  `std::bad_alloc` (ломается даже бандловый пример). `tools/build_release.sh`
  выставляет `LC_ALL=en_US.UTF-8` сам; при ручном запуске makensis — не забывать.
- `assets/icon.ico` (16-256) сгенерирован из `icon.svg`: `qlmanage -t -s 256` -> PNG -> Pillow.
- macOS dmg подписывается ad-hoc; GL-ошибки "Texture leaked" при выходе релизной
  сборки с `--quit-after` — известный безвредный артефакт принудительного выхода
  в gl_compatibility, не считать регрессией.
- **NSIS CRC**: алгоритм exehead — crc32 файла с байта 512 до поля CRC (firstheader + length_of_all_following_data - 4); makensis на macOS пишет его корректно. `build_release.sh` делает verify-only проверку по этому алгоритму (НЕ перезаписывать хвост файла — формула crc32(file[:-4]) неверна и портит инсталлер). Компрессор — zlib: solid-lzma поток кросс-собранного makensis подозревается в «integrity check failed» на реальной Windows.
- `SHA256SUMS.txt` генерируется в каталоге релиза; пользователь сверяет на Windows через `certutil -hashfile <файл> SHA256`.
- Windows-бинарь и инсталлер на Mac не запускаются — финальный тест на Windows-машине делает пользователь.
