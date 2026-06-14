# BUG: Tracked backup `.import` sidecars вызывают 85 UID-дублей при импорте

Статус: new
Приоритет: low
Роль: Back-end / Tooling
Версия: 0.1.5
Создано: 2026-06-14
Автор: QA (находка при SCRUM-337)
Связано: SCRUM-337, SCRUM-340, hero-select dragon, summons ethereal

## Контекст
При `--import` Godot выдаёт **85 предупреждений** `UID duplicate detected`:
бэкап-папки в `docs/design/backups/` содержат `.import` sidecars с теми же UID,
что и живые ассеты (бэкапы делались копированием PNG **вместе с** их `.import`).

Затронутые backup-папки (162 `.import` всего):
- `docs/design/backups/attack_vfx_pre_scrum337_2026_06_14/`
- `docs/design/backups/artifact_icons_pre_scrum340_2026_06_14/`
- `docs/design/backups/hero_select_frames_pre_dragon/`
- `docs/design/backups/summon_noglow/`

## Severity / Impact
Низкий — это **WARNING**, не error; все тесты (attack_vfx/hazard/enemy_projectile/
unique_weapon/animation/runtime smoke) зелёные. Но дубли UID — латентный риск:
Godot может разрешить `uid://...` в backup-файл вместо живого ассета, что даёт
труднодиагностируемые визуальные регрессии.

## Что нужно
1. Убрать дубли UID из импорт-скоупа проекта. Варианты (на выбор Back-end):
   - удалить `.import` sidecars внутри `docs/design/backups/**` (бэкапам импорт не
     нужен — это архив исходных PNG), **или**
   - перенести backups за пределы Godot project import scope (напр. в gitignored
     `build/backups/` или внешнюю папку), **или**
   - перегенерировать `.import` бэкапов с уникальными UID.
2. Закрепить правило в backup-процедуре (asset-generator/animation skill handoff):
   при бэкапе ассетов **не копировать** `.import` sidecars (или сразу чистить UID).
3. После чистки: `--import` без `UID duplicate` warning; smoke-тесты зелёные.

## Acceptance Criteria
- [ ] `Godot --headless --import` не выдаёт `UID duplicate detected` (0 warning).
- [ ] Живые ассеты грузятся корректно; attack_vfx + runtime smoke PASS.
- [ ] Backup-процедура задокументирована (не плодить дубли UID впредь).

## Files
- `docs/design/backups/**/*.import` (источник дублей)
- (опц.) backup-хелперы в `tools/` / skill handoff docs
- `tests/attack_vfx_smoke_test.gd`, `tests/runtime_smoke_test.gd` (регрессия)

## Verification command
```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --user-data-dir /private/tmp/uidcheck --path "$PWD" --import 2>&1 \
  | grep -c "UID duplicate detected"   # должно стать 0
```
