# Codex Design Task: Legacy Sprite Cleanup Spec

Статус: done (Design spec signed off 2026-06-13)
Версия: 0.1.4
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

## Result (2026-06-13)

Design cleanup spec completed without deleting or moving any assets.

Created:

- `docs/design/reviews/legacy_sprite_cleanup_spec_2026_06.md`

Updated Back-end handoff:

- `docs/tasks/backend_content_safe_cleanup_followup_task.md`

Design confirms the listed placeholder/prototype character sprites, root `player_*.png`, root `enemy_*.png`, and root `boss_warden.png` are visually obsolete cleanup candidates. Back-end must still perform final manifest/runtime checks, safe archive/removal and smoke tests.

Explicit Design keep list:

- `assets/sprites/characters/berserk_walk_sheet_v2.png` — live via `scripts/player.gd`;
- `assets/sprites/projectiles/enemy_projectile_magic_64.png` — live projectile;
- `assets/sprites/enemies/*.png` — active enemy roster source paths.


## Design Sign-off / 2026-06-13 — ПОДПИСАНО (Claude-Designer)
Design-проверка кандидатов завершена (read-only, ничего не удалялось):
- `*_placeholder.png` — 0 ссылок в scripts/ (player.gd ранее переведён на рестайл-`*.png`) → устаревшие.
- `player_berserk/ranger/summoner.png`, `boss_warden.png` — упоминаются ТОЛЬКО в
  `scripts/generate_prototype_sprites.py` (генератор-прототипов их создаёт, не рантайм-потребитель) → устаревшие.
- root `enemy_*.png` — устаревшие прототипы (активный ростер — `assets/sprites/enemies/*.png`, keep).
- KEEP подтверждён: `berserk_walk_sheet_v2.png` (жив в player.gd), `enemies/*.png`, `enemy_projectile_magic_64.png`.
ВНИМАНИЕ Back-end: при удалении учесть `generate_prototype_sprites.py` (legacy-генератор тех же файлов —
либо тоже архивировать, либо он перезапишет удалённое). Финальный manifest/runtime-smoke — Back-end
(`backend_content_safe_cleanup_followup_task.md`).
