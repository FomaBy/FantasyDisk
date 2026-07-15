# Game Updates (0.2.2+)

Обновлено: 2026-07-15

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
  штатный signed/notarized DMG на macOS либо NSIS Setup на Windows. Это сохраняет
  Gatekeeper/SmartScreen и rollback-поведение системного установщика.
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

## Публикация

1. Собрать и materialize exact tag через `tools/build_release.sh X.Y.Z`.
2. Выполнить dry-run, затем публикацию `github_release_publish.py`. Скрипт требует
   проверенную durable local release, существующий remote tag и `gh auth`; новый
   release создаётся draft и становится public/latest только после загрузки всех
   assets.
3. Только для `v0.2.2` дополнительно выполнить Telegram-публикацию. Скрипт
   `telegram_publish.py` fail-closed отклоняет любую версию выше `0.2.2`.
4. Discord-анонс всегда ведёт на публичный GitHub Release. Для `v0.2.2` Telegram
   остаётся дополнительным каналом доставки, а не каноническим URL.

Переход отражён и в именах poster assets: только 0.2.2 сохраняет suffix
`_announcement_telegram_discord.png`; последующие версии используют нейтральный
`_announcement.png`.

Фактический выпуск `v0.2.2` по-прежнему требует Developer ID и Apple notarization;
изменение updater-кода не ослабляет эти release gates.
