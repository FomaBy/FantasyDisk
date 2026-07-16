# Game Updates (0.2.2+)

Обновлено: 2026-07-15 (FAN-1121: канал unsigned macOS)

## Публичный источник

Единственный канонический источник клиентских обновлений — публичные
[GitHub Releases](https://github.com/FomaBy/FantasyDisk/releases). Клиент читает
стабильный URL:

```text
https://github.com/FomaBy/FantasyDisk/releases/latest/download/update-manifest.json
```

Манифест — asset того же GitHub Release, что DMG и Windows Setup. Его публикуют
последним, поэтому `latest` не указывает на ещё не загруженные установщики.

## Клиентский контракт

- `application/config/version` — установленная строгая SemVer `X.Y.Z`.
- В экспортированной игре выполняется одна фоновая проверка при запуске. Если
  сети нет, она молчит и не мешает игре; найденная новая версия всегда показывает
  prompt. В редакторе и headless автопроверка отключена.
- `Настройки → Обновить игру` выполняет явную проверку и всегда показывает
  результат, включая offline/error.
- Новая версия определяется числовым сравнением трёх SemVer-компонентов, не
  строковым сравнением.
- Клиент принимает только HTTPS URL внутри `FomaBy/FantasyDisk` GitHub Releases,
  точные имена `FantasyDisk-X.Y.Z-macos.dmg` и
  `FantasyDisk-X.Y.Z-windows-setup.exe`, положительный размер не более 1 GiB и
  64-символьный SHA-256.
- Файл сначала пишется как `user://updates/<name>.partial`, затем проверяется по
  размеру и SHA-256 и только после этого атомарно переименовывается. Ошибочный
  файл удаляется; текущая установка и сохранения не изменяются.
- Игра не перезаписывает собственный bundle/process. После проверки она открывает
  штатный DMG на macOS либо NSIS Setup на Windows. Это сохраняет
  Gatekeeper/SmartScreen и rollback-поведение системного установщика.
- Текущий macOS-канал — **unsigned** (решение владельца, FAN-1121, после отмены
  FAN-1094): DMG и .app не имеют подписи Developer ID и нотаризации. Целостность
  гарантируется HTTPS + доверенным манифестом + точным именем/размером/SHA-256,
  а не подписью Apple. Клиент обязан явно сообщать об этом: диалог обновления и
  сообщение после открытия DMG показывают, что сборка не подписана, и дают
  инструкцию ручного подтверждения Gatekeeper: Системные настройки →
  Конфиденциальность и безопасность → «Всё равно открыть» (Open Anyway).
- Метка канала в клиенте — `MACOS_UPDATE_CHANNEL` в `scripts/update_manager.gd`.
  `tools/build_release.sh` сверяет её с каналом сборки и падает при расхождении,
  чтобы UI-подсказки не могли лгать ни в одну сторону. Никаких заявлений о
  подписи/нотаризации в unsigned-канале быть не должно.
- Формат сохранений не меняется этим механизмом; обновление с 0.2.2 вперёд
  использует существующие backward-compatible loaders.

## Manifest schema 1

```json
{
  "schema_version": 1,
  "version": "0.2.3",
  "minimum_supported_version": "0.2.2",
  "release_url": "https://github.com/FomaBy/FantasyDisk/releases/tag/v0.2.3",
  "assets": {
    "macos": {
      "name": "FantasyDisk-0.2.3-macos.dmg",
      "url": "https://github.com/FomaBy/FantasyDisk/releases/download/v0.2.3/FantasyDisk-0.2.3-macos.dmg",
      "sha256": "<64 lowercase hex>",
      "size": 123
    },
    "windows": {
      "name": "FantasyDisk-0.2.3-windows-setup.exe",
      "url": "https://github.com/FomaBy/FantasyDisk/releases/download/v0.2.3/FantasyDisk-0.2.3-windows-setup.exe",
      "sha256": "<64 lowercase hex>",
      "size": 123
    }
  }
}
```

`tools/build_release.sh` создаёт манифест из фактических финальных байтов через
`build_update_manifest.py`. `local_release.py verify` повторно сверяет schema,
version, URL, имена, размеры и хэши до любой внешней публикации.

## Каналы сборки macOS

`tools/build_release.sh` поддерживает два взаимоисключающих канала, выбираемых
ЯВНО через `FANTASYDISK_MACOS_CHANNEL`; тихий downgrade запрещён в обе стороны:

- `signed` (default) — строгий production-канал: `MACOS_SIGN_IDENTITY`
  (Developer ID Application) и `MACOS_NOTARY_PROFILE` обязательны; codesign,
  notarytool, stapler и spctl выполняются для .app и DMG. Отсутствие
  credentials — ошибка (exit 2), а не переход на unsigned.
- `unsigned` — одобренный владельцем канал без Apple credentials (FAN-1121).
  Запускается только явным `FANTASYDISK_MACOS_CHANNEL=unsigned` и отказывается
  работать, если `MACOS_SIGN_IDENTITY`/`MACOS_NOTARY_PROFILE` установлены.
  Пропускаются ТОЛЬКО codesign/notarization/stapler/spctl; exact-tag inputs,
  headless import/export, layout DMG, NSIS + CRC, secret scan, `SHA256SUMS.txt`
  и `update-manifest.json` сохраняются полностью. Имена артефактов не меняются
  (клиентский контракт требует точные имена).

`local_release.py` записывает канал в `LOCAL_RELEASE.json` (`macos_channel`) при
materialize и на `verify` требует явного совпадения запрошенного канала с
записанным (`--macos-channel` или `FANTASYDISK_MACOS_CHANNEL`; default —
`signed`). Уже materialized релиз нельзя перемаркировать в другой канал. Для
unsigned-релиза проверки DMG/app выполняются без codesign/stapler/spctl, но
`hdiutil verify`, layout, версия bundle и launch smoke остаются обязательными.
Публикаторы (`github_release_publish.py`, `release_publish.py`) вызывают
`verify` и поэтому публикуют unsigned-релиз только при явно выставленном
`FANTASYDISK_MACOS_CHANNEL=unsigned` у оператора.

## Публикация

1. Собрать и materialize exact tag через `tools/build_release.sh X.Y.Z`
   (для unsigned-канала — с явным `FANTASYDISK_MACOS_CHANNEL=unsigned`).
2. Выполнить dry-run, затем публикацию `github_release_publish.py`. Скрипт требует
   проверенную durable local release (включая совпадение macOS-канала),
   существующий remote tag и `gh auth`; новый
   release создаётся draft и становится public/latest только после загрузки всех
   assets.
3. Только для `v0.2.2` дополнительно выполнить Telegram-публикацию. Скрипт
   `telegram_publish.py` fail-closed отклоняет любую версию выше `0.2.2`.
4. Discord-анонс всегда ведёт на публичный GitHub Release. Для `v0.2.2` Telegram
   остаётся дополнительным каналом доставки, а не каноническим URL.

Переход отражён и в именах poster assets: только 0.2.2 сохраняет suffix
`_announcement_telegram_discord.png`; последующие версии используют нейтральный
`_announcement.png`.

Требование Developer ID/notarization для публикации снято решением владельца
(FAN-1094 отменён; принят unsigned-канал с ручным Gatekeeper-подтверждением,
FAN-1121). Signed-канал остаётся строгим и включается автоматически как default,
как только credentials снова появятся; при возврате на signed необходимо в той
же задаче обновить `MACOS_UPDATE_CHANNEL` и клиентские подсказки, иначе сборка
упадёт на сверке меток.
