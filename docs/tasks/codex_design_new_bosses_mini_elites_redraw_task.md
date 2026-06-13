# Codex Design Task: New Bosses And Mini-Elites Canonical Redraw

Статус: done (superseded 2026-06-13; covered by SCRUM-156)
Версия: 0.1.4
Создано: 2026-06-13
Роль: Design / Codex image generation
Jira: SCRUM-180
Parent audit: `docs/tasks/audit_sprites_visual_consistency.md` / SCRUM-177

## Goal

Replace the placeholder/tint visual identity for SCRUM-155 roster additions with canonical D&D/dark-fantasy painterly sprites.

## Scope

Create final transparent PNG sprites for:

- `boss_bone_archon`
- `boss_brood_mother`
- `boss_ashen_colossus`
- `mini_scavenger_reaper`
- `mini_plague_bellringer`
- `mini_bone_warden`
- `mini_spark_wight`
- `mini_rot_hound`
- `mini_shadow_devourer`

Exact destination paths must be confirmed against scene/resource integration before generation. If Back-end needs new scene texture paths or registry hooks, create a Back-end handoff instead of editing gameplay logic here.

## Art Direction

- Match `assets/sprites/enemies/*`, `assets/sprites/elites/*`, `assets/sprites/bosses/boss_disk_devourer.png`, and `assets/sprites/bosses/boss_rift_warden.png`.
- Painterly D&D dark fantasy, strong silhouette, readable at battle scale, transparent background.
- Bosses should be larger/more imposing than standard enemies and have unique visual language.
- Mini-elites should be distinct enough to read without relying on runtime tint.

## Acceptance

- Contact sheet before/after in `docs/design/previews/`.
- PNG sizes and alpha validated.
- Content registry/current game state updated.
- Animator handoff created if cutout/rig/motion is required.

## Dispatcher Note (2026-06-13)
Duplicate audit: this scope is covered by active `design_codex_new_bosses_mini_elites_sprites_task.md` / Jira `SCRUM-156`. Requirements were sent to the Design thread as additional acceptance context for SCRUM-156 instead of dispatching a duplicate source task.
