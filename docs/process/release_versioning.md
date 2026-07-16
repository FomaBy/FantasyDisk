# Release & Versioning — FantasyDisk

Обновлено: 2026-07-16 (FAN-1210)
Ведет: PM. Исполняет сборки: Back-end.

## Версионирование

- Схема: **SemVer** `MAJOR.MINOR.PATCH`; до выхода 1.0 — `0.MINOR.PATCH`
  (0.1.0 → 0.2.0 — новые фичи; 0.2.1 — только хотфиксы).
- Текущий active target: `0.2.4`. Плановые `0.1.8` и `0.1.9` отменены/superseded:
  не создавать под них sprint, Multica release metadata (`release`),
  changelog-финализацию или release tasks. После `0.2.0` следующая patch-линия:
  `0.2.1`, `0.2.2`, `0.2.3`, `0.2.4`, ...
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
      retained DMG layout, bundle version, `hdiutil verify` и headless launch
      smoke для обоих каналов; `codesign`, `stapler` и `spctl` проверяются
      дополнительно только в канале `signed` (в `unsigned` они пропускаются, а
      `verify` требует явного совпадения записанного `macos_channel`).
    Существующий локальный релиз с отличающимися байтами не перезаписывается.
    GitHub, Telegram и Discord clients повторно запускают verify, отправляют
    байты только из возвращённого проверенного локального пути и обязательно
    прикладывают PNG release poster. Локальный root задаётся явно/env/config и
    никогда не угадывается по временному worktree.
9b. **Public GitHub distribution + updater manifest (начиная с 0.2.2).** Private
    source repository `FomaBy/FantasyDisk` не используется как download host.
    Пакет обязан содержать `update-manifest.json` schema 1 с точными именами,
    размерами, SHA-256 и URLs обоих installers в public binary-only repository
    `FomaBy/FantasyDisk-Releases`. До upload publisher доказывает, что public
    Git tree содержит только минимальный README, без source/secrets; release
    создаётся draft, manifest загружается последним и только полный allowlisted
    package становится latest. Стабильный клиентский URL:
    `https://github.com/FomaBy/FantasyDisk-Releases/releases/latest/download/update-manifest.json`.
    Затем `github_release_verify.py` без GitHub credentials сверяет page,
    manifest, installers, hashes и durable bytes и лишь после PASS удаляет stale
    distribution releases/tags. Каждый stable release обязательно отправляется
    в Telegram (poster, DMG, Windows Setup, SHA256SUMS), после чего Discord
    публикует Telegram download link и GitHub release URL. Полный контракт:
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

Feature block 0.1.5 снят релизом v0.1.5 (2026-06-15). На 2026-07-16 включён
release freeze для `0.2.4` в рамках FAN-1128/FAN-1210: в текущий релиз входит
только исправление публичного updater/distribution и доказанные release gates.
Новые продуктовые изменения уходят в следующую SemVer patch/minor версию.

Исторически блок 0.1.3 был снят релизом v0.1.3 (2026-06-12); механизм остается
тем же для каждой релизной стабилизации.

## Сборки (Godot 4.7)

Общее правило: **версия export templates обязана совпадать с версией редактора**
(сейчас 4.7). Templates ставятся один раз: Editor → Manage Export Templates.

### macOS
`tools/build_release.sh` поддерживает два взаимоисключающих канала, выбираемых
ЯВНО через `FANTASYDISK_MACOS_CHANNEL`; тихий downgrade запрещён в обе стороны.
Текущий выбранный канал — `unsigned` (решение владельца, FAN-1121, после отмены
FAN-1094); `signed` остаётся строгим default и включается автоматически, когда
Apple credentials снова доступны. Полный клиентский контракт:
`docs/process/game_updates.md`.

- Пресет `macOS` экспортирует `.app` в zip; `tools/build_release.sh` распаковывает
  окончательный bundle и удаляет quarantine/xattr для обоих каналов.
- Канал `signed` (строгий default): **после всех изменений** bundle повторно
  подписывается. `MACOS_SIGN_IDENTITY` обязан указывать установленный
  `Developer ID Application` (ad-hoc подпись для publishable release запрещена);
  подпись проверяется через `codesign --verify --deep --strict` до упаковки и
  после монтирования итогового DMG. `MACOS_NOTARY_PROFILE` обязателен: скрипт
  отдельно отправляет подписанное приложение и затем подписанный DMG в
  `notarytool`, требует `Accepted`, staples tickets в оба артефакта и проверяет
  их через `stapler validate` + `spctl`. Любое отсутствие credentials, отказ
  Apple, ошибка staple или Gatekeeper assessment останавливает сборку до
  публикации (exit 2), а не переходит на unsigned.
- Канал `unsigned` (текущий, FAN-1121): запускается только явным
  `FANTASYDISK_MACOS_CHANNEL=unsigned` и отказывается работать, если
  `MACOS_SIGN_IDENTITY`/`MACOS_NOTARY_PROFILE` установлены. Пропускаются ТОЛЬКО
  codesign/notarization/stapler/spctl; DMG и .app остаются без подписи Developer
  ID и нотаризации, а клиент явно помечает сборку unsigned и даёт ручную
  Gatekeeper-инструкцию. Никаких заявлений о подписи/нотаризации в этом канале.
- Для ОБОИХ каналов сохраняются exact-tag inputs, headless import/export, layout
  DMG, secret scan, `SHA256SUMS.txt` и `update-manifest.json`. DMG содержит
  только `FantasyDisk.app`, ярлык `Applications` и одну фоновую стрелку; стрелка
  хранится внутри app bundle, а `.background`, `.fseventsd` и другие видимые
  root-служебные элементы запрещены allowlist-гейтом. Имена артефактов не
  меняются (клиентский контракт требует точные имена).
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
- В канале `signed` macOS `.app` подписывается Developer ID последним шагом перед
  app notarization и DMG; в этом канале отсутствие Developer ID/notary profile —
  release blocker. В текущем канале `unsigned` (FAN-1121) этот шаг осознанно
  пропускается, а наличие credentials, наоборот, отклоняется.
  GL-ошибки "Texture leaked" при выходе релизной
  сборки с `--quit-after` — известный безвредный артефакт принудительного выхода
  в gl_compatibility, не считать регрессией.
- **NSIS CRC**: алгоритм exehead — crc32 файла с байта 512 до поля CRC (firstheader + length_of_all_following_data - 4); makensis на macOS пишет его корректно. `build_release.sh` делает verify-only проверку по этому алгоритму (НЕ перезаписывать хвост файла — формула crc32(file[:-4]) неверна и портит инсталлер). Компрессор — zlib: solid-lzma поток кросс-собранного makensis подозревается в «integrity check failed» на реальной Windows.
- `SHA256SUMS.txt` генерируется в каталоге релиза; пользователь сверяет на Windows через `certutil -hashfile <файл> SHA256`.
- `update-manifest.json` генерируется только после финальных DMG/NSIS байтов и
  проходит повторную проверку в durable local release до GitHub upload.
- Windows-бинарь и инсталлер на Mac не запускаются — финальный тест на Windows-машине делает пользователь.
