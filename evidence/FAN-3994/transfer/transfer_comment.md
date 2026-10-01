## Простыми словами

Ранняя передача установщика Windows 0.3.1.2 из FAN-3994 (пометка: **package review pending** — независимая проверка пакета на FAN-3994 ещё не проводилась). Установщик собран из точного тега `v0.3.1.2` с исправлением FAN-3991 и разбит на 9 частей по 50 000 000 байт; после склейки файл совпадает с сохранённым установщиком байт в байт.

## 🔧 Техника

- Источник: тег-объект `eaf68a1d335e577087e2c570c19e84792bdbb332` → коммит `9a19870a15d71bc2b63e622c7895519bd84dafb4`, дерево `05fc714ce1599d85ee01fc13dc8afbfca449d157`; сборка `tools/build_release.sh 0.3.1.2` (signed), 2026-10-01T14:30:49Z–14:42:01Z, exit 0.
- Установщик: `FantasyDisk-0.3.1.2-windows-setup.exe`, 438 450 173 B, SHA-256 `162740c47c8b0c32e068d454909d8dd68e9e0871ab427c7b1af7301bfac74bd5` (= строка в `SHA256SUMS.txt` и `update-manifest.json`, `version` `0.3.1.2`). NSIS CRC OK (firstheader @ 38912, crc @ 438450169), secret scan passed. Хеш отличается от 0.3.1.1 (`c981cb53…`) и 0.3.1 (`db99a929…`).
- Части: `split -b 50000000 -a 2` → `part-aa`…`part-ai` (8 × 50 000 000 B + 38 450 173 B). `PARTS.sha256` (SHA-256 `c720ed832ab6353a42aac75e7ed66d2062a7256af1d346e33b40e6ff0bc19023`) содержит SHA-256 каждой части.
- Склейка: `cat FantasyDisk-0.3.1.2-windows-setup.exe.part-* > FantasyDisk-0.3.1.2-windows-setup.exe`; SHA-256 результата `162740c4…` — проверено локально до отправки.
- Приложены также `SHA256SUMS.txt` (`d7b19b4f…`) и `update-manifest.json` (`e70d0e59…`) из сохранённого пакета `releases/v0.3.1.2`.
- PCK внутри Windows-плеера: 27 034 записи, 17 `data/ultimates/presentation/*.json`, 0 записей `docs/`/`evidence/`/`skills/`/`tools/`/`tests/`; таблица идентична macOS-PCK по путям, размерам и выборке содержимого.
- Ничего не публиковалось; `main` и теги не менялись.
