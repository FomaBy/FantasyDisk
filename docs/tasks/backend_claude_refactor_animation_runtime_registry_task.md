# Refactor Wave: Animation Runtime Registry And Rig Loading Audit

Jira: SCRUM-721
Статус: done
Приоритет: P2
Роль: Back-end / animation runtime quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-animation, area-runtime
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This is a runtime-code audit for animation registries/loaders only. Animator-owned motion, clips and visual polish are out of scope.

## Scope / Locked Paths

- `scripts/full_frame_animation_registry.gd`
- `scripts/cutout_rig_2d.gd`
- `scripts/skeleton_player_rig_2d.gd`
- `scripts/sliced_rig_manifest.gd`
- Animation tests
- `docs/design/systems/animation.md`

## Required Change

Audit and safely refactor animation runtime code only: SpriteFrames registry fallback, cutout/sliced/skeleton rig resource loading, pivot/rest validation, play-state adapters, visible-body lookup and parse/import safety. Do not change animation art, motion direction, or Animator-owned clips; create an Animator handoff if real motion work is needed.

## Acceptance Criteria

- Animation runtime audit is recorded.
- SpriteFrames/cutout/skeleton fallback behavior remains compatible.
- Missing resources fail safely with clear evidence.
- No animation art, motion timing or rig clip design is changed in this task.
- Focused animation tests cover changed loader/registry behavior.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/sliced_rig_manifest_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/skeletal_rig_rest_det_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## QA-Вердикт
Статус: PASSED

Проверял claude-qa (2026-06-30) на чистом изолир. worktree от origin/dev HEAD, fdengine slots=1. Коммиты `923bd3f6` (гейт+док) + `3adb5298` (mirror) — ancestor origin/dev подтверждён.

Scope: коммит test-only + doc (`full_frame_registry_integrity_test.gd` +71 +uid, `animation.md` +23). Анимация-рантайм/арт/клипы НЕ тронуты.

Code review нового гейта: итерирует ВСЕ записи `FULL_FRAME_SPRITEFRAMES`, грузит через тот же рантайм-путь `sprite_frames_for` (ловит битый/пустой .tres, который `ResourceLoader.exists` пропустит), проверяет SpriteFrames + ≥1 анимацию + типы полей (scale/position=Vector2, source_faces_left=bool), вакуум-гард (<20 записей → fail) и контракт безопасного фолбэка (незарегистр. id → null без краша). Прямо закрывает найденный пробел (протухший путь молча → null, потеря визуала без улики) и AC (missing resources fail safely WITH evidence).

Гейты (fdengine slots=1, все pass):
- `full_frame_registry_integrity_test` → passed (**30 записей**, все грузятся с ≥1 анимацией; 0 missing).
- `animation_smoke_test` → passed.
- `sliced_rig_manifest_smoke_test` → passed (34 рига, 17 персонажей).
- `skeletal_rig_rest_det_smoke_test` → passed (40 bones, 2 rigs).
- `character_sprite_registry_alignment_test` → passed (17 персонажей).

→ PASSED.
