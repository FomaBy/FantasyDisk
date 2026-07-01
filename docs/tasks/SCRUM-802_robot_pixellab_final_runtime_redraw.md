# ART/ANIM PixelLab: «Робот» (robot) — final 8-direction runtime redraw

Статус: new
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.1.8
Создано: 2026-07-01
Jira: SCRUM-802
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
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
