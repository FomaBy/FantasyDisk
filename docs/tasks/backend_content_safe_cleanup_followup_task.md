# Back-end Task: Safe Cleanup Follow-up For Legacy Asset Candidates

Статус: in_progress (Codex Back-end, dispatched 2026-06-13)
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-193
Эпик: epic_full_project_quality_pass

## Scope

Review and safely move likely unused legacy assets after the dynamic asset manifest task is complete.

## Candidate Groups

- `.DS_Store` under assets.
- old `*_placeholder.png` character sprites.
- legacy root enemy duplicates under `assets/sprites/`.
- legacy `assets/sprites/boss_warden.png`.

## Requirements

- No irreversible delete.
- Tracked candidates use `git rm` only after backup.
- Untracked candidates move to backup.
- Runtime and animation smoke pass after cleanup.

## Dependency

Blocked until `backend_content_unused_asset_audit_manifest_task.md` is done.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.

## Design Handoff Update (SCRUM-183, 2026-06-13)

Design audit/spec completed in `docs/design/reviews/legacy_sprite_cleanup_spec_2026_06.md`.

Design confirms these groups are visually obsolete and safe to treat as cleanup candidates after Back-end reference/runtime checks:

- old `assets/sprites/characters/*_placeholder.png` files for Assassin/Chemist/Doctor/Druid/Knight/Ranger;
- root prototype player sprites `assets/sprites/player_berserk.png`, `player_ranger.png`, `player_summoner.png`;
- root prototype enemy duplicates `assets/sprites/enemy_bone_shaman.png`, `enemy_bruiser.png`, `enemy_melee.png`, `enemy_runner.png`, `enemy_shooter.png`, `enemy_summoner.png`;
- legacy root `assets/sprites/boss_warden.png`.

Explicit keep list from Design:

- `assets/sprites/characters/berserk_walk_sheet_v2.png` remains live via `scripts/player.gd`;
- `assets/sprites/projectiles/enemy_projectile_magic_64.png` remains live via `scenes/EnemyProjectile.tscn`;
- `assets/sprites/enemies/*.png` remains active runtime/codex/rig source.

No deletion or move was performed by Design.
