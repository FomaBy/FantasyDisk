# Game Updates (0.2.2+)

Обновлено: 2026-08-10 (FAN-2307: signed/notarized current macOS channel)

## Публичный источник

Исходный репозиторий `FomaBy/FantasyDisk` остаётся приватным. Единственный
канонический источник клиентских обновлений — отдельный публичный binary-only
репозиторий [FomaBy/FantasyDisk-Releases](https://github.com/FomaBy/FantasyDisk-Releases).
В его Git-ветке разрешён только короткий player-facing `README.md`; DMG, Windows
Setup, SHA256SUMS, changelog, постер и manifest живут только как assets текущего
stable GitHub Release.

Клиент читает стабильный URL:

```text
https://github.com/FomaBy/FantasyDisk-Releases/releases/latest/download/update-manifest.json
```

Манифест — asset того же публичного Release, что DMG и Windows Setup. Его
upload начинается последним, но `gh` загружает assets параллельно, и порядок
завершения ничего не гарантирует. Инвариант безопасности другой: release
остаётся draft, пока весь allowlisted package, включая manifest, не проверен
byte-exact (имя, размер, SHA-256), и только затем становится public и latest —
поэтому `latest` никогда не указывает на ещё не готовые установщики.
Перед необратимым `--draft=false` publisher дополнительно доказывает
sole-writer boundary (FAN-1276): никакой другой аккаунт не может переписать
draft assets — репозиторий принадлежит самому публикатору, других
collaborators и pending invitations нет, deploy keys только read-only, и ни
одна GitHub App installation с contents/administration write не покрывает
репозиторий, — и повторно byte-exact сверяет все draft assets последним
чтением перед публичным edit. Подмена файла после последней чистой проверки
останавливает публикацию, пока release ещё draft.

## Клиентский контракт

- `application/config/version` — установленная release-версия `X.Y.Z` либо
  технический hotfix `X.Y.Z.R`. Обычный продуктовый выпуск остаётся строгим
  SemVer `X.Y.Z`; четвёртый компонент разрешён только когда меняются
  технические байты без новых игровых функций, баланса или заметного поведения.
- В экспортированной игре выполняется одна фоновая проверка при запуске. Если
  сети нет, она молчит и не мешает игре; найденная новая версия всегда показывает
  prompt. В редакторе и headless автопроверка отключена.
- `Настройки → Обновить игру` выполняет явную проверку и всегда показывает
  результат, включая offline/error.
- Новая версия определяется числовым сравнением четырёх компонентов с нулём для
  отсутствующего hotfix: `0.2.3 < 0.2.3.1 < 0.2.4`. Это сохраняет работу
  существующих manifests `X.Y.Z` и не использует строковое сравнение.
- Клиент принимает только HTTPS URL внутри `FomaBy/FantasyDisk-Releases` GitHub
  Releases, точные имена `FantasyDisk-<version>-macos.dmg` и
  `FantasyDisk-<version>-windows-setup.exe`, положительный размер не более 1 GiB
  и 64-символьный SHA-256; `<version>` обязан совпадать с manifest и иметь
  формат `X.Y.Z` или `X.Y.Z.R`.
- Файл сначала пишется как `user://updates/<name>.partial`, затем проверяется по
  размеру и SHA-256 и только после этого атомарно переименовывается. Ошибочный
  файл удаляется; текущая установка и сохранения не изменяются.
- Игра не перезаписывает собственный bundle/process. После проверки она открывает
  штатный DMG на macOS либо NSIS Setup на Windows. Это сохраняет
  Gatekeeper/SmartScreen и rollback-поведение системного установщика.
- Текущий macOS-канал — **signed**: DMG и .app обязаны иметь Developer ID
  Application signature, Apple notarization tickets и положительные trust checks.
  Поэтому current-channel prompt и сообщение после открытия DMG не показывают
  unsigned/«без Developer ID»/«Всё равно открыть» disclosure.
- FAN-1121 сохранён как контракт явно выбираемого historical `unsigned` fallback,
  но больше не является текущим product channel. Только relabelled unsigned tag
  показывает ручной путь Gatekeeper: Системные настройки → Конфиденциальность и
  безопасность → «Всё равно открыть» (Open Anyway).
- Известное ограничение macOS 26 (Tahoe) из FAN-2199/FAN-2297 относится только к
  quarantined unsigned artifacts: такое приложение может стартовать из read-only
  App Translocation, а после выхода быть асинхронно удалено из
  `/Applications/FantasyDisk.app`. Это не доказательство устойчивости нового
  signed-кандидата и не разрешает обещать её до отдельной native qualification.
- Метка канала в клиенте — `MACOS_UPDATE_CHANNEL` в `scripts/update_manager.gd`.
  `tools/build_release.sh` сверяет её с каналом сборки и падает при расхождении.

## Manifest schema 1

```json
{
  "schema_version": 1,
  "version": "0.2.4",
  "minimum_supported_version": "0.2.2",
  "release_url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.2.4",
  "assets": {
    "macos": {
      "name": "FantasyDisk-0.2.4-macos.dmg",
      "url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-macos.dmg",
      "sha256": "<64 lowercase hex>",
      "size": 123
    },
    "windows": {
      "name": "FantasyDisk-0.2.4-windows-setup.exe",
      "url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-windows-setup.exe",
      "sha256": "<64 lowercase hex>",
      "size": 123
    }
  }
}
```

`tools/build_release.sh` создаёт manifest из фактических финальных байтов через
`build_update_manifest.py`. `local_release.py verify` повторно сверяет schema,
version, URL, имена, размеры и хэши до любой внешней публикации.

## Неизменяемость и повторная доставка

- Опубликованный tag/version — immutable: GitHub publisher отказывается от
  существующего `v<version>`, а durable local release сравнивает все байты и
  отвергает отличия. Публикатор и verifier не удаляют старые distribution
  releases/tags.
- Если DMG, Windows Setup, SHA256SUMS и manifest уже проверены и их SHA-256 не
  меняются, их можно повторно отправить в новый Telegram/Discord-канал или дать
  на них новую ссылку. Номер, tag, manifest и asset bytes при этом не меняются;
  повторная доставка не является новым release.
- Если меняется хотя бы один технический байт, нужен новый immutable tag и
  версия `X.Y.Z.R`; нельзя заменять файлы или manifest под прежним номером.
  `project.godot`, имена артефактов, manifest и publication commands получают
  тот же logical номер. Windows сохраняет его в `application/product_version`,
  а `application/file_version` имеет дополнительный `.0` для `X.Y.Z` и равен
  logical версии для `X.Y.Z.R`.
- macOS exporter не получает четвёртый компонент напрямую: Godot записывает
  `application/short_version` в user-visible Xcode Version, а
  `application/version` — в machine-readable Xcode Build. Для logical
  `X.Y.Z.R` (у `X.Y.Z` считать `R=0`) `short_version` равен `X.Y.Z`, а build
  равен `(X+1).Y.(10*Z+R)`. Канонические bounds — `MAJOR=0…9998`,
  `MINOR=0…99`, `PATCH=0…9`, `HOTFIX=0…9`; поэтому Apple build имеет
  положительный первый компонент и не более двух цифр в третьем. Это сохраняет
  порядок `0.2.3 < 0.2.3.1 < 0.2.4` как `1.2.30 < 1.2.31 < 1.2.40` и оставляет
  оба Info.plist поля трёхкомпонентными. Источник контракта:
  [Apple CFBundleShortVersionString](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring),
  [Apple CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)
  и [Godot 4.7 macOS exporter](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformmacos.html).

## Каналы сборки macOS

`FANTASYDISK_MACOS_CHANNEL` выбирается явно; тихий downgrade запрещён:

- `signed` — текущий production-канал и строгий default; требует
  `MACOS_SIGN_IDENTITY`, `MACOS_NOTARY_PROFILE` и проходит
  codesign/notary/stapler/spctl для app и DMG.
- `unsigned` — явно выбираемый historical fallback без Apple credentials
  (FAN-1121), а не текущий product channel.
  Он запускается только с `FANTASYDISK_MACOS_CHANNEL=unsigned`, отказывается
  работать при заданных Apple credentials и после изменения bundle ставит только
  локальную ad-hoc подпись для проверки целостности. Это не подпись Developer ID
  и не отменяет ручное подтверждение Gatekeeper; Apple trust checks пропускаются.
  Exact-tag inputs, DMG layout, NSIS + CRC, secret scan, `SHA256SUMS.txt` и
  update manifest остаются обязательными.

`local_release.py` записывает канал в `LOCAL_RELEASE.json` и требует явного
совпадения при `verify`. Публикаторы используют только возвращённый verified
durable path.

### Первая signed stable qualification

Первый signed stable release допускается дальше только после независимого
exact-tag native evidence в FAN-2207. Отчёт обязан связать exact tag с DMG
SHA/provenance; показать `Accepted` notarization для app и DMG; результаты
`codesign`, `stapler` и `spctl`; Safari download source/event lineage; Finder
copy в `/Applications`; запуск вне App Translocation; затем first launch → quit
→ relaunch ×2 и сохранность приложения после каждого quit и каждого remediation
observation window. До terminal `PASSED` этой проверки signed durability is not
proven, а FAN-1231 не закрывается.

## Публикация

1. Собрать и materialize exact tag через
   `FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh <version>`, где
   `<version>` — `X.Y.Z` либо явно обоснованный технический `X.Y.Z.R`.
2. До upload публичный repo должен быть создан как `FomaBy/FantasyDisk-Releases`,
   быть public и содержать только минимальный `README.md`. Publisher проверяет
   tree и README на source/secret-like content, затем загружает assets в draft
   (upload в `gh` параллельный, порядок завершения не гарантирован) и делает
   release public, а затем latest, только после байт-точной allowlist-проверки
   всех draft assets, включая manifest. Перед самим `--draft=false` publisher
   повторно доказывает sole-writer boundary и повторно сверяет байты draft
   assets; любой другой аккаунт с правом записи, непроверяемое состояние или
   несовпадение байтов блокируют публикацию fail-closed, пока release ещё
   draft (FAN-1276).
3. Выполнить unauthenticated byte verification без GitHub credentials, сверив
   page, `releases/latest/download/update-manifest.json`, оба installers, размеры
   и SHA-256 с durable release:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/github_release_verify.py \
  --version <version> --local-release /absolute/durable/releases/v<version>
```

   Проверка не удаляет stale public distribution releases или tags: все
   опубликованные версии остаются immutable.
4. Telegram обязателен для каждого stable release: dry-run, затем отправка
   poster, DMG, Windows Setup и SHA256SUMS из verified durable path.
5. После успешной Telegram delivery опубликовать Discord news с Telegram download
   link и ссылкой на public GitHub latest release.

Секреты GitHub, Discord и Telegram, session files, signing identities и notary
profiles остаются только в ignored local config/keychain state.
