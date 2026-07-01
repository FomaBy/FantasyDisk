# ART/ANIM PixelLab: «Вор» (thief) — final 8-direction runtime redraw

Статус: blocked
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.1.8
Создано: 2026-07-01
Jira: SCRUM-800
Контур: Codex
Owner: Codex character serial integration worker
Thread/Worker: codex-character-serial-integration-20260701
Locked paths: `assets/sprites/characters/pixellab/thief/`, `assets/sprites/characters/full_frame/thief_pixellab/`, `assets/sprites/characters/thief_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.

## Context / Problem

`thief` still uses legacy/v2 non-PixelLab runtime art in active `dev`. SCRUM-435
was a v2 design-source handoff and is already done; this ticket is the
PixelLab-final live runtime pass.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. The base body must
stay empty-handed: no baked coin, dagger, smoke bomb, pouch weapon, or UI frame.

References: `docs/design/references/characters_v2/thief/thief_v2_source_clean.png`,
`docs/design/references/characters/thief/thief_sheet_source.png`,
`assets/sprites/characters/thief.png`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/thief/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/thief_pixellab/`.
- `assets/sprites/characters/thief_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `thief.sprite_path` to `res://assets/sprites/characters/full_frame/thief_pixellab/thief_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.

## Result / Serial Integration — 2026-07-01

Combined integration branch: `codex/character-pixellab-serial-integration-20260701`.
Integration commit: `PENDING_FIRST_COMMIT` (first functional integration commit on this branch).

Source branch/commit: `origin/codex/scrum-800-thief-pixellab` @ `2542e4dd`.

Integrated:
- PixelLab source/manifest under `assets/sprites/characters/pixellab/thief/`.
- Normalized runtime `512x512` frames under `assets/sprites/characters/full_frame/thief_pixellab/`.
- `assets/sprites/characters/thief_spriteframes.tres` with generic `idle`/`move`/`walk` plus 8-direction `idle_*`, 6-frame `move_*`, and 6-frame `walk_*` rows.
- `scripts/progression_data_characters.gd` now points `thief.sprite_path` to `res://assets/sprites/characters/full_frame/thief_pixellab/thief_idle_south.png`.
- `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `tests/animation_smoke_test.gd`, `tests/character_sprite_registry_alignment_test.gd`, and `tests/hero_select_pixellab_layout_test.gd` updated for the live PixelLab contract.

PixelLab source id: `02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f`; base id
`77a21499-0ae6-4600-873e-29cb7ee70630`; rejected first attempt
`e35fa768-5708-4d55-a082-a535057654f0`.

Tests/evidence:
- PASS: static integration validator checked 56 source PNGs, 56 runtime PNGs, `512x512` RGBA runtime frames, manifest, SpriteFrames directional names, canonical sprite path, and no `.import`/`.uid` sidecars for Soldier/Thief/Elementalist/Robot.
- BLOCKED: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` waited for the shared semaphore but did not launch Godot because all default slots were held by unrelated `unique_weapon_vfx_assets_test.gd` import processes. The queued gate was interrupted with exit 130 to avoid an indefinite wait; after fast-forwarding to `origin/dev` (`39fca93c`), static validation still passed and a process recheck still showed multiple unrelated `unique_weapon_vfx_assets_test.gd` Godot/gate jobs occupying or waiting on the shared gate. No Thief test failure was observed.
- Restored source-branch QA evidence under `build/qa/scrum800_thief_pixellab/`.

Disk cleanup: none created by this integration run; no `.godot/`, Python cache, or temp download directory was created here. Imported QA evidence is intentionally kept.
