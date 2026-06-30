# Refactor Wave: Scene/Resource Reference Integrity And Load-Path Audit

Jira: SCRUM-723
Статус: new
Приоритет: P2
Роль: Back-end / resource quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-resources, area-integrity
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task is a reference integrity pass for scenes, project config and load paths. It must not become a broad asset deletion task without proof.

## Scope / Locked Paths

- `project.godot`
- `export_presets.cfg`
- Selected `.tscn` files only after reference proof
- `tests/asset_reference_integrity_test.gd`
- `tests/weapon_scene_integrity_test.gd`
- `docs/design/content_registry.md` if canonical references change

## Required Change

Audit and safely fix scene/resource reference integrity: broken `res://` paths, stale scene scripts, duplicate class/resource references, export preset drift, tracked sidecars that should not exist and scene defaults that disagree with data registries. Do not delete assets without proof, backup/evidence and Jira rationale.

## Acceptance Criteria

- Scene/resource audit is recorded.
- Broken references are fixed or filed as scoped follow-up issues.
- No asset deletion happens without reference proof and backup/evidence.
- Scene defaults remain consistent with data registries.
- Asset/reference integrity tests pass.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/asset_reference_integrity_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_scene_integrity_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/content_registry_consistency_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
