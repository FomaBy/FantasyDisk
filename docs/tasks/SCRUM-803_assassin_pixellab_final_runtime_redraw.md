# ART/ANIM PixelLab: «Ассасин» (assassin) — final 8-direction runtime redraw

Статус: new
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.1.8
Создано: 2026-07-01
Jira: SCRUM-803
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `assets/sprites/characters/pixellab/assassin/`, `assets/sprites/characters/full_frame/assassin_pixellab/`, `assets/sprites/characters/assassin_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.

## Context / Problem

`assassin` still uses legacy/v2 non-PixelLab runtime art in active `dev`.
SCRUM-419 was a v2 design-source handoff and is already done; this ticket is the
PixelLab-final live runtime pass.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. The base body must
stay empty-handed: no baked chakrams, daggers, venom wire, or UI frame.

References:
`docs/design/references/characters_v2/assassin/assassin_v2_source_clean.png`,
`docs/design/references/characters/assassin/assassin_sheet_source.png`,
`assets/sprites/characters/assassin.png`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/assassin/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/assassin_pixellab/`.
- `assets/sprites/characters/assassin_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `assassin.sprite_path` to `res://assets/sprites/characters/full_frame/assassin_pixellab/assassin_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.
