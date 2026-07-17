# Release & Versioning — FantasyDisk

Обновлено: 2026-07-16 (FAN-1213)
Ведет: PM. Исполняет сборки: Back-end.

## Версионирование

- Обычная продуктовая схема: **SemVer** `MAJOR.MINOR.PATCH`; до выхода 1.0 —
  `0.MINOR.PATCH` (0.1.0 → 0.2.0 — новые фичи; patch меняется для видимого
  продукта, баланса или геймплея).
- Техническая схема: `MAJOR.MINOR.PATCH.HOTFIX` разрешена только после уже
  выпущенного patch, когда меняются байты технического исправления без новых
  игровых функций, баланса или заметного поведения. Например,
  `0.2.3 < 0.2.3.1 < 0.2.4`; отсутствие HOTFIX означает ноль. Этот формат не
  объявляется SemVer и не применяется молча до успешного tooling gate.
- Канонические границы, проверяемые updater, manifest, publication и platform
  mapping: `MAJOR=0…9998`, `MINOR=0…99`, `PATCH=0…9`, `HOTFIX=0…9`. Они нужны,
  чтобы одна logical version безопасно представлялась и Godot, и macOS bundle
  metadata; версия вне этих границ отклоняется до сборки или публикации.
- Текущий опубликованный stable release: `0.2.4`. Плановые `0.1.8` и `0.1.9` отменены/superseded:
  не создавать под них sprint, Multica release metadata (`release`),
  changelog-финализацию или release tasks. После `0.2.0` следующая patch-линия:
  `0.2.1`, `0.2.2`, `0.2.3`, `0.2.4`, ...
- **Источник истины версии** — `project.godot` → `[application] config/version`.
  Код может читать её через `ProjectSettings.get_setting("application/config/version")`
  (показывать в главном меню мелким текстом).
- Каждый релиз помечается immutable git-тегом `v<version>` на ветке `main`.
- Export presets отделяют logical release version от macOS bundle metadata.
  Для logical `X.Y.Z.R` (у `X.Y.Z` считать `R=0`) macOS
  `application/short_version` равен `X.Y.Z`, а `application/version` равен
  `(X+1).Y.(10*Z+R)`. Так machine-readable Apple build всегда имеет
  положительный первый компонент и третий компонент не длиннее двух цифр,
  остаётся трёхкомпонентным и сохраняет порядок hotfix (см. [Apple CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)
  и [Godot macOS exporter](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformmacos.html)). Windows `application/product_version` равен `<version>`, а
  `application/file_version` равен `<version>.0` для `X.Y.Z` и самому
  `<version>` для `X.Y.Z.R`.
- История изменений — `CHANGELOG.md` (раздел Unreleased пополняется по ходу dev,
  при релизе переименовывается в номер версии с датой).

## Ветки

```text
main — только релизные состояния. Каждый коммит в main = релиз с тегом v<version>.
dev  — основная ветка разработки. Все чаты (Backend/Designer/Animator/PM) работают здесь.
```

- Все агенты работают в одном рабочем каталоге, поэтому **текущая checked-out
  ветка всегда dev**. Переключение на main делает только PM в момент релиза.
- Хотфикс релиза: ветка от main → технический фикс → merge в main → новый
  immutable tag `vX.Y.Z.R` → merge main в dev. Новый игровой результат использует
  обычный SemVer `vX.Y.Z`, а не четвёртый компонент.

## Повторная публикация и immutable bytes

1. Если артефакты не меняются, сверить durable `SHA256SUMS.txt` и manifest с
   ранее опубликованной версией, затем повторно доставить те же файлы в новый
   Telegram/Discord-канал или опубликовать новые release notes со ссылкой на
   существующий public GitHub Release. Version/tag/assets не редактировать.
2. Если хотя бы один байт меняется, создать новую версию `X.Y.Z.R`, обновить все
   version fields и собрать новый package. Никогда не заменять bytes, manifest,
   tag или GitHub Release под существующим version.
3. `github_release_verify.py` не удаляет прошлые distribution releases/tags;
   опция pruning запрещена. Это сохраняет повторяемую доставку и доказуемую
   историю байтов.
