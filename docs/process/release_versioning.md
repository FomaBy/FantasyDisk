# Release & Versioning — FantasyDisk

Обновлено: 2026-07-15
Ведет: PM. Исполняет сборки: Back-end.

## Версионирование

- Схема: **SemVer** `MAJOR.MINOR.PATCH`; до выхода 1.0 — `0.MINOR.PATCH`
  (0.1.0 → 0.2.0 — новые фичи; 0.2.1 — только хотфиксы).
- Текущий active target: `0.2.2`. Плановые `0.1.8` и `0.1.9` отменены/superseded:
  не создавать под них sprint, Multica release metadata (`release`),
  changelog-финализацию или release tasks. После `0.2.0` следующая patch-линия:
  `0.2.1`, `0.2.2`, ...
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
3. Backend прогоняет `python3 tools/quality_gate.py --profile full` + ручной чек-лист (меню, забег, бой, элитка,
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
9a. **Постоянная локальная копия — блокирующий гейт.** До любой внешней публикации
    `tools/build_release.sh` обязан вызвать bundled
    `skills/codex/fantasydisk-release-director/scripts/local_release.py` и:
    - собирать package в отдельный staging и только затем атомарно создать
      `<local_root>/releases/vX.Y.Z/` независимо от временного agent worktree;
    - извлечь в `project/` неизменяемое evidence exact tag `vX.Y.Z`, записать tag
      SHA и SHA256 всех файлов в `LOCAL_RELEASE.json`;
    - создать отдельную редактируемую `godot-project/`, атомарно направить на неё
      `releases/current-project` и зарегистрировать путь как `favorite=true`, не
      изменяя рабочий `dev` оператора и immutable evidence;
    - на macOS атомарно установить приложение из итогового DMG и проверить
      retained DMG layout/signature, bundle version, `hdiutil verify`, `codesign`,
      `stapler`, `spctl` и headless launch smoke.
    Существующий локальный релиз с отличающимися байтами не перезаписывается.
    GitHub/Discord и legacy Telegram clients повторно запускают verify, отправляют
    байты только
    из возвращённого проверенного локального пути и обязательно прикладывают PNG
    release poster. Локальный root задаётся явно/env/config и никогда не
    угадывается по временному worktree.
9b. **Public GitHub Release + updater manifest (начиная с 0.2.2).** Пакет обязан
    содержать `update-manifest.json` schema 1 с точными именами, размерами,
    SHA-256 и GitHub download URL обоих установщиков. Сначала выполнить dry-run,
    затем `github_release_publish.py --version X.Y.Z`: remote tag уже должен
    существовать, новый release создаётся draft, манифест загружается последним,
    и только полный release становится public/latest. Стабильный клиентский URL:
    `https://github.com/FomaBy/FantasyDisk/releases/latest/download/update-manifest.json`.
    `v0.2.2` дополнительно публикуется в Telegram. Любая версия после `0.2.2`
    **не публикуется в Telegram**; `telegram_publish.py` блокирует её. Discord
    всегда ведёт на публичный GitHub Release. Полный контракт:
    `docs/process/game_updates.md`.
10. **Релиз в Multica** (правило пользователя 2026-06-12: спринт = релиз;
    live board — проект FantasyDisk, issues FAN-*):
    - закрыть все issues версии в статус `done` на доске FantasyDisk;
    - пометить Multica release metadata (`release`) X.Y.Z как released, в описание
      версии — краткий ченджлог + ссылка releases/vX.Y.Z/CHANGELOG-X.Y.Z.md;
    - открыть следующую версию X.Y.Z+1 (unreleased) с кратким описанием плана и
      завести под неё issues FAN-* в статусе `todo`;
    - новым issues версии проставлять release metadata (`release`) = активная
      целевая версия (issues следующей версии остаются в backlog без `release`
      до своей стабилизации).
11. **Патч-ноуты в игре**: обновить игровой файл патч-ноутов (см. задачу
    backend_ingame_patch_notes_task.md / экран «Что нового») — человекочитаемые
    заметки версии для игрока, по-русски, синхронно с CHANGELOG. Это часть
    блокирующего changelog-гейта шага 4. Готово.

## Feature Block

Feature block 0.1.5 снят релизом v0.1.5 (2026-06-15). На 2026-07-14 активной
freeze-директивы нет; текущий Multica release target — `0.2.2`. При следующей
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
- Пресет `macOS` экспортирует `.app` в zip; `tools/build_release.sh` распаковывает
  окончательный bundle, удаляет quarantine/xattr и **после всех изменений**
  повторно подписывает его. `MACOS_SIGN_IDENTITY` обязан указывать установленный
  `Developer ID Application`; ad-hoc подпись для publishable release запрещена.
- Подпись обязательно проверяется через `codesign --verify --deep --strict` как
  до упаковки, так и после монтирования итогового DMG.
- `MACOS_NOTARY_PROFILE` обязателен. Скрипт отдельно отправляет подписанное
  приложение и затем подписанный DMG в `notarytool`, требует `Accepted`, staples
  tickets в оба артефакта и проверяет их через `stapler validate` + `spctl`.
- Любое отсутствие credentials, отказ Apple, ошибка staple или Gatekeeper
  assessment останавливает сборку до публикации.
- DMG содержит только `FantasyDisk.app`, ярлык `Applications` и одну фоновую
  стрелку. Стрелка хранится внутри signed app bundle; `.background`,
  `.fseventsd` и другие видимые root-служебные элементы запрещены allowlist-гейтом.
- Выход: `releases/vX.Y.Z/FantasyDisk-X.Y.Z-macos.dmg`.

### Windows (собирается с этого же Mac)
- Добавить пресет `Windows Desktop` (x86_64): exe + embedded pck (`binary_format/embed_pck=true`),
  иконка — .ico, сгенерированный из `icon.svg`.
- Для иконки/метаданных exe нужен `rcedit` + wine; если ставить wine нежелательно —
  допустимо собирать без кастомной иконки exe (не блокер релиза).
- Игрокам публикуется только инсталлер **NSIS** (`brew install makensis`) —
  `FantasyDisk-X.Y.Z-windows-setup.exe`. Сырой exe нужен только как временный
  вход сборки; отдельный Windows zip больше не создаётся и не публикуется.
- Headless-экспорт обеих платформ выполняется только через
  `tools/build_release.sh X.Y.Z`, который вызывает Godot через
  `tools/godot_gate.py`, а не напрямую.

## Кроссплатформенная совместимость (правила для всех агентов)

1. **Пути ресурсов чувствительны к регистру** в экспортированных сборках:
   в коде путь `res://...` должен совпадать с именем файла побуквенно
   (на macOS в редакторе ошибка не всплывет, в Windows-сборке — сломается).
2. Сохранения/настройки — только в `user://`, никогда в `res://` (read-only в сборке).
3. Не использовать платформо-специфичные шорткаты/API без `OS.get_name()` проверки.
4. Рендерер проекта должен оставаться `gl_compatibility`; ANGLE/D3D12 и другая
   платформенная специфика включаются только после A/B профиля на реальной Windows.
5. Каждый релиз тестируется на обеих платформах до публикации.
6. `.godot/`, `build/`, `releases/` не коммитятся.


## Фактические Нюансы Сборки (выявлено при v0.1.0)

- Сборка из тега идет через **отдельный git worktree** (`git worktree add --detach /tmp/... vX.Y.Z`),
  а не checkout в рабочем каталоге: в каталоге параллельно работают другие агенты,
  переключение ветки под ними недопустимо. Реализовано в `tools/build_release.sh`.
- Все входы сборки (`export_presets.cfg`, иконки, NSIS source, DMG helper/arrow)
  берутся из exact tag worktree. Если старый тег их не содержит, сборка блокируется:
  накладывать свежие файлы поверх тега запрещено, иначе сохранённый Godot snapshot
  перестаёт соответствовать реально экспортированному проекту.
- **Export templates**: проверка `~/Library/Application Support/Godot/export_templates/<версия>/`;
  Windows-шаблоны ставятся из официального tpz (godotengine releases), распаковать
  `windows_release_x86_64.exe` / `windows_debug_x86_64.exe` в каталог шаблонов.
- **makensis (NSIS, brew install makensis) требует UTF-8 локали**: в локали `C`
  iconv-конверсия `wchar_t` падает на не-ASCII символах NSIS-констант с фиктивным
  `std::bad_alloc` (ломается даже бандловый пример). `tools/build_release.sh`
  выставляет `LC_ALL=en_US.UTF-8` сам; при ручном запуске makensis — не забывать.
- `assets/icon.ico` (16-256) сгенерирован из `icon.svg`: `qlmanage -t -s 256` -> PNG -> Pillow.
- macOS `.app` подписывается Developer ID последним шагом перед app notarization
  и DMG; отсутствие Developer ID/notary profile является release blocker.
  GL-ошибки "Texture leaked" при выходе релизной
  сборки с `--quit-after` — известный безвредный артефакт принудительного выхода
  в gl_compatibility, не считать регрессией.
- **NSIS CRC**: алгоритм exehead — crc32 файла с байта 512 до поля CRC (firstheader + length_of_all_following_data - 4); makensis на macOS пишет его корректно. `build_release.sh` делает verify-only проверку по этому алгоритму (НЕ перезаписывать хвост файла — формула crc32(file[:-4]) неверна и портит инсталлер). Компрессор — zlib: solid-lzma поток кросс-собранного makensis подозревается в «integrity check failed» на реальной Windows.
- `SHA256SUMS.txt` генерируется в каталоге релиза; пользователь сверяет на Windows через `certutil -hashfile <файл> SHA256`.
- `update-manifest.json` генерируется только после финальных DMG/NSIS байтов и
  проходит повторную проверку в durable local release до GitHub upload.
- Windows-бинарь и инсталлер на Mac не запускаются — финальный тест на Windows-машине делает пользователь.
