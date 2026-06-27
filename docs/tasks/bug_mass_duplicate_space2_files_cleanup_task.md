# BUG: Массовая дубликация файлов с суффиксом « 2» (Finder/sync) — чистка + источник

Статус: done
Приоритет: high
Роль: Back-end / Tooling
Версия: 0.1.6
Создано: 2026-06-15
Автор: QA (находка при SCRUM-422)
Jira: SCRUM-440
QA: in_progress (2026-06-15)

## Контекст
В репозитории расплодились дубликаты файлов с macOS-суффиксом « 2» (Finder
«Дублировать» / `cp` / rsync-без-delete): `<name> 2.<ext>`, `<name> 2.<ext>.uid`,
`<name>.<ext> 2.uid`. Появлялись минимум дважды (14.06 ~21:13 и снова к 15.06).

**Критично:** среди них есть дубли `.gd`-скриптов
(`scripts/run_autosave 2.gd`, `feedback_reporter 2.gd`, `status_effects 2.gd`,
`full_frame_animation_registry 2.gd`, +десятки тестов) с повторными `class_name`
→ Godot падает на импорте: `Parse Error: Class "RunAutosave" hides a global
script class` → **красный working-tree** (ломает green-gate всем агентам).

QA уже удалил untracked « 2.gd»/.md дубли (working-tree снова зелёный), но проблема
шире и частично **закоммичена**.

## Масштаб (на 2026-06-15)
- **~592 TRACKED « 2»-файла** (закоммичены чьим-то `git add -A`): ~365 `.import`,
  ~201 `.png` (в основном docs/design/previews), ~14 `.md`, ~11 `.json`.
- Сотни UNTRACKED « 2» дублей (.gd/.uid/.import/.png/...). `.gd`-дубли — самые
  опасные (ломают компиляцию).
- Ранее QA вручную удалял 162 « 2.md» в docs/tasks (разовая чистка) — рецидив.

## Что нужно
1. **Удалить ВСЕ « 2»-дубли** (tracked + untracked), убедившись для каждого, что
   это побайтовый дубль tracked-оригинала (`cmp -s` с `<name>.<ext>`), а не
   уникальный файл. Tracked — через `git rm`; untracked — `rm`.
   Паттерны: `* 2.<ext>`, `* 2.<ext>.uid`, `*.<ext> 2.uid`, `.gdignore 2`.
2. **Найти и устранить ИСТОЧНИК** дубликации: какой tool/скрипт/sync делает
   `cp -r`/Finder-duplicate каталогов (scripts/tests/docs/assets). Проверить
   feedback-intake/asset-generator/backup-хелперы, cron, rsync. Починить, чтобы
   рецидива не было.
3. Добавить guard: тест/скрипт, проверяющий что в репо нет файлов с « 2.»/« 2$»
   в имени (CI/pre-commit), чтобы дубли не коммитились впредь.

## Acceptance Criteria
- [ ] 0 файлов с « 2»-суффиксом-дублем (tracked + untracked); `git ls-files | grep ' 2'` пусто.
- [ ] `Godot --headless --import` без `hides a global script class`; runtime_smoke 3/3 зелёные.
- [ ] Источник дубликации найден и устранён (рецидива нет); guard-проверка добавлена.
- [ ] Уникальные файлы НЕ удалены (каждое удаление — verified дубль оригинала).

## Verification
```bash
git ls-files | grep -E " 2\.| 2$" | wc -l          # → 0
find . -name "* 2.*" -not -path "./.git/*" | wc -l  # → 0 (untracked тоже)
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --user-data-dir /tmp/dc --path "$PWD" --import 2>&1 | grep -c "hides a global"  # → 0
```

## Files
- Весь репозиторий (scripts/, tests/, docs/, assets/) — « 2»-дубли
- Источник: tools/ (feedback_intake, asset/animation helpers, backup), cron/sync

## Dispatcher Handoff

2026-06-15: Routed to existing Back-end window
`019eabd9-780b-78a2-9f4b-e7203d659ef2` as an eligible high-priority
Back-end/tooling bug in Sprint 0.1.6. Keep reasoning High/no low.

## Результат

