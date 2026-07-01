# ART/ANIM PixelLab: «Рейнджер» (ranger) — final 8-direction runtime redraw

Статус: new
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.1.8
Создано: 2026-07-01
Jira: SCRUM-804
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `assets/sprites/characters/pixellab/ranger/`, `assets/sprites/characters/full_frame/ranger_pixellab/`, `assets/sprites/characters/ranger_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.

## Context / Problem

`ranger` still uses legacy non-PixelLab runtime art in active `dev`. No dedicated
PixelLab-final ranger ticket existed before this issue; older broad art tasks are
historical and not live PixelLab runtime.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. The base body must
stay empty-handed: no baked bow, crossbow, trap, projectile, or UI frame.

References: `docs/design/references/characters/ranger/ranger_sheet_source.png`,
`assets/sprites/characters/ranger.png`, `assets/sprites/characters/full_frame/ranger/`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/ranger/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/ranger_pixellab/`.
- `assets/sprites/characters/ranger_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `ranger.sprite_path` to `res://assets/sprites/characters/full_frame/ranger_pixellab/ranger_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.
