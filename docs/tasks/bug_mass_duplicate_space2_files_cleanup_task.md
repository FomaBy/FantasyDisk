# BUG: Массовая дубликация файлов с суффиксом « 2» (Finder/sync) — чистка + источник

Статус: in_progress
Приоритет: high
Роль: Back-end / Tooling
Версия: 0.1.6
Создано: 2026-06-15
Автор: QA (находка при SCRUM-422)
Jira: SCRUM-440

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
