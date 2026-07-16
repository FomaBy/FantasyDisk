# Game Updates (0.2.2+)

Обновлено: 2026-07-16 (FAN-1210: public binary-only distribution)

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
загружают последним, поэтому `latest` не указывает на ещё не готовые установщики.

## Клиентский контракт

- `application/config/version` — установленная строгая SemVer `X.Y.Z`.
- В экспортированной игре выполняется одна фоновая проверка при запуске. Если
  сети нет, она молчит и не мешает игре; найденная новая версия всегда показывает
  prompt. В редакторе и headless автопроверка отключена.
- `Настройки → Обновить игру` выполняет явную проверку и всегда показывает
  результат, включая offline/error.
- Новая версия определяется числовым сравнением трёх SemVer-компонентов, не
  строковым сравнением.
- Клиент принимает только HTTPS URL внутри `FomaBy/FantasyDisk-Releases` GitHub
  Releases, точные имена `FantasyDisk-X.Y.Z-macos.dmg` и
  `FantasyDisk-X.Y.Z-windows-setup.exe`, положительный размер не более 1 GiB и
  64-символьный SHA-256.
- Файл сначала пишется как `user://updates/<name>.partial`, затем проверяется по
  размеру и SHA-256 и только после этого атомарно переименовывается. Ошибочный
  файл удаляется; текущая установка и сохранения не изменяются.
- Игра не перезаписывает собственный bundle/process. После проверки она открывает
  штатный DMG на macOS либо NSIS Setup на Windows. Это сохраняет
  Gatekeeper/SmartScreen и rollback-поведение системного установщика.
- Текущий macOS-канал — **unsigned** (решение владельца, FAN-1121): DMG и .app
  не имеют подписи Developer ID и нотаризации. Целостность гарантируется HTTPS +
  доверенным манифестом + точным именем/размером/SHA-256, а не подписью Apple.
  Клиент явно сообщает об этом и даёт ручной путь Gatekeeper: Системные настройки
  → Конфиденциальность и безопасность → «Всё равно открыть» (Open Anyway).
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

## Каналы сборки macOS

`FANTASYDISK_MACOS_CHANNEL` выбирается явно; тихий downgrade запрещён:

- `signed` (default) требует `MACOS_SIGN_IDENTITY`, `MACOS_NOTARY_PROFILE` и
  проходит codesign/notary/stapler/spctl для app и DMG.
- `unsigned` — одобренный владельцем канал без Apple credentials (FAN-1121).
  Он запускается только с `FANTASYDISK_MACOS_CHANNEL=unsigned`, отказывается
  работать при заданных Apple credentials и пропускает только Apple trust checks.
  Exact-tag inputs, DMG layout, NSIS + CRC, secret scan, `SHA256SUMS.txt` и
  update manifest остаются обязательными.

`local_release.py` записывает канал в `LOCAL_RELEASE.json` и требует явного
совпадения при `verify`. Публикаторы используют только возвращённый verified
durable path.

## Публикация

1. Собрать и materialize exact tag через
   `FANTASYDISK_MACOS_CHANNEL=unsigned tools/build_release.sh X.Y.Z`.
2. До upload публичный repo должен быть создан как `FomaBy/FantasyDisk-Releases`,
   быть public и содержать только минимальный `README.md`. Publisher проверяет
   tree и README на source/secret-like content, затем загружает assets в draft,
   manifest последним и только после allowlist-проверки делает release latest.
3. Выполнить unauthenticated byte verification без GitHub credentials, сверив
   page, `releases/latest/download/update-manifest.json`, оба installers, размеры
   и SHA-256 с durable release:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/github_release_verify.py \
  --version X.Y.Z --local-release /absolute/durable/releases/vX.Y.Z --prune-previous
```

   Только после успешной проверки удаляются stale public distribution releases и
   их distribution tags. Source tags и durable releases не затрагиваются.
4. Telegram обязателен для каждого stable release: dry-run, затем отправка
   poster, DMG, Windows Setup и SHA256SUMS из verified durable path.
5. После успешной Telegram delivery опубликовать Discord news с Telegram download
   link и ссылкой на public GitHub latest release.

Секреты GitHub, Discord и Telegram, session files, signing identities и notary
profiles остаются только в ignored local config/keychain state.
