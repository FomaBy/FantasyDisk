# Задача Для Back-end-Агента: БАГ — Windows-Инсталлер Не Проходит Integrity Check

Статус: done 2026-06-11. ДИАГНОЗ: makensis на macOS записывает НЕВЕРНЫЙ CRC32 в хвост инсталлера — данные целы (7z t: Everything is Ok), но NSIS-проверка на Windows честно падала (stored 79a75cfc != computed 373e46cd). ФИКС: в tools/build_release.sh добавлен пост-шаг — пересчет CRC32 файла и перезапись последних 4 байт + самопроверка (упадет сборкой, если CRC снова бит); в windows_installer.nsi явные Unicode true / CRCCheck on. Также добавлена генерация SHA256SUMS.txt для контроля порчи при передаче. Артефакты v0.1.1 пересобраны: NSIS CRC MATCH, 7z t OK, zip OK (рабочая альтернатива была цела изначально), dmg запуск OK. SHA256 setup.exe: 66f534e6aa439819a2349ec8ee6cc484c95dae3fa1c5d048cb9518a9d4726571. Проверка пользователем на Windows: certutil -hashfile FantasyDisk-0.1.1-windows-setup.exe SHA256 — хэш должен совпасть, затем установка.
Создано: 2026-06-11
Автор: PM
Приоритет: критический, блокирует релиз v0.1.1 (Windows-часть).

## Autonomy / Approval
Пользователь заранее одобрил все изменения, включая установку диагностических
инструментов через brew (p7zip и т.п.).

## Контекст
Пользователь запустил `FantasyDisk-*-windows-setup.exe` на реальной Windows-машине
и получил: **«NSIS Error: Installer integrity check has failed. Common causes
include incomplete download and damaged media»**. Инсталлер собирался makensis
на macOS (`tools/windows_installer.nsi` через `tools/build_release.sh`).
Уже известный нюанс среды: makensis на macOS падал в C-локали (iconv wchar_t),
лечится LC_ALL=en_US.UTF-8 — возможно, проблемы той же природы глубже и портят
CRC выходного файла.

## Требования

### 1. Диагностика (по порядку, фиксируй результаты в отчете)
1. Проверить целостность артефакта локально: `7z t` по setup.exe (p7zip умеет
   тестировать NSIS-инсталлеры), сверить размер/структуру. Если 7z уже видит
   повреждение — проблема в сборке, не в передаче файла.
2. Посчитать SHA256 артефакта и добавить генерацию `SHA256SUMS.txt` в
   `tools/build_release.sh` для всех артефактов релиза — чтобы пользователь
   мог исключить порчу при передаче файла на Windows (инструкция в отчет:
   `certutil -hashfile <файл> SHA256` на Windows).
3. Проверить версию/сборку makensis из brew и известные баги кросс-сборки
   NSIS на macOS (unicode/large-file/CRC). Проверить, не модифицируется ли
   exe после makensis (никаких post-build touch/sign операций быть не должно).

### 2. Исправление (варианты по убыванию предпочтительности)
4. Починить NSIS-сборку: попробовать `SetCompressor /SOLID lzma` → `zlib`
   (известный источник integrity-проблем на кросс-сборках), явный `CRCCheck on`,
   `Unicode true`, пересборка и повторный `7z t`.
5. Если NSIS на macOS принципиально ненадежен — заменить механизм инсталлера:
   например, самораспаковывающийся 7z SFX с конфигом (ставится без NSIS) или
   качественный zip как ОСНОВНОЙ канал + короткая инструкция установки
   (распаковать в Program Files, ярлык). Решение зафиксировать в
   release_versioning.md.
6. Пересобрать артефакты v0.1.1 целиком (`tools/build_release.sh 0.1.1`),
   обновить SHA256SUMS.

### 3. Верификация
7. Локально: `7z t` зеленый на новом setup.exe; SHA256 зафиксирован.
8. Сообщить пользователю в финалке: путь к новому артефакту, его SHA256,
   команду проверки хеша на Windows — финальный запуск снова за ним.
9. Отметить в отчете: zip-вариант (`FantasyDisk-0.1.1-windows.zip`) — рабочая
   альтернатива прямо сейчас; проверить его структуру `unzip -t`.

## Files / Assets / IDs
- `tools/windows_installer.nsi`, `tools/build_release.sh`, `releases/v0.1.1/`.

## Acceptance Criteria
- [ ] Причина integrity-fail диагностирована и описана.
- [ ] Новый setup.exe проходит `7z t` локально; SHA256SUMS.txt генерируется скриптом.
- [ ] Релизные артефакты v0.1.1 пересобраны.
- [ ] В отчете: инструкция проверки хеша для пользователя + статус zip-альтернативы.

## Документация
- `docs/process/release_versioning.md` (новые нюансы Windows-сборки), CHANGELOG при замене механизма.