4. FAN-1249/FAN-1265/FAN-1272: публикация возможна только при включённой на
   `FomaBy/FantasyDisk-Releases` GitHub-защите immutable releases и при
   активном tag ruleset без bypass actors, который блокирует update и deletion
   release-тегов (`v*`); publisher проверяет оба precondition до любых внешних
   действий. После публикации фактически повторно проверяются: public state
   release, byte-exact assets, tag identity и GitHub-reported immutability
   (release обязан отчитаться как immutable до пометки latest); сам ruleset
   endpoint повторно не читается — его гарантия доказана до claim. GitHub не
   даёт атомарного publish-with-expected-SHA, поэтому именно server-side
   ruleset держит захваченный tag неизменным между последней pre-public
   проверкой identity и публикацией. Release-тег захватывается атомарно на
   exact commit; появившийся параллельно чужой tag/release блокирует
   публикацию без reuse/edit. Draft создаётся с `--verify-tag`: исчезнувший
   после claim tag прерывает создание вместо тихого пересоздания. После любой
   ошибки или неоднозначности `release create` publisher делает best-effort
   re-read состояния Release (draft/public, маркер latest) и захваченного
   тега, честно сообщает прочитанное и не обещает draft-only state без
   доказательства. Delete/clobber/force путей нет: rollback не существует, а
   recovery различает пять состояний:
   - failed draft create — create вернул ошибку, а best-effort re-read
     доказал отсутствие public release: остаются максимум bare claimed tag и
     unpublished draft (возможно с частью assets); оставить их на месте и
     сжечь номер версии;
   - ambiguous create — состояние прочитать не удалось: release может быть и
     draft, и public (даже latest); ручная инспекция release и тега на
     GitHub, затем сжечь номер версии;
   - foreign/racing public release — параллельный publisher успел создать
     public (возможно latest) release на захваченном tag до нашего draft
     create: чужой release/tag нельзя удалять, редактировать, понижать
     (demote) или переиспользовать — даже помеченный latest он остаётся как
     есть, его метку latest не трогают; сжечь номер версии этой попытки;
   - successful public non-latest — наш public-edit подтверждён применённым
     (`gh release edit --draft=false --latest=false` вернул успех), но
     провалилась post-public проверка (foreign tag, отсутствие immutability,
     несовпадение assets): созданный нами публичный non-latest release
     остаётся; оставить его как есть, не помечать latest и не редактировать, и
     сжечь номер версии;
   - latest-only failure — release уже public, byte-exact verified и
     immutable, не удалась только пометка latest: единственное состояние без
     сжигания версии; после проверки страницы release вручную повторить
     `gh release edit v<version> --repo FomaBy/FantasyDisk-Releases --latest`,
     ничего не пересоздавая.
   Applied-but-response-lost (потерянный ответ public-edit) сам по себе не
   доказывает successful public non-latest: пока re-read не разрешит
   неоднозначность, отдельно возможны четыре исхода — release всё ещё draft
   (edit не применился → failed draft create), public non-latest (edit
   применился → successful public non-latest), неожиданный public latest
   (обращаться как с foreign/racing public latest: никогда не понижать) или
   нечитаемое состояние (ambiguous create). Потерянный ответ никогда не
   считается доказательством public non-latest.
   Любая другая неудачная попытка сжигает номер версии, следующая попытка
   использует следующий hotfix-компонент `X.Y.Z.R`.

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
   - финализировать раздел версии: Unreleased → `## [<version>] — дата`;
   - сверить ПОЛНОТУ с фактическим составом релиза: `git log v<пред>..HEAD --oneline` —
     каждое игровое/видимое изменение должно иметь пункт (внутренние docs/чекпоинты
     можно опускать); пункты — человеческим языком, для игрока/тестера;
   - создать новый пустой раздел Unreleased сверху.
   Релиз без финализированного changelog НЕ выполняется — это блокирующий гейт.
5. Поднять версию: `config/version` в project.godot.
6. Коммит в dev → `git checkout main` → `git merge dev --no-ff` → `git tag v<version>`
   → `git checkout dev`.
