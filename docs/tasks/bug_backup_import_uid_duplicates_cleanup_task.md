# BUG: Tracked backup `.import` sidecars вызывают 85 UID-дублей при импорте

Статус: done
Приоритет: low
Роль: Back-end / Tooling
Версия: 0.1.5
Jira: SCRUM-405
Создано: 2026-06-14
Автор: QA (находка при SCRUM-337)
QA: in_progress (2026-06-14)
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

## Result
Done 2026-06-14 (Codex Back-end):
- Добавлен `docs/design/backups/.gdignore`, чтобы архивные PNG в backup-root не
  попадали в Godot import scope и не получали duplicate UID относительно live
  ассетов.
- Удалены 162 tracked `.import` sidecars из `docs/design/backups/**`; backup PNG
  сохранены, live `assets/**` не тронуты.
- Закреплено правило backup hygiene в
  `docs/process/agent_role_boundaries_and_handoffs.md`; `tools/add_summon_contour_glow.py`
  явно документирует, что `.import` не копируются в backup, а
  `tools/build_hero_select_carousel_frame.py` больше не копирует `.import` в
  архивную папку.
- Verification:
  - `find docs/design/backups -name '*.import' | wc -l` → `0`
  - `Godot --headless --user-data-dir /private/tmp/uidcheck_scrum405_b --path ... --import` → `UID duplicate detected` count `0`
  - `res://tests/attack_vfx_smoke_test.gd` → PASS
  - `res://tests/runtime_smoke_test.gd` → PASS

## QA-Вердикт (2026-06-14)
Статус: PASSED — UID-дубли устранены (85 → 0), live-ассеты целы

Проверено (фактически, фикс делал отдельный Back-end/Tooling воркер):
- **UID-дубли 85 → 0**: `Godot --headless --import` теперь даёт `UID duplicate
  detected` count = **0** (было 85). Корень устранён.
- **Backup `.import` удалены**: `find docs/design/backups -name '*.import' | wc -l`
  = **0** (было 162); 162 backup PNG **сохранены** (архив цел).
- **`.gdignore`** в `docs/design/backups/` присутствует — backup-root вне Godot
  import scope.
- **Live-ассеты не тронуты**: 85 PNG в `assets/sprites/effects|projectiles` на месте.
- **Правило закреплено**: `docs/process/agent_role_boundaries_and_handoffs.md`
  → секция «Asset Backup Hygiene» (не копировать `.import` в backup);
  `build_hero_select_carousel_frame.py` бэкапит в gitignored `build/`.
- **Регрессия**: `attack_vfx_smoke_test` + `runtime_smoke_test` — PASS (live VFX
  грузятся корректно после чистки).

Acceptance:
- [x] `--import` без `UID duplicate detected` (0 warning).
- [x] Живые ассеты грузятся; attack_vfx + runtime smoke PASS.
- [x] Backup-процедура задокументирована (не плодить дубли UID впредь).

Статус done. Баги: нет. Петля закрыта: находка (QA при 337) → фикс (SCRUM-405).