2026-06-15 Back-end/Tooling:
- Удалены все найденные ` 2` duplicate artifacts после проверки оригиналов:
  629 tracked путей через `git rm` (байт-идентичные source/metadata файлы +
  generated `.import` sidecars для duplicate filenames), 230 untracked/generated
  путей, `.godot` cache-дубли, пустые duplicate-каталоги, `build/dmg`
  release-staging `FantasyDisk 2.app`/`Applications 2` и stale backup-carrier
  `build/cleanup_backup_dupes_2026_06_14`.
- Уникальные source files не удалялись: non-sidecar tracked files сверены как
  byte-identical к оригиналам; `.import` sidecars удалены как generated Godot
  metadata для уже удаляемых duplicate paths; `FantasyDisk 2.app` сверена с
  `FantasyDisk.app` через `diff -qr`.
- Источник рецидива: старый backup-carrier под `build/cleanup_backup_dupes_2026_06_14`
  сохранил ` 2` дерево, а прежний guard проверял только часть файловых сигнатур
  и пропускал directory tails/build backups. Backup удалён; guard расширен.
- Добавлен permanent guard `tests/no_duplicate_artifact_files_test.gd` для файлов
  и каталогов с ` 2`/` 2.<ext>`; полный `runtime_smoke_test.gd` теперь запускает
  такой же ранний check до загрузки `Main.tscn`.

Verification:
- `git ls-files | grep -E ' 2\.| 2$|\.gdignore 2$' | wc -l` → `0`.
- `find . -path ./.git -prune -o \( -name '* 2.*' -o -name '* 2' \) -print | wc -l` → `0`.
- `tests/no_duplicate_artifact_files_test.gd` PASS (`8029` files scanned).
- Godot `--import`: `grep -c 'hides a global'` → `0`.
- `tests/runtime_smoke_test.gd` PASS 3/3 consecutive runs.
- QA note: `build/qa/scrum440/duplicate_cleanup_report.md`.

## QA-Вердикт (2026-06-15)
Статус: PASSED — все « 2»-дубли вычищены, источник устранён, guard добавлен и зелёный

Проверено (фактически, текущее состояние):
- **AC1 — 0 « 2»-дублей**: `git ls-files | grep -E ' 2\.| 2$|\.gdignore 2$'` → **0**;
  `find . -path ./.git -prune -o \( -name '* 2.*' -o -name '* 2' \) -print` → **0**
  (tracked + untracked). 629 tracked-дублей удалены `git rm` (staged), untracked — `rm` ✓.
- **AC2 — компиляция/тесты**: `--import` `grep -c 'hides a global'` → **0** (нет
  `Class … hides a global script class`); `runtime_smoke_test` **3/3 зелёный**; standalone
  `no_duplicate_artifact_files_test` PASS (8029 файлов) ✓.
- **AC3 — источник + guard**: рецидив-источник найден (backup-carrier
  `build/cleanup_backup_dupes_2026_06_14` хранил « 2»-дерево) и удалён; добавлен
  permanent guard `tests/no_duplicate_artifact_files_test.gd` + ранний check в
  runtime_smoke. **Scope guard'а корректен**: `SKIP_DIRS=[.godot,.git,tmp,node_modules]`
  + `SKIP_PATH_PREFIXES=[res://build/dmg]` — исключает релиз-staging (где забандленные
  bundles/symlinks типа iMovie.app дают легитимные « N»-файлы), так что повторных
  ложных срабатываний на релиз-билдах не будет ✓.
- **AC4 — уникальные целы**: каждое удаление — verified байт-идентичный дубль оригинала
  (`cmp`/`diff -qr`); репозиторий компилится, все smoke зелёные → уникальный source не потерян ✓.

Acceptance:
- [x] 0 файлов с « 2»-суффиксом-дублем (tracked + untracked).
- [x] `--import` без `hides a global`; runtime_smoke 3/3 зелёные.
- [x] Источник устранён; guard добавлен (+ исключение build/dmg от ложных « N»).
- [x] Уникальные файлы не удалены (verified дубли).

Статус done → Готово. Баги: нет. Закрывает массовую дубликацию + защищает от рецидива.
⚠️ Замечание QA: на промежуточном тике guard падал на 20638 « N»-файлах из
`build/dmg/.../iMovie.app` (релиз-staging) — воркер устранил, добавив `res://build/dmg`
в skip; на момент вердикта guard зелёный и scope верный.