7. Backend собирает релизные билды для Windows и macOS (см. ниже) в `releases/v<version>/`
   (каталог в .gitignore — артефакты не коммитятся).
8. Положить копию changelog версии в артефакты релиза:
   `releases/v<version>/CHANGELOG-<version>.md` (раздел версии из CHANGELOG.md) — чтобы
   получатель билда видел, что нового, без доступа к репозиторию.
9. Smoke-проверка установленных билдов.
9a. **Постоянная локальная копия — блокирующий гейт.** До любой внешней публикации
    `tools/build_release.sh` обязан вызвать bundled
    `skills/codex/fantasydisk-release-director/scripts/local_release.py` и:
    - собирать package в отдельный staging и только затем атомарно создать
      `<local_root>/releases/v<version>/` независимо от временного agent worktree;
    - извлечь в `project/` неизменяемое evidence exact tag `v<version>`, записать tag
      SHA и SHA256 всех файлов в `LOCAL_RELEASE.json`;
    - создать отдельную редактируемую `godot-project/`, атомарно направить на неё
      `releases/current-project` и зарегистрировать путь как `favorite=true`, не
      изменяя рабочий `dev` оператора и immutable evidence;
    - на macOS атомарно установить приложение из итогового DMG и проверить
      retained DMG layout, bundle version, `hdiutil verify` и headless launch
      smoke и `codesign --verify --deep --strict` как integrity check для
      обоих каналов, включая unsigned с локальной ad-hoc seal. В канале
      `signed` дополнительно выполняются Apple trust checks через `stapler`
      и `spctl`; unsigned не требует Developer ID/notarization и пропускает
      только эти trust steps, а `verify` требует явного совпадения записанного
      `macos_channel`.
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
    создаётся draft (upload assets в `gh` параллельный, порядок завершения не
    гарантирован) и становится public, а затем latest, только после байт-точной
    проверки полного allowlisted package в draft, включая manifest — поэтому
    latest/download никогда не указывает на неполный набор installers.
    Публикация дополнительно защищена sole-writer boundary (FAN-1276): до
    первого внешнего side effect и повторно непосредственно перед
    `--draft=false` publisher доказывает, что переписать draft assets не может
    никакой другой аккаунт — репозиторий принадлежит аутентифицированному
    публикатору, других collaborators и pending invitations нет, deploy keys
    только read-only, и ни одна GitHub App installation с contents или
    administration write не покрывает репозиторий, — а затем повторно
    byte-exact сверяет все draft assets последним чтением перед публичным
    edit. Конкурентная подмена asset после последней чистой проверки блокирует
    публикацию, пока release ещё draft; непроверяемое состояние тоже блокирует
    (fail-closed), и publisher сам никогда не меняет эти настройки GitHub.
    Стабильный клиентский URL:
    `https://github.com/FomaBy/FantasyDisk-Releases/releases/latest/download/update-manifest.json`.
    Затем `github_release_verify.py` без GitHub credentials сверяет page,
    manifest, installers, hashes и durable bytes, не удаляя другие immutable
    distribution releases/tags. Каждый stable release обязательно отправляется
    в Telegram (poster, DMG, Windows Setup, SHA256SUMS), после чего Discord
    публикует Telegram download link и GitHub release URL. Полный контракт:
    `docs/process/game_updates.md`.
10. **Релиз в Multica** (правило пользователя 2026-06-12: спринт = релиз;
    live board — проект FantasyDisk, issues FAN-*):
    - закрыть все issues версии в статус `done` на доске FantasyDisk;
    - пометить Multica release metadata (`release`) `<version>` как released, в описание
      версии — краткий ченджлог + ссылка releases/v<version>/CHANGELOG-<version>.md;
    - открыть следующую обычную product-версию (unreleased) с кратким описанием плана и
      завести под неё issues FAN-* в статусе `todo`;
    - новым issues версии проставлять release metadata (`release`) = активная
      целевая версия (issues следующей версии остаются в backlog без `release`
      до своей стабилизации).
