## Простыми словами

Ранняя передача установщика Windows 0.3.1.1 из FAN-3989 (пометка: **package review pending** — независимая проверка пакета на FAN-3989 ещё не проводилась). Установщик собран из точного тега `v0.3.1.1` и разбит на 9 частей по 50 000 000 байт; после склейки файл совпадает с сохранённым установщиком байт в байт.

## 🔧 Техника

- Источник: тег-объект `a9e08364c0aaa0e588744d1dbc30b68e233da694` → коммит `01ee13687da712342964bcafebdb79c8a38b7d1e`, дерево `039b17c52480bb27c28d723248a8b85d4418bb58`; сборка `tools/build_release.sh 0.3.1.1` (signed), 2026-09-30T07:29:29Z–07:41:02Z, exit 0.
- Установщик: `FantasyDisk-0.3.1.1-windows-setup.exe`, 438 457 157 B, SHA-256 `c981cb533ae45de620ee2b760bc19b687add8772689aab7cb78fa805cf6050eb` (= строка в `SHA256SUMS.txt` и `update-manifest.json`, `version` `0.3.1.1`). NSIS CRC OK (firstheader @ 38912, crc @ 438457153), secret scan passed.
- Части: `split -b 50000000 -a 2` → `part-aa`…`part-ai` (8 × 50 000 000 B + 38 457 157 B). `PARTS.sha256` (SHA-256 `56ac0d13992dcda704cc1c91a37a2e85f858bd2240c748e5c1e4b0ef0d67d63a`) содержит SHA-256 каждой части.
- Склейка: `cat FantasyDisk-0.3.1.1-windows-setup.exe.part-* > FantasyDisk-0.3.1.1-windows-setup.exe`; SHA-256 результата `c981cb53…` — проверено локально до отправки.
- Приложены также `SHA256SUMS.txt` (`622d8f5c…`) и `update-manifest.json` (`b77d8887…`) из сохранённого пакета `releases/v0.3.1.1`.
- Ничего не публиковалось; `main` и теги не менялись.
