# Legacy Sprite Cleanup Spec — 2026-06-13

Design owner: Codex Design
Source task: `docs/tasks/codex_design_legacy_sprite_cleanup_spec_task.md` / SCRUM-183

## Scope

This is a Design audit/spec only. No sprite files were deleted or moved in this pass.

## Design Cleanup Verdict

The following assets are visually obsolete prototype/placeholder leftovers and should be removed or archived by Back-end only after manifest and runtime reference checks:

- `assets/sprites/characters/assassin_placeholder.png`
- `assets/sprites/characters/chemist_placeholder.png`
- `assets/sprites/characters/doctor_placeholder.png`
- `assets/sprites/characters/druid_placeholder.png`
- `assets/sprites/characters/knight_placeholder.png`
- `assets/sprites/characters/ranger_placeholder.png`
- `assets/sprites/player_berserk.png`
- `assets/sprites/player_ranger.png`
- `assets/sprites/player_summoner.png`
- `assets/sprites/enemy_bone_shaman.png`
- `assets/sprites/enemy_bruiser.png`
- `assets/sprites/enemy_melee.png`
- `assets/sprites/enemy_runner.png`
- `assets/sprites/enemy_shooter.png`
- `assets/sprites/enemy_summoner.png`
- `assets/sprites/boss_warden.png`

## Keep / Do Not Remove

- `assets/sprites/characters/berserk_walk_sheet_v2.png` is live. It is preloaded by `scripts/player.gd` and also documented in current game state as the Berserk fallback/resource animation sheet.
- `assets/sprites/projectiles/enemy_projectile_magic_64.png` is live. It is referenced by `scenes/EnemyProjectile.tscn`, `tests/animation_smoke_test.gd`, and content docs.
- `assets/sprites/enemies/*.png` are active enemy sprites. They are referenced by scenes, codex data, rig manifests, and animation smoke tests.

## Reference Check Summary

The candidate cleanup files are referenced only by generation scripts, historical docs, audit reports, or this cleanup task. Active runtime references point to the newer folders:

- enemies: `assets/sprites/enemies/*.png`;
- bosses: `assets/sprites/bosses/*.png`;
- characters: canonical `assets/sprites/characters/<class_id>.png` plus live cutout/walk resources.

## Back-end Handoff

Back-end should continue the existing handoff task:

```text
docs/tasks/backend_content_safe_cleanup_followup_task.md
```

Required Back-end checks before moving/removing:

- rerun the dynamic asset manifest audit;
- confirm no scene/script/codex/UI/test reference is active for each candidate;
- archive or remove with the repository's safe cleanup procedure, including paired `.import` files;
- rerun runtime and animation smoke after cleanup.
