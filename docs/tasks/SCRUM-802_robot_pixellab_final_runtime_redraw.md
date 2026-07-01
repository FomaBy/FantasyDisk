# ART/ANIM PixelLab: «Робот» (robot) — final 8-direction runtime redraw

Статус: blocked
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.1.8
Создано: 2026-07-01
Jira: SCRUM-802
Контур: Codex
Owner: Codex character serial integration worker
Thread/Worker: codex-character-serial-integration-20260701
Locked paths: `assets/sprites/characters/pixellab/robot/`, `assets/sprites/characters/full_frame/robot_pixellab/`, `assets/sprites/characters/robot_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.

## Context / Problem

`robot` still uses legacy/v2 non-PixelLab runtime art in active `dev`. SCRUM-432
is historical v2/cancelled scope; this ticket is the PixelLab-final live runtime
pass.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. Keep the look dark
fantasy metal and tank-control readable, not a sci-fi toy. The base body must
stay empty-handed: no baked magnet, press, reactor VFX, or UI frame.

References: `docs/design/references/characters_v2/robot/robot_v2_source_clean.png`,
`docs/design/references/characters/robot/robot_sheet_source.png`,
`assets/sprites/characters/robot.png`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/robot/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/robot_pixellab/`.
- `assets/sprites/characters/robot_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `robot.sprite_path` to `res://assets/sprites/characters/full_frame/robot_pixellab/robot_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.

## Result / Serial Integration — 2026-07-01

Combined integration branch: `codex/character-pixellab-serial-integration-20260701`.
Integration commit: `d97b8f84` (first functional integration commit on this branch).

Source branch/commit: `origin/codex/scrum-802-robot-pixellab` @ `763f0978`.

Integrated:
- PixelLab source/manifest under `assets/sprites/characters/pixellab/robot/`.
- Normalized runtime `512x512` frames under `assets/sprites/characters/full_frame/robot_pixellab/`.
- `assets/sprites/characters/robot_spriteframes.tres` with generic `idle`/`move`/`walk` plus 8-direction `idle_*`, 6-frame `move_*`, and 6-frame `walk_*` rows.
- `scripts/progression_data_characters.gd` now points `robot.sprite_path` to `res://assets/sprites/characters/full_frame/robot_pixellab/robot_idle_south.png`.
- `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `tests/animation_smoke_test.gd`, `tests/character_sprite_registry_alignment_test.gd`, and `tests/hero_select_pixellab_layout_test.gd` updated for the live PixelLab contract.

PixelLab source id: `37c6ccf2-ab40-4c89-83a3-db8365f85257`; group id
`1fd2462e-d72b-453d-8fa2-0ed8fd5e2990`; superseded draft
`a6fed769-5ebf-4fb3-8e6b-35357222fbdd`.

Tests/evidence:
- PASS: static integration validator checked 56 source PNGs, 56 runtime PNGs, `512x512` RGBA runtime frames, manifest, SpriteFrames directional names, canonical sprite path, and no `.import`/`.uid` sidecars for Soldier/Thief/Elementalist/Robot.
- BLOCKED: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` waited for the shared semaphore but did not launch Godot because all default slots were held by unrelated `unique_weapon_vfx_assets_test.gd` import processes. The queued gate was interrupted with exit 130 to avoid an indefinite wait; after fast-forwarding to `origin/dev` (`39fca93c`), static validation still passed and a process recheck still showed multiple unrelated `unique_weapon_vfx_assets_test.gd` Godot/gate jobs occupying or waiting on the shared gate. No Robot test failure was observed.
- Restored source-branch QA evidence under `build/qa/scrum802_robot_pixellab/`.

Disk cleanup: none created by this integration run; no `.godot/`, Python cache, or temp download directory was created here. Imported QA evidence is intentionally kept.