11. **Патч-ноуты в игре**: обновить игровой файл патч-ноутов (см. задачу
    backend_ingame_patch_notes_task.md / экран «Что нового») — человекочитаемые
    заметки версии для игрока, по-русски, синхронно с CHANGELOG. Это часть
    блокирующего changelog-гейта шага 4. Готово.

## Feature Block

Feature block 0.1.5 снят релизом v0.1.5 (2026-06-15). Релиз `0.2.4` уже
опубликован; его historical release freeze в рамках FAN-1128/FAN-1210 завершён.
Новые продуктовые изменения используют следующую SemVer patch/minor версию, а
техническая коррекция байтов опубликованного patch следует hotfix-правилу выше.

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
  `MACOS_SIGN_IDENTITY`/`MACOS_NOTARY_PROFILE` установлены. После всех изменений
  bundle получает локальную ad-hoc seal и проходит
  `codesign --verify --deep --strict` для проверки целостности. Эта seal
  заменяет унаследованную подпись export template, но не является подписью
  Developer ID и не делает artifact доверенным для Gatekeeper. Developer ID
  signing, notarization, `stapler` и `spctl` в этом канале не выполняются;
  клиент явно помечает сборку unsigned и даёт ручную инструкцию «Всё равно
  открыть». Никаких заявлений о доверии Apple в этом канале.
- Для ОБОИХ каналов сохраняются exact-tag inputs, headless import/export, layout
  DMG, secret scan, `SHA256SUMS.txt` и `update-manifest.json`. DMG содержит
  только `FantasyDisk.app`, ярлык `Applications` и одну фоновую стрелку; стрелка
  хранится внутри app bundle, а `.background`, `.fseventsd` и другие видимые
  root-служебные элементы запрещены allowlist-гейтом. Имена артефактов не
  меняются (клиентский контракт требует точные имена).
- Выход: `releases/v<version>/FantasyDisk-<version>-macos.dmg`.

### Windows (собирается с этого же Mac)
- Добавить пресет `Windows Desktop` (x86_64): exe + embedded pck (`binary_format/embed_pck=true`),
  иконка — .ico, сгенерированный из `icon.svg`.
- Для иконки/метаданных exe нужен `rcedit` + wine; если ставить wine нежелательно —
  допустимо собирать без кастомной иконки exe (не блокер релиза).
- Игрокам публикуется только инсталлер **NSIS** (`brew install makensis`) —
  `FantasyDisk-<version>-windows-setup.exe`. Сырой exe нужен только как временный
  вход сборки; отдельный Windows zip больше не создаётся и не публикуется.
- Headless-экспорт обеих платформ выполняется только через
  `tools/build_release.sh <version>`, который вызывает Godot через
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

- Сборка из тега идет через **отдельный git worktree** (`git worktree add --detach /tmp/... v<version>`),
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
  release blocker. В текущем канале `unsigned` (FAN-1121) пропускается только
  Developer ID/notarization этап, а локальная ad-hoc seal и
  `codesign --verify --deep --strict` для проверки целостности обязательны;
  наличие credentials, наоборот, отклоняется.
  GL-ошибки "Texture leaked" при выходе релизной
  сборки с `--quit-after` — известный безвредный артефакт принудительного выхода
  в gl_compatibility, не считать регрессией.
- **NSIS CRC**: алгоритм exehead — crc32 файла с байта 512 до поля CRC (firstheader + length_of_all_following_data - 4); makensis на macOS пишет его корректно. `build_release.sh` делает verify-only проверку по этому алгоритму (НЕ перезаписывать хвост файла — формула crc32(file[:-4]) неверна и портит инсталлер). Компрессор — zlib: solid-lzma поток кросс-собранного makensis подозревается в «integrity check failed» на реальной Windows.
- `SHA256SUMS.txt` генерируется в каталоге релиза; пользователь сверяет на Windows через `certutil -hashfile <файл> SHA256`.
- `update-manifest.json` генерируется только после финальных DMG/NSIS байтов и
  проходит повторную проверку в durable local release до GitHub upload.
- Windows-бинарь и инсталлер на Mac не запускаются — финальный тест на Windows-машине делает пользователь.
