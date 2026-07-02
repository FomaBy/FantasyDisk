# Refactor Wave: Scene/Resource Reference Integrity And Load-Path Audit

Jira: SCRUM-723
Статус: done
Приоритет: P2
Роль: Back-end / resource quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.2.0
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

## QA-Вердикт
Статус: PASSED

QA claim claude-qa 2026-06-30 — приёмка на origin/dev HEAD (commits 2f184974 audit + f3fdc2a2 mirror).

- Аудит ссылочной целостности записан → docs/design/content_registry.md §SCRUM-723.
- Broken references: 0 (нечего фиксить/филить). Asset deletion: НЕ выполнялось (0 deletions в diff).
- Версия консистентна: project.godot config/version=0.1.7 и все поля export_presets.cfg=0.1.7, без дрейфа.
- Гейт усилен: asset_reference_integrity сканирует .tres в assets/ (ловит битую SpriteFrames→atlas ссылку).

Гейты (godot_gate.py, fdengine slots=1, Godot 4.7) — все PASS:
- `asset_reference_integrity_test` → passed (184 файла, 1746 уникальных res://-ссылок).
- `weapon_scene_integrity_test` → passed (51 оружие, scene_path резолвятся, 35/35 attack-режимов).
- `content_registry_consistency_test` → passed (0 allowlisted).
- `runtime_smoke_test` → passed (11647 файлов, dup-guard ok).

→ PASSED.
