# ART/ANIM PixelLab: «Элементалист» (elementalist) — final 8-direction runtime redraw

Статус: blocked
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.2.0
Создано: 2026-07-01
Jira: SCRUM-801
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `assets/sprites/characters/pixellab/elementalist/`, `assets/sprites/characters/full_frame/elementalist_pixellab/`, `assets/sprites/characters/elementalist_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.

## Context / Problem

`elementalist` still uses legacy/v2 non-PixelLab runtime art in active `dev`.
SCRUM-427 was a v2 design-source handoff and is already done; this ticket is the
PixelLab-final live runtime pass.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. The base body must
stay empty-handed: no baked staff, orb, prism, meteor, focus, or UI frame.

References:
`docs/design/references/characters_v2/elementalist/elementalist_v2_source_clean.png`,
`docs/design/references/characters/elementalist/elementalist_sheet_source.png`,
`assets/sprites/characters/elementalist.png`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/elementalist/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/elementalist_pixellab/`.
- `assets/sprites/characters/elementalist_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `elementalist.sprite_path` to `res://assets/sprites/characters/full_frame/elementalist_pixellab/elementalist_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.

## Result / Serial Integration — 2026-07-01

Combined integration branch: `codex/character-pixellab-serial-integration-20260701`.
Integration commit: `d97b8f84` (first functional integration commit on this branch).

Source branch/commit: `origin/codex/scrum-801-elementalist-pixellab` @ `7c3f45b8`.

Integrated:
- PixelLab source/manifest under `assets/sprites/characters/pixellab/elementalist/`.
- Normalized runtime `512x512` frames under `assets/sprites/characters/full_frame/elementalist_pixellab/`.
- `assets/sprites/characters/elementalist_spriteframes.tres` with generic `idle`/`move`/`walk` plus 8-direction `idle_*`, 6-frame `move_*`, and 6-frame `walk_*` rows.
- `scripts/progression_data_characters.gd` now points `elementalist.sprite_path` to `res://assets/sprites/characters/full_frame/elementalist_pixellab/elementalist_idle_south.png`.
- `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `tests/animation_smoke_test.gd`, `tests/character_sprite_registry_alignment_test.gd`, and `tests/hero_select_pixellab_layout_test.gd` updated for the live PixelLab contract.

PixelLab source id: `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`; group id
`af7f3eee-e126-424c-b4ab-1c6d2f28596b`; rejected predecessor
`3068581d-2ff2-4203-ba5e-37c56edefdc6`.

Tests/evidence:
- PASS: static integration validator checked 56 source PNGs, 56 runtime PNGs, `512x512` RGBA runtime frames, manifest, SpriteFrames directional names, canonical sprite path, and no `.import`/`.uid` sidecars for Soldier/Thief/Elementalist/Robot.
- BLOCKED: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` waited for the shared semaphore but did not launch Godot because all default slots were held by unrelated `unique_weapon_vfx_assets_test.gd` import processes. The queued gate was interrupted with exit 130 to avoid an indefinite wait; after fast-forwarding to `origin/dev` (`39fca93c`), static validation still passed and a process recheck still showed multiple unrelated `unique_weapon_vfx_assets_test.gd` Godot/gate jobs occupying or waiting on the shared gate. No Elementalist test failure was observed.
- Restored source-branch QA evidence under `build/qa/scrum801_elementalist_pixellab/`.

Disk cleanup: none created by this integration run; no `.godot/`, Python cache, or temp download directory was created here. Imported QA evidence is intentionally kept.

## Gate Rerun / Environment Blocker — 2026-07-01

Thread/Worker: `codex-character-gate-rerun-20260701`.
Branch: `codex/character-pixellab-serial-integration-20260701` @ `a97e3eb9`.

Static validation PASS for the combined Soldier/Thief/Elementalist/Robot scope:
56 source PNGs, 56 runtime PNGs, manifests, 56 SpriteFrames texture refs,
canonical `*_idle_south.png` `sprite_path` values, and no task-owned
`.import`/`.uid` sidecars. Evidence:
`build/qa/character_gate_rerun_20260701/static_pack_validation.json`.

Godot gates are still environment-blocked, not product-failed. The worker
queued `res://tests/animation_smoke_test.gd` through `tools/godot_gate.py` twice:
first with default slots, then with `FSD_GODOT_SLOTS=6`, both with
`FSD_GODOT_MAXWAIT=86400` so the command would not fall through and bypass the
semaphore. Both attempts stayed queued and were interrupted before Godot
launched; `animation_smoke_test.log` remained empty. Final snapshot
`build/qa/character_gate_rerun_20260701/semaphore_blocker_snapshot.txt` shows all
six observed semaphore slots held by unrelated Godot/gate jobs
(`unique_weapon_vfx_assets_test.gd`, attack VFX, ranger pack/import). Required
gates still not completed: `animation_smoke_test.gd`,
`hero_select_pixellab_layout_test.gd`,
`character_sprite_registry_alignment_test.gd`, and `runtime_smoke_test.gd`.

No real Soldier/Thief/Elementalist/Robot defect was observed. Do not regenerate
art or re-integrate unless a future gate reports a concrete product failure.
Jira is released from active ownership until the semaphore clears.
Disk cleanup: no `.godot/` or user-data cache was created by this worker; only
the committed `build/qa/character_gate_rerun_20260701/` evidence files were
created.
