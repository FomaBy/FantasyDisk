# Codex Design Task: Legacy Sprite Cleanup Spec

Статус: in_progress (Codex Design, dispatched 2026-06-13)
Версия: 0.1.5
Создано: 2026-06-13
Роль: Design audit/spec + Back-end cleanup handoff
Jira: SCRUM-183
Parent audit: `docs/tasks/audit_sprites_visual_consistency.md` / SCRUM-177

## Goal

Confirm and remove/archive obsolete placeholder/prototype sprite assets that are no longer part of the active FantasyDisk visual pipeline.

## Candidate Assets

- `assets/sprites/characters/*_placeholder.png`
- `assets/sprites/player_berserk.png`
- `assets/sprites/player_ranger.png`
- `assets/sprites/player_summoner.png`
- root-level `assets/sprites/enemy_*.png`
- `assets/sprites/boss_warden.png`

## Important Exception

Do not remove `assets/sprites/characters/berserk_walk_sheet_v2.png` in this cleanup. It is still referenced by `scripts/player.gd` as a live Berserk animation resource.

## Process

1. Back-end/file-cleanup owner confirms no active runtime, scene, codex, UI, or tests reference each candidate.
2. Design confirms the candidate is visually obsolete and not needed as a source/reference.
3. Remove or archive with docs update.

## Acceptance

- No active scene/script/codex reference breaks.
- Project import remains clean.
- Runtime smoke passes after cleanup.

## Dispatcher Note (2026-06-13)
Dispatched to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after user confirmed no feature freeze / backlog is eligible.
